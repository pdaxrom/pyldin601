#ifndef _MC6800_H_
#define _MC6800_H_

#include "core/types.h"

int	mc6800Init(void);
void	mc6800Reset(void);
int	mc6800Step(void);
int	mc6800Finish(void);

O_INLINE void	mc6800SetInterrupt(int l);
O_INLINE dword	mc6800GetCyclesCounter(void);
O_INLINE byte 	*mc6800GetCpuRam(void);

O_INLINE byte mc6800MemReadByte(word a);
O_INLINE void mc6800MemWriteByte(word a, byte d);

byte *allocateCpuRam(dword size);
#endif
