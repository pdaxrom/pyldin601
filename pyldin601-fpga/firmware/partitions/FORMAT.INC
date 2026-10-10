; Format only an unmounted FAT12 partition. Geometry is the proven profile;
; smaller volumes retain 4 KiB clusters and reduce total sectors. BPB is
; committed last, after both FATs and all 512 root entries are initialized.
format_number
    jsr find_number
    bcc format_found
    rts
format_found
    ldx PR
    ldaa 11,x
    cmpa #$ff
    beq format_unmounted
    ldaa #15
    rts
format_unmounted
    ldaa 9,x
    cmpa #1
    beq format_kind
    ldaa #9
    rts
format_kind
    ; 32,400 sectors, or the whole smaller partition (minimum 65 sectors).
    ldaa #$7e
    staa PE+1
    ldaa #$90
    staa PE
    tst 7,x
    bne format_size
    tst 6,x
    bne format_size
    ldaa 4,x
    suba #$90
    ldaa 5,x
    sbca #$7e
    bcc format_size
    ldaa 4,x
    staa PE
    ldaa 5,x
    staa PE+1
format_size
    tst PE+1
    bne format_enough
    ldaa PE
    cmpa #65
    bcc format_enough
    ldaa #4
    rts
format_enough
    jsr state_pointer
    ldaa PE
    staa 42,x
    ldaa PE+1
    staa 43,x
    ldx PS
    stx PP
    ldx #512
    stx PT
    jsr zero_memory
    clr PL
    jsr format_sector
    tsta
    beq format_metadata
    rts
format_metadata
    inc PL
format_clear
    ldx PS
    clr 0,x
    clr 1,x
    clr 2,x
    ldaa PL
    cmpa #1
    beq format_fat_seed
    cmpa #13
    bne format_write
format_fat_seed
    ldaa #$f8
    staa 0,x
    ldaa #$ff
    staa 1,x
    staa 2,x
format_write
    jsr format_sector
    tsta
    beq format_written
    rts
format_written
    inc PL
    ldaa PL
    cmpa #57
    bcs format_clear
    ldx #format_bpb
    stx PP
    ldx PS
    stx PT
    ldab #62
format_header
    ldx PP
    ldaa 0,x
    inx
    stx PP
    ldx PT
    staa 0,x
    inx
    stx PT
    decb
    bne format_header
    jsr state_pointer
    ldaa 42,x
    ldx PS
    staa 19,x
    jsr state_pointer
    ldaa 43,x
    ldx PS
    staa 20,x
    ldx PR
    ldaa 0,x
    ldx PS
    staa 28,x
    ldx PR
    ldaa 1,x
    ldx PS
    staa 29,x
    ldx PR
    ldaa 2,x
    ldx PS
    staa 30,x
    ldx PR
    ldaa 3,x
    ldx PS
    staa 31,x
    ; A per-format serial comes from native date and time, no fixed OEM test.
    ldaa $18
    staa 39,x
    ldaa $19
    staa 40,x
    ldaa $1a
    staa 41,x
    ldaa $1b
    staa 42,x
    ldaa PS+1
    adda #$fe
    staa PP+1
    ldaa PS
    adca #1
    staa PP
    ldx PP
    ldaa #$55
    staa 0,x
    ldaa #$aa
    staa 1,x
    clr PL
    jsr format_sector
    tsta
    beq format_complete
    rts
format_complete
    jsr bpb_validate
    bcc format_valid
    ldaa #9
    rts
format_valid
    ldx PR
    ldaa #1
    staa 21,x
    ldx PS
    ldaa 20,x
    ldx PR
    staa 14,x
    ldx PS
    ldaa 19,x
    ldx PR
    staa 15,x
    clra
    rts
format_sector
    jsr state_pointer
    stx PP
    ldaa PS
    staa 0,x
    ldaa PS+1
    staa 1,x
    ldx PR
    ldaa 0,x
    adda PL
    ldx PP
    staa 2,x
    ldx PR
    ldaa 1,x
    adca #0
    ldx PP
    staa 3,x
    ldx PR
    ldaa 2,x
    adca #0
    ldx PP
    staa 4,x
    ldx PR
    ldaa 3,x
    adca #0
    ldx PP
    staa 5,x
    ldaa #2
    int $e2
    rts
format_bpb
    db $eb,$3c,$90,"P601FAT "
    dw $0002
    db 8,1,0,2
    dw $0002,$907e
    db $f8,12,0,81,0,2,0
    db 0,0,0,0,0,0,0,0
    db $80,0,$29,0,0,0,0
    db "P601 DATA  ","FAT12   "
