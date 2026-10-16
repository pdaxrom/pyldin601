; Drawing tools edit canonical pixels. A single row cache bounds RAM use;
; each changed stroke owns one canonical and encoded Undo snapshot.
    include PNTDEF.INC
    public draw_event
    public draw_flush
    public draw_finish
    public draw_pick
    public ham_dirty_left
    public ham_dirty_right
    extern canvas_read
    extern canvas_store
    extern canvas_show
    extern canvas_snapshot
    extern paint_idle
    extern canvas_getcode
    extern canvas_fill
    extern ham_row_show
    extern p_preview_ext
    extern p_kind
    extern p_width
    extern p_row
    extern p_cached_y
    extern p_row_dirty
    extern p_event_x
    extern p_event_y
    extern p_event_buttons
    extern p_prev_buttons
    extern p_stroke
    extern p_stroke_saved
    extern p_tool
    extern p_brush
    extern p_colour
    extern p_colour_rgb
    extern p_fg
    extern p_bg
    extern p_fg_rgb
    extern p_bg_rgb
    extern p_x0
    extern p_y0
    extern p_x1
    extern p_y1
    extern spans
    section
draw_error ds 1
ham_dirty_left ds 2
ham_dirty_right ds 2
draw_row ds 1
draw_pointer ds 2
draw_x ds 2
draw_y ds 1
brush_left ds 2
brush_top ds 2
brush_x ds 2
brush_y ds 2
brush_columns ds 1
brush_rows ds 1
line_x ds 2
line_y ds 1
line_dx ds 2
line_dy ds 2
line_sx ds 1
line_sy ds 1
line_error ds 2
line_twice ds 2
shape_left ds 2
shape_right ds 2
shape_top ds 1
shape_bottom ds 1
shape_x ds 2
shape_y ds 1
draw_button ds 1
draw_temp ds 1
span_left ds 2
span_right ds 2
span_pointer ds 2
span_y ds 1
span_x ds 2
fill_rectangle ds 7
    ends
draw_flush
    tst p_row_dirty
    beq flush_ok
    ldaa p_cached_y
    jsr canvas_store
    tsta
    bne flush_return
    ldaa p_cached_y
    ldab p_kind
    cmpb #4
    bne flush_full
    jsr ham_row_show
    bra flush_result
flush_full
    jsr canvas_show
flush_result
    tsta
    bne flush_return
    clr p_row_dirty
flush_ok
    clra
flush_return
    rts
draw_finish
    clr p_stroke
    clr p_prev_buttons
    jmp draw_flush
; Load A=row, flushing a previously changed row first.
ensure_row
    staa draw_row
    cmpa p_cached_y
    beq row_ready
    jsr draw_flush
    tsta
    bne row_return
    ldaa draw_row
    jsr canvas_read
    tsta
    bne row_return
    ldaa draw_row
    staa p_cached_y
    ldaa p_kind
    cmpa #4
    bne row_ready
    ldaa draw_row
    jsr canvas_getcode
    tsta
    bne row_return
row_ready
    clra
row_return
    rts
; X=address of draw_x in the loaded row, including HAM RGB triplets.
pixel_address
    ldx #draw_x
    ldaa 1,x
    ldab 0,x
    staa draw_pointer+1
    stab draw_pointer
    ldaa p_kind
    cmpa #4
    bne pixel_offset
    asl draw_pointer+1
    rol draw_pointer
    ldaa draw_pointer+1
    adda draw_x+1
    staa draw_pointer+1
    ldaa draw_pointer
    adca draw_x
    staa draw_pointer
pixel_offset
    ldx #p_row
    stx draw_x_base
    ldaa draw_pointer+1
    adda draw_x_base+1
    staa draw_pointer+1
    ldaa draw_pointer
    adca draw_x_base
    staa draw_pointer
    ldx draw_pointer
    rts
    section
draw_x_base ds 2
    ends
pixel
    ldaa draw_y
    jsr ensure_row
    tsta
    beq *+5
    jmp pixel_return
    jsr pixel_address
    ldaa p_kind
    cmpa #4
    beq pixel_compare_rgb
    ldaa p_colour
    cmpa 0,x
    bne *+5
    jmp pixel_unchanged
    bra pixel_changed
pixel_compare_rgb
    ldx #p_colour_rgb
    ldaa 0,x
    ldab 1,x
    ldx draw_pointer
    cmpa 0,x
    bne pixel_changed
    cmpb 1,x
    bne pixel_changed
    ldx #p_colour_rgb
    ldaa 2,x
    ldx draw_pointer
    cmpa 2,x
    bne *+5
    jmp pixel_unchanged
