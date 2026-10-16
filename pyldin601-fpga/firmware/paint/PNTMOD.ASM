; Immutable PGM cache in unused GPU SRAM, after the original PAL snapshot.
; Validate the whole new module before releasing the running one. Rollback
; can reload a previous module without asking an unavailable disk to respond.
    include PNTABI.INC
    include DMA.INC
    public module_select
    public module_valid
    extern backend_cached
    extern backend_stream
    extern backend_arg
    extern p_kind
    extern p_preview_ext
    extern p_file_buffer
    extern io_handle
    extern io_error
    extern io_begin
    extern io_close
    extern io_read
    extern io_count
    extern io_size
    extern paint_dma
    extern dma_reset
    extern dma_run
    section
module_valid ds 3
module_sizes ds 6
module_index ds 1
module_base ds 2
module_size ds 2
module_pos ds 2
module_next ds 2
module_buffer ds 2
module_count ds 2
module_left ds 2
module_open ds 4
module_error ds 1
module_header ds 16
module_desc ds 8
module_reloc ds 2
module_code ds 2
module_codeoff ds 2
module_records ds 2
module_bound ds 2
module_mask ds 1
    ends
; X=absolute PGM path already chosen by canvas_module.
module_select
    stx module_open
    clr module_error
    clr module_index
    ldaa p_kind
    cmpa #4
    beq module_ham
    tst p_preview_ext
    beq module_chosen
    inc module_index
    bra module_chosen
module_ham
    ldaa #2
    staa module_index
module_chosen
    ldx #module_bases
    ldab module_index
    jsr module_offset
    ldaa 0,x
    staa module_base
    clr module_base+1
    ldx #module_valid
    ldab module_index
    jsr module_offset
    tst 0,x
    bne module_hit
    jsr module_cache
    tsta
    beq *+5
    jmp module_return
    jsr module_check
    tsta
    beq *+5
    jmp module_return
    ldx #module_sizes
    ldab module_index
    aslb
    jsr module_offset
    ldaa module_size
    ldab module_size+1
    staa 0,x
    stab 1,x
    ldx #module_valid
    ldab module_index
    jsr module_offset
    inc 0,x
    bra module_ready
module_hit
    ldx #module_sizes
    ldab module_index
    aslb
    jsr module_offset
    ldx 0,x
    stx module_size
module_ready
    ldx #0
    stx module_pos
    ldx #module_stream
    stx backend_stream
    jmp backend_cached
module_return
    rts
module_offset
    tstb
    beq module_return
module_offset_next
    inx
    decb
    bne module_offset_next
    rts
module_cache
    ldx #0
    stx module_open+2
    ldaa #1
    ldx #module_open
    int $4a
    tsta
    beq *+5
    jmp module_return
    stab io_handle
    clra
    jsr io_begin
    tsta
    beq *+5
    jmp cache_close
    ldx #io_size
    ldaa 0,x
    oraa 1,x
    beq *+5
    jmp cache_invalid
    ldx 2,x
    stx module_size
    stx module_left
    ldaa module_size
    cmpa #$41
    bls *+5
    jmp cache_invalid
    bne cache_minimum
    tst module_size+1
    beq *+5
    jmp cache_invalid
cache_minimum
    tst module_size
    bne cache_copy_begin
    ldaa module_size+1
    cmpa #24
    bcs cache_invalid
cache_copy_begin
    ldx #0
    stx module_pos
cache_copy
    ldx #512
    ldaa module_left
    cmpa #2
    bcc cache_copy_size
    ldx module_left
cache_copy_size
    stx module_count
    stx io_count
    ldx p_file_buffer
    stx module_buffer
    jsr io_read
    bcs cache_close
    jsr module_descriptor
    ldx #paint_dma
    ldab #3
cache_swap
    ldaa 0,x
    psha
    ldaa 3,x
    staa 0,x
    pula
    staa 3,x
    inx
    decb
    bne cache_swap
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    beq *+5
    jmp cache_close
    ldaa module_pos+1
    adda module_count+1
    staa module_pos+1
    ldaa module_pos
    adca module_count
    staa module_pos
    ldaa module_left+1
    suba module_count+1
    staa module_left+1
    ldaa module_left
    sbca module_count
    staa module_left
    oraa module_left+1
    bne cache_copy
    clra
    bra cache_close
cache_invalid
    ldaa #65
cache_close
    staa module_error
    jsr io_close
    tst module_error
    bne cache_previous_error
    rts
cache_previous_error
    ldaa module_error
    rts
; A=0 read backend_arg=[ordinary pointer,BE16 count]; A=1 seek BE32.
module_stream
    tsta
    bne module_seek
    ldx backend_arg
    ldx 0,x
    stx module_buffer
    ldx backend_arg
    ldx 2,x
    stx module_count
    jmp module_read
