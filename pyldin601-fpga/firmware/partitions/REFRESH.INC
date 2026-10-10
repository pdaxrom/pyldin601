; Rescan without invalidating any mounted drive. Mounted start, count, type
; and mounted filesystem geometry must be unchanged. Roll back all records on error.
refresh
    tst PF
    bne refresh_installed
    jmp install_parts
refresh_installed
    ; Allocate the rollback copy above the relocated stack through the native
    ; heap API. No operation below allocates or marks resident memory.
    jsr state_pointer
    ldaa $ee1e
    staa 60,x
    ldaa $ee1f
    staa 61,x
    ldx #768
    clrb
    int $2a
    cpx #0
    bne refresh_allocated
    ldaa #6
    rts
refresh_allocated
    stx PR
    jsr state_pointer
    ldaa PR
    staa 62,x
    ldaa PR+1
    staa 63,x
    jsr state_pointer
    ldaa PN
    staa 41,x
    ldaa PW+1
    staa PP+1
    ldaa PW
    adda #2
    staa PP
    jsr records_copy
    jsr scan
    tsta
    beq refresh_check
    jmp refresh_bad
refresh_check
    clr PL
refresh_old
    jsr state_pointer
    ldaa PL
    cmpa 41,x
    bcs refresh_next_record
    clra
    jmp refresh_release
refresh_next_record
    jsr state_pointer
    ldaa 62,x
    staa PP
    ldaa 63,x
    staa PP+1
    ldab PL
    beq refresh_old_pointer
refresh_old_offset
    ldaa PP+1
    adda #24
    staa PP+1
    ldaa PP
    adca #0
    staa PP
    decb
    bne refresh_old_offset
refresh_old_pointer
    ldx PP
    ldaa 11,x
    cmpa #$ff
    bne refresh_continue_1
    jmp refresh_next
refresh_continue_1
    ldaa 8,x
    staa PB
    jsr find_number
    bcc refresh_continue_2
    jmp refresh_bad
refresh_continue_2
    ldab #8
refresh_same
    ldx PP
    ldaa 0,x
    inx
    stx PP
    ldx PR
    cmpa 0,x
    beq refresh_continue_3
    jmp refresh_bad
refresh_continue_3
    inx
    stx PR
    decb
    bne refresh_same
    ; Pointers now point to the number field, offset 8.
    ldx PP
    ldaa 1,x
    ldx PR
    cmpa 1,x
    beq refresh_continue_4
    jmp refresh_bad
refresh_continue_4
    tst 13,x
    bne refresh_continue_5
    jmp refresh_bad
refresh_continue_5
    ldx PP
    ldaa 6,x
    ldx PR
    cmpa 6,x
    beq refresh_continue_6
    jmp refresh_bad
refresh_continue_6
    ldx PP
    ldaa 7,x
    ldx PR
    cmpa 7,x
    beq refresh_continue_7
    jmp refresh_bad
refresh_continue_7
    ldx PP
    ldx 4,x
    stx PT
    stx PX
    ldaa PR+1
    suba #8
    staa PR+1
    ldaa PR
    sbca #0
    staa PR
    jsr volume_read
    bcc refresh_geometry_start
    jmp refresh_bad
refresh_geometry_start
    ldx PX
    stx PT
    ldaa PR+1
    adda #8
    staa PR+1
    ldaa PR
    adca #0
    staa PR
    clr PJ
refresh_geometry
    ldx #geometry_fields
    ldab PJ
refresh_geometry_index
    tstb
    beq refresh_geometry_pair
    inx
    inx
    decb
    bra refresh_geometry_index
refresh_geometry_pair
    ldaa 0,x
    ldab 1,x
    adda PS+1
    staa P0+1
    ldaa PS
    adca #0
    staa P0
    ldx P0
    ldaa 0,x
    psha
    tba
    adda PT+1
    staa P0+1
    ldaa PT
    adca #0
    staa P0
    ldx P0
    pula
    cmpa 0,x
    beq refresh_geometry_same
    jmp refresh_bad
refresh_geometry_same
    inc PJ
    ldaa PJ
    cmpa #11
    bcs refresh_geometry
    ldx PP
    ldaa 3,x
    ldx PR
    staa 3,x
    ldx PP
    ldaa 4,x
    ldx PR
    staa 4,x
    ldx PP
    ldaa 5,x
    ldx PR
    staa 5,x
refresh_next
    inc PL
    jmp refresh_old
refresh_bad
    jsr state_pointer
    ldaa 41,x
    staa PN
    ldaa 62,x
    staa PP
    ldaa 63,x
    staa PP+1
    ldaa PW+1
    staa PR+1
    ldaa PW
    adda #2
    staa PR
    jsr records_copy
    ldaa #15
refresh_release
    psha
    jsr state_pointer
    ldx 60,x
    int $2b
    pula
    rts
records_copy
    ldx #768
    stx P0
records_copy_loop
    ldx PP
    ldaa 0,x
    inx
    stx PP
    ldx PR
    staa 0,x
    inx
    stx PR
    ldx P0
    dex
    stx P0
    cpx #0
    bne records_copy_loop
    rts

geometry_fields
    db 13,16,14,17,16,18,18,19,17,20,20,21,19,22,21,23,22,24,24,25,26,26
