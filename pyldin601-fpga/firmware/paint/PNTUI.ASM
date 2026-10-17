; Modal native windows share NC's ROM font, line editor and mouse focus.
; The image survives in GPU SRAM, or in a DMA snapshot of its native frame.
    .ifdef PNT_TOOLS
    .define PNT_COLOUR
    .define PNT_FILES
    .endif
    .ifndef PNT_EDIT
    .ifndef PNT_FILES
    .define PNT_COLOUR
    .endif
    .endif
    .ifdef PNT_EDIT
    .define PNT_OVL
    .endif
    .ifdef PNT_FILES
    .define PNT_OVL
    .endif
    include PNTDEF.INC
    include DMA.INC
    public ui_enter
    public ui_leave
    public ui_new
    public ui_tool
    public ui_colour
    public ui_rgb
    public ui_swatch
    public ui_menu
    public ui_help
    public ui_error
    public ui_confirm
    public ui_progress
    public ui_choice
    extern draw_finish
    extern frame_save
    extern frame_load
    extern canvas_front
    extern paint_pointer
    extern paint_dma
    extern dma_reset
    extern dma_run
    extern mouse_wait
    extern mouse_pressed
    extern mouse_x
    extern mouse_x_low
    extern mouse_y_low
    extern p_kind
    extern p_tool
    extern p_fg
    extern p_fg_rgb
    extern p_cached_y
    extern p_row_dirty
    extern palette_index
    extern palette_ham
    extern p_frame
    extern p_native_mode
    extern p_native_pal
    extern p_preview_ext
    extern p_front_page
    extern p_ui_active
    extern p_ui_underlay
    extern p_ui_menu
    extern p_ui_result
    extern p_ignore
    extern p_queue_count
    extern p_queue_head
    extern p_error
    extern p_format_list
    extern p_tool_list
    extern p_format_title
    extern p_tool_title
    extern p_colour_title
    extern p_new_question
    extern p_modified
    extern p_readonly
    extern p_view_help
    extern p_view_title
    extern title
    extern mode
    extern screen_base
    extern ui_command
    extern command_caret
    extern window_open
    extern window_line
    extern window_wrap
    extern colour
    extern dialog
    extern input
    extern help
    extern error
    extern message
    extern p_bad_format
    extern p_no_memory
    extern confirm
    extern caret_hide
    extern add_b
    .ifdef PNT_OVL
    extern view_touch
    .endif
    section
choice_list ds 2
choice_title ds 2
choice_index ds 1
choice_row ds 1
choice_result ds 1
choice_hex ds 3
choice_count ds 1
choice_pointer ds 2
grid_index ds 1
grid_row ds 1
grid_column ds 1
grid_offset ds 2
grid_x ds 2
grid_y ds 1
ui_saved_a ds 1
rgb_target ds 2
grid_mode ds 1
grid_limit ds 1
    ends
ui_enter
    tst p_ui_active
    beq ui_enter_begin
    clra
    rts
ui_enter_begin
    jsr draw_finish
    tsta
    bne ui_enter_return
    inc p_ui_active
    clr p_queue_count
    clr p_queue_head
    ldaa #1
    staa p_ignore
    .ifdef PNT_OVL
    jsr view_touch
    .endif
    clr p_ui_underlay
    tst p_preview_ext
    bne ui_native_screen
    ldaa #P_DIALOG_PAGE
    jsr frame_save
    tsta
    bne ui_enter_failed
    inc p_ui_underlay
ui_native_screen
    clr $e650
    ldaa #3
    staa mode
    ldab #2
    ldx p_frame
    stx screen_base
    int $12
    ldaa #23
    staa ui_command
    clr command_caret
    jsr caret_hide
    clra
ui_enter_return
    rts
ui_enter_failed
    clr p_ui_active
    rts
ui_leave
    tst p_ui_active
    beq ui_leave_ok
    clr p_ui_menu
    ldaa p_native_mode
    oraa #$80
    ldab p_native_pal
    ldx p_frame
    int $12
    tst p_ui_underlay
    beq ui_leave_front
    ldaa #P_DIALOG_PAGE
    jsr frame_load
    tsta
    bne ui_leave_return
