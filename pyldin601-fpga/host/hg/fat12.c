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
bool hg_path(const char *s, char out[HG_PATH_MAX]) {
    size_t n = strlen(s);
    if (!n || n >= HG_PATH_MAX)
        return false;
    unsigned depth = 0, at = 0;
    while (*s) {
        const char *end = strchr(s, '/');
        size_t len = end ? (size_t)(end - s) : strlen(s);
        char component[13], upper[13];
        if (!len || len > 12 || ++depth > HG_MAX_DEPTH)
            return false;
        memcpy(component, s, len);
        component[len] = 0;
        if (!hg_name(component, upper))
            return false;
        memcpy(out + at, upper, len);
        at += (unsigned)len;
        if (!end)
            break;
        out[at++] = '/';
        s = end + 1;
        if (!*s)
            return false;
    }
    out[at] = 0;
    return true;
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
                      : !((a->attr ^ b->attr) & 16) && a->size == b->size &&
                            (!a->size || !memcmp(a->data, b->data, a->size));
}
int hg_file_copy(HgFiles *dst, const HgFile *src) {
    if (dst->n >= HG_MAX_FILES)
        return hg_error("too many HG files/directories (maximum %u)", HG_MAX_FILES);
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
/* Directory entries keep their physical byte offset, including fragmented
   subdirectory chains. One global ownership map catches file/directory loops.
 */
static int read_chain(const uint8_t *d, const HgFat *f, unsigned first, bool *used, HgFile *file) {
    uint16_t chain[4084];
    unsigned count = 0, c = first, unit = f->spc * 512;
    while (c < 0xff8) {
        if (c < 2 || c >= f->clusters + 2 || used[c] || count >= f->clusters)
            return hg_error("invalid/cross-linked FAT12 chain: %s", file->name);
        used[c] = true;
        chain[count++] = (uint16_t)c;
        c = fat_get(d + f->fat, c);
    }
    if (!count || (!(file->attr & 16) && count != (file->size + unit - 1) / unit))
        return hg_error("invalid FAT12 chain length: %s", file->name);
    file->chain = malloc(count * sizeof(*file->chain));
    if (!file->chain)
        return -1;
    memcpy(file->chain, chain, count * sizeof(*chain));
    file->nchain = count;
    if (!(file->attr & 16)) {
        file->data = malloc(file->size ? file->size : 1);
        if (!file->data)
            return -1;
        for (unsigned i = 0; i < count; i++) {
            unsigned at = i * unit, n = file->size - at;
            if (n > unit)
                n = unit;
            memcpy(file->data + at, d + f->payload + (chain[i] - 2) * unit, n);
        }
    }
    return 0;
}
static int read_directory(const uint8_t *d, const HgFat *f, const HgFile *dir, unsigned parent,
                          unsigned depth, bool *used, HgFiles *result) {
    unsigned unit = f->spc * 512;
    unsigned slots = dir ? dir->nchain * unit / 32 : f->entries;
    for (unsigned slot = 0; slot < slots; slot++) {
        size_t offset =
            dir ? f->payload + (dir->chain[slot * 32 / unit] - 2) * unit + (slot * 32 % unit)
                : f->root + slot * 32;
        const uint8_t *e = d + offset;
        if (dir && slot < 2) {
            const char *dot = slot ? "..         " : ".          ";
            if (memcmp(e, dot, 11) || !(e[11] & 16) || hg_u32(e + 28) ||
                hg_u16(e + 26) != (slot ? parent : dir->chain[0]))
                return hg_error("invalid FAT12 . or .. entry: %s", dir->name);
            continue;
        }
        if (!e[0])
            return 0;
        if (e[0] == 0xe5 || (e[11] & 8))
            continue;
        HgFile file = {0};
        char text[13], normalized[13];
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
        if (!hg_name(text, normalized) || strcmp(text, normalized) || depth >= HG_MAX_DEPTH ||
            snprintf(file.name, sizeof(file.name), "%s%s%s", dir ? dir->name : "", dir ? "/" : "",
                     text) >= (int)sizeof(file.name) ||
            hg_find(result, file.name))
            return hg_error("invalid/duplicate/too deep FAT12 path");
        strcpy(file.host, file.name);
        file.size = hg_u32(e + 28);
        file.slot = (unsigned)offset;
        file.attr = e[11];
        file.time = hg_u16(e + 22);
        file.date = hg_u16(e + 24);
        if (file.size > (uint32_t)f->clusters * unit || ((file.attr & 16) && file.size))
            return hg_error("invalid FAT12 file/directory size");
        unsigned first = hg_u16(e + 26);
        int rc = 0;
        if ((file.attr & 16) || file.size)
            rc = read_chain(d, f, first, used, &file);
        else if (first)
            rc = hg_error("empty FAT12 file has a chain");
        if (!rc && (file.attr & 16))
            rc = read_directory(d, f, &file, dir ? dir->chain[0] : 0, depth + 1, used, result);
        if (rc < 0 || result->n >= HG_MAX_FILES) {
            free(file.chain);
            free(file.data);
            return -1;
        }
        HgFile *p = realloc(result->v, (result->n + 1) * sizeof(*p));
        if (!p) {
            free(file.chain);
            free(file.data);
            return -1;
        }
        result->v = p;
        result->v[result->n++] = file;
    }
    return 0;
}
int hg_fat_files(const uint8_t *d, size_t size, HgFiles *files) {
    HgFat f = {0};
    HgFiles result = {0};
    bool used[4086] = {0};
    if (hg_fat_info(d, size, &f) < 0 || read_directory(d, &f, NULL, 0, 0, used, &result) < 0) {
        hg_files_free(&result);
        return -1;
    }
    *files = result;
    return 0;
}
static void short_bytes(uint8_t *out, const char *name) {
    memset(out, ' ', 11);
    const char *base = strrchr(name, '/');
    if (base)
        name = base + 1;
    const char *dot = strchr(name, '.');
    memcpy(out, name, dot ? (size_t)(dot - name) : strlen(name));
    if (dot)
        memcpy(out + 8, dot + 1, strlen(dot + 1));
}
static HgFile *parent_file(HgFiles *files, const char *name) {
    const char *slash = strrchr(name, '/');
    if (!slash)
        return NULL;
    char parent[HG_PATH_MAX];
    memcpy(parent, name, (size_t)(slash - name));
    parent[slash - name] = 0;
    return hg_find(files, parent);
}
static unsigned allocate(uint8_t *d, const HgFat *f) {
    for (unsigned c = 2; c < f->clusters + 2; c++)
        if (!fat_get(d + f->fat, c)) {
            fat_set(d + f->fat, c, 0xfff);
            memset(d + f->payload + (c - 2) * f->spc * 512, 0, f->spc * 512);
            return c;
        }
    return 0;
}
static int entry_slot(uint8_t *d, const HgFat *f, HgFile *parent, unsigned *offset) {
    unsigned unit = f->spc * 512;
    unsigned slots = parent ? parent->nchain * unit / 32 : f->entries;
    for (unsigned i = parent ? 2 : 0; i < slots; i++) {
        unsigned at = parent ? (unsigned)f->payload + (parent->chain[i * 32 / unit] - 2) * unit +
                                   i * 32 % unit
                             : (unsigned)f->root + i * 32;
        if (!d[at] || d[at] == 0xe5) {
            *offset = at;
            /* Retain a terminator after insertion into an unused slot. */
            if (!d[at] && i + 1 < slots) {
                unsigned next = parent ? (unsigned)f->payload +
                                             (parent->chain[(i + 1) * 32 / unit] - 2) * unit +
                                             (i + 1) * 32 % unit
                                       : at + 32;
                memset(d + next, 0, 32);
            }
            return 0;
        }
    }
    if (!parent)
        return hg_error("FAT12 root is full");
    unsigned c = allocate(d, f);
    if (!c)
        return hg_error("no room to extend FAT12 directory");
    uint16_t *chain = realloc(parent->chain, (parent->nchain + 1) * sizeof(*chain));
    if (!chain)
        return -1;
    parent->chain = chain;
    fat_set(d + f->fat, chain[parent->nchain - 1], c);
    chain[parent->nchain++] = (uint16_t)c;
    *offset = (unsigned)f->payload + (c - 2) * unit;
    return 0;
}
static int path_compare(const void *a, const void *b) {
    return strcmp((*(const HgFile *const *)a)->name, (*(const HgFile *const *)b)->name);
}
int hg_fat_update(uint8_t *d, size_t size, const HgFiles *wanted) {
    HgFat f = {0};
    HgFiles old = {0};
    const HgFile **order = NULL;
    int rc = -1;
    if (wanted->n > HG_MAX_FILES || hg_fat_info(d, size, &f) < 0 || hg_fat_files(d, size, &old) < 0)
        return -1;
    order = malloc((wanted->n ? wanted->n : 1) * sizeof(*order));
    if (!order)
        goto end;
    unsigned unit = f.spc * 512;
    for (unsigned i = 0; i < wanted->n; i++) {
        const HgFile *file = &wanted->v[i];
        char name[HG_PATH_MAX];
        if (!hg_path(file->name, name) || strcmp(name, file->name) ||
            file->size > (uint32_t)f.clusters * unit || ((file->attr & 16) && file->size) ||
            (file->size && !file->data)) {
            hg_error("invalid/oversized host path");
            goto end;
        }
        for (unsigned j = 0; j < i; j++)
            if (!strcmp(file->name, wanted->v[j].name)) {
                hg_error("duplicate host path");
                goto end;
            }
        HgFile *parent = parent_file((HgFiles *)wanted, file->name);
        if (strchr(file->name, '/') && (!parent || !(parent->attr & 16))) {
            hg_error("missing FAT12 parent directory: %s", file->name);
            goto end;
        }
        order[i] = file;
    }
    if (wanted->n > 1)
        qsort(order, wanted->n, sizeof(*order), path_compare);
    /* Delete descendants as well as their directory entries before reuse. */
    for (unsigned i = 0; i < old.n; i++) {
        HgFile *prev = &old.v[i];
        const HgFile *file = hg_find(wanted, prev->name);
        if (!file || ((file->attr ^ prev->attr) & 16)) {
            d[prev->slot] = 0xe5;
            for (unsigned c = 0; c < prev->nchain; c++)
                fat_set(d + f.fat, prev->chain[c], 0);
            prev->name[0] = 0;
        }
    }
    for (unsigned i = 0; i < wanted->n; i++) {
        const HgFile *file = order[i];
        HgFile *prev = hg_find(&old, file->name);
        if (prev && ((file->attr & 16) ||
                     (hg_same(prev, file) && prev->date == file->date && prev->time == file->time)))
            continue;
        unsigned slot = prev ? prev->slot : 0;
        HgFile *parent = parent_file(&old, file->name);
        if (!prev && entry_slot(d, &f, parent, &slot) < 0)
            goto end;
        unsigned count = (file->attr & 16) ? 1 : (file->size + unit - 1) / unit;
        uint16_t chain[4084];
        unsigned keep = prev ? prev->nchain : 0;
        if (keep > count)
            keep = count;
        if (keep)
            memcpy(chain, prev->chain, keep * sizeof(*chain));
        if (prev)
            for (unsigned c = keep; c < prev->nchain; c++)
                fat_set(d + f.fat, prev->chain[c], 0);
        for (unsigned n = keep; n < count; n++) {
            chain[n] = (uint16_t)allocate(d, &f);
            if (!chain[n]) {
                hg_error("host files do not fit in FAT12");
                goto end;
            }
        }
        uint8_t *e = d + slot;
        memset(e, 0, 32);
        short_bytes(e, file->name);
        e[11] = file->attr;
        hg_p16(e + 22, file->time);
        hg_p16(e + 24, file->date);
        hg_p16(e + 26, count ? chain[0] : 0);
        hg_p32(e + 28, file->size);
        for (unsigned c = 0; c < count; c++) {
            fat_set(d + f.fat, chain[c], c + 1 < count ? chain[c + 1] : 0xfff);
            uint8_t *data = d + f.payload + (chain[c] - 2) * unit;
            if (file->attr & 16) {
                memset(data, 0, unit);
                memcpy(data, ".          ", 11);
                data[11] = 16;
                hg_p16(data + 26, chain[0]);
                memcpy(data + 32, "..         ", 11);
                data[43] = 16;
                hg_p16(data + 58, parent ? parent->chain[0] : 0);
            } else {
                unsigned at = c * unit, len = file->size - at;
                if (len > unit)
                    len = unit;
                if (len)
                    memcpy(data, file->data + at, len);
                memset(data + len, 0, unit - len);
            }
        }
        if (!prev) {
            HgFile *p = realloc(old.v, (old.n + 1) * sizeof(*p));
            if (!p)
                goto end;
            old.v = p;
            prev = &old.v[old.n++];
            *prev = *file;
            prev->data = NULL;
            prev->chain = NULL;
        } else {
            free(prev->chain);
            free(prev->data);
            prev->data = NULL;
        }
        prev->slot = slot;
        prev->nchain = count;
        prev->chain = malloc((count ? count : 1) * sizeof(*chain));
        if (!prev->chain)
            goto end;
        if (count)
            memcpy(prev->chain, chain, count * sizeof(*chain));
    }
    for (unsigned i = 1; i < f.fats; i++)
        memcpy(d + f.fat + i * f.fat_size, d + f.fat, f.fat_size);
    rc = 0;
end:
    free(order);
    hg_files_free(&old);
    return rc;
}
