# CPU68 provenance

Unmodified local vendor copy: John E. Kent CPU68, source header identifies
OpenCores December 2002 and the GNU public license. The original license
notice and revision history are retained. No more specific GPL version is
asserted here because the source header does not identify one.

SHA-256 of `cpu68.vhd`: `eec078252275f534d0916788401e810c09db9eedb4ecd926778521ed198eb7af`.

`../rtl/cpu6800.vhd` is the adapted classic MC6800 implementation: excludes
6801 additions, corrects classic CPX, TST and DAA behavior, and exposes debug
signals used by the differential tests. The original authorship remains.
The differential reference is the existing project's classic MC6800 C core.
The tests establish covered behavior, not exhaustive instruction/interrupt
compatibility. See the parent repository license for its C core and ROM assets.
