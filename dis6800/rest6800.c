#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <inttypes.h>

typedef struct {
   uint8_t opcode;
   uint8_t numoperands;
   char name[6];
   uint8_t mode;
   uint8_t numcycles;
} opcodeinfo;
   
/* 6800 ADDRESSING MODES */
#define INH 0        
#define DIR 1
#define IND 2
#define REL 3
#define EXT 4
#define IMM 5

static opcodeinfo opcodes[]={
	{ 0x01,	0,	"nop",	INH,	2 },
	{ 0x06,	0,	"tap",	INH,	2 },
	{ 0x07,	0,	"tpa",	INH,	2 },
	{ 0x08,	0,	"inx",	INH,	3 },
	{ 0x09,	0,	"dex",	INH,	3 },
	{ 0x0A,	0,	"clv",	INH,	2 },
	{ 0x0B,	0,	"sev",	INH,	2 },
	{ 0x0C,	0,	"clc",	INH,	2 },
	{ 0x0D,	0,	"sec",	INH,	2 },
	{ 0x0E,	0,	"cli",	INH,	2 },
	{ 0x0F,	0,	"sei",	INH,	2 },
	{ 0x10,	0,	"sba",	INH,	2 },
	{ 0x11,	0,	"cba",	INH,	2 },
	{ 0x16,	0,	"tab",	INH,	2 },
	{ 0x17,	0,	"tba",	INH,	2 },
	{ 0x19,	0,	"daa",	INH,	2 },
	{ 0x1B,	0,	"aba",	INH,	2 },
	{ 0x20,	1,	"bra",	REL,	3 },
	{ 0x22,	1,	"bhi",	REL,	3 },
	{ 0x23,	1,	"bls",	REL,	3 },
	{ 0x24,	1,	"bcc",	REL,	3 },
	{ 0x25,	1,	"bcs",	REL,	3 },
	{ 0x26,	1,	"bne",	REL,	3 },
	{ 0x27,	1,	"beq",	REL,	3 },
	{ 0x28,	1,	"bvc",	REL,	3 },
	{ 0x29,	1,	"bvs",	REL,	3 },
	{ 0x2A,	1,	"bpl",	REL,	3 },
	{ 0x2B,	1,	"bmi",	REL,	3 },
	{ 0x2C,	1,	"bge",	REL,	3 },
	{ 0x2D,	1,	"blt",	REL,	3 },
	{ 0x2E,	1,	"bgt",	REL,	3 },
	{ 0x2F,	1,	"ble",	REL,	3 },
	{ 0x30,	0,	"tsx",	INH,	3 },
	{ 0x31,	0,	"ins",	INH,	3 },
	{ 0x32,	0,	"pula",	INH,	4 },
	{ 0x33,	0,	"pulb",	INH,	4 },
	{ 0x34,	0,	"des",	INH,	3 },
	{ 0x35,	0,	"txs",	INH,	3 },
	{ 0x36,	0,	"psha",	INH,	3 },
	{ 0x37,	0,	"pshb",	INH,	3 },
	{ 0x39,	0,	"rts",	INH,	5 },
	{ 0x3B,	0,	"rti",	INH,	12 },
	{ 0x3E,	0,	"wai",	INH,	14 },
	{ 0x3F,	1,	"int",	DIR,	12 },
	{ 0x40,	0,	"nega",	INH,	2 },
	{ 0x43,	0,	"coma",	INH,	2 },
	{ 0x44,	0,	"lsra",	INH,	2 },
	{ 0x46,	0,	"rora",	INH,	2 },
	{ 0x47,	0,	"asra",	INH,	2 },
	{ 0x48,	0,	"asla",	INH,	2 },
	{ 0x49,	0,	"rola",	INH,	2 },
	{ 0x4A,	0,	"deca",	INH,	2 },
	{ 0x4C,	0,	"inca",	INH,	2 },
	{ 0x4D,	0,	"tsta",	INH,	2 },
	{ 0x4F,	0,	"clra",	INH,	2 },
	{ 0x50,	0,	"negb",	INH,	2 },
	{ 0x53,	0,	"comb",	INH,	2 },
	{ 0x54,	0,	"lsrb",	INH,	2 },
	{ 0x56,	0,	"rorb",	INH,	2 },
	{ 0x57,	0,	"asrb",	INH,	2 },
	{ 0x58,	0,	"aslb",	INH,	2 },
	{ 0x59,	0,	"rolb",	INH,	2 },
	{ 0x5A,	0,	"decb",	INH,	2 },
	{ 0x5C,	0,	"incb",	INH,	2 },
	{ 0x5D,	0,	"tstb",	INH,	2 },
	{ 0x5F,	0,	"clrb",	INH,	2 },
	{ 0x60,	1,	"neg",	IND,	6 },
	{ 0x63,	1,	"com",	IND,	6 },
	{ 0x64,	1,	"lsr",	IND,	6 },
	{ 0x66,	1,	"ror",	IND,	6 },
	{ 0x67,	1,	"asr",	IND,	6 },
	{ 0x68,	1,	"asl",	IND,	6 },
	{ 0x69,	1,	"rol",	IND,	6 },
	{ 0x6A,	1,	"dec",	IND,	6 },
	{ 0x6C,	1,	"inc",	IND,	6 },
	{ 0x6D,	1,	"tst",	IND,	6 },
	{ 0x6E,	1,	"jmp",	IND,	3 },
	{ 0x6F,	1,	"clr",	IND,	6 },
	{ 0x70,	2,	"neg",	EXT,	6 },
	{ 0x73,	2,	"com",	EXT,	6 },
	{ 0x74,	2,	"lsr",	EXT,	6 },
	{ 0x76,	2,	"ror",	EXT,	6 },
	{ 0x77,	2,	"asr",	EXT,	6 },
	{ 0x78,	2,	"asl",	EXT,	6 },
	{ 0x79,	2,	"rol",	EXT,	6 },
	{ 0x7A,	2,	"dec",	EXT,	6 },
	{ 0x7C,	2,	"inc",	EXT,	6 },
	{ 0x7D,	2,	"tst",	EXT,	6 },
	{ 0x7E,	2,	"jmp",	EXT,	3 },
	{ 0x7F,	2,	"clr",	EXT,	6 },
	{ 0x80,	1,	"suba",	IMM,	2 },
	{ 0x81,	1,	"cmpa",	IMM,	2 },
	{ 0x82,	1,	"sbca",	IMM,	2 },
	{ 0x84,	1,	"anda",	IMM,	2 },
	{ 0x85,	1,	"bita",	IMM,	2 },
	{ 0x86,	1,	"ldaa",	IMM,	2 },
	{ 0x88,	1,	"eora",	IMM,	2 },
	{ 0x89,	1,	"adca",	IMM,	2 },
	{ 0x8A,	1,	"oraa",	IMM,	2 },
	{ 0x8B,	1,	"adda",	IMM,	2 },
	{ 0x8C,	2,	"cpx",	IMM,	4 },
	{ 0x8D,	1,	"bsr",	REL,	6 },
	{ 0x8E,	2,	"lds",	IMM,	3 },
	{ 0x90,	1,	"suba",	DIR,	3 },
	{ 0x91,	1,	"cmpa",	DIR,	3 },
	{ 0x92,	1,	"sbca",	DIR,	3 },
	{ 0x94,	1,	"anda",	DIR,	3 },
	{ 0x95,	1,	"bita",	DIR,	3 },
	{ 0x96,	1,	"ldaa",	DIR,	3 },
	{ 0x97,	1,	"staa",	DIR,	3 },
	{ 0x98,	1,	"eora",	DIR,	3 },
	{ 0x99,	1,	"adca",	DIR,	3 },
	{ 0x9A,	1,	"oraa",	DIR,	3 },
	{ 0x9B,	1,	"adda",	DIR,	3 },
	{ 0x9C,	1,	"cpx",	DIR,	5 },
	{ 0x9E,	1,	"lds",	DIR,	4 },
	{ 0x9F,	1,	"sts",	DIR,	4 },
	{ 0xA0,	1,	"suba",	IND,	4 },
	{ 0xA1,	1,	"cmpa",	IND,	4 },
	{ 0xA2,	1,	"sbca",	IND,	4 },
	{ 0xA4,	1,	"anda",	IND,	4 },
	{ 0xA5,	1,	"bita",	IND,	4 },
	{ 0xA6,	1,	"ldaa",	IND,	4 },
	{ 0xA7,	1,	"staa",	IND,	4 },
	{ 0xA8,	1,	"eora",	IND,	4 },
	{ 0xA9,	1,	"adca",	IND,	4 },
	{ 0xAA,	1,	"oraa",	IND,	4 },
	{ 0xAB,	1,	"adda",	IND,	4 },
	{ 0xAC,	1,	"cpx",	IND,	6 },
	{ 0xAD,	1,	"jsr",	IND,	6 },
	{ 0xAE,	1,	"lds",	IND,	5 },
	{ 0xAF,	1,	"sts",	IND,	5 },
	{ 0xB0,	2,	"suba",	EXT,	4 },
	{ 0xB1,	2,	"cmpa",	EXT,	4 },
	{ 0xB2,	2,	"sbca",	EXT,	4 },
	{ 0xB4,	2,	"anda",	EXT,	4 },
	{ 0xB5,	2,	"bita",	EXT,	4 },
	{ 0xB6,	2,	"ldaa",	EXT,	4 },
	{ 0xB7,	2,	"staa",	EXT,	4 },
	{ 0xB8,	2,	"eora",	EXT,	4 },
	{ 0xB9,	2,	"adca",	EXT,	4 },
	{ 0xBA,	2,	"oraa",	EXT,	4 },
	{ 0xBB,	2,	"adda",	EXT,	4 },
	{ 0xBC,	2,	"cpx",	EXT,	6 },
	{ 0xBD,	2,	"jsr",	EXT,	6 },
	{ 0xBE,	2,	"lds",	EXT,	5 },
	{ 0xBF,	2,	"sts",	EXT,	5 },
	{ 0xC0,	1,	"subb",	IMM,	2 },
	{ 0xC1,	1,	"cmpb",	IMM,	2 },
	{ 0xC2,	1,	"sbcb",	IMM,	2 },
	{ 0xC4,	1,	"andb",	IMM,	2 },
	{ 0xC5,	1,	"bitb",	IMM,	2 },
	{ 0xC6,	1,	"ldab",	IMM,	2 },
	{ 0xC8,	1,	"eorb",	IMM,	2 },
	{ 0xC9,	1,	"adcb",	IMM,	2 },
	{ 0xCA,	1,	"orab",	IMM,	2 },
	{ 0xCB,	1,	"addb",	IMM,	2 },
	{ 0xCE,	2,	"ldx",	IMM,	3 },
	{ 0xD0,	1,	"subb",	DIR,	3 },
	{ 0xD1,	1,	"cmpb",	DIR,	3 },
	{ 0xD2,	1,	"sbcb",	DIR,	3 },
	{ 0xD4,	1,	"andb",	DIR,	3 },
	{ 0xD5,	1,	"bitb",	DIR,	3 },
	{ 0xD6,	1,	"ldab",	DIR,	3 },
	{ 0xD7,	1,	"stab",	DIR,	3 },
	{ 0xD8,	1,	"eorb",	DIR,	3 },
	{ 0xD9,	1,	"adcb",	DIR,	3 },
	{ 0xDA,	1,	"orab",	DIR,	3 },
	{ 0xDB,	1,	"addb",	DIR,	3 },
	{ 0xDE,	1,	"ldx",	DIR,	4 },
	{ 0xDF,	1,	"stx",	DIR,	4 },
	{ 0xE0,	1,	"subb",	IND,	4 },
	{ 0xE1,	1,	"cmpb",	IND,	4 },
	{ 0xE2,	1,	"sbcb",	IND,	4 },
	{ 0xE4,	1,	"andb",	IND,	4 },
	{ 0xE5,	1,	"bitb",	IND,	4 },
	{ 0xE6,	1,	"ldab",	IND,	4 },
	{ 0xE7,	1,	"stab",	IND,	4 },
	{ 0xE8,	1,	"eorb",	IND,	4 },
	{ 0xE9,	1,	"adcb",	IND,	4 },
	{ 0xEA,	1,	"orab",	IND,	4 },
	{ 0xEB,	1,	"addb",	IND,	4 },
	{ 0xEE,	1,	"ldx",	IND,	5 },
	{ 0xEF,	1,	"stx",	IND,	5 },
	{ 0xF0,	2,	"subb",	EXT,	4 },
	{ 0xF1,	2,	"cmpb",	EXT,	4 },
	{ 0xF2,	2,	"sbcb",	EXT,	4 },
	{ 0xF4,	2,	"andb",	EXT,	4 },
	{ 0xF5,	2,	"bitb",	EXT,	4 },
	{ 0xF6,	2,	"ldab",	EXT,	4 },
	{ 0xF7,	2,	"stab",	EXT,	4 },
	{ 0xF8,	2,	"eorb",	EXT,	4 },
	{ 0xF9,	2,	"adcb",	EXT,	4 },
	{ 0xFA,	2,	"orab",	EXT,	4 },
	{ 0xFB,	2,	"addb",	EXT,	4 },
	{ 0xFE,	2,	"ldx",	EXT,	5 },
	{ 0xFF,	2,	"stx",	EXT,	4 },
};

