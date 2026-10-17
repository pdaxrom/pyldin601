; Portable MC6800 PAL table builder. RGB666 palette and signed Q9 gains;
; the waveform and the original table move through flat DMA, never RAMMAN.
    include PNTDEF.INC
    include DMA.INC
    public palette_default
    public palette_index
    public palette_ham
    public palette_save
    public palette_restore
    public pal_snapshot
    public palette_undo
    extern paint_dma
    extern pal_wave
    extern dma_reset
    extern dma_run
    extern paint_idle
    extern p_palette
    extern p_palette_end
    extern p_kind
    extern p_original_read
    extern p_palette_saved
    extern p_row
    extern p_cached_y
    extern p_row_dirty
    extern src
    extern dst
    extern copy_n
    section
pal_pointer ds 2
pal_walk ds 2
pal_phase ds 1
pal_level ds 1
pal_channel ds 1
pal_rgb ds 3
pal_component ds 1
pal_wave_ptr ds 2
pal_bias ds 2
pal_acc ds 2
pal_gain ds 1
pal_sign ds 1
pal_factor ds 1
pal_value ds 2
pal_product ds 2
pal_steps ds 1
pal_index ds 1
pal_result ds 1
pal_undo_slot ds 1
    ends
palette_default
    ldx #p_palette
    clra
pal_default_clear
    staa 0,x
    inx
    cpx #p_palette_end
    bne pal_default_clear
    ldaa p_kind
    cmpa #2
    beq pal_four_default
    cmpa #3
    bcc pal_cube_default
    ldx #p_palette
    ldaa #63
    staa 3,x
    staa 4,x
    staa 5,x
    clra
    rts
pal_four_default
    ldx #native_four
    stx pal_pointer
    ldx #p_palette
    stx pal_walk
    ldab #12
pal_four_copy
    ldx pal_pointer
    ldaa 0,x
    inx
    stx pal_pointer
    ldx pal_walk
    staa 0,x
    inx
    stx pal_walk
    decb
    bne pal_four_copy
    clra
    rts
pal_cube_default
    ldx #p_palette
    stx pal_pointer
    clr pal_index
pal_cube_next
    ldaa pal_index
    ldab p_kind
    cmpb #4
    beq pal_cube_ham
    lsra
    lsra
    lsra
    lsra
    lsra
    jsr times_nine
    ldx pal_pointer
    staa 0,x
    ldaa pal_index
    lsra
    lsra
    anda #7
    jsr times_nine
    staa 1,x
    ldaa pal_index
    anda #3
    jsr times_twentyone
    staa 2,x
    bra pal_cube_advance
pal_cube_ham
    lsra
    lsra
    lsra
    lsra
    anda #3
    jsr times_twentyone
    ldx pal_pointer
    staa 0,x
    ldaa pal_index
    lsra
    lsra
    anda #3
    jsr times_twentyone
    staa 1,x
    ldaa pal_index
    anda #3
    jsr times_twentyone
    staa 2,x
pal_cube_advance
    inx
    inx
    inx
    stx pal_pointer
    inc pal_index
    bne pal_cube_next
    clra
    rts
times_nine
    staa pal_component
    asla
    asla
    asla
    adda pal_component
    rts
times_twentyone
    staa pal_component
    asla
    asla
    adda pal_component
    asla
    asla
    adda pal_component
    rts
; Expand A RGB666 to RGB888, preserving B/X.
pal_expand
    anda #63
    staa pal_component
    asla
    asla
    staa pal_value
    ldaa pal_component
    lsra
    lsra
    lsra
    lsra
    oraa pal_value
    rts
; A signed gain, B unsigned intensity; add signed product to pal_acc.
pal_multiply
    clr pal_sign
    tsta
    bpl pal_gain_abs
    inc pal_sign
    nega
pal_gain_abs
    staa pal_factor
    stab pal_value+1
    clr pal_value
    clr pal_product
    clr pal_product+1
    ldaa #8
    staa pal_steps
pal_mul_bit
    lsr pal_factor
    bcc pal_mul_shift
    ldaa pal_product+1
    adda pal_value+1
    staa pal_product+1
    ldaa pal_product
    adca pal_value
    staa pal_product
pal_mul_shift
    asl pal_value+1
    rol pal_value
    dec pal_steps
    bne pal_mul_bit
    tst pal_sign
    bne pal_subtract
    ldaa pal_acc+1
    adda pal_product+1
    staa pal_acc+1
    ldaa pal_acc
    adca pal_product
    staa pal_acc
    rts
