; The display cache is ordinary RAM because native text VRAM reads see ROM.
; Full view discovery indexes just the visible logical lines. Edits within a
; line repaint only its visible slice, using the cached horizontal anchor.
redraw
editor_redraw
    clr block_state+105
    ldx #screen_chars
    ldaa #$ff
    ldab #240
invalidate_octet
    staa 0,x
    staa 1,x
    staa 2,x
    staa 3,x
    staa 4,x
    staa 5,x
    staa 6,x
    staa 7,x
    inx
    inx
    inx
    inx
    inx
    inx
    inx
    inx
    decb
    bne invalidate_octet
    jsr build_view
    tsta
    beq *+5
    jmp editor_error
    jsr editor_footer
    jsr editor_header
    jsr editor_caret
editor_key
    ldaa #1
    staa editor_initialized
    int $11
    staa last_key
    jsr editor_uncaret
    jmp editor_dispatch
editor_finish
    tsta
    beq *+5
    jmp editor_error
    tst block_state+28
    beq *+5
    jmp editor_restore
    jsr block_finish
    jsr editor_header
    jsr editor_caret
    jmp editor_key
editor_error
    cmpa #$ff
    bne editor_io_error
    jsr block_cancel_release
    tst editor_initialized
    bne *+5
    jmp editor_close
    tst view_valid
    beq *+5
    jmp editor_restore
    jmp editor_redraw
editor_io_error
    jsr error
    staa error_key
    tst apply_phase
    bne editor_pending
    cmpa #27
    beq editor_error_exit
    tst base_closed
    beq editor_backing_ready
    jsr reopen_base
    tsta
    bne editor_error
editor_backing_ready
    tst apply_phase
    bne editor_pending
    ldaa error_key
    cmpa #27
    bne *+5
    jmp key_exit
    tst view_valid
    beq *+5
    jmp editor_restore
    jmp editor_redraw
editor_error_exit
    jmp key_exit
editor_pending
    ldx #retry_title
    jsr window_open
    ldx #retry_text
    ldaa #8
    jsr window_wrap
editor_pending_key
    int $11
    cmpa #27
    bne editor_pending_retry
    jmp editor_close
editor_pending_retry
    cmpa #$c0
    bne editor_pending_key
    jsr history_resume
    tsta
    bne editor_error
    jmp editor_redraw
editor_header
    tst block_state+105
    beq editor_header_full
    ldaa modified
    cmpa block_state+106
    bne editor_header_full
    ldaa overwrite
    cmpa block_state+107
    bne editor_header_full
    ldaa block_state+24
    cmpa block_state+35
    bne editor_header_full
    ; Filename and mode are stable while typing; repaint only the column.
    ldaa columns
    suba #12
    staa ui_x
    clr ui_y
    ldaa #$03
    jsr colour
    jsr position
    ldaa #12
    staa remaining
    bra header_column
editor_header_full
    ldaa block_state+24
    staa block_state+35
    ldaa #1
    staa block_state+105
    ldaa modified
    staa block_state+106
    ldaa overwrite
    staa block_state+107
    clr ui_x
    clr ui_y
    ldaa #$03
    jsr colour
    jsr position
    ldaa columns
    suba #20
    staa remaining
    ldx #filename
    jsr field
    ldaa #20
    staa remaining
    ldaa #' '
    tst modified
    beq header_mark
    ldaa #'*'
header_mark
    jsr put_field
    ldx #insert_label
    tst overwrite
    beq header_mode
    ldx #overwrite_label
header_mode
    tst block_state+24
    beq *+5
    ldx #block_label
    jsr text_field
header_column
    ldx #e_column
    jsr q_load
    jsr q_inc
    ldx #number
    jsr q_store
    jsr decimal_number
    ldx #number_text
    jsr field
    rts
