    .ifdef PNT_TOOLS
    .define PNT_FILES
    .endif
; Magnified viewport and selection state. Canonical/Undo previews stay intact.
    include PNTDEF.INC
    include PNTABI.INC
    include DMA.INC
    public view_reset
    public view_touch
    public view_action
    public view_refresh
    public view_event
    public view_key
    public p_view_shift
    public p_view_x
    public p_view_y
    public view_front
    public view_grid
    public p_sel_active
    public p_sel_left
    public p_sel_right
    public p_sel_top
    public p_sel_bottom
    public p_clip_valid
    extern p_kind
    extern p_width
    extern p_stride
    extern p_row
    extern p_encoded
    extern p_params
    extern p_cached_y
    extern p_event_x
    extern p_event_y
    extern p_event_buttons
    extern p_tool
    extern p_readonly
    extern p_brush
    extern p_stroke
    extern p_x0
    extern p_y0
    extern p_y1
    extern p_doc_page
    extern p_bg
    extern p_bg_rgb
    extern mouse_x
    extern mouse_y_low
    extern canvas_read
    extern canvas_store
    extern canvas_show
    extern canvas_front
    extern canvas_snapshot
    extern row_document
    extern row_address
    extern backend_encode
    extern draw_finish
    extern draw_flush
    extern paint_idle
    extern dma_reset
    extern dma_run
    extern paint_dma
    section
p_view_shift ds 1
p_view_x ds 2
p_view_y ds 1
view_dirty ds 1
view_full ds 1
view_top ds 1
view_bottom ds 1
view_grid ds 1
view_front ds 1
p_sel_active ds 1
sel_drag ds 1
sel_x0 ds 2
sel_y0 ds 1
p_sel_left ds 2
p_sel_right ds 2
p_sel_top ds 1
p_sel_bottom ds 1
p_clip_valid ds 1
clip_kind ds 1
clip_width ds 2
clip_height ds 1
v_x ds 2
v_y ds 1
v_width ds 2
v_max_x ds 2
v_height ds 1
v_hshift ds 1
v_hrep ds 1
v_vrep ds 1
v_rows ds 1
v_screen_y ds 1
v_doc_y ds 1
v_doc_x ds 2
v_offset ds 2
v_source ds 2
v_target ds 2
v_count ds 2
v_pixels ds 2
v_repeat ds 1
v_rgb ds 3
v_border ds 1
v_grid ds 1
v_key ds 1
v_temp ds 2
v_pointer ds 2
v_op ds 1
v_full ds 1
v_old_front ds 1
v_limit ds 1
    ends
view_reset
    clr p_view_shift
    clr p_view_x
    clr p_view_x+1
    clr p_view_y
    clr p_sel_active
    clr sel_drag
    clr p_clip_valid
    ldaa #1
    staa view_grid
view_touch
    ldaa #1
    staa view_dirty
    staa view_full
    clra
    rts
view_action
    tst view_dirty
    beq view_touch
    clra
    rts
    .ifndef PNT_FILES
; Mouse coordinates -> logical image point, bounded to the current viewport.
view_map
    ldx p_event_x
    stx v_x
    ldaa p_event_y
    staa v_y
    ldaa p_view_shift
    beq map_normal
    lsr v_x
    ror v_x+1
    staa v_repeat
    ldaa p_kind
    cmpa #1
    bne map_divide
    dec v_repeat
map_divide
    tst v_repeat
    beq map_y
    lsr v_x
    ror v_x+1
    dec v_repeat
    bra map_divide
map_y
    ldaa p_view_shift
    staa v_repeat
map_y_bit
    lsr v_y
    dec v_repeat
    bne map_y_bit
    ldaa v_x+1
    adda p_view_x+1
    staa v_x+1
    ldaa v_x
    adca p_view_x
    staa v_x
    ldaa v_y
    adda p_view_y
    staa v_y
    rts
map_normal
    ldaa p_kind
    cmpa #1
    beq map_done
    lsr v_x
    ror v_x+1
map_done
    rts
map_mouse
    ldx mouse_x
    stx p_event_x
    ldaa mouse_y_low
    staa p_event_y
    jmp view_map
; Visible logical extent, replication and legal upper-left corner.
view_sizes
    ldaa p_view_shift
    staa v_hshift
    ldaa p_kind
    cmpa #1
    bne size_shift
    tst v_hshift
    beq size_shift
    dec v_hshift
size_shift
    ldx #320
    stx v_width
    ldaa #1
    staa v_hrep
    ldab v_hshift
