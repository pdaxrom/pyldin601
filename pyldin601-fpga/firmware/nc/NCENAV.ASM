; NCENAV: Editor navigation, line scanning and search.
    .define NC_EDITOR
    include NCABI.INC
    include NCBOX.INC
    public column_fro_c274
    public editor_dispatch
    public editor_nat_5e73
    public editor_poll
    public editor_res_c671
    public ensure_hor_027b
    public find_line_start
    public horizontal_beef
    public key_exit
    public key_ignored
    public move_docum_6b40
    public rebuild_cursor
    public scan_line_tail
    public shift_meta_3672
    public v_view_sc_1313
    public v_view_sc_402d
    public v_view_sc_56a1
    public v_view_sca_0
    public v_view_sca_1
    public v_view_sca_10
    public v_view_sca_14
    public v_view_sca_18
    public v_view_sca_19
    public v_view_sca_2
    public v_view_sca_20
    public v_view_sca_24
    public v_view_sca_25
    public v_view_sca_27
    public v_view_sca_29
    public v_view_sca_30
    public v_view_sca_6
    extern add_b
    extern block_dispatch
    extern body_rows
    extern build_full
    extern build_line
    extern build_view
    extern cancel_sav_fb1e
    extern change_add
    extern change_at
    extern change_bytes
    extern change_delete
    extern change_group
    extern change_lin_2598
    extern colour
    extern columns
    extern copy_z
    extern cursor_row
    extern cursor_seen
    extern decimal_number
    extern deleted_char
    extern desired_column
    extern desired_valid
    extern dialog
    extern doc_byte
    extern doc_size
    extern dst
    extern e_column
    extern e_cursor
    extern edit_delta
    extern editor_change
    extern editor_close
    extern editor_error
    extern editor_finish
    extern editor_his_2705
    extern editor_restore
    extern editor_save
    extern editor_save_as
    extern end_pointer
    extern eol_bytes
    extern eol_length
    extern exit_butto_56b1
    extern exit_draw
    extern exit_focus
    extern exit_message
    extern exit_title
    extern field
    extern group_open
    extern half_columns
    extern help_text
    extern history_redo
    extern history_undo
    extern horizontal
    extern input
    extern last_key
    extern left_colum_1c1a
    extern left_pointer
    extern line_pointer
    extern line_valid
    extern message
    extern metadata_row
    extern modified
    extern nav_column
    extern nav_end
    extern nav_line
    extern nav_position
    extern nav_probe
    extern nav_saved
    extern nav_start
    extern not_found_text
    extern number
    extern number_text
    extern overwrite
    extern page_remaining
    extern paint_line
    extern poll_count
    extern position
    extern put_field
    extern q
    extern q_add
    extern q_cmp
    extern q_dec
    extern q_inc
    extern q_load
    extern q_small
    extern q_store
    extern q_sub
    extern q_test
    extern remaining
    extern render_row
    extern screen_top
    extern search_amount
    extern search_char
    extern search_i
    extern search_j
    extern search_length
    extern search_pre_0813
    extern search_skip
    extern search_start
    extern search_text
    extern search_title
    extern search_wrapped
    extern src
    extern stream_block
    extern stream_init
    extern stream_left
    extern stream_next
    extern stream_ptr
    extern stream_rem_2015
    extern ui_x
    extern ui_y
    extern v_change_b_1
    extern v_e_column_1
    extern v_e_column_2
    extern v_e_column_3
    extern v_e_cursor_1
    extern v_e_cursor_2
    extern v_e_cursor_3
    extern v_edit_del_1
    extern v_edit_del_2
    extern v_edit_del_3
    extern v_eol_byte_1
    extern v_horizont_1
    extern v_horizont_2
    extern v_horizont_3
    extern v_nav_colu_1
    extern v_nav_colu_2
    extern v_nav_colu_3
    extern v_q_1
    extern v_q_2
    extern v_q_3
    extern v_screen_t_1
    extern v_screen_t_2
    extern v_screen_t_3
    extern v_stream_l_1
    extern v_where_1
    extern v_where_2
    extern v_where_3
    extern where
    extern window_line
    extern window_open
    extern window_wrap

; Once a line's visible slice is drawn, scan ordinary off-screen runs in
; blocks. CR/LF/TAB and the cursor boundary return to the character parser.
scan_line_tail
    jsr stream_block
    bcc *+5
    jmp scan_tail_return
    ldx stream_left
    stx view_tail+0
    ldx #e_cursor
    jsr q_load
    ldx #where
    jsr q_sub
    bcs scan_tail_limit
    jsr q_test
    bne *+5
    jmp scan_tail_ok
    ldaa q
    oraa v_q_1
    bne scan_tail_limit
    ldaa v_q_2
    cmpa view_tail+0
    bne scan_tail_compare
    ldaa v_q_3
    cmpa view_tail+0+1
