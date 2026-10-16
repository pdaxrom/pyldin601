; NCMUI: Panel rendering, menus, settings, drive choice and progress.
    include NCABI.INC
    include NCBOX.INC
    public drive_number
    public drive_left
    public drive_right
    public menu
    public menu_command
    public menu_copy
    public menu_delete
    public menu_editor
    public menu_move
    public menu_quit
    public open_menu
    public progress_a_cc75
    public progress_finish
    public progress_start
    public progress_update
    public query_free_e16e
    public render
    public render_act_cbe7
    public render_com_7e25
    public render_pan_c869
    public render_prepare
    public settings
    public switch_panel
    public update_cursor
    extern mouse_wait
    extern active
    extern add_b
    extern apply_canc_22f2
    extern attribute_names
    extern button_focus
    extern cache_leas_2b52
    extern cancel_button
    extern caret_at
    extern choose_panel
    extern colour
    extern columns
    extern command_actions
    extern command_caret
    extern command_length
    extern command_line
    extern command_prompt
    extern copy_n
    extern copy_octets
    extern copy_z
    extern cursor_byte
    extern cursor_cells
    extern cursor_marker
    extern cursor_selected
    extern date_heading
    extern decimal_le
    extern decimal_number
    extern dialog
    extern dir_entry
    extern dir_text
    extern divide_number
    extern draft_hidden
    extern draft_sort
    extern draft_workdir
    extern draw_index
    extern draw_panel
    extern drive_buttons
    extern drive_choice
    extern drive_current
    extern drive_list
    extern drive_original
    extern drive_prompt
    extern drive_scan
    extern drive_target
    extern dst
    extern edit_file
    extern end_z
    extern enter
    extern entry_pointer
    extern error
    extern field
    extern field_padding
    extern field_ptr
    extern file_action
    extern file_actions
    extern fill_char
    extern fill_field
    extern find_state
    extern find_table
    extern free_left
    extern free_query
    extern free_right
    extern free_suffix
    extern free_unknown
    extern full_table
    extern has_previous
    extern header_ink
    extern info_unit
    extern ink
    extern input
    extern keys_long
    extern keys_short
    extern leave
    extern menu_active
    extern menu_count
    extern menu_counts
    extern menu_draw
    extern menu_group
    extern menu_index
    extern menu_lists
    extern menu_previous
    extern menu_slot
    extern menu_table
    extern message
    extern mode
    extern name_heading
    extern name_text
    extern next_top
    extern no_drives_text
    extern number
    extern number_divisor
    extern number_text
    extern operation
    extern origin
    extern outptr
    extern owner
    extern padding
    extern page_flag__1353
    extern panel
    extern panel_width
    extern path_length
    extern pathptr
    extern pcount
    extern pcur
    extern position
    extern previous_cursor
    extern previous_top
    extern progress_bytes
    extern progress_cells
    extern progress_done
    extern progress_from
    extern progress_i_c232
    extern progress_index
    extern progress_items
    extern progress_mode
    extern progress_next
    extern progress_p_70c2
    extern progress_q_e83a
    extern progress_slash
    extern progress_titles
    extern progress_to
    extern progress_total
    extern progress_v_0160
    extern progress_width
    extern ptop
    extern put
    extern put_field
    extern record_name
    extern redraw
    extern refresh
    extern remainder
    extern remaining
    extern row_entry
    extern scroll_count
    extern scroll_dir_9732
    extern scroll_row
    extern scroll_source
    extern scroll_tail
    extern scroll_target
    extern search_path
    extern settings_rows
    extern settings_title
    extern size_heading
    extern sort_keys
    extern source_handle
    extern source_path
    extern src
    extern stat_path
    extern store_cursor
    extern target_path
    extern text_field
    extern textptr
    extern top_names
    extern tops
    extern ui_bottom
    extern ui_command
    extern ui_end
    extern ui_info
    extern ui_keys
    extern ui_rows
    extern ui_x
    extern ui_y
    extern up_text
    extern v_20b2500eb9
    extern v_4b58002d3a
    extern v_51fd781692
    extern v_534cb484b8
    extern v_62eaa41089
    extern v_7299279710
    extern v_993c946a81
    extern v_a1fcfeedc2
    extern v_a45ec5704b
    extern v_c4fc9c08c2
    extern v_find_tab_2
    extern v_find_tab_4
    extern v_free_que_2
    extern v_full_tab_2
    extern v_number_1
    extern v_number_2
    extern v_number_3
    extern v_progress_1
    extern v_progress_2
    extern v_progress_3
    extern v_row_entr_1
    extern v_stat_ent_11
    extern window_bottom
    extern window_buttons
    extern window_draw
    extern window_focus
    extern window_inner
    extern window_key
    extern window_left
    extern window_line
    extern window_open
    extern window_text
    extern window_top
    extern workdir_default
    extern workdir_label
    extern workdir_title

