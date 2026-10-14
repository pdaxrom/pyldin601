; The display cache is ordinary RAM because native text VRAM reads see ROM.
; Full view discovery indexes just the visible logical lines. Edits within a
; line repaint only its visible slice, using the cached horizontal anchor.
redraw
editor_redraw
    clr header_valid
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
    jsr editor_header
    jsr editor_caret
    jmp editor_key
editor_error
    cmpa #$ff
    bne editor_io_error
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
    tst header_valid
    beq editor_header_full
    ldaa modified
    cmpa header_modified
    bne editor_header_full
    ldaa overwrite
    cmpa header_overwrite
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
    ldaa #1
    staa header_valid
    ldaa modified
    staa header_modified
    ldaa overwrite
    staa header_overwrite
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
    ldaa screen_top
    staa where
    ldaa screen_top+1
    staa where+1
    ldaa screen_top+2
    staa where+2
    ldaa screen_top+3
    staa where+3
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
    clr render_x
    clr anchor_set
    tst build_full
    beq build_partial
    clr scan_column
    clr scan_column+1
    clr scan_column+2
    clr scan_column+3
    ldaa where
    staa scan_start
    ldaa where+1
    staa scan_start+1
    ldaa where+2
    staa scan_start+2
    ldaa where+3
    staa scan_start+3
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
    ldx #scan_column
    jsr q_store
    clr anchor_set
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
    ldaa scan_column
    staa e_column
    ldaa scan_column+1
    staa e_column+1
    ldaa scan_column+2
    staa e_column+2
    ldaa scan_column+3
    staa e_column+3
    ldaa render_row
    staa cursor_row
    ldaa #1
    staa cursor_seen
build_read
    ldaa where
    staa scan_char_pos
    ldaa where+1
    staa scan_char_pos+1
    ldaa where+2
    staa scan_char_pos+2
    ldaa where+3
    staa scan_char_pos+3
    ldaa scan_column
    staa scan_char_column
    ldaa scan_column+1
    staa scan_char_column+1
    ldaa scan_column+2
    staa scan_char_column+2
    ldaa scan_column+3
    staa scan_char_column+3
    jsr stream_next
    bcc *+5
    jmp build_eof
    staa scan_char
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
    staa display_char
    jsr build_emit
    bra build_continue
build_tab
    ldaa #' '
    staa display_char
build_tab_space
    jsr build_emit
    ldaa scan_column+3
    anda #7
    bne build_tab_space
build_continue
    jsr editor_poll
    tsta
    beq *+3
    rts
    tst build_full
    beq build_partial_limit
    ldaa render_x
    cmpa columns
    bcs build_more_chars
    jsr scan_line_tail
    tsta
    beq *+3
    rts
build_more_chars
    jmp build_character
build_partial_limit
    ldaa render_x
    cmpa columns
    bcs build_more_chars
    clra
    rts

build_emit
    ldx #scan_column
    jsr q_load
    ldx #horizontal
    jsr q_cmp
    bcs build_advance_column
    ldaa render_x
    cmpa columns
    bcc build_advance_column
    tst anchor_set
    bne build_emit_store
    ldaa render_row
    jsr left_pointer
    ldx #scan_char_pos
    jsr q_load
    ldaa render_row
    jsr left_pointer
    jsr q_store
    ldx #scan_char_column
    jsr q_load
    ldaa render_row
    jsr left_column_pointer
    jsr q_store
    inc anchor_set
build_emit_store
    ldab render_x
    ldx #new_line
    jsr add_b
    ldaa display_char
    staa 0,x
    inc render_x
build_advance_column
    ldx #scan_column
    jsr q_load
    jsr q_inc
    ldx #scan_column
    jsr q_store
    rts
build_cr
    ldaa scan_char_pos
    staa scan_end
    ldaa scan_char_pos+1
    staa scan_end+1
    ldaa scan_char_pos+2
    staa scan_end+2
    ldaa scan_char_pos+3
    staa scan_end+3
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
    tst eol_detected
    bne build_newline
    ldaa #1
    staa eol_length
    ldaa #13
    staa eol_bytes
    bra build_detected
build_crlf
    tst eol_detected
    bne build_newline
    ldaa #2
    staa eol_length
    ldaa #13
    staa eol_bytes
    ldaa #10
    staa eol_bytes+1
    bra build_detected
build_lf
    ldaa scan_char_pos
    staa scan_end
    ldaa scan_char_pos+1
    staa scan_end+1
    ldaa scan_char_pos+2
    staa scan_end+2
    ldaa scan_char_pos+3
    staa scan_end+3
    tst eol_detected
    bne build_newline
    ldaa #1
    staa eol_length
    ldaa #10
    staa eol_bytes
build_detected
    inc eol_detected
build_newline
    bra build_store_end
build_eof
    tsta
    beq *+5
    jmp build_return
    ldaa where
    staa scan_end
    ldaa where+1
    staa scan_end+1
    ldaa where+2
    staa scan_end+2
    ldaa where+3
    staa scan_end+3
    inc render_eof
    ldx #where
    jsr q_load
    ldx #e_cursor
    jsr q_cmp
    bne build_store_end
    ldaa scan_column
    staa e_column
    ldaa scan_column+1
    staa e_column+1
    ldaa scan_column+2
    staa e_column+2
    ldaa scan_column+3
    staa e_column+3
    ldaa render_row
    staa cursor_row
    ldaa #1
    staa cursor_seen
build_store_end
    tst anchor_set
    bne build_anchor_ready
    ldx #scan_end
    jsr q_load
    ldaa render_row
    jsr left_pointer
    jsr q_store
    ldx #scan_column
    jsr q_load
    ldaa render_row
    jsr left_column_pointer
    jsr q_store
build_anchor_ready
    ldx #scan_end
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
    ldaa where
    staa scan_end
    ldaa where+1
    staa scan_end+1
    ldaa where+2
    staa scan_end+2
    ldaa where+3
    staa scan_end+3
    clr scan_column
    clr scan_column+1
    clr scan_column+2
    clr scan_column+3
    jmp build_store_end
paint_line
    jsr screen_pointer
    stx paint_cache
    ldx #new_line
    stx paint_text
    clr ui_x
    ldaa render_row
    inca
    staa ui_y
    clr paint_run
    ldaa #$71
    jsr colour
paint_cell
    ldx paint_text
    ldaa 0,x
    inx
    stx paint_text
    staa paint_char
    ldx paint_cache
    cmpa 0,x
    beq paint_same
    staa 0,x
    tst paint_run
    bne paint_put
    jsr position
paint_put
    ldaa paint_char
    jsr put
    ldaa #1
    staa paint_run
    bra paint_advance
paint_same
    clr paint_run
paint_advance
    ldx paint_cache
    inx
    stx paint_cache
    inc ui_x
    ldaa ui_x
    cmpa columns
    bcs paint_cell
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
    ldaa #$03
    jsr colour
    jsr position
    ldaa caret_char
    jmp put
editor_uncaret
    ldaa mode
    anda #3
    beq editor_native_uncaret
    ldaa #$71
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
    clr header_valid
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
    ldx restore_ptr
    ldaa 0,x
    inx
    stx restore_ptr
    jsr put
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
