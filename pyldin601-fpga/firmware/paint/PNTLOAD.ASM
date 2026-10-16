; Relocatable Paint backend loader. Prefer one leased RAMMAN page; ordinary
; RAM fallback uses the same native PGM and high-byte relocation records.
; DOS reads always target the ordinary bounce buffer, never C000 ROM space.
    include PNTABI.INC
    public backend_load
    public backend_cached
    public backend_stream
    public backend_arg
    public backend_close
    public backend_encode
    public backend_base
    public backend_banked
    public backend_lease
    public backend_kind
    public backend_params
    public paint_alloc
    extern backend_buffer
    section
backend_base ds 2
backend_banked ds 1
backend_lease ds 4
backend_kind ds 1
backend_params ds 2
backend_stream ds 2
backend_arg ds 2
load_cached ds 1
backend_group ds 1
backend_page ds 1
backend_top ds 2
backend_error ds 1
load_old_page ds 1
load_old_group ds 1
load_handle ds 1
load_live ds 1
load_open ds 4
load_io ds 4
load_header ds 16
load_position ds 4
load_records ds 2
load_code ds 2
load_limit ds 2
load_bytes ds 2
load_left ds 2
load_cursor ds 2
load_target ds 2
load_chunk ds 2
load_blocks ds 1
load_walk ds 2
safe_size ds 2
safe_align ds 1
safe_sp ds 2
    ends
; X=pathname, backend_kind=0..4. A=0 or native DOS error.
backend_load
    clr load_cached
    stx load_open
    jsr backend_close
    clr load_live
    ldaa $e6f0
    staa load_old_page
    ldaa $e6f1
    staa load_old_group
    ldx #0
    stx load_open+2
    ldaa #1
    ldx #load_open
    int $4a
    tsta
    beq load_opened
    rts
load_opened
    stab load_handle
    inc load_live
    bra load_source
; The caller has validated an immutable staged PGM. A callback reads/seeks
; that source without disk I/O; old code can therefore be restored offline.
backend_cached
    jsr backend_close
    ldaa #1
    staa load_cached
    clr load_live
    ldaa $e6f0
    staa load_old_page
    ldaa $e6f1
    staa load_old_group
load_source
    ldx #load_header
    stx load_io
    ldx #16
    stx load_chunk
    jsr load_read
    tsta
    beq load_validate
    jmp load_failed
load_validate
    ldx load_header
    cpx #$a55a
    beq *+5
    jmp load_invalid
    ldx load_header+8
    cpx #0
    beq *+5
    jmp load_invalid
    ldaa load_header+3
    ldab load_header+2
    asla
    rolb
    bcc *+5
    jmp load_invalid
    adda #16
    adcb #0
    bcc *+5
    jmp load_invalid
    cmpb load_header+4
    beq *+5
    jmp load_invalid
    cmpa load_header+5
    beq *+5
    jmp load_invalid
    ldx load_header+2
    stx load_records
    ldx load_header+6
    stx load_code
    ldaa load_header+6
    bne load_code_valid
    ldaa load_header+7
    cmpa #8
    bcc load_code_valid
    jmp load_invalid
load_code_valid
    dex
    stx load_limit
    ldaa load_header+7
    adda load_header+11
    staa load_bytes+1
    ldaa load_header+6
    adca load_header+10
    staa load_bytes
    bcc *+5
    jmp load_invalid
    cmpa #32
    bcs load_allocate
    bne *+5
    tst load_bytes+1
    beq load_allocate
    jmp load_invalid
load_allocate
    ldaa #$e5
    int $2e
    cpx #0
    beq load_plain
    ldaa #1
    ldab #1
    ldx #backend_lease
    int $e5
    tsta
    bne load_plain
    inc backend_banked
    ldaa backend_lease+3
    clr backend_group
load_bank_divide
    cmpa #6
    bcs load_bank_ready
    suba #6
    inc backend_group
    bra load_bank_divide
load_bank_ready
    inca
    staa backend_page
    ldx #$c000
    bra load_allocated
load_plain
    ldx #0
    clrb
    int $2a
    stx backend_top
    ldx load_bytes
    clrb
    jsr paint_alloc
    cpx #0
    bne load_allocated
    ldaa #66
    jmp load_failed
load_allocated
    stx backend_base
    stx load_target
    clr load_position
    clr load_position+1
    ldx load_header+4
    stx load_position+2
    jsr load_seek
    tsta
    beq load_copy_begin
    jmp load_failed
load_copy_begin
    ldx load_code
    stx load_left
load_copy_next
    ldx load_left
    cpx #0
    beq load_zero_begin
    ldx #512
    ldaa load_left
    cmpa #2
    bcc load_copy_count
    ldx load_left
load_copy_count
    stx load_chunk
    ldx #backend_buffer
    stx load_io
    jsr load_read
    tsta
    beq *+5
    jmp load_failed
    jsr load_map
    ldx #backend_buffer
    stx load_cursor
    ldx load_chunk
    stx load_walk
load_copy_byte
    ldx load_cursor
    ldaa 0,x
    inx
    stx load_cursor
    ldx load_target
    staa 0,x
    inx
    stx load_target
    ldx load_walk
    dex
    stx load_walk
    bne load_copy_byte
    jsr load_restore
    ldaa load_left+1
    suba load_chunk+1
    staa load_left+1
    ldaa load_left
    sbca load_chunk
    staa load_left
    bra load_copy_next
