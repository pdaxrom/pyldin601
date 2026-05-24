#include <stdio.h>
#include <string.h>
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

#define HD6303_RAM_SIZE 131072
#define HD6303_ROM_PAGE_SIZE 8192
#define HD6303_ROM_PAGES 16
#define HD6303_VRAM_SIZE 8192

#define HD_REG_RMCR     0x10
#define HD_REG_TRCSR1   0x11
#define HD_REG_RDR      0x12
#define HD_REG_TDR      0x13
#define HD_REG_RP5CR    0x14
#define HD_REG_PORT5    0x15
#define HD_REG_DDRP6    0x16
#define HD_REG_PORT6    0x17
#define HD_REG_DDRP5    0x20

#define HD_MEMPAGE_PAGE_MASK 0x07
#define HD_MEMPAGE_ROM  0x08
#define HD_MEMPAGE_HI   0x10
#define HD_MEMPAGE_FMASK 0xe0

#define HD_PS2_IRQ      0x80
#define HD_PS2_IEN      0x40
#define HD_PS2_RDY      0x20
#define HD_PS2_BSY      0x10
#define HD_PS2_TIM      0x08
#define HD_PS2_E1       0x04
#define HD_PS2_E0       0x02
#define HD_PS2_REL      0x01
#define HD_PS2_BYTE_DELAY_CYCLES 2048

#define HD_SPI_READY    0x80
#define HD_SPI_SSM      0x20
#define HD_SPI_16B      0x10
#define HD_SPI_SS0      0x01
#define HD_SPI_SS1      0x02

#define HD_VPU_IRQ      0x80
#define HD_VPU_IEN      0x40
#define HD_VPU_VBL      0x20
#define HD_VPU_GRF      0x10
#define HD_VPU_CURINV   0x08
#define HD_VPU_CUR      0x04
#define HD_VPU_ID       0x02
#define HD_VPU_AUTO     0x01

#define HD_SD_BLOCK_SIZE 512
#define HD_SD_RESP_SIZE  1024

static byte *hdBios;
static byte *hdRom[HD6303_ROM_PAGES];
static byte *hdVideoRom;
static byte *hdSdImage;
static dword hdSdImageSize;
static int hdSdDirty;
static byte hdRegs[0x28];

static struct {
	byte vram[HD6303_VRAM_SIZE];
	word addr;
	byte config;
	byte autoOffset;
	word startAddr;
	byte hOffset;
	byte vOffset;
	byte hSize;
	byte vSize;
	byte curPos;
	byte curLineStart;
	byte curLineEnd;
} HdVpu;

static struct {
	byte data;
	byte status;
	byte writeData;
	byte queueData[16];
	byte queueFlags[16];
	int queueHead;
	int queueTail;
	int queueCount;
	dword nextReadyCycle;
} HdPs2;

static byte hdSimpleIo[0x20];
static byte hdPsg[16];
static byte hdPsgAddr;
static word hdIntRouter;

static struct {
	byte config;
	byte prescaler;
	byte pout;
	byte rxData[2];
	byte txData[2];
	byte resp[HD_SD_RESP_SIZE];
	byte cmd[6];
	byte writeBlock[HD_SD_BLOCK_SIZE];
	dword writeLba;
	int respHead;
	int respTail;
	int respCount;
	int cmdLen;
	int selected;
	int idle;
	int appCmd;
	int blockAddressing;
	int writeState;
	int writeIndex;
	int writeCrc;
	int txHighPending;
} HdSpi;