; Native text and graphics share the ROM font (see NCCOM.ASM).
; NC colours: light grey on blue, black on cyan, yellow marked names.
; Pyldin's Cyrillic font differs from PC code pages at CF and D3.
render
    clr menu_active
    jsr render_menu_bar
    clr draw_panel
    jsr render_one_panel
    inc draw_panel
    jsr render_one_panel
    ldaa active
    jsr choose_panel
    jsr render_command_line
    clr ui_x
    ldaa ui_keys
    staa ui_y
    jsr position
    ldaa columns
    staa remaining
    ldx #keys_short
    ldaa columns
    cmpa #80
    bcs render_keys
    ldx #keys_long
render_keys
    stx textptr
render_key_character
    ldx textptr
    ldaa 0,x
    beq render_key_padding
    inx
    stx textptr
    psha
    cmpa #'0'
    bcs render_key_label
    cmpa #'9'
    bhi render_key_label
    ldaa #$70
    bra render_key_colour
render_key_label
    ldaa #$03
render_key_colour
    jsr colour
    pula
    jsr put_field
    bra render_key_character
render_key_padding
    ldaa #$03
    jsr colour
    jsr padding

render_done
    rts
render_one_panel
    ldaa draw_panel
    jsr choose_panel
    jsr render_prepare
    jsr render_panel_header
    jsr render_column_headings
    jsr render_panel_body
    ldaa origin
    staa ui_x
    ldaa ui_end
    staa ui_y
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_LEFT_TEE
    jsr put
    ldaa panel_width
    suba #2
    staa remaining
    ldaa #BOX_HORIZONTAL
    staa fill_char
    jsr fill_field
    ldaa #BOX_RIGHT_TEE
    jsr put
    jsr render_panel_info
    ldaa origin
    staa ui_x
    ldaa ui_bottom
    staa ui_y
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_BOTTOM_LEFT
    jsr put
    ldaa panel_width
    suba #2
    staa remaining
    ldaa #BOX_HORIZONTAL
    staa fill_char
    jsr free_text_pointer
    jsr right_field
    ldaa #BOX_BOTTOM_RIGHT
    jsr put
    rts
; The active catalogue is already cached for ordinary navigation.
render_prepare
    ldaa pcur
    cmpa pcount
    bcs render_cursor_ok
    ldaa pcount
    deca
    staa pcur
    jsr store_cursor
render_cursor_ok
    ldaa pcur
    cmpa ptop
    bcs render_new_top
    suba ptop
    cmpa ui_rows
    bcs render_top_ok
    ldaa pcur
    suba ui_rows
    inca
render_new_top
    staa ptop
render_top_ok
    ; The parent is visible only at the actual start of the directory.
    tst ptop
    bne render_visible_top
    ldab panel
    ldx #has_previous
    jsr add_b
    tst 0,x
    beq render_visible_top
    inc ptop
render_visible_top
    ldab panel
    ldx #tops
    jsr add_b
    ldaa ptop
    staa 0,x
    clr origin
    tst draw_panel
    beq render_origin
    ldaa panel_width
    staa origin
render_origin
    ldaa origin
    staa ui_x
    rts
render_panel_header
    ldaa origin
    staa ui_x
    ldaa #1
    staa ui_y
    ldaa #$31
    ldab draw_panel
    cmpb active
    bne render_header
    ldaa #$03
