#define _POSIX_C_SOURCE 200809L
#include "hg.h"
#include <errno.h>
#include <getopt.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static volatile sig_atomic_t stopping;
static void stop(int sig) {
    (void)sig;
    stopping = 1;
}
static void usage(FILE *out) {
    fputs("hgfsd --directory PATH | --image FILE | --create-image FILE | --jtag-only\n"
          "  --clock N       TCK 100..1000000 Hz, default 1000000\n"
          "  --blocks N      FAT12 sectors, default 32736\n"
          "  --read-only     reject guest writes (host changes still imported)\n"
          "  --stats         log transfers and throughput\n"
          "  --serial S --index N --vid N --pid N  select FT2232 interface A\n"
          "  --watch-only    mirror directory without opening FTDI\n"
          "  --sync-only     mirror/recover once without FTDI, then exit\n"
          "SIGINT/SIGTERM finish the transaction, sync files and restore JTAG.\n",
          out);
}
static unsigned number(const char *s) {
    char *end;
    errno = 0;
    unsigned long n = strtoul(s, &end, 0);
    if (errno || !*s || *end || n > 0xfffffffful || *s == '-') {
        fprintf(stderr, "Invalid number: %s\n", s);
        exit(2);
    }
    return (unsigned)n;
}
int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IOLBF, 0);
    setvbuf(stderr, NULL, _IOLBF, 0);
    const char *directory = NULL, *image = NULL, *create = NULL, *serial = NULL;
    unsigned clock = 1000000, blocks = HG_MAX_SECTORS, index = 0, vid = 0x403, pid = 0x6010;
    bool readonly = false, stats = false, jtag = false, watch = false, once = false;
    enum {
        DIRECTORY = 256,
        IMAGE,
        CREATE,
        CLOCK,
        BLOCKS,
        READONLY,
        STATS,
        SERIAL,
        INDEX,
        VID,
        PID,
        JTAG,
        WATCH,
        ONCE,
        COMPAT
    };
    static const struct option opts[] = {{"directory", 1, 0, DIRECTORY},
                                         {"image", 1, 0, IMAGE},
                                         {"create-image", 1, 0, CREATE},
                                         {"clock", 1, 0, CLOCK},
                                         {"blocks", 1, 0, BLOCKS},
                                         {"read-only", 0, 0, READONLY},
                                         {"stats", 0, 0, STATS},
                                         {"serial", 1, 0, SERIAL},
                                         {"index", 1, 0, INDEX},
                                         {"vid", 1, 0, VID},
                                         {"pid", 1, 0, PID},
                                         {"jtag-only", 0, 0, JTAG},
                                         {"watch-only", 0, 0, WATCH},
                                         {"sync-only", 0, 0, ONCE},
                                         {"jtag-enable-adbus7", 0, 0, COMPAT},
                                         {"help", 0, 0, 'h'},
                                         {0, 0, 0, 0}};
    int opt;
    while ((opt = getopt_long(argc, argv, "h", opts, NULL)) != -1)
        switch (opt) {
        case DIRECTORY:
            directory = optarg;
            break;
        case IMAGE:
            image = optarg;
            break;
        case CREATE:
            create = optarg;
            break;
        case CLOCK:
            clock = number(optarg);
            break;
        case BLOCKS:
            blocks = number(optarg);
            break;
        case READONLY:
            readonly = true;
            break;
        case STATS:
            stats = true;
            break;
        case SERIAL:
            serial = optarg;
            break;
        case INDEX:
            index = number(optarg);
            break;
        case VID:
            vid = number(optarg);
            break;
        case PID:
            pid = number(optarg);
            break;
        case JTAG:
            jtag = true;
            break;
        case WATCH:
            watch = true;
            break;
        case ONCE:
            once = true;
            break;
        case COMPAT:
            break;
        case 'h':
            usage(stdout);
            return 0;
        default:
            usage(stderr);
            return 2;
        }
    if (optind != argc || !!directory + !!image + !!create + jtag != 1 ||
        ((watch || once) && !directory) || (watch && once) || clock < 100 || clock > 1000000 ||
        vid > 65535 || pid > 65535 || blocks < 128 || blocks > HG_MAX_SECTORS) {
        usage(stderr);
        return 2;
    }
    if (create) {
        if (hg_create_image(create, blocks) < 0) {
            hg_error("creating image: %s", strerror(errno));
            return 1;
        }
        printf("Created %s: %u FAT12 sectors\n", create, blocks);
        return 0;
    }
    struct sigaction action = {0};
    action.sa_handler = stop;
    sigemptyset(&action.sa_mask);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGTERM, &action, NULL);
    HgVolume volume = {0};
    volume.fd = volume.dirfd = volume.lockfd = volume.watchfd = -1;
    HgMpsse *m = NULL;
    int rc = 1;
    if (!jtag &&
        hg_volume_open(&volume, directory ? directory : image, !!directory, blocks, readonly) < 0)
        goto end;
    if (once) {
        rc = 0;
        goto end;
    }
    if (!watch) {
        if (hg_mpsse_open(&m, clock, serial, index, vid, pid) < 0 || hg_mpsse_jtag(m, jtag) < 0)
            goto end;
        if (jtag) {
            rc = 0;
            goto end;
        }
    }
    printf("Serving %s at %u Hz; %u sectors; native C HG v1/v2%s\n", volume.path, clock,
           volume.fat.sectors, directory ? "; automatic directory updates enabled" : "");
    uint64_t last_io = hg_millis(), retry = 0;
    HgLink link = hg_mpsse_link(m);
    while (!stopping) {
        if (hg_volume_events(&volume) < 0)
            goto end;
        int pending = m ? hg_mpsse_pending(m) : 0;
        if (pending < 0)
            goto end;
        if (pending) {
            if (hg_serve(&link, &volume, stats) < 0)
                goto end;
            last_io = hg_millis();
        } else if (volume.directory && (volume.changed || volume.dirty) &&
                   hg_millis() - last_io >= 500 && hg_millis() - volume.event_ms >= 500 &&
                   hg_millis() >= retry) {
            if (hg_volume_sync(&volume) < 0)
                retry = hg_millis() + 1000;
        }
        struct pollfd pfd = {volume.watchfd, POLLIN, 0};
        if (poll(&pfd, volume.watchfd >= 0 ? 1 : 0, m ? 2 : 50) < 0 && errno != EINTR)
            goto end;
    }
    rc = 0;
end:
    hg_mpsse_close(m);
    if (volume.directory && volume.image && volume.base && hg_volume_sync(&volume) < 0) {
        hg_error("pending changes kept in the journal for recovery");
        rc = 1;
    }
    hg_volume_close(&volume);
    return rc;
}
