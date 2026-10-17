; Bounded flood fill and implicit integer ellipses. No HD6303 instructions.
; The inactive zoom page owns two 16000-byte maps during flood discovery;
; canonical pixels, the clipboard and Undo are untouched until discovery ends.
    include PNTDEF.INC
    include DMA.INC
    public tools_state
    public tools_run
    public tools_poll
    public tools_abort
    extern p_tool
    extern p_width
    extern p_kind
    extern p_x0
    extern p_y0
    extern p_x1
    extern p_y1
    extern p_row
    extern p_colour
    extern p_colour_rgb
    extern p_row_dirty
    extern p_cached_y
    extern p_stroke_saved
    extern p_have_redo
    extern p_queue_head
    extern p_queue_count
    extern p_ignore
    extern draw_x
    extern draw_y
    extern draw_pixel
    extern draw_ensure
    extern draw_address
    extern draw_flush
    extern canvas_snapshot
    extern ham_dirty_left
    extern ham_dirty_right
    extern canvas_undo
    extern paint_idle
    extern paint_dma
    extern dma_reset
    extern dma_run
    extern spans
    extern add_b
    .ifdef PNT_TOOLS
    .define TOOLS_CODE
    .endif
    .ifndef PNT_EDIT
    .ifndef PNT_FILES
    .define TOOLS_CODE
    .endif
    .endif
    section
tools_state
t_x ds 2
t_scan ds 2
t_y ds 1
t_map_y ds 1
t_left ds 2
t_right ds 2
t_top ds 1
t_bottom ds 1
t_first ds 1
t_last ds 1
t_bound ds 2
t_saved_x ds 2
t_pointer ds 2
t_up ds 2
t_down ds 2
t_visit ds 2
t_other ds 2
t_queue ds 2
t_flags ds 2
t_head ds 1
t_tail ds 1
t_count ds 1
t_target ds 3
t_error ds 1
t_page ds 1
t_buffer ds 2
t_direction ds 1
t_plane ds 1
t_offset ds 2
t_temp ds 2
t_mask ds 1
t_byte ds 1
e_a ds 4
e_b ds 4
e_f ds 4
e_sx ds 4
e_sy ds 4
e_stepx ds 4
e_stepy ds 4
t_q ds 4
m_value ds 4
m_factor ds 2
m_count ds 1
e_width ds 2
e_height ds 1
e_parity ds 1
    ends
    .ifdef TOOLS_CODE
tools_run
    clr t_error
    clr p_stroke_saved
    ldaa p_tool
    cmpa #P_TOOL_FLOOD
    beq tools_flood
    cmpa #P_TOOL_ELLIPSE
    beq tools_ellipse
    cmpa #P_TOOL_SOLID
    beq tools_ellipse
    ldaa #65
    rts
tools_flood
    jsr flood
    bra tools_result
tools_ellipse
    jsr ellipse
tools_result
    staa t_error
    tsta
    bne tools_abort
    jsr draw_flush
    staa t_error
    tsta
    bne tools_abort
    bra tools_done
tools_abort
    clr p_row_dirty
    ldaa #$ff
    staa p_cached_y
    tst p_stroke_saved
    beq tools_done
    clra
    jsr canvas_undo
    tsta
    beq tools_rolled_back
    staa t_error
    bra tools_done
tools_rolled_back
    clr p_have_redo
tools_done
    clr p_queue_count
    clr p_queue_head
    ldaa #1
    staa p_ignore
    ldaa t_error
    cmpa #$ff
    bne tools_return
    ; A held Esc must not also close Paint after cancelling this operation.
tools_release
    int $10
    cmpa #27
    beq tools_consume
    cmpa #3
    beq tools_consume
    ldaa $ed31
    cmpa #27
    beq tools_wait_release
    cmpa #3
    bne tools_cancelled
tools_wait_release
    jsr paint_idle
    bra tools_release
tools_consume
    int $11
    bra tools_release
tools_cancelled
    clra
tools_return
    rts
; Escape/Ctrl+C cancel. Ordinary mouse events are drained by paint_idle;
; right-click remains the background drawing button, never an implicit cancel.
tools_poll
    jsr paint_idle
    int $10
    cmpa #27
    beq tools_cancel_key
    cmpa #3
    beq tools_cancel_key
    clra
    rts
tools_cancel_key
    int $11
    ldaa #$ff
    rts
