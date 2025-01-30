/*
 *
 * Pyldin-601 emulator version 3.1 for Linux,MSDOS,Win32
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2004
 *
 */

#include <stdio.h>
#include "core/mc6800.h"
#include "core/keyboard.h"

#ifdef __BIONIC__

static unsigned char BBPriv_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'1','2','3','4','5','6','7','8','9','0','-','=',0x7f,0xed,
	'#','1','2','3','(',')','_','-','+','@','[',']',0xc0,0xff,'*','4',
	'5','6','/',':',';','\'','"',';',0x27,'`',0xff,'\\','7','8','9','?',
	'!',',','.',',','.','/',0xff,0xff,0xff,' ',0xfc,0xc9,0xca,0xcb,0xcc,0xcd,
	0xce,0xcf,0xd0,0xd1,0xd2,0xff,0xfb,0xc5,0xc4,0xc8,0xff,0xc1,0xff,0xc2,0xff,0xc6,
	0xc3,0xc7,0xfa,0xf9,0xff,0xff,0xff,0xd3,0xd4,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char BBPriv_shift_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'1','2','3','4','5','6','7','8','9','0','-','=',0x7f,0xed,
	'#','%','^','=','[',']','{','}','+','@','[',']',0xc0,0xff,'*','`',
	'~','6','|',':',';','\'','"',';',0x27,'`',0xff,'\\','7','8','9','\\',
	'!','<','>',',','.','/',0xff,0xff,0xff,' ',0xfc,0xc9,0xca,0xcb,0xcc,0xcd,
	0xce,0xcf,0xd0,0xd1,0xd2,0xff,0xfb,0xc5,0xc4,0xc8,0xff,0xc1,0xff,0xc2,0xff,0xc6,
	0xc3,0xc7,0xfa,0xf9,0xff,0xff,0xff,0xd3,0xd4,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char BBPriv_sym_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'1','2','3','4','5','6','7','8','9','0','-','=',0xf9,0xed,
	0x1b,0xc4,0xed,'r',0xc9,0xca,0xcb,0xd2,0xd3,0xd4,'[',']',0xc0,0xff,0xc1,0xc3,
	0xc2,'f',0xcc,0xcd,0xce,'k','l',';',0x27,'`',0xff,'\\',0xfa,0xfb,0xfc,0xcf,
	0xd0,0xd1,'m',',','.','/',0xff,0xff,0xff,' ',0xfc,0xc9,0xca,0xcb,0xcc,0xcd,
	0xce,0xcf,0xd0,0xd1,0xd2,0xff,0xfb,0xc5,0xc4,0xc8,0xff,0xc1,0xff,0xc2,0xff,0xc6,
	0xc3,0xc7,0xfa,0xf9,0xff,0xff,0xff,0xd3,0xd4,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char BBPriv_sym_shift_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'1','2','3','4','5','6','7','8','9','0','-','=',0xf9,0xed,
	0x1b,0xc8,0xee,'r',0xd5,0xd6,0xd7,0xde,0xdf,0xe0,'[',']',0xc0,0xff,0xc5,0xc7,
	0xc6,'f',0xd8,0xd9,0xda,'k','l',';',0x27,'`',0xff,'\\',0xfa,0xfb,0xfc,0xdb,
	0xdc,0xdd,'m',',','.','/',0xff,0xff,0xff,' ',0xfc,0xc9,0xca,0xcb,0xcc,0xcd,
	0xce,0xcf,0xd0,0xd1,0xd2,0xff,0xfb,0xc5,0xc4,0xc8,0xff,0xc1,0xff,0xc2,0xff,0xc6,
	0xc3,0xc7,0xfa,0xf9,0xff,0xff,0xff,0xd3,0xd4,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char BBPriv_sym_ctrl_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'1','2','3','4','5','6','7','8','9','0','-','=',0xef,0xed,
	0x1b,0xf4,0xed,'r',0xe1,0xe2,0xe3,0xea,0xeb,0xec,'[',']',0xf0,0xff,0xf1,0xf3,
	0xf2,'f',0xe4,0xe5,0xe6,'k','l',';',0x27,'`',0xff,'\\',0xfa,0xfb,0xfc,0xe7,
	0xe8,0xe9,'m',',','.','/',0xff,0xff,0xff,' ',0xfc,0xc9,0xca,0xcb,0xcc,0xcd,
	0xce,0xcf,0xd0,0xd1,0xd2,0xff,0xfb,0xc5,0xc4,0xc8,0xff,0xc1,0xff,0xc2,0xff,0xc6,
	0xc3,0xc7,0xfa,0xf9,0xff,0xff,0xff,0xd3,0xd4,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

