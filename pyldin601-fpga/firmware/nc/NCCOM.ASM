; NCCOM: Common video, strings, numbers and dialog routines (NCUI.LIB).
    include NCABI.INC
    include NCBOX.INC
    public add_b
    public caret_at
    public caret_hide
    public colour
    public confirm
    public copy_n
    public copy_octets
    public copy_z
    public decimal_le
    public decimal_number
    public dialog
    public divide_number
    public end_z
    public error
    public field
    public fill_field
    public help
    public line_text
    public message
    public padding
    public position
    public put
    public put_field
    public text_field
    public window_buttons
    public window_draw
    public window_line
    public window_open
    public window_wrap
    extern add_pointer
    extern button_focus
    extern button_table
    extern button_width
    extern columns
    extern command_caret
    extern confirm_title
    extern copy_blocks
    extern dst
    extern edit_cursor
    extern edit_index
    extern edit_length
    extern edit_offset
    extern error_text
    extern fill_char
    extern font_saved_19b7
    extern font_saved_page
    extern gfx_table
    extern help_text
    extern ink
    extern input
    extern input_end
    extern message_ptr
    extern mode
    extern number
    extern number_divisor
    extern number_ptr
    extern number_text
    extern ok_button
    extern ok_cancel__0523
    extern outptr
    extern output_char
    extern redraw
    extern remainder
    extern remaining
    extern screen_base
    extern src
    extern stride
    extern text_stride
    extern textptr
    extern title
    extern ui_command
    extern ui_x
    extern ui_y
    extern v_add_poin_1
    extern v_dst_1
    extern v_number_1
    extern v_number_2
    extern v_number_3
    extern v_number_t_10
    extern v_outptr_1
    extern v_screen_b_1
    extern v_src_1
    extern window_bottom
    extern window_focus
    extern window_index
    extern window_inner
    extern window_key
    extern window_left
    extern window_text
    extern window_title
    extern window_top
    extern yes_no_buttons

; Cursor focus follows NC's coordinates, independently of the DOS console.
; Text uses the CRTC cursor. Packed graphics uses its software caret, since
; a colour-graphics hardware cursor covers only half a character cell.
caret_at
    jsr position
    ldaa mode
    anda #3
    bne caret_graphic
    ldx outptr
    tst $fff7
    bmi caret_model_a
    inx
    inx
    bra caret_write
caret_model_a
    tst mode
    bne caret_write
    inx
    bra caret_write
caret_graphic
    jsr caret_hide
    ldaa #'_'
    jmp put
; Parking outside the screen also hides the cursor when BIOS INT11 ORs in
; the Cyrillic cursor blink bits ($60), which defeat cursor_start | $20.
caret_hide
    ldx #$3fff
caret_write
    stx add_pointer
    tpa
    psha
    sei
    ldaa $e600
    psha
    ldaa #14
    staa $e600
    ldaa add_pointer
    staa $e601
    ldaa #15
    staa $e600
    ldaa v_add_poin_1
    staa $e601
    pula
    staa $e600
    pula
    tap
    rts

; Native text and packed graphics use the same ROM 8x8 glyphs, including the
; box-drawing set. Own glyph output avoids clipping/state in the DOS console.
colour
    staa ink
    ldx #pixels_paper
    cmpa #$07
    beq colour_table
    cmpa #$17
    beq colour_table
    ldx #pixels_white
    cmpa #$31
    bne colour_selection
    ldx #pixels_cyan
    bra colour_table
colour_selection
    cmpa #$03
    bne colour_table
    ldx #pixels_selected
colour_table
    stx gfx_table
    rts

position
    ldaa mode
    anda #3
    bne position_graphics
    ldx screen_base
    stx outptr
    ldaa text_stride
    staa stride
    ldab ui_y
position_row
    tstb
    beq position_col
    ldaa v_outptr_1
    adda stride
    staa v_outptr_1
    bcc position_row_carry
    inc outptr