tools_pause
    ldaa t_x+1
    anda #31
    beq tools_poll
    clra
    rts
; Canonical row and colour comparison, preserving t_x/t_y.
tools_row
    ldaa t_y
    jmp draw_ensure
tools_match
    ldx t_x
    stx draw_x
    jsr draw_address
    ldaa p_kind
    cmpa #4
    beq tools_match_rgb
    ldaa 0,x
    cmpa t_target
    bra tools_match_end
tools_match_rgb
    ldaa 0,x
    cmpa t_target
    bne tools_match_end
    ldaa 1,x
    cmpa t_target+1
    bne tools_match_end
    ldaa 2,x
    cmpa t_target+2
tools_match_end
    bne tools_not_match
    clra
    rts
tools_not_match
    ldaa #1
    rts
; X=bitmap base -> addressed byte, t_mask=bit at t_x.
bit_pointer
    ldaa t_x+1
    ldab t_x
    lsrb
    rora
    lsrb
    rora
    lsrb
    rora
    staa t_byte
    ldaa #$80
    ldab t_x+1
    andb #7
bit_shift
    tstb
    beq bit_ready
    lsra
    decb
    bra bit_shift
bit_ready
    staa t_mask
    ldab t_byte
    jmp add_b
bit_test
    jsr bit_pointer
    ldaa 0,x
    anda t_mask
    rts
bit_set
    jsr bit_pointer
    ldaa 0,x
    oraa t_mask
    staa 0,x
    rts
; A=0 read/1 write, B=0 frontier/1 visited, X=ordinary 80-byte buffer.
map_transfer
    stx t_buffer
    staa t_direction
    stab t_plane
    clr t_offset
    ldaa t_map_y
    staa t_offset+1
    asl t_offset+1
    rol t_offset
    asl t_offset+1
    rol t_offset
    asl t_offset+1
    rol t_offset
    asl t_offset+1
    rol t_offset
    ldx t_offset
    stx t_temp
    asl t_offset+1
    rol t_offset
    asl t_offset+1
    rol t_offset
    ldaa t_offset+1
    adda t_temp+1
    staa t_offset+1
    ldaa t_offset
    adca t_temp
    tst t_plane
    beq map_offset_ready
    adda #$40
map_offset_ready
    staa t_offset
    jsr dma_reset
    ldx #paint_dma
    tst t_direction
    bne map_write
    jsr map_gpu_address
    jsr map_ram_address
    bra map_launch
map_write
    jsr map_ram_address
    jsr map_gpu_address
map_launch
    ldx #paint_dma
    ldaa #80
    staa DMA_WIDTH,x
    ldaa #DMA_COPY
    jmp dma_run
map_gpu_address
    ldaa t_offset+1
    staa 0,x
    ldaa t_offset
    staa 1,x
    ldaa t_page
    staa 2,x
    inx
    inx
    inx
    rts
map_ram_address
    ldaa t_buffer+1
    staa 0,x
    ldaa t_buffer
    staa 1,x
    inx
    inx
    inx
    rts
; At most 200 distinct queued rows. Flags prevent duplicate queue entries.
row_push
    ldab t_map_y
    ldx t_flags
    jsr add_b
    tst 0,x
    bne row_push_ok
    inc 0,x
    ldx t_queue
    ldab t_tail
    jsr add_b
    ldaa t_map_y
    staa 0,x
    inc t_count
    inc t_tail
    ldaa t_tail
    cmpa #200
    bcs row_push_ok
    clr t_tail
row_push_ok
    clra
    rts
row_pop
    ldx t_queue
    ldab t_head
    jsr add_b
    ldaa 0,x
    staa t_y
    staa t_map_y
    tab
    ldx t_flags
    jsr add_b
    clr 0,x
    dec t_count
    inc t_head
    ldaa t_head
    cmpa #200
    bcs row_pop_ok
    clr t_head
row_pop_ok
    rts
flood
    ldx p_x0
    stx t_x
    ldaa p_y0
    staa t_y
    jsr tools_row
    tsta
    beq *+5
    jmp tools_return
    ldx t_x
    stx draw_x
    jsr draw_address
    ldaa 0,x
    staa t_target
    ldaa 1,x
    staa t_target+1
    ldaa 2,x
    staa t_target+2
    ldaa p_kind
    cmpa #4
    beq flood_same_rgb
    ldaa p_colour
    cmpa t_target
    bra flood_same_end