scan_tail_compare
    bcc scan_tail_limit
    ldx v_q_2
    stx view_tail+0
scan_tail_limit
    ldx stream_ptr
    stx view_tail+2
    ldaa view_tail+2+1
    adda view_tail+0+1
    staa view_tail+4+1
    ldaa view_tail+2
    adca view_tail+0
    staa view_tail+4
scan_run_byte
    ldaa 0,x
    cmpa #9
    beq scan_run_done
    cmpa #10
    beq scan_run_done
    cmpa #13
    beq scan_run_done
    inx
    cpx view_tail+4
    bne scan_run_byte
scan_run_done
    stx stream_ptr
    stx view_tail+4
    clr view_tail+6
    clr view_tail+6+1
    ldaa view_tail+4+1
    suba view_tail+2+1
    staa view_tail+6+3
    ldaa view_tail+4
    sbca view_tail+2
    staa view_tail+6+2
    ldaa view_tail+6+2
    oraa view_tail+6+3
    bne *+5
    jmp scan_tail_ok
    ldx #stream_rem_2015
    jsr q_load
    ldx #view_tail+6
    jsr q_sub
    ldx #stream_rem_2015
    jsr q_store
    ldx #where
    jsr q_load
    ldx #view_tail+6
    jsr q_add
    ldx #where
    jsr q_store
    ldx #view_scan+2
    jsr q_load
    ldx #view_tail+6
    jsr q_add
    ldx #view_scan+2
    jsr q_store
    ldaa v_stream_l_1
    suba view_tail+6+3
    staa v_stream_l_1
    ldaa stream_left
    sbca view_tail+6+2
    staa stream_left
    ldaa #$ff
    staa poll_count
    jmp editor_poll
scan_tail_ok
    clra
scan_tail_return
    rts
editor_dispatch
    jmp block_dispatch
editor_native_dispatch
    ldaa last_key
    cmpa #$c1
    bne *+5
    jmp move_left
    cmpa #$c2
    bne *+5
    jmp move_right
    cmpa #$c4
    bne *+5
    jmp move_up
    cmpa #$c3
    bne *+5
    jmp move_down
    cmpa #$c5
    bne *+5
    jmp move_home
    cmpa #$c6
    bne *+5
    jmp move_end
    cmpa #$c7
    bne *+5
    jmp move_page_down
    cmpa #$c8
    bne *+5
    jmp move_page_up
    cmpa #$f5
    bne *+5
    jmp move_document_home
    cmpa #$f6
    bne *+5
    jmp move_document_end
    cmpa #$fa
    beq toggle_overwrite
    cmpa #$f9
    bne *+5
    jmp key_delete
    cmpa #127
    bne *+5
    jmp key_backspace
    cmpa #8
    bne *+5
    jmp key_backspace
    cmpa #$c0
    bne *+5
    jmp key_newline
    cmpa #13
    bne *+5
    jmp key_newline
    cmpa #$ed
    bne *+5
    jmp key_tab
    cmpa #$ca
    beq key_save
    cmpa #$d6
    beq key_save_as
    cmpa #$cf
    beq key_search
    cmpa #$db
    beq key_search_next
    cmpa #$1a
    beq key_undo
    cmpa #$19
    beq key_redo
    cmpa #$c9
    beq key_help
    cmpa #$d2
    bne *+5
    jmp key_exit
    cmpa #27
    bne *+5
    jmp key_exit
    cmpa #32
    bcc *+5
    jmp key_ignored
    cmpa #$c0
    bcc *+5
    jmp key_text
key_ignored
    clra
    jmp editor_finish
toggle_overwrite
    ldaa overwrite
    eora #1
    staa overwrite
    bra key_ignored
key_help
    ldx #help_text
    jsr message
    jmp editor_restore
key_save
    clr group_open
    jsr editor_save
    jmp editor_result_redraw
key_save_as
    clr group_open
    jsr editor_save_as
    jmp editor_result_redraw
key_search
    clr group_open
    jsr editor_search
    jmp editor_result_redraw
key_search_next
    clr group_open
    jsr editor_search_next
    jmp editor_result_redraw
key_undo
    jsr history_undo
    jmp editor_his_2705
key_redo
    jsr history_redo
    jmp editor_his_2705
editor_result_redraw
    tsta
    beq *+5
    jmp editor_error
    jmp editor_restore
editor_result_rebuild
    tsta
    beq *+5
    jmp editor_error
    jmp rebuild_cursor