pixel_changed
    tst p_stroke_saved
    bne pixel_write
    jsr canvas_snapshot
    tsta
    beq *+5
    jmp pixel_return
    inc p_stroke_saved
pixel_write
    ldaa p_kind
    cmpa #4
    beq pixel_write_rgb
    ldx draw_pointer
    ldaa p_colour
    staa 0,x
    bra pixel_dirty
pixel_write_rgb
    ldx #p_colour_rgb
    ldaa 0,x
    ldab 1,x
    ldx draw_pointer
    staa 0,x
    stab 1,x
    ldx #p_colour_rgb
    ldaa 2,x
    ldx draw_pointer
    staa 2,x
pixel_dirty
    tst p_row_dirty
    bne dirty_compare_left
    ldx draw_x
    stx ham_dirty_left
    stx ham_dirty_right
    bra dirty_bounds_ready
dirty_compare_left
    ldaa draw_x
    cmpa ham_dirty_left
    bcs dirty_left
    bhi dirty_compare_right
    ldaa draw_x+1
    cmpa ham_dirty_left+1
    bcc dirty_compare_right
dirty_left
    ldx draw_x
    stx ham_dirty_left
dirty_compare_right
    ldaa draw_x
    cmpa ham_dirty_right
    bcs dirty_bounds_ready
    bhi dirty_right
    ldaa draw_x+1
    cmpa ham_dirty_right+1
    bls dirty_bounds_ready
dirty_right
    ldx draw_x
    stx ham_dirty_right
dirty_bounds_ready
    ldaa #1
    staa p_row_dirty
pixel_unchanged
    clra
pixel_return
    rts
; Collect the union of square brushes as one span per image row. A thick
; horizontal stroke must not re-encode the same HAM row once per point.
brush
    ldaa p_brush
    bne brush_size
    inca
brush_size
    staa brush_rows
    lsra
    staa draw_temp
    ldaa line_x+1
    suba draw_temp
    staa brush_left+1
    ldaa line_x
    sbca #0
    staa brush_left
    bpl brush_left_valid
    clr brush_left
    clr brush_left+1
brush_left_valid
    ldx brush_left
    stx span_left
    ldaa p_brush
    suba draw_temp
    deca
    adda line_x+1
    staa span_right+1
    ldaa line_x
    adca #0
    staa span_right
    cmpa p_width
    bcs brush_right_valid
    bhi brush_right_clip
    ldx #p_width
    ldaa span_right+1
    cmpa 1,x
    bcs brush_right_valid
brush_right_clip
    ldx p_width
    dex
    stx span_right
brush_right_valid
    ldaa line_y
    suba draw_temp
    staa brush_top+1
    ldaa #0
    sbca #0
    staa brush_top
    ldx brush_top
    stx brush_y
brush_row
    ldaa brush_y
    bne brush_next_row
    ldaa brush_y+1
    cmpa #200
    bcc brush_next_row
    staa draw_y
    jsr span_address
    ldaa 0,x
    cmpa #$ff
    beq span_initialize
    cmpa span_left
    bcs span_left_kept
    bhi span_replace_left
    ldaa 1,x
    cmpa span_left+1
    bls span_left_kept
span_replace_left
    ldaa span_left
    staa 0,x
    ldaa span_left+1
    staa 1,x
span_left_kept
    ldaa 2,x
    cmpa span_right
    bhi brush_next_row
    bcs span_replace_right
    ldaa 3,x
    cmpa span_right+1
    bcc brush_next_row
span_replace_right
    ldaa span_right
    staa 2,x
    ldaa span_right+1
    staa 3,x
    bra brush_next_row
span_initialize
    ldaa span_left
    staa 0,x
    ldaa span_left+1
    staa 1,x
    ldaa span_right
    staa 2,x
    ldaa span_right+1
    staa 3,x
brush_next_row
    inc brush_y+1
    bne brush_y_done
    inc brush_y
brush_y_done
    dec brush_rows
    bne brush_row
    clra
brush_return
    rts
; A=row, X=span's BE16 left/right pair.
span_address
    clrb
    asla
    rolb
    asla
    rolb
    staa span_pointer+1
    stab span_pointer
    ldx #spans
    stx brush_x
    ldaa span_pointer+1
    adda brush_x+1
    staa span_pointer+1
    ldaa span_pointer
    adca brush_x
    staa span_pointer
    ldx span_pointer
    rts
render_spans
    clr span_y
span_render_row
    ldaa span_y
    jsr span_address
    ldaa 0,x
    cmpa #$ff
    beq span_render_next
    ldx 0,x
    stx span_x
span_render_pixel
    ldx span_x
    stx draw_x
    ldaa span_y
    staa draw_y
    jsr pixel
    tsta
    bne span_render_return
    ldaa span_x+1
    anda #7
    bne span_render_test
    jsr paint_idle
