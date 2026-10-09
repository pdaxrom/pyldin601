#define _POSIX_C_SOURCE 200809L
#include "hg.h"
#include <ctype.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

uint16_t hg_u16(const uint8_t *p) { return p[0] | (uint16_t)p[1] << 8; }
uint32_t hg_u32(const uint8_t *p) { return hg_u16(p) | (uint32_t)hg_u16(p + 2) << 16; }
void hg_p16(uint8_t *p, unsigned n) {
    p[0] = n;
    p[1] = n >> 8;
}
void hg_p32(uint8_t *p, uint32_t n) {
    hg_p16(p, n);
    hg_p16(p + 2, n >> 16);
}
uint64_t hg_millis(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (uint64_t)t.tv_sec * 1000 + (unsigned long)t.tv_nsec / 1000000;
}
void hg_delay(unsigned usec) {
    struct timespec t = {usec / 1000000, (long)(usec % 1000000) * 1000};
    while (nanosleep(&t, &t) < 0 && errno == EINTR) {
    }
}
int hg_error(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fputs("HG: ", stderr);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
    return -1;
}
bool hg_name(const char *s, char out[13]) {
    const char *allowed = "_$~!#%&()@^{}-";
    unsigned b = 0, e = 0, n = 0;
    bool dot = false;
    for (; *s; s++) {
        unsigned char c = (unsigned char)*s;
        if (c == '.') {
            if (dot || !b)
                return false;
            dot = true;
        } else {
            if (c >= 'a' && c <= 'z')
                c -= 32;
            if (!((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || strchr(allowed, c)))
                return false;
            if (dot ? ++e > 3 : ++b > 8)
                return false;
        }
        if (n >= 12)
            return false;
        out[n++] = (char)c;
    }
    out[n] = 0;
    return b && (!dot || e);
}
void hg_files_free(HgFiles *f) {
    for (unsigned i = 0; i < f->n; i++) {
        free(f->v[i].data);
        free(f->v[i].chain);
    }
    free(f->v);
    memset(f, 0, sizeof(*f));
}
HgFile *hg_find(const HgFiles *f, const char *name) {
    for (unsigned i = 0; i < f->n; i++)
        if (!strcmp(f->v[i].name, name))
            return &f->v[i];
    return NULL;
}
bool hg_same(const HgFile *a, const HgFile *b) {
    return (!a || !b) ? a == b
                      : a->size == b->size && (!a->size || !memcmp(a->data, b->data, a->size));
}
int hg_file_copy(HgFiles *dst, const HgFile *src) {
    if (dst->n >= HG_MAX_FILES)
        return hg_error("too many root files");
    HgFile *v = realloc(dst->v, (dst->n + 1) * sizeof(*v));
    if (!v)
        return hg_error("out of memory");
    dst->v = v;
    HgFile *p = &v[dst->n];
    *p = *src;
    p->chain = NULL;
    p->nchain = 0;
    p->data = malloc(src->size ? src->size : 1);
    if (!p->data)
        return hg_error("out of memory");
    if (src->size)
        memcpy(p->data, src->data, src->size);
    dst->n++;
    return 0;
}
static unsigned fat_get(const uint8_t *p, unsigned c) {
    unsigned n = hg_u16(p + c + c / 2);
    return c & 1 ? n >> 4 : n & 4095;
}
static void fat_set(uint8_t *p, unsigned c, unsigned n) {
    p += c + c / 2;
    unsigned old = hg_u16(p);
    hg_p16(p, c & 1 ? (old & 15) | (n << 4) : (old & 0xf000) | n);
}
int hg_fat_info(const uint8_t *d, size_t size, HgFat *f) {
    if (size < 512 || size % 512 || (hg_u16(d + 510) != 0xaa55 && hg_u16(d + 510) != 0x5aa5))
        return hg_error("invalid FAT12 image/signature");
    memset(f, 0, sizeof(*f));
    f->spc = d[13];
    f->reserved = hg_u16(d + 14);
    f->fats = d[16];
    f->entries = hg_u16(d + 17);
    f->sectors = hg_u16(d + 19);
    f->spf = hg_u16(d + 22);
    if (hg_u16(d + 11) != 512 || !f->spc || f->spc > 128 || (f->spc & (f->spc - 1)) ||
        !f->reserved || f->reserved > 255 || !f->fats || !f->entries || !f->spf || f->spf > 255 ||
        !f->sectors || f->sectors > size / 512)
        return hg_error("unsupported UniDOS BPB");
    f->fat = f->reserved * 512;
    f->fat_size = f->spf * 512;
    f->root = f->fat + f->fats * f->fat_size;
    f->payload = f->root + ((f->entries * 32 + 511) / 512) * 512;
    if (f->payload >= f->sectors * 512u)
        return hg_error("FAT12 metadata outside volume");
    f->clusters = (f->sectors - f->payload / 512) / f->spc;
    if (!f->clusters || f->clusters >= 4085 || f->fat_size < ((f->clusters + 2) * 3 + 1) / 2)
        return hg_error("not FAT12 or insufficient FAT space");
    const uint8_t *table = d + f->fat;
    for (unsigned i = 1; i < f->fats; i++)
        if (memcmp(table, table + i * f->fat_size, f->fat_size))
            return hg_error("FAT copies differ; deferring sync");
    if ((fat_get(table, 0) & 255) != d[21] || fat_get(table, 1) < 0xff8)
        return hg_error("invalid FAT reserved entries");
    return 0;
}
uint8_t *hg_fat_blank(unsigned sectors, size_t *size) {
    if (sectors < 128 || sectors > HG_MAX_SECTORS) {
        hg_error("FAT12 sectors must be 128..32736");
        return NULL;
    }
    *size = sectors * 512u;
    uint8_t *d = calloc(1, *size);
    if (!d)
        return NULL;
    memcpy(d, "\xeb\x3c\x90UniDOS  ", 11);
    hg_p16(d + 11, 512);
    d[13] = 8;
    hg_p16(d + 14, 1);
    d[16] = 2;
    hg_p16(d + 17, 512);
    hg_p16(d + 19, sectors);
    d[21] = 0xf8;
    hg_p16(d + 22, 12);
    hg_p16(d + 24, 81);
    hg_p16(d + 26, 2);
    d[38] = 0x29;
    memcpy(d + 43, "UniDOS     FAT12   ", 19);
    hg_p16(d + 510, 0xaa55);
    memcpy(d + 512, "\xf8\xff\xff", 3);
    memcpy(d + 13 * 512, "\xf8\xff\xff", 3);
    return d;
}
int hg_fat_files(const uint8_t *d, size_t size, HgFiles *files) {
    HgFat f = {0};
    HgFiles result = {0};
    bool used[4086] = {0};
    if (hg_fat_info(d, size, &f) < 0)
        return -1;
    const uint8_t *table = d + f.fat;
    unsigned unit = f.spc * 512;
    for (unsigned slot = 0; slot < f.entries; slot++) {
        const uint8_t *e = d + f.root + slot * 32;
        if (!e[0])
            break;
        if (e[0] == 0xe5 || (e[11] & 8) || e[11] == 15)
            continue;
        if (e[11] & 16) {
            hg_error("directory mirror supports root files only");
            goto fail;
        }
        HgFile file = {0};
        char text[13];
        unsigned b = 8, x = 3;
        while (b && e[b - 1] == ' ')
            b--;
        while (x && e[8 + x - 1] == ' ')
            x--;
        memcpy(text, e, b);
        unsigned len = b;
        if (x) {
            text[len++] = '.';
            memcpy(text + len, e + 8, x);
            len += x;
        }
        text[len] = 0;
        if (!hg_name(text, file.name) || strcmp(text, file.name) || hg_find(&result, file.name)) {
            hg_error("invalid/duplicate FAT12 name");
            goto fail;
        }
        strcpy(file.host, file.name);
        file.size = hg_u32(e + 28);
        file.slot = slot;
        file.attr = e[11];
        file.time = hg_u16(e + 22);
        file.date = hg_u16(e + 24);
        if (file.size > (uint32_t)f.clusters * unit) {
            hg_error("file exceeds FAT12 capacity");
            goto fail;
        }
        file.nchain = (file.size + unit - 1) / unit;
        file.chain = calloc(file.nchain ? file.nchain : 1, sizeof(*file.chain));
        file.data = malloc(file.size ? file.size : 1);
        if (!file.chain || !file.data) {
            free(file.chain);
            free(file.data);
            goto fail;
        }
        unsigned c = hg_u16(e + 26);
        for (unsigned i = 0; i < file.nchain; i++) {
            if (c < 2 || c >= f.clusters + 2 || used[c]) {
                free(file.chain);
                free(file.data);
                hg_error("invalid/cross-linked FAT12 chain");
                goto fail;
            }
            used[c] = true;
            file.chain[i] = c;
            unsigned at = i * unit, n = file.size - at;
            if (n > unit)
                n = unit;
            memcpy(file.data + at, d + f.payload + (c - 2) * unit, n);
            c = fat_get(table, c);
        }
        if ((file.nchain && c < 0xff8) || (!file.nchain && c)) {
            free(file.chain);
            free(file.data);
            hg_error("invalid FAT12 end marker");
            goto fail;
        }
        if (result.n >= HG_MAX_FILES) {
            free(file.chain);
            free(file.data);
            goto fail;
        }
        HgFile *p = realloc(result.v, (result.n + 1) * sizeof(*p));
        if (!p) {
            free(file.chain);
            free(file.data);
            goto fail;
        }
        result.v = p;
        result.v[result.n++] = file;
    }
    *files = result;
    return 0;
fail:
    hg_files_free(&result);
    return -1;
}
static void short_bytes(uint8_t *out, const char *name) {
    memset(out, ' ', 11);
    const char *dot = strchr(name, '.');
    memcpy(out, name, dot ? (size_t)(dot - name) : strlen(name));
    if (dot)
        memcpy(out + 8, dot + 1, strlen(dot + 1));
}
int hg_fat_update(uint8_t *d, size_t size, const HgFiles *wanted) {
    HgFat f = {0};
    HgFiles old = {0};
    if (hg_fat_info(d, size, &f) < 0 || hg_fat_files(d, size, &old) < 0)
        return -1;
    uint8_t *table = d + f.fat;
    unsigned unit = f.spc * 512;
    for (unsigned i = 0; i < old.n; i++)
        if (!hg_find(wanted, old.v[i].name)) {
            d[f.root + old.v[i].slot * 32] = 0xe5;
            for (unsigned c = 0; c < old.v[i].nchain; c++)
                fat_set(table, old.v[i].chain[c], 0);
        }
    for (unsigned i = 0; i < wanted->n; i++) {
        const HgFile *file = &wanted->v[i], *prev = hg_find(&old, file->name);
        char name[13];
        if (!hg_name(file->name, name) || strcmp(name, file->name) ||
            file->size > (uint32_t)f.clusters * unit) {
            hg_error("invalid/oversized host file");
            goto fail;
        }
        if (hg_same(prev, file) && prev->date == file->date && prev->time == file->time)
            continue;
        unsigned slot = prev ? prev->slot : f.entries;
        if (!prev)
            for (unsigned s = 0; s < f.entries; s++)
                if (!d[f.root + s * 32] || d[f.root + s * 32] == 0xe5) {
                    slot = s;
                    break;
                }
        if (slot == f.entries) {
            hg_error("FAT12 root is full");
            goto fail;
        }
        unsigned count = (file->size + unit - 1) / unit;
        uint16_t chain[4084];
        unsigned keep = prev ? prev->nchain : 0;
        if (keep > count)
            keep = count;
        if (keep)
            memcpy(chain, prev->chain, keep * sizeof(*chain));
        if (prev)
            for (unsigned c = keep; c < prev->nchain; c++)
                fat_set(table, prev->chain[c], 0);
        unsigned n = keep;
        for (unsigned c = 2; c < f.clusters + 2 && n < count; c++)
            if (!fat_get(table, c)) {
                chain[n++] = c;
                fat_set(table, c, 0xfff);
            }
        if (n != count) {
            hg_error("host files do not fit in FAT12");
            goto fail;
        }
        uint8_t *e = d + f.root + slot * 32;
        bool end = !e[0];
        memset(e, 0, 32);
        short_bytes(e, file->name);
        e[11] = file->attr;
        hg_p16(e + 22, file->time);
        hg_p16(e + 24, file->date);
        hg_p16(e + 26, count ? chain[0] : 0);
        hg_p32(e + 28, file->size);
        if (end && slot + 1 < f.entries)
            memset(e + 32, 0, 32);
        for (unsigned c = 0; c < count; c++) {
            fat_set(table, chain[c], c + 1 < count ? chain[c + 1] : 0xfff);
            size_t offset = f.payload + (chain[c] - 2) * unit;
            unsigned at = c * unit, len = file->size - at;
            if (len > unit)
                len = unit;
            memcpy(d + offset, file->data + at, len);
            memset(d + offset + len, 0, unit - len);
        }
    }
    for (unsigned i = 1; i < f.fats; i++)
        memcpy(table + i * f.fat_size, table, f.fat_size);
    hg_files_free(&old);
    return 0;
fail:
    hg_files_free(&old);
    return -1;
}