move_right
    clr group_open
    clr desired_valid
    ldx #e_cursor
    jsr q_load
    ldx #where
    jsr q_store
    jsr doc_byte
    bcc *+5
    jmp key_ignored
    cmpa #13
    beq move_right_cr
    cmpa #10
    bne *+5
    jmp move_right_line
    cmpa #9
    beq move_right_tab
    ldx #where
    jsr q_load
    ldx #e_cursor
    jsr q_store
    ldx #e_column
    jsr q_load
    jsr q_inc
    ldx #e_column
    jsr q_store
    jmp move_finished
move_right_tab
    ldx #where
    jsr q_load
    ldx #e_cursor
    jsr q_store
    ldx #e_column
    jsr q_load
    ldaa v_q_3
    oraa #7
    staa v_q_3
    jsr q_inc
    ldx #e_column
    jsr q_store
    jmp move_finished
move_right_cr
    ldx #where
    jsr q_load
    ldx #nav_saved
    jsr q_store
    jsr doc_byte
    bcs move_right_cr_end
    cmpa #10
    bne *+5
    jmp move_right_line
move_right_cr_end
    ldx #nav_saved
    jsr q_load
    ldx #where
    jsr q_store
move_right_line
    ldx #where
    jsr q_load
    ldx #e_cursor
    jsr q_store
    clr e_column
    clr v_e_column_1
    clr v_e_column_2
    clr v_e_column_3
    inc cursor_row
    ldaa cursor_row
    cmpa body_rows
    bcs move_line_visible
    ldaa #1
    jsr line_pointer
    jsr q_load
    ldx #screen_top
    jsr q_store
    dec cursor_row
    jmp rebuild_cursor
move_line_visible
    ldx #horizontal
    jsr q_load
    jsr q_test
    bne *+5
    jmp key_ignored
    clr horizontal
    clr v_horizont_1
    clr v_horizont_2
    clr v_horizont_3
    jmp rebuild_cursor
move_left
    clr group_open
    clr desired_valid
    ldaa cursor_row
    jsr line_pointer
    jsr q_load
    ldx #nav_line
    jsr q_store
    ldx #e_cursor
    jsr q_cmp
    beq move_left_line
    ldx #e_cursor
    jsr q_load
    jsr q_dec
    ldx #e_cursor
    jsr q_store
    ldx #where
    jsr q_store
    jsr doc_byte
    bcc *+5
    jmp editor_error
    cmpa #9
    beq move_left_tab
    ldx #e_column
    jsr q_load
    jsr q_dec
    ldx #e_column
    jsr q_store
    jmp move_finished
move_left_tab
    jsr column_from_start
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
move_left_line
    ldx #e_cursor
    jsr q_load
    jsr q_test
    bne *+5
    jmp key_ignored
    ldx #nav_line
    jsr q_load
    ldx #nav_position
    jsr q_store
    jsr previous_line
    tsta
    beq *+5
    jmp editor_error
    ldx #nav_end
    jsr q_load
    ldx #e_cursor
    jsr q_store
    tst cursor_row
    beq move_left_scroll
    dec cursor_row
    jsr column_from_start
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
move_left_scroll
    ldx #nav_start
    jsr q_load
    ldx #screen_top
    jsr q_store
    jmp rebuild_cursor
move_home
    clr group_open
    clr desired_valid
    ldaa cursor_row
    jsr line_pointer
    jsr q_load
    ldx #e_cursor
    jsr q_store
    clr e_column
    clr v_e_column_1
    clr v_e_column_2
    clr v_e_column_3
    jmp move_finished
move_end
    clr group_open
    clr desired_valid
    ldaa cursor_row
    jsr end_pointer
    jsr q_load
    ldx #e_cursor
    jsr q_store
    jsr column_from_anchor
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
move_up
    jsr remember_column
    tst cursor_row
    beq move_up_scroll
    dec cursor_row
    jsr cursor_to_column
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
move_up_scroll
    ldaa #0
    jsr line_pointer
    jsr q_load
    jsr q_test
    bne *+5
    jmp key_ignored
    ldx #nav_position
    jsr q_store
    jsr previous_line
    tsta
    beq *+5
    jmp editor_error
    ldx #nav_start
    jsr q_load
    ldx #screen_top
    jsr q_store
    jsr build_view
    tsta
    beq *+5
    jmp editor_error
    clr cursor_row
    jsr cursor_to_column
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
move_down
    jsr remember_column
    ldaa cursor_row
    inca
    cmpa body_rows
    bcc move_down_scroll
    tab
    ldx #line_valid
    jsr add_b
    tst 0,x
    bne *+5
    jmp key_ignored
    inc cursor_row
    jsr cursor_to_column
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
move_down_scroll
    ldaa body_rows
    jsr line_pointer
    jsr q_load
    ldx #doc_size
    jsr q_cmp
    bcs *+5
    jmp key_ignored
    ldaa #1
    jsr line_pointer
    jsr q_load
    ldx #screen_top
    jsr q_store
    jsr build_view
    tsta
    beq *+5
    jmp editor_error
    ldaa body_rows
    deca
    staa cursor_row
    jsr cursor_to_column
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
remember_column
    clr group_open
    tst desired_valid
    bne remembered_column
    ldx #e_column
    jsr q_load
    ldx #desired_column
    jsr q_store
    inc desired_valid