static const byte set1_to_set2[128] = {
	0x00, 0x76, 0x16, 0x1e, 0x26, 0x25, 0x2e, 0x36,
	0x3d, 0x3e, 0x46, 0x45, 0x4e, 0x55, 0x66, 0x0d,
	0x15, 0x1d, 0x24, 0x2d, 0x2c, 0x35, 0x3c, 0x43,
	0x44, 0x4d, 0x54, 0x5b, 0x5a, 0x00, 0x1c, 0x1b,
	0x23, 0x2b, 0x34, 0x33, 0x3b, 0x42, 0x4b, 0x4c,
	0x52, 0x0e, 0x00, 0x5d, 0x1a, 0x22, 0x21, 0x2a,
	0x32, 0x31, 0x3a, 0x41, 0x49, 0x4a, 0x00, 0x00,
	0x00, 0x29, 0x58, 0x05, 0x06, 0x04, 0x0c, 0x03,
	0x0b, 0x83, 0x0a, 0x01, 0x09, 0x00, 0x7e, 0x00,
	0x00, 0x00, 0x70, 0x00, 0x00, 0x6c, 0x00, 0x00,
	0x00, 0x69, 0x00, 0x6b, 0x00, 0x74, 0x00, 0x00,
	0x00, 0x72, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static int hd6303_is_active(void)
{
	return MC6800GetMachine() == PYLDIN_MACHINE_HD6303;
}

static byte hd6303_page_number(void)
{
	byte port6 = hdRegs[HD_REG_PORT6];

	return ((port6 & HD_MEMPAGE_HI) >> 1) | (port6 & HD_MEMPAGE_PAGE_MASK);
}

static int hd6303_bios_visible(void)
{
	byte fn = hdRegs[HD_REG_PORT6] & HD_MEMPAGE_FMASK;

	return fn == 0 || fn == HD_MEMPAGE_FMASK;
}

static dword hd6303_ram_offset(word a)
{
	if (a >= 0xc000 && a < 0xe000) {
		return (dword)hd6303_page_number() * HD6303_ROM_PAGE_SIZE + (a - 0xc000);
	}

	if (a >= 0xe000) {
		return 0xe000 + (a - 0xe000);
	}

	return a;
}

static int hd6303_page_ram_visible(void)
{
	return (hdRegs[HD_REG_PORT6] & HD_MEMPAGE_ROM) == 0;
}

static int hd6303_page_rom_visible(void)
{
	return (hdRegs[HD_REG_PORT6] & HD_MEMPAGE_ROM) != 0;
}

static byte hd6303_internal_read(word a)
{
	switch (a) {
		case HD_REG_TRCSR1:
			return hdRegs[a] | 0x20;
		case HD_REG_RDR:
			return 0xff;
		case HD_REG_PORT6:
			return hdRegs[HD_REG_PORT6];
		default:
			return hdRegs[a];
	}
}

static void hd6303_internal_write(word a, byte d)
{
	if (a >= sizeof(hdRegs)) {
		return;
	}

	hdRegs[a] = d;
}

static int hd6303_interrupt_select(int shift)
{
	return (hdIntRouter >> shift) & 0x03;
}

static void hd6303_raise_interrupt(int shift)
{
	int route = hd6303_interrupt_select(shift);

	if (route == 0 || route == 1) {
		MC6800SetInterrupt(1);
	}
}

static void hd6303_vpu_reset(void)
{
	memset(&HdVpu, 0, sizeof(HdVpu));
	HdVpu.config = HD_VPU_AUTO;
	HdVpu.autoOffset = 1;
	HdVpu.hOffset = 96;
	HdVpu.vOffset = 50;
	HdVpu.hSize = 39;
	HdVpu.vSize = 199;
}

static void hd6303_sd_queue_clear(void)
{
	HdSpi.respHead = 0;
	HdSpi.respTail = 0;
	HdSpi.respCount = 0;
}

static void hd6303_sd_queue(byte d)
{
	if (HdSpi.respCount >= HD_SD_RESP_SIZE) {
		return;
	}

	HdSpi.resp[HdSpi.respTail] = d;
	HdSpi.respTail = (HdSpi.respTail + 1) % HD_SD_RESP_SIZE;
	HdSpi.respCount++;
}

static byte hd6303_sd_dequeue(byte def)
{
	byte d;

	if (HdSpi.respCount == 0) {
		return def;
	}

	d = HdSpi.resp[HdSpi.respHead];
	HdSpi.respHead = (HdSpi.respHead + 1) % HD_SD_RESP_SIZE;
	HdSpi.respCount--;
	return d;
}

static dword hd6303_sd_arg(void)
{
	return ((dword)HdSpi.cmd[1] << 24) |
		((dword)HdSpi.cmd[2] << 16) |
		((dword)HdSpi.cmd[3] << 8) |
		HdSpi.cmd[4];
}

static int hd6303_sd_lba(dword arg, dword *lba)
{
	if (HdSpi.blockAddressing) {
		*lba = arg;
	} else {
		*lba = arg >> 9;
	}

	return hdSdImage && *lba < (hdSdImageSize / HD_SD_BLOCK_SIZE);
}

static void hd6303_sd_command(void)
{
	byte cmd = HdSpi.cmd[0] & 0x3f;
	dword arg = hd6303_sd_arg();
	dword lba;
	int app = HdSpi.appCmd;

	HdSpi.cmdLen = 0;
	HdSpi.appCmd = 0;

	if (!hdSdImage) {
		hd6303_sd_queue(0x05);
		return;
	}

	if (app && cmd == 41) {
		HdSpi.idle = 0;
		HdSpi.blockAddressing = 1;
		hd6303_sd_queue(0x00);
		return;
	}

	switch (cmd) {
		case 0:
			HdSpi.idle = 1;
			HdSpi.blockAddressing = 0;
			hd6303_sd_queue(0x01);
			break;
		case 1:
			HdSpi.idle = 0;
			HdSpi.blockAddressing = 0;
			hd6303_sd_queue(0x00);
			break;
		case 8:
			hd6303_sd_queue(HdSpi.idle ? 0x01 : 0x00);
			hd6303_sd_queue(0x00);
			hd6303_sd_queue(0x00);
			hd6303_sd_queue(0x01);
			hd6303_sd_queue(0xaa);
			break;
		case 16:
			hd6303_sd_queue(arg == HD_SD_BLOCK_SIZE ? 0x00 : 0x04);
			break;
		case 17:
			if (!hd6303_sd_lba(arg, &lba)) {
				hd6303_sd_queue(0x04);
				break;
			}
			hd6303_sd_queue(0x00);
			hd6303_sd_queue(0xff);
			hd6303_sd_queue(0xfe);
			for (int i = 0; i < HD_SD_BLOCK_SIZE; i++) {
				hd6303_sd_queue(hdSdImage[lba * HD_SD_BLOCK_SIZE + i]);
			}
			hd6303_sd_queue(0xff);
			hd6303_sd_queue(0xff);
			break;
		case 24:
			if (!hd6303_sd_lba(arg, &lba)) {
				hd6303_sd_queue(0x04);
				break;
			}
			hd6303_sd_queue(0x00);
			HdSpi.writeState = 1;
			HdSpi.writeLba = lba;
			HdSpi.writeIndex = 0;
			HdSpi.writeCrc = 0;
			break;
		case 55:
			HdSpi.appCmd = 1;
			hd6303_sd_queue(HdSpi.idle ? 0x01 : 0x00);
			break;
		case 58:
			hd6303_sd_queue(HdSpi.idle ? 0x01 : 0x00);
			hd6303_sd_queue(HdSpi.blockAddressing ? 0x40 : 0x00);
			hd6303_sd_queue(0x00);
			hd6303_sd_queue(0x00);
			hd6303_sd_queue(0x00);
			break;
		default:
			hd6303_sd_queue(0x04);
			break;
	}
}

static int hd6303_spi_sd_selected(void)
{
	return (HdSpi.config & HD_SPI_SS1) == 0;
}

static byte hd6303_spi_transfer(byte d)
{
	if (!HdSpi.selected || !hdSdImage) {
		return 0xff;
	}

	if (HdSpi.writeState == 1) {
		if (d == 0xfe) {
			HdSpi.writeState = 2;
			HdSpi.writeIndex = 0;
			HdSpi.writeCrc = 0;
		}
		return hd6303_sd_dequeue(0xff);
	}

	if (HdSpi.writeState == 2) {
		HdSpi.writeBlock[HdSpi.writeIndex++] = d;
		if (HdSpi.writeIndex == HD_SD_BLOCK_SIZE) {
			HdSpi.writeState = 3;
		}
		return 0xff;
	}

	if (HdSpi.writeState == 3) {
		HdSpi.writeCrc++;
		if (HdSpi.writeCrc == 2) {
			memcpy(hdSdImage + HdSpi.writeLba * HD_SD_BLOCK_SIZE,
				HdSpi.writeBlock, HD_SD_BLOCK_SIZE);
			hdSdDirty = 1;
			HdSpi.writeState = 0;
			hd6303_sd_queue(0x05);
		}
		return 0xff;
	}

	if (HdSpi.respCount) {
		return hd6303_sd_dequeue(0xff);
	}

	if (HdSpi.cmdLen == 0) {
		if ((d & 0xc0) == 0x40) {
			HdSpi.cmd[HdSpi.cmdLen++] = d;
		}
		return 0xff;
	}

	HdSpi.cmd[HdSpi.cmdLen++] = d;
	if (HdSpi.cmdLen == sizeof(HdSpi.cmd)) {
		hd6303_sd_command();
	}

	return 0xff;
}

static void hd6303_spi_reset(void)
{
	memset(&HdSpi, 0, sizeof(HdSpi));
	HdSpi.config = HD_SPI_SSM | HD_SPI_SS0 | HD_SPI_SS1;
	HdSpi.rxData[0] = 0xff;
	HdSpi.rxData[1] = 0xff;
	HdSpi.txData[0] = 0xff;
	HdSpi.txData[1] = 0xff;
	HdSpi.idle = 1;
	HdSpi.selected = hd6303_spi_sd_selected();
}

static void hd6303_reset(void)
{
	memset(hdRegs, 0, sizeof(hdRegs));
	memset(hdSimpleIo, 0, sizeof(hdSimpleIo));
	memset(hdPsg, 0, sizeof(hdPsg));
	hd6303_spi_reset();
	memset(&HdPs2, 0, sizeof(HdPs2));

	hdRegs[HD_REG_PORT6] = HD_MEMPAGE_FMASK;
	hdRegs[HD_REG_DDRP6] = 0xff;
	hdRegs[HD_REG_RP5CR] = 0x40;

	hdIntRouter = 0;
	hdPsgAddr = 0;
	hd6303_vpu_reset();
}

static void hd6303_vpu_inc_addr(void)
{
	if (!(HdVpu.config & HD_VPU_AUTO)) {
		return;
	}

	if (HdVpu.config & HD_VPU_ID) {
		HdVpu.addr -= HdVpu.autoOffset;
	} else {
		HdVpu.addr += HdVpu.autoOffset;
	}
	HdVpu.addr &= HD6303_VRAM_SIZE - 1;
}

static byte hd6303_vpu_read(word a)
{
	switch (a & 0x0f) {
		case 0x00: {
			byte d = HdVpu.vram[HdVpu.addr & (HD6303_VRAM_SIZE - 1)];
			hd6303_vpu_inc_addr();
			return d;
		}
		case 0x01:
			return (HdVpu.addr >> 8) & 0x1f;
		case 0x02:
			return HdVpu.addr & 0xff;
		case 0x03: {
			byte d = HdVpu.config;
			HdVpu.config &= ~HD_VPU_IRQ;
			return d;
		}
		case 0x04:
			return HdVpu.autoOffset;
		case 0x05:
			return (HdVpu.startAddr >> 8) & 0x1f;
		case 0x06:
			return HdVpu.startAddr & 0xff;
		case 0x07:
			return HdVpu.hOffset;
		case 0x08:
			return HdVpu.vOffset;
		case 0x09:
			return HdVpu.hSize;
		case 0x0a:
			return HdVpu.vSize;
		case 0x0b:
			return HdVpu.curPos;
		case 0x0c:
			return HdVpu.curLineStart;
		case 0x0d:
			return HdVpu.curLineEnd;
	}

	return 0xa5;
}

static void hd6303_vpu_write(word a, byte d)
{
	switch (a & 0x0f) {
		case 0x00:
			HdVpu.vram[HdVpu.addr & (HD6303_VRAM_SIZE - 1)] = d;
			hd6303_vpu_inc_addr();
			break;
		case 0x01:
			HdVpu.addr = ((d & 0x1f) << 8) | (HdVpu.addr & 0xff);
			break;
		case 0x02:
			HdVpu.addr = (HdVpu.addr & 0x1f00) | d;
			break;
		case 0x03:
			HdVpu.config = (HdVpu.config & (HD_VPU_IRQ | HD_VPU_VBL)) |
				(d & (HD_VPU_IEN | HD_VPU_GRF | HD_VPU_CURINV | HD_VPU_CUR | HD_VPU_ID | HD_VPU_AUTO));
			break;
		case 0x04:
			HdVpu.autoOffset = d;
			break;
		case 0x05:
			HdVpu.startAddr = ((d & 0x1f) << 8) | (HdVpu.startAddr & 0xff);
			break;
		case 0x06:
			HdVpu.startAddr = (HdVpu.startAddr & 0x1f00) | d;
			break;
		case 0x07:
			HdVpu.hOffset = d;
			break;
		case 0x08:
			HdVpu.vOffset = d;
			break;
		case 0x09:
			HdVpu.hSize = d;
			break;
		case 0x0a:
			HdVpu.vSize = d;
			break;
		case 0x0b:
			HdVpu.curPos = d;
			break;
		case 0x0c:
			HdVpu.curLineStart = d;
			break;
		case 0x0d:
			HdVpu.curLineEnd = d;
			break;
	}
}

static void hd6303_ps2_load_next(void)
{
	if ((HdPs2.status & HD_PS2_RDY) || HdPs2.queueCount == 0) {
		return;
	}

	HdPs2.data = HdPs2.queueData[HdPs2.queueHead];
	HdPs2.status = (HdPs2.status & HD_PS2_IEN) |
		HD_PS2_RDY | HdPs2.queueFlags[HdPs2.queueHead];
	HdPs2.queueHead = (HdPs2.queueHead + 1) & 0x0f;
	HdPs2.queueCount--;

	if (HdPs2.status & HD_PS2_IEN) {
		HdPs2.status |= HD_PS2_IRQ;
		hd6303_raise_interrupt(12);
	}

	HdPs2.nextReadyCycle = 0;
}

static void hd6303_ps2_schedule_next(void)
{
	if (HdPs2.queueCount == 0) {
		HdPs2.nextReadyCycle = 0;
		return;
	}

	HdPs2.nextReadyCycle = MC6800GetCyclesCounter() + HD_PS2_BYTE_DELAY_CYCLES;
}

static void hd6303_ps2_update(void)
{
	if ((HdPs2.status & HD_PS2_RDY) || HdPs2.queueCount == 0) {
		return;
	}

	if (HdPs2.nextReadyCycle == 0 ||
	    (int)(MC6800GetCyclesCounter() - HdPs2.nextReadyCycle) >= 0) {
		hd6303_ps2_load_next();
	}
}

static void hd6303_ps2_enqueue(byte d, byte flags)
{
	if (HdPs2.queueCount < 16) {
		HdPs2.queueData[HdPs2.queueTail] = d;
		HdPs2.queueFlags[HdPs2.queueTail] = flags;
		HdPs2.queueTail = (HdPs2.queueTail + 1) & 0x0f;
		HdPs2.queueCount++;
	}

	hd6303_ps2_update();
}

static byte hd6303_ps2_read(word a)
{
	if ((a & 0x01) == 0) {
		byte d = HdPs2.data;

		HdPs2.status &= HD_PS2_IEN;
		hd6303_ps2_schedule_next();
		return d;
	}

	byte d = HdPs2.status;
	HdPs2.status &= ~HD_PS2_IRQ;
	return d;
}

static void hd6303_ps2_write(word a, byte d)
{
	if ((a & 0x01) == 0) {
		HdPs2.writeData = d;
		HdPs2.status &= ~HD_PS2_BSY;
		hd6303_ps2_enqueue(0xfa, 0);
		if (d == 0xff) {
			hd6303_ps2_enqueue(0xaa, 0);
		}
		return;
	}

	HdPs2.status = (HdPs2.status & ~HD_PS2_IEN) | (d & HD_PS2_IEN);
	if (HdPs2.status & HD_PS2_RDY) {
		if (HdPs2.status & HD_PS2_IEN) {
			HdPs2.status |= HD_PS2_IRQ;
			hd6303_raise_interrupt(12);
		}
	} else {
		hd6303_ps2_update();
	}
}

static byte hd6303_simpleio_read(word a)
{
	switch (a & 0x0f) {
		case 0x00:
			return ~hdSimpleIo[0x00];
		case 0x01:
		case 0x02:
			return hdSimpleIo[a & 0x0f];
		case 0x03:
			return ((~hdSimpleIo[0x03]) & 0x77);
		case 0x04:
			return 0xf0;
		case 0x08: {
			byte d = hdSimpleIo[0x08];
			hdSimpleIo[0x08] &= ~0x80;
			return d;
		}
		case 0x09:
		case 0x0a:
		case 0x0b:
			return hdSimpleIo[a & 0x0f];
	}

	return 0xa5;
}

static void hd6303_simpleio_write(word a, byte d)
{
	switch (a & 0x0f) {
		case 0x00:
		case 0x01:
		case 0x02:
		case 0x03:
			hdSimpleIo[a & 0x0f] = d;
			break;
		case 0x08:
			hdSimpleIo[0x08] = d & 0x41;
			break;
		case 0x09:
		case 0x0a:
		case 0x0b:
			hdSimpleIo[a & 0x0f] = d;
			break;
	}
}

static byte hd6303_spi_read(word a)
{
	switch (a & 0x07) {
		case 0x00:
			return HdSpi.rxData[0];
		case 0x01:
			return HdSpi.rxData[1];
		case 0x02:
			return HD_SPI_READY | (HdSpi.config & (HD_SPI_SSM | HD_SPI_16B | HD_SPI_SS1 | HD_SPI_SS0));
		case 0x03:
			return HdSpi.prescaler;
		case 0x04:
			return HdSpi.pout & 0x03;
	}

	return 0xa5;
}

static void hd6303_spi_write(word a, byte d)
{
	switch (a & 0x07) {
		case 0x00:
			HdSpi.txData[0] = d;
			if (HdSpi.config & HD_SPI_16B) {
				HdSpi.txHighPending = 1;
			}
			break;
		case 0x01:
			HdSpi.txData[1] = d;
			if (HdSpi.config & HD_SPI_16B) {
				if (HdSpi.txHighPending) {
					HdSpi.rxData[0] = hd6303_spi_transfer(HdSpi.txData[0]);
					HdSpi.rxData[1] = hd6303_spi_transfer(HdSpi.txData[1]);
					HdSpi.txHighPending = 0;
				}
			} else {
				HdSpi.rxData[1] = hd6303_spi_transfer(d);
			}
			break;
		case 0x02: {
			int wasSelected = HdSpi.selected;
			HdSpi.config = d & (HD_SPI_SSM | HD_SPI_16B | HD_SPI_SS1 | HD_SPI_SS0);
			HdSpi.selected = hd6303_spi_sd_selected();
			if (!(HdSpi.config & HD_SPI_16B)) {
				HdSpi.txHighPending = 0;
			}
			if (wasSelected != HdSpi.selected) {
				HdSpi.cmdLen = 0;
				if (!HdSpi.selected) {
					hd6303_sd_queue_clear();
					HdSpi.writeState = 0;
					HdSpi.txHighPending = 0;
				}
			}
			break;
		}
		case 0x03:
			HdSpi.prescaler = d;
			break;
		case 0x04:
			HdSpi.pout = d & 0x03;
			break;
	}
}

static byte hd6303_io_read(word a)
{
	if (a >= 0xe610 && a <= 0xe61f) {
		return hd6303_vpu_read(a);
	}
	if (a >= 0xe6a0 && a <= 0xe6af) {
		return hd6303_simpleio_read(a);
	}
	if (a == 0xe6b0) {
		return hdPsg[hdPsgAddr & 0x0f];
	}
	if (a >= 0xe6c0 && a <= 0xe6c7) {
		return hd6303_spi_read(a);
	}
	if (a == 0xe6d0 || a == 0xe6d1) {
		return hd6303_ps2_read(a);
	}
	if (a == 0xe6fe) {
		return hdIntRouter >> 8;
	}
	if (a == 0xe6ff) {
		return hdIntRouter & 0xff;
	}

	return 0xa5;
}

static void hd6303_io_write(word a, byte d)
{
	if (a >= 0xe610 && a <= 0xe61f) {
		hd6303_vpu_write(a, d);
		return;
	}
	if (a >= 0xe6a0 && a <= 0xe6af) {
		hd6303_simpleio_write(a, d);
		return;
	}
	if (a == 0xe6b0) {
		hdPsg[hdPsgAddr & 0x0f] = d;
		return;
	}
	if (a == 0xe6b1) {
		hdPsgAddr = d & 0x0f;
		return;
	}
	if (a >= 0xe6c0 && a <= 0xe6c7) {
		hd6303_spi_write(a, d);
		return;
	}
	if (a == 0xe6d0 || a == 0xe6d1) {
		hd6303_ps2_write(a, d);
		return;
	}
	if (a == 0xe6fe) {
		hdIntRouter = (hdIntRouter & 0x00ff) | ((word)d << 8);
		return;
	}
	if (a == 0xe6ff) {
		hdIntRouter = (hdIntRouter & 0xff00) | d;
		return;
	}
}

static int hd6303_read_byte(word a, byte *t)
{
	if (a < sizeof(hdRegs)) {
		*t = hd6303_internal_read(a);
		return 1;
	}

	if (a >= 0xf000 && hd6303_bios_visible()) {
		*t = hdBios ? hdBios[a - 0xf000] : 0xff;
		return 1;
	}

	if (a >= 0xc000 && a < 0xe000) {
		if (hd6303_page_rom_visible()) {
			byte page = hd6303_page_number();
			*t = hdRom[page] ? hdRom[page][a - 0xc000] : 0xff;
			return 1;
		}

		if (!hd6303_page_ram_visible()) {
			*t = 0xff;
			return 1;
		}
	}

	if ((a & 0xff00) == 0xe600) {
		*t = hd6303_io_read(a);
		return 1;
	}

	*t = MEM[hd6303_ram_offset(a) % HD6303_RAM_SIZE];
	return 1;
}

static void hd6303_write_byte(word a, byte d)
{
	if (a < sizeof(hdRegs)) {
		hd6303_internal_write(a, d);
		return;
	}

	if ((a & 0xff00) == 0xe600) {
		hd6303_io_write(a, d);
		return;
	}

	if (a >= 0xc000 && a < 0xe000) {
		if (hd6303_page_rom_visible() || !hd6303_page_ram_visible()) {
			return;
		}
	}

	MEM[hd6303_ram_offset(a) % HD6303_RAM_SIZE] = d;
}

static byte hd6303_set2_from_set1(unsigned int set1ScanCode, byte *flags)
{
	*flags = 0;

	switch (set1ScanCode) {
		case 0x47:
			*flags = HD_PS2_E0;
			return 0x6c;
		case 0x48:
			*flags = HD_PS2_E0;
			return 0x75;
		case 0x49:
			*flags = HD_PS2_E0;
			return 0x7d;
		case 0x4b:
			*flags = HD_PS2_E0;
			return 0x6b;
		case 0x4d:
			*flags = HD_PS2_E0;
			return 0x74;
		case 0x4f:
			*flags = HD_PS2_E0;
			return 0x69;
		case 0x50:
			*flags = HD_PS2_E0;
			return 0x72;
		case 0x51:
			*flags = HD_PS2_E0;
			return 0x7a;
		case 0x52:
			*flags = HD_PS2_E0;
			return 0x70;
		case 0x53:
			*flags = HD_PS2_E0;
			return 0x71;
	}

	if (set1ScanCode < sizeof(set1_to_set2)) {
		return set1_to_set2[set1ScanCode];
	}

	return 0;
}

static void hd6303_ps2_key_event(unsigned int set1ScanCode, byte flags)
{
	byte prefixFlags;
	byte set2 = hd6303_set2_from_set1(set1ScanCode, &prefixFlags);

	if (!set2) {
		return;
	}

	hd6303_ps2_enqueue(set2, flags | prefixFlags);
}

void SuperIoPs2KeyDown(unsigned int set1ScanCode)
{
	if (!hd6303_is_active()) {
		return;
	}

	hd6303_ps2_key_event(set1ScanCode, 0);
}

void SuperIoPs2KeyUp(unsigned int set1ScanCode)
{
	if (!hd6303_is_active()) {
		return;
	}

	hd6303_ps2_key_event(set1ScanCode, HD_PS2_REL);
}

void SuperIoPs2ModKeyDown(byte mode)
{
	if (!hd6303_is_active()) {
		return;
	}

	if (mode & 1) {
		hd6303_ps2_enqueue(0x14, 0);
	}
	if (mode & 2) {
		hd6303_ps2_enqueue(0x12, 0);
	}
	if (mode & (8 | 16)) {
		hd6303_ps2_enqueue(0x11, 0);
	}
}

void SuperIoPs2ModKeyUp(byte mode)
{
	if (!hd6303_is_active()) {
		return;
	}

	if (mode & 1) {
		hd6303_ps2_enqueue(0x14, HD_PS2_REL);
	}
	if (mode & 2) {
		hd6303_ps2_enqueue(0x12, HD_PS2_REL);
	}
	if (mode & (8 | 16)) {
		hd6303_ps2_enqueue(0x11, HD_PS2_REL);
	}
}

void SuperIoDrawVideo(void *video, int width, int height)
{
	word *vmem = (word *)video;
	int visibleHeight = (height > 24) ? height - 24 : height;
	int cols = (HdVpu.hSize & 0x7f) + 1;
	int rowsOrLines = HdVpu.vSize + 1;
	int x0;
	int y0;
	int y;

	if (!hd6303_is_active()) {
		return;
	}

	if (cols < 1) {
		cols = 1;
	}
	if (cols > 64) {
		cols = 64;
	}
	if (rowsOrLines < 1) {
		rowsOrLines = 1;
	}

	memset(video, 0, width * visibleHeight * sizeof(word));

	x0 = (width - cols * 8) / 2;
	if (x0 < 0) {
		x0 = 0;
	}
	y0 = (visibleHeight - rowsOrLines) / 2;
	if (y0 < 0) {
		y0 = 0;
	}

	for (y = 0; y < rowsOrLines && y0 + y < visibleHeight; y++) {
		int xbyte;

		for (xbyte = 0; xbyte < cols && x0 + xbyte * 8 < width; xbyte++) {
			byte data;
			int bit;

			if (HdVpu.config & HD_VPU_GRF) {
				dword addr = (HdVpu.startAddr + y * cols + xbyte) & (HD6303_VRAM_SIZE - 1);
				data = HdVpu.vram[addr];
			} else {
				int charLine = y & 7;
				int row = y >> 3;
				dword addr = (HdVpu.startAddr + row * cols + xbyte) & (HD6303_VRAM_SIZE - 1);
				byte code = HdVpu.vram[addr];
				dword fontAddr = ((code & 0x7f) << 4) | ((code & 0x80) ? 8 : 0) | charLine;
				data = hdVideoRom ? hdVideoRom[fontAddr & 0x7ff] : 0;
			}

			if ((HdVpu.config & HD_VPU_CUR) &&
				xbyte == HdVpu.curPos &&
				y >= HdVpu.curLineStart &&
				y <= HdVpu.curLineEnd) {
				data = (HdVpu.config & HD_VPU_CURINV) ? (byte)~data : 0xff;
			}

			for (bit = 0; bit < 8 && x0 + xbyte * 8 + bit < width; bit++) {
				word pixel = (data & 0x80) ? PIXEL_ON : PIXEL_OFF;
				vmem[(y0 + y) * width + x0 + xbyte * 8 + bit] = pixel;
				data <<= 1;
			}
		}
	}
}

int SuperIoInit(void)
{
    int i;

    if (hd6303_is_active()) {
		hdBios = (byte *) loadHd6303BiosRom(4096);
		for (i = 0; i < HD6303_ROM_PAGES; i++) {
			hdRom[i] = (byte *) loadHd6303RomPage(i, HD6303_ROM_PAGE_SIZE);
		}
		hdVideoRom = (byte *) loadCharGenRom(2048);
		hdSdImage = loadHd6303SdImage(&hdSdImageSize);
		hdSdDirty = 0;
		memset(MEM, 0, HD6303_RAM_SIZE);
		hd6303_reset();
		PrinterPort.mode = PRINTER_NONE;
		return 0;
    }

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
	if (hd6303_is_active()) {
		unloadHd6303SdImage(hdSdImage, hdSdImageSize, hdSdDirty);
		hdSdImage = NULL;
		hdSdImageSize = 0;
		hdSdDirty = 0;
	} else {
		unloadRamDisk(vdiskSIZE);
	}

    return 0;
}

void SuperIoReset(void)
{
	if (hd6303_is_active()) {
		hd6303_reset();
		return;
	}

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
	if (hd6303_is_active()) {
		year = (year % 100) + 1000 * (1 + year / 100);
		MC6800MemWriteByte(0x40, 0);
		MC6800MemWriteByte(0x41, sec);
		MC6800MemWriteByte(0x42, min);
		MC6800MemWriteByte(0x43, hour);
		MC6800MemWriteByte(0x44, mday);
		MC6800MemWriteByte(0x45, mon + 1);
		MC6800MemWriteByte(0x46, year >> 8);
		MC6800MemWriteByte(0x47, year & 0xff);
		MC6800MemWriteByte(0xed00, 0xa5);
		MC6800MemWriteByte(0xed01, 0x5a);
		return;
	}

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

void SuperIoUpdate(void)
{
	if (hd6303_is_active()) {
		hd6303_ps2_update();
	}
}

O_INLINE int SuperIoReadByte(word a, byte *t)
{
    if (hd6303_is_active()) {
		return hd6303_read_byte(a, t);
    }

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
    if (hd6303_is_active()) {
		hd6303_write_byte(a, d);
		return 1;
    }

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
    if (hd6303_is_active()) {
		HdVpu.config |= HD_VPU_VBL;
		if (HdVpu.config & HD_VPU_IEN) {
			HdVpu.config |= HD_VPU_IRQ;
			hd6303_raise_interrupt(0);
		}
		if ((hdSimpleIo[0x08] & 0x41) == 0x41) {
			hdSimpleIo[0x08] |= 0x80;
			hd6303_raise_interrupt(10);
		}
		return;
    }

    tick50 = 0x80;
}