editor_footer
    clr ui_x
    ldaa ui_keys
    staa ui_y
    ldaa #$03
    jsr colour
    jsr position
    ldx #editor_keys_short
    ldaa columns
    cmpa #80
    bcs footer_text
    ldx #editor_keys_long
footer_text
    jmp line_text
; A row, X = requested BE32 line metadata entry.
line_pointer
    ldx #line_offsets
    bra row_word_pointer
end_pointer
    ldx #line_ends
    bra row_word_pointer
left_pointer
    ldx #line_left
    bra row_word_pointer
left_column_pointer
    ldx #line_left_column
row_word_pointer
    tab
    aslb
    aslb
    jmp add_b
screen_pointer
    ldx #screen_chars
    ldaa render_row
screen_pointer_loop
    tsta
    beq screen_pointer_done
    ldab columns
    jsr add_b
    deca
    bra screen_pointer_loop
screen_pointer_done
    rts
build_view
    clr view_valid
    clr render_row
    clr cursor_seen
    clr render_eof
    ldx #screen_top
    jsr q_load
    ldx #where
    jsr q_store
    ldaa #1
    staa build_full
build_view_row
    ldaa render_row
    jsr line_pointer
    ldx #where
    jsr q_load
    ldaa render_row
    jsr line_pointer
    jsr q_store
    jsr build_line
    tsta
    beq *+5
    jmp build_return
    jsr paint_line
    inc render_row
    ldaa render_row
    cmpa body_rows
    bcs build_view_row
    ldaa render_row
    jsr line_pointer
    ldx #where
    jsr q_load
    ldaa render_row
    jsr line_pointer
    jsr q_store
    ldaa #1
    staa view_valid
    clra
build_return
    rts
build_line
    ldx #new_line
    ldab #80
build_blank
    ldaa #' '
    staa 0,x
    inx
    decb
    bne build_blank
    clr view_scan+0
    clr view_scan+1
    tst build_full
    beq build_partial
    clr view_scan+2
    clr view_scan+2+1
    clr view_scan+2+2
    clr view_scan+2+3
    ldx #where
    jsr q_load
    ldx #view_scan+6
    jsr q_store
    tst render_eof
    beq *+5
    jmp build_inactive
    ldaa render_row
    tab
    ldx #line_valid
    jsr add_b
    ldaa #1
    staa 0,x
    bra build_stream
build_partial
    ldaa render_row
    jsr left_pointer
    jsr q_load
    ldx #where
    jsr q_store
    ldaa render_row
    jsr left_column_pointer
    jsr q_load
    ldx #view_scan+2
    jsr q_store
    clr view_scan+1
build_stream
    jsr stream_init
    bcc *+5
    jmp build_eof
build_character
    ; Cursor position is measured before consuming each byte, including EOL.
    ldx #where
    jsr q_load
    ldx #e_cursor
    jsr q_cmp
    bne build_read
    ldx #view_scan+2
    jsr q_load
    ldx #e_column
    jsr q_store
    ldaa render_row
    staa cursor_row
    ldaa #1
    staa cursor_seen
build_read
    ldx #where
    jsr q_load
    ldx #view_scan+10
    jsr q_store
    ldx #view_scan+2
    jsr q_load
    ldx #view_scan+14
    jsr q_store
    jsr stream_next
    bcc *+5
    jmp build_eof
    staa view_scan+18
    cmpa #13
    bne *+5
    jmp build_cr
    cmpa #10
    bne *+5
    jmp build_lf
    cmpa #9
    beq build_tab
    cmpa #32
    bcs build_control
    cmpa #127
    bne build_emit_char
build_control
    ldaa #'.'
build_emit_char
    staa view_scan+19
    jsr build_emit
    bra build_continue
build_tab
    ldaa #' '
    staa view_scan+19
build_tab_space
    jsr build_emit
    ldaa view_scan+2+3
    anda #7
    bne build_tab_space