remembered_column
    rts
move_document_home
    clr group_open
    clr desired_valid
    clr e_cursor
    clr v_e_cursor_1
    clr v_e_cursor_2
    clr v_e_cursor_3
    clr e_column
    clr v_e_column_1
    clr v_e_column_2
    clr v_e_column_3
    clr screen_top
    clr v_screen_t_1
    clr v_screen_t_2
    clr v_screen_t_3
    clr horizontal
    clr v_horizont_1
    clr v_horizont_2
    clr v_horizont_3
    jmp rebuild_cursor
move_document_end
    clr group_open
    clr desired_valid
    ldx #doc_size
    jsr q_load
    ldx #e_cursor
    jsr q_store
    ldx #doc_size
    jsr q_load
    ldx #nav_start
    jsr q_store
    jsr find_line_start
    tsta
    beq *+5
    jmp editor_error
    ldx #nav_start
    jsr q_load
    ldx #screen_top
    jsr q_store
    jmp rebuild_cursor
move_page_down
    jsr remember_column
    ldaa body_rows
    jsr line_pointer
    jsr q_load
    ldx #doc_size
    jsr q_cmp
    bcc move_document_end
    ldx #screen_top
    jsr q_store
    ldx #e_cursor
    jsr q_store
    jsr build_view
    tsta
    beq *+5
    jmp editor_error
    clr cursor_row
    jsr cursor_to_column
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
move_page_up
    jsr remember_column
    ldaa body_rows
    staa page_remaining
    ldx #screen_top
    jsr q_load
    ldx #nav_position
    jsr q_store
page_previous
    ldx #nav_position
    jsr q_load
    jsr q_test
    beq page_previous_done
    jsr previous_line
    tsta
    beq *+5
    jmp editor_error
    ldx #nav_start
    jsr q_load
    ldx #nav_position
    jsr q_store
    dec page_remaining
    bne page_previous
page_previous_done
    ldx #nav_position
    jsr q_load
    ldx #screen_top
    jsr q_store
    ldx #nav_position
    jsr q_load
    ldx #e_cursor
    jsr q_store
    jsr build_view
    tsta
    beq *+5
    jmp editor_error
    clr cursor_row
    jsr cursor_to_column
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
; Find a logical line start without a fixed-size line buffer.
find_line_start
    ldx #nav_start
    jsr q_load
    jsr q_test
    beq find_line_done
find_line_back
    ldx #nav_start
    jsr q_load
    jsr q_dec
    ldx #nav_probe
    jsr q_store
    ldx #where
    jsr q_store
    jsr doc_byte
    bcs find_line_return
    cmpa #13
    beq find_line_done
    cmpa #10
    beq find_line_done
    ldx #nav_probe
    jsr q_load
    ldx #nav_start
    jsr q_store
    jsr editor_poll
    tsta
    beq *+5
    jmp find_line_return
    ldx #nav_start
    jsr q_load
    jsr q_test
    bne find_line_back
find_line_done
    clra
find_line_return
    rts
previous_line
    ldx #nav_position
    jsr q_load
    jsr q_dec
    ldx #nav_end
    jsr q_store
    ldx #where
    jsr q_store
    jsr doc_byte
    bcs find_line_return
    cmpa #10
    bne previous_find
    ldx #nav_end
    jsr q_load
    jsr q_test
    beq previous_find
    jsr q_dec
    ldx #where
    jsr q_store
    jsr doc_byte
    bcs find_line_return
    cmpa #13
    bne previous_find
    ldx #nav_end
    jsr q_load
    jsr q_dec
    ldx #nav_end
    jsr q_store
previous_find
    ldx #nav_end
    jsr q_load
    ldx #nav_start
    jsr q_store
    jmp find_line_start
; Derive the column from the nearest known horizontal anchor when possible.
column_from_start
    clr nav_column
    clr v_nav_colu_1
    clr v_nav_colu_2
    clr v_nav_colu_3
    ldaa cursor_row
    jsr line_pointer
    jsr q_load
    ldx #where
    jsr q_store
    bra column_scan
column_from_anchor
    ldaa cursor_row
    jsr left_pointer
    jsr q_load
    ldx #e_cursor
    jsr q_cmp
    bhi column_from_start
    ldx #where
    jsr q_store
    ldaa cursor_row
    jsr left_colum_1c1a
    jsr q_load
    ldx #nav_column
    jsr q_store
column_scan
    jsr stream_init
    bcs column_done