#endif

static unsigned char keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'1','2','3','4','5','6','7','8','9','0','-','=',0x7f,0xed,
	'q','w','e','r','t','y','u','i','o','p','[',']',0xc0,0xff,'a','s',
	'd','f','g','h','j','k','l',';',0x27,'`',0xff,'\\','z','x','c','v',
	'b','n','m',',','.','/',0xff,0xff,0xff,' ',0xfc,0xc9,0xca,0xcb,0xcc,0xcd,
	0xce,0xcf,0xd0,0xd1,0xd2,0xff,0xfb,0xc5,0xc4,0xc8,0xff,0xc1,0xff,0xc2,0xff,0xc6,
	0xc3,0xc7,0xfa,0xf9,0xff,0xff,0xff,0xd3,0xd4,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char cyr_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'1','2','3','4','5','6','7','8','9','0','-','=',0x7f,0xed,
	0xa9,0xb6,0xb3,0xaa,0xa5,0xad,0xa3,0xb8,0xb9,0xa7,0xb5,0xba,0xc0,0xff,0xb4,0xbb,
	0xa2,0xa0,0xaf,0xb0,0xae,0xab,0xa4,0xa6,0xbd,'[',0xff,'\\',0xbf,0xb7,0xb1,0xac,
	0xa8,0xb2,0xbc,0xa1,0xbe,'.',0xff,0xff,0xff,' ',0xfc,0xc9,0xca,0xcb,0xcc,0xcd,
	0xce,0xcf,0xd0,0xd1,0xd2,0xff,0xfb,0xc5,0xc4,0xc8,0xff,0xc1,0xff,0xc2,0xff,0xc6,
	0xc3,0xc7,0xfa,0xf9,0xff,0xff,0xff,0xd3,0xd4,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char Sh_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'!','@','#','$','%','^','&','*','(',')','_','+',0x7f,0xee,
	'Q','W','E','R','T','Y','U','I','O','P','{','}',0xc0,0xff,'A','S',
	'D','F','G','H','J','K','L',':','"','~',0xff,'|','Z','X','C','V',
	'B','N','M','<','>','?',0xff,0xff,0xff,0xfd,0xfc,0xd5,0xd6,0xd7,0xd8,0xd9,
	0xda,0xdb,0xdc,0xdd,0xde,0xff,0xfb,0xc5,0xc8,0xc8,0xff,0xc5,0xff,0xc6,0xff,0xc6,
	0xc7,0xc7,0xfa,0xf9,0xff,0xff,0xff,0xdf,0xe0,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char cyr_Sh_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'!','"','#',';','%',':','?','*','(',')','_','+',0x7f,0xee,
	0x89,0x96,0x93,0x8a,0x85,0x8d,0x83,0x98,0x99,0x87,0x95,0x9a,0xc0,0xff,0x94,0x9b,
	0x82,0x80,0x8f,0x90,0x8e,0x8b,0x84,0x86,0x9d,']',0xff,'/',0x9f,0x97,0x91,0x8c,
	0x88,0x92,0x9c,0x81,0x9e,',',0xff,0xff,0xff,0xfd,0xfc,0xd5,0xd6,0xd7,0xd8,0xd9,
	0xda,0xdb,0xdc,0xdd,0xde,0xff,0xfb,0xc5,0xc8,0xc8,0xff,0xc5,0xff,0xc6,0xff,0xc6,
	0xc7,0xc7,0xfa,0xf9,0xff,0xff,0xff,0xdf,0xe0,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char Ct_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'1',0,'3','4','5',0x1e,'7','8','9','0',0x1f,'=',0xef,0xed,
	0x11,0x17,0x5,0x12,0x14,0x19,0x15,0x9,0x0f,0x10,0x1b,0x1d,0xf0,0xff,0x1,0x13,
	0x4,0x6,0x7,0x8,0xa,0xb,0xc,';',0x27,'`',0xff,0x1c,0x1a,0x18,0x3,0x16,
	0x2,0xe,0xd,',','.','/',0xff,0xff,0xff,0xfe,0xfc,0xe1,0xe2,0xe3,0xe4,0xe5,
	0xe6,0xe7,0xe8,0xe9,0xea,0xff,0xfb,0xf5,0xf4,0xf8,0xff,0xf1,0xff,0xf2,0xff,0xf6,
	0xf3,0xf7,0xfa,0xf9,0xff,0xff,0xff,0xeb,0xec,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char Ct_Sh_keytable[]={
/*	 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f */
	0xff,0x1b,'1',0,'3','4','5',0x1e,'7','8','9','0',0x1f,'+',0xef,0xee,
	0x11,0x17,0x5,0x12,0x14,0x19,0x15,0x9,0x0f,0x10,0x1b,0x1d,0xf0,0xff,0x1,0x13,
	0x4,0x6,0x7,0x8,0xa,0xb,0xc,':','"','~',0xff,0x1c,0x1a,0x18,0x3,0x16,
	0x2,0xe,0xd,'<','>','?',0xff,0xff,0xff,0xfe,0xfc,0xe1,0xe2,0xe3,0xe4,0xe5,
	0xe6,0xe7,0xe8,0xe9,0xea,0xff,0xfb,0xf5,0xf8,0xf8,0xff,0xf5,0xff,0xf6,0xff,0xf6,
	0xf7,0xf7,0xfa,0xf9,0xff,0xff,0xff,0xeb,0xec,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
	0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static unsigned char keyReady = 0;
static unsigned char keyCode = 0;
static unsigned char flagKey = 0;
static unsigned char cyrMode=0;
static byte trigger = 0;

unsigned char getkeycode(int x, int y)
{
    unsigned char retc = 0xff;

    if (y < 40) {
	if (x < 13) retc = 0xff;
	else if (x < 31) retc = 0x01; //esc
	else if (x < 50) retc = 0x3b; //f1
	else if (x < 69) retc = 0x3c; //f2
	else if (x < 88) retc = 0x3d; //f3
	else if (x < 107) retc = 0x3e; //f4
	else if (x < 126) retc = 0x3f; //f5
	else if (x < 146) retc = 0x40; //f6
	else if (x < 164) retc = 0x41; //f7
	else if (x < 182) retc = 0x42; //f8
	else if (x < 201) retc = 0x43; //f9
	else if (x < 220) retc = 0x44; //f10
	else if (x < 239) retc = 0x57; //f11
	else if (x < 258) retc = 0x58; //f12
	else if (x < 277) retc = 0x47; //home
	else if (x < 295) retc = 0x4f; //end
	else if (x < 315) retc = 0x52; //insert
    } else if (y < 90) {
	if (x < 13) retc = 0xff;
	else if (x < 31) retc = 0x02; //1
	else if (x < 50) retc = 0x03; //2
	else if (x < 69) retc = 0x04; //3
	else if (x < 88) retc = 0x05; //4
	else if (x < 107) retc = 0x06; //5
	else if (x < 126) retc = 0x07; //6
	else if (x < 146) retc = 0x08; //7
	else if (x < 164) retc = 0x09; //8
	else if (x < 182) retc = 0x0a; //9
	else if (x < 201) retc = 0x0b; //0
	else if (x < 220) retc = 0x0c; //-
	else if (x < 239) retc = 0x0d; //=
	else if (x < 258) retc = 0x2b; ////
	else if (x < 277) retc = 0x0e; //backspace
	else if (x < 295) retc = 0x46; //lat/kir
	else if (x < 315) resetRequested();
    } else if (y < 125) {
	if (x < 21) retc = 0x0f; //TAB
	else if (x < 40) retc = 0x10; //Q
	else if (x < 59) retc = 0x11; //W
	else if (x < 78) retc = 0x12; //E
	else if (x < 97) retc = 0x13; //R
	else if (x < 115) retc = 0x14; //T
	else if (x < 135) retc = 0x15; //Y
	else if (x < 154) retc = 0x16; //U
	else if (x < 173) retc = 0x17; //I
	else if (x < 192) retc = 0x18; //O
	else if (x < 211) retc = 0x19; //P
	else if (x < 230) retc = 0x29; //~
	else if (x < 287) retc = 0x1c; //enter
	else if (x < 306) retc = 0x48; //up
    } else if (y < 160) {
	if (x < 27) { 
	    if (flagKey & 1)  
		flagKey &= ~1; 
	    else 
		flagKey |= 1;
	} else if (x < 46) retc = 0x1e; //A
	else if (x < 65) retc = 0x1f; //S
	else if (x < 84) retc = 0x20; //D
	else if (x < 102) retc = 0x21; //F
	else if (x < 122) retc = 0x22; //G
	else if (x < 140) retc = 0x23; //H
	else if (x < 159) retc = 0x24; //J
	else if (x < 178) retc = 0x25; //K
	else if (x < 197) retc = 0x26; //L
	else if (x < 216) retc = 0x27; //;
	else if (x < 235) retc = 0x28; //'
	else if (x < 254) retc = 0x1a; //[
	else if (x < 273) retc = 0x1b; //]
	else if (x < 292) retc = 0x4b; //left
	else if (x < 311) retc = 0x4d; //right
    } else if (y < 195) {
	if (x < 36) { 
	    if (flagKey & 2) 
		flagKey &= ~2;
	    else 
		flagKey |= 2;
	} else if (x < 55) retc = 0x2c; //Z
	else if (x < 74) retc = 0x2d; //X
	else if (x < 93) retc = 0x2e; //C
	else if (x < 112) retc = 0x2f; //V
	else if (x < 131) retc = 0x30; //B
	else if (x < 150) retc = 0x31; //N
	else if (x < 169) retc = 0x32; //M
	else if (x < 188) retc = 0x33; //,
	else if (x < 207) retc = 0x34; //.
	else if (x < 226) retc = 0x35; ///
	else if (x < 264) { 
	    if (flagKey & 2) 
		flagKey &= ~2;
	    else 
		flagKey |= 2;
	} else if (x < 284) retc = 0x3a; //capslock
	else if (x < 302) retc = 0x50; //down
    } else if (y < 230) {
	if (x > 43 && x < 249) 
	    retc = 0x39; //space
    }

    return retc;
}

void KBDVirtKeyDown(int x, int y)
{
    unsigned int tempKeyCode = getkeycode(x, y);
    if (tempKeyCode == 0xff) {
    	return;
    }
    MC6800SetInterrupt(1);
    keyReady--;
    switch(flagKey | cyrMode) {
		case 1:
		case 5: keyCode=Ct_keytable[tempKeyCode]; break;
		case 3:
		case 7: keyCode=Ct_Sh_keytable[tempKeyCode]; break;
		case 2: keyCode=Sh_keytable[tempKeyCode]; break;
		case 4: keyCode=cyr_keytable[tempKeyCode]; break;
		case 6: keyCode=cyr_Sh_keytable[tempKeyCode]; break;
		default: keyCode=keytable[tempKeyCode]; break;
    }
}

void KBDVirtKeyUp(void)
{
    keyReady = 0;
}

void KBDKeyDown(unsigned int tempKeyCode)
{
    if (tempKeyCode == 0xff) {
    	return;
    }
    MC6800SetInterrupt(1);
    keyReady--;

#ifdef __BIONIC__

    if (flagKey & 8) {
		switch(flagKey & 7) {
			case 2:	keyCode = BBPriv_shift_keytable[tempKeyCode]; return;
			default:	keyCode = BBPriv_keytable[tempKeyCode]; return;
		}
    }

    if (flagKey & 16) {
		switch(flagKey & 7) {
			case 1:
			case 5:	keyCode = BBPriv_sym_ctrl_keytable[tempKeyCode]; return;
			case 2:
			case 6:	keyCode = BBPriv_sym_shift_keytable[tempKeyCode]; return;
			default:	keyCode = BBPriv_sym_keytable[tempKeyCode]; return;
		}
    }

#endif

    switch(flagKey | cyrMode) {
		case 1:
		case 5: keyCode=Ct_keytable[tempKeyCode]; break;
		case 3:
		case 7: keyCode=Ct_Sh_keytable[tempKeyCode]; break;
		case 2: keyCode=Sh_keytable[tempKeyCode]; break;
		case 4: keyCode=cyr_keytable[tempKeyCode]; break;
		case 6: keyCode=cyr_Sh_keytable[tempKeyCode]; break;
		default: keyCode=keytable[tempKeyCode]; break;
    }
}

void KBDKeyUp(void)
{
    keyReady = 0;
}

void KBDModKeyDown(byte mode)
{
    flagKey |= mode;
}

void KBDModKeyUp(byte mode)
{
    flagKey &= ~mode;
}

unsigned char KBDCheckKey()
{
    if (keyReady) {
		trigger = ~trigger;
		if (trigger) {
			return 0;
		} else {
			return 0x80;
		}
    }
    
    return 0;
}

unsigned char KBDReadKey()
{
    trigger = 0;
    if (keyReady == 0) {
    	return 0xff;
    }
    return keyCode;
}

void KBDSetCyrMode(byte mode)
{
    cyrMode = mode;
}