build_continue
    jsr editor_poll
    tsta
    beq *+3
    rts
    tst build_full
    beq build_partial_limit
    ldaa view_scan+0
    cmpa columns
    bcs build_more_chars
    jsr scan_line_tail
    tsta
    beq *+3
    rts
build_more_chars
    jmp build_character
build_partial_limit
    ldaa view_scan+0
    cmpa columns
    bcs build_more_chars
    clra
    rts

build_emit
    ldx #view_scan+2
    jsr q_load
    ldx #horizontal
    jsr q_cmp
    bcs build_advance_column
    ldaa view_scan+0
    cmpa columns
    bcc build_advance_column
    tst view_scan+1
    bne build_emit_store
    ldaa render_row
    jsr left_pointer
    ldx #view_scan+10
    jsr q_load
    ldaa render_row
    jsr left_pointer
    jsr q_store
    ldx #view_scan+14
    jsr q_load
    ldaa render_row
    jsr left_column_pointer
    jsr q_store
    inc view_scan+1
build_emit_store
    ldab view_scan+0
    ldx #new_line
    jsr add_b
    ldaa view_scan+19
    staa 0,x
    inc view_scan+0
build_advance_column
    ldx #view_scan+2
    jsr q_load
    jsr q_inc
    ldx #view_scan+2
    jsr q_store
    rts
build_cr
    ldx #view_scan+10
    jsr q_load
    ldx #view_scan+20
    jsr q_store
    jsr stream_next
    bcc build_cr_next
    tsta
    beq build_cr_alone
    rts
build_cr_next
    cmpa #10
    beq build_crlf
    ldx #where
    jsr q_load
    jsr q_dec
    ldx #where
    jsr q_store
build_cr_alone
    tst view_scan+24
    bne build_newline
    ldaa #1
    staa eol_length
    ldaa #13
    staa eol_bytes
    bra build_detected
build_crlf
    tst view_scan+24
    bne build_newline
    ldaa #2
    staa eol_length
    ldaa #13
    staa eol_bytes
    ldaa #10
    staa eol_bytes+1
    bra build_detected
build_lf
    ldx #view_scan+10
    jsr q_load
    ldx #view_scan+20
    jsr q_store
    tst view_scan+24
    bne build_newline
    ldaa #1
    staa eol_length
    ldaa #10
    staa eol_bytes
build_detected
    inc view_scan+24
build_newline
    bra build_store_end
build_eof
    tsta
    beq *+5
    jmp build_return
    ldx #where
    jsr q_load
    ldx #view_scan+20
    jsr q_store
    inc render_eof
    ldx #where
    jsr q_load
    ldx #e_cursor
    jsr q_cmp
    bne build_store_end
    ldx #view_scan+2
    jsr q_load
    ldx #e_column
    jsr q_store
    ldaa render_row
    staa cursor_row
    ldaa #1
    staa cursor_seen
build_store_end
    tst view_scan+1
    bne build_anchor_ready
    ldx #view_scan+20
    jsr q_load
    ldaa render_row
    jsr left_pointer
    jsr q_store
    ldx #view_scan+2
    jsr q_load
    ldaa render_row
    jsr left_column_pointer
    jsr q_store
build_anchor_ready
    ldx #view_scan+20
    jsr q_load
    ldaa render_row
    jsr end_pointer
    jsr q_store
    clra
    rts
build_inactive
    ldx #line_valid
    ldab render_row
    jsr add_b
    clr 0,x
    ldx #where
    jsr q_load
    ldx #view_scan+20
    jsr q_store
    clr view_scan+2
    clr view_scan+2+1
    clr view_scan+2+2
    clr view_scan+2+3
    jmp build_store_end
paint_line
    jsr block_row
    jsr block_mark_pointer
    ldaa 0,x
    staa block_state+31
    ldaa 1,x
    staa block_state+32
    ldaa block_state+29
    staa 0,x
    ldaa block_state+30
    staa 1,x
    jsr screen_pointer
    stx view_scan+25
    ldx #new_line
    stx view_scan+27
    clr ui_x
    ldaa render_row
    inca
    staa ui_y
    clr view_scan+30
    ldaa block_state+30
    oraa block_state+32
    staa block_state+91
    ldaa #$71
    staa block_state+33
