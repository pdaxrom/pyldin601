; Private INT E1 services, independent of partition-service scratch:
; 14 count (X FH descriptor -> FH_VALUE BE16), 15 forget descriptor,
; 16 prepare FAT update, 17 commit it, 18 prepare external physical write,
; 19 forget all counts. No change to the public INT52 or 50-byte FH layout.
space_dispatch
    cmpa #14
    bne space_dispatch_forget
    jsr space_query
    jmp result
space_dispatch_forget
    cmpa #15
    bne space_dispatch_begin
    jsr space_forget
    jmp result
space_dispatch_begin
    cmpa #16
    bne space_dispatch_commit
    jsr space_update_begin
    jmp result
space_dispatch_commit
    cmpa #17
    bne space_dispatch_raw
    jsr space_update_commit
    jmp result
space_dispatch_raw
    cmpa #18
    bne space_dispatch_all
    jsr space_raw_prepare
    jmp result
space_dispatch_all
    jsr space_forget_all
    jmp result

; Probes and arbitrary caller descriptors never share a mounted-drive count.
space_pointer
    ldx $07
    stx FS_FREE_CURSOR
    ; MC6800 CPX leaves C unchanged: use an explicit unsigned subtraction.
    ldaa FS_FREE_CURSOR+1
    suba #FS_AREA
    ldaa FS_FREE_CURSOR
    sbca #/FS_AREA
    bcs space_no_pointer
    ldaa FS_FREE_CURSOR+1
    suba #FS_AREA+FS_OWNER
    ldaa FS_FREE_CURSOR
    sbca #/(FS_AREA+FS_OWNER)
    bcc space_no_pointer
    ldaa FH_IO+2,x
    cmpa #8
    bcc space_no_pointer
    asla
    adda #FS_FREE_BASE
    staa FS_FREE_CURSOR+1
    ldaa #/FS_FREE_BASE
    staa FS_FREE_CURSOR
    ldx FS_FREE_CURSOR
    clc
    rts
space_no_pointer
    sec
    rts
space_forget
    jsr space_pointer
    bcs space_ok
    ldaa #$ff
    staa 0,x
    staa 1,x
space_ok
    clra
    rts
space_forget_all
    ldx FS_STATE_PTR
    cpx #FS_AREA
    bne space_ok
    ldx #FS_FREE_BASE
    ldab #16
    ldaa #$ff
space_forget_byte
    staa 0,x
    inx
    decb
    bne space_forget_byte
    bra space_ok

space_query
    jsr space_pointer
    bcc space_query_pointer
    ldaa #2
    rts
space_query_pointer
    ldaa 0,x
    ldab 1,x
    cmpa #$ff
    bne space_query_cached
    cmpb #$ff
    beq space_scan
space_query_cached
    ldx $07
    staa FH_VALUE,x
    stab FH_VALUE+1,x
    clra
    rts

; Read the coherent FAT cache once per sector. Dirty entries and RAMMAN
; ownership are handled by FATCORE, exactly as for an ordinary FAT read.
space_scan
    ldx $07
    stx FS_FREE_DESC
    ldaa #16
    int $e9
    tsta
    beq space_scan_limit
    rts
space_scan_limit
    ldx FS_FREE_DESC
    ldaa FH_VALUE,x
    staa FS_FREE_LEFT
    ldaa FH_VALUE+1,x
    staa FS_FREE_LEFT+1
    clr FS_FREE_SUM
    clr FS_FREE_SUM+1
    clr FH_SECTOR,x
    clr FH_SECTOR+1,x
    clr FH_SECTOR+2,x
    clr FH_SECTOR+3,x
    clr FS_FREE_OFFSET
    ldaa #3
    ldab FH_BITS,x
    cmpb #16
    bne space_scan_offset
    inca
space_scan_offset
    staa FS_FREE_OFFSET+1
    jsr space_load_sector
    tsta
    beq space_scan_loaded
    rts
space_scan_loaded
    ldx FS_FREE_DESC
    ldaa FH_BITS,x
    cmpa #16
    beq space_scan16
    jmp space_scan12
space_scan16
    ldx FS_FREE_CURSOR
    ldab #254
space_scan16_word
    ldaa 0,x
    oraa 1,x
    jsr space_record
    beq space_scan_finish
    inx
    inx
    decb
    bne space_scan16_word
    jsr space_next_sector
    tsta
    beq space_scan16_loaded
    rts
space_scan16_loaded
    ldx FS_FREE_CURSOR
    clrb
    bra space_scan16_word

; Two FAT12 entries use three bytes. Keep the middle byte across a sector
; boundary, including entries 341/682, and never count reserved/tail entries.
space_scan12
    jsr space_scan_byte
    bcs space_scan_error
    staa FS_FREE_NEW
    jsr space_scan_byte
    bcs space_scan_error
    staa FS_FREE_HIGH
    anda #15
    oraa FS_FREE_NEW
    jsr space_record
    beq space_scan_finish
    jsr space_scan_byte
    bcs space_scan_error
    staa FS_FREE_NEW
    ldaa FS_FREE_HIGH
    lsra
    lsra
    lsra
    lsra
    oraa FS_FREE_NEW
    jsr space_record
    bne space_scan12
space_scan_finish
    jsr space_pointer
    ldaa FS_FREE_SUM
    ldab FS_FREE_SUM+1
    staa 0,x
    stab 1,x
    ldx FS_FREE_DESC
    staa FH_VALUE,x
    stab FH_VALUE+1,x
    clra
space_scan_error
    rts
space_record
    tsta
    bne space_record_used
    inc FS_FREE_SUM+1
    bne space_record_used
    inc FS_FREE_SUM
