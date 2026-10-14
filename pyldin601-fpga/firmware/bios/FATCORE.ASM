; FAT12/FAT16 algorithms, classic MC6800. INT E9 uses an explicit FH descriptor.
; A: 0 normalize BPB at FH_IO.buffer; 1 get; 2 set; 3 cluster -> sector;
; 4 flush. The descriptor and cache belong to the kernel, not this ROM.
; SWIX is the BIOS's saved incoming parameter, restored across nested SWIs.
fatcore
    cmpa #25
    bcs fc_dispatch_files
    jmp fc_kernel_service
fc_dispatch_files
    cmpa #21
    bne fc_file_dispatch22
    jmp fc_file_map
fc_file_dispatch22
    cmpa #22
    bne fc_file_dispatch23
    ldx $eb2f
    stx $07
    ldaa $07
    suba #2
    staa $07
    ldx $07
    jsr fc_file_map
    stx $ebc1
    rts
fc_file_dispatch23
    cmpa #23
    bne fc_existing_dispatch
    jmp fc_file_pointer
fc_existing_dispatch
    cmpa #24
    bne fc_volume_dispatch
    jmp fc_directory_allocate
fc_volume_dispatch
    cmpa #11
    bne fc_dispatch_metadata
    jsr fc_bank_initialize
    jmp fc_return
fc_dispatch_metadata
    cmpa #20
    bne fc_dispatch_metadata20_work
    jsr fc_abort_create
    jmp fc_return
fc_dispatch_metadata20_work
    cmpa #16
    bne fc_dispatch_metadata13
    jsr fc_allocation_limit
    jmp fc_return
fc_dispatch_metadata13
    cmpa #12
    bne fc_dispatch_metadata_handle
    jsr fc_validate_open
    jmp fc_return
fc_dispatch_metadata_handle
    cmpa #17
    bne fc_dispatch_metadata13_work
    jsr fc_media_refresh
    jmp fc_return
fc_dispatch_metadata13_work
    cmpa #18
    bne fc_dispatch_metadata18_work
    jsr fc_buffer_invalidate
    jmp fc_return
fc_dispatch_metadata18_work
    cmpa #19
    bne fc_dispatch_metadata19_work
    jsr fc_flush_idle
    jmp fc_return
fc_dispatch_metadata19_work
    cmpa #13
    bne fc_metadata_buffer
    jsr fc_handle_meta
    stx $07
    jmp fc_return
fc_metadata_buffer
    cmpa #14
    bne fc_algorithms
    jsr fc_buffer_meta
    stx $07
    jmp fc_return
fc_algorithms
    tsta
    bne fc_dispatch_get
    jsr fc_mount
    jmp fc_return
fc_dispatch_get
    cmpa #1
    bne fc_dispatch_set
    jsr fc_get
    jmp fc_return
fc_dispatch_set
    cmpa #2
    bne fc_dispatch_sector
    jsr fc_set
    jmp fc_return
fc_dispatch_sector
    cmpa #3
    bne fc_dispatch_flush
    jsr fc_sector
    jmp fc_return
fc_dispatch_flush
    cmpa #7
    bne fc_dispatch_allocate
    jsr fc_check
    jmp fc_return
fc_dispatch_allocate
    cmpa #8
    bne fc_dispatch_legacy
    jsr fc_allocate
    jmp fc_return
fc_dispatch_legacy
    cmpa #9
    bne fc_dispatch_legacy6
    jsr fc_validate_chain
    jmp fc_return
fc_dispatch_legacy6
    cmpa #6
    bne fc_dispatch_flush4
    jsr fc_legacy
    jmp fc_return
fc_dispatch_flush4
    cmpa #4
    bne fc_invalid
    jsr fc_flush
    jmp fc_return
fc_invalid
    ldaa #1
fc_return
    staa SWIA
    tsta
    beq fc_success
    sec
    bra fc_cc
fc_success
    clc
fc_cc
    tpa
    staa $04
    rts
fc_bad
    ldaa #9
    rts
fc_legacy
    ldx $07
    ldx FH_HEADER,x
    ldaa 16,x
    ldab 18,x
    ldx $07
    staa FH_SPC,x
    stab FH_NOF,x
    ldx FH_HEADER,x
    ldaa 17,x
    ldab 24,x
    ldx $07
    clr FH_RESERVED,x
    staa FH_RESERVED+1,x
    clr FH_SPF,x
    stab FH_SPF+1,x
    ldx FH_HEADER,x
    ldaa 21,x
    ldab 22,x
    ldx $07
    clr FH_TOTAL,x
    clr FH_TOTAL+1,x
    staa FH_TOTAL+2,x
    stab FH_TOTAL+3,x
    ldx FH_HEADER,x
    ldaa 19,x
    ldab 20,x
    ldx $07
    staa FH_ROOT,x
    stab FH_ROOT+1,x
    jmp fc_total_ready