span_render_test
    ldx span_pointer
    ldx 2,x
    cpx span_x
    beq span_render_flush
    ldx span_x
    inx
    stx span_x
    bra span_render_pixel
span_render_flush
    jsr draw_flush
    tsta
    bne span_render_return
span_render_next
    inc span_y
    ldaa span_y
    cmpa #200
    bne span_render_row
    clra
span_render_return
    rts
; Integer Bresenham, all octants and 640-pixel spans on either CPU ISA.
line
    ldx #spans
    ldab #200
line_clear_spans
    ldaa #$ff
    staa 0,x
    staa 1,x
    clr 2,x
    clr 3,x
    inx
    inx
    inx
    inx
    decb
    bne line_clear_spans
    ldx p_x0
    stx line_x
    ldaa p_y0
    staa line_y
    ldx #p_x1
    ldaa 1,x
    ldx #p_x0
    suba 1,x
    staa line_dx+1
    ldaa p_x1
    sbca p_x0
    staa line_dx
    ldaa #1
    staa line_sx
    tst line_dx
    bpl line_y_delta
    neg line_sx
    com line_dx
    com line_dx+1
    inc line_dx+1
    bne line_x_abs
    inc line_dx
line_x_abs
line_y_delta
    clr line_dy
    ldaa p_y1
    suba p_y0
    ldab #1
    bcc line_y_abs
    nega
    negb
line_y_abs
    staa line_dy+1
    stab line_sy
    ldaa line_dx+1
    suba line_dy+1
    staa line_error+1
    ldaa line_dx
    sbca line_dy
    staa line_error
line_point
    jsr brush
    tsta
    beq *+5
    jmp line_return
    jsr paint_idle
    ldx line_x
    cpx p_x1
    bne line_continue
    ldaa line_y
    cmpa p_y1
    beq line_done
line_continue
    ldaa line_error+1
    asla
    staa line_twice+1
    ldaa line_error
    rola
    staa line_twice
    ; e2 >= -dy is equivalent to e2+dy >= 0.
    ldaa line_twice+1
    adda line_dy+1
    ldaa line_twice
    adca line_dy
    bmi line_step_y
    ldaa line_error+1
    suba line_dy+1
    staa line_error+1
    ldaa line_error
    sbca line_dy
    staa line_error
    ldaa line_sx
    bmi line_x_back
    inc line_x+1
    bne line_step_y
    inc line_x
    bra line_step_y
line_x_back
    tst line_x+1
    bne line_x_low
    dec line_x
line_x_low
    dec line_x+1
line_step_y
    ; e2 <= dx is equivalent to dx-e2 >= 0.
    ldaa line_dx+1
    suba line_twice+1
    ldaa line_dx
    sbca line_twice
    bmi line_point
    ldaa line_error+1
    adda line_dx+1
    staa line_error+1
    ldaa line_error
    adca line_dx
    staa line_error
    ldaa line_y
    adda line_sy
    staa line_y
    jmp line_point
line_done
    jmp render_spans
line_return
    rts
; Rectangle bounds sorted by unsigned bytes, avoiding MC6800 CPX carry.
rectangle
    ldx p_x0
    stx shape_left
    ldx p_x1
    stx shape_right
    ldaa p_x0
    cmpa p_x1
    bcs shape_x_sorted
    bhi shape_x_swap
    ldx #p_x0
    ldaa 1,x
    ldx #p_x1
    cmpa 1,x
    bls shape_x_sorted
shape_x_swap
    ldx p_x0
    stx shape_right
    ldx p_x1
    stx shape_left
shape_x_sorted
    ldaa p_y0
    ldab p_y1
    cba
    bls shape_y_sorted
    psha
    tba
    pulb
shape_y_sorted
    staa shape_top
    stab shape_bottom
    staa shape_y
    ldaa p_tool
    cmpa #P_TOOL_FILLED
    bne shape_row
    ldaa p_kind
    cmpa #4
    beq shape_row
    tst p_preview_ext
    beq shape_row
    jsr draw_flush
    tsta
    beq *+5
    jmp shape_return
    jsr canvas_snapshot
    tsta
    beq *+5
    jmp shape_return
    ldx #fill_rectangle
    ldaa shape_left
    ldab shape_left+1
    staa 0,x
    stab 1,x
    ldaa shape_top
    staa 2,x
    ldaa shape_right+1
    suba shape_left+1
    tab
    ldaa shape_right
    sbca shape_left
    incb
    bne fill_width_ready
    inca
