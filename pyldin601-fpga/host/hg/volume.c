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
/* A file is imported only if its inode, size and timestamps survived the read. */
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
static int scan(HgVolume *v, HgFiles *files) {
    int fd = openat(v->dirfd, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0)
        return -1;
    DIR *dir = fdopendir(fd);
    if (!dir) {
        close(fd);
        return -1;
    }
    HgFiles result = {0};
    struct dirent *de;
    int rc = -1;
    while ((de = readdir(dir))) {
        if (de->d_name[0] == '.')
            continue;
        struct stat st;
        if (fstatat(v->dirfd, de->d_name, &st, AT_SYMLINK_NOFOLLOW) < 0)
            goto end;
        if (S_ISLNK(st.st_mode)) {
            hg_error("symlink is not an HG file: %s", de->d_name);
            goto end;
        }
        if (!S_ISREG(st.st_mode))
            continue;
        HgFile f = {0};
        if (!hg_name(de->d_name, f.name)) {
            hg_error("skipping non-DOS 8.3 file: %s", de->d_name);
            continue;
        }
        if (hg_find(&result, f.name)) {
            hg_error("case-insensitive duplicate: %s", de->d_name);
            goto end;
        }
        strcpy(f.host, de->d_name);
        size_t size;
        if (read_file(v->dirfd, de->d_name, &f.data, &size, &st, v->size) < 0)
            goto end;
        f.size = (uint32_t)size;
        f.attr = 0x20;
        struct tm tm;
        localtime_r(&st.st_mtime, &tm);
        int year = tm.tm_year + 1900;
        if (year < 1980)
            year = 1980;
        if (year > 2107)
            year = 2107;
        f.date = (uint16_t)((year - 1980) << 9 | (tm.tm_mon + 1) << 5 | tm.tm_mday);
        f.time = (uint16_t)(tm.tm_hour << 11 | tm.tm_min << 5 | tm.tm_sec / 2);
        if (hg_file_copy(&result, &f) < 0) {
            free(f.data);
            goto end;
        }
        free(f.data);
    }
    qsort(result.v, result.n, sizeof(*result.v), file_compare);
    *files = result;
    memset(&result, 0, sizeof(result));
    rc = 0;
end:
    closedir(dir);
    hg_files_free(&result);
    return rc;
}
static void set_host_names(HgFiles *files, const HgFiles *names) {
    for (unsigned i = 0; i < files->n; i++) {
        const HgFile *f = hg_find(names, files->v[i].name);
        if (f)
            strcpy(files->v[i].host, f->host);
    }
}
/* The small journal and immutable base image precede any durable guest write. */
static int save_state(HgVolume *v, bool dirty, const HgFiles *names) {
    size_t n = 16 + names->n * 26;
    uint8_t *state = calloc(1, n);
    if (!state)
        return -1;
    memcpy(state, "P601HG\1", 7);
    state[8] = dirty;
    hg_p16(state + 10, v->fat.sectors);
    hg_p16(state + 12, names->n);
    for (unsigned i = 0; i < names->n; i++) {
        memcpy(state + 16 + i * 26, names->v[i].name, 13);
        memcpy(state + 29 + i * 26, names->v[i].host, 13);
    }
    int rc = atomic_file(v->dirfd, ".p601-hg.state", state, n);
    free(state);
    return rc;
}
static int load_state(HgVolume *v) {
    uint8_t *data;
    size_t size;
    if (read_file(v->dirfd, ".p601-hg.state", &data, &size, NULL, 16 + HG_MAX_FILES * 26) < 0)
        return errno == ENOENT ? 1 : -1;
    unsigned n = size >= 16 ? hg_u16(data + 12) : 0;
    if (size != 16 + n * 26 || memcmp(data, "P601HG\1", 8) || data[8] > 1 || n > HG_MAX_FILES ||
        hg_u16(data + 10) != v->fat.sectors) {
        free(data);
        return hg_error("invalid HG journal");
    }
    for (unsigned i = 0; i < n; i++) {
        HgFile f = {0};
        char normalized[13];
        memcpy(f.name, data + 16 + i * 26, 13);
        memcpy(f.host, data + 29 + i * 26, 13);
        if (!memchr(f.name, 0, 13) || !memchr(f.host, 0, 13) || !hg_name(f.name, normalized) ||
            strcmp(normalized, f.name) || !hg_name(f.host, normalized) ||
            strcmp(normalized, f.name) || hg_find(&v->names, f.name) ||
            hg_file_copy(&v->names, &f) < 0) {
            free(data);
            return hg_error("invalid HG journal filename");
        }
    }
    v->dirty = data[8];
    free(data);
    return 0;
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
    /* Reusing an identical backup makes retries/crash replay idempotent.
       The hash chooses a name; byte comparison also handles collisions. */
    uint64_t hash = UINT64_C(14695981039346656037);
    for (uint32_t i = 0; i < file->size; i++)
        hash = (hash ^ file->data[i]) * UINT64_C(1099511628211);
    char name[80];
    int rc = -1;
    bool created = false;
    for (unsigned seq = 0; seq < 100; seq++) {
        snprintf(name, sizeof(name), "%s.guest-%016llx-%u-%u", file->name, (unsigned long long)hash,
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
                "HG conflict: host wins for %s; guest copy preserved in .p601-hg-conflicts/%s\n",
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
static int export_files(HgVolume *v, const HgFiles *wanted, const HgFiles *host) {
    /* Recheck the complete snapshot before any export. Concurrent edits retry. */
    HgFiles check = {0};
    if (scan(v, &check) < 0)
        return -1;
    bool same = files_same(&check, host);
    hg_files_free(&check);
    if (!same) {
        errno = EAGAIN;
        return -1;
    }
    for (unsigned i = 0; i < wanted->n; i++) {
        const HgFile *f = &wanted->v[i], *h = hg_find(host, f->name);
        if (hg_same(f, h))
            continue;
        if (atomic_file(v->dirfd, f->host, f->data, f->size) < 0)
            return -1;
    }
    for (unsigned i = 0; i < host->n; i++)
        if (!hg_find(wanted, host->v[i].name)) {
            if (unlinkat(v->dirfd, host->v[i].host, 0) < 0 && errno != ENOENT)
                return -1;
        }
    return fsync(v->dirfd);
}
int hg_volume_sync(HgVolume *v) {
    if (!v->directory)
        return 0;
    if (v->nhost_writes) {
        errno = EAGAIN;
        return -1;
    }
    HgFiles guest = {0}, base = {0}, host = {0}, wanted = {0};
    const HgFile *conflicts[HG_MAX_FILES];
    unsigned nconflicts = 0;
    uint8_t *candidate = NULL;
    int rc = -1;
    if (hg_fat_files(v->image, v->size, &guest) < 0 || hg_fat_files(v->base, v->size, &base) < 0 ||
        scan(v, &host) < 0)
        goto end;
    set_host_names(&guest, &v->names);
    set_host_names(&base, &v->names);
    /* Host deltas win only for the files actually edited on the host. Other
       guest deltas, including deletions, survive. Conflicting guest data is kept. */
    for (unsigned i = 0; i < host.n; i++) {
        HgFile *h = &host.v[i], *b = hg_find(&base, h->name), *g = hg_find(&guest, h->name);
        bool hc = !hg_same(h, b), gc = !hg_same(g, b);
        if (hc) {
            if (gc && g && !hg_same(h, g))
                conflicts[nconflicts++] = g;
            if (hg_file_copy(&wanted, h) < 0)
                goto end;
        } else if (g) {
            strcpy(g->host, h->host);
            if (hg_file_copy(&wanted, g) < 0)
                goto end;
        }
    }
    for (unsigned i = 0; i < guest.n; i++) {
        HgFile *g = &guest.v[i];
        if (hg_find(&host, g->name))
            continue;
        HgFile *b = hg_find(&base, g->name);
        if (b) {
            if (!hg_same(g, b))
                conflicts[nconflicts++] = g;
        } else if (hg_file_copy(&wanted, g) < 0)
            goto end;
    }
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
        if (export_files(v, &wanted, &host) < 0)
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
    rc = 0;
end:
    free(candidate);
    hg_files_free(&guest);
    hg_files_free(&base);
    hg_files_free(&host);
    hg_files_free(&wanted);
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
    v->watch_id =
        inotify_add_watch(v->watchfd, path,
                          IN_MODIFY | IN_CLOSE_WRITE | IN_MOVED_TO | IN_MOVED_FROM | IN_CREATE |
                              IN_DELETE | IN_ATTRIB | IN_DELETE_SELF | IN_MOVE_SELF);
    if (v->watch_id < 0)
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
            if (v->dirty && export_files(v, &guest, &host) < 0) {
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
            if (e->mask & (IN_DELETE_SELF | IN_MOVE_SELF | IN_IGNORED | IN_UNMOUNT))
                return hg_error("HG directory moved/unmounted; stopping");
            if (e->mask & IN_Q_OVERFLOW) {
                v->nhost_writes = 0;
                fprintf(stderr, "HG inotify overflow: rescanning the complete directory\n");
            }
            if (e->len && e->name[0] != '.') {
                char name[13];
                if (hg_name(e->name, name)) {
                    unsigned i;
                    for (i = 0; i < v->nhost_writes; i++)
                        if (!strcmp(v->host_writes[i], name))
                            break;
                    if ((e->mask & IN_MODIFY) && i == v->nhost_writes && i < HG_MAX_FILES)
                        strcpy(v->host_writes[v->nhost_writes++], name);
                    if ((e->mask & (IN_CLOSE_WRITE | IN_DELETE | IN_MOVED_FROM)) &&
                        i < v->nhost_writes) {
                        v->nhost_writes--;
                        if (i < v->nhost_writes)
                            memcpy(v->host_writes[i], v->host_writes[v->nhost_writes], 13);
                    }
                }
            }
            if ((e->mask & IN_Q_OVERFLOW) || (e->len && e->name[0] != '.')) {
                v->changed = true;
                v->event_ms = hg_millis();
            }
        }
    }
    if (n < 0 && errno != EAGAIN && errno != EINTR)
        return -1;
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
