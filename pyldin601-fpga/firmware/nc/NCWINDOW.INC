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
    ldx #ok_cancel_buttons
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