render_header
    staa header_ink
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_TOP_LEFT
    jsr put
    ldaa header_ink
    jsr colour
    ldaa panel_width
    suba #2
    staa remaining
    ldx pathptr
    jsr text_field
    ldaa #$31
    jsr colour
    ldaa #BOX_HORIZONTAL
    staa fill_char
    jsr fill_field
    ldaa #BOX_TOP_RIGHT
    jsr put
    rts
render_column_headings
    ldaa origin
    staa ui_x
    ldaa #2
    staa ui_y
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #$61
    jsr colour
    ldaa panel_width
    suba #2
    staa remaining
    ldaa columns
    cmpa #80
    bcs render_name_heading
    ldaa #13
    staa remaining
render_name_heading
    ldx #name_heading
    jsr field
    ldaa columns
    cmpa #80
    bcc *+5
    jmp render_row_border
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #10
    staa remaining
    ldx #size_heading
    ldaa #' '
    staa fill_char
    jsr right_field
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #13
    staa remaining
    ldx #date_heading
    jsr field
    jmp render_row_border
render_panel_body
    ldaa #UI_FIRST
    staa ui_y
    ldaa ptop
    staa draw_index
render_rows
    jsr render_row
    inc draw_index
    inc ui_y
    ldaa ui_y
    cmpa ui_end
    bcs render_rows
    rts
render_row
    ldaa origin
    staa ui_x
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #$71
    jsr colour
    ldaa draw_index
    cmpa pcount
    bcs render_valid_entry
    clr row_entry
    clr v_row_entr_1
    clr name_text
    ldaa #' '
    jsr put
    bra render_name_field
render_valid_entry
    jsr entry_pointer
    stx row_entry
    ldaa 12,x
    beq render_not_marked
    ldaa #$61
    jsr colour
render_not_marked
    ldaa draw_panel
    cmpa active
    bne render_not_cursor
    ldaa draw_index
    cmpa pcur
    bne render_not_cursor
    ldaa #$03
    jsr colour
    ldaa #'>'
    bra render_marker
render_not_cursor
    ldx row_entry
    ldaa 12,x
    beq render_unmarked
    ldaa #'*'
    bra render_marker
render_unmarked
    ldaa #' '
render_marker
    jsr put
    ldx #name_text
    stx dst
    ldx row_entry
    jsr record_name
render_name_field
    ldaa #12
    staa remaining
    ldx #name_text
    jsr field
    ldaa columns
    cmpa #80
    bcc render_wide_fields
    ldaa #5
    staa remaining
    ldx row_entry
    beq render_empty
    ldaa 11,x
    bita #16
    beq render_empty
    jsr directory_label
    jsr field
    jmp render_row_border
render_wide_fields
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #10
    staa remaining
    ldx row_entry
    beq render_empty_size
    ldaa 11,x
    bita #16
    beq render_file_size
    jsr directory_label
    bra render_size_text
render_file_size
    ldab #E_SIZE
    jsr add_b
    jsr decimal_le
    ldx #number_text
render_size_text
    ldaa #' '
    staa fill_char
    jsr right_field
    bra render_date_field
render_empty_size
    jsr padding
render_date_field
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #13
    staa remaining
    jsr render_file_date
render_empty
    jsr padding
render_row_border
    ldaa #$31
    jsr colour
    ldaa #BOX_VERTICAL
    jmp put

directory_label
    ldaa 0,x
    ldx #dir_text
    cmpa #'.'
    bne directory_label_done
    ldx #up_text
directory_label_done
    rts

; DD.MM [YYYY] HH:MM from the native little-endian FAT date/time. Parent/unknown
; timestamps stay blank; formatting uses no DOS calls or bank transfers.
render_file_date
    ldx row_entry
    bne *+5
    jmp render_date_done
    ldaa E_DATE,x
    oraa E_DATE+1,x
    bne *+5
    jmp render_date_done
    ldaa E_DATE,x
    anda #31
    jsr date_two
    ldaa #'.'
    jsr put_field
    ldx row_entry
    ldaa E_DATE+1,x
    asla
    asla
    asla
    anda #8
    staa field_padding
    ldaa E_DATE,x
    lsra
    lsra
    lsra
    lsra
    lsra
    oraa field_padding
    jsr date_two
    ldaa remaining
    cmpa #20
    bcs render_date_time
    ldaa #'.'
    jsr put_field
    clr number
    clr v_number_1
    ldaa #7
    staa v_number_2
    ldx row_entry
    ldaa E_DATE+1,x
    lsra
    adda #188
    staa v_number_3
    bcc render_date_year
    inc v_number_2