ui_leave_front
    jsr canvas_front
    tsta
    bne ui_leave_return
    clr p_ui_active
    clr p_ui_underlay
    clr p_queue_count
    clr p_queue_head
    ldaa #1
    staa p_ignore
ui_leave_ok
    clra
ui_leave_return
    rts
; X=caption, choice_list points to five strings; selected index 0..4.
    .ifndef PNT_FILES
ui_choice
    stx choice_title
    ldaa #5
    staa choice_count
    ldx choice_list
    cpx #p_tool_list
    bne choice_not_tool
    ldaa #10
choice_not_tool
    cpx #menu_list
    bne choice_limit
    .ifdef PNT_OVL
    ldaa #10
    .endif
choice_limit
    staa choice_count
    staa p_ui_menu
choice_draw
    ldx choice_title
    jsr window_open
    clr choice_row
choice_line
    ldaa #$07
    ldab choice_row
    cmpb choice_index
    bne choice_ink
    ; Native monochrome needs the opposite polarity for a visible selection.
    ldaa #$70
choice_ink
    jsr colour
    ldab choice_row
    aslb
    ldx choice_list
    jsr add_b
    ldx 0,x
    ldaa choice_row
    adda #8
    jsr window_line
    inc choice_row
    ldaa choice_row
    cmpa choice_count
    bne choice_line
choice_key
    ldaa #5
    jsr mouse_wait
    cmpa #27
    beq choice_cancel
    cmpa #3
    beq choice_cancel
    cmpa #$c0
    beq choice_accept
    cmpa #$c4
    beq choice_up
    cmpa #$c3
    beq choice_down
    cmpa #'0'
    bne choice_digit
    ldaa #':'
choice_digit
    suba #'1'
    cmpa choice_count
    bcc choice_key
    staa choice_index
choice_accept
    ldaa choice_index
    clr p_ui_menu
    rts
choice_cancel
    clr p_ui_menu
    ldaa #$ff
    rts
choice_up
    tst choice_index
    bne choice_previous
    ldaa choice_count
    staa choice_index
choice_previous
    dec choice_index
    jmp choice_draw
choice_down
    inc choice_index
    ldaa choice_index
    cmpa choice_count
    bcc *+5
    jmp choice_draw
    clr choice_index
    jmp choice_draw
ui_new
    jsr ui_enter
    tsta
    bne ui_choice_error
    tst p_modified
    beq new_choose
    ldx #p_new_question
    jsr confirm
    cmpa #'Y'
    bne ui_choice_cancel
new_choose
    ldaa p_kind
    staa choice_index
    ldx #p_format_list
    stx choice_list
    ldx #p_format_title
    jsr ui_choice
    bra ui_choice_leave
ui_choice_cancel
    ldaa #$ff
ui_choice_leave
    staa choice_result
    jsr ui_leave
    tsta
    bne ui_choice_error
    ldaa choice_result
    rts
ui_choice_error
    staa p_error
    ldaa #$ff
    rts
ui_tool
    jsr ui_enter
    tsta
    bne ui_choice_error
    ldaa p_tool
    staa choice_index
    ldx #p_tool_list
    stx choice_list
    ldx #p_tool_title
    jsr ui_choice
    cmpa #$ff
    beq tool_done
    staa p_tool
tool_done
    jmp ui_leave
ui_menu
    jsr ui_enter
    tsta
    bne ui_choice_error
    clr choice_index
    ldx #menu_list
    tst p_readonly
    beq menu_edit_list
    ldx #view_menu
menu_edit_list
    stx choice_list
    ldx #title
    tst p_readonly
    beq menu_caption
    ldx #p_view_title
menu_caption
    jsr ui_choice
    jsr ui_choice_leave
    cmpa #$ff
    beq menu_return
    tst p_readonly
    beq menu_edit_result
    tab
    ldx #view_menu_keys
    jsr add_b
    ldaa 0,x
    rts
menu_edit_result
    .ifdef PNT_OVL
    cmpa #5
    bcs menu_function
    suba #5
    tab
    ldx #menu_extra_keys
    jsr add_b
    ldaa 0,x
    rts