; BPB normalization also derives all offsets/counts with checked arithmetic.
fc_mount
    ldx $07
    ldx FH_IO,x
    tst 11,x
    beq fc_long_1
    jmp fc_bad
fc_long_1
    ldaa 12,x
    cmpa #2
    beq fc_long_2
    jmp fc_bad
fc_long_2
    ldaa 13,x
    bne fc_long_3
    jmp fc_bad
fc_long_3
    cmpa #128
    bls fc_long_4
    jmp fc_bad
fc_long_4
    tab
    deca
    pshb
    tsx
    anda 0,x
    pulb
    beq fc_long_5
    jmp fc_bad
fc_long_5
    ldx $07
    stab FH_SPC,x
    ldx FH_IO,x
    ldaa 16,x
    bne fc_long_6
    jmp fc_bad
fc_long_6
    cmpa #2
    bls fc_long_7
    jmp fc_bad
fc_long_7
    ldx $07
    staa FH_NOF,x
    ldx FH_IO,x
    ldaa 15,x
    ldab 14,x
    ldx $07
    staa FH_RESERVED,x
    stab FH_RESERVED+1,x
    oraa FH_RESERVED+1,x
    bne fc_long_8
    jmp fc_bad
fc_long_8
    ldx FH_IO,x
    ldaa 23,x
    ldab 22,x
    ldx $07
    staa FH_SPF,x
    stab FH_SPF+1,x
    oraa FH_SPF+1,x
    bne fc_long_9
    jmp fc_bad
fc_long_9
    ldx FH_IO,x
    ldaa 18,x
    ldab 17,x
    ; Native FindNext retains its byte-sized sector-in-root field.
    ; Accept ordinary roots up to 4080 entries, aligned to 16 entries.
    cmpa #$0f
    bls fc_long_10
    jmp fc_bad
fc_long_10
    pshb
    andb #15
    pulb
    beq fc_long_11
    jmp fc_bad
fc_long_11
    ldx $07
    staa FH_ROOT,x
    stab FH_ROOT+1,x
    oraa FH_ROOT+1,x
    bne fc_long_12
    jmp fc_bad
fc_long_12
    ldx FH_IO,x
    ldaa 20,x
    ldab 19,x
    ldx $07
    clr FH_TOTAL,x
    clr FH_TOTAL+1,x
    staa FH_TOTAL+2,x
    stab FH_TOTAL+3,x
    oraa FH_TOTAL+3,x
    bne fc_total_ready
    ldx FH_IO,x
    ldaa 35,x
    ldab 34,x
    ldx $07
    staa FH_TOTAL,x
    stab FH_TOTAL+1,x
    ldx FH_IO,x
    ldaa 33,x
    ldab 32,x
    ldx $07
    staa FH_TOTAL+2,x
    stab FH_TOTAL+3,x
fc_total_ready
    ; root sectors = root entries >> 4; add reserved and all FAT copies.
    ldx $07
    ldaa FH_ROOT+1,x
    ldab FH_ROOT,x
    lsrb
    rora
    lsrb
    rora
    lsrb
    rora
    lsrb
    rora
    adda FH_RESERVED+1,x
    adcb FH_RESERVED,x
    staa FH_DATA+3,x
    stab FH_DATA+2,x
    ldaa #0
    adca #0
    staa FH_DATA+1,x
    clr FH_DATA,x
    ldaa FH_NOF,x
    staa FH_TMP,x
fc_overhead
    ldaa FH_DATA+3,x
    adda FH_SPF+1,x
    staa FH_DATA+3,x
    ldaa FH_DATA+2,x
    adca FH_SPF,x
    staa FH_DATA+2,x
    ldaa FH_DATA+1,x
    adca #0
    staa FH_DATA+1,x
    dec FH_TMP,x
    bne fc_overhead
    ; Store remaining data sectors temporarily in FH_SECTOR.
    ldaa FH_TOTAL+3,x
    suba FH_DATA+3,x
    staa FH_SECTOR+3,x
    ldaa FH_TOTAL+2,x
    sbca FH_DATA+2,x
    staa FH_SECTOR+2,x
    ldaa FH_TOTAL+1,x
    sbca FH_DATA+1,x
    staa FH_SECTOR+1,x
    ldaa FH_TOTAL,x
    sbca FH_DATA,x
    staa FH_SECTOR,x
    bcc fc_long_13
    jmp fc_mount_bad
fc_long_13
    ldab FH_SPC,x