render_date_year
    jsr decimal_number
    ldx #number_text
    jsr text_field
render_date_time
    ldaa #' '
    jsr put_field
    ldx row_entry
    ldaa E_TIME+1,x
    lsra
    lsra
    lsra
    jsr date_two
    ldaa #':'
    jsr put_field
    ldx row_entry
    ldaa E_TIME+1,x
    anda #7
    asla
    asla
    asla
    staa field_padding
    ldaa E_TIME,x
    lsra
    lsra
    lsra
    lsra
    lsra
    oraa field_padding
    jsr date_two
render_date_done
    rts
date_two
    clrb
date_tens
    cmpa #10
    bcs date_digits
    suba #10
    incb
    bra date_tens
date_digits
    psha
    tba
    adda #'0'
    jsr put_field
    pula
    adda #'0'
    jmp put_field

render_active_info
render_panel_info
    ldaa origin
    staa ui_x
    ldaa ui_info
    staa ui_y
    jsr info_line_start
    ldaa pcur
    jsr entry_pointer
    stx row_entry
    ldx #name_text
    stx dst
    ldx row_entry
    jsr record_name
    ldaa panel_width
    suba #6
    staa remaining
    ldx #name_text
    jsr field
    ldab #1
    ldx #attribute_names
    stx textptr
info_attribute
    pshb
    ldx row_entry
    ldaa #'-'
    bitb E_ATTR,x
    beq info_attribute_put
    ldx textptr
    ldaa 0,x
info_attribute_put
    jsr put
    ldx textptr
    inx
    stx textptr
    pulb
    aslb
    cmpb #8
    bne info_attribute_archive
    ldab #32
info_attribute_archive
    cmpb #64
    bcs info_attribute
    jsr render_row_border
    inc ui_y
    ldaa origin
    staa ui_x
    jsr info_line_start
    ldaa panel_width
    suba #2
    staa remaining
    jsr render_file_date
    ldx row_entry
    ldaa E_ATTR,x
    bita #16
    beq info_file_size
    jsr directory_label
    bra info_size_text
info_file_size
    ldab #E_SIZE
    jsr add_b
    jsr decimal_le
    ldx #number_text
    jsr path_length
    cmpb remaining
    bcs info_size_ready
    ; Compact text uses KiB/MiB when the exact byte count would touch time.
    ldx row_entry
    ldaa E_SIZE+3,x
    staa number
    ldaa E_SIZE+2,x
    staa v_number_1
    ldaa E_SIZE+1,x
    staa v_number_2
    ldaa E_SIZE,x
    staa v_number_3
    ldaa #'K'
    staa info_unit
info_scale
    ldab #10
info_shift
    lsr number
    ror v_number_1
    ror v_number_2
    ror v_number_3
    decb
    bne info_shift
    ldaa number
    oraa v_number_1
    bne info_scale_more
    ldaa v_number_2
    cmpa #39
    bcs info_scaled
    bne info_scale_more
    ldaa v_number_3
    cmpa #16
    bcs info_scaled
info_scale_more
    ldaa #'M'
    staa info_unit
    bra info_scale
info_scaled
    jsr decimal_number
    ldx #number_text
    jsr end_z
    ldaa info_unit
    staa 0,x
    clr 1,x
info_size_ready
    ldx #number_text
info_size_text
    ldaa #' '
    staa fill_char
    jsr right_field
    jsr padding
    jmp render_row_border
info_line_start
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #$71
    jmp colour

; Both panels retain a formatted free-space string. Only catalogue refresh
; queries INT52; navigation and painting use these strings directly.
free_text_pointer
    ldx #free_left
    tst panel
    beq free_text_ready
    ldx #free_right
free_text_ready
    rts