position_row_carry
    decb
    bra position_row
position_col
    ldab ui_x
    tst mode
    bne position_add
    tst $fff7
    bpl position_add
    aslb
position_add
    ldx outptr
    jsr add_b
    stx outptr
    rts
position_graphics
    ; Each character row is 320 bytes (601) or 640 (601A).
    ldaa ui_y
    asla
    asla
    adda ui_y
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    tst $fff7
    bpl position_graphic_row
    asla
    rolb
position_graphic_row
    adda v_screen_b_1
    adcb screen_base
    staa v_outptr_1
    stab outptr
    ldaa ui_x
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    psha
    ldaa mode
    cmpa #2
    pula
    bne position_graphic_col
    asla
    rolb
position_graphic_col
    adda v_outptr_1
    adcb outptr
    staa v_outptr_1
    stab outptr
    rts
put
    staa output_char
    ldaa mode
    anda #3
    bne put_graphic
    ldx outptr
    tst mode
    bne put_native
    tst $fff7
    bpl put_native
    ldaa ink
    staa 0,x
    inx
put_native
    ldaa output_char
    staa 0,x
    inx
    stx outptr
    rts
put_graphic
    ldaa output_char
    cmpa #32
    bne put_font
    jmp put_blank
put_font
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    addb #$d8
    staa glyph_ptr+1
    stab glyph_ptr
    ldaa $e6f0
    staa font_saved_page
    ldaa $e6f1
    staa font_saved_19b7
    clr $e6f1
    ldaa #8
    staa $e6f0
    ldx glyph_ptr
    ldaa 0,x
    staa glyph
    ldaa 1,x
    staa glyph+1
    ldaa 2,x
    staa glyph+2
    ldaa 3,x
    staa glyph+3
    ldaa 4,x
    staa glyph+4
    ldaa 5,x
    staa glyph+5
    ldaa 6,x
    staa glyph+6
    ldaa 7,x
    staa glyph+7
    ldaa font_saved_19b7
    staa $e6f1
    ldaa font_saved_page
    staa $e6f0
    ldaa mode
    cmpa #2
    beq put_four_colours
    ldx outptr
    ldaa ink
    cmpa #$07
    beq put_mono_inverted
    cmpa #$17
    beq put_mono_inverted
    cmpa #$03
    beq put_mono_inverted
    ldaa glyph
    staa 0,x
    ldaa glyph+1
    staa 1,x
    ldaa glyph+2
    staa 2,x
    ldaa glyph+3
    staa 3,x
    ldaa glyph+4
    staa 4,x
    ldaa glyph+5
    staa 5,x
    ldaa glyph+6
    staa 6,x
    ldaa glyph+7
    staa 7,x
    bra put_advance_eight
put_mono_inverted
    ldaa glyph
    coma
    staa 0,x
    ldaa glyph+1
    coma
    staa 1,x
    ldaa glyph+2
    coma
    staa 2,x
    ldaa glyph+3
    coma
    staa 3,x
    ldaa glyph+4
    coma
    staa 4,x
    ldaa glyph+5
    coma
    staa 5,x
    ldaa glyph+6
    coma
    staa 6,x
    ldaa glyph+7
    coma
    staa 7,x
put_advance_eight
    ldab #8
    jsr add_b
    stx outptr
    rts

put_four_colours
    clr glyph_row
put_colour_row
    ldx #glyph
    ldab glyph_row
    jsr add_b
    ldaa 0,x
    staa glyph_bits
    jsr pack_pixels
    ldx outptr
    ldaa glyph_byte
    staa 0,x
    jsr pack_pixels
    ldx outptr
    ldaa glyph_byte
    staa 8,x
    inx
    stx outptr
    inc glyph_row
    ldaa glyph_row
    cmpa #8
    bcs put_colour_row
    ldab #8
    ldx outptr
    jsr add_b
    stx outptr
    rts
