#pragma once

#include "core/types.h"

int				MC6800Init(void);
void			MC6800Reset(void);
int				MC6800Step(void);
int				MC6800Finish(void);

O_INLINE void	MC6800SetInterrupt(int l);
dword			MC6800GetCyclesCounter(void);
O_INLINE byte 	*MC6800GetCpuRam(void);

O_INLINE byte 	MC6800MemReadByte(word a);
O_INLINE void 	MC6800MemWriteByte(word a, byte d);

byte 			*allocateCpuRam(dword size);
