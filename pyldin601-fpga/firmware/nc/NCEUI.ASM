; NCEUI: Editor rendering, viewport copying and status.
    .define NC_EDITOR
    include NCABI.INC
    include NCBOX.INC
    public build_line
    public build_view
    public copy_bytes
    public editor_error
    public editor_finish
    public editor_redraw
    public editor_restore
    public end_pointer
    public left_colum_1c1a
    public left_pointer
    public line_pointer
    public paint_line
    public redraw
    public screen_pointer
    extern add_b
    extern apply_phase
    extern base_closed
    extern block_cach_8b13
    extern block_canc_33d4
    extern block_finish
    extern block_label
    extern block_mark_dc41
    extern block_put
    extern block_row
    extern body_rows
    extern build_full
    extern caret_at
    extern caret_char
    extern caret_hide
    extern caret_x
    extern caret_y
    extern colour
    extern columns
    extern copy_n
    extern copy_octets
    extern copy_tail
    extern cursor_row
    extern cursor_seen
    extern decimal_number
    extern e_column
    extern e_cursor
    extern editor_close
    extern editor_dispatch
    extern editor_ini_76b1
    extern editor_key_002a
    extern editor_key_4267
    extern editor_poll
    extern eol_bytes
    extern eol_length
    extern error
    extern error_key
    extern field
    extern filename
    extern history_resume
    extern horizontal
    extern ink
    extern insert_label
    extern key_exit
    extern last_key
    extern line_ends
    extern line_left
    extern line_left__56a0
    extern line_offsets
    extern line_text
    extern line_valid
    extern mode
    extern modified
    extern new_line
    extern number
    extern number_text
    extern overwrite
    extern overwrite_label
    extern position
    extern put
    extern put_field
    extern q_cmp
    extern q_dec
    extern q_inc
    extern q_load
    extern q_store
    extern q_sub
    extern remaining
    extern render_eof
    extern render_row
    extern reopen_base
    extern restore_ptr
    extern restore_row
    extern retry_text
    extern retry_title
    extern scan_line_tail
    extern screen_chars
    extern screen_top
    extern split_bytes
    extern stream_init
    extern stream_next
    extern text_field
    extern ui_keys
    extern ui_x
    extern ui_y
    extern v_block_st_105
    extern v_block_st_106
    extern v_block_st_107
    extern v_block_st_24
    extern v_block_st_28
    extern v_block_st_29
    extern v_block_st_30
    extern v_block_st_31
    extern v_block_st_32
    extern v_block_st_33
    extern v_block_st_34
    extern v_block_st_35
    extern v_block_st_36
    extern v_block_st_90
    extern v_block_st_91
    extern v_eol_byte_1
    extern v_q_3
    extern v_split_by_1
    extern v_view_sc_1313
    extern v_view_sc_402d
    extern v_view_sc_56a1
    extern v_view_sca_0
    extern v_view_sca_1
    extern v_view_sca_10
    extern v_view_sca_14
    extern v_view_sca_18
    extern v_view_sca_19
    extern v_view_sca_2
    extern v_view_sca_20
    extern v_view_sca_24
    extern v_view_sca_25
    extern v_view_sca_27
    extern v_view_sca_29
    extern v_view_sca_30
    extern v_view_sca_6
    extern view_valid
    extern where
    extern window_open
    extern window_wrap

; The display cache is ordinary RAM because native text VRAM reads see ROM.
; Full view discovery indexes just the visible logical lines. Edits within a
; line repaint only its visible slice, using the cached horizontal anchor.
redraw
editor_redraw
    clr v_block_st_105
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
    staa editor_ini_76b1
    int $11
    staa last_key
    jsr editor_uncaret
    jmp editor_dispatch
editor_finish
    tsta
    beq *+5
    jmp editor_error
    tst v_block_st_28
    beq *+5
    jmp editor_restore
    jsr block_finish
    jsr editor_header
    jsr editor_caret
    jmp editor_key