flood_same_rgb
    ldx #p_colour_rgb
    ldaa 0,x
    cmpa t_target
    bne flood_same_end
    ldaa 1,x
    cmpa t_target+1
    bne flood_same_end
    ldaa 2,x
    cmpa t_target+2
flood_same_end
    bne flood_workspace
    clra
    rts
flood_workspace
    ; The requested front remains visible; choose the other zoom frame.
    ldaa #$1c
    ldab $e655
    cmpb #5
    beq flood_page
    ldaa #$15
flood_page
    staa t_page
    ldx #spans
    ldab #80
    jsr add_b
    stx t_visit
    ldab #80
    jsr add_b
    stx t_other
    ldab #80
    jsr add_b
    stx t_queue
    ldab #200
    jsr add_b
    stx t_flags
    ldx #spans
    ldab #255
    jsr add_b
    ldab #255
    jsr add_b
    ldab #255
    jsr add_b
    ldab #35
    jsr add_b
    stx t_temp
    ldx #spans
flood_clear_work
    clr 0,x
    inx
    cpx t_temp
    bne flood_clear_work
    clr t_head
    clr t_tail
    clr t_count
    jsr dma_reset
    ldx #paint_dma
    ldaa t_page
    staa DMA_DST+2,x
    ldaa #$80
    staa DMA_WIDTH+1,x
    ldaa #DMA_FILL
    jsr dma_run
    tsta
    beq *+5
    jmp tools_return
    ldx #spans
    jsr bit_set
    ldaa t_y
    staa t_map_y
    ldx #spans
    ldaa #1
    clrb
    jsr map_transfer
    tsta
    beq *+5
    jmp tools_return
    jsr row_push
flood_next_row
    tst t_count
    bne *+5
    jmp flood_apply
    jsr tools_poll
    tsta
    beq *+5
    jmp tools_return
    jsr row_pop
    ldx #spans
    clra
    clrb
    jsr map_transfer
    tsta
    beq *+5
    jmp tools_return
    ldx t_visit
    clra
    ldab #1
    jsr map_transfer
    tsta
    beq *+5
    jmp tools_return
    ; Remove already-visited frontier bits before scanning a row again.
    clr t_first
    ldx #spans
    ldab #80
flood_filter
    ldaa 80,x
    coma
    anda 0,x
    staa 0,x
    oraa t_first
    staa t_first
    inx
    decb
    bne flood_filter
    ldx t_other
    ldab #80
flood_clear_front
    clr 0,x
    inx
    decb
    bne flood_clear_front
    ldx t_other
    ldaa #1
    clrb
    jsr map_transfer
    tsta
    beq *+5
    jmp tools_return
    tst t_first
    bne *+5
    jmp flood_next_row
    jsr tools_row
    tsta
    beq *+5
    jmp tools_return
    ldx #0
    stx t_x
flood_scan
    ldx #spans
    jsr bit_test
    bne *+5
    jmp flood_advance
    ldx t_visit
    jsr bit_test
    beq *+5
    jmp flood_advance
    jsr tools_match
    tsta
    beq *+5
    jmp flood_advance
    ldx t_x
    stx t_left
flood_left
    ldx t_x
    cpx #0
    beq flood_left_end
    dex
    stx t_x
    ldx t_visit
    jsr bit_test
    bne flood_left_restore
    jsr tools_match
    tsta
    beq flood_left
flood_left_restore
    ldx t_x
    inx
    stx t_x
flood_left_end
    ldx t_x
    stx t_left
flood_right
    jsr tools_match
    tsta
    bne flood_right_end
    ldx t_visit
    jsr bit_test
    bne flood_right_end
    ldx t_visit
    jsr bit_set
    ldx t_x
    inx
    stx t_x
    cpx p_width
    beq flood_right_end
    bra flood_right
flood_right_end
    ldx t_x
    stx t_scan
    dex
    stx t_right
    ldaa t_y
    beq flood_below
    deca
    jsr flood_neighbour
    tsta
    beq *+5
    jmp tools_return
flood_below
    ldaa t_y
    cmpa #199
    beq flood_run_done
    inca
    jsr flood_neighbour
    tsta
    beq *+5
    jmp tools_return
flood_run_done
    ldx t_scan
    stx t_x
    cpx p_width
    beq flood_row_done
    jmp flood_scan
