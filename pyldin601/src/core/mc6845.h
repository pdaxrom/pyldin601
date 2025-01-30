#pragma once

#define PIXEL_ON		(0x3f<<5) //0xffff
#define PIXEL_OFF		0x0

void MC6845Init(void);
O_INLINE void MC6845SetupScreen(int mode);
O_INLINE void MC6845WriteByte(byte a, byte d);
O_INLINE byte MC6845ReadByte(byte a);
O_INLINE void MC6845CursorBlink(void);
void MC6845DrawScreen(void *video, int width, int height);

byte *loadCharGenRom(dword size);