column_character
    ldx #where
    jsr q_load
    ldx #e_cursor
    jsr q_cmp
    bcc column_done
    jsr stream_next
    bcs column_done
    cmpa #9
    bne column_one
    ldaa v_nav_colu_3
    oraa #7
    staa v_nav_colu_3
column_one
    ldx #nav_column
    jsr q_load
    jsr q_inc
    ldx #nav_column
    jsr q_store
    jsr editor_poll
    tsta
    beq *+5
    jmp find_line_return
    bra column_character
column_done
    ldx #nav_column
    jsr q_load
    ldx #e_column
    jsr q_store
    clra
    rts
cursor_to_column
    ldaa cursor_row
    jsr left_colum_1c1a
    jsr q_load
    ldx #desired_column
    jsr q_cmp
    bhi cursor_column_start
    ldx #nav_column
    jsr q_store
    ldaa cursor_row
    jsr left_pointer
    jsr q_load
    ldx #where
    jsr q_store
    bra cursor_column_stream
cursor_column_start
    clr nav_column
    clr v_nav_colu_1
    clr v_nav_colu_2
    clr v_nav_colu_3
    ldaa cursor_row
    jsr line_pointer
    jsr q_load
    ldx #where
    jsr q_store
cursor_column_stream
    jsr stream_init
    bcs cursor_column_set
cursor_column_read
    ldx #where
    jsr q_load
    ldx #nav_saved
    jsr q_store
    ldx #nav_column
    jsr q_load
    ldx #desired_column
    jsr q_cmp
    bcc cursor_column_set
    jsr stream_next
    bcs cursor_column_set
    cmpa #13
    beq cursor_column_before
    cmpa #10
    beq cursor_column_before
    cmpa #9
    bne cursor_column_one
    ldx #nav_column
    jsr q_load
    ldaa v_q_3
    oraa #7
    staa v_q_3
    bra cursor_column_advance
cursor_column_one
    ldx #nav_column
    jsr q_load
cursor_column_advance
    jsr q_inc
    ldx #desired_column
    jsr q_cmp
    bhi cursor_column_before
    ldx #nav_column
    jsr q_store
    bra cursor_column_read
cursor_column_before
    ldx #nav_saved
    jsr q_load
    ldx #where
    jsr q_store
cursor_column_set
    ldx #where
    jsr q_load
    ldx #e_cursor
    jsr q_store
    ldx #nav_column
    jsr q_load
    ldx #e_column
    jsr q_store
    clra
    rts
move_finished
    jsr ensure_horizontal
    tsta
    beq move_no_horizontal
    jsr horizontal_repaint
    jmp editor_finish
move_no_horizontal
    clra
    jmp editor_finish
ensure_horizontal
    ldx #e_column
    jsr q_load
    ldx #horizontal
    jsr q_cmp
    bcs horizontal_left
    ldx #horizontal
    jsr q_sub
    ldaa q
    oraa v_q_1
    oraa v_q_2
    bne horizontal_right
    ldaa v_q_3
    cmpa columns
    bcc horizontal_right
    clra
    rts
horizontal_right
    ldaa columns
    lsra
    jsr q_small
    ldx #half_columns
    jsr q_store
    ldx #e_column
    jsr q_load
    ldx #half_columns
    jsr q_sub
    bra horizontal_align
horizontal_left
    ldx #e_column
    jsr q_load
horizontal_align
    ldaa v_q_3
    anda #$f8
    staa v_q_3
    ldx #horizontal
    jsr q_store
    ldaa #1
    rts
rebuild_cursor
    jsr build_view
    tsta
    beq *+5
    jmp editor_error
    tst cursor_seen
    bne rebuild_horizontal
    ldx #e_cursor
    jsr q_load
    ldx #nav_start
    jsr q_store
    jsr find_line_start
    tsta
    beq *+5
    jmp editor_error
    ldx #nav_start
    jsr q_load
    ldx #screen_top
    jsr q_store
    jsr build_view
    tsta
    beq *+5
    jmp editor_error
rebuild_horizontal
    jsr ensure_horizontal
    tsta
    beq *+5
    jmp rebuild_cursor
    clra
    jmp editor_finish
; Simple character edits keep the cached line starts and repaint one row.
key_text
    clr change_lin_2598
    staa change_bytes
    ldaa #1
    staa change_add
    staa change_group
    clr change_delete
    ldx #e_cursor
    jsr q_load
    ldx #change_at
    jsr q_store
    tst overwrite
    beq text_change
    ldx #e_cursor
    jsr q_load
    ldx #where
    jsr q_store
    jsr doc_byte
    bcs text_change
    cmpa #13
    beq text_change
    cmpa #10
    beq text_change
    inc change_delete
