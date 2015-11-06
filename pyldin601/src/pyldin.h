/*
 *
 * Pyldin-601 emulator version 3.4
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2015
 *
 */

#ifndef __PYLDIN_H__
#define __PYLDIN_H__

#define MENU_HEIGHT 26

void clearScr();
void drawXbm(unsigned char *xbm, int xp, int yp, int w, int h, int over);
void drawChar(unsigned int c, int xp, int yp, unsigned int fg, unsigned int bg);
void drawString(char *str, int xp, int yp, unsigned int fg, unsigned int bg);

#endif
