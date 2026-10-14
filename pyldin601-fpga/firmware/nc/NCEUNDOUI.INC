; A grouped Undo inside the visible line does not rescan a very long prefix.
history_fast_update
    tst history_record+29
    bne history_full_view
    clr metadata_row
history_find_row
    ldx #line_valid
    ldab metadata_row
    jsr add_b
    tst 0,x
    beq history_full_view
    ldx #apply_pos
    jsr q_load
    ldaa metadata_row
    jsr line_pointer
    jsr q_cmp
    bcs history_next_row
    ldaa metadata_row
    jsr end_pointer
    jsr q_cmp
    bls history_row_found
history_next_row
    inc metadata_row
    ldaa metadata_row
    cmpa body_rows
    bcs history_find_row
history_full_view
    ldaa #1
    rts
history_row_found
    ldx #apply_pos
    jsr q_load
    ldaa metadata_row
    jsr left_pointer
    jsr q_cmp
    bcs history_full_view
    ldaa history_mode
    cmpa #1
    beq history_undo_delta
    ldx #apply_pos
    jsr q_load
    ldx #history_record+8
    jsr q_add
    ldaa metadata_row
    jsr end_pointer
    jsr q_cmp
    bhi history_full_view
    ldx #history_record+16
    jsr q_load
    ldx #history_record+8
    jsr q_sub
    bra history_delta_ready
history_undo_delta
    ldx #apply_pos
    jsr q_load
    ldx #history_record+16
    jsr q_add
    ldaa metadata_row
    jsr end_pointer
    jsr q_cmp
    bhi history_full_view
    ldx #history_record+8
    jsr q_load
    ldx #history_record+16
    jsr q_sub
history_delta_ready
    ldx #edit_delta
    jsr q_store
    ldaa metadata_row
    staa cursor_row
    jsr shift_metadata_ready
    jsr column_from_anchor
    tsta
    bne history_fast_return
    jsr ensure_horizontal
    tsta
    beq history_fast_line
    jmp horizontal_repaint
history_fast_line
    ldaa cursor_row
    staa render_row
    clr build_full
    jsr build_line
    tsta
    bne history_fast_return
    jsr paint_line
    clra
history_fast_return
    rts
editor_history_result
    tsta
    bne history_fast_error
    jsr history_fast_update
    cmpa #1
    beq history_fast_rebuild
    jmp editor_finish
history_fast_rebuild
    jmp rebuild_cursor
history_fast_error
    jmp editor_error
