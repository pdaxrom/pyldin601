#pragma once

#define MAX_ROMCHIPS	5

/*
 * LED bits
 */

#define KBD_LED_SCROLL     0x01
#define KBD_LED_NUM        0x02
#define KBD_LED_CAPS       0x04

#define PRINTER_NONE    0
#define PRINTER_FILE    1
#define PRINTER_SYSTEM  2
#define PRINTER_COVOX   3

int SuperIoInit(void);
int SuperIoFinish(void);
void SuperIoReset(void);
void SuperIoPrinterPortMode(int mode);
void SuperIoSetDateTime(word year, word mon, word mday, word hour, word min, word sec);
void SuperIoUpdate(void);
O_INLINE void SuperIoSetTick50(void);
O_INLINE int SuperIoReadByte(word a, byte *t);
O_INLINE int SuperIoWriteByte(word a, byte d);
void SuperIoPs2KeyDown(unsigned int set1ScanCode);
void SuperIoPs2KeyUp(unsigned int set1ScanCode);
void SuperIoPs2ModKeyDown(byte mode);
void SuperIoPs2ModKeyUp(byte mode);
void SuperIoDrawVideo(void *video, int width, int height);

byte *loadBiosRom(dword size);
byte *loadHd6303BiosRom(dword size);
byte *loadHd6303RomPage(byte page, dword size);
byte *loadHd6303SdImage(dword *size);
void unloadHd6303SdImage(byte *mem, dword size, int dirty);
byte *loadRamDisk(dword size);
void  unloadRamDisk(dword size);
byte *loadRomDisk(byte chip, dword size);

void BeeperSetBit(byte val);
void CovoxSetByte(byte val);
void PrinterPutChar(byte data);