fill_width_ready
    staa 3,x
    stab 4,x
    ldaa shape_bottom
    suba shape_top
    inca
    staa 5,x
    ldaa p_colour
    staa 6,x
    jsr canvas_fill
    tsta
    beq *+5
    jmp shape_return
    ldaa #$ff
    staa p_cached_y
    clr p_row_dirty
    clra
    rts
shape_row
    ldx shape_left
    stx shape_x
shape_column
    ldaa p_tool
    cmpa #P_TOOL_FILLED
    beq shape_pixel
    ldaa shape_y
    cmpa shape_top
    beq shape_pixel
    cmpa shape_bottom
    beq shape_pixel
    ldx shape_x
    cpx shape_left
    beq shape_pixel
    cpx shape_right
    bne shape_advance
shape_pixel
    ldx shape_x
    stx draw_x
    ldaa shape_y
    staa draw_y
    jsr pixel
    tsta
    beq *+5
    jmp shape_return
shape_advance
    ldaa shape_x+1
    anda #7
    bne shape_advance_test
    jsr paint_idle
shape_advance_test
    ldx shape_x
    cpx shape_right
    beq shape_next_row
    ldaa p_tool
    cmpa #P_TOOL_RECT
    bne shape_step_x
    ldaa shape_y
    cmpa shape_top
    beq shape_step_x
    cmpa shape_bottom
    beq shape_step_x
    ldx shape_right
    stx shape_x
    jmp shape_column
shape_step_x
    ldx shape_x
    inx
    stx shape_x
    bra shape_column
shape_next_row
    jsr draw_flush
    tsta
    beq *+5
    jmp shape_return
    jsr paint_idle
    ldaa shape_y
    cmpa shape_bottom
    beq shape_done
    inc shape_y
    jmp shape_row
shape_done
    clra
shape_return
    rts
draw_pick
    ldaa p_y1
    jsr ensure_row
    tsta
    bne pick_return
    ldx p_x1
    stx draw_x
    jsr pixel_address
    ldaa p_kind
    cmpa #4
    beq pick_rgb
    ldaa 0,x
    staa p_fg
    clra
    rts
pick_rgb
    ldaa 0,x
    ldab 1,x
    ldx #p_fg_rgb
    staa 0,x
    stab 1,x
    ldx draw_pointer
    ldaa 2,x
    ldx #p_fg_rgb
    staa 2,x
    clra
pick_return
    rts
choose_colour
    ldaa p_fg
    ldx #p_fg_rgb
    ldab draw_button
    bitb #1
    bne colour_ready
    ldaa p_bg
    ldx #p_bg_rgb
colour_ready
    staa p_colour
    stx draw_pointer
    ldaa 0,x
    ldab 1,x
    ldx #p_colour_rgb
    staa 0,x
    stab 1,x
    ldx draw_pointer
    ldaa 2,x
    ldx #p_colour_rgb
    staa 2,x
    rts
; Events have common hardware coordinates (640 horizontal, 200 vertical).
draw_event
    clr draw_error
    ldx p_event_x
    stx line_x
    ldaa p_kind
    cmpa #1
    beq event_x_ready
    lsr line_x
    ror line_x+1
event_x_ready
    ldx line_x
    stx p_x1
    ldaa p_event_y
    cmpa #200
    bcs event_y_ready
    ldaa #199
event_y_ready
    staa p_y1
    ldaa p_event_buttons
    anda #3
    staa draw_button
    ldaa p_event_buttons
    bita #4
    beq event_draw
    jsr draw_pick
    jmp event_return
event_draw
    ldaa draw_button
    beq event_release
    tst p_stroke
    bne event_continue
    ldaa p_tool
    cmpa #P_TOOL_PICK
    beq event_pick
    clr p_stroke_saved
    jsr choose_colour
    ldaa draw_button
    staa p_stroke
    ldx p_x1
    stx p_x0
    ldaa p_y1
    staa p_y0
event_continue
    ldaa p_tool
    cmpa #P_TOOL_BRUSH
    bne event_ok
    jsr line
    tsta
    bne event_return
    ldx p_x1
    stx p_x0
    ldaa p_y1
    staa p_y0
    jsr draw_flush
    bra event_return
event_pick
    jsr draw_pick
    bra event_return
event_release
    tst p_stroke
    beq event_ok
    clr p_stroke
    ldaa p_tool
    cmpa #P_TOOL_BRUSH
    beq event_ok
    cmpa #P_TOOL_LINE
    bne event_shape
    jsr line
    bra event_flush
event_shape
    jsr rectangle
event_flush
    tsta
    bne event_return
    jsr draw_flush
    bra event_return
event_ok
    clra
event_return
    staa draw_error
    ldaa p_event_buttons
    staa p_prev_buttons
    ldaa draw_error
    rts
    end
