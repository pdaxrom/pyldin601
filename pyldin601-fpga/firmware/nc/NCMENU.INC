; Five persistent top-level menus. F9 opens the bar; F2 opens Command.
render_menu_bar
    clr ui_x
    clr ui_y
    clr menu_draw
    ldaa #8
    ldab columns
    cmpb #80
    bcs menu_slot_ready
    asla
menu_slot_ready
    staa menu_slot
menu_bar_item
    ldaa #$03
    tst menu_active
    beq menu_bar_colour
    ldab menu_draw
    cmpb menu_group
    bne menu_bar_colour
    ldaa #$70
menu_bar_colour
    jsr colour
    jsr position
    ldaa menu_slot
    staa remaining
    ldab menu_draw
    aslb
    ldx #top_names
    jsr add_b
    ldx 0,x
    jsr field
    ldaa ui_x
    adda menu_slot
    staa ui_x
    inc menu_draw
    ldaa menu_draw
    cmpa #5
    bcs menu_bar_item
    rts
menu
    ldaa #2
    staa menu_group
open_menu
    ldaa #1
    staa menu_active
    jsr render_menu_bar
    ldab menu_group
    ldx #menu_counts
    jsr add_b
    ldaa 0,x
    staa menu_count
    adda #2
    staa window_bottom
    ldaa #1
    staa window_top
    ldaa #22
    staa window_inner
    ldaa menu_group
    clrb
menu_offset
    tsta
    beq menu_offset_ready
    addb menu_slot
    deca
    bra menu_offset
menu_offset_ready
    ldaa columns
    suba #24
    stab window_left
    cmpa window_left
    bcc menu_position_ready
    staa window_left
menu_position_ready
    ldab menu_group
    aslb
    ldx #menu_lists
    jsr add_b
    ldx 0,x
    stx menu_table
    ldab menu_group
    aslb
    ldx #top_names
    jsr add_b
    ldx 0,x
    jsr window_draw
    clr menu_index
    clr menu_draw
menu_draw_all
    jsr menu_draw_item
    inc menu_draw
    ldaa menu_draw
    cmpa menu_count
    bcs menu_draw_all
menu_key
    int $11
    cmpa #27
    bne nc_long_ncmenu_1_377
    jmp menu_done
nc_long_ncmenu_1_377
    cmpa #3
    bne nc_long_ncmenu_2_377
    jmp menu_done
nc_long_ncmenu_2_377
    cmpa #$c1
    beq menu_left
    cmpa #$c2
    beq menu_right
    cmpa #$c0
    bne nc_long_ncmenu_3_377
    jmp menu_selected
nc_long_ncmenu_3_377
    cmpa #$c4
    beq menu_up
    cmpa #$c3
    beq menu_down
    cmpa #$ed
    beq menu_down
    suba #'1'
    cmpa menu_count
    bcc menu_key
    staa menu_index
    jmp menu_selected
menu_done
    jmp redraw
menu_left
    ldaa menu_group
    bne menu_left_step
    ldaa #5
menu_left_step
    deca
    staa menu_group
    bra menu_reopen
menu_right
    inc menu_group
    ldaa menu_group
    cmpa #5
    bcs menu_reopen
    clr menu_group
menu_reopen
    ; Text VRAM lies beneath BIOS ROM, so reconstruct the small covered
    ; region instead of reading an underlay or rebuilding the entire screen.
    clr draw_panel
menu_restore_panel
    ldaa draw_panel
    jsr choose_panel
    jsr render_prepare
    jsr render_panel_header
    jsr render_column_headings
    ldaa ptop
    staa draw_index
    ldaa #UI_FIRST
    staa ui_y
menu_restore_row
    jsr render_row
    inc draw_index
    inc ui_y
    ldaa ui_y
    cmpa #10
    bcs menu_restore_row
    inc draw_panel
    ldaa draw_panel
    cmpa #2
    bcs menu_restore_panel
    ldaa active
    jsr choose_panel
    jmp open_menu
menu_up
    ldaa menu_index
    staa menu_previous
    bne menu_up_step
    ldaa menu_count
menu_up_step
    deca
    bra menu_selection_move
menu_down
    ldaa menu_index
    staa menu_previous
    inca
    cmpa menu_count
    bcs menu_selection_move
    clra
menu_selection_move
    staa menu_index
    ldaa menu_previous
    staa menu_draw
    jsr menu_draw_item
    ldaa menu_index
    staa menu_draw
    jsr menu_draw_item
    jmp menu_key
menu_draw_item
    ldaa #$07
    ldab menu_draw
    cmpb menu_index
    bne menu_item_colour
    ldaa #$03
menu_item_colour
    jsr colour
    ldaa menu_draw
    adda #2
    staa ui_y
    ldaa window_left
    inca
    staa ui_x
    jsr position
    ldaa window_inner
    staa remaining
    ldaa #' '
    ldab menu_draw
    cmpb menu_index
    bne menu_item_marker
    ldaa #'>'