size_x
    tstb
    beq size_y
    lsr v_width
    ror v_width+1
    asl v_hrep
    decb
    bra size_x
size_y
    ldaa #200
    staa v_height
    ldaa #1
    staa v_vrep
    ldab p_view_shift
size_y_bit
    tstb
    beq size_limit
    lsr v_height
    asl v_vrep
    decb
    bra size_y_bit
size_limit
    ldx #p_width
    ldaa 1,x
    suba v_width+1
    staa v_max_x+1
    ldaa p_width
    sbca v_width
    staa v_max_x
    rts
view_bounds
    tst p_view_x
    bpl bound_right
    clr p_view_x
    clr p_view_x+1
bound_right
    ldaa p_view_x
    cmpa v_max_x
    bcs bound_y
    bhi bound_max
    ldaa p_view_x+1
    cmpa v_max_x+1
    bls bound_y
bound_max
    ldx v_max_x
    stx p_view_x
bound_y
bound_bottom
    ldaa #200
    suba v_height
    cmpa p_view_y
    bcc bound_done
    staa p_view_y
bound_done
    jmp view_touch
view_zoom
    jsr draw_finish
    jsr map_mouse
    inc p_view_shift
    ldaa p_view_shift
    anda #3
    staa p_view_shift
    bne zoom_center
    clr p_view_x
    clr p_view_x+1
    clr p_view_y
    ldaa p_kind
    cmpa #1
    bne zoom_done
    clr p_sel_active
zoom_done
    jmp view_touch
zoom_center
    jsr view_sizes
    ldx v_width
    stx v_temp
    lsr v_temp
    ror v_temp+1
    ldaa v_x+1
    suba v_temp+1
    staa p_view_x+1
    ldaa v_x
    sbca v_temp
    staa p_view_x
    ldaa v_height
    lsra
    staa v_repeat
    ldaa v_y
    suba v_repeat
    bcc zoom_y_ready
    clra
zoom_y_ready
    staa p_view_y
    jmp view_bounds
; Return A=1 for a selection event; otherwise adapt coordinates for DRAW.
view_event
    jsr view_map
    ldaa p_tool
    cmpa #P_TOOL_SELECT
    beq *+5
    jmp event_normal
    ldaa p_event_buttons
    bita #4
    beq *+5
    jmp event_normal
    bita #2
    beq *+5
    jmp selection_clear
    bita #1
    bne selection_down
    tst sel_drag
    beq selection_handled
    clr sel_drag
    bra selection_extend
selection_down
    tst sel_drag
    bne selection_extend
    inc sel_drag
    ldx v_x
    stx sel_x0
    ldaa v_y
    staa sel_y0
    ldaa #1
    staa p_sel_active
    jsr view_wide
selection_extend
    ldx sel_x0
    stx p_sel_left
    ldx v_x
    stx p_sel_right
    ldaa sel_x0
    cmpa v_x
    bcs selection_y
    bhi selection_swap
    ldaa sel_x0+1
    cmpa v_x+1
    bls selection_y
selection_swap
    ldx sel_x0
    stx p_sel_right
    ldx v_x
    stx p_sel_left
selection_y
    ldaa sel_y0
    ldab v_y
    cba
    bls selection_y_sorted
    psha
    tba
    pulb
selection_y_sorted
    staa p_sel_top
    stab p_sel_bottom
    jsr view_touch
selection_handled
    ldaa #1
    rts
selection_clear
    clr sel_drag
    clr p_sel_active
    jsr view_touch
    bra selection_handled
event_normal
    ldaa p_tool
    beq event_active
    ldaa p_event_buttons
    anda #3
    bne event_coordinates
event_active
    ldaa p_event_buttons
    anda #3
    oraa p_stroke
    beq event_coordinates
    ldaa p_brush
    lsra
    inca
    staa v_repeat
    ldaa v_y
    ldab p_y0
    tst p_stroke
    bne event_has_anchor
    ldab v_y
event_has_anchor
    cba
    bls event_range
    psha
    tba
    pulb
event_range
    suba v_repeat
    bcc event_top
    clra
event_top
    staa v_border
    addb v_repeat
    bcc event_bottom
    ldab #199
event_bottom
    cmpb #200
    bcs event_dirty
    ldab #199
event_dirty
    tst view_dirty
    beq event_new_dirty
    cmpa view_top
    bcc event_keep_top
    staa view_top
event_keep_top
    cmpb view_bottom
    bls event_coordinates
    stab view_bottom
    bra event_coordinates
