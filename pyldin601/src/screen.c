/*
 *
 * Pyldin-601 emulator version 3.1 for Linux,MSDOS,Win32
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2004
 *
 */

#include <stdio.h>
#include <string.h>

#include "screen.h"
#include "core/mc6800.h"
#include "core/mc6845.h"

void screen_drawXbm(void *video, int width, int height, unsigned char *xbm, int xp, int yp, int w, int h, int over)
{
    height = height;
    unsigned short *vscr = (unsigned short *) video;
    int ofj = yp * width + xp;
    int ifj = 0;
    int i, j, x;

    for (j = 0; j < h; j++) {
	for (i = 0; i < (w >> 3); i++) {
	    unsigned char c = xbm[ifj + i];
	    for (x = 0; x < 8; x++) {
		if (!over || !(c & 0x1)) {
		    vscr[ofj + (i * 8 + x)] = (c & 0x1)?0:0x3ef;
		}
		c >>= 1;
	    }
	}
	ofj += width;
	ifj += (w >> 3);
    }
}

void screen_drawChar(void *video, int width, int height, unsigned int c, int xp, int yp, unsigned int fg, unsigned int bg)
{
    height = height;
    int i, j;
    unsigned short *vscr = video;
    int offset = yp * width + xp;

    static unsigned char *font = NULL;
    if (!font) {
	font = get_videorom_mem(2048);
    }

    c = ((c<<1) | (c>>7)) & 0xff;
    c = c * 8;
    for (j = 0; j < 8; j++) {
	unsigned char d = font[c + j];
	for (i=0; i < 8; i++) {
	    vscr[offset + i] = (d & 0x80)?fg:bg;
	    d<<=1;
	}
	offset += width;
    }
}

void screen_drawString(void *video, int width, int height, char *str, int xp, int yp, unsigned int fg, unsigned int bg)
{
	yp *= 8;
	while (*str != 0) {
	    screen_drawChar(video, width, height, *str, xp, yp, fg, bg);
	    xp += 8;
	    str++;
	}
}
