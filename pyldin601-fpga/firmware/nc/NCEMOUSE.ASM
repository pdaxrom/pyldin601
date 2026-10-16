; Editor mouse: click-to-position and drag selection use the disk-backed
; editor's existing line anchors, tab/column walker and clipboard selection.
    .define NC_EDITOR
    include NCABI.INC
    public mouse_event
    public mouse_activate
    public mouse_refocus
    extern mouse_context
    extern mouse_column
    extern mouse_row
    extern mouse_pressed
    extern mouse_released
    extern mouse_buttons
    extern mouse_moved
    extern mouse_focus
    extern mouse_bar_key
    extern editor_key_002a
    extern editor_key_4267
    extern columns
    extern ui_keys
    extern mode
    extern ui_x
    extern ui_y
    extern caret_at
    extern editor_caret
    extern body_rows
    extern line_valid
    extern cursor_row
    extern q_load
    extern q_store
    extern q_small
    extern q_add
    extern q_cmp
    extern e_cursor
    extern horizontal
    extern desired_column
    extern desired_valid
    extern cursor_to_col
    extern editor_finish
    extern editor_error
    extern block_anchor
    extern block_state
    extern v_block_st_24
    extern v_block_st_25
    extern v_block_st_26
    extern v_block_st_27
    extern selection_clear
    extern group_open
    extern exit_focus
    section
mouse_drag ds 1
    ends
mouse_refocus
    jmp editor_caret
mouse_event
    ldaa mouse_context
    cmpa #1
    beq mouse_editor
    cmpa #9
    beq *+5
    jmp mouse_ignore
    ldaa mouse_pressed
    bita #1
    bne *+5
    jmp mouse_ignore
    ldaa mouse_row
    cmpa #16
    beq *+5
    jmp mouse_ignore
    ldaa columns
    suba #27
    lsra
    staa mouse_drag
    ldaa mouse_column
    suba mouse_drag
    bcc *+5
    jmp mouse_ignore
    clrb
mouse_exit_button
    cmpa #9
    bcs mouse_exit_ready
    suba #9
    incb
    cmpb #3
    bcs mouse_exit_button
    jmp mouse_ignore
mouse_exit_ready
    stab exit_focus
    ldaa #$c0
    rts
mouse_editor
    ldaa mode
    anda #3
    bne mouse_editor_click
    tst mouse_moved
    beq mouse_editor_click
    ldaa mouse_column
    staa ui_x
    ldaa mouse_row
    staa ui_y
    jsr caret_at
    inc mouse_focus
mouse_editor_click
    ldaa mouse_pressed
    bita #1
    bne mouse_editor_left
    ldaa mouse_buttons
    anda #1
    oraa mouse_released
    anda #1
    bne *+5
    jmp mouse_ignore
    tst mouse_drag
    bne *+5
    jmp mouse_ignore
mouse_editor_left
    ldaa mouse_row
    cmpa ui_keys
    beq mouse_editor_function
    tsta
    bne *+5
    jmp mouse_ignore
    deca
    cmpa body_rows
    bcs *+5
    jmp mouse_ignore
    ldaa #$fe
    rts
mouse_editor_function
    ldaa mouse_pressed
    bita #1
    bne *+5
    jmp mouse_ignore
    ldx #editor_key_002a
    ldaa columns
    cmpa #80
    bcs mouse_editor_bar
    ldx #editor_key_4267
mouse_editor_bar
    jmp mouse_bar_key
mouse_ignore
    ldaa #$ff
    rts
mouse_activate
    ldaa mouse_row
    deca
    tab
    ldx #line_valid
mouse_line_valid
    tstb
    beq mouse_line_check
    inx
    decb
    bra mouse_line_valid
mouse_line_check
    tst 0,x
    bne *+5
    jmp mouse_finish
    ldaa mouse_row
    deca
    staa cursor_row
    clr group_open
    clr desired_valid
    ldaa mouse_pressed
    bita #1
    beq mouse_seek
    jsr selection_clear
    clr v_block_st_25
mouse_seek
    ldaa mouse_column
    jsr q_small
    ldx #horizontal
    jsr q_add
    ldx #desired_column
    jsr q_store
    jsr cursor_to_col
    tsta
    beq *+5
    jmp editor_error
    ldaa mouse_pressed
    bita #1
    beq mouse_extend
    jsr block_anchor
    clr v_block_st_24
    ldaa #1
    staa mouse_drag
    bra mouse_finish
mouse_extend
    ldaa mouse_released
    bita #1
    beq mouse_extend_range
    clr mouse_drag
mouse_extend_range
    ldx #e_cursor
    jsr q_load
    ldx #block_state
    jsr q_cmp
    bne mouse_extend_nonempty
    jsr selection_clear
    bra mouse_finish
mouse_extend_nonempty
    ldaa #1
    staa v_block_st_24
    staa v_block_st_26
    staa v_block_st_27
mouse_finish
    clra
    jmp editor_finish
    end