fc_count_shift
    lsrb
    beq fc_count_ready
    lsr FH_SECTOR,x
    ror FH_SECTOR+1,x
    ror FH_SECTOR+2,x
    ror FH_SECTOR+3,x
    bra fc_count_shift
fc_count_ready
    ldaa FH_SECTOR,x
    oraa FH_SECTOR+1,x
    beq fc_long_14
    jmp fc_mount_bad
fc_long_14
    ldaa FH_SECTOR+2,x
    ldab FH_SECTOR+3,x
    staa FH_COUNT,x
    stab FH_COUNT+1,x
    cpx #0
    oraa FH_COUNT+1,x
    bne fc_long_15
    jmp fc_mount_bad
fc_long_15
    ldaa FH_COUNT,x
    cmpa #$0f
    bcs fc_is12
    bhi fc_is16
    cmpb #$f5
    bcs fc_is12
fc_is16
    ; FAT16 classification ends at 65524 clusters. Allocation separately
    ; excludes indices FFF0..FFFF, while reading legacy tail files is allowed.
    ldaa FH_COUNT,x
    cmpa #$ff
    bcs fc_16_count
    cmpb #$f4
    bls fc_long_16
    jmp fc_mount_bad
fc_long_16
fc_16_count
    tst FH_SPC,x
    bpl fc_long_17
    jmp fc_mount_bad
fc_long_17
    ldaa #16
    staa FH_BITS,x
    ; Required FAT sectors = ceil((count+2)/256).
    ldab FH_COUNT+1,x
    addb #2
    ldaa FH_COUNT,x
    adca #0
    tstb
    beq fc_16_required
    inca
fc_16_required
    ; A may wrap to zero for the valid requirement of 256 sectors.
    tab
    clra
    tstb
    bne fc_check_size
    inca
    bra fc_check_size
fc_is12
    ldaa #12
    staa FH_BITS,x
    ldaa FH_COUNT+1,x
    adda #2
    ldab FH_COUNT,x
    adcb #0
    staa FH_TMP+1,x
    stab FH_TMP+2,x
    asla
    rolb
    adda FH_TMP+1,x
    adcb FH_TMP+2,x
    ; ceil(3*(count+2)/1024).
    staa FH_TMP+1,x
    stab FH_TMP+2,x
    lsrb
    lsrb
    ldaa FH_TMP+2,x
    anda #3
    oraa FH_TMP+1,x
    beq fc_12_required
    incb
fc_12_required
    clra
fc_check_size
    cmpa FH_SPF,x
    bcs fc_mount_ok
    beq fc_long_18
    jmp fc_mount_bad
fc_long_18
    cmpb FH_SPF+1,x
    bls fc_long_19
    jmp fc_mount_bad
fc_long_19
fc_mount_ok
    clr FH_VALID,x
    clr FH_DIRTY,x
    ldaa #0
    staa FH_HINT,x
    ldaa #2
    staa FH_HINT+1,x
    clra
    rts
fc_mount_bad
    jmp fc_bad

; Calculate FAT cache sector + byte offset without a 16-bit 2*cluster overflow.
fc_entry
    ldx $07
    ldaa FH_BITS,x
    cmpa #16
    bne fc_entry12
    clr FH_SECTOR,x
    clr FH_SECTOR+1,x
    clr FH_SECTOR+2,x
    ldaa FH_CLUSTER,x
    staa FH_SECTOR+3,x
    ldaa FH_CLUSTER+1,x
    asla
    staa FH_TMP+1,x
    ldaa #0
    rola
    staa FH_TMP,x
    jmp fc_cache
fc_entry12
    ldaa FH_CLUSTER+1,x
    ldab FH_CLUSTER,x
    asla
    rolb
    adda FH_CLUSTER+1,x
    adcb FH_CLUSTER,x
    lsrb
    rora
    staa FH_TMP+1,x
    stab FH_TMP,x
    ; Save entry parity separately; FAT12 can straddle a sector boundary.
    ldaa FH_CLUSTER+1,x
    anda #1
    staa FH_TMP+2,x
fc_byte
    ldx $07
    ldaa FH_BITS,x
    cmpa #16
    bne fc_byte12
    ldab FH_CLUSTER,x
    bra fc_byte_sector
fc_byte12
    ldab FH_TMP,x
    lsrb
fc_byte_sector
    stab FH_SECTOR+3,x
    clr FH_SECTOR,x
    clr FH_SECTOR+1,x
    clr FH_SECTOR+2,x
    jsr fc_cache
    tsta
    bne fc_byte_return
    ldx $07
    ldaa FH_TMP+1,x
    ldab FH_TMP,x
    andb #1
    ldx FH_HEADER,x
    adda 8,x
    adcb 7,x
    staa BUF+1
    stab BUF
    ldx BUF
    clra