module_seek
    cmpa #1
    beq *+5
    jmp module_bad
    ldx backend_arg
    ldaa 0,x
    oraa 1,x
    beq *+5
    jmp module_bad
    ldx 2,x
    stx module_next
    jsr module_range
    tsta
    beq *+5
    jmp module_return
    ldx module_next
    stx module_pos
    clra
    rts
module_range
    ldaa module_next
    cmpa module_size
    bcs module_range_ok
    bls *+5
    jmp module_bad
    ldaa module_next+1
    cmpa module_size+1
    bls *+5
    jmp module_bad
module_range_ok
    clra
    rts
module_read
    ldaa module_pos+1
    adda module_count+1
    staa module_next+1
    ldaa module_pos
    adca module_count
    staa module_next
    bcc *+5
    jmp module_bad
    jsr module_range
    tsta
    beq *+5
    jmp module_return
    jsr module_descriptor
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    beq *+5
    jmp module_return
    ldx module_next
    stx module_pos
    ldx module_count
    clra
    rts
module_descriptor
    jsr dma_reset
    ldx #paint_dma
    ldaa module_pos+1
    adda module_base+1
    staa DMA_SRC,x
    ldaa module_pos
    adca module_base
    staa DMA_SRC+1,x
    ldaa #$1f
    staa DMA_SRC+2,x
    ldaa module_buffer+1
    staa DMA_DST,x
    ldaa module_buffer
    staa DMA_DST+1,x
    ldaa module_count+1
    staa DMA_WIDTH,x
    ldaa module_count
    staa DMA_WIDTH+1,x
    rts
module_bad
    ldaa #65
    rts
; Preflight every descriptor and relocation without touching current code.
module_check
    ldx #0
    stx module_pos
    ldx #16
    stx module_count
    ldx #module_header
    stx module_buffer
    jsr module_read
    tsta
    beq *+5
    jmp module_return
    ldx module_header
    cpx #$a55a
    beq *+5
    jmp module_bad
    ldx module_header+8
    cpx #0
    beq *+5
    jmp module_bad
    ldx module_header+6
    stx module_code
    dex
    stx module_bound
    ldaa module_code
    bne check_code_size
    ldaa module_code+1
    cmpa #8
    bcc *+5
    jmp module_bad
check_code_size
    ldaa module_header+11
    adda module_code+1
    tab
    ldaa module_header+10
    adca module_code
    bcc *+5
    jmp module_bad
    cmpa #32
    bcs check_ram_ok
    beq *+5
    jmp module_bad
    tstb
    beq *+5
    jmp module_bad
check_ram_ok
    ldx module_header+2
    stx module_records
    ldaa module_header+3
    ldab module_header+2
    asla
    rolb
    bcc *+5
    jmp module_bad
    adda #16
    adcb #0
    bcc *+5
    jmp module_bad
    cmpb module_header+4
    beq *+5
    jmp module_bad
    cmpa module_header+5
    beq *+5
    jmp module_bad
    staa module_codeoff+1
    stab module_codeoff
    adda module_code+1
    adcb module_code
    bcc *+5
    jmp module_bad
    cmpa module_size+1
    beq *+5
    jmp module_bad
    cmpb module_size
    beq *+5
    jmp module_bad
    ldx module_codeoff
    stx module_pos
    ldx #8
    stx module_count
    ldx #module_desc
    stx module_buffer
    jsr module_read
    tsta
    beq *+5
    jmp module_return
    ldx module_desc+2
    cpx #$504e
    beq *+5
    jmp module_bad
    ldx module_desc+4
    cpx #$4231
    beq *+5
    jmp module_bad
    ldaa module_desc+7
    cmpa #PNT_ABI
    beq *+5
    jmp module_bad
    ldaa #1
    ldab p_kind
check_kind_bit
    tstb
    beq check_kind_ready
    asla
    decb
    bra check_kind_bit
check_kind_ready
    bita module_desc+6
    bne *+5
    jmp module_bad
    ldx #16
    stx module_pos
check_reloc
    ldx module_records
    cpx #0
    beq check_complete
    ldx #2
    stx module_count
    ldx #module_reloc
    stx module_buffer
    jsr module_read
    tsta
    beq *+5
    jmp module_return
    ldaa module_reloc
    cmpa module_bound
    bcs check_reloc_ok
    bls *+5
    jmp module_bad
    ldaa module_reloc+1
    cmpa module_bound+1
    bcs *+5
    jmp module_bad
check_reloc_ok
    ldx module_records
    dex
    stx module_records
    bra check_reloc
check_complete
    clra
    rts
module_bases db $20,$61,$a2
    end