flood_advance
    ldx t_x
    inx
    stx t_x
    cpx p_width
    beq flood_row_done
    jsr tools_pause
    tsta
    beq *+5
    jmp tools_return
    jmp flood_scan
flood_row_done
    ldaa t_y
    staa t_map_y
    ldx t_visit
    ldaa #1
    ldab #1
    jsr map_transfer
    tsta
    beq *+5
    jmp tools_return
    jmp flood_next_row
flood_neighbour
    staa t_map_y
    clra
    clrb
    ldx t_other
    jsr map_transfer
    tsta
    bne flood_neighbour_return
    ldx t_left
    stx t_x
flood_mark
    ldx t_other
    jsr bit_set
    ldx t_x
    cpx t_right
    beq flood_mark_done
    inx
    stx t_x
    bra flood_mark
flood_mark_done
    ldx t_other
    ldaa #1
    clrb
    jsr map_transfer
    tsta
    bne flood_neighbour_return
    jsr row_push
flood_neighbour_return
    rts
flood_apply
    clr t_y
flood_apply_row
    ldaa t_y
    staa t_map_y
    ldx #spans
    clra
    ldab #1
    jsr map_transfer
    tsta
    beq *+5
    jmp tools_return
    ; Avoid row decoding and re-encoding when no visited pixels exist.
    ldx #spans
    ldab #80
    clra
flood_any
    oraa 0,x
    inx
    decb
    bne flood_any
    tsta
    bne *+5
    jmp flood_apply_row_end
    jsr tools_row
    tsta
    beq *+5
    jmp tools_return
    tst p_stroke_saved
    bne flood_apply_saved
    jsr canvas_snapshot
    tsta
    beq *+5
    jmp tools_return
    inc p_stroke_saved
flood_apply_saved
    ldx #0
    stx t_x
    stx ham_dirty_left
    ldx p_width
    dex
    stx ham_dirty_right
    ldx #p_row
    stx t_pointer
    clr t_byte
    ldaa #$80
    staa t_mask
flood_apply_pixel
    ldx #spans
    ldab t_byte
    jsr add_b
    ldaa 0,x
    anda t_mask
    beq flood_apply_next
    ldx t_pointer
    ldaa p_kind
    cmpa #4
    beq flood_apply_rgb
    ldaa p_colour
    staa 0,x
    bra flood_apply_dirty
flood_apply_rgb
    ldx #p_colour_rgb
    ldaa 0,x
    ldab 1,x
    ldx t_pointer
    staa 0,x
    stab 1,x
    ldx #p_colour_rgb
    ldaa 2,x
    ldx t_pointer
    staa 2,x
flood_apply_dirty
    ldaa #1
    staa p_row_dirty
flood_apply_next
    jsr tools_pause
    tsta
    beq *+5
    jmp tools_return
    ldx t_pointer
    inx
    ldaa p_kind
    cmpa #4
    bne flood_pointer_ready
    inx
    inx
flood_pointer_ready
    stx t_pointer
    lsr t_mask
    bne flood_mask_ready
    inc t_byte
    ldaa #$80
    staa t_mask
flood_mask_ready
    ldx t_x
    inx
    stx t_x
    cpx p_width
    bne flood_apply_pixel
    jsr draw_flush
    tsta
    beq *+5
    jmp tools_return
flood_apply_row_end
    inc t_y
    ldaa t_y
    cmpa #200
    beq flood_apply_done
    jmp flood_apply_row
flood_apply_done
    clra
    rts
tools_pixel
    ldx t_x
    stx draw_x
    ldaa t_y
    staa draw_y
    jmp draw_pixel
; Unsigned endpoint sorting. Arithmetic thereafter uses signed 32-bit error
; differences, bounded below 2^30 for every 640x200 canvas.
ellipse
    ldx p_x0
    stx t_left
    ldx p_x1
    stx t_right
    ldaa p_x0
    cmpa p_x1
    bcs ellipse_x_sorted
    bhi ellipse_x_swap
    ldx #p_x0
    ldaa 1,x
    ldx #p_x1
    cmpa 1,x
    bls ellipse_x_sorted
ellipse_x_swap
    ldx p_x0
    stx t_right
    ldx p_x1
    stx t_left
