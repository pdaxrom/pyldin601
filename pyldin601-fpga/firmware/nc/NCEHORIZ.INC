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
    ldx #view_anchor+0
    jsr q_store
    ldaa render_row
    jsr left_column_pointer
    jsr q_load
    ldx #view_anchor+4
    jsr q_store
anchor_rewind
    ldx #view_anchor+4
    jsr q_load
    ldx #horizontal
    jsr q_cmp
    bhi *+5
    jmp anchor_ready
    ldx #view_anchor+0
    jsr q_load
    ldaa render_row
    jsr line_pointer
    jsr q_cmp
    bhi *+5
    jmp anchor_ready
    jsr q_dec
    ldx #view_anchor+0
    jsr q_store
    ldx #where
    jsr q_store
    jsr doc_byte
    bcs horizontal_return
    cmpa #9
    beq anchor_tab
    ldx #view_anchor+4
    jsr q_load
    jsr q_dec
    ldx #view_anchor+4
    jsr q_store
    jmp anchor_rewind
anchor_tab
    ldx #e_cursor
    jsr q_load
    ldx #view_anchor+8
    jsr q_store
    ldx #e_column
    jsr q_load
    ldx #view_anchor+12
    jsr q_store
    ldaa cursor_row
    staa view_anchor+16
    ldaa render_row
    staa cursor_row
    ldx #view_anchor+0
    jsr q_load
    ldx #e_cursor
    jsr q_store
    jsr column_from_start
    staa view_anchor+17
    ldx #e_column
    jsr q_load
    ldx #view_anchor+4
    jsr q_store
    ldx #view_anchor+8
    jsr q_load
    ldx #e_cursor
    jsr q_store
    ldx #view_anchor+12
    jsr q_load
    ldx #e_column
    jsr q_store
    ldaa view_anchor+16
    staa cursor_row
    ldaa view_anchor+17
    beq *+5
    jmp horizontal_return
    jmp anchor_rewind
anchor_ready
    ldx #view_anchor+0
    jsr q_load
    ldaa render_row
    jsr left_pointer
    jsr q_store
    ldx #view_anchor+4
    jsr q_load
    ldaa render_row
    jsr left_column_pointer
    jsr q_store
    clra
    rts
