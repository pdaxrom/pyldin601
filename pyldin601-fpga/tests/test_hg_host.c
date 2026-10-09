#define _POSIX_C_SOURCE 200809L
#define _DARWIN_C_SOURCE
#include "hg.h"
#include <assert.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void put(const char *dir, const char *name, const char *data) {
    char path[1024];
    snprintf(path, sizeof(path), "%s/%s", dir, name);
    FILE *f = fopen(path, "wb");
    assert(f);
    assert(fwrite(data, 1, strlen(data), f) == strlen(data));
    assert(!fclose(f));
}
static void expect(const char *dir, const char *name, const char *data) {
    char path[1024], buf[1024];
    snprintf(path, sizeof(path), "%s/%s", dir, name);
    FILE *f = fopen(path, "rb");
    assert(f);
    size_t n = fread(buf, 1, sizeof(buf), f);
    assert(!fclose(f));
    assert(n == strlen(data) && !memcmp(buf, data, n));
}
static void remove_tree(const char *path) {
    DIR *dir = opendir(path);
    assert(dir);
    struct dirent *e;
    while ((e = readdir(dir))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, ".."))
            continue;
        char name[1024];
        snprintf(name, sizeof(name), "%s/%s", path, e->d_name);
        struct stat st;
        assert(!lstat(name, &st));
        if (S_ISDIR(st.st_mode))
            remove_tree(name);
        else
            assert(!unlink(name));
    }
    closedir(dir);
    assert(!rmdir(path));
}
static void guest_file(HgVolume *v, const char *name, const char *text) {
    HgFiles files = {0};
    assert(!hg_fat_files(v->image, v->size, &files));
    HgFile *found = hg_find(&files, name);
    if (found) {
        if (!text) {
            unsigned at = (unsigned)(found - files.v);
            free(found->data);
            free(found->chain);
            memmove(found, found + 1, (files.n - at - 1) * sizeof(*found));
            files.n--;
        } else {
            free(found->data);
            found->size = (uint32_t)strlen(text);
            found->data = (uint8_t *)strdup(text);
        }
    } else if (text) {
        HgFile file = {0};
        strcpy(file.name, name);
        strcpy(file.host, name);
        file.attr = 0x20;
        file.date = 0x5921;
        file.size = (uint32_t)strlen(text);
        file.data = (uint8_t *)text;
        assert(!hg_file_copy(&files, &file));
    }
    uint8_t *data = malloc(v->size);
    assert(data);
    memcpy(data, v->image, v->size);
    assert(!hg_fat_update(data, v->size, &files));
    for (size_t at = 0; at < v->size; at += 512)
        if (memcmp(v->image + at, data + at, 512))
            assert(hg_volume_write(v, (unsigned)(at / 512), data + at, 512) == HG_OK);
    free(data);
    hg_files_free(&files);
}
static void volume_tests(void) {
    char dir[] = "/tmp/p601-hg-native-XXXXXX";
    assert(mkdtemp(dir));
    put(dir, "hello.txt", "original");
    HgVolume v;
    assert(!hg_volume_open(&v, dir, true, 32736, false));
    assert(v.fat.clusters == 4084);
    HgFiles files = {0};
    assert(!hg_fat_files(v.image, v.size, &files));
    unsigned cluster = hg_find(&files, "HELLO.TXT")->chain[0];
    hg_files_free(&files);
    HgVolume duplicate;
    assert(hg_volume_open(&duplicate, dir, true, 32736, false) < 0);
    /* Guest writes and an independent host edit merge rather than blank/repack. */
    guest_file(&v, "BACK.TXT", "guest file");
    put(dir, "photo.pcx", "host image");
    assert(!hg_volume_sync(&v));
    expect(dir, "BACK.TXT", "guest file");
    expect(dir, "hello.txt", "original");
    assert(!hg_fat_files(v.image, v.size, &files));
    assert(hg_find(&files, "HELLO.TXT")->chain[0] == cluster && hg_find(&files, "PHOTO.PCX"));
    hg_files_free(&files);
    put(dir, "hello.txt", "host replacement");
    assert(!hg_volume_sync(&v));
    assert(!hg_fat_files(v.image, v.size, &files));
    assert(hg_find(&files, "HELLO.TXT")->chain[0] == cluster);
    hg_files_free(&files);
    guest_file(&v, "BACK.TXT", NULL);
    assert(!hg_volume_sync(&v));
    char path[1024];
    snprintf(path, sizeof(path), "%s/BACK.TXT", dir);
    assert(access(path, F_OK) < 0);
    /* Recovery before export preserves the journal and merges a new host file. */
    guest_file(&v, "RECOVER.TXT", "durable guest");
    hg_volume_close(&v);
    put(dir, "HOST.TXT", "new during crash");
    assert(!hg_volume_open(&v, dir, true, 32736, false));
    expect(dir, "RECOVER.TXT", "durable guest");
    expect(dir, "HOST.TXT", "new during crash");
    /* Both sides editing one file: host wins; guest data stays in a conflict copy. */
    guest_file(&v, "HELLO.TXT", "guest conflict");
    put(dir, "hello.txt", "host conflict");
    snprintf(path, sizeof(path), "%s/FULL.DAT", dir);
    int full = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    assert(full >= 0 && !ftruncate(full, (off_t)v.fat.clusters * 4096) && !close(full));
    assert(hg_volume_sync(&v) < 0 && hg_volume_sync(&v) < 0);
    expect(dir, "hello.txt", "host conflict");
    assert(!unlink(path));
    snprintf(path, sizeof(path), "%s/.p601-hg-conflicts", dir);
    assert(access(path, F_OK) < 0);
    assert(!hg_volume_sync(&v));
    expect(dir, "hello.txt", "host conflict");
    snprintf(path, sizeof(path), "%s/.p601-hg-conflicts", dir);
    DIR *conf = opendir(path);
    assert(conf);
    struct dirent *e;
    bool preserved = false;
    while ((e = readdir(conf)))
        if (strstr(e->d_name, "HELLO.TXT.guest-")) {
            expect(path, e->d_name, "guest conflict");
            preserved = true;
        }
    closedir(conf);
    assert(preserved);
    /* Repeated conflict/replay preserves one backup for identical content. */
    guest_file(&v, "HELLO.TXT", "guest conflict");
    put(dir, "hello.txt", "host conflict #2");
    assert(!hg_volume_sync(&v));
    conf = opendir(path);
    assert(conf);
    unsigned backups = 0;
    while ((e = readdir(conf)))
        if (strstr(e->d_name, "HELLO.TXT.guest-"))
            backups++;
    closedir(conf);
    assert(backups == 1);
    put(dir, "hello.txt", "host conflict");
    assert(!hg_volume_sync(&v));
    /* Inconsistent FAT copies must keep the pending image and host files. */
    uint8_t sector[512];
    memcpy(sector, v.image + 512, 512);
    sector[400] ^= 1;
    assert(hg_volume_write(&v, 1, sector, 512) == HG_OK);
    assert(hg_volume_sync(&v) < 0);
    expect(dir, "hello.txt", "host conflict");
    sector[400] ^= 1;
    assert(hg_volume_write(&v, 1, sector, 512) == HG_OK);
    assert(!hg_volume_sync(&v));
    hg_volume_close(&v);
    /* Read-only guest writes fail, but host imports remain automatic. */
    assert(!hg_volume_open(&v, dir, true, 32736, true));
    assert(hg_volume_write(&v, 1, sector, 512) == HG_READ_ONLY);
    put(dir, "RO.TXT", "host import");
    assert(!hg_volume_sync(&v));
    assert(!hg_fat_files(v.image, v.size, &files));
    assert(hg_find(&files, "RO.TXT"));
    hg_files_free(&files);
    hg_volume_close(&v);
    /* Files too large, collisions and symlinks do not replace the live image. */
    assert(!hg_volume_open(&v, dir, true, 32736, false));
    put(dir, "HELLO.TXT", "duplicate");
    assert(hg_volume_sync(&v) < 0);
    snprintf(path, sizeof(path), "%s/HELLO.TXT", dir);
    assert(!unlink(path));
    snprintf(path, sizeof(path), "%s/LINK.TXT", dir);
    assert(!symlink("hello.txt", path));
    assert(hg_volume_sync(&v) < 0);
    assert(!unlink(path));
    put(dir, "a-long-host-name.txt", "ignored");
    assert(!hg_volume_sync(&v));
    hg_volume_close(&v);
    remove_tree(dir);
    puts("PASS native directory import/export, stable clusters, concurrent merge, conflict "
         "preservation, crash recovery, readonly and malformed FAT");
}
static void make_directory(const char *root, const char *name) {
    char path[1024];
    snprintf(path, sizeof(path), "%s/%s", root, name);
    assert(!mkdir(path, 0700));
}
static void guest_directory(HgVolume *v, const char *name) {
    HgFiles files = {0};
    assert(!hg_fat_files(v->image, v->size, &files));
    HgFile f = {0};
    strcpy(f.name, name);
    strcpy(f.host, name);
    f.attr = 16;
    assert(!hg_file_copy(&files, &f));
    uint8_t *data = malloc(v->size);
    assert(data);
    memcpy(data, v->image, v->size);
    assert(!hg_fat_update(data, v->size, &files));
    for (size_t at = 0; at < v->size; at += 512)
        if (memcmp(v->image + at, data + at, 512))
            assert(hg_volume_write(v, (unsigned)(at / 512), data + at, 512) == HG_OK);
    free(data);
    hg_files_free(&files);
}
static void guest_remove_tree(HgVolume *v, const char *name) {
    HgFiles files = {0}, wanted = {0};
    assert(!hg_fat_files(v->image, v->size, &files));
    size_t len = strlen(name);
    for (unsigned i = 0; i < files.n; i++)
        if (strncmp(files.v[i].name, name, len) ||
            (files.v[i].name[len] && files.v[i].name[len] != '/'))
            assert(!hg_file_copy(&wanted, &files.v[i]));
    uint8_t *data = malloc(v->size);
    assert(data);
    memcpy(data, v->image, v->size);
    assert(!hg_fat_update(data, v->size, &wanted));
    for (size_t at = 0; at < v->size; at += 512)
        if (memcmp(v->image + at, data + at, 512))
            assert(hg_volume_write(v, (unsigned)(at / 512), data + at, 512) == HG_OK);
    free(data);
    hg_files_free(&files);
    hg_files_free(&wanted);
}
static void directory_tests(void) {
    char dir[] = "/tmp/p601-hg-tree-XXXXXX", path[1024];
    assert(mkdtemp(dir));
    put(dir, "ROOT.TXT", "root remains");
    make_directory(dir, "pictures");
    make_directory(dir, "pictures/inner");
    make_directory(dir, "EMPTY");
    put(dir, "pictures/inner/lena.iff", "original image");
    put(dir, "pictures/ROOT.TXT", "same leaf in another directory");
    HgVolume v;
    assert(!hg_volume_open(&v, dir, true, HG_MAX_SECTORS, false));
    HgFiles files = {0};
    assert(!hg_fat_files(v.image, v.size, &files));
    assert(hg_find(&files, "EMPTY")->attr & 16);
    unsigned cluster = hg_find(&files, "PICTURES/INNER/LENA.IFF")->chain[0];
    hg_files_free(&files);
    guest_file(&v, "PICTURES/INNER/NEW.TXT", "nested guest write");
    put(dir, "pictures/ROOT.TXT", "independent host edit");
    assert(!hg_volume_sync(&v));
    expect(dir, "pictures/inner/NEW.TXT", "nested guest write");
    expect(dir, "pictures/ROOT.TXT", "independent host edit");
    assert(!hg_fat_files(v.image, v.size, &files));
    assert(hg_find(&files, "PICTURES/INNER/LENA.IFF")->chain[0] == cluster);
    hg_files_free(&files);
    /* A full directory grows into a fragmented chain; retained file clusters
       and all entries must survive another host edit. */
    for (unsigned i = 0; i < 140; i++) {
        char name[80];
        snprintf(name, sizeof(name), "pictures/inner/F%03u.TXT", i);
        put(dir, name, "entry");
    }
    assert(!hg_volume_sync(&v));
    assert(!hg_fat_files(v.image, v.size, &files));
    HgFile *folder = hg_find(&files, "PICTURES/INNER");
    assert(folder && folder->nchain == 2 && folder->chain[1] != folder->chain[0] + 1);
    assert(hg_find(&files, "PICTURES/INNER/F139.TXT"));
    assert(hg_find(&files, "PICTURES/INNER/LENA.IFF")->chain[0] == cluster);
    /* A directory loop and invalid parent pointer are rejected without export. */
    size_t offset = v.fat.payload + (folder->chain[0] - 2) * 4096;
    uint8_t *bad = malloc(v.size);
    assert(bad);
    memcpy(bad, v.image, v.size);
    hg_p16(bad + offset + 58, folder->chain[0]);
    HgFiles rejected = {0};
    assert(hg_fat_files(bad, v.size, &rejected) < 0);
    memcpy(bad, v.image, v.size);
    hg_p16(bad + hg_find(&files, "PICTURES/INNER/LENA.IFF")->slot + 26, folder->chain[0]);
    assert(hg_fat_files(bad, v.size, &rejected) < 0);
    free(bad);
    hg_files_free(&files);
    /* Crash after durable guest directory/data writes, before any export. */
    guest_directory(&v, "DISK_C");
    guest_directory(&v, "DISK_C/SUB");
    guest_file(&v, "DISK_C/SUB/UE.CMD", "durable nested guest");
    hg_volume_close(&v);
    put(dir, "pictures/inner/HOST.TXT", "host edited while down");
    assert(!hg_volume_open(&v, dir, true, HG_MAX_SECTORS, false));
    expect(dir, "DISK_C/SUB/UE.CMD", "durable nested guest");
    expect(dir, "pictures/inner/HOST.TXT", "host edited while down");
    guest_file(&v, "DISK_C/SUB/UE.CMD", NULL);
    assert(!hg_volume_sync(&v));
    guest_remove_tree(&v, "DISK_C");
    assert(!hg_volume_sync(&v));
    snprintf(path, sizeof(path), "%s/DISK_C", dir);
    assert(access(path, F_OK) < 0);
    /* Concurrent guest deletion / host addition retains the edited host tree. */
    guest_remove_tree(&v, "PICTURES");
    put(dir, "pictures/inner/ADDED.TXT", "host wins tree deletion conflict");
    assert(!hg_volume_sync(&v));
    expect(dir, "pictures/inner/lena.iff", "original image");
    assert(!hg_fat_files(v.image, v.size, &files));
    assert(hg_find(&files, "PICTURES/INNER/ADDED.TXT"));
    hg_files_free(&files);
    /* Host deletion / modified guest leaf is saved with its full path. */
    guest_file(&v, "PICTURES/INNER/LENA.IFF", "guest conflict");
    snprintf(path, sizeof(path), "%s/pictures", dir);
    remove_tree(path);
    assert(!hg_volume_sync(&v));
    snprintf(path, sizeof(path), "%s/.p601-hg-conflicts/PICTURES/INNER", dir);
    DIR *backups = opendir(path);
    assert(backups);
    bool saved = false;
    struct dirent *de;
    while ((de = readdir(backups)))
        if (strstr(de->d_name, "LENA.IFF.guest-")) {
            expect(path, de->d_name, "guest conflict");
            saved = true;
        }
    closedir(backups);
    assert(saved);
    /* Replacing an unchanged host directory with a guest file removes only
       its known children. Switching back to a directory also works. */
    make_directory(dir, "SWAP");
    put(dir, "SWAP/ONE.TXT", "old nested file");
    assert(!hg_volume_sync(&v));
    guest_remove_tree(&v, "SWAP");
    guest_file(&v, "SWAP", "guest replaced directory");
    assert(!hg_volume_sync(&v));
    expect(dir, "SWAP", "guest replaced directory");
    guest_file(&v, "SWAP", NULL);
    guest_directory(&v, "SWAP");
    guest_file(&v, "SWAP/ONE.TXT", "new nested file");
    assert(!hg_volume_sync(&v));
    expect(dir, "SWAP/ONE.TXT", "new nested file");
    /* Nested case collisions and intermediate symlinks preserve the image. */
    put(dir, "SWAP/one.txt", "duplicate");
    assert(hg_volume_sync(&v) < 0);
    snprintf(path, sizeof(path), "%s/SWAP/one.txt", dir);
    assert(!unlink(path));
    snprintf(path, sizeof(path), "%s/SWAP/LINK", dir);
    assert(!symlink("/tmp", path));
    assert(hg_volume_sync(&v) < 0);
    assert(!unlink(path));
    assert(!hg_volume_sync(&v));
    hg_volume_close(&v);
    assert(!hg_volume_open(&v, dir, true, HG_MAX_SECTORS, false));
    expect(dir, "SWAP/ONE.TXT", "new nested file");
    hg_volume_close(&v);
    remove_tree(dir);
    char normalized[HG_PATH_MAX];
    assert(!hg_path("../OUT.TXT", normalized));
    assert(!hg_path("DIR/../../OUT", normalized));
    assert(!hg_path("/OUT.TXT", normalized));
    assert(!hg_path("DIR//OUT", normalized));
    assert(hg_path("Dir/Sub/a.txt", normalized) && !strcmp(normalized, "DIR/SUB/A.TXT"));
    puts("PASS nested/empty directories, fragmented growth, stable clusters, bidirectional "
         "merge/delete/type changes, crash recovery, tree conflicts, nested symlinks/collisions");
}
typedef struct {
    uint8_t input[524], output[1024];
    unsigned in_len, in_at, out_len, phases, packets, maxpacket;
    bool selected;
} Fake;
static int select_fake(void *ctx, bool s) {
    ((Fake *)ctx)->selected = s;
    return 0;
}
static int exchange_fake(void *ctx, const uint8_t *out, uint8_t *in, unsigned n, bool packet) {
    Fake *f = ctx;
    assert(f->selected);
    if (packet) {
        assert(n <= 32);
        f->packets++;
        if (n > f->maxpacket)
            f->maxpacket = n;
    }
    if (out) {
        assert(f->out_len + n <= sizeof(f->output));
        memcpy(f->output + f->out_len, out, n);
        f->out_len += n;
    }
    if (in) {
        assert(f->in_at + n <= f->in_len);
        memcpy(in, f->input + f->in_at, n);
        f->in_at += n;
    }
    return 0;
}
static int phase_fake(void *ctx, unsigned value, unsigned mask) {
    Fake *f = ctx;
    f->phases++;
    assert((value & mask) == value);
    return 0;
}
static void request(Fake *f, unsigned ver, unsigned op, unsigned block, unsigned count,
                    const uint8_t *payload) {
    memset(f, 0, sizeof(*f));
    memcpy(f->input, "HG", 2);
    f->input[2] = ver;
    f->input[3] = op;
    hg_p16(f->input + 5, block);
    hg_p16(f->input + 7, count);
    for (unsigned i = 0; i < 9; i++)
        f->input[9] ^= f->input[i];
    f->in_len = 10;
    if (payload) {
        memcpy(f->input + 10, payload, count);
        unsigned sum = 0;
        for (unsigned i = 0; i < count; i++)
            sum += payload[i];
        hg_p16(f->input + 10 + count, sum);
        f->in_len += count + 2;
    }
}
static void protocol_tests(void) {
    char path[] = "/tmp/p601-hg-protocol-XXXXXX";
    int fd = mkstemp(path);
    assert(fd >= 0);
    close(fd);
    unlink(path);
    assert(!hg_create_image(path, 32736));
    HgVolume v;
    assert(!hg_volume_open(&v, path, false, 32736, false));
    uint8_t data[512];
    for (unsigned i = 0; i < 512; i++)
        data[i] = (uint8_t)i;
    Fake f;
    HgLink l = {&f, select_fake, exchange_fake, phase_fake};
    for (unsigned version = 1; version <= 2; version++) {
        request(&f, version, 1, 0, 512, NULL);
        assert(hg_serve(&l, &v, false) == 0);
        assert(f.out_len == 515 && f.output[0] == 0 && !memcmp(f.output + 1, v.image, 512) &&
               !f.selected);
        request(&f, version, 2, 100, 512, data);
        assert(hg_serve(&l, &v, false) == 1);
        assert(f.out_len == 2 && !f.output[0] && !f.output[1] &&
               !memcmp(v.image + 100 * 512, data, 512));
        if (version == 2)
            assert(f.maxpacket == 32 && f.packets == 18 && f.phases == 21);
        request(&f, version, 2, 100, 512, data);
        f.input[523] ^= 1;
        assert(!hg_serve(&l, &v, false));
        assert(f.output[1] == HG_CHECKSUM);
        request(&f, version, 1, 65535, 512, NULL);
        assert(!hg_serve(&l, &v, false));
        assert(f.output[0] == HG_RANGE);
        request(&f, version, 3, 50, 6, NULL);
        assert(!hg_serve(&l, &v, false));
        assert(f.out_len == 9 && !f.output[0]);
        request(&f, version, 3, 51, 6, NULL);
        assert(!hg_serve(&l, &v, false));
        assert(f.output[0] == HG_PROTOCOL);
        request(&f, version, 1, 0, 512, NULL);
        f.input[9] ^= 1;
        assert(!hg_serve(&l, &v, false));
        assert(f.output[0] == HG_PROTOCOL);
        v.readonly = true;
        request(&f, version, 2, 100, 512, NULL);
        assert(!hg_serve(&l, &v, false));
        assert(f.output[0] == HG_READ_ONLY);
        v.readonly = false;
    }
    setenv("TZ", "UTC", 1);
    tzset();
    struct tm tm = {0};
    tm.tm_year = 126;
    tm.tm_mon = 9;
    tm.tm_mday = 8;
    tm.tm_hour = 19;
    tm.tm_min = 14;
    tm.tm_sec = 25;
    struct timespec t = {mktime(&tm), 440000000};
    uint8_t time_data[6];
    assert(!hg_time(50, &t, time_data));
    assert(hg_u16(time_data) == 0x6916 &&
           ((uint32_t)hg_u16(time_data + 2) * 65536 + hg_u16(time_data + 4)) ==
               (19 * 3600 + 14 * 60 + 25) * 50u + 22);
    tm.tm_year = 136;
    t.tv_sec = mktime(&tm);
    assert(hg_time(50, &t, time_data) < 0);
    hg_volume_close(&v);
    unlink(path);
    puts("PASS native HG v1/v2 READ/WRITE/TIME, packet phases, checksum/range/header/readonly and "
         "time encoding");
}
int main(void) {
    size_t size;
    uint8_t *d = hg_fat_blank(32400, &size);
    HgFat fat;
    assert(d && !hg_fat_info(d, size, &fat) && fat.clusters == 4042);
    free(d);
    assert(!hg_fat_blank(32737, &size));
    protocol_tests();
    volume_tests();
    directory_tests();
    return 0;
}
