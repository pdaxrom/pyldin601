#define _POSIX_C_SOURCE 200809L
#define _DEFAULT_SOURCE
#define _DARWIN_C_SOURCE
#include "hg.h"
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef __linux__
#include <sys/inotify.h>
#endif

static int all_write(int fd, const uint8_t *p, size_t n, off_t offset) {
    while (n) {
        ssize_t done = pwrite(fd, p, n, offset);
        if (done < 0 && errno == EINTR)
            continue;
        if (done <= 0)
            return -1;
        p += done;
        n -= done;
        offset += done;
    }
    return 0;
}
static int all_read(int fd, uint8_t *p, size_t n) {
    while (n) {
        ssize_t done = read(fd, p, n);
        if (done < 0 && errno == EINTR)
            continue;
        if (done <= 0)
            return -1;
        p += done;
        n -= done;
    }
    return 0;
}
static int atomic_file(int dirfd, const char *name, const uint8_t *data, size_t n) {
    static unsigned seq;
    char temporary[80];
    int fd = -1;
    for (unsigned tries = 0; tries < 100; tries++) {
        snprintf(temporary, sizeof(temporary), ".p601-hg-tmp-%ld-%u", (long)getpid(), seq++);
        fd = openat(dirfd, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
        if (fd >= 0 || errno != EEXIST)
            break;
    }
    if (fd < 0)
        return hg_error("creating %s: %s", name, strerror(errno));
    int rc = all_write(fd, data, n, 0);
    if (!rc)
        rc = fsync(fd);
    if (close(fd) < 0)
        rc = -1;
    if (!rc)
        rc = renameat(dirfd, temporary, dirfd, name);
    if (!rc)
        rc = fsync(dirfd);
    if (rc) {
        int saved = errno;
        unlinkat(dirfd, temporary, 0);
        return hg_error("saving %s: %s", name, strerror(saved));
    }
    return 0;
}
static bool same_stat(const struct stat *a, const struct stat *b) {
#ifdef __APPLE__
    const struct timespec *am = &a->st_mtimespec, *bm = &b->st_mtimespec;
    const struct timespec *ac = &a->st_ctimespec, *bc = &b->st_ctimespec;
#else
    const struct timespec *am = &a->st_mtim, *bm = &b->st_mtim;
    const struct timespec *ac = &a->st_ctim, *bc = &b->st_ctim;
#endif
    return a->st_dev == b->st_dev && a->st_ino == b->st_ino && a->st_size == b->st_size &&
           am->tv_sec == bm->tv_sec && am->tv_nsec == bm->tv_nsec && ac->tv_sec == bc->tv_sec &&
           ac->tv_nsec == bc->tv_nsec;
}
/* A file is imported only if its inode, size and timestamps survived the read.
 */
static int read_file(int dirfd, const char *name, uint8_t **data, size_t *size, struct stat *st,
                     size_t limit) {
    int fd = openat(dirfd, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0)
        return -1;
    struct stat before, after, path_stat;
    int rc = -1;
    uint8_t *p = NULL;
    if (fstat(fd, &before) < 0 || !S_ISREG(before.st_mode) || before.st_size < 0 ||
        (uint64_t)before.st_size > limit)
        goto end;
    p = malloc(before.st_size ? (size_t)before.st_size : 1);
    if (!p)
        goto end;
    if (all_read(fd, p, (size_t)before.st_size) < 0 || fstat(fd, &after) < 0 ||
        fstatat(dirfd, name, &path_stat, AT_SYMLINK_NOFOLLOW) < 0 || !same_stat(&before, &after) ||
        !same_stat(&before, &path_stat)) {
        errno = EAGAIN;
        goto end;
    }
    *data = p;
    *size = (size_t)before.st_size;
    if (st)
        *st = before;
    p = NULL;
    rc = 0;
end:
    free(p);
    {
        int saved = errno;
        close(fd);
        errno = saved;
    }
    return rc;
}
static int file_compare(const void *a, const void *b) {
    return strcmp(((const HgFile *)a)->name, ((const HgFile *)b)->name);
}
static int join_path(char out[HG_PATH_MAX], const char *prefix, const char *leaf) {
    if (snprintf(out, HG_PATH_MAX, "%s%s%s", prefix, *prefix ? "/" : "", leaf) >= HG_PATH_MAX)
        return hg_error("HG path exceeds %u bytes", HG_PATH_MAX - 1);
    return 0;
}
/* Walk each component with O_NOFOLLOW; no intermediate symlink can redirect
   a guest export outside the configured directory. */
static int open_parent(int root, const char *path, bool create, char leaf[13]) {
    char upper[HG_PATH_MAX], copy[HG_PATH_MAX];
    if (!hg_path(path, upper)) {
        errno = EINVAL;
        return -1;
    }
    strcpy(copy, path);
    int fd = openat(root, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0)
        return -1;
    char *component = copy, *slash;
    while ((slash = strchr(component, '/'))) {
        *slash = 0;
        if (create && mkdirat(fd, component, 0700) < 0 && errno != EEXIST) {
            close(fd);
            return -1;
        }
        int next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (next < 0) {
            close(fd);
            return -1;
        }
        if (create && fsync(fd) < 0) {
            close(fd);
            close(next);
            return -1;
        }
        close(fd);
        fd = next;
        component = slash + 1;
    }
    strcpy(leaf, component);
    return fd;
}
static int watch_directory(HgVolume *v, int fd, const char *path) {
#ifdef __linux__
    /* Watch the opened inode, even if an ancestor is renamed during the scan. */
    char proc[64];
    snprintf(proc, sizeof(proc), "/proc/self/fd/%d", fd);
    int id =
        inotify_add_watch(v->watchfd, proc,
                          IN_ONLYDIR | IN_MODIFY | IN_CLOSE_WRITE | IN_MOVED_TO | IN_MOVED_FROM |
                              IN_CREATE | IN_DELETE | IN_ATTRIB | IN_DELETE_SELF | IN_MOVE_SELF);
    if (id < 0)
        return hg_error("watching %s: %s", path, strerror(errno));
    for (unsigned i = 0; i < v->nwatches; i++)
        if (v->watches[i].id == id) {
            char before[HG_PATH_MAX], after[HG_PATH_MAX];
            if (*v->watches[i].path && *path && hg_path(v->watches[i].path, before) &&
                hg_path(path, after)) {
                size_t len = strlen(before);
                for (unsigned j = 0; j < v->nhost_writes; j++)
                    if (!strncmp(v->host_writes[j], before, len) && v->host_writes[j][len] == '/') {
                        char moved[HG_PATH_MAX];
                        if (join_path(moved, after, v->host_writes[j] + len + 1) < 0)
                            return -1;
                        strcpy(v->host_writes[j], moved);
                    }
            }
            strcpy(v->watches[i].path, path);
            v->watches[i].seen = true;
            return 0;
        }
    if (v->nwatches >= HG_MAX_FILES + 1)
        return hg_error("too many watched directories");
    HgWatch *p = realloc(v->watches, (v->nwatches + 1) * sizeof(*p));
    if (!p)
        return -1;
    v->watches = p;
    p[v->nwatches].id = id;
    p[v->nwatches].seen = true;
    strcpy(p[v->nwatches++].path, path);
    if (!*path)
        v->watch_id = id;
#else
    (void)v;
    (void)fd;
    (void)path;
#endif
    return 0;
}
static int scan_directory(HgVolume *v, int parent, const char *host_prefix, const char *prefix,
                          unsigned depth, HgFiles *result) {
    int fd = openat(parent, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0)
        return -1;
    DIR *dir = fdopendir(fd);
    if (!dir) {
        close(fd);
        return -1;
    }
    struct stat before, after;
    int rc = -1;
    if (fstat(fd, &before) < 0 || watch_directory(v, fd, host_prefix) < 0)
        goto end;
    struct dirent *de;
    while ((de = readdir(dir))) {
        if (de->d_name[0] == '.')
            continue;
        struct stat st;
        if (fstatat(fd, de->d_name, &st, AT_SYMLINK_NOFOLLOW) < 0)
            goto end;
        if (S_ISLNK(st.st_mode)) {
            hg_error("symlink is not an HG entry: %s/%s", host_prefix, de->d_name);
            goto end;
        }
        if (!S_ISREG(st.st_mode) && !S_ISDIR(st.st_mode))
            continue;
        HgFile f = {0};
        char upper[13];
        if (!hg_name(de->d_name, upper)) {
            hg_error("skipping non-DOS 8.3 entry: %s/%s", host_prefix, de->d_name);
            continue;
        }
        if (depth >= HG_MAX_DEPTH || join_path(f.name, prefix, upper) < 0 ||
            join_path(f.host, host_prefix, de->d_name) < 0)
            goto end;
        if (hg_find(result, f.name)) {
            hg_error("case-insensitive duplicate: %s", f.host);
            goto end;
        }
        f.attr = S_ISDIR(st.st_mode) ? 16 : 0x20;
        if (f.attr & 16) {
            int child = openat(fd, de->d_name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            struct stat opened;
            if (child < 0)
                goto end;
            bool same =
                !fstat(child, &opened) && st.st_dev == opened.st_dev && st.st_ino == opened.st_ino;
            int scanned = same ? scan_directory(v, child, f.host, f.name, depth + 1, result) : -1;
            close(child);
            if (scanned < 0)
                goto end;
        } else {
            size_t size;
            if (read_file(fd, de->d_name, &f.data, &size, &st, v->size) < 0)
                goto end;
            f.size = (uint32_t)size;
        }
        struct tm tm;
        localtime_r(&st.st_mtime, &tm);
        int year = tm.tm_year + 1900;
        if (year < 1980)
            year = 1980;
        if (year > 2107)
            year = 2107;
        f.date = (uint16_t)((year - 1980) << 9 | (tm.tm_mon + 1) << 5 | tm.tm_mday);
        f.time = (uint16_t)(tm.tm_hour << 11 | tm.tm_min << 5 | tm.tm_sec / 2);
        int copied = hg_file_copy(result, &f);
        free(f.data);
        if (copied < 0)
            goto end;
    }
    if (fstat(fd, &after) < 0 || !same_stat(&before, &after)) {
        errno = EAGAIN;
        goto end;
    }
    rc = 0;
end:
    closedir(dir);
    return rc;
}
static int scan(HgVolume *v, HgFiles *files) {
    HgFiles result = {0};
    for (unsigned i = 0; i < v->nwatches; i++)
        v->watches[i].seen = false;
    if (scan_directory(v, v->dirfd, "", "", 0, &result) < 0) {
        for (unsigned i = 0; i < v->nwatches; i++)
            v->watches[i].seen = true;
        hg_files_free(&result);
        return -1;
    }
    if (result.n > 1)
        qsort(result.v, result.n, sizeof(*result.v), file_compare);
    *files = result;
    return 0;
}
static void set_host_names(HgFiles *files, const HgFiles *names) {
    for (unsigned i = 0; i < files->n; i++) {
        const HgFile *f = hg_find(names, files->v[i].name);
        if (f)
            strcpy(files->v[i].host, f->host);
    }
}
/* Version 2 records relative 8.3 paths; version 1 flat journals are read in
   place and upgraded only after successful recovery, never by dropping data. */
static int save_state(HgVolume *v, bool dirty, const HgFiles *names) {
    size_t n = 16;
    for (unsigned i = 0; i < names->n; i++)
        n += 4 + strlen(names->v[i].name) + strlen(names->v[i].host);
    uint8_t *state = calloc(1, n);
    if (!state)
        return -1;
    memcpy(state, "P601HG\2", 7);
    state[8] = dirty;
    hg_p16(state + 10, v->fat.sectors);
    hg_p16(state + 12, names->n);
    size_t at = 16;
    for (unsigned i = 0; i < names->n; i++) {
        const HgFile *f = &names->v[i];
        size_t a = strlen(f->name), b = strlen(f->host);
        hg_p16(state + at, (unsigned)a);
        hg_p16(state + at + 2, (unsigned)b);
        memcpy(state + at + 4, f->name, a);
        memcpy(state + at + 4 + a, f->host, b);
        at += 4 + a + b;
    }
    int rc = atomic_file(v->dirfd, ".p601-hg.state", state, n);
    free(state);
    return rc;
}
static int load_state(HgVolume *v) {
    uint8_t *data;
    size_t size;
    if (read_file(v->dirfd, ".p601-hg.state", &data, &size, NULL,
                  16 + HG_MAX_FILES * (4 + 2 * HG_PATH_MAX)) < 0)
        return errno == ENOENT ? 1 : -1;
    unsigned n = size >= 16 ? hg_u16(data + 12) : 0;
    unsigned version = size >= 16 ? data[6] : 0;
    if (size < 16 || memcmp(data, "P601HG", 6) || data[7] || (version != 1 && version != 2) ||
        data[8] > 1 || n > HG_MAX_FILES || hg_u16(data + 10) != v->fat.sectors ||
        (version == 1 && size != 16 + n * 26))
        goto invalid;
    size_t at = 16;
    for (unsigned i = 0; i < n; i++) {
        HgFile f = {0};
        char normalized[HG_PATH_MAX];
        if (version == 1) {
            memcpy(f.name, data + at, 13);
            memcpy(f.host, data + at + 13, 13);
            if (!memchr(f.name, 0, 13) || !memchr(f.host, 0, 13))
                goto invalid;
            at += 26;
        } else {
            if (size - at < 4)
                goto invalid;
            unsigned a = hg_u16(data + at), b = hg_u16(data + at + 2);
            if (!a || !b || a >= HG_PATH_MAX || b >= HG_PATH_MAX || size - at - 4 < a + b ||
                memchr(data + at + 4, 0, a + b))
                goto invalid;
            memcpy(f.name, data + at + 4, a);
            memcpy(f.host, data + at + 4 + a, b);
            at += 4 + a + b;
        }
        if (!hg_path(f.name, normalized) || strcmp(normalized, f.name) ||
            !hg_path(f.host, normalized) || strcmp(normalized, f.name) ||
            hg_find(&v->names, f.name) || hg_file_copy(&v->names, &f) < 0)
            goto invalid;
    }
    if (at != size)
        goto invalid;
    v->dirty = data[8];
    free(data);
    return 0;
invalid:
    free(data);
    return hg_error("invalid HG journal/path; preserving image");
}
/* Read only the deliberately narrow JSON schema of the former Python daemon. */
static void space(const char **p) {
    while (**p == ' ' || **p == '\n' || **p == '\r' || **p == '\t')
        (*p)++;
}
static int json_string(const char **p, char *out, size_t n) {
    space(p);
    if (*(*p)++ != '"')
        return -1;
    size_t i = 0;
    while (**p && **p != '"') {
        if (**p == '\\' || i + 1 >= n)
            return -1;
        out[i++] = *(*p)++;
    }
    if (**p != '"')
        return -1;
    (*p)++;
    out[i] = 0;
    return 0;
}
static int legacy_state(HgVolume *v, bool *found) {
    uint8_t *data;
    size_t size;
    *found = false;
    if (read_file(v->dirfd, ".p601-hg.json", &data, &size, NULL, 65536) < 0)
        return errno == ENOENT ? 0 : -1;
    char *text = malloc(size + 1);
    if (!text) {
        free(data);
        return -1;
    }
    memcpy(text, data, size);
    text[size] = 0;
    free(data);
    const char *p = text;
    bool have_dirty = false, have_names = false;
    int rc = -1;
    if (memchr(text, 0, size))
        goto end;
    space(&p);
    if (*p++ != '{')
        goto end;
    for (;;) {
        char key[16];
        if (json_string(&p, key, sizeof(key)) < 0)
            goto end;
        space(&p);
        if (*p++ != ':')
            goto end;
        space(&p);
        if (!strcmp(key, "dirty") && !have_dirty) {
            if (!strncmp(p, "true", 4)) {
                v->dirty = true;
                p += 4;
            } else if (!strncmp(p, "false", 5)) {
                v->dirty = false;
                p += 5;
            } else
                goto end;
            have_dirty = true;
        } else if (!strcmp(key, "names") && !have_names) {
            if (*p++ != '{')
                goto end;
            space(&p);
            if (*p != '}')
                for (;;) {
                    HgFile f = {0};
                    char upper[13];
                    if (json_string(&p, f.name, sizeof(f.name)) < 0)
                        goto end;
                    space(&p);
                    if (*p++ != ':')
                        goto end;
                    if (json_string(&p, f.host, sizeof(f.host)) < 0 || !hg_name(f.name, upper) ||
                        strcmp(upper, f.name) || !hg_name(f.host, upper) || strcmp(upper, f.name) ||
                        hg_find(&v->names, f.name) || hg_file_copy(&v->names, &f) < 0)
                        goto end;
                    space(&p);
                    if (*p != ',')
                        break;
                    p++;
                }
            if (*p++ != '}')
                goto end;
            have_names = true;
        } else
            goto end;
        space(&p);
        if (*p != ',')
            break;
        p++;
    }
    if (*p++ != '}' || !have_dirty || !have_names)
        goto end;
    space(&p);
    if (*p)
        goto end;
    *found = true;
    rc = 0;
end:
    free(text);
    if (rc)
        hg_error("invalid legacy HG journal; preserving image");
    return rc;
}
static int conflict(HgVolume *v, const HgFile *file) {
    if (!file)
        return 0;
    if (mkdirat(v->dirfd, ".p601-hg-conflicts", 0700) < 0 && errno != EEXIST)
        return -1;
    int fd =
        openat(v->dirfd, ".p601-hg-conflicts", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0)
        return -1;
    char leaf[13];
    int parent = open_parent(fd, file->name, true, leaf);
    close(fd);
    if (parent < 0)
        return -1;
    fd = parent;
    /* Reusing an identical backup makes retries/crash replay idempotent.
       The hash chooses a name; byte comparison also handles collisions. */
    uint64_t hash = UINT64_C(14695981039346656037);
    for (uint32_t i = 0; i < file->size; i++)
        hash = (hash ^ file->data[i]) * UINT64_C(1099511628211);
    char name[80];
    int rc = -1;
    bool created = false;
    for (unsigned seq = 0; seq < 100; seq++) {
        snprintf(name, sizeof(name), "%s.guest-%016llx-%u-%u", leaf, (unsigned long long)hash,
                 file->size, seq);
        uint8_t *data = NULL;
        size_t size;
        if (!read_file(fd, name, &data, &size, NULL, v->size)) {
            bool same = size == file->size && (!size || !memcmp(data, file->data, size));
            free(data);
            if (same) {
                rc = 0;
                break;
            }
        } else if (errno == ENOENT) {
            rc = atomic_file(fd, name, file->data, file->size);
            created = !rc;
            break;
        } else
            break;
    }
    if (!rc)
        rc = fsync(v->dirfd);
    close(fd);
    if (!rc && created)
        fprintf(stderr,
                "HG conflict: host wins for %s; guest copy preserved in "
                ".p601-hg-conflicts/%.*s%s\n",
                file->name,
                (int)(strrchr(file->name, '/') ? strrchr(file->name, '/') - file->name + 1 : 0),
                file->name, name);
    return rc;
}
static bool files_same(const HgFiles *a, const HgFiles *b) {
    if (a->n != b->n)
        return false;
    for (unsigned i = 0; i < a->n; i++) {
        const HgFile *f = hg_find(b, a->v[i].name);
        if (!hg_same(&a->v[i], f) || strcmp(a->v[i].host, f->host))
            return false;
    }
    return true;
}
/* Before changing the host tree, persist its complete snapshot. On replay,
   entries already matching the desired image are treated as our own exports;
   partial directory/type changes are completed, while other host edits merge. */
static int save_export(HgVolume *v, const HgFiles *host) {
    size_t size = 16;
    for (unsigned i = 0; i < host->n; i++)
        size += 12 + strlen(host->v[i].name) + strlen(host->v[i].host) + host->v[i].size;
    uint8_t *data = calloc(1, size);
    if (!data)
        return -1;
    memcpy(data, "P601HGX1", 8);
    hg_p16(data + 8, host->n);
    size_t at = 16;
    for (unsigned i = 0; i < host->n; i++) {
        const HgFile *f = &host->v[i];
        unsigned a = (unsigned)strlen(f->name), b = (unsigned)strlen(f->host);
        hg_p16(data + at, a);
        hg_p16(data + at + 2, b);
        hg_p32(data + at + 4, f->size);
        data[at + 8] = f->attr;
        memcpy(data + at + 12, f->name, a);
        memcpy(data + at + 12 + a, f->host, b);
        if (f->size)
            memcpy(data + at + 12 + a + b, f->data, f->size);
        at += 12 + a + b + f->size;
    }
    int rc = atomic_file(v->dirfd, ".p601-hg.export", data, size);
    free(data);
    return rc;
}
static int replay_host(HgVolume *v, const HgFiles *host, const HgFiles *guest, HgFiles *effective) {
    if (!v->dirty || !memcmp(v->image, v->base, v->size))
        return 1;
    uint8_t *data;
    size_t size;
    if (read_file(v->dirfd, ".p601-hg.export", &data, &size, NULL,
                  v->size + 16 + HG_MAX_FILES * (12 + 2 * HG_PATH_MAX)) < 0)
        return errno == ENOENT ? 1 : -1;
    HgFiles before = {0};
    unsigned count = size >= 16 ? hg_u16(data + 8) : 0;
    size_t at = 16;
    int rc = -1;
    if (size < 16 || memcmp(data, "P601HGX1", 8) || count > HG_MAX_FILES)
        goto end;
    for (unsigned i = 0; i < count; i++) {
        if (at > size || size - at < 12)
            goto end;
        unsigned a = hg_u16(data + at), b = hg_u16(data + at + 2);
        HgFile f = {0};
        f.size = hg_u32(data + at + 4);
        f.attr = data[at + 8];
        if (!a || !b || a >= HG_PATH_MAX || b >= HG_PATH_MAX || (f.attr & 16 && f.size) ||
            f.size > v->size || (uint64_t)a + b + f.size > size - at - 12 ||
            memchr(data + at + 12, 0, a + b))
            goto end;
        memcpy(f.name, data + at + 12, a);
        memcpy(f.host, data + at + 12 + a, b);
        f.data = data + at + 12 + a + b;
        char normalized[HG_PATH_MAX];
        if (!hg_path(f.name, normalized) || strcmp(f.name, normalized) ||
            !hg_path(f.host, normalized) || strcmp(f.name, normalized) ||
            hg_find(&before, f.name) || hg_file_copy(&before, &f) < 0)
            goto end;
        at += 12 + a + b + f.size;
    }
    if (at != size)
        goto end;
    for (unsigned i = 0; i < host->n; i++) {
        const HgFile *h = &host->v[i], *old = hg_find(&before, h->name);
        if (hg_same(h, hg_find(guest, h->name))) {
            if (old) {
                HgFile f = *old;
                strcpy(f.host, h->host);
                if (hg_file_copy(effective, &f) < 0)
                    goto end;
            }
        } else if (hg_file_copy(effective, h) < 0)
            goto end;
    }
    for (unsigned i = 0; i < before.n; i++) {
        const HgFile *old = &before.v[i];
        if (!hg_find(host, old->name) && !hg_find(guest, old->name) &&
            hg_file_copy(effective, old) < 0)
            goto end;
    }
    /* An unrelated host edit inside a partly exported new directory keeps
       its actual ancestors. Do not reconstruct a file above a live child. */
    for (unsigned i = 0; i < effective->n; i++) {
        char path[HG_PATH_MAX];
        strcpy(path, effective->v[i].name);
        char *slash = strrchr(path, '/');
        while (slash) {
            *slash = 0;
            HgFile *parent = hg_find(effective, path);
            if (!parent || !(parent->attr & 16)) {
                const HgFile *actual = hg_find(host, path);
                if (!actual || !(actual->attr & 16))
                    goto end;
                if (parent) {
                    free(parent->data);
                    free(parent->chain);
                    *parent = *actual;
                    parent->data = NULL;
                    parent->chain = NULL;
                } else if (hg_file_copy(effective, actual) < 0)
                    goto end;
            }
            slash = strrchr(path, '/');
        }
    }
    rc = 0;
end:
    free(data);
    hg_files_free(&before);
    if (rc < 0)
        hg_error("invalid export journal; preserving pending image/host data");
    return rc;
}
static int export_files(HgVolume *v, const HgFiles *wanted, const HgFiles *host) {
    /* Recheck the complete tree before any export. Concurrent edits retry. */
    HgFiles check = {0};
    if (scan(v, &check) < 0)
        return -1;
    bool same = files_same(&check, host);
    hg_files_free(&check);
    if (!same) {
        errno = EAGAIN;
        return -1;
    }
    /* Remove only recorded entries, deepest first. Unknown/hidden host files
       are never recursively deleted just because their parent was removed. */
    for (unsigned i = host->n; i > 0; i--) {
        const HgFile *h = &host->v[i - 1], *f = hg_find(wanted, h->name);
        if (f && !((f->attr ^ h->attr) & 16))
            continue;
        char leaf[13];
        int fd = open_parent(v->dirfd, h->host, false, leaf);
        if (fd < 0)
            return -1;
        int rc = unlinkat(fd, leaf, (h->attr & 16) ? AT_REMOVEDIR : 0);
        if (rc < 0 && errno == ENOENT)
            rc = 0;
        if (!rc)
            rc = fsync(fd);
        close(fd);
        if (rc < 0)
            return -1;
    }
    /* The sorted desired tree creates parents before children. */
    for (unsigned i = 0; i < wanted->n; i++) {
        const HgFile *f = &wanted->v[i], *h = hg_find(host, f->name);
        if (hg_same(f, h))
            continue;
        char leaf[13];
        int fd = open_parent(v->dirfd, f->host, false, leaf);
        if (fd < 0)
            return -1;
        int rc;
        if (f->attr & 16) {
            rc = mkdirat(fd, leaf, 0700);
            if (rc < 0 && errno == EEXIST) {
                int child = openat(fd, leaf, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
                rc = child < 0 ? -1 : 0;
                if (child >= 0)
                    close(child);
            }
            if (!rc)
                rc = fsync(fd);
        } else
            rc = atomic_file(fd, leaf, f->data, f->size);
        close(fd);
        if (rc < 0)
            return -1;
    }
    return fsync(v->dirfd);
}
static bool in_tree(const char *name, const char *root) {
    size_t n = strlen(root);
    return !*root || (!strncmp(name, root, n) && (name[n] == 0 || name[n] == '/'));
}
static bool tree_changed(const HgFiles *a, const HgFiles *b, const char *root) {
    for (unsigned i = 0; i < a->n; i++)
        if (in_tree(a->v[i].name, root) && !hg_same(&a->v[i], hg_find(b, a->v[i].name)))
            return true;
    for (unsigned i = 0; i < b->n; i++)
        if (in_tree(b->v[i].name, root) && !hg_find(a, b->v[i].name))
            return true;
    return false;
}
static int merge_tree(const HgFiles *host, const HgFiles *guest, const HgFiles *base,
                      const char *root, HgFiles *wanted, const HgFile **conflicts,
                      unsigned *nconflicts) {
    const HgFile *h = hg_find(host, root), *g = hg_find(guest, root);
    if (*root && !(h && g && (h->attr & 16) && (g->attr & 16))) {
        bool hc = tree_changed(host, base, root);
        const HgFiles *chosen = hc ? host : guest;
        for (unsigned i = 0; i < chosen->n; i++) {
            HgFile f = chosen->v[i];
            const HgFile *actual = hg_find(host, f.name);
            if (!hc && actual)
                strcpy(f.host, actual->host);
            if (in_tree(f.name, root) && hg_file_copy(wanted, &f) < 0)
                return -1;
        }
        if (hc)
            for (unsigned i = 0; i < guest->n; i++) {
                const HgFile *f = &guest->v[i];
                if (in_tree(f->name, root) && !(f->attr & 16) &&
                    !hg_same(f, hg_find(base, f->name)) && !hg_same(f, hg_find(host, f->name)))
                    conflicts[(*nconflicts)++] = f;
            }
        return 0;
    }
    if (*root) {
        HgFile dir = *g;
        strcpy(dir.host, h->host);
        if (hg_file_copy(wanted, &dir) < 0)
            return -1;
    }
    /* Union of immediate children only: type/deletion conflicts choose an
       entire subtree, while two surviving directories merge independently. */
    HgFiles children = {0};
    const HgFiles *sets[] = {host, guest, base};
    size_t n = strlen(root);
    int rc = -1;
    for (unsigned set = 0; set < 3; set++)
        for (unsigned i = 0; i < sets[set]->n; i++) {
            const HgFile *f = &sets[set]->v[i];
            if (!in_tree(f->name, root) || !strcmp(f->name, root))
                continue;
            const char *child = f->name + n + (n ? 1 : 0);
            if (strchr(child, '/') || hg_find(&children, f->name))
                continue;
            HgFile name = {0};
            strcpy(name.name, f->name);
            if (hg_file_copy(&children, &name) < 0)
                goto end;
        }
    for (unsigned i = 0; i < children.n; i++)
        if (merge_tree(host, guest, base, children.v[i].name, wanted, conflicts, nconflicts) < 0)
            goto end;
    rc = 0;
end:
    hg_files_free(&children);
    return rc;
}
static int resolve_host_paths(HgFiles *files) {
    if (files->n > 1)
        qsort(files->v, files->n, sizeof(*files->v), file_compare);
    for (unsigned i = 0; i < files->n; i++) {
        HgFile *f = &files->v[i];
        const char *slash = strrchr(f->name, '/');
        if (!slash)
            continue;
        char parent[HG_PATH_MAX], host[HG_PATH_MAX];
        memcpy(parent, f->name, (size_t)(slash - f->name));
        parent[slash - f->name] = 0;
        const HgFile *p = hg_find(files, parent);
        const char *leaf = strrchr(f->host, '/');
        if (!p || !(p->attr & 16) || join_path(host, p->host, leaf ? leaf + 1 : f->host) < 0)
            return hg_error("missing merged parent: %s", f->name);
        strcpy(f->host, host);
    }
    return 0;
}
int hg_volume_sync(HgVolume *v) {
    if (!v->directory)
        return 0;
    if (v->nhost_writes) {
        errno = EAGAIN;
        return -1;
    }
    HgFiles guest = {0}, base = {0}, host = {0}, wanted = {0}, effective = {0};
    const HgFile *conflicts[HG_MAX_FILES];
    unsigned nconflicts = 0;
    uint8_t *candidate = NULL;
    int rc = -1;
    if (hg_fat_files(v->image, v->size, &guest) < 0 || hg_fat_files(v->base, v->size, &base) < 0 ||
        scan(v, &host) < 0)
        goto end;
    set_host_names(&guest, &v->names);
    set_host_names(&base, &v->names);
    int replay = replay_host(v, &host, &guest, &effective);
    if (replay < 0 || merge_tree(replay ? &host : &effective, &guest, &base, "", &wanted, conflicts,
                                 &nconflicts) < 0)
        goto end;
    set_host_names(&wanted, &host);
    if (resolve_host_paths(&wanted) < 0)
        goto end;
    candidate = malloc(v->size);
    if (!candidate)
        goto end;
    memcpy(candidate, v->image, v->size);
    if (hg_fat_update(candidate, v->size, &wanted) < 0)
        goto end;
    /* A full/invalid candidate must not create backups on every retry. */
    for (unsigned i = 0; i < nconflicts; i++)
        if (conflict(v, conflicts[i]) < 0)
            goto end;
    bool image_changed = memcmp(candidate, v->image, v->size) != 0;
    bool need_commit = v->dirty || image_changed || !files_same(&wanted, &host);
    if (need_commit) {
        if (!v->dirty && save_state(v, true, &v->names) < 0)
            goto end;
        v->dirty = true;
        if (image_changed) {
            if (atomic_file(v->dirfd, ".p601-hg.img", candidate, v->size) < 0)
                goto end;
            int fd = openat(v->dirfd, ".p601-hg.img", O_RDWR | O_NOFOLLOW | O_CLOEXEC);
            if (fd < 0)
                goto end;
            if (flock(fd, LOCK_EX | LOCK_NB) < 0) {
                close(fd);
                goto end;
            }
            if (v->fd >= 0)
                close(v->fd);
            v->fd = fd;
            memcpy(v->image, candidate, v->size);
        }
        if (save_export(v, &host) < 0 || export_files(v, &wanted, &host) < 0)
            goto end;
    }
    if (need_commit || !files_same(&wanted, &v->names)) {
        if (atomic_file(v->dirfd, ".p601-hg.base", v->image, v->size) < 0 ||
            save_state(v, false, &wanted) < 0)
            goto end;
        memcpy(v->base, v->image, v->size);
        hg_files_free(&v->names);
        v->names = wanted;
        memset(&wanted, 0, sizeof(wanted));
        if (image_changed)
            printf("HG directory updated: %u files; guest file clusters retained\n", v->names.n);
    }
    v->dirty = false;
    v->changed = false;
    if (unlinkat(v->dirfd, ".p601-hg.export", 0) < 0 && errno != ENOENT)
        goto end;
    if (fsync(v->dirfd) < 0)
        goto end;
    rc = 0;
end:
    free(candidate);
    hg_files_free(&guest);
    hg_files_free(&base);
    hg_files_free(&host);
    hg_files_free(&wanted);
    hg_files_free(&effective);
    return rc;
}
static int open_image(HgVolume *v, const char *path) {
    v->fd = v->directory ? openat(v->dirfd, ".p601-hg.img", O_RDWR | O_NOFOLLOW | O_CLOEXEC)
                         : open(path, (v->readonly ? O_RDONLY : O_RDWR) | O_NOFOLLOW | O_CLOEXEC);
    if (v->fd < 0 || flock(v->fd, LOCK_EX | LOCK_NB) < 0)
        return -1;
    struct stat st;
    if (fstat(v->fd, &st) < 0 || !S_ISREG(st.st_mode) || st.st_size < 512 ||
        st.st_size > 65535 * 512LL)
        return -1;
    v->size = (size_t)st.st_size;
    v->image = malloc(v->size);
    if (!v->image || all_read(v->fd, v->image, v->size) < 0 ||
        hg_fat_info(v->image, v->size, &v->fat) < 0)
        return -1;
    return 0;
}
int hg_volume_open(HgVolume *v, const char *path, bool directory, unsigned sectors, bool readonly) {
    memset(v, 0, sizeof(*v));
    v->fd = v->dirfd = v->lockfd = v->watchfd = v->watch_id = -1;
    v->path = strdup(path);
    v->readonly = readonly;
    v->directory = directory;
    if (!v->path)
        goto fail;
    if (!directory) {
        if (open_image(v, path) < 0)
            goto fail;
        return 0;
    }
    v->dirfd = open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (v->dirfd < 0)
        goto fail;
    v->lockfd = openat(v->dirfd, ".p601-hg.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (v->lockfd < 0 || flock(v->lockfd, LOCK_EX | LOCK_NB) < 0) {
        hg_error("HG directory already in use");
        goto fail;
    }
#ifdef __linux__
    v->watchfd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (v->watchfd < 0)
        goto fail;
#endif
    struct stat st;
    bool exists = fstatat(v->dirfd, ".p601-hg.img", &st, AT_SYMLINK_NOFOLLOW) == 0;
    if (exists) {
        if (open_image(v, path) < 0)
            goto fail;
        int state = load_state(v);
        if (state < 0)
            goto fail;
        if (!state) {
            size_t size;
            if (read_file(v->dirfd, ".p601-hg.base", &v->base, &size, NULL, v->size) < 0 ||
                size != v->size) {
                hg_error("missing/incomplete immutable HG base; preserving image");
                goto fail;
            }
        } else {
            bool found;
            if (legacy_state(v, &found) < 0 || !found) {
                hg_error("HG image has no journal; preserving image");
                goto fail;
            }
            HgFiles guest = {0}, host = {0};
            if (hg_fat_files(v->image, v->size, &guest) < 0 || scan(v, &host) < 0) {
                hg_files_free(&guest);
                hg_files_free(&host);
                goto fail;
            }
            set_host_names(&guest, &v->names);
            if (v->dirty && readonly) {
                hg_files_free(&guest);
                hg_files_free(&host);
                hg_error("recover pending legacy writes without --read-only");
                goto fail;
            }
            /* Legacy deletion tracking covers recorded names only. Preserve
               host additions that occurred while the Python server was down. */
            if (v->dirty) {
                for (unsigned i = 0; i < host.n; i++) {
                    if (!hg_find(&v->names, host.v[i].name) && !hg_find(&guest, host.v[i].name) &&
                        hg_file_copy(&guest, &host.v[i]) < 0) {
                        hg_files_free(&guest);
                        hg_files_free(&host);
                        goto fail;
                    }
                }
            }
            if (v->dirty &&
                (resolve_host_paths(&guest) < 0 || export_files(v, &guest, &host) < 0)) {
                hg_files_free(&guest);
                hg_files_free(&host);
                goto fail;
            }
            hg_files_free(&guest);
            hg_files_free(&host);
            v->base = malloc(v->size);
            if (!v->base)
                goto fail;
            memcpy(v->base, v->image, v->size);
            if (atomic_file(v->dirfd, ".p601-hg.base", v->base, v->size) < 0 ||
                save_state(v, false, &v->names) < 0)
                goto fail;
            v->dirty = false;
            printf("Migrated Python HG cache to the native journal\n");
        }
        if (v->fat.sectors != sectors) {
            hg_error("existing HG geometry differs from --blocks");
            goto fail;
        }
    } else {
        v->image = hg_fat_blank(sectors, &v->size);
        if (!v->image || hg_fat_info(v->image, v->size, &v->fat) < 0)
            goto fail;
        v->base = malloc(v->size);
        if (!v->base)
            goto fail;
        memcpy(v->base, v->image, v->size);
        if (atomic_file(v->dirfd, ".p601-hg.img", v->image, v->size) < 0 ||
            atomic_file(v->dirfd, ".p601-hg.base", v->base, v->size) < 0 ||
            save_state(v, false, &v->names) < 0)
            goto fail;
        v->fd = openat(v->dirfd, ".p601-hg.img", O_RDWR | O_NOFOLLOW | O_CLOEXEC);
        if (v->fd < 0 || flock(v->fd, LOCK_EX | LOCK_NB) < 0)
            goto fail;
    }
    if (v->dirty && readonly) {
        hg_error("recover pending writes without --read-only");
        goto fail;
    }
    if (hg_volume_sync(v) < 0)
        goto fail;
    if (save_state(v, false, &v->names) < 0)
        goto fail;
    v->scan_ms = hg_millis();
    return 0;
fail:
    hg_volume_close(v);
    return -1;
}
int hg_volume_write(HgVolume *v, unsigned block, const uint8_t *data, unsigned n) {
    if (v->readonly)
        return HG_READ_ONLY;
    if (!n || n > 512 || (uint64_t)block * 512 + n > (uint64_t)v->fat.sectors * 512)
        return HG_RANGE;
    if (v->directory && !v->dirty && save_state(v, true, &v->names) < 0)
        return HG_IO;
    v->dirty = true;
    if (all_write(v->fd, data, n, (off_t)block * 512) < 0 || fsync(v->fd) < 0)
        return HG_IO;
    memcpy(v->image + (size_t)block * 512, data, n);
    return HG_OK;
}
#ifdef __linux__
static void forget_watch(HgVolume *v, unsigned at) {
    char prefix[HG_PATH_MAX] = "";
    if (*v->watches[at].path && !hg_path(v->watches[at].path, prefix))
        return;
    for (unsigned i = 0; i < v->nhost_writes;)
        if (in_tree(v->host_writes[i], prefix)) {
            v->nhost_writes--;
            memcpy(v->host_writes[i], v->host_writes[v->nhost_writes], HG_PATH_MAX);
        } else
            i++;
    v->nwatches--;
    v->watches[at] = v->watches[v->nwatches];
}
#endif
int hg_volume_events(HgVolume *v) {
    if (!v->directory)
        return 0;
#ifdef __linux__
    union {
        char bytes[16384];
        struct inotify_event align;
    } buffer;
    ssize_t n;
    while ((n = read(v->watchfd, buffer.bytes, sizeof(buffer.bytes))) > 0) {
        for (size_t at = 0; at < (size_t)n;) {
            struct inotify_event *e = (void *)(buffer.bytes + at);
            at += sizeof(*e) + e->len;
            if (e->wd == v->watch_id &&
                (e->mask & (IN_DELETE_SELF | IN_MOVE_SELF | IN_IGNORED | IN_UNMOUNT)))
                return hg_error("HG root directory moved/unmounted; stopping");
            unsigned watch;
            for (watch = 0; watch < v->nwatches; watch++)
                if (v->watches[watch].id == e->wd)
                    break;
            if (e->mask & IN_Q_OVERFLOW) {
                v->nhost_writes = 0;
                fprintf(stderr, "HG inotify overflow: rescanning the complete tree\n");
            }
            if (watch < v->nwatches && e->len && e->name[0] != '.') {
                char component[13], name[HG_PATH_MAX];
                if (hg_name(e->name, component) &&
                    !join_path(name, v->watches[watch].path, component)) {
                    /* Pending writers are keyed by normalized complete path. */
                    char upper[HG_PATH_MAX];
                    if (!hg_path(name, upper))
                        return -1;
                    unsigned i;
                    for (i = 0; i < v->nhost_writes; i++)
                        if (!strcmp(v->host_writes[i], upper))
                            break;
                    if ((e->mask & IN_MODIFY) && !(e->mask & IN_ISDIR) && i == v->nhost_writes) {
                        if (i == HG_MAX_FILES)
                            return hg_error("too many open HG writers");
                        strcpy(v->host_writes[v->nhost_writes++], upper);
                    }
                    if ((e->mask & (IN_CLOSE_WRITE | IN_DELETE | IN_MOVED_FROM)) &&
                        i < v->nhost_writes) {
                        v->nhost_writes--;
                        memcpy(v->host_writes[i], v->host_writes[v->nhost_writes], HG_PATH_MAX);
                    }
                }
            }
            if ((e->mask & (IN_Q_OVERFLOW | IN_MOVE_SELF | IN_DELETE_SELF)) ||
                (e->len && e->name[0] != '.')) {
                v->changed = true;
                v->event_ms = hg_millis();
            }
            if (watch < v->nwatches && (e->mask & IN_IGNORED))
                forget_watch(v, watch);
        }
    }
    if (n < 0 && errno != EAGAIN && errno != EINTR)
        return -1;
    /* Successful scans mark all reachable directories. Retire watches on
       directories removed/moved outside the mirrored tree. */
    for (unsigned i = 0; i < v->nwatches;)
        if (!v->watches[i].seen) {
            inotify_rm_watch(v->watchfd, v->watches[i].id);
            forget_watch(v, i);
        } else
            i++;
#endif
    if (hg_millis() - v->scan_ms >= 2000) {
        v->changed = true;
        v->scan_ms = hg_millis();
    }
    return 0;
}
void hg_volume_close(HgVolume *v) {
    if (v->watchfd >= 0)
        close(v->watchfd);
    if (v->fd >= 0)
        close(v->fd);
    if (v->lockfd >= 0)
        close(v->lockfd);
    if (v->dirfd >= 0)
        close(v->dirfd);
    hg_files_free(&v->names);
    free(v->image);
    free(v->base);
    free(v->path);
    free(v->watches);
    memset(v, 0, sizeof(*v));
    v->fd = v->dirfd = v->lockfd = v->watchfd = v->watch_id = -1;
}
int hg_create_image(const char *path, unsigned sectors) {
    size_t size;
    uint8_t *data = hg_fat_blank(sectors, &size);
    if (!data)
        return -1;
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600), rc = -1;
    if (fd >= 0) {
        rc = all_write(fd, data, size, 0);
        if (!rc)
            rc = fsync(fd);
        if (close(fd) < 0)
            rc = -1;
    }
    free(data);
    return rc;
}