struct symbol {
    uint16_t		addr;
    int			isCode;
    struct symbol	*prev;
};

#define FLAG_CMD	1

static uint8_t MEM[65536];
static uint8_t MAP[65536];

opcodeinfo *getOpCode(uint8_t opcode)
{
    int i;

    for (i = 0; i < sizeof(opcodes)/sizeof(opcodeinfo); i++) {
	if (opcodes[i].opcode == opcode) {
	    return &opcodes[i];
	}
    }

    return NULL;
}

struct symbol *findsymbol(struct symbol *syms, uint16_t addr)
{
    while(syms) {
	if (syms->addr == addr) {
	    return syms;
	}
	syms = syms->prev;
    }
    return NULL;
}

uint16_t getsymbols(struct symbol **syms, uint8_t *mem, uint16_t start_addr, uint16_t end_addr, uint8_t *map)
{
    int flag = 1;
    uint16_t addr = start_addr;

    while (addr < end_addr) {
	opcodeinfo *op;

	struct symbol *sym = findsymbol(*syms, addr);
	if (sym) {
	    flag |= sym->isCode;
	}
	if (map) {
	    if (map[addr] == 'C' || flag) {
		flag |= FLAG_CMD;
	    }
	}

	if (!flag) {
	    addr += 1;
	    continue;
	}

	op = getOpCode(mem[addr]);
	if (!op) {
	    flag = 0;
	    addr += 1;
	    continue;
	}

	if (op->numoperands) {
	    int ok = 0;
	    uint16_t d = (op->numoperands == 1) ? mem[addr + 1] : ((mem[addr + 1] << 8) | mem[addr + 2]);

	    switch (op->mode) {
		case DIR:
		    if (op->opcode != 0x3F) { // int
			ok = 1;
		    }
		    break;
		case REL:
		    ok = 1;
		    d = ((char)d) + addr + op->numoperands + 1;
		    break;
		case EXT:
		    ok = 1;
		    break;
		case IMM:
		    if (op->numoperands == 2) {
			if (d >= start_addr && d < end_addr) {
			    ok = 1;
			}
		    }
		    break;
	    }
	    if (ok) {
		int new_addr = 0;
		struct symbol *tmp = findsymbol(*syms, d);
		if (!tmp) {
		    tmp = malloc(sizeof(struct symbol));
		    tmp->addr = d;
		    tmp->prev = NULL;
		    tmp->prev = *syms;
		    *syms = tmp;
		    new_addr = 1;
		}
	
		if (op->mode == REL || !strcmp(op->name, "jmp") ||
		    !strcmp(op->name, "jsr")) {
//printf("-->>L%04X\n", d);
		    tmp->isCode = 1;
		    if (new_addr) {
//fprintf(stderr, "check addr %04X\n", d);
			getsymbols(syms, mem, d, end_addr, map);
		    }
		} else {
		    tmp->isCode = 0;
		}
	    }
	}
	addr += op->numoperands + 1;

	if (!strcmp(op->name, "jmp") ||
	    !strcmp(op->name, "bra") ||
	    !strcmp(op->name, "rts") ||
	    !strcmp(op->name, "rti")) {
	    flag = 0;
	}
    }

    return addr;
}

