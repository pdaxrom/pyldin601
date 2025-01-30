/*
 *
 * Pyldin-601 emulator version 3.1 for Linux,MSDOS,Win32
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2004
 *
 */

#include <stdio.h>
#include <string.h>
#include "floppy.h"

#define SSIZE	512
#define NSECT	9
#define NHEAD	2

char *diskImage[] = {
    NULL, NULL, NULL, NULL
};

int diskSize[] = {
    0, 0, 0, 0
};

int diskChanged[] = {
    0, 0, 0, 0
};

static int floppyOp(int Op, int Drive, int Track, int Head, int Sector, unsigned char *mema)
{
    (void)Op;
    (void)Drive;
    (void)Track;
    (void)Head;
    (void)Sector;
    (void)mema;

    return 0xc0;
}

int FloppyStatus(int Disk)
{
    if (diskImage[Disk]) {
	return 0;
    }

    return 0xc0;
}

int FloppyReadSector(int Disk, int Track, int Sector, int Head, unsigned char *dst)
{
    if (Track > 79 || Sector > 18) {
	return 0x40;
    }

    if (!diskImage[Disk]) {
	return floppyOp(1, Disk, Track, Head, Sector, dst);
    }

    int offs;

    if (diskSize[Disk] > 737280) {
        offs = (Sector-1)*SSIZE+Head*18*SSIZE+Track*18*NHEAD*SSIZE;
    } else {
	offs = (Sector-1)*SSIZE+Head*NSECT*SSIZE+Track*NSECT*NHEAD*SSIZE;
    }

    memcpy(dst, diskImage[Disk] + offs, SSIZE);

    return 0;
}

int FloppyWriteSector(int Disk, int Track, int Sector, int Head, unsigned char *src)
{
    if (Track > 79 || Sector > 18) {
	return 0x40;
    }

    if (!diskImage[Disk]) {
	return floppyOp(2, Disk, Track, Head, Sector, src);
    }

    diskChanged[Disk] = 1;

    int offs;

    if (diskSize[Disk] > 737280) {
	offs = (Sector-1)*SSIZE+Head*18*SSIZE+Track*18*NHEAD*SSIZE;
    } else {
	offs = (Sector-1)*SSIZE+Head*NSECT*SSIZE+Track*NSECT*NHEAD*SSIZE;
    }

    memcpy(diskImage[Disk] + offs, src, SSIZE);
    
    return 0;
}

int FloppyFormatTrack(int Disk, int Track, int Head)
{
    if (Track > 79) {
	return 0x40;
    }

    if (!diskImage[Disk]) {
	return floppyOp(4, Disk, Track, Head, 0, NULL);
    }

    diskChanged[Disk] = 1;

    int offs;

    if (diskSize[Disk] > 737280) {
	offs = Head*18*SSIZE+Track*18*NHEAD*SSIZE;
    } else {
	offs = Head*NSECT*SSIZE+Track*NSECT*NHEAD*SSIZE;
    }

    if (diskSize[Disk] > 737280) {
	memset(diskImage[Disk] + offs, 0xf6, 18*SSIZE);
    } else {
	memset(diskImage[Disk] + offs, 0xe5, NSECT*SSIZE);
    }

    return 0;
}

int FloppyInit(void)
{
    if (!diskImage[FLOPPY_A]) {
	floppyOp(0, FLOPPY_A, 0, 0, 0, NULL);
    }

    if (!diskImage[FLOPPY_B]) {
	floppyOp(0, FLOPPY_B, 0, 0, 0, NULL);
    }

    return 0;
}
