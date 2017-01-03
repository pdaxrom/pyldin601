#include <stdio.h>
#include <unistd.h>
#include "core/mc6800.h"
#include "core/devices.h"
#include "core/mc6845.h"
#include "core/i8272.h"
#include "core/keyboard.h"

static	byte	*BMEM;
static	byte	*vdiskMEM;

static	byte	*ROMP[MAX_ROMCHIPS];	// 5 x 64KB - max. 320KB
static	byte	*CurrP;			// указатель на содержимое текущей страницы

static dword vdiskAddress;
static dword vdiskSIZE = 524288;

static struct {
	byte dr[2];
	byte cr[2];
	int mode;
} PrinterPort;

static byte led_status = 0;

static int tick50;	// устанавливается в 1 при TIMER INT 50Hz

static byte fSpeaker;		// бит состояния динамика

int SuperIoInit(void)
{
    int i;

    BMEM 	= (byte *) loadBiosRom(4096);
    vdiskMEM 	= (byte *) loadRamDisk(vdiskSIZE);

    for (i = 0; i < MAX_ROMCHIPS; i++) {
    	ROMP[i] = (byte *) loadRomDisk(i, 65536);
    }

    CurrP = NULL;

    PrinterPort.mode = PRINTER_NONE;

    MC6845Init();

    i8272Init();

    return 0;
}

int SuperIoFinish(void)
{
	unloadRamDisk(vdiskSIZE);

    return 0;
}

void SuperIoReset(void)
{
    tick50 = 0;
}

void SuperIoPrinterPortMode(int mode)
{
    if (mode == PRINTER_SYSTEM) {
    	mode = PRINTER_NONE;
    }
    PrinterPort.mode = mode;
}

void SuperIoSetDateTime(word year, word mon, word mday, word hour, word min, word sec)
{
    MC6800MemWriteByte(0x1c, mday);
    MC6800MemWriteByte(0x1d, mon + 1);

    year = (year % 100) + 1000 * (1 + year / 100);

    MC6800MemWriteByte(0x1e, year >> 8);
    MC6800MemWriteByte(0x1f, year % 256);

    MC6800MemWriteByte(0x18, 0);
    MC6800MemWriteByte(0x19, sec);
    MC6800MemWriteByte(0x1a, min);
    MC6800MemWriteByte(0x1b, hour);

    MC6800MemWriteByte(0xed00, 0xa5);
    MC6800MemWriteByte(0xed01, 0x5a);
}

O_INLINE int SuperIoReadByte(word a, byte *t)
{

    if (a >= 0xf000) {
    	*t = BMEM[a - 0xf000]; //чтение системного BIOS
    	return 1;
    }

    if (a >= 0xc000 && a < 0xe000) {
    	if (!CurrP) {
    		return 0;
    	}
    	*t = CurrP[a - 0xc000]; //чтение ROMpage
    	return 1;
    }

    if ((a & 0xff00) != 0xe600) {
    	return 0;
    }

    switch (a) {
		case 0xe600:
		case 0xe601:
		case 0xe604:
		case 0xe605:
			*t = MC6845ReadByte(a & 0x7); //чтение данных из регистров видеоконтроллера
			return 1;

		case 0xe628:
			*t = KBDReadKey(); //чтение порта a (клавиатуры)
			return 1;

		case 0xe62a:
		case 0xe62e:	//чтение упр.порта a
			*t = KBDCheckKey() | ((led_status & KBD_LED_CAPS)?0:8) | 0x37;
			return 1;

		case 0xe62b:	//чтение упр.порта b
			*t = tick50 | fSpeaker | 0x37;
			tick50 = 0;
			return 1;

	//    case 0xe6d0:
	//	*t = 0x80;
	//	return 1;

		case 0xe683:
			*t = vdiskMEM[vdiskAddress % vdiskSIZE];
			vdiskAddress += 1;
			vdiskAddress %= vdiskSIZE;
			return 1;

		case 0xe632:
			*t = 0x80;	//для принтера 601А
			return 1;

		case 0xe634:
			if (PrinterPort.mode == PRINTER_FILE) {
				*t = 0x0;
			} else {
				*t = PrinterPort.dr[0];
			}
			return 1;

		case 0xe6c0:
		case 0xe6d0:
		case 0xe6d1:
			*t = i8272ReadByte(a & 0x1f);
			return 1;
    }

    return 0;
}

O_INLINE int SuperIoWriteByte(word a, byte d)
{
    if ((a & 0xff00) != 0xe600) {
    	return 0;
    }

    static byte old_3s=0;

    switch (a) {
		case 0xe6f0:
			if (d & 8) {
				int chip = (d >> 4) % MAX_ROMCHIPS;
				int page = d & 7;
				CurrP = ROMP[chip] + page * 8192; //запись в рег.номера страниц
			} else {
				CurrP = NULL;
			}
			return 0;

		case 0xe600:
		case 0xe601:
		case 0xe604:
		case 0xe605:
			MC6845WriteByte(a & 0xf, d); //запись данных в рег.видеоконтроллера
			return 0;

		case 0xe629:
			MC6800MemWriteByte(0xe62d, d); //только для программы kltr.ubp
			KBDSetCyrMode((d&1)?0:4);
			MC6845SetupScreen(d);
			return 0;

		case 0xe62a:
		case 0xe62e:
			if (d & 0x08) {
				led_status = led_status & ~KBD_LED_CAPS;
			} else {
				led_status = led_status | KBD_LED_CAPS;
			}
			return 0;

		case 0xe62b:
			//запись в упр.рег b
			//и COVOX, если разрешена его эмуляция
			//old_3s=fSpeaker;
			fSpeaker = d & 0x08;
			if (old_3s != fSpeaker) {
				BeeperSetBit(fSpeaker);
			}
			old_3s = fSpeaker;
			return 0;

		case 0xe635:
			if (PrinterPort.mode == PRINTER_FILE) {
				PrinterPutChar(d);
			} else if (PrinterPort.mode == PRINTER_COVOX) {
				CovoxSetByte(d);
			}
			PrinterPort.dr[1] = d;
			return 0;

		case 0xe680:
			vdiskAddress = (vdiskAddress & 0x0ffff) | ((d & 0x0f)<<16);
			return 0;

		case 0xe681:
			vdiskAddress = (vdiskAddress & 0xf00ff) | (d<<8);
			return 0;

		case 0xe682:
			vdiskAddress = (vdiskAddress & 0xfff00) | d;
			return 0;

		case 0xe683:
			vdiskMEM[vdiskAddress % vdiskSIZE] = d;
			vdiskAddress += 1;
			vdiskAddress %= vdiskSIZE;
			return 0;

		case 0xe6c0:
		case 0xe6d0:
		case 0xe6d1:
			i8272WriteByte(a & 0x1f, d);
			return 0;
    }

    return 0;
}

O_INLINE void SuperIoSetTick50(void)
{
    tick50 = 0x80;
}