menu_function
    .endif
    adda #$ca
menu_return
    rts
ui_help
    jsr ui_enter
    tsta
    bne ui_simple_return
    tst p_readonly
    beq help_edit
    ldx #p_view_help
    jsr message
    jmp ui_leave
help_edit
    jsr help
    jmp ui_leave
    .else
ui_choice
ui_new
ui_tool
ui_menu
    ldaa #$ff
    rts
ui_help
    clra
    rts
    .endif
ui_error
    staa p_error
    jsr ui_enter
    tsta
    bne ui_simple_return
    ldaa p_error
    cmpa #65
    beq ui_bad_format
    cmpa #66
    beq ui_no_memory
    jsr error
    bra ui_error_leave
ui_bad_format
    ldx #p_bad_format
    bra ui_error_message
ui_no_memory
    ldx #p_no_memory
ui_error_message
    jsr message
ui_error_leave
    jsr ui_leave
    clr p_error
    rts
; X=question, return 'Y'/'N'; errors are negative confirmation.
ui_confirm
    stx choice_title
    jsr ui_enter
    tsta
    bne confirm_failed
    ldx choice_title
    jsr confirm
    staa choice_result
    jsr ui_leave
    tsta
    bne confirm_failed
    ldaa choice_result
    rts
confirm_failed
    ldaa #'N'
ui_simple_return
    rts
; File operations enter native UI once and update a row count between rows.
; X=message, A=completed rows. Keep cancellation in the main file loop.
ui_progress
    psha
    ldaa #8
    jsr window_line
    pula
    staa grid_index
    ; 20 cells represent 200 rows; draw completed cells with the ROM glyph.
    ldx #progress_text
    ldab #20
progress_clear
    ldaa #'.'
    staa 0,x
    inx
    decb
    bne progress_clear
    clr 0,x
    ldx #progress_text
    ldaa grid_index
progress_fill
    cmpa #10
    bcs progress_show
    suba #10
    ldab #'#'
    stab 0,x
    inx
    bra progress_fill
progress_show
    ldaa #12
    ldx #progress_text
    jmp window_line
    section
progress_text ds 21
    ends
ui_colour
    .ifndef PNT_COLOUR
ui_rgb
ui_swatch
    clra
    rts
    .else
    clr grid_mode
    bra colour_enter
ui_swatch
    ldaa #1
    staa grid_mode
colour_enter
    clr p_ui_result
    clr choice_result
    jsr ui_enter
    tsta
    beq colour_begin
    rts
colour_begin
    ldaa p_kind
    cmpa #4
    bne colour_grid
    tst grid_mode
    bne colour_swatch
    jmp colour_ham
colour_swatch
    ldaa #$ff
    staa p_cached_y
    clr p_row_dirty
    jsr palette_index
    tsta
    beq colour_grid
    staa choice_result
    jmp colour_leave
colour_grid
    jsr grid_build
    tsta
    beq colour_grid_ready
    staa choice_result
    jmp colour_leave
colour_grid_ready
    ldaa #2
    staa p_ui_menu
    jsr grid_cursor
grid_wait
    ldaa #10
    jsr mouse_wait
    cmpa #27
    bne *+5
    jmp colour_leave
    cmpa #3
    bne *+5
    jmp colour_leave
    cmpa #$c0
    beq grid_accept
    cmpa #$c1
    beq grid_left
    cmpa #$c2
    beq grid_right
    cmpa #$c4
    beq grid_up
    cmpa #$c3
    beq grid_down
    cmpa #$fe
    bne grid_wait
    ldaa mouse_pressed
    bita #2
    beq *+5
    jmp colour_leave
    bita #1
    beq grid_wait
    jsr grid_hit
    bcs grid_wait
grid_accept
    ldaa grid_index
    tst grid_limit
    beq grid_index_valid
    cmpa grid_limit
    bcc grid_wait
grid_index_valid
    ldab p_kind
    cmpb #2
    bcc grid_four_check
    cmpa #2
    bcc grid_wait
    bra grid_store