fc_byte_return
    rts
fc_cache
    jsr fc_shared_cache
    tsta
    bne fc_cache_return
    ldx $07
    tst FH_VALID,x
    beq fc_cache_miss
    ldaa FH_CACHE,x
    cmpa FH_SECTOR+2,x
    bne fc_cache_miss
    ldaa FH_CACHE+1,x
    cmpa FH_SECTOR+3,x
    beq fc_cache_hit
fc_cache_miss
    jsr fc_flush
    tsta
    beq fc_long_20
    jmp fc_cache_return
fc_long_20
    ldx $07
    ldaa FH_SECTOR+2,x
    cmpa FH_SPF,x
    bcs fc_cache_range
    bne fc_cache_error
    ldaa FH_SECTOR+3,x
    cmpa FH_SPF+1,x
    bcc fc_cache_error
fc_cache_range
    ; Build explicit sector descriptor in the caller's resident volume state.
    clr FH_IO+3,x
    clr FH_IO+4,x
    ldaa FH_SECTOR+3,x
    adda FH_RESERVED+1,x
    staa FH_IO+6,x
    ldaa FH_SECTOR+2,x
    adca FH_RESERVED,x
    staa FH_IO+5,x
    rol FH_IO+4,x
    ldx FH_HEADER,x
    ldaa 7,x
    ldab 8,x
    ldx $07
    staa FH_IO,x
    stab FH_IO+1,x
    jsr fc_io_pointer
    ldaa #1
    int $ea
    tsta
    beq fc_long_21
    jmp fc_cache_return
fc_long_21
    ldx $07
    ldaa FH_SECTOR+2,x
    staa FH_CACHE,x
    ldaa FH_SECTOR+3,x
    staa FH_CACHE+1,x
    ldaa #1
    staa FH_VALID,x
fc_cache_hit
    clra
fc_cache_return
    rts
fc_cache_error
    ldaa #10
    rts

; A/B use the kernel's original E700 FAT buffer. Its owner is explicit
; kernel state, in the replaced E900 buffer. Other drivers keep private FATs.
; Flush the previous owner before invalidating either cached sector.
fc_shared_cache
    ldx $07
    ldx FH_HEADER,x
    ldx 7,x
    cpx #$e700
    bne fc_shared_ok
    ldx FS_AREA+FS_OWNER
    cpx $07
    beq fc_shared_ok
    cpx #0
    beq fc_shared_claim
    ldaa $07
    psha
    ldaa $08
    psha
    stx $07
    jsr fc_flush
    ldx $07
    tst FH_DIRTY,x
    bne fc_shared_restore
    .ifdef FAT_RAMMAN
    ldaa FS_AREA+FS_BANK
    cmpa #1
    bne fc_shared_invalidate
    clra
    jsr fc_bank_transfer
    bra fc_shared_restore
fc_shared_invalidate
    .endif
    clr FH_VALID,x
    clra
fc_shared_restore
    pulb
    stab $08
    pulb
    stab $07
    tsta
    bne fc_shared_return
fc_shared_claim
    ldx $07
    stx FS_AREA+FS_OWNER
    .ifdef FAT_RAMMAN
    ldaa FS_AREA+FS_BANK
    cmpa #1
    bne fc_shared_cold
    tst FH_VALID,x
    beq fc_shared_ok
    ldaa #1
    jsr fc_bank_transfer
    tsta
    beq fc_shared_return
    ldx $07
    clr FH_VALID,x
    rts
fc_shared_cold
    .endif
    clr FH_VALID,x
fc_shared_ok
    clra
fc_shared_return
    rts

fc_bank_initialize
    .ifdef FAT_RAMMAN
    tst FS_AREA+FS_BANK
    beq fc_bank_gate_1
    jmp fc_bank_ready
fc_bank_gate_1
    dec FS_AREA+FS_BANK
    ldaa $e6f2
    cmpa #'R'
    beq fc_bank_gate_2
    jmp fc_bank_ready
fc_bank_gate_2
    ldaa $e6f3
    cmpa #111
    beq fc_bank_gate_3
    jmp fc_bank_ready
fc_bank_gate_3
    ldaa #$e5
    int $2e
    cpx #0
    bne fc_bank_gate_4
    jmp fc_bank_ready
fc_bank_gate_4
    clra
    int $e5
    cmpa #1
    beq fc_bank_gate_5
    jmp fc_bank_ready
fc_bank_gate_5
    tstb
    bne fc_bank_gate_6
    jmp fc_bank_ready
fc_bank_gate_6
    ldaa #$e8
    int $2e
    cpx #0
    bne fc_bank_gate_7
    jmp fc_bank_ready