text_change
    jsr editor_change
    tsta
    beq *+5
    jmp editor_error
    ldx #e_column
    jsr q_load
    jsr q_inc
    ldx #e_column
    jsr q_store
    jmp edit_one_line
key_tab
    clr change_lin_2598
    clr group_open
    clr desired_valid
    ldaa #9
    staa change_bytes
    ldaa #1
    staa change_add
    clr change_group
    clr change_delete
    ldx #e_cursor
    jsr q_load
    ldx #change_at
    jsr q_store
    jsr editor_change
    tsta
    beq *+5
    jmp editor_error
    ldx #e_column
    jsr q_load
    ldaa v_q_3
    oraa #7
    staa v_q_3
    jsr q_inc
    ldx #e_column
    jsr q_store
    jmp edit_one_line
key_newline
    ldaa #1
    staa change_lin_2598
    clr group_open
    clr desired_valid
    clr change_group
    clr change_delete
    ldaa eol_length
    staa change_add
    ldaa eol_bytes
    staa change_bytes
    ldaa v_eol_byte_1
    staa v_change_b_1
    ldx #e_cursor
    jsr q_load
    ldx #change_at
    jsr q_store
    jsr editor_change
    tsta
    beq *+5
    jmp editor_error
    clr horizontal
    clr v_horizont_1
    clr v_horizont_2
    clr v_horizont_3
    jmp rebuild_cursor
key_delete
    clr change_lin_2598
    clr group_open
    clr desired_valid
    clr change_group
    clr change_add
    ldx #e_cursor
    jsr q_load
    ldx #change_at
    jsr q_store
    ldx #e_cursor
    jsr q_load
    ldx #where
    jsr q_store
    jsr doc_byte
    bcc *+5
    jmp key_ignored
    staa deleted_char
    ldaa #1
    staa change_delete
    ldaa deleted_char
    cmpa #13
    beq delete_cr
    cmpa #10
    beq delete_line_change
    jsr editor_change
    tsta
    beq *+5
    jmp editor_error
    jmp edit_one_line
delete_cr
    jsr doc_byte
    bcs delete_line_change
    cmpa #10
    bne delete_line_change
    inc change_delete
delete_line_change
    ldaa #1
    staa change_lin_2598
    jsr editor_change
    jmp editor_result_rebuild
key_backspace
    clr change_lin_2598
    clr group_open
    clr desired_valid
    clr change_group
    clr change_add
    ldx #e_cursor
    jsr q_load
    jsr q_test
    bne *+5
    jmp key_ignored
    ldaa cursor_row
    jsr line_pointer
    jsr q_load
    ldx #e_cursor
    jsr q_cmp
    beq backspace_line
    ldx #e_cursor
    jsr q_load
    jsr q_dec
    ldx #change_at
    jsr q_store
    ldx #where
    jsr q_store
    jsr doc_byte
    bcc *+5
    jmp editor_error
    staa deleted_char
    ldaa #1
    staa change_delete
    jsr editor_change
    tsta
    beq *+5
    jmp editor_error
    ldaa deleted_char
    cmpa #9
    beq backspace_tab
    ldx #e_column
    jsr q_load
    jsr q_dec
    ldx #e_column
    jsr q_store
    jmp edit_one_line
backspace_tab
    jsr shift_metadata
    jsr column_from_start
    tsta
    beq *+5
    jmp editor_error
    jmp rebuild_cursor
backspace_line
    ldaa #1
    staa change_lin_2598
    ldx #e_cursor
    jsr q_load
    ldx #nav_position
    jsr q_store
    jsr previous_line
    tsta
    beq *+5
    jmp editor_error
    ldx #e_cursor
    jsr q_load
    ldx #nav_end
    jsr q_sub
    ldaa v_q_3
    staa change_delete
    ldx #nav_end
    jsr q_load
    ldx #change_at
    jsr q_store
    tst cursor_row
    bne backspace_join
    ldx #nav_start
    jsr q_load
    ldx #screen_top
    jsr q_store
backspace_join
    jsr editor_change
    jmp editor_result_rebuild
edit_one_line
    clr desired_valid
    jsr shift_metadata
    jsr ensure_horizontal
    tsta
    beq edit_same_horizontal
    jsr horizontal_repaint
    jmp editor_finish
edit_same_horizontal
    ldaa cursor_row
    staa render_row
    clr build_full
    jsr build_line
    tsta
    beq *+5
    jmp editor_error
    jsr paint_line
    clra
    jmp editor_finish
shift_metadata
    ldaa change_add
    suba change_delete
    staa v_edit_del_3
    ldab #0
    tsta
    bpl edit_delta_high
    comb
edit_delta_high
    stab edit_delta
    stab v_edit_del_1
    stab v_edit_del_2
shift_metadata_ready
    ldaa cursor_row
    staa metadata_row