ellipse_x_sorted
    ldx t_left
    stx t_bound
    ldaa t_right+1
    suba t_left+1
    staa e_width+1
    ldaa t_right
    sbca t_left
    staa e_width
    ldx e_width
    inx
    stx e_width
    ldaa p_y0
    ldab p_y1
    cba
    bls ellipse_y_sorted
    psha
    tba
    pulb
ellipse_y_sorted
    staa t_top
    staa t_first
    stab t_bottom
    stab t_last
    sba
    nega
    inca
    staa e_height
    ldx #spans
    ldab #200
ellipse_clear
    ldaa #$ff
    staa 0,x
    staa 1,x
    staa 2,x
    staa 3,x
    inx
    inx
    inx
    inx
    decb
    bne ellipse_clear
    jsr q_zero
    ldx e_width
    stx t_q+2
    stx m_factor
    jsr q_multiply
    ldx #e_a
    jsr q_store
    jsr q_zero
    ldaa e_height
    staa t_q+3
    staa m_factor+1
    clr m_factor
    jsr q_multiply
    ldx #e_b
    jsr q_store
    jsr q_shift3
    ldx #e_stepx
    jsr q_store
    ldx #e_a
    jsr q_load
    jsr q_shift3
    ldx #e_stepy
    jsr q_store
    ldaa e_width+1
    deca
    anda #1
    staa e_parity
    ldx #e_b
    jsr q_load
    jsr q_shift2
    tst e_parity
    beq ellipse_sx
    jsr q_shift
ellipse_sx
    ldx #e_sx
    jsr q_store
    ldx #e_a
    jsr q_load
    clr m_factor
    ldaa e_height
    suba #2
    bcc ellipse_sy_factor
    ldaa #1
ellipse_sy_factor
    staa m_factor+1
    jsr q_multiply
    jsr q_shift2
    ldaa e_height
    cmpa #1
    bne ellipse_sy
    jsr q_negate
ellipse_sy
    ldx #e_sy
    jsr q_store
    ldx #e_a
    jsr q_load
    ldaa e_height
    clrb
    asla
    rolb
    suba #1
    sbcb #0
    staa m_factor+1
    stab m_factor
    jsr q_multiply
    jsr q_negate
    tst e_parity
    beq ellipse_f
    ldx #e_b
    jsr q_add
ellipse_f
    ldx #e_f
    jsr q_store
    ldx e_width
    dex
    stx t_temp
    lsr t_temp
    ror t_temp+1
    ldaa t_left+1
    adda t_temp+1
    staa t_left+1
    ldaa t_left
    adca t_temp
    staa t_left
    ldaa t_right+1
    suba t_temp+1
    staa t_right+1
    ldaa t_right
    sbca t_temp
    staa t_right
ellipse_row
    ldx t_left
    cpx t_bound
    beq ellipse_span
    ldx #e_f
    jsr q_load
    ldx #e_sx
    jsr q_add
    tst t_q
    bmi ellipse_expand
    ldaa t_q
    oraa t_q+1
    oraa t_q+2
    oraa t_q+3
    bne ellipse_span
ellipse_expand
    ldx #e_f
    jsr q_store
    ldx #e_sx
    jsr q_load
    ldx #e_stepx
    jsr q_add
    ldx #e_sx
    jsr q_store
    ldx t_left
    dex
    stx t_left
    ldx t_right
    inx
    stx t_right
    bra ellipse_row
ellipse_span
    ldaa t_top
    jsr span_pointer
    jsr ellipse_store
    ldaa t_bottom
    jsr span_pointer
    jsr ellipse_store
    jsr tools_poll
    tsta
    beq *+5
    jmp tools_return
    ldaa t_bottom
    suba t_top
    cmpa #2
    bcs ellipse_draw
    ldx #e_f
    jsr q_load
    ldx #e_sy
    jsr q_sub
    ldx #e_f
    jsr q_store
    ldx #e_sy
    jsr q_load
    ldx #e_stepy
    jsr q_sub
    ldx #e_sy
    jsr q_store
    inc t_top
    dec t_bottom
    jmp ellipse_row
ellipse_store
    ldaa t_left
    ldab t_left+1
    staa 0,x
    stab 1,x
    ldaa t_right
    ldab t_right+1
    staa 2,x
    stab 3,x
    rts
ellipse_draw
    ldaa t_first
    staa t_y
ellipse_draw_row
    ldaa t_y
    jsr span_pointer
    stx t_pointer
    ldx 0,x
    stx t_x
    ldaa t_y
    deca
    jsr span_pointer
    stx t_up
    ldaa t_y
    inca
    jsr span_pointer
    stx t_down