fc_bank_gate_7
    ldaa $ee1e
    psha
    ldaa $ee1f
    psha
    ldx #4
    clrb
    int $2a
    cpx #0
    beq fc_bank_no_heap
    stx FS_AREA+FS_LEASE
    ldaa #1
    jsr fc_kernel_lease
    tsta
    bne fc_bank_free_heap
    ; Probe the fixed-ROM copy gateway before selecting banked allocation.
    ldaa #$a5
    staa $e700
    clra
    jsr fc_bank_transfer
    tsta
    bne fc_bank_copy_failed
    clr $e700
    ldaa #1
    jsr fc_bank_transfer
    tsta
    bne fc_bank_copy_failed
    ldaa $e700
    cmpa #$a5
    beq fc_bank_active
fc_bank_copy_failed
    ldaa #2
    jsr fc_kernel_lease
fc_bank_free_heap
    pula
    staa BUF+1
    pula
    staa BUF
    ldx BUF
    int $2b
    clr FS_AREA+FS_LEASE
    clr FS_AREA+FS_LEASE+1
    bra fc_bank_ready
fc_bank_no_heap
    ins
    ins
    bra fc_bank_ready
fc_bank_active
    ins
    ins
    ldaa #1
    staa FS_AREA+FS_BANK
    int $2c
fc_bank_ready
    .endif
    clra
    rts

    .ifdef FAT_RAMMAN
; Permanent lease owner FFFF cannot be an application PCB. An application
; RELEASE-OWNER/INT38 never reclaims filesystem buffers. Restore PCB on all paths.
fc_kernel_lease
    tab
    ldaa $ec00
    psha
    ldaa $ec01
    psha
    ldaa #$ff
    staa $ec00
    staa $ec01
    tba
    ldab #1
    ldx FS_AREA+FS_LEASE
    int $e5
    tab
    pula
    staa $ec01
    pula
    staa $ec00
    tba
    rts

; A=0 save, A=1 restore. One leased bank has eight 512-byte FAT cache slots.
; No executable code resides in a switched RAM window or in processor RAM.
fc_bank_transfer
    psha
    ldx $07
    ldaa FH_IO+2,x
    asla
    adda #$c0
    ldab #0
    staa FS_AREA+FS_COPY+2
    stab FS_AREA+FS_COPY+3
    ldx #$e700
    stx FS_AREA+FS_COPY
    pula
    tsta
    beq fc_bank_select
    ldx FS_AREA+FS_COPY+2
    stx FS_AREA+FS_COPY
    ldx #$e700
    stx FS_AREA+FS_COPY+2
fc_bank_select
    ldx FS_AREA+FS_LEASE
    ldaa 3,x
    clrb
fc_bank_group
    cmpa #6
    bcs fc_bank_page
    suba #6
    incb
    bra fc_bank_group
fc_bank_page
    inca
    staa FS_AREA+FS_COPY+4
    stab FS_AREA+FS_COPY+5
    ldx #FS_AREA+FS_COPY
    ldaa #4
    int $e8
    rts
    .endif
fc_io_pointer
    ldx $07
    ldab #FH_IO
fc_io_step
    inx
    decb
    bne fc_io_step
    rts
fc_get
    jsr fc_entry
    tsta
    beq fc_long_22
    jmp fc_get_return
fc_long_22
    jsr fc_byte
    tsta
    beq fc_long_23
    jmp fc_get_return
fc_long_23
    ldaa 0,x
    ldx $07
    staa FH_VALUE+1,x
    inc FH_TMP+1,x
    bne fc_get_second
    inc FH_TMP,x
fc_get_second
    jsr fc_byte
    tsta
    beq fc_long_24
    jmp fc_get_return
fc_long_24
    ldaa 0,x
    ldx $07
    staa FH_VALUE,x
    ldaa FH_BITS,x
    cmpa #16
    beq fc_get_ok
    tst FH_TMP+2,x
    bne fc_get_odd
    ldaa FH_VALUE,x
    anda #15
    staa FH_VALUE,x
    bra fc_get_ok
fc_get_odd
    ldab #4
fc_get_shift
    lsr FH_VALUE,x
    ror FH_VALUE+1,x
    decb
    bne fc_get_shift
fc_get_ok
    clra
fc_get_return
    rts
fc_set
    jsr fc_write_allowed
    tsta
    beq fc_set_allowed
    rts
fc_set_allowed
    jsr fc_entry
    tsta
    beq fc_long_25
    jmp fc_set_return
fc_long_25
    ldx $07
    ldaa FH_BITS,x
    cmpa #16
    beq fc_set16
    tst FH_TMP+2,x
    bne fc_set_odd
    jsr fc_byte
    tsta
    beq fc_long_26
    jmp fc_set_return