space_record_used
    ldaa FS_FREE_LEFT+1
    suba #1
    staa FS_FREE_LEFT+1
    ldaa FS_FREE_LEFT
    sbca #0
    staa FS_FREE_LEFT
    oraa FS_FREE_LEFT+1
    rts
space_scan_byte
    ldaa FS_FREE_OFFSET
    cmpa #2
    bne space_scan_byte_ready
    jsr space_next_sector
    tsta
    beq space_scan_byte_ready
    sec
    rts
space_scan_byte_ready
    ldx FS_FREE_CURSOR
    ldaa 0,x
    inx
    stx FS_FREE_CURSOR
    inc FS_FREE_OFFSET+1
    bne space_scan_byte_ok
    inc FS_FREE_OFFSET
space_scan_byte_ok
    clc
    rts
space_next_sector
    ldx FS_FREE_DESC
    inc FH_SECTOR+3,x
    bne space_next_ready
    inc FH_SECTOR+2,x
space_next_ready
    clr FS_FREE_OFFSET
    clr FS_FREE_OFFSET+1
space_load_sector
    ldx FS_FREE_DESC
    ldaa #30
    int $e9
    tsta
    bne space_load_return
    ldx FS_FREE_DESC
    ldx FH_HEADER,x
    ldaa 8,x
    adda FS_FREE_OFFSET+1
    staa FS_FREE_CURSOR+1
    ldaa 7,x
    adca FS_FREE_OFFSET
    staa FS_FREE_CURSOR
    clra
space_load_return
    rts

; Only a known count requires the previous entry. Snapshot the requested
; value before GET; FAT12's setter may subsequently shift that value in place.
space_update_begin
    clr FS_FREE_ACTION
    jsr space_pointer
    bcc space_update_pointer
    jmp space_update_skip
space_update_pointer
    ldaa 0,x
    anda 1,x
    cmpa #$ff
    bne space_update_known
    jmp space_update_skip
space_update_known
    ldx $07
    ldaa FH_VALUE,x
    staa FS_FREE_NEW
    ldaa FH_VALUE+1,x
    staa FS_FREE_NEW+1
    ldaa FH_CLUSTER+1,x
    suba #2
    staa FS_FREE_LEFT+1
    ldaa FH_CLUSTER,x
    sbca #0
    staa FS_FREE_LEFT
    bcs space_update_restore
    ldaa #16
    int $e9
    ldx $07
    ldaa FS_FREE_LEFT
    cmpa FH_VALUE,x
    bcs space_update_get
    bne space_update_restore
    ldaa FS_FREE_LEFT+1
    cmpa FH_VALUE+1,x
    bcc space_update_restore
space_update_get
    ldaa #1
    int $e9
    tsta
    beq space_update_value
    psha
    jsr space_update_restore
    jsr space_forget
    pula
    rts
space_update_value
    ldx $07
    ldaa FH_VALUE,x
    oraa FH_VALUE+1,x
    beq space_update_old_free
    ldaa #2
    staa FS_FREE_ACTION
    bra space_update_new
space_update_old_free
    ldaa #1
    staa FS_FREE_ACTION
space_update_new
    ldaa FS_FREE_NEW
    ldab FH_BITS,x
    cmpb #16
    beq space_update_new16
    anda #15
space_update_new16
    oraa FS_FREE_NEW+1
    bne space_update_new_used
    ldaa FS_FREE_ACTION
    cmpa #2
    beq space_update_restore
    bra space_update_no_change
space_update_new_used
    ldaa FS_FREE_ACTION
    cmpa #1
    beq space_update_restore
space_update_no_change
    clr FS_FREE_ACTION
space_update_restore
    ldx $07
    ldaa FS_FREE_NEW
    staa FH_VALUE,x
    ldaa FS_FREE_NEW+1
    staa FH_VALUE+1,x
space_update_skip
    clra
    rts
space_update_commit
    tst FS_FREE_ACTION
    beq space_update_skip
    jsr space_pointer
    bcs space_update_clear
    ldaa 0,x
    anda 1,x
    cmpa #$ff
    beq space_update_clear
    ldaa FS_FREE_ACTION
    cmpa #2
    beq space_update_release
    ldaa 1,x
    suba #1
    staa 1,x
    ldaa 0,x
    sbca #0
    staa 0,x
    bra space_update_clear
space_update_release
    inc 1,x
    bne space_update_clear
    inc 0,x
space_update_clear
    clr FS_FREE_ACTION
    clra
    rts

; Ordinary filesystem writes are marked by the kernel/FAT flush. An external
; INT40/EA/E1/E2 write first drains dirty native FATs, then discards their
; sector caches as well as all counts. Never drop uncommitted FAT bytes.
space_raw_prepare
    ldx FS_STATE_PTR
    cpx #FS_AREA
    bne space_raw_ok
    tst FS_WRITE_CONTEXT
    bne space_raw_ok
    jsr space_forget_all
    ldx #FS_AREA
    stx FS_FREE_DESC
space_raw_volume
    ldx FS_FREE_DESC
    ldaa FH_FLAGS,x
    bita #2
    beq space_raw_next
    ldaa #4
    int $e9
    tsta
    bne space_raw_return
    ldx FS_FREE_DESC
    clr FH_VALID,x
space_raw_next
    ldaa FS_FREE_DESC+1
    adda #FH_SIZE
    staa FS_FREE_DESC+1
    ldaa FS_FREE_DESC
    adca #0
    staa FS_FREE_DESC
    ldx FS_FREE_DESC
    cpx #FS_AREA+FS_OWNER
    bne space_raw_volume
space_raw_ok
    clra
space_raw_return
    rts
