#include <stdio.h>
#include <string.h>
#include <time.h>

#define O_INLINE static inline

#include "core/mc6800.h"
#include "core/swiemu.h"
#include "core/devices.h"
#include "core/mc6845.h"
#include "core/i8272.h"
#include "core/keyboard.h"

#include "core/mc6800.c"
#include "core/devices.c"
#ifndef  ENABLE_INT17_EMULATOR
#include "core/floppy.c"
#include "core/i8272.c"
#endif
#include "core/swiemu.c"
#include "core/keyboard.c"
#include "core/mc6845.c"

void core_50Hz_irq(void)
{
    SuperIoSetTick50();
    MC6845CursorBlink();
    MC6800SetInterrupt(1);
}