menu_item_marker
    jsr put_field
    ldab menu_draw
    aslb
    ldx menu_table
    jsr add_b
    ldx 0,x
    jmp field
menu_selected
    ldaa menu_index
    staa window_key
    ldaa menu_group
    cmpa #1
    beq menu_file_actions
    cmpa #2
    beq menu_command_actions
    cmpa #3
    beq settings
    lsra
    lsra
    staa active
    jsr choose_panel
    tst window_key
    beq menu_drive
    jmp refresh
menu_drive
    jmp change_drive
menu_file_actions
    ldx #file_actions
    bra menu_action
menu_command_actions
    ldx #command_actions
menu_action
    ldab window_key
    aslb
    jsr add_b
    ldx 0,x
    jmp 0,x
menu_editor
    ldx #editor_message
    jsr message
    jmp redraw
menu_copy
    ldaa #1
    jmp file_action
menu_move
    ldaa #2
    jmp file_action
menu_delete
    ldaa #3
    jmp file_action
menu_quit
    clra
    jmp leave
menu_command
    clr input
    ldx #command_prompt
    jsr dialog
    bcc nc_long_ncmenu_4_377
    jmp menu_done
nc_long_ncmenu_4_377
    ldx #input
    stx src
    ldx #command_line
    stx dst
    jsr copy_z
    ldx #command_line
    jsr path_length
    stab command_length
    tstb
    bne nc_long_ncmenu_5_377
    jmp menu_done
nc_long_ncmenu_5_377
    jmp enter

; Changes are staged in the modal window. Esc/Cancel discards the draft;
; Apply commits both controls atomically to the supervisor-owned settings.
settings
    ldx owner
    ldaa S_SORT,x
    staa draft_sort
    staa window_focus
    ldaa S_HIDDEN,x
    staa draft_hidden
    ldx #settings_title
    jsr window_open
settings_draw
    clr menu_draw
settings_control
    ldaa #$07
    ldab menu_draw
    cmpb window_focus
    bne settings_control_colour
    ldaa #$03
settings_control_colour
    jsr colour
    ldab menu_draw
    aslb
    ldx #settings_rows
    jsr add_b
    ldx 0,x
    ldaa menu_draw
    adda #8
    jsr window_line
    ldaa #6
    staa ui_x
    jsr position
    ldaa #' '
    ldab menu_draw
    cmpb window_focus
    bne settings_focus_marker
    ldaa #'>'
settings_focus_marker
    jsr put
    ldaa #8
    staa ui_x
    jsr position
    ldaa #' '
    ldab menu_draw
    cmpb #4
    beq settings_checkbox
    cmpb draft_sort
    bne settings_value_marker
    ldaa #'*'
    bra settings_value_marker
settings_checkbox
    tst draft_hidden
    beq settings_value_marker
    ldaa #'X'
settings_value_marker
    jsr put
    inc menu_draw
    ldaa menu_draw
    cmpa #5
    bcs settings_control
    ldaa window_focus
    suba #5
    staa button_focus
    ldx #apply_cancel_buttons
    jsr window_buttons
settings_key
    int $11
    cmpa #27
    bne nc_long_ncmenu_1_387
    jmp settings_cancel
nc_long_ncmenu_1_387
    cmpa #3
    bne nc_long_ncmenu_2_387
    jmp settings_cancel
nc_long_ncmenu_2_387
    cmpa #$c0
    beq settings_enter
    cmpa #$c4
    beq settings_up
    cmpa #$c3
    beq settings_down
    cmpa #$ed
    beq settings_down
    cmpa #32
    beq settings_space
    oraa #$20
    cmpa #'h'
    beq settings_toggle_hidden
    ldx #sort_keys
    clrb
settings_find_key
    cmpa 0,x
    beq settings_set_sort
    inx
    incb
    cmpb #4
    bcs settings_find_key
    bra settings_key
settings_set_sort
    stab draft_sort
    stab window_focus
    jmp settings_draw
settings_up
    ldaa window_focus
    bne settings_up_step
    ldaa #7
settings_up_step
    deca
    bra settings_focus
settings_down
    ldaa window_focus
    inca
    cmpa #7
    bcs settings_focus
    clra
settings_focus
    staa window_focus
    jmp settings_draw
settings_space
    ldaa window_focus
    cmpa #4
    beq settings_toggle_hidden
    bcc settings_enter
    staa draft_sort
    jmp settings_draw
settings_toggle_hidden
    ldaa draft_hidden
    eora #1
    staa draft_hidden
    ldaa #4
    staa window_focus
    jmp settings_draw
settings_enter
    ldaa window_focus
    cmpa #6
    bne nc_long_ncmenu_3_387
    jmp settings_cancel
nc_long_ncmenu_3_387
settings_apply
    ldx owner
    ldaa draft_sort
    staa S_SORT,x
    ldaa draft_hidden
    staa S_HIDDEN,x
    clr S_PAGEFLAGS,x
    clr S_PAGEFLAGS+1,x
    jmp refresh
settings_cancel
    jmp redraw
