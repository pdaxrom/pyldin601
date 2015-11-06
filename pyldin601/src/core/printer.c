#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "core/mc6800.h"
#include "core/printer.h"

static int p_mode = PRINTER_NONE;

static byte port_dra = 0;
static byte port_drb = 0;
static byte port_cra = 0;
static byte port_crb = 0;

int printer_init(int mode)
{
    if (mode == PRINTER_SYSTEM) {
	mode = PRINTER_NONE;
    }
    p_mode = mode;

    return 0;
}

void printer_fini(void)
{
}

void printer_dra_wr(byte data)
{
    port_dra = data;
}

void printer_drb_wr(byte data)
{
    if (p_mode == PRINTER_FILE) {
	printer_put_char(data);
    } else if (p_mode == PRINTER_COVOX)
	Covox_Set(data);

    port_drb = data;
}

void printer_cra_wr(byte data)
{
    port_cra = data;
}

void printer_crb_wr(byte data)
{
    port_crb = data;
}

byte printer_dra_rd(void)
{
    if (p_mode == PRINTER_FILE)
	return 0x0;

    return port_dra;
}

byte printer_drb_rd(void)
{
    return port_drb;
}

byte printer_cra_rd(void)
{
    return port_cra;
}

byte printer_crb_rd(void)
{
    return port_crb;
}
