; NC panels mouse hit testing. Disk/UI actions run after mouse_wait returns.
    include NCABI.INC
    public mouse_event
    public mouse_action
    public mouse_target
    public mouse_ui_row
    public mouse_refocus
    public mouse_activate
    extern mouse_context
    extern mouse_column
    extern mouse_row
    extern mouse_pressed
    extern mouse_moved
    extern mouse_buttons
    extern mouse_focus
    extern mode
    extern columns
    extern caret_at
    extern ui_x
    extern ui_y
    extern ui_keys
    extern ui_rows
    extern ui_command
    extern ui_end
    extern active
    extern ptop
    extern pcur
    extern pcount
    extern choose_panel
    extern store_cursor
    extern menu_group
    extern menu_count
    extern menu_index
    extern menu_slot
    extern window_left
    extern window_inner
    extern window_focus
    extern drive_number
    extern menu_draw
    extern render_com_7e25
    extern keys_long
    extern keys_short
    extern mouse_bar_key
    section
mouse_action ds 1
mouse_target ds 1
mouse_ui_row ds 1
mouse_click ds 1
mouse_click_pan ds 1
mouse_click_idx ds 1
mouse_click_sec ds 1
mouse_click_cs ds 1
    ends
mouse_refocus
    jmp render_com_7e25
mouse_event
    tst mouse_context
    bne *+5
    jmp mouse_main
    ldaa mouse_pressed
    bita #1
    bne *+5
    jmp mouse_ignore
    ldaa mouse_context
    cmpa #5
    bne mouse_window_hit
    tst mouse_row
    bne mouse_window_hit
    jmp mouse_top_hit
mouse_window_hit
    ldaa mouse_column
    cmpa window_left
    bcc *+5
    jmp mouse_ignore
    suba window_left
    cmpa window_inner
    bls *+5
    jmp mouse_ignore
    ldaa mouse_context
    cmpa #5
    beq mouse_menu
    cmpa #6
    beq mouse_settings
    cmpa #7
    beq mouse_drive
    jmp mouse_ignore
mouse_menu
    ldaa mouse_row
    suba #2
    cmpa menu_count
    bcs *+5
    jmp mouse_ignore
    adda #'1'
    rts
mouse_drive
    ldaa mouse_row
    suba #8
    cmpa menu_count
    bcs *+5
    jmp mouse_ignore
    staa menu_index
    ldaa #$c0
    rts
mouse_settings
    ldaa mouse_row
    cmpa #8
    bcc *+5
    jmp mouse_ignore
    cmpa #13
    bcs mouse_settings_item
    cmpa #15
    bcs mouse_settings_work
    cmpa #16
    beq *+5
    jmp mouse_ignore
    ldaa mouse_column
    ldab columns
    lsrb
    cba
    ldaa #6
    bcs mouse_settings_button
    inca
mouse_settings_button
    staa window_focus
    ldaa #$c0
    rts
mouse_settings_item
    suba #8
    staa window_focus
    ldaa #32
    rts
mouse_settings_work
    ldaa #'w'
    rts
mouse_main
    ldaa mode
    anda #3
    bne mouse_main_click
    tst mouse_moved
    beq mouse_main_click
    ldaa mouse_column
    staa ui_x
    ldaa mouse_row
    staa ui_y
    jsr caret_at
    inc mouse_focus
mouse_main_click
    ldaa mouse_pressed
    bita #2
    beq mouse_left_click
    ldaa #$ca
    rts
mouse_left_click
    bita #1
    bne *+5
    jmp mouse_ignore
    ldaa mouse_row
    bne mouse_main_body
mouse_top_hit
    ldaa mouse_column
    clrb
mouse_top_group
    cmpa menu_slot
    bcs mouse_top_ready
    suba menu_slot
    incb
    cmpb #4
    bcs mouse_top_group
mouse_top_ready
    stab menu_group
    ldaa #2
    staa mouse_action
    ldaa #$fe
    rts
mouse_main_body
    cmpa #1
    bne mouse_body_rows
    ldaa mouse_column
    ldab columns
    lsrb
    cba
    ldaa #$e1
    bcs mouse_header_drive
    inca
mouse_header_drive
    rts
mouse_body_rows
    cmpa ui_keys
    beq mouse_function
    cmpa #UI_FIRST
    bcc *+5
    jmp mouse_ignore
    cmpa ui_end
    bcs *+5
    jmp mouse_ignore
    suba #UI_FIRST
    staa mouse_ui_row
    clra
    ldaa mouse_column
    ldab columns
    lsrb
    cba
    ldaa #0
    bcs mouse_panel_ready
    inca
mouse_panel_ready
    staa mouse_target
    ldaa #1
    staa mouse_action
    ldaa #$fe
    rts
mouse_function
    ldx #keys_short
    ldaa columns
    cmpa #80
    bcs mouse_function_ready
    ldx #keys_long
mouse_function_ready
    jmp mouse_bar_key

mouse_ignore
    ldaa #$ff
    rts
mouse_activate
    ldaa mouse_target
    staa active
    jsr choose_panel
    ldaa ptop
    adda mouse_ui_row
    cmpa pcount
    bcc mouse_activate_done
    staa pcur
    jsr store_cursor
    tst mouse_click
    beq mouse_record_click
    ldaa active
    cmpa mouse_click_pan
    bne mouse_record_click
    ldaa pcur
    cmpa mouse_click_idx
    bne mouse_record_click
    ldaa $19
    cmpa mouse_click_sec
    bne mouse_click_next_second
    ldaa $18
    suba mouse_click_cs
    bcs mouse_record_click
    bra mouse_click_interval
mouse_click_next_second
    ldaa mouse_click_sec
    inca
    cmpa #60
    bcs mouse_click_second_ready
    clra
mouse_click_second_ready
    cmpa $19
    bne mouse_record_click
    ldaa $18
    suba mouse_click_cs
    adda #100
mouse_click_interval
    cmpa #36
    bcc mouse_record_click
    clr mouse_click
    ldaa #3
    staa mouse_action
    rts
mouse_record_click
    ldaa #1
    staa mouse_click
    ldaa active
    staa mouse_click_pan
    ldaa pcur
    staa mouse_click_idx
    ldaa $19
    staa mouse_click_sec
    ldaa $18
    staa mouse_click_cs
mouse_activate_done
    rts
    end
