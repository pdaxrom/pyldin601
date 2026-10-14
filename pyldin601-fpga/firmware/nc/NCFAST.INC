; Incremental navigation. The active catalogue remains in ordinary RAM or its leased bank.
; Selection changes recolour existing cells/pixels and replace two markers.
; One-line scrolling copies the visible panel and draws only its new row.
update_cursor
    ldaa active
    staa draw_panel
    jsr render_prepare
    ldaa ptop
    cmpa previous_top
    bne cursor_scroll
    ldaa pcur
    cmpa previous_cursor
    beq cursor_update_done
    ldaa previous_cursor
    staa draw_index
    jsr flip_cursor_row
    ldaa pcur
    staa draw_index
    jsr flip_cursor_row
    jmp render_active_info
cursor_update_done
    rts
cursor_scroll
    staa next_top
    ; Native text VRAM is write-only beneath the BIOS ROM overlay. Rebuild
    ; this panel from its cached catalogue; only graphics can copy pixels.
    ldaa mode
    anda #3
    beq cursor_rebuild_view
    ldaa next_top
    suba previous_top
    cmpa #1
    beq scroll_one_down
    cmpa #$ff
    beq scroll_one_up
    ; Home/End/PgUp/PgDn can expose a completely different viewport.
cursor_rebuild_view
    jsr render_panel_body
    jmp render_active_info
scroll_one_down
    clr scroll_direction
    bra scroll_one
scroll_one_up
    ldaa #1
    staa scroll_direction
scroll_one
    ldaa previous_top
    staa ptop
    ldaa previous_cursor
    staa draw_index
    jsr flip_cursor_row
    ldaa next_top
    staa ptop
    jsr scroll_panel
    ldaa #UI_FIRST
    staa ui_y
    ldaa ptop
    tst scroll_direction
    bne scroll_new_row
    adda ui_rows
    deca
    ldab ui_end
    decb
    stab ui_y
scroll_new_row
    staa draw_index
    jsr render_row
    jmp render_active_info

switch_panel
    ldaa active
    staa draw_panel
    eora #1
    staa active
    jsr render_prepare
    ldaa pcur
    staa draw_index
    jsr flip_cursor_row
    jsr render_panel_header
    ldaa active
    staa draw_panel
    jsr choose_panel
    jsr render_prepare
    jsr render_panel_header
    tst cache_lease_open
    bne switch_cached_panel
    ; Ordinary-RAM fallback just reread this catalogue; show any changes.
    jsr render_panel_body
    bra switch_path
switch_cached_panel
    ldaa pcur
    staa draw_index
    jsr flip_cursor_row
switch_path
    jsr render_active_info
    jmp render_command_line

flip_cursor_row
    ldaa draw_index
    suba ptop
    bcs flip_row_done
    cmpa ui_rows
    bcc flip_row_done
    adda #UI_FIRST
    staa ui_y
    ldaa origin
    inca
    staa ui_x
    clr cursor_selected
    ldaa draw_index
    jsr entry_pointer
    ldaa #$71
    ldab #' '
    tst 12,x
    beq flip_unmarked
    ldaa #$61
    ldab #'*'
flip_unmarked
    psha
    ldaa draw_panel
    cmpa active
    bne flip_not_selected
    ldaa draw_index
    cmpa pcur
    bne flip_not_selected
    pula
    ldaa #1
    staa cursor_selected
    ldab #'>'
    ldaa #$03
    bra flip_colour
flip_not_selected
    pula
flip_colour
    stab cursor_marker
    jsr colour
    jsr position
    ldaa panel_width
    suba #2
    staa cursor_cells
    ldaa mode
    anda #3
    bne flip_graphics
    tst mode
    bne flip_marker
    tst $fff7
    bpl flip_marker
    ldx outptr
    ldaa ink
flip_attributes
    staa 0,x
    inx
    inx
    dec cursor_cells
    bne flip_attributes
flip_marker
    ldaa cursor_marker
    jmp put
flip_row_done
    rts
flip_graphics
    ldx outptr
    ldaa mode
    cmpa #2
    beq flip_colour_pixels
flip_mono_cell
    ldab #8
flip_mono_byte
    com 0,x
    inx
    decb
    bne flip_mono_byte
    dec cursor_cells
    bne flip_mono_cell
    bra flip_marker
flip_colour_pixels
    tst cursor_selected
    beq flip_restore_colour
flip_select_cell
    ldab #16
flip_select_byte
    ldaa 0,x
    coma
    anda #$55
    staa 0,x
    inx
    decb
    bne flip_select_byte
    dec cursor_cells
    bne flip_select_cell
    bra flip_marker
flip_restore_colour
    ldab #16
flip_restore_byte
    ldaa 0,x
    staa cursor_byte
    asla
    oraa cursor_byte
    coma
    staa 0,x
    inx
    decb
    bne flip_restore_byte
    dec cursor_cells
    bne flip_restore_colour
    bra flip_marker

scroll_panel
    ldaa ui_rows
    deca
    staa scroll_count
    ldaa #UI_FIRST
    tst scroll_direction
    beq scroll_start
    ldaa ui_end
    deca
scroll_start
    staa scroll_row
scroll_next_row
    ldaa origin
    staa ui_x
    ldaa scroll_row
    staa ui_y
    jsr position
    ldx outptr
    stx scroll_target
    ldaa scroll_row
    tst scroll_direction
    bne scroll_source_before
    inca
    bra scroll_source_row
scroll_source_before
    deca
scroll_source_row
    staa ui_y
    jsr position
    ldx outptr
    stx scroll_source
    ; A panel spans 20/40 text bytes, 40 colour-text bytes, or 160/320
    ; packed graphics bytes. Copy rows in the safe overlap direction.
    ldaa panel_width
    clrb
    psha
    ldaa mode
    anda #3
    pula
    bne scroll_graphic_width
    tst mode
    bne scroll_width_ready
    tst $fff7
    bpl scroll_width_ready
    asla
    bra scroll_width_ready
scroll_graphic_width
    asla
    rolb
    asla
    rolb
    asla
    rolb
    psha
    ldaa mode
    cmpa #2
    pula
    bne scroll_width_ready
    asla
    rolb
scroll_width_ready
    psha
    anda #7
    staa scroll_tail
    pula
    lsrb
    rora
    lsrb
    rora
    lsrb
    rora
    psha
    ldx scroll_source
    stx src
    ldx scroll_target
    stx dst
    pula
    jsr copy_octets
    ldab scroll_tail
    beq scroll_row_copied
    jsr copy_n
scroll_row_copied
    ldaa scroll_row
    inca
    tst scroll_direction
    beq scroll_advance
    suba #2
scroll_advance
    staa scroll_row
    dec scroll_count
    beq nc_long_ncfast_1_286
    jmp scroll_next_row
nc_long_ncfast_1_286
    rts
