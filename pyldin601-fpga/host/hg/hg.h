#ifndef P601_HG_H
#define P601_HG_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <time.h>

#define HG_MAX_SECTORS 32736
#define HG_MAX_FILES 512
enum { HG_OK, HG_PROTOCOL, HG_RANGE, HG_IO, HG_CHECKSUM, HG_READ_ONLY };

typedef struct {
    char name[13], host[13];
    uint8_t *data;
    uint32_t size;
    uint16_t date, time, *chain;
    unsigned nchain, slot;
    uint8_t attr;
} HgFile;
typedef struct {
    HgFile *v;
    unsigned n;
} HgFiles;
typedef struct {
    unsigned sectors, spc, clusters, reserved, fats, spf, entries;
    size_t fat, fat_size, root, payload;
} HgFat;
typedef struct {
    int fd, dirfd, lockfd, watchfd, watch_id;
    bool directory, readonly, dirty, changed;
    char *path;
    uint8_t *image, *base;
    size_t size;
    HgFat fat;
    HgFiles names;
    char host_writes[HG_MAX_FILES][13];
    unsigned nhost_writes;
    uint64_t event_ms, scan_ms;
} HgVolume;

uint16_t hg_u16(const uint8_t *p);
uint32_t hg_u32(const uint8_t *p);
void hg_p16(uint8_t *p, unsigned n);
void hg_p32(uint8_t *p, uint32_t n);
uint64_t hg_millis(void);
void hg_delay(unsigned usec);
int hg_error(const char *fmt, ...);
bool hg_name(const char *name, char out[13]);
void hg_files_free(HgFiles *files);
HgFile *hg_find(const HgFiles *files, const char *name);
bool hg_same(const HgFile *a, const HgFile *b);
int hg_file_copy(HgFiles *dst, const HgFile *src);
int hg_fat_info(const uint8_t *image, size_t size, HgFat *fat);
int hg_fat_files(const uint8_t *image, size_t size, HgFiles *files);
uint8_t *hg_fat_blank(unsigned sectors, size_t *size);
int hg_fat_update(uint8_t *image, size_t size, const HgFiles *wanted);

int hg_volume_open(HgVolume *v, const char *path, bool directory, unsigned sectors, bool readonly);
int hg_volume_write(HgVolume *v, unsigned block, const uint8_t *data, unsigned n);
int hg_volume_sync(HgVolume *v);
int hg_volume_events(HgVolume *v);
void hg_volume_close(HgVolume *v);
int hg_create_image(const char *path, unsigned sectors);

/* The dispatcher can use either FTDI or a deterministic test transport. */
typedef struct HgLink {
    void *ctx;
    int (*select)(void *, bool);
    int (*exchange)(void *, const uint8_t *, uint8_t *, unsigned, bool);
    int (*phase)(void *, unsigned, unsigned);
} HgLink;
int hg_time(unsigned hz, const struct timespec *now, uint8_t out[6]);
int hg_serve(HgLink *link, HgVolume *v, bool stats);
typedef struct HgMpsse HgMpsse;
int hg_mpsse_open(HgMpsse **m, unsigned clock, const char *serial, unsigned index, unsigned vid,
                  unsigned pid);
int hg_mpsse_jtag(HgMpsse *m, bool enabled);
int hg_mpsse_pending(HgMpsse *m);
HgLink hg_mpsse_link(HgMpsse *m);
void hg_mpsse_close(HgMpsse *m);
#endif