ellipse_pixel
    ldaa p_tool
    cmpa #P_TOOL_SOLID
    beq ellipse_plot
    ldaa t_y
    cmpa t_first
    beq ellipse_plot
    cmpa t_last
    beq ellipse_plot
    ldx t_pointer
    ldx 0,x
    cpx t_x
    beq ellipse_plot
    ldx t_pointer
    ldx 2,x
    cpx t_x
    beq ellipse_plot
    ldx t_up
    jsr span_outside
    tsta
    bne ellipse_plot
    ldx t_down
    jsr span_outside
    tsta
    beq ellipse_next
ellipse_plot
    jsr tools_pixel
    tsta
    beq *+5
    jmp tools_return
ellipse_next
    jsr tools_pause
    tsta
    beq *+5
    jmp tools_return
    ldx t_pointer
    ldx 2,x
    cpx t_x
    beq ellipse_draw_next
    ldx t_x
    inx
    stx t_x
    jmp ellipse_pixel
ellipse_draw_next
    jsr draw_flush
    tsta
    beq *+5
    jmp tools_return
    ldaa t_y
    cmpa t_last
    beq ellipse_done
    inc t_y
    jmp ellipse_draw_row
ellipse_done
    clra
    rts
span_outside
    ldaa t_x
    cmpa 0,x
    bcs span_yes
    bhi span_right
    ldaa t_x+1
    cmpa 1,x
    bcs span_yes
span_right
    ldaa t_x
    cmpa 2,x
    bcs span_no
    bhi span_yes
    ldaa t_x+1
    cmpa 3,x
    bhi span_yes
span_no
    clra
    rts
span_yes
    ldaa #1
    rts
span_pointer
    clrb
    asla
    rolb
    asla
    rolb
    staa t_temp+1
    stab t_temp
    ldx #spans
    stx t_saved_x
    ldaa t_temp+1
    adda t_saved_x+1
    staa t_temp+1
    ldaa t_temp
    adca t_saved_x
    staa t_temp
    ldx t_temp
    rts
; Tiny BE32 accumulator and a portable 32x16 shift/add multiplier.
q_load
    ldaa 0,x
    staa t_q+0
    ldaa 1,x
    staa t_q+1
    ldaa 2,x
    staa t_q+2
    ldaa 3,x
    staa t_q+3
    rts
q_store
    ldaa t_q+0
    staa 0,x
    ldaa t_q+1
    staa 1,x
    ldaa t_q+2
    staa 2,x
    ldaa t_q+3
    staa 3,x
    rts
q_add
    ldaa t_q+3
    adda 3,x
    staa t_q+3
    ldaa t_q+2
    adca 2,x
    staa t_q+2
    ldaa t_q+1
    adca 1,x
    staa t_q+1
    ldaa t_q+0
    adca 0,x
    staa t_q+0
    rts
q_sub
    ldaa t_q+3
    suba 3,x
    staa t_q+3
    ldaa t_q+2
    sbca 2,x
    staa t_q+2
    ldaa t_q+1
    sbca 1,x
    staa t_q+1
    ldaa t_q+0
    sbca 0,x
    staa t_q+0
    rts
q_zero
    clr t_q+0
    clr t_q+1
    clr t_q+2
    clr t_q+3
    rts
q_shift3
    jsr q_shift
q_shift2
    jsr q_shift
q_shift
    asl t_q+3
    rol t_q+2
    rol t_q+1
    rol t_q
    rts
q_negate
    com t_q+0
    com t_q+1
    com t_q+2
    com t_q+3
    inc t_q+3
    bne q_negate_done
    inc t_q+2
    bne q_negate_done
    inc t_q+1
    bne q_negate_done
    inc t_q
q_negate_done
    rts
q_multiply
    ldx #m_value
    jsr q_store
    jsr q_zero
    ldaa #16
    staa m_count
q_multiply_bit
    lsr m_factor
    ror m_factor+1
    bcc q_multiply_shift
    ldx #m_value
    jsr q_add
q_multiply_shift
    asl m_value+3
    rol m_value+2
    rol m_value+1
    rol m_value
    dec m_count
    bne q_multiply_bit
    rts
    .else
tools_run
tools_poll
tools_abort
    clra
    rts
    .endif
    end
