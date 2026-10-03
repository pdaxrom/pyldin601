HD6303 tests for classic Pyldin-601 / 601A FPGA

Cold boot, select model 1/2, then CPU 2 (HD6303).
Both boot menus wait 10 seconds; Enter selects their defaults.
In UniDOS type:
  B:
  HDTEST
  HDMUL
  HDSLEEP

HDTEST checks extended instructions, every documented addressing mode,
registers, CCR, memory writes, stack bytes and stack balance.
It saves/restores direct-page bytes $80/$81 and masks IRQ while using them.
Failure prints the case ID, actual and expected registers/CCR.

HDMUL checks all 65536 unsigned A/B products. Expected products are
calculated by byte additions, independently of MUL. It verifies C from
product bit 7, preservation of H/I/N/Z/V and preservation of X/SP.
This test takes several seconds; normal PAL interrupts remain enabled.

HDSLEEP checks 32 SLP wakes with IRQ enabled and 32 with IRQ masked.
The normal PAL IRQ is used. D, X, CCR and SP must survive each wake.
Video continues. Time can lag briefly during the masked phase.

All tests print PASS or FAIL and terminate back to UniDOS.
MC6800 mode prints SKIP before executing any HD6303 instructions.
No test reads or writes disk files. ASM sources are included on B.

TRAP and external NMI need separate simulation tests; these programs do
not replace the ROM vectors or change locked ROM pages.