grid_four_check
    cmpb #2
    bne grid_store
    cmpa #4
    bcc grid_wait
grid_store
    staa p_fg
    inc p_ui_result
    jmp colour_leave
grid_left
    dec grid_index
    bra grid_move
grid_right
    inc grid_index
    bra grid_move
grid_up
    ldaa grid_index
    suba #16
    staa grid_index
    bra grid_move
grid_down
    ldaa grid_index
    adda #16
    staa grid_index
grid_move
    tst grid_limit
    beq grid_move_ready
    ldaa grid_index
    anda #63
    staa grid_index
grid_move_ready
    jsr grid_cursor
    jmp grid_wait
colour_ham
    ldx #p_fg_rgb
    jsr ui_rgb
    jmp colour_leave
; X=RGB666 triplet, native UI is already active. p_ui_result=1 on OK.
ui_rgb
    clr p_ui_result
    stx rgb_target
    stx choice_pointer
    ldx #input
    stx choice_list
    ldaa #3
    staa choice_count
colour_hex_output
    ldx choice_pointer
    ldaa 0,x
    inx
    stx choice_pointer
    staa ui_saved_a
    lsra
    lsra
    lsra
    lsra
    jsr hex_digit
    ldx choice_list
    staa 0,x
    ldaa ui_saved_a
    anda #15
    jsr hex_digit
    staa 1,x
    inx
    inx
    stx choice_list
    dec choice_count
    bne colour_hex_output
    clr 0,x
colour_hex_dialog
    ldx #p_colour_title
    jsr dialog
    bcc colour_rgb_parse
    clra
    rts
colour_rgb_parse
    ldx #input
    stx choice_pointer
    ldx #choice_hex
    stx choice_list
    ldaa #3
    staa choice_count
colour_hex_input
    ldx choice_pointer
    ldaa 0,x
    jsr hex_value
    bcs colour_hex_dialog
    cmpa #4
    bcc colour_hex_dialog
    asla
    asla
    asla
    asla
    staa ui_saved_a
    ldaa 1,x
    jsr hex_value
    bcs colour_hex_dialog
    oraa ui_saved_a
    inx
    inx
    stx choice_pointer
    ldx choice_list
    staa 0,x
    inx
    stx choice_list
    dec choice_count
    bne colour_hex_input
    ldx choice_pointer
    tst 0,x
    bne colour_hex_dialog
    ldx rgb_target
    ldaa choice_hex
    ldab choice_hex+1
    staa 0,x
    stab 1,x
    ldaa choice_hex+2
    staa 2,x
    inc p_ui_result
    clra
    rts
colour_leave
    ldaa p_kind
    cmpa #4
    bne colour_native_leave
    tst grid_mode
    beq colour_native_leave
    clr $e650
    jsr palette_ham
    tsta
    beq colour_native_leave
    staa choice_result
colour_native_leave
    jsr ui_leave
    tsta
    bne colour_return
    ldaa choice_result
colour_return
    rts
hex_digit
    adda #'0'
    cmpa #'9'
    bls hex_done
    adda #7
hex_done
    rts
hex_value
    cmpa #'0'
    bcs hex_bad
    cmpa #'9'
    bls hex_numeric
    anda #$df
    suba #'A'
    cmpa #6
    bcs *+5
    jmp hex_bad
    adda #10
    clc
    rts
hex_numeric
    suba #'0'
    clc
    rts
hex_bad
    sec
    rts
grid_build
    clr grid_limit
    ldaa p_kind
    cmpa #4
    bne grid_build_clear
    ldaa #64
    staa grid_limit
grid_build_clear
    jsr dma_reset
    ldx #paint_dma
    ldaa #P_PICKER_PAGE
    staa DMA_DST+2,x
    ldaa #$fa
    staa DMA_WIDTH+1,x
    ldaa #DMA_FILL
    jsr dma_run
    tsta
    beq *+5
    jmp grid_return
    clr grid_index
    clr grid_row
    clr grid_column
    ldx #0
    stx grid_offset
