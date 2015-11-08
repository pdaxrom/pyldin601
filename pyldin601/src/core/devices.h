#ifndef _DEVICES_H_
#define _DEVICES_H_

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
O_INLINE void SuperIoSetTick50(void);
O_INLINE int SuperIoReadByte(word a, byte *t);
O_INLINE int SuperIoWriteByte(word a, byte d);

byte *loadBiosRom(dword size);
byte *loadRamDisk(dword size);
byte *loadRomDisk(byte chip, dword size);

void BeeperSetBit(byte val);
void CovoxSetByte(byte val);
void PrinterPutChar(byte data);

#endif