query_free_space
    ldx pathptr
    ldaa 0,x
    suba #'A'
    ldx #free_query
    int $52
    tsta
    bne free_space_unknown
    ldx free_query
    stx number
    ldx v_free_que_2
    stx v_number_2
    jsr decimal_number
    jsr free_text_pointer
    stx dst
    ldx #number_text
    stx src
    jsr copy_z
    ldx #free_suffix
    bra free_space_copy
free_space_unknown
    jsr free_text_pointer
    stx dst
    ldx #free_unknown
free_space_copy
    stx src
    jmp copy_z

; X=string, remaining=field width, fill_char=left padding glyph.
right_field
    stx field_ptr
    jsr path_length
    ldaa remaining
    sba
    bcs right_field_text
    staa field_padding
right_field_pad
    tst field_padding
    beq right_field_text
    ldaa fill_char
    jsr put_field
    dec field_padding
    bra right_field_pad
right_field_text
    ldx field_ptr
    jmp text_field

render_command_line
    clr ui_x
    ldaa ui_command
    staa ui_y
    ldaa #$70
    jsr colour
    jsr position
    ; Keep room for input even when the active directory has a long name.
    ldaa columns
    lsra
    staa remaining
    ldx pathptr
    jsr text_field
    ldaa columns
    lsra
    adda remaining
    staa remaining
    ldaa #'>'
    jsr put_field
    ; Reserve the caret cell and show the command's tail when it is longer
    ; than the space after the prompt. Editing is append/backspace only.
    dec remaining
    ldx #command_line
    ldab command_length
    subb remaining
    bcc command_tail
    clrb
command_tail
    jsr add_b
    jsr text_field
    ldaa columns
    suba remaining
    deca
    staa command_caret
    inc remaining
    jsr padding
    ldaa command_caret
    staa ui_x
    jmp caret_at


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
    clr scroll_dir_9732
    bra scroll_one
scroll_one_up
    ldaa #1
    staa scroll_dir_9732
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
    tst scroll_dir_9732
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
    tst cache_leas_2b52
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
    tst scroll_dir_9732
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
    tst scroll_dir_9732
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
    tst scroll_dir_9732
    beq scroll_advance
    suba #2
scroll_advance
    staa scroll_row
    dec scroll_count
    beq *+5
    jmp scroll_next_row
    rts
; Per-file byte progress uses actual successful writes and unsigned 32-bit
; thresholds. Directory traversal/deletion show activity and completed items.
progress_open
    tst progress_v_0160
    bne progress_open_done
    ldaa #1
    staa progress_v_0160
    ldaa columns
    suba #18
    staa progress_width
    ldab operation
    decb
    aslb
    ldx #progress_titles
    jsr add_b
    ldx 0,x
    jsr window_open
    ldaa #$07
    jsr colour
    ldx #cancel_button
    ldaa #16
    jsr window_line
progress_open_done
    rts
progress_activity
    jsr progress_open
    clr progress_mode
    ldaa #8
    ldx #source_path
    jsr progress_path
    ldaa operation
    cmpa #3
    beq progress_activity_draw
    ldaa #10
    ldx #target_path
    jsr progress_path
progress_activity_draw
    jmp progress_draw
progress_path
    stx window_text
    staa ui_y
    ldaa #6
    staa ui_x
    ldaa #$07
    jsr colour
    jsr position
    ldaa columns
    suba #12
    staa remaining
    ldx #progress_from
    ldaa ui_y
    cmpa #8
    beq progress_path_label
    ldx #progress_to
progress_path_label
    jsr text_field
    ldx window_text
    jsr path_length
    cmpb remaining
    bcs progress_path_full
    subb remaining
    ldx window_text
    jsr add_b
    bra progress_path_text
progress_path_full
    ldx window_text
progress_path_text
    jmp field
progress_start
    ldaa source_handle
    ldx #progress_total
    int $51
    tsta
    beq progress_size_ready
    rts
progress_size_ready
    ldx #progress_done
    ldab #4
progress_clear_done
    clr 0,x
    inx
    decb
    bne progress_clear_done
    clr progress_cells
    jsr progress_activity
    ldaa #1
    staa progress_mode
    ldx #progress_total
    jsr progress_number
    ldaa progress_width
    staa number_divisor
    jsr divide_number
    tst remainder
    beq progress_round_done
    inc v_number_3
    bne progress_round_done
    inc v_number_2
    bne progress_round_done
    inc v_number_1
    bne progress_round_done
    inc number
