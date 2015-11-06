#ifndef _PRINTER_H_
#define _PRINTER_H_

#define PRINTER_NONE	0
#define PRINTER_FILE	1
#define PRINTER_SYSTEM	2
#define PRINTER_COVOX	3

int  printer_init(int mode);
void printer_fini(void);

void printer_dra_wr(byte data);
void printer_drb_wr(byte data);
void printer_cra_wr(byte data);
void printer_crb_wr(byte data);

byte printer_dra_rd(void);
byte printer_drb_rd(void);
byte printer_cra_rd(void);
byte printer_crb_rd(void);

void printer_put_char(byte data);
void Covox_Set(byte val);

#endif
