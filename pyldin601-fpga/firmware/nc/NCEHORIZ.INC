; Horizontal scrolling discovers only the new visible slices. Rewinding an
; ordinary byte uses the known column; a cold TAB derives its exact column.
horizontal_repaint
    clr render_row
    clr build_full
horizontal_row
    ldab render_row
    ldx #line_valid
    jsr add_b
    tst 0,x
    beq horizontal_next
    jsr horizontal_anchor
    tsta
    beq *+5
    jmp horizontal_return
    jsr build_line
    tsta
    beq *+5
    jmp horizontal_return
    jsr paint_line
horizontal_next
    inc render_row
    ldaa render_row
    cmpa body_rows
    bcs horizontal_row
    clra
horizontal_return
    rts
horizontal_anchor
    ldaa render_row
    jsr left_pointer
    jsr q_load
    ldx #anchor_offset
    jsr q_store
    ldaa render_row
    jsr left_column_pointer
    jsr q_load
    ldx #anchor_column
    jsr q_store
anchor_rewind
    ldx #anchor_column
    jsr q_load
    ldx #horizontal
    jsr q_cmp
    bhi *+5
    jmp anchor_ready
    ldx #anchor_offset
    jsr q_load
    ldaa render_row
    jsr line_pointer
    jsr q_cmp
    bhi *+5
    jmp anchor_ready
    jsr q_dec
    ldx #anchor_offset
    jsr q_store
    ldx #where
    jsr q_store
    jsr doc_byte
    bcs horizontal_return
    cmpa #9
    beq anchor_tab
    ldx #anchor_column
    jsr q_load
    jsr q_dec
    ldx #anchor_column
    jsr q_store
    jmp anchor_rewind
anchor_tab
    ldaa e_cursor
    staa anchor_saved_cursor
    ldaa e_cursor+1
    staa anchor_saved_cursor+1
    ldaa e_cursor+2
    staa anchor_saved_cursor+2
    ldaa e_cursor+3
    staa anchor_saved_cursor+3
    ldaa e_column
    staa anchor_saved_column
    ldaa e_column+1
    staa anchor_saved_column+1
    ldaa e_column+2
    staa anchor_saved_column+2
    ldaa e_column+3
    staa anchor_saved_column+3
    ldaa cursor_row
    staa anchor_saved_row
    ldaa render_row
    staa cursor_row
    ldaa anchor_offset
    staa e_cursor
    ldaa anchor_offset+1
    staa e_cursor+1
    ldaa anchor_offset+2
    staa e_cursor+2
    ldaa anchor_offset+3
    staa e_cursor+3
    jsr column_from_start
    staa anchor_error
    ldaa e_column
    staa anchor_column
    ldaa e_column+1
    staa anchor_column+1
    ldaa e_column+2
    staa anchor_column+2
    ldaa e_column+3
    staa anchor_column+3
    ldaa anchor_saved_cursor
    staa e_cursor
    ldaa anchor_saved_cursor+1
    staa e_cursor+1
    ldaa anchor_saved_cursor+2
    staa e_cursor+2
    ldaa anchor_saved_cursor+3
    staa e_cursor+3
    ldaa anchor_saved_column
    staa e_column
    ldaa anchor_saved_column+1
    staa e_column+1
    ldaa anchor_saved_column+2
    staa e_column+2
    ldaa anchor_saved_column+3
    staa e_column+3
    ldaa anchor_saved_row
    staa cursor_row
    ldaa anchor_error
    beq *+5
    jmp horizontal_return
    jmp anchor_rewind
anchor_ready
    ldx #anchor_offset
    jsr q_load
    ldaa render_row
    jsr left_pointer
    jsr q_store
    ldx #anchor_column
    jsr q_load
    ldaa render_row
    jsr left_column_pointer
    jsr q_store
    clra
    rts
