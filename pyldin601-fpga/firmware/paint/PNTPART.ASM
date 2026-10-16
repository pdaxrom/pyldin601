; Incremental HAM rows. Retain the unmodified encoded prefix, seed the row
; backend with its held RGB, then stop once old/new held colours resynchronize.
; The result is byte-identical to a complete deterministic greedy re-encode.
    include PNTABI.INC
    include DMA.INC
    public ham_row_show
    extern p_row
    extern p_encoded
    extern p_enc_tail
    extern p_params
    extern ham_dirty_left
    extern ham_dirty_right
    extern backend_encode
    extern canvas_blit
    extern canvas_show
    extern paint_idle
    extern paint_dma
    extern dma_reset
    extern dma_run
    public part_y
    section
part_y ds 1
part_pos ds 2
part_count ds 2
part_left ds 2
part_source ds 2
part_new_ptr ds 2
part_old_ptr ds 2
part_new_rgb ds 3
part_old_rgb ds 3
part_code ds 1
part_value ds 1
part_product ds 1
part_copy_src ds 2
part_copy_dst ds 2
    ends
    .ifndef PNT_FILES
ham_row_show
    staa part_y
    ldx #p_enc_tail
    stx part_copy_src
    ldx #p_encoded
    stx part_copy_dst
    jsr part_copy
    tsta
    beq *+5
    jmp part_return
    ldx ham_dirty_left
    stx part_pos
    stx part_left
    jsr part_pointers
    clr part_old_rgb
    clr part_old_rgb+1
    clr part_old_rgb+2
    ; Most rows have a nearby base-colour command. Find the last reset
    ; backwards, then decode only its suffix instead of the whole prefix.
part_backwards
    ldx part_left
    cpx #0
    beq part_prefix
    dex
    stx part_left
    ldx part_old_ptr
    dex
    stx part_old_ptr
    ldaa 0,x
    cmpa #64
    bcc part_backwards_idle
    ldx #part_old_rgb
    jsr part_decode
    ldx part_old_ptr
    inx
    stx part_old_ptr
    ldx part_left
    inx
    stx part_left
    bra part_prefix
part_backwards_idle
    ldaa part_left+1
    anda #7
    bne part_backwards
    jsr paint_idle
    bra part_backwards
part_prefix
    ldx part_left
    cpx ham_dirty_left
    beq part_seed
    ldx part_old_ptr
    ldaa 0,x
    inx
    stx part_old_ptr
    ldx #part_old_rgb
    jsr part_decode
    ldx part_left
    inx
    stx part_left
    ldaa part_left+1
    anda #7
    bne part_prefix
    jsr paint_idle
    bra part_prefix
part_seed
    ldaa part_old_rgb
    ldab part_old_rgb+1
    staa part_new_rgb
    stab part_new_rgb+1
    ldaa part_old_rgb+2
    staa part_new_rgb+2
    ldx #ham_dirty_right
    ldaa 1,x
    ldx #ham_dirty_left
    suba 1,x
    staa part_count+1
    ldaa ham_dirty_right
    sbca ham_dirty_left
    staa part_count
    inc part_count+1
    bne part_encode
    inc part_count
part_encode
    jsr part_pointers
    ldx #p_params
    ldaa #PNT_PARTIAL
    staa PB_OPERATION,x
    ldaa part_count
    staa PB_WIDTH,x
    ldaa part_count+1
    staa PB_WIDTH+1,x
    ldaa part_source
    staa PB_SOURCE,x
    ldaa part_source+1
    staa PB_SOURCE+1,x
    ldaa part_new_ptr
    staa PB_DEST,x
    ldaa part_new_ptr+1
    staa PB_DEST+1,x
    ldx #part_new_rgb
    stx part_source
    ldx #p_params
    ldaa part_source
    staa PB_BYTES,x
    ldaa part_source+1
    staa PB_BYTES+1,x
    jsr backend_encode
    tsta
    bne part_fallback
    ldx part_count
    stx part_left