; Expand four font bits at a time instead of testing all eight pixels.
pack_pixels
    ldaa glyph_bits
    lsra
    lsra
    lsra
    lsra
    tab
    ldx gfx_table
    jsr add_b
    ldaa 0,x
    staa glyph_byte
    asl glyph_bits
    asl glyph_bits
    asl glyph_bits
    asl glyph_bits
    rts
; Blanks dominate panel padding. Fill their pixels without reading the font.
put_blank
    clra
    ldab ink
    cmpb #$07
    beq put_blank_paper
    cmpb #$17
    beq put_blank_paper
    cmpb #$03
    bne put_blank_value
    ldaa #$ff
    ldab mode
    cmpb #2
    bne put_blank_value
    ldaa #$55
    bra put_blank_value
put_blank_paper
    ldaa #$ff
put_blank_value
    ldx outptr
    staa 0,x
    staa 1,x
    staa 2,x
    staa 3,x
    staa 4,x
    staa 5,x
    staa 6,x
    staa 7,x
    ldab mode
    cmpb #2
    beq *+5
    jmp put_advance_eight
    staa 8,x
    staa 9,x
    staa 10,x
    staa 11,x
    staa 12,x
    staa 13,x
    staa 14,x
    staa 15,x
    ldab #16
    jsr add_b
    stx outptr
    rts
pixels_white
    db $00,$03,$0c,$0f,$30,$33,$3c,$3f,$c0,$c3,$cc,$cf,$f0,$f3,$fc,$ff
pixels_cyan
    db $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
pixels_selected
    db $55,$54,$51,$50,$45,$44,$41,$40,$15,$14,$11,$10,$05,$04,$01,$00
pixels_paper
    db $ff,$fc,$f3,$f0,$cf,$cc,$c3,$c0,$3f,$3c,$33,$30,$0f,$0c,$03,$00
add_b
    tstb
    beq add_done
    ; MC6800 has no ABX. Add in constant time, preserving A as before.
    stx add_pointer
    psha
    ldaa v_add_poin_1
    aba
    staa v_add_poin_1
    bcc add_no_carry
    inc add_pointer
add_no_carry
    ldx add_pointer
    pula
    clrb
add_done
    rts
end_z
    tst 0,x
    beq end_done
    inx
    bra end_z
end_done
    rts
copy_z
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    staa 0,x
    beq copy_z_done
    inx
    stx dst
    bra copy_z
copy_z_done
    rts
copy_n
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    staa 0,x
    inx
    stx dst
    decb
    bne copy_n
    rts
; A = number of eight-byte groups (zero is empty). Separate pointers permit
; banked cache transfers and overlapping panel-row copies on an MC6800.
copy_octets
    staa copy_blocks
    tsta
    beq copy_octets_done
copy_octet
    ldx src
    ldaa 0,x
    ldab 1,x
    ldx dst
    staa 0,x
    stab 1,x
    ldx src
    ldaa 2,x
    ldab 3,x
    ldx dst
    staa 2,x
    stab 3,x
    ldx src
    ldaa 4,x
    ldab 5,x
    ldx dst
    staa 4,x
    stab 5,x
    ldx src
    ldaa 6,x
    ldab 7,x
    ldx dst
    staa 6,x
    stab 7,x
    ldaa v_src_1
    adda #8
    staa v_src_1
    bcc copy_source_advanced
    inc src
copy_source_advanced
    ldaa v_dst_1
    adda #8
    staa v_dst_1
    bcc copy_target_advanced
    inc dst
copy_target_advanced
    dec copy_blocks
    bne copy_octet
copy_octets_done
    rts
line_text
    ldaa columns
    staa remaining
field
    jsr text_field
padding
    ldaa #' '
    staa fill_char
fill_field
    tst remaining
    beq field_done
    ldaa fill_char
    jsr put_field
    bra fill_field
field_done
    rts
text_field
    stx textptr