shift_line_end
    ldx #edit_delta
    jsr q_load
    ldaa metadata_row
    jsr end_pointer
    jsr q_add
    ldaa metadata_row
    jsr end_pointer
    jsr q_store
    inc metadata_row
    ldaa metadata_row
    cmpa body_rows
    bcs shift_line_end
    ldaa cursor_row
    inca
    staa metadata_row
shift_line_start
    ldx #edit_delta
    jsr q_load
    ldaa metadata_row
    jsr line_pointer
    jsr q_add
    ldaa metadata_row
    jsr line_pointer
    jsr q_store
    ldaa metadata_row
    cmpa body_rows
    beq shift_metadata_done
    ldx #edit_delta
    jsr q_load
    ldaa metadata_row
    jsr left_pointer
    jsr q_add
    ldaa metadata_row
    jsr left_pointer
    jsr q_store
    inc metadata_row
    bra shift_line_start
shift_metadata_done
    rts
; Long scans check the keyboard once per 256 bytes, preserving the stream.
editor_poll
    inc poll_count
    bne editor_poll_ready
    int $10
    cmpa #$ff
    beq editor_poll_ready
    int $11
    cmpa #27
    beq editor_poll_cancel
    cmpa #3
    beq editor_poll_cancel
editor_poll_ready
    clra
    rts
editor_poll_cancel
    ldaa #$ff
    rts
key_exit
    clr group_open
    tst modified
    bne exit_dialog
    jmp editor_close
exit_dialog
    ldx #exit_title
    jsr window_open
    ldx #exit_message
    ldaa #8
    jsr window_wrap
    ldaa #2
    staa exit_focus
exit_buttons
    clr exit_draw
exit_draw_button
    ldaa #$07
    ldab exit_draw
    cmpb exit_focus
    bne exit_draw_ink
    ldaa #$03
exit_draw_ink
    jsr colour
    ldaa columns
    suba #27
    lsra
    ldab exit_draw
exit_draw_x
    tstb
    beq exit_draw_position
    adda #9
    decb
    bra exit_draw_x
exit_draw_position
    staa ui_x
    ldaa #16
    staa ui_y
    jsr position
    ldaa #9
    staa remaining
    ldaa #' '
    ldab exit_draw
    cmpb exit_focus
    bne exit_draw_mark
    ldaa #'>'
exit_draw_mark
    jsr put_field
    ldab exit_draw
    aslb
    ldx #exit_butto_56b1
    jsr add_b
    ldx 0,x
    jsr field
    inc exit_draw
    ldaa exit_draw
    cmpa #3
    bcs exit_draw_button

exit_key
    int $11
    cmpa #27
    beq exit_cancel
    cmpa #3
    beq exit_cancel
    cmpa #'y'
    beq exit_save
    cmpa #'s'
    beq exit_save
    cmpa #'n'
    beq exit_discard
    cmpa #'d'
    beq exit_discard
    cmpa #$c0
    beq exit_enter
    cmpa #$c1
    beq exit_left
    cmpa #$c2
    beq exit_right
    cmpa #$ed
    beq exit_right
    bra exit_key
exit_enter
    ldaa exit_focus
    beq exit_save
    deca
    beq exit_discard
exit_cancel
    jmp editor_restore
exit_discard
    jmp editor_close
exit_save
    jsr editor_save
    tsta
    beq *+5
    jmp editor_error
    jmp editor_close
exit_left
    ldaa exit_focus
    bne exit_left_step
    ldaa #3
exit_left_step
    deca
    staa exit_focus
    jmp exit_buttons
exit_right
    inc exit_focus
    ldaa exit_focus
    cmpa #3
    bcc *+5
    jmp exit_buttons
    clr exit_focus
    jmp exit_buttons
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
    jsr left_colum_1c1a
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
    jsr left_colum_1c1a
    jsr q_store
    clra
    rts
; KMP search streams arbitrary-length documents, preserving the last pattern.
; Its prefix table reuses the line-construction buffer while the modal owns UI.
editor_search
    ldx #search_text
    stx src
    ldx #input
    stx dst
    jsr copy_z
    ldx #search_title
    jsr dialog
    bcc *+5
    jmp search_cancel
    tst input
    bne *+5
    jmp search_cancel
    ldx #input
    stx src
    ldx #search_text
    stx dst
    jsr copy_z
    clr search_skip
    bra search_begin
editor_search_next
    tst search_text
    beq editor_search
    ldaa #1
    staa search_skip
search_begin
    clr search_length
    ldx #search_text
search_count
    tst 0,x
    beq search_prefix
    inx
    inc search_length
    bra search_count
search_prefix
    clr search_pre_0813
    clr search_j
    ldaa #1
    staa search_i