grid_cell
    jsr dma_reset
    ldx #paint_dma
    ldaa grid_offset+1
    staa DMA_DST,x
    ldaa grid_offset
    staa DMA_DST+1,x
    ldaa #P_PICKER_PAGE
    staa DMA_DST+2,x
    ldaa #20
    staa DMA_WIDTH,x
    ldaa #12
    staa DMA_HEIGHT,x
    ldaa #64
    staa DMA_DST_STRIDE,x
    ldaa #1
    staa DMA_DST_STRIDE+1,x
    ldaa grid_index
    staa DMA_VALUE,x
    ldaa #DMA_FILL
    jsr dma_run
    tsta
    beq *+5
    jmp grid_return
    ldaa grid_offset+1
    adda #20
    staa grid_offset+1
    bcc grid_column_next
    inc grid_offset
grid_column_next
    inc grid_column
    ldaa grid_column
    cmpa #16
    bne grid_cell_next
    clr grid_column
    ldaa grid_offset+1
    adda #$c0
    staa grid_offset+1
    ldaa grid_offset
    adca #$0d
    staa grid_offset
grid_cell_next
    inc grid_index
    beq grid_cells_ready
    ldaa grid_limit
    beq grid_cell
    cmpa grid_index
    bne grid_cell
grid_cells_ready
    ldaa #5
    staa $e655
    ldaa #3
    staa $e651
grid_flip_wait
    ldaa $e650
    bmi grid_flip_wait
    ldaa #1
    staa $e650
    ldaa p_fg
    tst grid_limit
    beq grid_initial
    anda #63
grid_initial
    staa grid_index
    clra
grid_return
    rts
grid_cursor
    ldaa grid_index
    anda #15
    staa grid_column
    ldx #20
    stx grid_x
grid_cursor_x
    tst grid_column
    beq grid_cursor_y
    ldaa grid_x+1
    adda #40
    staa grid_x+1
    bcc grid_cursor_x_done
    inc grid_x
grid_cursor_x_done
    dec grid_column
    bra grid_cursor_x
grid_cursor_y
    ldaa grid_index
    lsra
    lsra
    lsra
    lsra
    staa grid_row
    ldaa #6
grid_cursor_row
    tst grid_row
    beq grid_cursor_ready
    adda #12
    dec grid_row
    bra grid_cursor_row
grid_cursor_ready
    staa mouse_y_low
    ldx grid_x
    stx mouse_x
    jmp paint_pointer
grid_hit
    ldx mouse_x
    stx grid_x
    clr grid_column
grid_hit_column
    tst grid_x
    bne grid_subtract_x
    ldaa grid_x+1
    cmpa #40
    bcs grid_hit_row
grid_subtract_x
    ldaa grid_x+1
    suba #40
    staa grid_x+1
    ldaa grid_x
    sbca #0
    staa grid_x
    inc grid_column
    bra grid_hit_column
grid_hit_row
    clr grid_row
    ldaa mouse_y_low
    cmpa #192
    bcs *+5
    jmp hex_bad
grid_hit_y
    cmpa #12
    bcs grid_hit_ready
    suba #12
    inc grid_row
    bra grid_hit_y
grid_hit_ready
    ldaa grid_row
    asla
    asla
    asla
    asla
    oraa grid_column
    staa grid_index
    clc
    rts
    .endif
view_menu dw view_open,view_zoom,view_grid,view_help,view_exit
view_menu_keys db $cb,'z','g',$c9,$d2
view_open db '1  Open image',0
view_zoom db '2  Zoom',0
view_grid db '3  Pixel grid',0
view_help db '4  Help',0
view_exit db '5  Exit',0
menu_list dw menu_save,menu_open,p_colour_title,p_tool_title,p_format_title
    .ifdef PNT_OVL
    dw menu_zoom,menu_copy,menu_paste,menu_clear,menu_palette
menu_zoom db '6  Zoom 1x / 2x / 4x / 8x',0
menu_copy db '7  Copy selection',0
menu_paste db '8  Paste at pointer',0
menu_clear db '9  Clear selection',0
menu_palette db '0  Palette editor (P)',0
menu_extra_keys db 'z',3,22,4,'p'
    .endif
menu_save db '1  Save image',0
menu_open db '2  Open image',0
    end