pal_subtract
    ldaa pal_acc+1
    suba pal_product+1
    staa pal_acc+1
    ldaa pal_acc
    sbca pal_product
    staa pal_acc
    rts
pal_begin
    clr $e652
    clr $e65d
    rts
pal_wave_begin
    ldx #pal_wave
    stx pal_wave_ptr
    ldaa #32
    staa pal_phase
    rts
pal_sample
    ldaa pal_acc
    lsra
    ldx pal_wave_ptr
    staa 0,x
    inx
    stx pal_wave_ptr
    dec pal_phase
    rts
pal_wave_dma
    jsr dma_reset
    ldx #pal_wave
    stx pal_walk
    ldx #paint_dma
    ldaa pal_walk+1
    staa DMA_SRC,x
    ldaa pal_walk
    staa DMA_SRC+1,x
    ldaa #$5e
    staa DMA_DST,x
    ldaa #$e6
    staa DMA_DST+1,x
    ldaa #32
    staa DMA_WIDTH,x
    ldaa #DMA_DST_PORT
    staa DMA_MODE,x
    ldaa #DMA_COPY
    jmp dma_run
; Convert all 256 RGB666 entries to the 8192-sample indexed PAL table.
palette_index
    jsr pal_begin
    ldx #p_palette
    stx pal_pointer
    clr pal_index
pal_index_next
    ldx pal_pointer
    ldaa 0,x
    jsr pal_expand
    staa pal_rgb
    ldaa 1,x
    jsr pal_expand
    staa pal_rgb+1
    ldaa 2,x
    jsr pal_expand
    staa pal_rgb+2
    inx
    inx
    inx
    stx pal_pointer
    ldx #pal_coefficients
    stx pal_walk
    jsr pal_wave_begin
pal_index_phase
    ldx #7936
    stx pal_acc
    ldx pal_walk
    ldaa 0,x
    ldab pal_rgb
    jsr pal_multiply
    ldaa 1,x
    ldab pal_rgb+1
    jsr pal_multiply
    ldaa 2,x
    ldab pal_rgb+2
    jsr pal_multiply
    inx
    inx
    inx
    stx pal_walk
    jsr pal_sample
    bne pal_index_phase
    jsr pal_wave_dma
    tsta
    bne pal_index_return
    jsr paint_idle
    inc pal_index
    bne pal_index_next
pal_index_return
    rts
; HAM8 component tables: 64 intensities x32 phases for R, G, B.
palette_ham
    jsr pal_begin
    clr pal_channel
pal_channel_next
    ldx #6400
    ldaa pal_channel
    cmpa #1
    bne pal_bias_ready
    ldx #768
pal_bias_ready
    stx pal_bias
    clr pal_level
pal_level_next
    ldaa pal_level
    jsr pal_expand
    staa pal_rgb
    ldx #pal_coefficients
    ldab pal_channel
pal_gain_offset
    tstb
    beq pal_gain_ready
    inx
    decb
    bra pal_gain_offset
pal_gain_ready
    stx pal_walk
    jsr pal_wave_begin
pal_ham_phase
    ldx pal_bias
    stx pal_acc
    ldx pal_walk
    ldaa 0,x
    ldab pal_rgb
    jsr pal_multiply
    inx
    inx
    inx
    stx pal_walk
    jsr pal_sample
    bne pal_ham_phase
    jsr pal_wave_dma
    tsta
    bne pal_ham_return
    jsr paint_idle
    inc pal_level
    ldaa pal_level
    cmpa #64
    bne pal_level_next
    inc pal_channel
    ldaa pal_channel
    cmpa #3
    bne pal_channel_next
    clra
pal_ham_return
    rts
; Indexed palette is document data. Two GPU slots make Undo transactional;
; the other slot retains the live colours until programming succeeds.
pal_snapshot
    ldaa p_kind
    cmpa #3
    beq pal_snapshot_indexed
    clra
    rts
pal_snapshot_indexed
    ldaa pal_undo_slot
    ldx #p_palette
    jmp pal_store_slot
palette_undo
    ldaa p_kind
    cmpa #3
    beq pal_undo_indexed
    clra
    rts
pal_undo_indexed
    ldaa #$ff
    staa p_cached_y
    clr p_row_dirty
    ldaa pal_undo_slot
    ldx #p_row
    jsr pal_fetch_slot
    tsta
    bne pal_undo_return
    ldx #p_palette
    stx pal_pointer
    ldx #p_row
    stx pal_walk