event_new_dirty
    staa view_top
    stab view_bottom
    ldaa #1
    staa view_dirty
event_coordinates
    ldx v_x
    stx p_event_x
    ldaa p_kind
    cmpa #1
    beq event_y
    ldx #p_event_x
    asl 1,x
    rol 0,x
event_y
    ldaa v_y
    staa p_event_y
    clra
    rts
view_key
    staa v_key
    cmpa #3
    beq key_copy
    cmpa #22
    beq key_paste
    cmpa #24
    beq key_cut
    cmpa #4
    beq key_clear
    cmpa #1
    beq key_all
    anda #$df
    cmpa #'Z'
    bne key_grid
    jsr view_zoom
    bra key_handled
key_grid
    cmpa #'G'
    bne key_select
    ldaa view_grid
    eora #1
    staa view_grid
    jsr view_touch
    bra key_handled
key_select
    cmpa #'S'
    bne key_brush
    ldaa #P_TOOL_SELECT
    staa p_tool
    bra key_success
key_brush
    cmpa #'B'
    bne key_pan
    clr p_tool
    bra key_success
key_copy
    jsr clip_copy
    bra key_handled
key_cut
    tst p_readonly
    bne key_success
    jsr clip_cut
    bra key_handled
key_paste
    tst p_readonly
    bne key_success
    jsr clip_paste
    bra key_handled
key_clear
    clr p_sel_active
    clr sel_drag
    jsr view_touch
    bra key_handled
key_all
    clr p_sel_left
    clr p_sel_left+1
    clr p_sel_top
    ldx p_width
    dex
    stx p_sel_right
    ldaa #199
    staa p_sel_bottom
    ldaa #1
    staa p_sel_active
    jsr view_wide
key_all_ready
    jsr view_touch
key_handled
    sec
    rts
key_success
    clra
    bra key_handled
key_pan
    cmpa #'I'
    beq pan_up
    cmpa #'J'
    beq pan_left
    cmpa #'K'
    beq pan_down
    cmpa #'L'
    beq pan_right
    ldaa v_key
    clc
    rts
pan_up
    tst p_view_y
    beq pan_ready
    dec p_view_y
    bra pan_ready
pan_down
    inc p_view_y
    bra pan_ready
pan_left
    ldx p_view_x
    dex
    stx p_view_x
    bra pan_ready
pan_right
    ldx p_view_x
    inx
    stx p_view_x
pan_ready
    jsr view_sizes
    jsr view_bounds
    bra key_handled
; Render a separate 320x200 preview, alternating GPU pages 5 and 12.
view_refresh
    tst view_dirty
    bne refresh_begin
    clra
    rts
refresh_begin
    clr view_dirty
    ldaa view_full
    staa v_full
    clr view_full
    ldaa p_view_shift
    oraa p_sel_active
    bne refresh_active
    jmp canvas_front
refresh_active
    jsr draw_flush
    tsta
    beq *+5
    jmp view_return
    jsr view_sizes
    ldaa p_view_y
    adda v_height
    deca
    staa v_limit
    ldaa view_front
    staa v_old_front
    cmpa #5
    beq refresh_bounds
    cmpa #12
    beq refresh_bounds
    inc v_full
refresh_bounds
    ldaa p_view_y
    staa v_doc_y
    tst v_full
    bne refresh_destination
    ldaa view_bottom
    cmpa p_view_y
    bcs refresh_empty
    ldaa view_top
    cmpa v_limit
    bhi refresh_empty
    cmpa p_view_y
    bcs refresh_bottom
    staa v_doc_y
refresh_bottom
    ldaa view_bottom
    cmpa v_limit
    bcc refresh_destination
    staa v_limit
refresh_destination
    ldaa #5
    cmpa view_front
    bne refresh_page
    ldaa #12
refresh_page
    staa view_front
    clr v_offset
    clr v_offset+1
    ldaa v_doc_y
    suba p_view_y
    ldab p_view_shift
refresh_y_scale
    tstb
    beq refresh_y_start
    asla
    decb
    bra refresh_y_scale
refresh_y_start
    staa v_screen_y
    staa v_repeat
refresh_seek
    tst v_repeat
    beq refresh_underlay
    ldaa v_offset+1
    adda #64
    staa v_offset+1
    ldaa v_offset
    adca #1
    staa v_offset
    dec v_repeat
    bra refresh_seek
refresh_empty
    clra
    rts