text_loop
    tst remaining
    beq text_done
    ldx textptr
    ldaa 0,x
    beq text_done
    inx
    stx textptr
    jsr put_field
    bra text_loop
text_done
    rts
put_field
    tst remaining
    beq field_done
    dec remaining
    jmp put
; Shared modal windows. All state is ordinary RAM; video mode is preserved.
; Underlay is reconstructed by the caller's redraw/refresh on modal exit.
window_open
    ldaa #4
    staa window_left
    ldaa #6
    staa window_top
    ldaa #18
    staa window_bottom
    ldaa columns
    suba #10
    staa window_inner
window_draw
    stx window_title
    jsr caret_hide
    ; The graphics caret is an underscore in the prompt's reserved blank
    ; cell. Hardware parking alone cannot remove it when a modal opens.
    ldaa mode
    anda #3
    beq window_frame_start
    ldaa #$70
    jsr colour
    ldaa command_caret
    staa ui_x
    ldaa ui_command
    staa ui_y
    jsr position
    ldaa #' '
    jsr put
window_frame_start
    ldaa window_top
    staa window_index
window_frame_row
    ldaa window_left
    staa ui_x
    ldaa window_index
    staa ui_y
    ldaa #$17
    jsr colour
    jsr position
    ldaa #BOX_VERTICAL
    ldab window_index
    cmpb window_top
    bne window_frame_bottom
    ldaa #BOX_TOP_LEFT
window_frame_bottom
    cmpb window_bottom
    bne window_frame_left
    ldaa #BOX_BOTTOM_LEFT
window_frame_left
    jsr put
    ldaa window_inner
    staa remaining
    ldaa #BOX_HORIZONTAL
    ldab window_index
    cmpb window_top
    beq window_frame_fill
    cmpb window_bottom
    beq window_frame_fill
    ldaa #$07
    jsr colour
    ldaa #' '
window_frame_fill
    staa fill_char
    jsr fill_field
    ldaa #$17
    jsr colour
    ldaa #BOX_VERTICAL
    ldab window_index
    cmpb window_top
    bne window_right_bottom
    ldaa #BOX_TOP_RIGHT
window_right_bottom
    cmpb window_bottom
    bne window_frame_right
    ldaa #BOX_BOTTOM_RIGHT
window_frame_right
    jsr put
    ldaa window_index
    cmpa window_bottom
    beq window_caption
    inc window_index
    bra window_frame_row
window_caption
    ldaa window_left
    adda #2
    staa ui_x
    ldaa window_top
    staa ui_y
    jsr position
    ldaa window_inner
    suba #2
    staa remaining
    ldx window_title
    jmp text_field
; A=row, X=text. One-cell horizontal margins inside the frame.
window_line
    stx window_text
    staa ui_y
    ldaa #6
    staa ui_x
    jsr position
    ldaa columns
    suba #12
    staa remaining
    ldx window_text
    jmp field
window_wrap
    stx window_text
    staa window_index
window_wrap_line
    ldaa #$07
    jsr colour
    ldaa window_index
    ldx window_text
    jsr window_line
    ldx textptr
    tst 0,x
    beq window_wrap_done
    stx window_text
    inc window_index
    ldaa window_index
    cmpa #15
    bcs window_wrap_line
window_wrap_done
    rts
; X=two label pointers; button_focus=0/1, FF when the input owns focus.
window_buttons
    stx button_table
    ldaa columns
    lsra
    suba #6
    staa button_width
    clr window_index
window_button
    ldaa #6
    tst window_index
    beq window_button_position
    adda button_width
window_button_position
    staa ui_x
    ldaa #16
    staa ui_y
    ldaa #$07
    ldab window_index
    cmpb button_focus
    bne window_button_ink
    ldaa #$03
window_button_ink
    jsr colour
    jsr position
    ldaa button_width
    staa remaining
    ldaa #' '
    ldab window_index
    cmpb button_focus
    bne window_button_marker
    ldaa #'>'