pal_undo_compare
    ldx pal_walk
    ldaa 0,x
    inx
    stx pal_walk
    ldx pal_pointer
    cmpa 0,x
    bne pal_undo_change
    inx
    stx pal_pointer
    cpx #p_palette_end
    bne pal_undo_compare
    clra
pal_undo_return
    rts
pal_undo_change
    ldaa pal_undo_slot
    eora #1
    ldx #p_palette
    jsr pal_store_slot
    tsta
    bne pal_undo_return
    ldx #p_row
    stx src
    ldx #p_palette
    stx dst
    ldaa #3
    staa pal_channel
pal_undo_install
    clrb
    jsr copy_n
    dec pal_channel
    bne pal_undo_install
    jsr palette_index
    tsta
    bne pal_undo_rollback
    ldaa pal_undo_slot
    eora #1
    staa pal_undo_slot
    clra
    rts
pal_undo_rollback
    staa pal_result
    ldaa pal_undo_slot
    eora #1
    ldx #p_palette
    jsr pal_fetch_slot
    tsta
    bne pal_undo_return
    jsr palette_index
    tsta
    bne pal_undo_return
    ldaa pal_result
    rts
; A=slot (0/1), X=ordinary RGB table. The slots start after backend caches.
pal_store_slot
    jsr pal_slot_descriptor
    ldaa pal_walk+1
    staa DMA_SRC,x
    ldaa pal_walk
    staa DMA_SRC+1,x
    ldaa pal_level
    staa DMA_DST+1,x
    ldaa #P_PALETTE_PAGE
    staa DMA_DST+2,x
    bra pal_slot_run
pal_fetch_slot
    jsr pal_slot_descriptor
    ldaa pal_walk+1
    staa DMA_DST,x
    ldaa pal_walk
    staa DMA_DST+1,x
    ldaa pal_level
    staa DMA_SRC+1,x
    ldaa #P_PALETTE_PAGE
    staa DMA_SRC+2,x
pal_slot_run
    ldaa #3
    staa DMA_WIDTH+1,x
    ldaa #DMA_COPY
    jmp dma_run
pal_slot_descriptor
    stx pal_walk
    tsta
    beq pal_slot_zero
    ldaa #$e7
    bra pal_slot_ready
pal_slot_zero
    ldaa #$e4
pal_slot_ready
    staa pal_level
    jsr dma_reset
    ldx #paint_dma
    rts
palette_save
    tst p_palette_saved
    beq pal_save_begin
    clra
    rts
pal_save_begin
    ldaa $e65e
    cmpa #'G'
    beq pal_read_disabled
    ldaa #1
    bra pal_read_known
pal_read_disabled
    clra
pal_read_known
    staa p_original_read
    ldaa #1
    staa $e65f
    jsr pal_begin
    jsr dma_reset
    ldx #paint_dma
    ldaa #$5e
    staa DMA_SRC,x
    ldaa #$e6
    staa DMA_SRC+1,x
    ldaa #P_PALETTE_PAGE
    staa DMA_DST+2,x
    ldaa #32
    staa DMA_WIDTH+1,x
    ldaa #DMA_SRC_PORT
    staa DMA_MODE,x
    ldaa #DMA_COPY
    jsr dma_run
    staa pal_result
    bne pal_save_readback
    inc p_palette_saved
pal_save_readback
    ldaa p_original_read
    staa $e65f
    ldaa pal_result
    rts
palette_restore
    tst p_palette_saved
    bne pal_restore_begin
    clra
    rts
pal_restore_begin
    jsr pal_begin
    jsr dma_reset
    ldx #paint_dma
    ldaa #P_PALETTE_PAGE
    staa DMA_SRC+2,x
    ldaa #$5e
    staa DMA_DST,x
    ldaa #$e6
    staa DMA_DST+1,x
    ldaa #32
    staa DMA_WIDTH+1,x
    ldaa #DMA_DST_PORT
    staa DMA_MODE,x
    ldaa #DMA_COPY
    jsr dma_run
    staa pal_result
    bne pal_restore_readback
    clr p_palette_saved
pal_restore_readback
    ldaa p_original_read
    staa $e65f
    ldaa pal_result
    rts
native_four db 21,21,63,21,63,63,63,21,63,63,63,63
pal_coefficients
    include PALCOEF.ASM
    end