refresh_underlay
    tst v_full
    bne refresh_grid
    jsr dma_reset
    ldx #paint_dma
    ldaa v_old_front
    adda #$10
    staa DMA_SRC+2,x
    ldaa view_front
    adda #$10
    staa DMA_DST+2,x
    ldaa #$fa
    staa DMA_WIDTH+1,x
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    beq *+5
    jmp view_return
refresh_grid
    clr v_grid
    ldaa v_hrep
    cmpa #4
    bcs refresh_row
    ldaa view_grid
    staa v_grid
refresh_row
    ldaa v_doc_y
    jsr canvas_read
    tsta
    beq *+5
    jmp view_return
    ldx #p_row
    stx v_source
    tst p_view_shift
    beq refresh_expand
    ldx p_view_x
    stx v_temp
    ldx v_width
    stx v_count
    ldaa p_kind
    cmpa #4
    bne refresh_crop
    asl v_temp+1
    rol v_temp
    ldaa v_temp+1
    adda p_view_x+1
    staa v_temp+1
    ldaa v_temp
    adca p_view_x
    staa v_temp
    asl v_count+1
    rol v_count
    ldaa v_count+1
    adda v_width+1
    staa v_count+1
    ldaa v_count
    adca v_width
    staa v_count
refresh_crop
    ldaa v_source+1
    adda v_temp+1
    staa v_source+1
    ldaa v_source
    adca v_temp
    staa v_source
    ldx #p_encoded
    stx v_target
crop_byte
    ldx v_source
    ldaa 0,x
    inx
    stx v_source
    ldx v_target
    staa 0,x
    inx
    stx v_target
    ldx v_count
    dex
    stx v_count
    bne crop_byte
    ldx #p_encoded
    stx v_source
refresh_expand
    ldx #p_row
    stx v_target
    ldx v_width
    stx v_pixels
    ldx p_view_x
    stx v_doc_x
expand_pixel
    ldx v_source
    ldaa 0,x
    staa v_rgb
    inx
    ldaa p_kind
    cmpa #4
    bne expand_loaded
    ldaa 0,x
    staa v_rgb+1
    inx
    ldaa 0,x
    staa v_rgb+2
    inx
expand_loaded
    stx v_source
    jsr border_pixel
    ldaa v_hrep
    staa v_repeat
expand_repeat
    ldx v_target
    tst v_grid
    beq expand_colour
    ldaa v_repeat
    cmpa #1
    bne expand_colour
    clr 0,x
    inx
    ldaa p_kind
    cmpa #4
    bne expand_next
    clr 0,x
    clr 1,x
    inx
    inx
    bra expand_next
expand_colour
    ldaa v_rgb
    staa 0,x
    inx
    ldaa p_kind
    cmpa #4
    bne expand_next
    ldaa v_rgb+1
    staa 0,x
    ldaa v_rgb+2
    staa 1,x
    inx
    inx
expand_next
    stx v_target
    dec v_repeat
    bne expand_repeat
    ldx v_doc_x
    inx
    stx v_doc_x
    ldx v_pixels
    dex
    stx v_pixels
    bne expand_pixel
    ldaa v_vrep
    staa v_rows
    tst v_grid
    beq refresh_encode
    dec v_rows
refresh_encode
    ldx #p_row
    stx v_source
    ldaa p_kind
    cmpa #4
    bne refresh_upload
    jsr backend_encode
    tsta
    beq *+5
    jmp view_return
    ldx #p_encoded
    stx v_source
refresh_upload
    jsr view_descriptor
    ldx #paint_dma
    ldaa v_source+1
    staa DMA_SRC,x
    ldaa v_source
    staa DMA_SRC+1,x
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    beq *+5
    jmp view_return
    ldaa v_offset+1
    adda #64
    staa v_offset+1
    ldaa v_offset
    adca #1
    staa v_offset
    dec v_rows
    bne refresh_upload
    tst v_grid
    beq refresh_next
    ; Grid bottom row is a black base command, safe even in HAM8.
    jsr view_descriptor
    ldx #paint_dma
    ldaa #DMA_FILL
    jsr dma_run
    tsta
    beq *+5
    jmp view_return
    ldaa v_offset+1
    adda #64
    staa v_offset+1
    ldaa v_offset
    adca #1
    staa v_offset
refresh_next
    ldaa v_doc_y
    cmpa v_limit
    beq refresh_flip
    inc v_doc_y
    ldaa v_screen_y
    adda v_vrep
    staa v_screen_y
    jsr paint_idle
    jmp refresh_row