fc_long_26
    pshb
    ldx $07
    ldaa FH_VALUE+1,x
    pulb
    bra fc_set_first
fc_set16
    jsr fc_byte
    tsta
    beq fc_long_27
    jmp fc_set_return
fc_long_27
    ; X is now the actual cache address, preserved while retrieving value.
    stx BUF
    ldx $07
    ldaa FH_VALUE+1,x
    ldx BUF
    jsr fc_put
    bra fc_set_second
fc_set_odd
    ldab #4
fc_set_shift
    asl FH_VALUE+1,x
    rol FH_VALUE,x
    decb
    bne fc_set_shift
    jsr fc_byte
    tsta
    beq fc_long_28
    jmp fc_set_return
fc_long_28
    ldaa 0,x
    anda #15
    stx BUF
    ldx $07
    oraa FH_VALUE+1,x
    ldx BUF
fc_set_first
    ; Even FAT12 path needs to recover the cache address as well.
    psha
    jsr fc_byte
    tsta
    beq fc_set_first_ready
    ins
    rts
fc_set_first_ready
    pula
    jsr fc_put
fc_set_second
    ldx $07
    inc FH_TMP+1,x
    bne fc_set_second_ready
    inc FH_TMP,x
fc_set_second_ready
    jsr fc_byte
    tsta
    beq fc_long_29
    jmp fc_set_return
fc_long_29
    ldaa 0,x
    stx BUF
    ldx $07
    ldab FH_BITS,x
    cmpb #16
    beq fc_set_high
    tst FH_TMP+2,x
    bne fc_set_high
    anda #$f0
    ldab FH_VALUE,x
    andb #15
    stab FH_TMP+3,x
    oraa FH_TMP+3,x
    bra fc_set_write
fc_set_high
    ldaa FH_VALUE,x
fc_set_write
    ldx BUF
    jsr fc_put
    clra
fc_set_return
    rts
fc_put
    staa 0,x
    ldx $07
    ldaa #1
    staa FH_DIRTY,x
    ldx FH_HEADER,x
    staa 12,x
    rts

; Dirty remains set until every FAT copy has accepted the sector.
fc_flush
    ldx $07
    tst FH_DIRTY,x
    beq fc_flush_ok
    ldaa FH_NOF,x
    staa FH_TMP+4,x
    clr FH_IO+3,x
    clr FH_IO+4,x
    ldaa FH_CACHE+1,x
    adda FH_RESERVED+1,x
    staa FH_IO+6,x
    ldaa FH_CACHE,x
    adca FH_RESERVED,x
    staa FH_IO+5,x
    rol FH_IO+4,x
    ldx FH_HEADER,x
    ldaa 7,x
    ldab 8,x
    ldx $07
    staa FH_IO,x
    stab FH_IO+1,x
fc_flush_copy
    jsr fc_io_pointer
    ldaa #2
    int $ea
    tsta
    bne fc_flush_return
    ldx $07
    dec FH_TMP+4,x
    beq fc_flush_done
    ldaa FH_IO+6,x
    adda FH_SPF+1,x
    staa FH_IO+6,x
    ldaa FH_IO+5,x
    adca FH_SPF,x
    staa FH_IO+5,x
    ldaa FH_IO+4,x
    adca #0
    staa FH_IO+4,x
    bra fc_flush_copy
fc_flush_done
    clr FH_DIRTY,x
    ldx FH_HEADER,x
    clr 12,x
fc_flush_ok
    clra
fc_flush_return
    rts

; Compute a complete volume-relative address; cluster numbers stay BE16.
fc_sector
    ldx $07
    ldaa FH_CLUSTER,x
    oraa FH_CLUSTER+1,x
    bne fc_sector_data
    ; Root base = data base - root sectors.
    ldaa FH_ROOT+1,x
    ldab FH_ROOT,x
    lsrb
    rora
    lsrb
    rora
    lsrb
    rora
    lsrb
    rora
    staa FH_TMP+1,x
    stab FH_TMP,x
    ldaa FH_DATA+3,x
    suba FH_TMP+1,x
    staa FH_SECTOR+3,x
    ldaa FH_DATA+2,x
    sbca FH_TMP,x
    staa FH_SECTOR+2,x
    ldaa FH_DATA+1,x
    sbca #0
    staa FH_SECTOR+1,x
    ldaa FH_DATA,x
    sbca #0
    staa FH_SECTOR,x
    bra fc_sector_add_index
