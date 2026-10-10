; The native monitor breakpoint abandons its SWI frame instead of using RTI.
; Account for return address, E6F1, E6F0 and the seven hardware frame bytes.
; Entry fixed at F800 for both BIOS models; the monitor remains in ROM page 8.
    ins
    ins
    ins
    ins
    ins
    ins
    ins
    ins
    ins
    ins
    ins
    dec indos
    jsr MON_REGDUMP
    jmp MON_LOOP