refresh_flip
    ldaa #$ff
    staa p_cached_y
    ldaa view_front
    staa $e655
    ldaa #3
    staa $e651
    ldx #$ffff
    stx v_count
view_vblank
    ldaa $e650
    bpl view_enabled
    jsr paint_idle
    ldx v_count
    dex
    stx v_count
    bne view_vblank
    ldaa #3
    rts
view_enabled
    ldaa #1
    ldab p_kind
    cmpb #4
    bne view_enable
    ldaa #7
view_enable
    staa $e650
    clra
view_return
    rts
view_descriptor
    jsr dma_reset
    ldx #paint_dma
    ldaa v_offset+1
    staa DMA_DST,x
    ldaa v_offset
    staa DMA_DST+1,x
    ldaa view_front
    adda #$10
    staa DMA_DST+2,x
    ldaa #64
    staa DMA_WIDTH,x
    ldaa #1
    staa DMA_WIDTH+1,x
    rts
border_pixel
    tst p_sel_active
    beq border_done
    ldaa v_doc_y
    cmpa p_sel_top
    bcs border_done
    cmpa p_sel_bottom
    bhi border_done
    ldaa v_doc_x
    cmpa p_sel_left
    bcs border_done
    bne border_right
    ldaa v_doc_x+1
    cmpa p_sel_left+1
    bcs border_done
border_right
    ldaa v_doc_x
    cmpa p_sel_right
    bhi border_done
    bne border_test
    ldaa v_doc_x+1
    cmpa p_sel_right+1
    bhi border_done
border_test
    ldaa v_doc_y
    cmpa p_sel_top
    beq border_draw
    cmpa p_sel_bottom
    beq border_draw
    ldx v_doc_x
    cpx p_sel_left
    beq border_draw
    cpx p_sel_right
    bne border_done
border_draw
    ldaa #$ff
    ldab p_kind
    cmpb #3
    bcc border_mask
    ldaa #3
    cmpb #2
    beq border_mask
    ldaa #1
border_mask
    eora v_rgb
    staa v_rgb
    cmpb #4
    bne border_done
    ldaa v_rgb
    anda #63
    staa v_rgb
    ldaa v_rgb+1
    eora #63
    staa v_rgb+1
    ldaa v_rgb+2
    eora #63
    staa v_rgb+2
border_done
    rts
; Packed canonical rows retain the document stride in the 192K clipboard.
clip_copy
    tst p_sel_active
    beq clip_ok
    jsr draw_finish
    tsta
    bne clip_return
    ldx p_sel_left
    stx v_x
    ldaa p_sel_top
    staa v_y
    ldaa p_sel_right+1
    suba p_sel_left+1
    staa clip_width+1
    ldaa p_sel_right
    sbca p_sel_left
    staa clip_width
    ldx clip_width
    inx
    stx clip_width
    stx v_width
    ldaa p_sel_bottom
    suba p_sel_top
    inca
    staa clip_height
    staa v_rows
    jsr clip_descriptor
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    bne clip_return
    ldaa p_kind
    staa clip_kind
    ldaa #1
    staa p_clip_valid
clip_ok
    clra
clip_return
    rts
clip_cut
    tst p_sel_active
    beq clip_ok
    jsr clip_copy
    tsta
    bne clip_return
    jsr canvas_snapshot
    tsta
    bne clip_return
    ldaa #1
    staa v_op
    jmp clip_rebuild
clip_paste
    tst p_clip_valid
    beq clip_ok
    ldaa clip_kind
    cmpa p_kind
    beq clip_compatible
    ldaa #65
    rts
clip_compatible
    jsr draw_finish
    tsta
    bne clip_return
    jsr map_mouse
    ldx #p_width
    ldaa 1,x
    suba v_x+1
    staa v_width+1
    ldaa p_width
    sbca v_x
    staa v_width
    cmpa clip_width
    bcs paste_height
    bhi paste_width
    ldaa v_width+1
    cmpa clip_width+1
    bls paste_height
paste_width
    ldx clip_width
    stx v_width
paste_height
    ldaa #200
    suba v_y
    cmpa clip_height
    bls paste_rows
    ldaa clip_height
paste_rows
    staa v_rows
    jsr canvas_snapshot
    tsta
    bne clip_return
    jsr clip_descriptor
    ldx #paint_dma
    ldab #3