void exportlist(FILE *out, struct symbol *syms, uint16_t start_addr, uint16_t end_addr)
{
    while (syms) {
	if ((syms->addr < start_addr) || (syms->addr >= end_addr)) {
	    if (syms->addr < 0x100) {
		fprintf(out, "L%02X  \t\tEQU\t$%02X\n", syms->addr, syms->addr);
	    } else {
		fprintf(out, "L%04X\t\tEQU\t$%04X\n", syms->addr, syms->addr);
	    }
	}
	syms = syms->prev;
    }
}

uint16_t disassembly(FILE *out, struct symbol *syms, uint8_t *mem, uint16_t start_addr, uint16_t end_addr, uint8_t *map)
{
    int flag = 1;
    uint16_t addr = start_addr;

    while (addr < end_addr) {
	opcodeinfo *op;
	struct symbol *sym = findsymbol(syms, addr);
	if (sym) {
	    flag |= sym->isCode;
	    fprintf(out, "L%04X\t", sym->addr);
	} else {
	    fprintf(out, "\t");
	}
	if (map) {
	    if (map[addr] == 'C' || flag) {
		flag |= FLAG_CMD;
	    }
	}

	op = getOpCode(mem[addr]);

	if (!flag || !op) {
	    fprintf(out, "\tdb\t$%02X\t; '%c'\n", mem[addr], (mem[addr] >= 32 && mem[addr] <= 0x7F) ? mem[addr] : '.');
	    flag = 0;
	    addr += 1;
	    continue;
	}

	fprintf(out, "\t%s", op->name);

	if (op->numoperands) {
	    char d_s[128];
	    uint16_t d = (op->numoperands == 1) ? mem[addr + 1] : ((mem[addr + 1] << 8) | mem[addr + 2]);
	    if (op->numoperands == 1) {
		sprintf(d_s, "%02X", d);
	    } else {
		sprintf(d_s, "%04X", d);
	    }
	
	    switch (op->mode) {
		case DIR:
		    sym = findsymbol(syms, d);
		    if (sym && op->opcode != 63) {
			fprintf(out, "\tL%s", d_s);
		    } else {
			fprintf(out, "\t$%s", d_s);
		    }
		    break;
		case IND:
		    fprintf(out, "\t$%02X,x", d);
		    break;
		case REL:
		    sym = findsymbol(syms, ((char)d) + addr + op->numoperands + 1);
		    if (sym) {
			fprintf(out, "\tL%04X", sym->addr);
		    } else {
			fprintf(out, "\t$%04X", ((char)d) + addr + op->numoperands + 1);
		    }
		    break;
		case EXT:
		    sym = findsymbol(syms, d);
		    if (sym) {
			fprintf(out, "\tL%s", d_s);
		    } else {
			fprintf(out, "\t$%s", d_s);
		    }
		    break;
		case IMM:
		    sym = findsymbol(syms, d);
		    if (sym && op->numoperands == 2 &&
			sym->addr >= start_addr &&
			sym->addr < end_addr) {
			fprintf(out, "\t#L%s\t; constant?", d_s);
		    } else {
			fprintf(out, "\t#$%s%s", d_s, (op->numoperands == 2) ? "\t; external address?" : "");
		    }
		    break;
	    }
	}
	fprintf(out, "\n");

	if (!strcmp(op->name, "rts") ||
	    !strcmp(op->name, "jmp")) {
	    fprintf(out, "\n");
	}

	if (!strcmp(op->name, "jmp") ||
	    !strcmp(op->name, "bra") ||
	    !strcmp(op->name, "rts") ||
	    !strcmp(op->name, "rti")) {
	    flag = 0;
	}

	addr += op->numoperands + 1;
    }

    return addr;
}

