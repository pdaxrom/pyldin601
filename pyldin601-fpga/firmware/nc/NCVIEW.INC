; Streaming text viewer. Only one 512-byte disk buffer, 32-bit offsets.
viewer
    ldaa active
    jsr choose_panel
    jsr selected
    bcs viewer_redraw
    ldaa 11,x
    bita #16
    bne viewer_redraw
    jsr selected_path
    ldx #source_path
    stx open_table
    ldx #0
    stx open_table+2
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    beq viewer_opened
    jsr error
viewer_redraw
    jmp redraw
viewer_opened
    stab view_handle
    ldx #view_position
    ldab #4
viewer_zero
    clr 0,x
    inx
    decb
    bne viewer_zero
    clr view_page
viewer_page
    jsr view_seek
    tsta
    beq nc_long_ncview_1_227
    jmp viewer_error
nc_long_ncview_1_227
    clr ui_x
    clr ui_y
    ldaa #$06
    jsr colour
    jsr position
    ldx #source_path
    jsr line_text
    ldaa #$71
    jsr colour
    ldaa #1
    staa ui_y
    clr ui_x
    jsr position
    clr view_eof
viewer_character
    jsr view_byte
    bcs viewer_end_page
    cmpa #13
    beq viewer_character
    cmpa #26
    beq viewer_end_page
    cmpa #10
    beq viewer_newline
    cmpa #9
    beq viewer_tab
    cmpa #32
    bcc viewer_print
    ldaa #'.'
viewer_print
    jsr put
    inc ui_x
    ldaa ui_x
    cmpa columns
    bcs viewer_character
    bra viewer_line_full
viewer_tab
    ldaa #' '
    jsr put
    inc ui_x
    ldaa ui_x
    cmpa columns
    bcc viewer_line_full
    anda #7
    bne viewer_tab
    bra viewer_character
viewer_newline
    ldaa columns
    suba ui_x
    staa remaining
    jsr padding
viewer_line_full
    inc ui_y
    clr ui_x
    ldaa ui_y
    cmpa #23
    bcc viewer_end_page
    jsr position
    bra viewer_character
viewer_end_page
    ldaa columns
    suba ui_x
    staa remaining
    jsr padding
viewer_clear_tail
    inc ui_y
    ldaa ui_y
    cmpa #24
    bcc viewer_footer
    clr ui_x
    jsr position
    ldaa columns
    staa remaining
    jsr padding
    bra viewer_clear_tail
viewer_footer
    clr ui_x
    ldaa #24
    staa ui_y
    ldaa #$06
    jsr colour
    jsr position
    ldx #viewer_keys
    jsr line_text
viewer_key
    int $11
    cmpa #3
    beq viewer_close
    cmpa #27
    beq viewer_close
    cmpa #$c5
    beq viewer_home
    cmpa #$c8
    beq viewer_previous
    cmpa #$c7
    beq viewer_next
    cmpa #32
    beq viewer_next
    bra viewer_key
viewer_home
    clr view_page
    ldx #view_position
    ldab #4
viewer_home_zero
    clr 0,x
    inx
    decb
    bne viewer_home_zero
    jmp viewer_page
viewer_previous
    tst view_page
    beq viewer_home
    dec view_page
    jsr view_history_pointer
    stx src
    ldx #view_position
    stx dst
    ldab #4
    jsr copy_n
    jmp viewer_page
viewer_next
    tst view_eof
    bne viewer_key
    ldaa view_page
    cmpa #63
    bcs viewer_grow_history
    ldx #view_history+4
    stx src
    ldx #view_history
    stx dst
    ldab #252
    jsr copy_n
    bra viewer_store_history
viewer_grow_history
    inc view_page
viewer_store_history
    jsr view_history_pointer
    stx dst
    ldx #view_position
    stx src
    ldab #4
    jsr copy_n
    jmp viewer_page
viewer_error
    jsr error
viewer_close
    ldaa view_handle
    int $4e
    jmp redraw
view_history_pointer
    ldaa view_page
    asla
    asla
    tab
    ldx #view_history
    jmp add_b
view_seek
    ldaa view_handle
    clrb
    ldx #view_position
    int $50
    ldx #0
    stx view_left
    rts
view_byte
    ldx view_left
    bne view_buffered
    ldx #io_buffer
    stx io_table
    ldx #512
    stx io_table+2
    ldaa view_handle
    ldx #io_table
    int $4c
    tsta
    bne view_no_byte
    stx view_left
    cpx #0
    beq view_no_byte
    ldx #io_buffer
    stx view_ptr
view_buffered
    ldx view_ptr
    ldaa 0,x
    inx
    stx view_ptr
    ldx view_left
    dex
    stx view_left
    inc view_position+3
    bne view_byte_done
    inc view_position+2
    bne view_byte_done
    inc view_position+1
    bne view_byte_done
    inc view_position
view_byte_done
    clc
    rts
view_no_byte
    inc view_eof
    sec
    rts
