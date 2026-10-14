; A = number of eight-byte groups (zero is empty). Separate pointers permit
; banked cache transfers and overlapping panel-row copies on an MC6800.
copy_octets
    staa copy_blocks
    tsta
    beq copy_octets_done
copy_octet
    ldx src
    ldaa 0,x
    ldab 1,x
    ldx dst
    staa 0,x
    stab 1,x
    ldx src
    ldaa 2,x
    ldab 3,x
    ldx dst
    staa 2,x
    stab 3,x
    ldx src
    ldaa 4,x
    ldab 5,x
    ldx dst
    staa 4,x
    stab 5,x
    ldx src
    ldaa 6,x
    ldab 7,x
    ldx dst
    staa 6,x
    stab 7,x
    ldaa src+1
    adda #8
    staa src+1
    bcc copy_source_advanced
    inc src
copy_source_advanced
    ldaa dst+1
    adda #8
    staa dst+1
    bcc copy_target_advanced
    inc dst
copy_target_advanced
    dec copy_blocks
    bne copy_octet
copy_octets_done
    rts
