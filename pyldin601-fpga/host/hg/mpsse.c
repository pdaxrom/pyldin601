#define _POSIX_C_SOURCE 200809L
#include "hg.h"
#include <errno.h>
#include <ftdi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct HgMpsse {
    struct ftdi_context *ftdi;
    uint8_t value, direction;
    bool opened, controlled;
};
static int checked(HgMpsse *m, int value, const char *operation) {
    return value < 0 ? hg_error("%s: %s", operation, ftdi_get_error_string(m->ftdi)) : value;
}
static int write_usb(HgMpsse *m, const uint8_t *p, unsigned n) {
    uint64_t deadline = hg_millis() + 5000;
    while (n) {
        int done = checked(m, ftdi_write_data(m->ftdi, p, (int)n), "FTDI write");
        if (done < 0)
            return -1;
        p += done;
        n -= (unsigned)done;
        if (n && hg_millis() > deadline)
            return hg_error("MPSSE USB write timeout");
        if (!done)
            hg_delay(1000);
    }
    return 0;
}
static int read_usb(HgMpsse *m, uint8_t *p, unsigned n) {
    uint64_t deadline = hg_millis() + 5000;
    while (n) {
        int done = checked(m, ftdi_read_data(m->ftdi, p, (int)n), "FTDI read");
        if (done < 0)
            return -1;
        p += done;
        n -= (unsigned)done;
        if (n && hg_millis() > deadline)
            return hg_error("MPSSE USB read timeout");
        if (!done)
            hg_delay(1000);
    }
    return 0;
}
static int set_low(HgMpsse *m) {
    uint8_t command[] = {0x80, m->value, m->direction};
    return write_usb(m, command, sizeof(command));
}
static int pins(HgMpsse *m) {
    uint8_t command[] = {0x81, 0x87}, result;
    if (write_usb(m, command, sizeof(command)) < 0 || read_usb(m, &result, 1) < 0)
        return -1;
    return result;
}
int hg_mpsse_jtag(HgMpsse *m, bool enabled) {
    m->controlled = true;
    m->value &= (uint8_t)~0x80;
    if (enabled)
        m->direction &= (uint8_t)~0x80;
    else
        m->direction |= 0x80;
    if (set_low(m) < 0)
        return -1;
    hg_delay(1000);
    int p = pins(m);
    if (p < 0)
        return -1;
    if (!!(p & 0x80) != enabled)
        return hg_error("JTAGENB readback failed");
    printf("JTAGENB %s readback verified%s\n", enabled ? "high" : "low",
           enabled ? "" : "; HG enabled");
    return 0;
}
static int select_link(void *ctx, bool selected) {
    HgMpsse *m = ctx;
    if (selected)
        m->value |= 8;
    else
        m->value &= (uint8_t)~8;
    return set_low(m);
}
static int exchange_link(void *ctx, const uint8_t *out, uint8_t *in, unsigned n, bool packet) {
    HgMpsse *m = ctx;
    if (!n || (packet && n > 32))
        return hg_error("invalid MPSSE packet length");
    uint8_t command[36], result[32];
    for (unsigned at = 0; at < n;) {
        unsigned len = packet ? n : 1;
        command[0] = 0x39;
        command[1] = (uint8_t)(len - 1);
        command[2] = 0;
        if (out)
            memcpy(command + 3, out + at, len);
        else
            memset(command + 3, 0, len);
        command[3 + len] = 0x87;
        if (write_usb(m, command, len + 4) < 0 || read_usb(m, result, len) < 0)
            return -1;
        if (in)
            memcpy(in + at, result, len);
        at += len;
    }
    return 0;
}
static int phase_link(void *ctx, unsigned value, unsigned mask) {
    uint64_t deadline = hg_millis() + 5000;
    for (;;) {
        uint8_t p;
        if (exchange_link(ctx, NULL, &p, 1, true) < 0)
            return -1;
        if (p != 0xff && (p & 0x40))
            return hg_error("HG FIFO overflow/underflow");
        if ((p & mask) == value)
            return 0;
        if (hg_millis() > deadline)
            return hg_error("HG FIFO credit/status timeout (phase=%02x)", p);
    }
}
int hg_mpsse_pending(HgMpsse *m) {
    int p = pins(m);
    return p < 0 ? -1 : !!(p & 4);
}
HgLink hg_mpsse_link(HgMpsse *m) {
    HgLink link = {m, select_link, exchange_link, phase_link};
    return link;
}
int hg_mpsse_open(HgMpsse **out, unsigned clock, const char *serial, unsigned index, unsigned vid,
                  unsigned pid) {
    if (clock < 100 || clock > 1000000)
        return hg_error("MPSSE clock must be 100..1000000 Hz");
    HgMpsse *m = calloc(1, sizeof(*m));
    if (!m)
        return -1;
    m->direction = 0x0b;
    m->ftdi = ftdi_new();
    if (!m->ftdi) {
        free(m);
        return -1;
    }
    if (checked(m, ftdi_set_interface(m->ftdi, INTERFACE_A), "FTDI interface A") < 0 ||
        checked(m, ftdi_usb_open_desc_index(m->ftdi, (int)vid, (int)pid, NULL, serial, index),
                "FTDI open") < 0)
        goto fail;
    m->opened = true;
    m->ftdi->usb_read_timeout = 100;
    m->ftdi->usb_write_timeout = 1000;
    if (checked(m, ftdi_usb_reset(m->ftdi), "FTDI reset") < 0 ||
        checked(m, ftdi_set_latency_timer(m->ftdi, 1), "FTDI latency") < 0 ||
        checked(m, ftdi_set_bitmode(m->ftdi, 0, BITMODE_RESET), "FTDI reset mode") < 0 ||
        checked(m, ftdi_set_bitmode(m->ftdi, m->direction, BITMODE_MPSSE), "FTDI MPSSE") < 0)
        goto fail;
    hg_delay(50000);
    if (checked(m, ftdi_tcioflush(m->ftdi), "FTDI flush") < 0)
        goto fail;
    uint8_t sync[] = {0xaa, 0x87}, reply[2];
    if (write_usb(m, sync, 2) < 0 || read_usb(m, reply, 2) < 0 || memcmp(reply, "\xfa\xaa", 2)) {
        hg_error("MPSSE sync failed");
        goto fail;
    }
    unsigned divisor = 6000000 / clock - 1;
    if (divisor > 65535)
        divisor = 65535;
    uint8_t command[] = {0x86, (uint8_t)divisor, (uint8_t)(divisor >> 8), 0x85, 0x87};
    if (write_usb(m, command, sizeof(command)) < 0 || set_low(m) < 0)
        goto fail;
    *out = m;
    return 0;
fail:
    hg_mpsse_close(m);
    return -1;
}
void hg_mpsse_close(HgMpsse *m) {
    if (!m)
        return;
    if (m->opened) {
        m->value = 0;
        if (set_low(m) >= 0 && m->controlled)
            hg_mpsse_jtag(m, true);
        m->direction = 0;
        set_low(m);
        ftdi_set_bitmode(m->ftdi, 0, BITMODE_RESET);
        ftdi_usb_close(m->ftdi);
    }
    ftdi_free(m->ftdi);
    free(m);
}
