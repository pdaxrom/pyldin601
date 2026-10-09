#define _POSIX_C_SOURCE 200809L
#include "hg.h"
#include <stdio.h>
#include <string.h>

int hg_time(unsigned hz, const struct timespec *given, uint8_t out[6]) {
    struct timespec now;
    if (!given) {
        clock_gettime(CLOCK_REALTIME, &now);
        given = &now;
    }
    struct tm tm;
    if (!localtime_r(&given->tv_sec, &tm))
        return -1;
    int age = tm.tm_year + 1900 - 1972;
    if ((hz != 50 && hz != 60) || age < 0 || age > 63)
        return -1;
    unsigned date =
        (unsigned)(age >> 5) << 14 | (tm.tm_mon + 1) << 10 | tm.tm_mday << 5 | (age & 31);
    uint32_t ticks = (uint32_t)(tm.tm_hour * 3600 + tm.tm_min * 60 + tm.tm_sec) * hz;
    ticks += (uint32_t)((uint64_t)given->tv_nsec * hz / 1000000000);
    hg_p16(out, date);
    hg_p16(out + 2, ticks >> 16);
    hg_p16(out + 4, ticks & 65535);
    return 0;
}
static unsigned checksum(const uint8_t *p, unsigned n) {
    unsigned sum = 0;
    while (n--)
        sum += *p++;
    return sum & 65535;
}
static int status(HgLink *l, unsigned version, unsigned value) {
    if (version == 2) {
        if (l->select(l->ctx, false) < 0 || l->phase(l->ctx, 0x9a, 0x9e) < 0 ||
            l->select(l->ctx, true) < 0)
            return -1;
    } else
        hg_delay(500);
    uint8_t b = (uint8_t)value;
    return l->exchange(l->ctx, &b, NULL, 1, false);
}
static int flow(HgLink *l, const uint8_t *out, uint8_t *in, unsigned n) {
    if (l->select(l->ctx, false) < 0)
        return -1;
    for (unsigned at = 0; at < n; at += 32) {
        unsigned len = n - at;
        if (len > 32)
            len = 32;
        if (l->phase(l->ctx, out ? 0x8b : 0x8d, 0x9f) < 0 || l->select(l->ctx, true) < 0 ||
            l->exchange(l->ctx, out ? out + at : NULL, in ? in + at : NULL, len, true) < 0 ||
            l->select(l->ctx, false) < 0)
            return -1;
    }
    return 0;
}
int hg_serve(HgLink *l, HgVolume *v, bool stats) {
    uint64_t started = hg_millis();
    uint8_t h[10], p[514];
    unsigned version = 1, op = 0, block = 0, count = 0, outcome = HG_OK;
    int rc = -1, wrote = 0;
    if (l->select(l->ctx, true) < 0)
        goto transport;
    hg_delay(2000);
    if (l->exchange(l->ctx, NULL, h, 10, true) < 0)
        goto transport;
    if (h[2] == 2)
        version = 2;
    unsigned xor = 0;
    for (unsigned i = 0; i < 9; i++)
        xor ^= h[i];
    op = h[3];
    block = hg_u16(h + 5);
    count = hg_u16(h + 7);
    if (memcmp(h, "HG", 2) || (h[2] != 1 && h[2] != 2) || h[4] || xor != h[9] || op < 1 || op > 3 ||
        !count || count > 512 || (op == 3 && (count != 6 || (block != 50 && block != 60)))) {
        outcome = HG_PROTOCOL;
        goto error_status;
    }
    if (op == 3) {
        if (hg_time(block, NULL, p) < 0) {
            outcome = HG_RANGE;
            goto error_status;
        }
    } else if ((uint64_t)block * 512 + count > (uint64_t)v->fat.sectors * 512) {
        outcome = HG_RANGE;
        goto error_status;
    } else if (op == 1)
        memcpy(p, v->image + (size_t)block * 512, count);
    else if (v->readonly) {
        outcome = HG_READ_ONLY;
        goto error_status;
    }
    if (status(l, version, HG_OK) < 0)
        goto transport;
    if (op != 2)
        hg_p16(p + count, checksum(p, count));
    if (version == 2) {
        if (flow(l, op == 2 ? NULL : p, op == 2 ? p : NULL, count + 2) < 0)
            goto transport;
    } else {
        hg_delay(500);
        if (l->exchange(l->ctx, op == 2 ? NULL : p, op == 2 ? p : NULL, count + 2, false) < 0)
            goto transport;
    }
    if (op == 2) {
        outcome = checksum(p, count) == hg_u16(p + count)
                      ? (unsigned)hg_volume_write(v, block, p, count)
                      : HG_CHECKSUM;
        if (status(l, version, outcome) < 0)
            goto transport;
        wrote = outcome == HG_OK;
    }
    goto complete;
error_status:
    if (status(l, version, outcome) < 0)
        goto transport;
complete:
    if (version == 2) {
        if (l->select(l->ctx, false) < 0 || l->phase(l->ctx, 0x98, 0x9e) < 0 ||
            l->select(l->ctx, true) < 0 || l->phase(l->ctx, 0, 0x80) < 0)
            goto transport;
    }
    hg_delay(500);
    rc = wrote;
    goto end;
transport:
    outcome = HG_IO;
end:
    if (l->select(l->ctx, false) < 0)
        rc = -1;
    if (stats) {
        static uint64_t requests[3][4], bytes[3][4], millis[3][4];
        unsigned key = op < 4 ? op : 0;
        uint64_t elapsed = hg_millis() - started;
        requests[version][key]++;
        bytes[version][key] += count;
        millis[version][key] += elapsed;
        const char *names[] = {"INVALID", "READ", "WRITE", "TIME"};
        printf("HG v%u %s LBA=%u bytes=%u status=%u %llums; average=%.2fKiB/s (%llu requests)\n",
               version, names[key], block, count, outcome, (unsigned long long)elapsed,
               millis[version][key]
                   ? (double)bytes[version][key] * 1000 / millis[version][key] / 1024
                   : 0,
               (unsigned long long)requests[version][key]);
    }
    return rc;
}