window_button_marker
    jsr put_field
    ldab window_index
    aslb
    ldx button_table
    jsr add_b
    ldx 0,x
    jsr field
    inc window_index
    ldaa window_index
    cmpa #2
    bcs window_button
    rts
message
    stx message_ptr
    ldx #title
    jsr window_open
    ldx message_ptr
    ldaa #8
    jsr window_wrap
    ldaa #$03
    jsr colour
    ldx #ok_button
    ldaa #16
    jsr window_line
message_key
    int $11
    cmpa #27
    beq message_done
    cmpa #3
    beq message_done
    cmpa #$c0
    bne message_key
message_done
    rts
error
    ldx #error_text
    int $3d
    ldx #error_text
    jmp message
confirm
    stx message_ptr
    ldx #confirm_title
    jsr window_open
    ldx message_ptr
    ldaa #8
    jsr window_wrap
    ldaa #1
    staa button_focus
confirm_draw
    ldx #yes_no_buttons
    jsr window_buttons
confirm_key
    int $11
    cmpa #27
    beq confirm_no
    cmpa #3
    beq confirm_no
    cmpa #$ed
    beq confirm_toggle
    cmpa #$c1
    beq confirm_toggle
    cmpa #$c2
    beq confirm_toggle
    cmpa #$c0
    beq confirm_enter
    oraa #$20
    cmpa #'y'
    beq confirm_yes
    cmpa #'n'
    bne confirm_key
    bra confirm_no
confirm_enter
    tst button_focus
    beq confirm_yes

confirm_no
    ldaa #'N'
    rts
confirm_yes
    ldaa #'Y'
    rts
confirm_toggle
    ldaa button_focus
    eora #1
    staa button_focus
    bra confirm_draw

; Full insert-mode line editor with a visible caret, horizontal scrolling,
; cursor keys, Home/End/Delete and explicit OK/Cancel button focus.
dialog
    jsr window_open
    ldx #input
    jsr end_z
    stx input_end
    ldx #input
    clrb
dialog_length
    cpx input_end
    beq dialog_measured
    incb
    inx
    bra dialog_length
dialog_measured
    stab edit_length
    stab edit_cursor
    clr window_focus
    clr edit_offset
dialog_draw
    jsr caret_hide
    ldaa #$70
    jsr colour
    ldaa edit_cursor
    cmpa edit_offset
    bcc dialog_right_edge
    staa edit_offset
dialog_right_edge
    ldaa columns
    suba #13
    adda edit_offset
    cmpa edit_cursor
    bhi dialog_visible
    ldaa edit_cursor
    suba columns
    adda #14
    staa edit_offset
dialog_visible
    ldx #input
    ldab edit_offset
    jsr add_b
    ldaa #10
    jsr window_line
    ldaa window_focus
    bne dialog_buttons_draw
    ldaa edit_cursor
    suba edit_offset
    adda #6
    staa ui_x
    ldaa #10
    staa ui_y
    ldaa #$03
    jsr colour
    jsr position
    ldaa mode
    anda #3
    beq dialog_native_caret
    ldx #input
    ldab edit_cursor
    jsr add_b
    ldaa 0,x
    bne dialog_caret
    ldaa #'_'
dialog_caret
    jsr put
    bra dialog_buttons_draw
dialog_native_caret
    jsr caret_at
dialog_buttons_draw
    ldaa window_focus
    deca
    staa button_focus
    ldx #ok_cancel__0523
    jsr window_buttons
dialog_key
    int $11
    cmpa #27
    beq dialog_cancel
    cmpa #3
    beq dialog_cancel
    cmpa #$c0
    beq dialog_enter
    cmpa #13
    beq dialog_enter
    cmpa #$ed
    beq dialog_focus
    tst window_focus
    beq dialog_edit
    cmpa #$c1
    beq dialog_focus
    cmpa #$c2
    beq dialog_focus
    bra dialog_key