editor_error
    cmpa #$ff
    bne editor_io_error
    jsr block_canc_33d4
    tst editor_ini_76b1
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
    tst v_block_st_105
    beq editor_header_full
    ldaa modified
    cmpa v_block_st_106
    bne editor_header_full
    ldaa overwrite
    cmpa v_block_st_107
    bne editor_header_full
    ldaa v_block_st_24
    cmpa v_block_st_35
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
    ldaa v_block_st_24
    staa v_block_st_35
    ldaa #1
    staa v_block_st_105
    ldaa modified
    staa v_block_st_106
    ldaa overwrite
    staa v_block_st_107
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
    tst v_block_st_24
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
    ldx #editor_key_002a
    ldaa columns
    cmpa #80
    bcs footer_text
    ldx #editor_key_4267
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
    ldx #line_left__56a0
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
    clr v_view_sca_0
    clr v_view_sca_1
    tst build_full
    beq build_partial
    clr v_view_sca_2
    clr v_view_sc_56a1
    clr v_view_sc_1313
    clr v_view_sc_402d
    ldx #where
    jsr q_load
    ldx #v_view_sca_6
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
    ldx #v_view_sca_2
    jsr q_store
    clr v_view_sca_1
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
    ldx #v_view_sca_2
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
    ldx #v_view_sca_10
    jsr q_store
    ldx #v_view_sca_2
    jsr q_load
    ldx #v_view_sca_14
    jsr q_store
    jsr stream_next
    bcc *+5
    jmp build_eof
    staa v_view_sca_18
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
    staa v_view_sca_19
    jsr build_emit
    bra build_continue
build_tab
    ldaa #' '
    staa v_view_sca_19
build_tab_space
    jsr build_emit
    ldaa v_view_sc_402d
    anda #7
    bne build_tab_space
build_continue
    jsr editor_poll
    tsta
    beq *+3
    rts
    tst build_full
    beq build_partial_limit
    ldaa v_view_sca_0
    cmpa columns
    bcs build_more_chars
    jsr scan_line_tail
    tsta
    beq *+3
    rts
build_more_chars
    jmp build_character
build_partial_limit
    ldaa v_view_sca_0
    cmpa columns
    bcs build_more_chars
    clra
    rts

build_emit
    ldx #v_view_sca_2
    jsr q_load
    ldx #horizontal
    jsr q_cmp
    bcs build_advance_column
    ldaa v_view_sca_0
    cmpa columns
    bcc build_advance_column
    tst v_view_sca_1
    bne build_emit_store
    ldaa render_row
    jsr left_pointer
    ldx #v_view_sca_10
    jsr q_load
    ldaa render_row
    jsr left_pointer
    jsr q_store
    ldx #v_view_sca_14
    jsr q_load
    ldaa render_row
    jsr left_column_pointer
    jsr q_store
    inc v_view_sca_1
build_emit_store
    ldab v_view_sca_0
    ldx #new_line
    jsr add_b
    ldaa v_view_sca_19
    staa 0,x
    inc v_view_sca_0
build_advance_column
    ldx #v_view_sca_2
    jsr q_load
    jsr q_inc
    ldx #v_view_sca_2
    jsr q_store
    rts
build_cr
    ldx #v_view_sca_10
    jsr q_load
    ldx #v_view_sca_20
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
    tst v_view_sca_24
    bne build_newline
    ldaa #1
    staa eol_length
    ldaa #13
    staa eol_bytes
    bra build_detected
build_crlf
    tst v_view_sca_24
    bne build_newline
    ldaa #2
    staa eol_length
    ldaa #13
    staa eol_bytes
    ldaa #10
    staa v_eol_byte_1
    bra build_detected
build_lf
    ldx #v_view_sca_10
    jsr q_load
    ldx #v_view_sca_20
    jsr q_store
    tst v_view_sca_24
    bne build_newline
    ldaa #1
    staa eol_length
    ldaa #10
    staa eol_bytes
build_detected
    inc v_view_sca_24
build_newline
    bra build_store_end
build_eof
    tsta
    beq *+5
    jmp build_return
    ldx #where
    jsr q_load
    ldx #v_view_sca_20
    jsr q_store
    inc render_eof
    ldx #where
    jsr q_load
    ldx #e_cursor
    jsr q_cmp
    bne build_store_end
    ldx #v_view_sca_2
    jsr q_load
    ldx #e_column
    jsr q_store
    ldaa render_row
    staa cursor_row
    ldaa #1
    staa cursor_seen