fc_sector_data
    ; 2 <= cluster <= count+1.
    ldaa FH_CLUSTER+1,x
    suba #2
    staa FH_SECTOR+3,x
    ldaa FH_CLUSTER,x
    sbca #0
    staa FH_SECTOR+2,x
    bcc fc_long_30
    jmp fc_sector_bad
fc_long_30
    cmpa FH_COUNT,x
    bcs fc_sector_range_ok
    beq fc_long_31
    jmp fc_sector_bad
fc_long_31
    ldaa FH_SECTOR+3,x
    cmpa FH_COUNT+1,x
    bcs fc_long_32
    jmp fc_sector_bad
fc_long_32
fc_sector_range_ok
    clr FH_SECTOR,x
    clr FH_SECTOR+1,x
    ldab FH_SPC,x
fc_sector_shift
    lsrb
    beq fc_sector_base
    asl FH_SECTOR+3,x
    rol FH_SECTOR+2,x
    rol FH_SECTOR+1,x
    rol FH_SECTOR,x
    bra fc_sector_shift
fc_sector_base
    ldaa FH_SECTOR+3,x
    adda FH_DATA+3,x
    staa FH_SECTOR+3,x
    ldaa FH_SECTOR+2,x
    adca FH_DATA+2,x
    staa FH_SECTOR+2,x
    ldaa FH_SECTOR+1,x
    adca FH_DATA+1,x
    staa FH_SECTOR+1,x
    ldaa FH_SECTOR,x
    adca FH_DATA,x
    staa FH_SECTOR,x
    bcc fc_long_33
    jmp fc_sector_bad
fc_long_33
fc_sector_add_index
    ldaa FH_SECTOR+3,x
    adda FH_VALUE+1,x
    staa FH_SECTOR+3,x
    ldaa FH_SECTOR+2,x
    adca #0
    staa FH_SECTOR+2,x
    ldaa FH_SECTOR+1,x
    adca #0
    staa FH_SECTOR+1,x
    ldaa FH_SECTOR,x
    adca #0
    staa FH_SECTOR,x
    bcc fc_long_34
    jmp fc_sector_bad
fc_long_34
    clra
    rts
fc_sector_bad
    ldaa #10
    rts

fc_check
    ldx $07
    ldaa FH_BITS,x
    cmpa #16
    beq fc_check16
    ldaa FH_VALUE,x
    cmpa #$0f
    bne fc_check_data
    bra fc_check_low
fc_check16
    ldaa FH_VALUE,x
    cmpa #$ff
    bne fc_check_data
fc_check_low
    ldaa FH_VALUE+1,x
    cmpa #$f0
    bcs fc_check_data
    cmpa #$f7
    beq fc_check_bad
    bcs fc_check_reserved
    ldaa #200
    rts
fc_check_bad
    ldaa #202
    rts
fc_check_reserved
    ldaa #201
    rts
fc_check_data
    ldaa FH_VALUE+1,x
    suba #2
    ldab FH_VALUE,x
    sbcb #0
    bcs fc_check_range
    cmpb FH_COUNT,x
    bcs fc_check_ok
    bne fc_check_range
    cmpa FH_COUNT+1,x
    bcc fc_check_range
fc_check_ok
    clra
    rts
fc_check_range
    ldaa #10
    rts

; Validate a complete chain before opening a file or traversing a directory.
; A corrupt cycle takes at most COUNT steps, rather than hanging FindFirst.
; fc_get/flush preserve TMP+5/6. Zero denotes an empty file or the fixed root.
fc_validate_chain
    ldx $07
    ldaa FH_CLUSTER,x
    oraa FH_CLUSTER+1,x
    beq fc_validate_ok
    ldaa FH_COUNT,x
    staa FH_TMP+5,x
    ldaa FH_COUNT+1,x
    staa FH_TMP+6,x
fc_validate_loop
    ldaa FH_CLUSTER,x
    staa FH_VALUE,x
    ldaa FH_CLUSTER+1,x
    staa FH_VALUE+1,x
    jsr fc_check_data
    tsta
    bne fc_validate_bad
    jsr fc_get
    tsta
    bne fc_validate_return
    jsr fc_check
    cmpa #200
    beq fc_validate_ok
    tsta
    bne fc_validate_bad
    ldx $07
    ldaa FH_VALUE,x
    staa FH_CLUSTER,x
    ldaa FH_VALUE+1,x
    staa FH_CLUSTER+1,x
    ldaa FH_TMP+6,x
    suba #1
    staa FH_TMP+6,x
    ldaa FH_TMP+5,x
    sbca #0
    staa FH_TMP+5,x
    oraa FH_TMP+6,x
    bne fc_validate_loop
fc_validate_bad
    ldaa #10
    rts
fc_validate_ok
    clra
fc_validate_return
    rts

