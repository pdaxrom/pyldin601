; Native Ctrl+F1/Ctrl+F2 select a panel independently of the active panel.
drive_left
    clra
    bra change_drive
drive_right
    ldaa #1
change_drive
    staa drive_target
    jsr choose_panel
    ldx pathptr
    ldaa 0,x
    suba #'A'
    staa drive_current
    int $45
    staa drive_original
    clr menu_count
drive_enumerate
    clr drive_scan
drive_scan_next
    ; SET DRIVE validates registration without probing media or touching
    ; empty floppy devices. Restore the shell's working drive afterwards.
    ldaa drive_scan
    int $44
    tsta
    bne drive_scan_skip
    ldx #drive_list
    ldab menu_count
    jsr add_b
    ldaa drive_scan
    staa 0,x
    inc menu_count
drive_scan_skip
    inc drive_scan
    ldaa drive_scan
    cmpa #8
    bcs drive_scan_next
    ldaa drive_original
    int $44
drive_list_ready
    tst menu_count
    bne drive_find_current
    ldx #no_drives_text
    jsr message
    jmp redraw
drive_find_current
    clr menu_index
    clr menu_draw
drive_find_loop
    jsr drive_number
    cmpa drive_current
    bne drive_find_next
    ldaa menu_draw
    staa menu_index
drive_find_next
    inc menu_draw
    ldaa menu_draw
    cmpa menu_count
    bcs drive_find_loop
drive_draw
    ; An 18-cell window is centred inside the requested panel, including
    ; the 40-column modes. At most eight registered drives fit vertically.
    ldaa panel_width
    suba #18
    lsra
    tst drive_target
    beq drive_window_left
    adda panel_width
drive_window_left
    staa window_left
    ldaa #16
    staa window_inner
    ldaa #6
    staa window_top
    ldaa menu_count
    adda #10
    staa window_bottom
    ldx #drive_prompt
    jsr window_draw
    clr menu_draw
drive_draw_all
    jsr drive_row
    inc menu_draw
    ldaa menu_draw
    cmpa menu_count
    bcs drive_draw_all
    ldaa window_left
    adda #2
    staa ui_x
    ldaa menu_count
    adda #9
    staa ui_y
    ldaa #$07
    jsr colour
    jsr position
    ldaa #14
    staa remaining
    ldx #drive_buttons
    jsr field
drive_key
    int $11
    cmpa #27
    bne *+5
    jmp drive_cancel
    cmpa #3
    bne *+5
    jmp drive_cancel
    cmpa #$c0
    beq drive_accept
    cmpa #13
    beq drive_accept
    cmpa #$c4
    beq drive_up
    cmpa #$c1
    beq drive_up
    cmpa #$c3
    beq drive_down
    cmpa #$c2
    beq drive_down
    cmpa #$ed
    beq drive_down
    cmpa #$c5
    beq drive_home
    cmpa #$c6
    beq drive_end
    anda #$df
    suba #'A'
    cmpa #8
    bcc drive_key
    staa drive_choice
    clr menu_draw
drive_letter
    jsr drive_number
    cmpa drive_choice
    beq drive_letter_found
    inc menu_draw
    ldaa menu_draw
    cmpa menu_count
    bcs drive_letter
    bra drive_key
drive_letter_found
    ldaa menu_draw
    bra drive_move
drive_up
    ldaa menu_index
    bne drive_up_step
    ldaa menu_count
drive_up_step
    deca
    bra drive_move
drive_down
    ldaa menu_index
    inca
    cmpa menu_count
    bcs drive_move
drive_home
    clra
    bra drive_move
drive_end
    ldaa menu_count
    deca
drive_move
    ldab menu_index
    staa menu_index
    stab menu_draw
    jsr drive_row
    ldaa menu_index
    staa menu_draw
    jsr drive_row
    jmp drive_key
drive_cancel
    jmp redraw
drive_accept
    ldaa menu_index
    staa menu_draw
    jsr drive_number
    staa drive_choice
    cmpa drive_current
    beq drive_activate
    int $5c
    tsta
    bne drive_error
    ; An unchanged SD medium can pass MEDIA CHECK without a read. Verify
    ; that its root can be searched before committing either panel's path.
    ldx #search_path
    ldaa drive_choice
    adda #'A'
    staa 0,x
    ldaa #':'
    staa 1,x
    ldaa #'\'
    staa 2,x
    ldaa #'*'
    staa 3,x
    staa 5,x
    ldaa #'.'
    staa 4,x
    clr 6,x
    stx find_table+4
    ldx #find_state
    stx find_table
    ldx #dir_entry
    stx find_table+2
    clra
    ldab #8
    ldx #find_table
    int $42
    tsta
    beq drive_root_ready
    cmpa #11
    bne drive_error
drive_root_ready
    ldaa drive_target
    staa active
    jsr choose_panel
    ldaa drive_choice
    adda #'A'
    ldx pathptr
    staa 0,x
    ldaa #':'
    staa 1,x
    ldaa #'\'
    staa 2,x
    clr 3,x
    jsr page_flag_pointer
    clr 0,x
    clr pcur
    clr ptop
    jsr store_cursor
    jmp refresh
drive_activate
    ldaa drive_target
    staa active
    jmp redraw
drive_error
    jsr error
    ; The error window is wider than this picker. Restore its whole underlay.
    jsr render
    jmp drive_draw
drive_number
    ldx #drive_list
    ldab menu_draw
    jsr add_b
    ldaa 0,x
    rts
drive_row
    ldaa window_left
    inca
    staa ui_x
    ldaa menu_draw
    adda #8
    staa ui_y
    ldaa #$07
    ldab menu_draw
    cmpb menu_index
    bne drive_row_colour
    ldaa #$03
drive_row_colour
    jsr colour
    jsr position
    ldaa #16
    staa remaining
    ldaa #' '
    ldab menu_draw
    cmpb menu_index
    bne drive_row_marker
    ldaa #'>'
drive_row_marker
    jsr put_field
    ldaa #' '
    jsr put_field
    jsr drive_number
    adda #'A'
    jsr put_field
    ldaa #':'
    jsr put_field
    jmp padding
