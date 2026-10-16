; Paint row backends, ABI1. Ordinary relocatable PGM, <=8192 code+BSS.
; Enter at its PGM entry with A:B pointing to this ordinary-RAM record.
; Returns A=0 success, 1 invalid record/format. B/X and flags are scratch.
; No BIOS vectors, zero-page storage, hardware state or resident ownership.
PB_MAGIC equ 0
PB_ABI equ 2
PB_OPERATION equ 3
PB_KIND equ 4
PB_WIDTH equ 6
PB_SOURCE equ 8
PB_DEST equ 10
PB_BYTES equ 12
PB_IDLE equ 14
; Optional ordinary-RAM idle callback (0 disables), no args, B/X destroyed.
; It may drain PS/2 but must restore selectors and not reenter this backend.
PB_SIZE equ 16
PNT_MAGIC equ $504e
PNT_ABI equ 1
PNT_ENCODE equ 0
; Optional HAM operation1: WIDTH=1..320 pixels, BYTES initially points to
; three RGB666 seed bytes (0=black); BYTES returns the encoded pixel count.
; Apps fall back to operation0 when an older ABI1 HAM module rejects it.
PNT_PARTIAL equ 1
PNT_MONO320 equ 0
PNT_MONO640 equ 1
PNT_FOUR equ 2
PNT_INDEXED equ 3
PNT_HAM8 equ 4