progress_round_done
    ldx #number
    stx src
    ldx #progress_q_e83a
    stx dst
    ldab #4
    jsr copy_n
    ldx #progress_q_e83a
    stx src
    ldx #progress_next
    stx dst
    ldab #4
    jsr copy_n
    jsr progress_draw
    clra
    rts
; X=successful write length. Preserve no transient file-I/O pointers.
progress_update
    stx progress_bytes
    ldaa v_progress_3
    adda v_progress_1
    staa v_progress_3
    ldaa v_progress_2
    adca progress_bytes
    staa v_progress_2
    ldaa v_7299279710
    adca #0
    staa v_7299279710
    ldaa progress_done
    adca #0
    staa progress_done
    ldaa progress_cells
    staa progress_p_70c2
progress_threshold
    ldaa progress_cells
    cmpa progress_width
    bcc progress_update_done
    ldx #progress_done
    stx src
    ldx #progress_next
    stx dst
    ldab #4
progress_compare
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    cmpa 0,x
    bcs progress_update_done
    bhi progress_advance
    inx
    stx dst
    decb
    bne progress_compare
progress_advance
    inc progress_cells
    ldaa v_62eaa41089
    adda v_c4fc9c08c2
    staa v_62eaa41089
    ldaa v_51fd781692
    adca v_a1fcfeedc2
    staa v_51fd781692
    ldaa v_4b58002d3a
    adca v_a45ec5704b
    staa v_4b58002d3a
    ldaa progress_next
    adca progress_q_e83a
    staa progress_next
    bcc progress_threshold
    ldx #progress_next
    ldab #4
    ldaa #$ff
progress_saturate
    staa 0,x
    inx
    decb
    bne progress_saturate
progress_update_done
    ldaa progress_cells
    cmpa progress_p_70c2
    beq progress_no_draw
    jmp progress_draw
progress_no_draw
    rts
progress_finish
    inc v_993c946a81
    bne progress_finished_count
    inc v_20b2500eb9
    bne progress_finished_count
    inc v_534cb484b8
    bne progress_finished_count
    inc progress_items
progress_finished_count
    ldaa progress_width
    tst progress_mode
    bne progress_finish_cells
    ldaa progress_cells
    adda #4
    cmpa progress_width
    bcs progress_finish_cells
    clra
progress_finish_cells
    staa progress_cells
progress_draw
    ldaa #6
    staa ui_x
    ldaa #12
    staa ui_y
    ldaa #$71
    jsr colour
    jsr position
    ldaa #'['
    jsr put
    clr progress_index
progress_bar_cell
    ldaa #' '
    ldab progress_index
    cmpb progress_cells
    bcc progress_bar_empty
    ldaa #$db
progress_bar_empty
    jsr put
    inc progress_index
    ldaa progress_index
    cmpa progress_width
    bcs progress_bar_cell
    ldaa #']'
    jsr put
    ldaa #6
    staa ui_x
    ldaa #14
    staa ui_y
    ldaa #$07
    jsr colour
    jsr position
    ldaa columns
    suba #12
    staa remaining
    ldx #progress_items
    tst progress_mode
    beq progress_item_count
    ldx #progress_done
    jsr progress_number
    jsr decimal_number
    ldx #number_text
    jsr text_field
    ldx #progress_slash
    jsr text_field
    ldx #progress_total
    bra progress_amount
progress_item_count
    ldx #progress_i_c232
    jsr text_field
    ldx #progress_items
progress_amount
    jsr progress_number
    jsr decimal_number
    ldx #number_text
    jmp field
progress_number
    ldaa 0,x
    staa number
    ldaa 1,x
    staa v_number_1
    ldaa 2,x
    staa v_number_2
    ldaa 3,x
    staa v_number_3
    rts
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
    ldaa #5
    jsr mouse_wait
    cmpa #$fe
    bne *+5
    jmp menu_reopen
    cmpa #27
    bne *+5
    jmp menu_done
    cmpa #3
    bne *+5
    jmp menu_done
    cmpa #$c1
    beq menu_left
    cmpa #$c2
    beq menu_right
    cmpa #$c0
    bne *+5
    jmp menu_selected
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
    tst window_key
    beq menu_drive
    staa active
    jsr choose_panel
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
    jmp edit_file
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
    bcc *+5
    jmp menu_done
    ldx #input
    stx src
    ldx #command_line
    stx dst
    jsr copy_z
    ldx #command_line
    jsr path_length
    stab command_length
    tstb
    bne *+5
    jmp menu_done
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
    jsr settings_work_pointer
    stx src
    ldx #draft_workdir
    stx dst
    jsr copy_z
