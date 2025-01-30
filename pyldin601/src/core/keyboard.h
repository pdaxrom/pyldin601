/*
 *
 * Pyldin-601 emulator version 3.1 for Linux,MSDOS,Win32
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2004
 *
 */

#pragma once

#define KBD_DATA_PORT      0x60
#define KBD_CTRL_PORT      0x64

/*
 * Controller commands
 */

#define KBD_READ_MODE      0x20
#define KBD_WRITE_MODE     0x60
#define KBD_SELF_TEST      0xAA
#define KBD_LINE_TEST      0xAB
#define KBD_CTRL_ENABLE    0xAE

/*
 * Keyboard commands
 */

#define KBD_ENABLE         0xF4
#define KBD_DISABLE        0xF5
#define KBD_RESET          0xFF

/*
 * Keyboard responces
 */

#define KBD_ACK            0xFA
#define KBD_BATCC          0xAA

/*
 * Controller status register bits
 */

#define KBD_OBF            0x01
#define KBD_IBF            0x02
#define KBD_GTO            0x40
#define KBD_PERR           0x80

void KBDSetCyrMode(byte mode);

void KBDVirtKeyDown(int x, int y);
void KBDVirtKeyUp(void);
void KBDKeyDown(unsigned int tempKeyCode);
void KBDKeyUp(void);
void KBDModKeyDown(byte mode);
void KBDModKeyUp(byte mode);
unsigned char KBDCheckKey(void);
unsigned char KBDReadKey(void);

extern void resetRequested(void);