part_evaluate
    ldx part_new_ptr
    ldaa 0,x
    inx
    stx part_new_ptr
    ldx #part_new_rgb
    jsr part_decode
    ldx part_old_ptr
    ldaa 0,x
    inx
    stx part_old_ptr
    ldx #part_old_rgb
    jsr part_decode
    jsr part_advance
    ldx part_left
    dex
    stx part_left
    bne part_evaluate
    ldx part_pos
    cpx #320
    beq part_finish
    ldaa part_new_rgb
    cmpa part_old_rgb
    bne part_extend
    ldaa part_new_rgb+1
    cmpa part_old_rgb+1
    bne part_extend
    ldaa part_new_rgb+2
    cmpa part_old_rgb+2
    beq part_finish
part_extend
    jsr paint_idle
    ldx #1
    stx part_count
    jmp part_encode
part_finish
    jsr part_restore
    ldaa part_y
    jsr canvas_blit
    bra part_update_tail
part_fallback
    ; Optional extension: old ABI1 modules still work through full rows.
    jsr part_restore
    ldaa part_y
    jsr canvas_show
part_update_tail
    tsta
    beq *+5
    jmp part_return
    ldx #p_encoded
    stx part_copy_src
    ldx #p_enc_tail
    stx part_copy_dst
    jsr part_copy
part_return
    rts
part_restore
    ldx #p_params
    clr PB_OPERATION,x
    ldaa #1
    staa PB_WIDTH,x
    staa PB_BYTES,x
    ldaa #64
    staa PB_WIDTH+1,x
    staa PB_BYTES+1,x
    ldx #p_row
    stx part_source
    ldx #p_params
    ldaa part_source
    staa PB_SOURCE,x
    ldaa part_source+1
    staa PB_SOURCE+1,x
    ldx #p_encoded
    stx part_source
    ldx #p_params
    ldaa part_source
    staa PB_DEST,x
    ldaa part_source+1
    staa PB_DEST+1,x
    rts
part_pointers
    ldx #p_encoded
    stx part_new_ptr
    ldaa part_new_ptr+1
    adda part_pos+1
    staa part_new_ptr+1
    ldaa part_new_ptr
    adca part_pos
    staa part_new_ptr
    ldx #p_enc_tail
    stx part_old_ptr
    ldaa part_old_ptr+1
    adda part_pos+1
    staa part_old_ptr+1
    ldaa part_old_ptr
    adca part_pos
    staa part_old_ptr
    ldx part_pos
    stx part_source
    asl part_source+1
    rol part_source
    ldaa part_source+1
    adda part_pos+1
    staa part_source+1
    ldaa part_source
    adca part_pos
    staa part_source
    ldx #p_row
    stx part_copy_src
    ldaa part_source+1
    adda part_copy_src+1
    staa part_source+1
    ldaa part_source
    adca part_copy_src
    staa part_source
    rts
part_advance
    inc part_pos+1
    beq *+5
    jmp part_return
    inc part_pos
    rts
; A=HAM8 command, X=held RGB666 triplet. X is preserved.
part_decode
    staa part_code
    cmpa #64
    bcc part_component
    lsra
    lsra
    lsra
    lsra
    jsr part_level
    staa 0,x
    ldaa part_code
    lsra
    lsra
    anda #3
    jsr part_level
    staa 1,x
    ldaa part_code
    anda #3
    jsr part_level
    staa 2,x
    rts
part_component
    anda #63
    staa part_value
    ldaa part_code
    cmpa #128
    bcs part_blue
    cmpa #192
    bcs part_red
    ldaa part_value
    staa 1,x
    rts
part_blue
    ldaa part_value
    staa 2,x
    rts
part_red
    ldaa part_value
    staa 0,x
    rts
part_level
    staa part_product
    asla
    asla
    adda part_product
    asla
    asla
    adda part_product
    rts
part_copy
    jsr dma_reset
    ldx #paint_dma
    ldaa part_copy_src+1
    staa DMA_SRC,x
    ldaa part_copy_src
    staa DMA_SRC+1,x
    ldaa part_copy_dst+1
    staa DMA_DST,x
    ldaa part_copy_dst
    staa DMA_DST+1,x
    ldaa #64
    staa DMA_WIDTH,x
    ldaa #1
    staa DMA_WIDTH+1,x
    ldaa #DMA_COPY
    jmp dma_run
    .else
ham_row_show
    clra
    rts
    .endif
    end