settings_window
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
    ldaa #$07
    ldab window_focus
    cmpb #5
    bne settings_work_colour
    ldaa #$03
settings_work_colour
    jsr colour
    ldx #workdir_label
    ldaa #13
    jsr window_line
    ldaa #$07
    jsr colour
    ldx #draft_workdir
    tst 0,x
    bne settings_work_value
    ldx #workdir_default
settings_work_value
    ldaa #14
    jsr window_line
    ldaa window_focus
    suba #6
    staa button_focus
    ldx #apply_canc_22f2
    jsr window_buttons
settings_key
    ldaa #6
    jsr mouse_wait
    cmpa #27
    bne *+5
    jmp settings_cancel
    cmpa #3
    bne *+5
    jmp settings_cancel
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
    cmpa #'w'
    bne *+5
    jmp settings_work_edit
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
    ldaa #8
settings_up_step
    deca
    bra settings_focus
settings_down
    ldaa window_focus
    inca
    cmpa #8
    bcs settings_focus
    clra
settings_focus
    staa window_focus
    jmp settings_draw
settings_space
    ldaa window_focus
    cmpa #5
    bne *+5
    jmp settings_work_edit
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
    cmpa #5
    bne *+5
    jmp settings_work_edit
    cmpa #7
    bne *+5
    jmp settings_cancel
settings_apply
    ldx owner
    ldaa draft_sort
    staa S_SORT,x
    ldaa draft_hidden
    staa S_HIDDEN,x
    clr S_PAGEFLAGS,x
    clr S_PAGEFLAGS+1,x
    jsr settings_work_pointer
    stx dst
    ldx #draft_workdir
    stx src
    jsr copy_z
    jmp refresh
settings_cancel
    jmp redraw

settings_work_pointer
    ldx owner
    ldab #255
    jsr add_b
    ldab #52
    jmp add_b
settings_work_edit
    ldx #draft_workdir
    stx src
    ldx #input
    stx dst
    jsr copy_z
    ldx #workdir_title
    jsr dialog
    bcs settings_work_back
    tst input
    beq settings_work_auto
    ldx #input
    stx full_table
    ldx #target_path
    stx v_full_tab_2
    ldx #full_table
    int $3f
    tsta
    bne settings_work_error
    ldx #target_path
    jsr path_length
    cmpb #3
    beq settings_work_slash
    ldx #target_path
    jsr stat_path
    tsta
    bne settings_work_error
    ldaa v_stat_ent_11
    bita #16
    beq settings_work_invalid
settings_work_slash
    ldx #target_path
    jsr path_length
    cmpb #51
    bhi settings_work_invalid
    dex
    ldaa 0,x
    inx
    cmpa #'\'
    beq settings_work_copy
    cmpb #51
    beq settings_work_invalid
    ldaa #'\'
    staa 0,x
    clr 1,x
settings_work_copy
    ldx #target_path
    stx src
    ldx #draft_workdir
    stx dst
    jsr copy_z
    bra settings_work_back
settings_work_auto
    clr draft_workdir
    bra settings_work_back
settings_work_invalid
    ldaa #19
settings_work_error
    jsr error
settings_work_back
    ldaa #5
    staa window_focus
    jmp settings_window
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
    ldaa #7
    jsr mouse_wait
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
    stx v_find_tab_4
    ldx #find_state
    stx find_table
    ldx #dir_entry
    stx v_find_tab_2
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
    jsr page_flag__1353
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
progress_a_cc75 equ progress_activity
query_free_e16e equ query_free_space
render_act_cbe7 equ render_active_info
render_com_7e25 equ render_command_line
render_pan_c869 equ render_panel_body
    end
