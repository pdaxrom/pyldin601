# CPU68 provenance

Unmodified local vendor copy: John E. Kent CPU68, source header identifies
OpenCores December 2002 and the GNU public license. The original license
notice and revision history are retained. No more specific GPL version is
asserted here because the source header does not identify one.

SHA-256 of `cpu68.vhd`: `eec078252275f534d0916788401e810c09db9eedb4ecd926778521ed198eb7af`.

`../rtl/cpu6800.vhd` is the adapted MC6800/HD6303 ISA implementation.
The external hd6303_en input defaults to MC6800 and gates all additions.
It corrects classic CPX, TST, DAA, CLR and CCR behavior,
interrupt-vector latching, and reset/WAI/NMI masks. Production hardware leaves the legacy test_alu/test_cc outputs unconnected;
no diagnostic CPU control or UART recorder is included. Differential tests
add register observation ports only to a simulation copy. The original authorship remains.
The differential reference is the existing project's MC6800/HD6303 C core.
HD6303 flags, SLP and undefined opcode TRAP also use the original Hitachi
data sheet; scope and results are in [HD6303.md](../audit/HD6303.md).
The tests establish covered behavior, not exhaustive instruction/interrupt
compatibility. Results and reference limitations are documented in
[CPU-CONFORMANCE.md](../audit/CPU-CONFORMANCE.md). See the parent
repository license for its C core and ROM assets.
