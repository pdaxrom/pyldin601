/*
 *
 * Pyldin-601 emulator version 3.1 for Linux,MSDOS,Win32
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2004
 *
 */

#pragma once

void screen_drawXbm(void *video, int width, int height, unsigned char *xpm, int xp, int yp, int w, int h, int over);
void screen_drawChar(void *video, int width, int height, unsigned int c, int xp, int yp, unsigned int fg, unsigned int bg);
void screen_drawString(void *video, int width, int height, char *str, int xp, int yp, unsigned int fg, unsigned int bg);