dialog_enter
    ldaa window_focus
    cmpa #2
    beq dialog_cancel
    clc
    rts
dialog_cancel
    sec
    rts
dialog_focus
    inc window_focus
    ldaa window_focus
    cmpa #3
    bcc *+5
    jmp dialog_draw
    clr window_focus
    jmp dialog_draw
dialog_edit
    cmpa #$c5
    beq dialog_home
    cmpa #$c6
    beq dialog_end
    cmpa #$c1
    beq dialog_left
    cmpa #$c2
    beq dialog_right
    cmpa #$7f
    beq dialog_back
    cmpa #8
    beq dialog_back
    cmpa #$f9
    beq dialog_delete
    cmpa #32
    bcs dialog_key
    cmpa #127
    beq dialog_key
    cmpa #$c0
    bcc dialog_key
    ldab edit_length
    cmpb #79
    bcc dialog_key
    staa window_key
    stab edit_index
dialog_insert_shift
    ldx #input
    ldab edit_index
    jsr add_b
    ldaa 0,x
    staa 1,x
    ldaa edit_index
    cmpa edit_cursor
    beq dialog_store
    dec edit_index
    bra dialog_insert_shift
dialog_store
    ldaa window_key
    staa 0,x
    inc edit_length
    inc edit_cursor
    jmp dialog_draw
dialog_home
    clr edit_cursor
    jmp dialog_draw
dialog_end
    ldaa edit_length
    staa edit_cursor
    jmp dialog_draw
dialog_left
    tst edit_cursor
    bne *+5
    jmp dialog_key
    dec edit_cursor
    jmp dialog_draw
dialog_right
    ldaa edit_cursor
    cmpa edit_length
    bne *+5
    jmp dialog_key
    inc edit_cursor
    jmp dialog_draw
dialog_back
    tst edit_cursor
    bne *+5
    jmp dialog_key
    dec edit_cursor
dialog_delete
    ldaa edit_cursor
    cmpa edit_length
    bne *+5
    jmp dialog_key
    staa edit_index
dialog_delete_shift
    ldx #input
    ldab edit_index
    jsr add_b
    ldaa 1,x
    staa 0,x
    inc edit_index
    tsta
    bne dialog_delete_shift
    dec edit_length
    jmp dialog_draw
help
    ldx #help_text
    jsr message
    jmp redraw
; X=32-bit little-endian integer -> zero-terminated decimal, no 64K truncation.
decimal_le
    ldaa 3,x
    staa number
    ldaa 2,x
    staa v_number_1
    ldaa 1,x
    staa v_number_2
    ldaa 0,x
    staa v_number_3
decimal_number
    ldaa #10
    staa number_divisor
    ldx #v_number_t_10
    clr 0,x
    stx number_ptr
decimal_digit
    jsr divide_number
    ldaa remainder
    adda #'0'
    ldx number_ptr
    dex
    staa 0,x
    stx number_ptr
    ldaa number
    oraa v_number_1
    oraa v_number_2
    oraa v_number_3
    bne decimal_digit
    ; Stop when the quotient reaches zero, rather than doing ten complete
    ; 32-bit divisions for every small file on every newly exposed row.
    ldx number_ptr
    stx src
    ldx #number_text
    stx dst
    jsr copy_z
    rts
; Unsigned BE32 / byte, quotient in number, remainder in remainder.
divide_number
    clr remainder
    ldx #number
    ldab #4
decimal_byte
    pshb
    ldab #8
decimal_bit
    asl 0,x
    rol remainder
    ldaa remainder
    cmpa number_divisor
    bcs decimal_less
    suba number_divisor
    staa remainder
    inc 0,x
decimal_less
    decb
    bne decimal_bit
    inx
    pulb
    decb
    bne decimal_byte
    rts
    section
glyph ds 8
glyph_ptr ds 2
glyph_row ds 1
glyph_bits ds 1
glyph_byte ds 1
    ends
    end