load_zero_begin
    jsr load_map
    ldx load_header+10
    stx load_left
load_zero_next
    ldx load_left
    cpx #0
    beq load_reloc_begin
    dex
    stx load_left
    ldx load_target
    clr 0,x
    inx
    stx load_target
    bra load_zero_next
load_reloc_begin
    jsr load_restore
    ldx #16
    stx load_position+2
    jsr load_seek
    tsta
    beq load_reloc_next
    jmp load_failed
load_reloc_next
    ldx load_records
    cpx #0
    bne *+5
    jmp load_descriptor
    ldaa #32
    tst load_records
    bne load_reloc_count
    cmpa load_records+1
    bcs load_reloc_count
    ldaa load_records+1
load_reloc_count
    staa load_blocks
    clrb
    asla
    rolb
    staa load_chunk+1
    stab load_chunk
    ldx #backend_buffer
    stx load_io
    jsr load_read
    tsta
    beq *+5
    jmp load_failed
    jsr load_map
    ldx #backend_buffer
    stx load_cursor
load_relocate
    ldx load_cursor
    ldaa 0,x
    cmpa load_limit
    bne load_reloc_compare
    ldaa 1,x
    cmpa load_limit+1
load_reloc_compare
    bcs load_reloc_valid
    jmp load_invalid
load_reloc_valid
    ldaa 1,x
    adda backend_base+1
    staa load_target+1
    ldaa 0,x
    adca backend_base
    staa load_target
    ldx load_target
    ldaa 1,x
    adda backend_base+1
    staa 1,x
    ldaa 0,x
    adca backend_base
    staa 0,x
    ldx load_cursor
    inx
    inx
    stx load_cursor
    ldx load_records
    dex
    stx load_records
    dec load_blocks
    bne load_relocate
    jsr load_restore
    jmp load_reloc_next
load_descriptor
    jsr load_map
    ldx backend_base
    ldaa 2,x
    cmpa #'P'
    bne load_invalid
    ldaa 3,x
    cmpa #'N'
    bne load_invalid
    ldaa 4,x
    cmpa #'B'
    bne load_invalid
    ldaa 5,x
    cmpa #'1'
    bne load_invalid
    ldaa 7,x
    cmpa #1
    bne load_invalid
    ldab backend_kind
    cmpb #5
    bcc load_invalid
    ldaa #1
load_mask
    tstb
    beq load_mask_ready
    asla
    decb
    bra load_mask
load_mask_ready
    bita 6,x
    beq load_invalid
    jsr load_restore
    tst load_live
    beq load_success
    ldaa load_handle
    int $4e
    clr load_live
    tsta
    bne load_failed
load_success
    clra
    rts
load_invalid
    ldaa #65
load_failed
    staa backend_error
    jsr load_restore
    tst load_live
    beq load_discard
    ldaa load_handle
    int $4e
    clr load_live
load_discard
    jsr backend_close
    ldaa backend_error
    rts
load_read
    ldx load_chunk
    stx load_io+2
    tst load_cached
    beq load_read_disk
    ldx #load_io
    stx backend_arg
    clra
    ldx backend_stream
    jsr 0,x
    bra load_read_result
load_read_disk
    ldaa load_handle
    ldx #load_io
    int $4c
load_read_result
    tsta
    bne load_read_return
    cpx load_chunk
    beq load_read_return
    ldaa #3
load_read_return
    rts
load_seek
    tst load_cached
    beq load_seek_disk
    ldx #load_position
    stx backend_arg
    ldaa #1
    ldx backend_stream
    jmp 0,x
load_seek_disk
    ldaa load_handle
    clrb
    ldx #load_position
    int $50
    rts
load_map
    tst backend_banked
    beq load_map_return
    ldaa backend_page
    staa $e6f0
    ldaa backend_group
    staa $e6f1
load_map_return
    rts
load_restore
    ldaa load_old_group
    staa $e6f1
    ldaa load_old_page
    staa $e6f0
    rts
backend_close
    ldx backend_base
    cpx #0
    beq backend_closed
    tst backend_banked
    beq backend_release_plain
    ldaa #2
    ldx #backend_lease
    int $e5
    bra backend_closed
backend_release_plain
    ldx backend_top
    int $2b
backend_closed
    clr backend_base
    clr backend_base+1
    clr backend_banked
    rts
backend_encode
    ldaa $e6f0
    psha
    ldaa $e6f1
    psha
    jsr load_map
    ldaa backend_params
    ldab backend_params+1
    ldx backend_base
    jsr 0,x
    staa backend_error
    pula
    staa $e6f1
    pula
    staa $e6f0
    ldaa backend_error
    rts
; X=bytes, B=0,3 or8. Guard INT2A's below-0100 wrap, including padding.
paint_alloc
    stx safe_size
    stab safe_align
    tsx
    stx safe_sp
    ldaa safe_sp+1
    suba safe_size+1
    staa safe_sp+1
    ldaa safe_sp
    sbca safe_size
    bcs safe_failed
    staa safe_sp
    tst safe_align
    beq safe_check
    ldab #7
    ldaa safe_align
    cmpa #3
    beq safe_padding
    cmpa #8
    bne safe_failed
    ldab #255
safe_padding
    ldaa safe_sp+1
    sba
    ldaa safe_sp
    sbca #0
    bcs safe_failed
safe_check
    tsta
    beq safe_failed
    ldx safe_size
    ldab safe_align
    int $2a
    rts
safe_failed
    ldx #0
    rts
    end
