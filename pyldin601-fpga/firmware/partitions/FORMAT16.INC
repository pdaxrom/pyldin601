; FAT16 formatter: 512-byte sectors, 2 FATs of 256 sectors, 512 root entries,
; 2048 reserved sectors. Choose 1..64 sectors/cluster by actual cluster count.
; A temporary 32-byte descriptor is freed on every path. Publish BPB last.
format16_number
    jsr find_number
    bcc f16_found
    rts
f16_found
    ldx PR
    ldaa 11,x
    cmpa #$ff
    bne f16_busy
    ldaa 9,x
    cmpa #4
    beq f16_kind
    cmpa #6
    beq f16_kind
    cmpa #$0e
    beq f16_kind
    ldaa #9
    rts
f16_busy
    ldaa #15
    rts
f16_kind
    ; The compatible profile caps volumes at 2 GiB / 32-KiB clusters.
    tst 7,x
    bne f16_range
    ldaa 6,x
    cmpa #$40
    bcs f16_allocate
    bne f16_range
    ldaa 4,x
    oraa 5,x
    bne f16_range
f16_allocate
    jsr state_pointer
    ldaa $ee1e
    staa 60,x
    ldaa $ee1f
    staa 61,x
    ldx #32
    clrb
    int $2a
    cpx #0
    bne f16_allocated
    ldaa #6
    rts
f16_range
    ldaa #4
    rts
f16_allocated
    stx PA
    stx PP
    ldx #32
    stx PT
    jsr zero_memory
    jsr state_pointer
    ldaa 60,x
    ldab 61,x
    ldx PA
    staa 20,x
    stab 21,x
    ldx PR
    ldaa 4,x
    ldx PA
    staa 0,x
    staa 9,x
    ldx PR
    ldaa 5,x
    ldx PA
    staa 1,x
    staa 10,x
    ldx PR
    ldaa 6,x
    ldx PA
    staa 2,x
    staa 11,x
    ldx PR
    ldaa 7,x
    ldx PA
    staa 3,x
    staa 12,x
    ; data sectors = total - (2048 reserved + 512 FAT + 32 root).
    ldaa 9,x
    suba #$20
    staa 9,x
    ldaa 10,x
    sbca #$0a
    staa 10,x
    ldaa 11,x
    sbca #0
    staa 11,x
    ldaa 12,x
    sbca #0
    staa 12,x
    bcc f16_long_1
    jmp f16_bad_size
f16_long_1
    ldaa #1
    staa 8,x
f16_choose_cluster
    ldaa 12,x
    oraa 11,x
    bne f16_larger_cluster
    ldaa 10,x
    cmpa #$ff
    bcs f16_check_min
    bne f16_larger_cluster
    ldaa 9,x
    cmpa #$ee
    bls f16_check_min
f16_larger_cluster
    asl 8,x
    bpl f16_cluster_supported
    jmp f16_bad_size
f16_cluster_supported
    lsr 12,x
    ror 11,x
    ror 10,x
    ror 9,x
    bra f16_choose_cluster
f16_check_min
    ldaa 10,x
    cmpa #$10
    bcc f16_profile_ready
    cmpa #$0f
    beq f16_long_2
    jmp f16_bad_size
f16_long_2
    ldaa 9,x
    cmpa #$f7
    bcc f16_long_3
    jmp f16_bad_size
f16_long_3
f16_profile_ready
    ldx PS
    stx PP
    ldx #512
    stx PT
    jsr zero_memory
    ; Invalidate old BPB before metadata writes.
    jsr f16_write
    tsta
    beq f16_long_4
    jmp f16_finish
f16_long_4
f16_clear
    ldx PA
    inc 4,x
    bne f16_clear_index
    inc 5,x
f16_clear_index
    ldaa 5,x
    cmpa #$0a
    bcs f16_clear_sector
    ldaa 4,x
    cmpa #$20
    bcc f16_publish
f16_clear_sector
    ldx PS
    clr 0,x
    clr 1,x
    clr 2,x
    clr 3,x
    ldx PA
    tst 4,x
    bne f16_clear_write
    ldaa 5,x
    cmpa #8
    beq f16_seed
    cmpa #9
    bne f16_clear_write
f16_seed
    ldx PS
    ldaa #$f8
    staa 0,x
    ldaa #$ff
    staa 1,x
    staa 2,x
    staa 3,x
f16_clear_write
    jsr f16_write
    tsta
    beq f16_clear
    jmp f16_finish
f16_bad_size
    ldaa #4
    jmp f16_finish
f16_publish
    ldx PS
    stx PT
    ldx #format_bpb
    stx PP
    ldab #62
f16_header_copy
    ldx PP
    ldaa 0,x
    inx
    stx PP
    ldx PT
    staa 0,x
    inx
    stx PT
    decb
    bne f16_header_copy
    ldx PA
    ldaa 8,x
    ldx PS
    staa 13,x
    clr 14,x
    ldaa #8
    staa 15,x
    clr 22,x
    ldaa #1
    staa 23,x
    ldaa #'6'
    staa 58,x
    ldx PA
    ldaa 2,x
    oraa 3,x
    beq f16_total16
    ldx PS
    clr 19,x
    clr 20,x
    ldx PA
    ldaa 0,x
    ldx PS
    staa 32,x
    ldx PA
    ldaa 1,x
    ldx PS
    staa 33,x
    ldx PA
    ldaa 2,x
    ldx PS
    staa 34,x
    ldx PA
    ldaa 3,x
    ldx PS
    staa 35,x
    bra f16_hidden
f16_total16
    ldx PA
    ldaa 0,x
    ldab 1,x
    ldx PS
    staa 19,x
    stab 20,x
f16_hidden
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
    ldx PA
    clr 4,x
    clr 5,x
    jsr f16_write
    tsta
    beq f16_long_5
    jmp f16_finish
f16_long_5
    jsr bpb_validate
    bcs f16_publish_bad
    ; Register the normalized type/extent in the existing 24-byte record.
    ldx PT
    ldaa FH_TOTAL,x
    oraa FH_TOTAL+1,x
    beq f16_record16
    ldaa #$ff
    ldab #$ff
    bra f16_record
f16_record16
    ldaa FH_TOTAL+2,x
    ldab FH_TOTAL+3,x
f16_record
    ldx PR
    staa 14,x
    stab 15,x
    ldaa #16
    staa 22,x
    ldaa #1
    staa 21,x
    clra
    bra f16_finish
f16_publish_bad
    ldaa #9
f16_finish
    psha
    ldx PA
    ldx 20,x
    int $2b
    pula
    rts
f16_write
    ldx PA
    ldaa PS
    staa 14,x
    ldaa PS+1
    staa 15,x
    ldx PR
    ldaa 0,x
    ldx PA
    adda 4,x
    staa 16,x
    ldx PR
    ldaa 1,x
    ldx PA
    adca 5,x
    staa 17,x
    ldx PR
    ldaa 2,x
    ldx PA
    adca 6,x
    staa 18,x
    ldx PR
    ldaa 3,x
    ldx PA
    adca 7,x
    staa 19,x
    bcs f16_write_bad
    ldab #14
f16_write_pointer
    inx
    decb
    bne f16_write_pointer
    ldaa #2
    int $e2
    rts
f16_write_bad
    ldaa #4
    rts