build_store_end
    tst v_view_sca_1
    bne build_anchor_ready
    ldx #v_view_sca_20
    jsr q_load
    ldaa render_row
    jsr left_pointer
    jsr q_store
    ldx #v_view_sca_2
    jsr q_load
    ldaa render_row
    jsr left_column_pointer
    jsr q_store
build_anchor_ready
    ldx #v_view_sca_20
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
    ldx #v_view_sca_20
    jsr q_store
    clr v_view_sca_2
    clr v_view_sc_56a1
    clr v_view_sc_1313
    clr v_view_sc_402d
    jmp build_store_end
paint_line
    jsr block_row
    jsr block_mark_dc41
    ldaa 0,x
    staa v_block_st_31
    ldaa 1,x
    staa v_block_st_32
    ldaa v_block_st_29
    staa 0,x
    ldaa v_block_st_30
    staa 1,x
    jsr screen_pointer
    stx v_view_sca_25
    ldx #new_line
    stx v_view_sca_27
    clr ui_x
    ldaa render_row
    inca
    staa ui_y
    clr v_view_sca_30
    ldaa v_block_st_30
    oraa v_block_st_32
    staa v_block_st_91
    ldaa #$71
    staa v_block_st_33
paint_cell
    ldx v_view_sca_27
    ldaa 0,x
    inx
    stx v_view_sca_27
    staa v_view_sca_29
    tst v_block_st_91
    bne paint_cell_marked
    ldx v_view_sca_25
    cmpa 0,x
    beq paint_same
    bra paint_changed
paint_cell_marked
    ldaa #$71
    staa v_block_st_33
    staa v_block_st_34
    ldaa ui_x
    cmpa v_block_st_29
    bcs paint_old_ink
    cmpa v_block_st_30
    bcc paint_old_ink
    ldaa #$03
    staa v_block_st_33
paint_old_ink
    ldaa ui_x
    cmpa v_block_st_31
    bcs paint_compare
    cmpa v_block_st_32
    bcc paint_compare
    ldaa #$03
    staa v_block_st_34
paint_compare
    ldx v_view_sca_25
    ldaa v_view_sca_29
    cmpa 0,x
    bne paint_changed
    ldaa v_block_st_33
    cmpa v_block_st_34
    bne paint_changed
    cmpa #$03
    bne paint_same
    tst v_block_st_90
    beq paint_same
    ldaa v_block_st_29
    cmpa v_block_st_31
    bne paint_changed
    ldaa v_block_st_30
    cmpa v_block_st_32
    beq paint_same
paint_changed
    ldaa v_view_sca_29
    staa 0,x
    tst v_view_sca_30
    bne paint_put
    jsr position
paint_put
    ldaa v_block_st_33
    cmpa ink
    beq *+5
    jsr colour
    ldaa v_view_sca_29
    jsr block_put
    ldaa #1
    staa v_view_sca_30
    bra paint_advance
paint_same
    clr v_view_sca_30
paint_advance
    ldx v_view_sca_25
    inx
    stx v_view_sca_25
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
    ldaa v_q_3
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
    jsr block_cach_8b13
    staa v_block_st_36
    eora #$72
    jsr colour
    jsr position
    ldaa caret_char
    jmp put
editor_uncaret
    ldaa mode
    anda #3
    beq editor_native_uncaret
    ldaa v_block_st_36
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
    clr v_block_st_28
    clr v_block_st_105
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
    jsr block_cach_8b13
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
; Copy at most 512 ordinary/banked bytes, with a fast eight-byte body.
copy_bytes
    ldaa v_split_by_1
    anda #7
    staa copy_tail
    ldaa split_bytes
    ldab v_split_by_1
    lsra
    rorb
    lsra
    rorb
    lsra
    rorb
    tba
    jsr copy_octets
    ldab copy_tail
    tstb
    beq copy_bytes_done
    jmp copy_n
copy_bytes_done
    rts
left_colum_1c1a equ left_column_pointer
    end