; Bounded next-fit allocation scans at most the actual data-cluster count.
fc_allocate
    jsr fc_write_allowed
    tsta
    beq fc_allocate_allowed
    rts
fc_allocate_allowed
    ldx $07
    ldaa FH_HINT,x
    staa FH_CLUSTER,x
    ldaa FH_HINT+1,x
    staa FH_CLUSTER+1,x
    ldaa FH_COUNT,x
    staa FH_TMP+5,x
    ldaa FH_COUNT+1,x
    staa FH_TMP+6,x
fc_allocate_loop
    jsr fc_get
    tsta
    bne fc_allocate_return
    ldx $07
    ldaa FH_VALUE,x
    oraa FH_VALUE+1,x
    beq fc_allocate_found
    ldaa FH_TMP+6,x
    suba #1
    staa FH_TMP+6,x
    ldaa FH_TMP+5,x
    sbca #0
    staa FH_TMP+5,x
    oraa FH_TMP+6,x
    beq fc_allocate_full
    jsr fc_allocate_next
    bra fc_allocate_loop
fc_allocate_found
    ldaa #$ff
    staa FH_VALUE+1,x
    ldaa FH_BITS,x
    cmpa #16
    beq fc_allocate_eof16
    ldaa #$0f
    bra fc_allocate_eof
fc_allocate_eof16
    ldaa #$ff
fc_allocate_eof
    staa FH_VALUE,x
    jsr fc_set
    tsta
    bne fc_allocate_return
    ldx $07
    ldaa FH_CLUSTER,x
    staa FH_HINT,x
    ldaa FH_CLUSTER+1,x
    staa FH_HINT+1,x
    ; Advance hint without changing the returned allocated cluster.
    ldaa FH_CLUSTER,x
    staa FH_TMP+5,x
    ldaa FH_CLUSTER+1,x
    staa FH_TMP+6,x
    jsr fc_allocate_next
    ldaa FH_CLUSTER,x
    staa FH_HINT,x
    ldaa FH_CLUSTER+1,x
    staa FH_HINT+1,x
    ldaa FH_TMP+5,x
    staa FH_CLUSTER,x
    ldaa FH_TMP+6,x
    staa FH_CLUSTER+1,x
    clra
fc_allocate_return
    rts
fc_allocate_full
    ldaa #17
    rts
fc_allocate_next
    inc FH_CLUSTER+1,x
    bne fc_allocate_compare
    inc FH_CLUSTER,x
fc_allocate_compare
    jsr fc_allocation_limit
    ldaa FH_CLUSTER+1,x
    suba #2
    ldab FH_CLUSTER,x
    sbcb #0
    cmpb FH_VALUE,x
    bcs fc_allocate_next_done
    bne fc_allocate_wrap
    cmpa FH_VALUE+1,x
    bcs fc_allocate_next_done
fc_allocate_wrap
    clr FH_CLUSTER,x
    ldaa #2
    staa FH_CLUSTER+1,x
fc_allocate_next_done
    rts

; Mount counts include the complete BPB extent, but allocation/free-space
; exclude cluster indices whose values coincide with FAT reserved markers.
fc_allocation_limit
    ldx $07
    ldaa FH_BITS,x
    cmpa #12
    bne fc_limit16
    ldaa #$0f
    bra fc_limit_max
fc_limit16
    ldaa #$ff
fc_limit_max
    staa FH_VALUE,x
    ldab #$ee
    stab FH_VALUE+1,x
    cmpa FH_COUNT,x
    bcs fc_limit_ready
    bne fc_limit_actual
    cmpb FH_COUNT+1,x
    bls fc_limit_ready
fc_limit_actual
    ldaa FH_COUNT,x
    staa FH_VALUE,x
    ldaa FH_COUNT+1,x
    staa FH_VALUE+1,x
fc_limit_ready
    clra
    rts

; Metadata lookup descriptor: target BE16, native handle-list BE16.
; Handles are linked 59-byte allocations:
; original next pointer + 48-byte body + four handle bytes + five cache bytes.
fc_handle_meta
    ldx $07
    ldaa 0,x
    ldab 1,x
    staa BUF
    stab BUF+1
    ldx 2,x
    clrb
fc_handle_meta_loop
    stx LBA
    inx
    inx
    cpx BUF
    beq fc_meta_index
    ldx LBA
    ldx 0,x
    beq fc_meta_missing
    incb
    cmpb #32
    bcs fc_handle_meta_loop
    bra fc_meta_missing
fc_meta_index
    ldx LBA
    ldab #50
fc_meta_tail
    inx
    decb
    bne fc_meta_tail
    clra
    rts
fc_meta_missing
    ldx #0
    ldaa #16
    rts