paste_swap
    ldaa 0,x
    psha
    ldaa 3,x
    staa 0,x
    pula
    staa 3,x
    inx
    decb
    bne paste_swap
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    beq *+5
    jmp clip_return
    ldx v_x
    stx p_sel_left
    ldaa v_x+1
    adda v_width+1
    staa p_sel_right+1
    ldaa v_x
    adca v_width
    staa p_sel_right
    ldx p_sel_right
    dex
    stx p_sel_right
    ldaa v_y
    staa p_sel_top
    adda v_rows
    deca
    staa p_sel_bottom
    ldaa #1
    staa p_sel_active
    clr v_op
clip_rebuild
    ldaa v_y
    staa v_doc_y
    adda v_rows
    deca
    staa v_limit
rebuild_row
    ldaa v_doc_y
    jsr canvas_read
    tsta
    beq *+5
    jmp clip_return
    tst v_op
    beq rebuild_preview
    ldx v_x
    jsr clip_byte_x
    ldx #p_row
    stx v_source
    ldaa v_source+1
    adda v_temp+1
    staa v_source+1
    ldaa v_source
    adca v_temp
    staa v_source
    ldx v_width
    stx v_pixels
cut_pixel
    ldx v_source
    ldaa p_bg
    staa 0,x
    inx
    ldaa p_kind
    cmpa #4
    bne cut_next
    dex
    ldaa p_bg_rgb
    staa 0,x
    ldx #p_bg_rgb
    ldaa 1,x
    ldab 2,x
    ldx v_source
    staa 1,x
    stab 2,x
    inx
    inx
    inx
cut_next
    stx v_source
    ldx v_pixels
    dex
    stx v_pixels
    bne cut_pixel
    ldaa v_doc_y
    jsr canvas_store
    tsta
    beq *+5
    jmp clip_return
rebuild_preview
    ldaa v_doc_y
    jsr canvas_show
    tsta
    beq *+5
    jmp clip_return
    ldaa v_doc_y
    cmpa v_limit
    beq rebuild_done
    inc v_doc_y
    jsr paint_idle
    jmp rebuild_row
rebuild_done
    ldaa #$ff
    staa p_cached_y
    jsr view_wide
    jmp view_touch
; Native 640-wide selection uses a 320-wide zoom viewport. Preserve the
; image point under the mouse while changing the horizontal sampling.
view_wide
    ldaa p_kind
    cmpa #1
    bne wide_done
    tst p_view_shift
    bne wide_done
    inc p_view_shift
    ldx mouse_x
    stx v_temp
    lsr v_temp
    ror v_temp+1
    ldx #mouse_x
    ldaa 1,x
    suba v_temp+1
    staa p_view_x+1
    ldaa 0,x
    sbca v_temp
    staa p_view_x
    ldaa mouse_y_low
    lsra
    staa v_repeat
    ldaa mouse_y_low
    suba v_repeat
    staa p_view_y
    jsr view_sizes
    jmp view_bounds
wide_done
    rts
; X=logical horizontal coordinate -> v_temp byte offset.
clip_byte_x
    stx v_temp
    ldaa p_kind
    cmpa #4
    bne byte_x_done
    asl v_temp+1
    rol v_temp
    stx v_pointer
    ldaa v_temp+1
    adda v_pointer+1
    staa v_temp+1
    ldaa v_temp
    adca v_pointer
    staa v_temp
byte_x_done
    rts
clip_descriptor
    jsr dma_reset
    ldaa v_y
    jsr row_document
    ldx v_x
    jsr clip_byte_x
    ldx #row_address
    ldaa 0,x
    adda v_temp+1
    staa v_source+1
    ldaa 1,x
    adca v_temp
    staa v_source
    ldaa 2,x
    adca #0
    staa v_border
    ldx v_width
    jsr clip_byte_x
    ldx #paint_dma
    ldaa v_source+1
    staa DMA_SRC,x
    ldaa v_source
    staa DMA_SRC+1,x
    ldaa v_border
    staa DMA_SRC+2,x
    ldaa #P_LOAD_PAGE
    staa DMA_DST+2,x
    ldaa v_temp+1
    staa DMA_WIDTH,x
    ldaa v_temp
    staa DMA_WIDTH+1,x
    ldaa v_rows
    staa DMA_HEIGHT,x
    ldx #p_stride
    ldaa 1,x
    ldab 0,x
    ldx #paint_dma
    staa DMA_SRC_STRIDE,x
    staa DMA_DST_STRIDE,x
    stab DMA_SRC_STRIDE+1,x
    stab DMA_DST_STRIDE+1,x
    clra
    rts
    .else
view_event
view_refresh
view_key
    clra
    rts
    .endif
    end