void usage(char *app)
{
    fprintf(stderr, "Usage: %s [-h][-m mapfile][-s startaddr][-o outputfile] inputfile\n", app);
    exit(0);
}

int main(int argc, char *argv[])
{
    extern char *optarg;
    extern int optind, optopt, opterr;
    int c;
    uint16_t startaddr = 0, length;
    int use_map = 0;

    FILE *srcFile = NULL;
    FILE *dstFile = stdout;
    FILE *mapFile = NULL;

    while ((c = getopt(argc, argv, ":ho:s:m:")) != -1)
    {
        switch (c)
        {
	case 'h':
	    usage(argv[0]);
	    break;
        case 'o':
	    dstFile = fopen(optarg, "wb");
	    if (!dstFile) {
		fprintf(stderr, "Can't open output file!\n");
		return 1;
	    }
            break;
        case 'm':
	    use_map = 1;
	    mapFile = fopen(optarg, "rb");
	    if (!mapFile) {
		fprintf(stderr, "Can't open map file!\n");
		return 1;
	    }
	    fread(MAP, 1, sizeof(MAP), mapFile);
	    fclose(mapFile);
            break;
	case 's': {
		int tmp;
	        sscanf(optarg, "%x", &tmp);
		startaddr = tmp;
	    }
	    break;
        default:
	    usage(argv[0]);
            break;
        }
    }

    if (optind == argc)
	usage(argv[0]);

    for ( ; optind < argc; optind++) {
	fprintf(dstFile, ";\n; %s\n;\n", argv[optind]);
	srcFile = fopen(argv[optind], "rb");
	if (!srcFile) {
	    fprintf(stderr, "Can't open input file!\n");
	    return 1;
	}
	length = fread(MEM + startaddr, 1, sizeof(MEM) - startaddr, srcFile);
	fclose(srcFile);

	struct symbol *syms = NULL;

	fprintf(stderr, "Pass 1: get symbols\n");

	getsymbols(&syms, MEM, startaddr, startaddr + length, use_map ? MAP : NULL);
	
//	while (syms) {
//	    fprintf(dstFile, "%04X\n", syms->addr);
//	    syms = syms->prev;
//	}

	fprintf(stderr, "Pass 2: disassembly\n");

	exportlist(dstFile, syms, startaddr, startaddr + length);

	fprintf(dstFile, "\n\t\torg\t$%X\n\n", startaddr);

	disassembly(dstFile, syms, MEM, startaddr, startaddr + length, use_map ? MAP : NULL);

	fprintf(dstFile, "\n\n\n");

	break;
    }

    fclose(dstFile);

    return 0;
}