search_prefix_loop
    ldaa search_i
    cmpa search_length
    bcc search_open
    tab
    ldx #search_text
    jsr add_b
    ldaa 0,x
    staa search_char
search_prefix_compare
    ldab search_j
    ldx #search_text
    jsr add_b
    ldaa 0,x
    cmpa search_char
    beq search_prefix_match
    tst search_j
    beq search_prefix_store
    ldab search_j
    decb
    ldx #search_pre_0813
    jsr add_b
    ldaa 0,x
    staa search_j
    bra search_prefix_compare
search_prefix_match
    inc search_j
search_prefix_store
    ldab search_i
    ldx #search_pre_0813
    jsr add_b
    ldaa search_j
    staa 0,x
    inc search_i
    bra search_prefix_loop
search_open
    ldx #search_title
    jsr window_open
    ldx #search_text
    ldaa #8
    jsr window_line
    ldx #cancel_sav_fb1e
    ldaa #16
    jsr window_line
    ldx #e_cursor
    jsr q_load
    ldx #where
    jsr q_store
    tst search_skip
    beq search_position
    ldx #where
    jsr q_load
    ldx #doc_size
    jsr q_cmp
    bcc search_position
    jsr q_inc
    ldx #where
    jsr q_store
search_position
    ldx #where
    jsr q_load
    ldx #search_start
    jsr q_store
    clr search_wrapped
search_stream
    clr search_j
    jsr stream_init
    bcc *+5
    jmp search_end
search_byte
    tst search_wrapped
    beq search_read
    ldx #where
    jsr q_load
    ldx #search_start
    jsr q_cmp
    bcs *+5
    jmp search_not_found
search_read
    jsr stream_next
    bcc *+5
    jmp search_end
    staa search_char
search_compare
    ldab search_j
    ldx #search_text
    jsr add_b
    ldaa 0,x
    cmpa search_char
    beq search_match
    tst search_j
    beq search_advance
    ldab search_j
    decb
    ldx #search_pre_0813
    jsr add_b
    ldaa 0,x
    staa search_j
    bra search_compare
search_match
    inc search_j
    ldaa search_j
    cmpa search_length
    beq search_found
search_advance
    jsr editor_poll
    tsta
    beq *+5
    jmp search_return
    ldaa v_where_2
    anda #15
    oraa v_where_3
    bne search_byte
    ldx #where
    jsr q_load
    ldx #number
    jsr q_store
    jsr decimal_number
    ldx #number_text
    ldaa #11
    jsr window_line
    jmp search_byte
search_end
    tsta
    beq *+5
    jmp search_return
    tst search_wrapped
    bne search_not_found
    inc search_wrapped
    clr where
    clr v_where_1
    clr v_where_2
    clr v_where_3
    jmp search_stream
search_found
    ldaa search_length
    jsr q_small
    ldx #search_amount
    jsr q_store
    ldx #where
    jsr q_load
    ldx #search_amount
    jsr q_sub
    ldx #e_cursor
    jsr q_store
    ldx #nav_start
    jsr q_store
    jsr find_line_start
    tsta
    beq *+5
    jmp search_return
    ldx #nav_start
    jsr q_load
    ldx #screen_top
    jsr q_store
    clr horizontal
    clr v_horizont_1
    clr v_horizont_2
    clr v_horizont_3
    jsr build_view
    tsta
    beq *+5
    jmp search_return
    jsr ensure_horizontal
    clra
search_return
    rts
search_not_found
    ldx #not_found_text
    jsr message
    clra
    rts
search_cancel
    ldaa #$ff
    rts
    section
view_scan ds 31
view_anchor ds 18
view_tail ds 10
    ends
column_fro_c274 equ column_from_anchor
editor_nat_5e73 equ editor_native_dispatch
editor_res_c671 equ editor_result_redraw
ensure_hor_027b equ ensure_horizontal
horizontal_beef equ horizontal_repaint
move_docum_6b40 equ move_document_end
shift_meta_3672 equ shift_metadata_ready
v_view_sc_1313 equ view_scan+2+2
v_view_sc_402d equ view_scan+2+3
v_view_sc_56a1 equ view_scan+2+1
v_view_sca_0 equ view_scan+0
v_view_sca_1 equ view_scan+1
v_view_sca_10 equ view_scan+10
v_view_sca_14 equ view_scan+14
v_view_sca_18 equ view_scan+18
v_view_sca_19 equ view_scan+19
v_view_sca_2 equ view_scan+2
v_view_sca_20 equ view_scan+20
v_view_sca_24 equ view_scan+24
v_view_sca_25 equ view_scan+25
v_view_sca_27 equ view_scan+27
v_view_sca_29 equ view_scan+29
v_view_sca_30 equ view_scan+30
v_view_sca_6 equ view_scan+6
    end