paint_cell
    ldx view_scan+27
    ldaa 0,x
    inx
    stx view_scan+27
    staa view_scan+29
    tst block_state+91
    bne paint_cell_marked
    ldx view_scan+25
    cmpa 0,x
    beq paint_same
    bra paint_changed
paint_cell_marked
    ldaa #$71
    staa block_state+33
    staa block_state+34
    ldaa ui_x
    cmpa block_state+29
    bcs paint_old_ink
    cmpa block_state+30
    bcc paint_old_ink
    ldaa #$03
    staa block_state+33
paint_old_ink
    ldaa ui_x
    cmpa block_state+31
    bcs paint_compare
    cmpa block_state+32
    bcc paint_compare
    ldaa #$03
    staa block_state+34
paint_compare
    ldx view_scan+25
    ldaa view_scan+29
    cmpa 0,x
    bne paint_changed
    ldaa block_state+33
    cmpa block_state+34
    bne paint_changed
    cmpa #$03
    bne paint_same
    tst block_state+90
    beq paint_same
    ldaa block_state+29
    cmpa block_state+31
    bne paint_changed
    ldaa block_state+30
    cmpa block_state+32
    beq paint_same
paint_changed
    ldaa view_scan+29
    staa 0,x
    tst view_scan+30
    bne paint_put
    jsr position
paint_put
    ldaa block_state+33
    cmpa ink
    beq *+5
    jsr colour
    ldaa view_scan+29
    jsr block_put
    ldaa #1
    staa view_scan+30
    bra paint_advance
paint_same
    clr view_scan+30
paint_advance
    ldx view_scan+25
    inx
    stx view_scan+25
    inc ui_x
    ldaa ui_x
    cmpa columns
    bcc *+5
    jmp paint_cell
    rts

editor_caret
    ldx #e_column
    jsr q_load
    ldx #horizontal
    jsr q_sub
    ldaa q+3
    staa caret_x
    ldaa cursor_row
    inca
    staa caret_y
    ldaa caret_x
    staa ui_x
    ldaa caret_y
    staa ui_y
    ldaa mode
    anda #3
    bne editor_graphic_caret
    jmp caret_at
editor_graphic_caret
    jsr caret_hide
    ldaa cursor_row
    staa render_row
    jsr screen_pointer
    ldab caret_x
    jsr add_b
    ldaa 0,x
    staa caret_char
    jsr block_cached_ink
    staa block_state+36
    eora #$72
    jsr colour
    jsr position
    ldaa caret_char
    jmp put
editor_uncaret
    ldaa mode
    anda #3
    beq editor_native_uncaret
    ldaa block_state+36
    jsr colour
    ldaa caret_x
    staa ui_x
    ldaa caret_y
    staa ui_y
    jsr position
    ldaa caret_char
    jsr put
editor_native_uncaret
    jmp caret_hide

; Modal underlays come from the display cache, without rescanning long lines.
editor_restore
    clr block_state+28
    clr block_state+105
    clr restore_row
restore_body_row
    ldaa restore_row
    staa render_row
    jsr screen_pointer
    stx restore_ptr
    clr ui_x
    ldaa restore_row
    inca
    staa ui_y
    ldaa #$71
    jsr colour
    jsr position
restore_body_cell
    jsr block_cached_ink
    jsr colour
    ldx restore_ptr
    ldaa 0,x
    inx
    stx restore_ptr
    jsr block_put
    inc ui_x
    ldaa ui_x
    cmpa columns
    bcs restore_body_cell
    inc restore_row
    ldaa restore_row
    cmpa body_rows
    bcs restore_body_row
    jsr editor_footer
    clra
    jmp editor_finish
