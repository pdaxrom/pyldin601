editor_dispatch
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
    jmp editor_history_result
key_redo
    jsr history_redo
    jmp editor_history_result
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
    ldaa e_cursor
    staa where
    ldaa e_cursor+1
    staa where+1
    ldaa e_cursor+2
    staa where+2
    ldaa e_cursor+3
    staa where+3
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
    ldaa where
    staa e_cursor
    ldaa where+1
    staa e_cursor+1
    ldaa where+2
    staa e_cursor+2
    ldaa where+3
    staa e_cursor+3
    ldx #e_column
    jsr q_load
    jsr q_inc
    ldx #e_column
    jsr q_store
    jmp move_finished
move_right_tab
    ldaa where
    staa e_cursor
    ldaa where+1
    staa e_cursor+1
    ldaa where+2
    staa e_cursor+2
    ldaa where+3
    staa e_cursor+3
    ldx #e_column
    jsr q_load
    ldaa q+3
    oraa #7
    staa q+3
    jsr q_inc
    ldx #e_column
    jsr q_store
    jmp move_finished
move_right_cr
    ldaa where
    staa nav_saved
    ldaa where+1
    staa nav_saved+1
    ldaa where+2
    staa nav_saved+2
    ldaa where+3
    staa nav_saved+3
    jsr doc_byte
    bcs move_right_cr_end
    cmpa #10
    bne *+5
    jmp move_right_line
move_right_cr_end
    ldaa nav_saved
    staa where
    ldaa nav_saved+1
    staa where+1
    ldaa nav_saved+2
    staa where+2
    ldaa nav_saved+3
    staa where+3
move_right_line
    ldaa where
    staa e_cursor
    ldaa where+1
    staa e_cursor+1
    ldaa where+2
    staa e_cursor+2
    ldaa where+3
    staa e_cursor+3
    clr e_column
    clr e_column+1
    clr e_column+2
    clr e_column+3
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
    clr horizontal+1
    clr horizontal+2
    clr horizontal+3
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
    ldaa nav_line
    staa nav_position
    ldaa nav_line+1
    staa nav_position+1
    ldaa nav_line+2
    staa nav_position+2
    ldaa nav_line+3
    staa nav_position+3
    jsr previous_line
    tsta
    beq *+5
    jmp editor_error
    ldaa nav_end
    staa e_cursor
    ldaa nav_end+1
    staa e_cursor+1
    ldaa nav_end+2
    staa e_cursor+2
    ldaa nav_end+3
    staa e_cursor+3
    tst cursor_row
    beq move_left_scroll
    dec cursor_row
    jsr column_from_start
    tsta
    beq *+5
    jmp editor_error
    jmp move_finished
move_left_scroll
    ldaa nav_start
    staa screen_top
    ldaa nav_start+1
    staa screen_top+1
    ldaa nav_start+2
    staa screen_top+2
    ldaa nav_start+3
    staa screen_top+3
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
    clr e_column+1
    clr e_column+2
    clr e_column+3
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
    ldaa nav_start
    staa screen_top
    ldaa nav_start+1
    staa screen_top+1
    ldaa nav_start+2
    staa screen_top+2
    ldaa nav_start+3
    staa screen_top+3
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
    ldaa e_column
    staa desired_column
    ldaa e_column+1
    staa desired_column+1
    ldaa e_column+2
    staa desired_column+2
    ldaa e_column+3
    staa desired_column+3
    inc desired_valid
remembered_column
    rts
move_document_home
    clr group_open
    clr desired_valid
    clr e_cursor
    clr e_cursor+1
    clr e_cursor+2
    clr e_cursor+3
    clr e_column
    clr e_column+1
    clr e_column+2
    clr e_column+3
    clr screen_top
    clr screen_top+1
    clr screen_top+2
    clr screen_top+3
    clr horizontal
    clr horizontal+1
    clr horizontal+2
    clr horizontal+3
    jmp rebuild_cursor
move_document_end
    clr group_open
    clr desired_valid
    ldaa doc_size
    staa e_cursor
    ldaa doc_size+1
    staa e_cursor+1
    ldaa doc_size+2
    staa e_cursor+2
    ldaa doc_size+3
    staa e_cursor+3
    ldaa doc_size
    staa nav_start
    ldaa doc_size+1
    staa nav_start+1
    ldaa doc_size+2
    staa nav_start+2
    ldaa doc_size+3
    staa nav_start+3
    jsr find_line_start
    tsta
    beq *+5
    jmp editor_error
    ldaa nav_start
    staa screen_top
    ldaa nav_start+1
    staa screen_top+1
    ldaa nav_start+2
    staa screen_top+2
    ldaa nav_start+3
    staa screen_top+3
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
    ldaa screen_top
    staa nav_position
    ldaa screen_top+1
    staa nav_position+1
    ldaa screen_top+2
    staa nav_position+2
    ldaa screen_top+3
    staa nav_position+3
page_previous
    ldx #nav_position
    jsr q_load
    jsr q_test
    beq page_previous_done
    jsr previous_line
    tsta
    beq *+5
    jmp editor_error
    ldaa nav_start
    staa nav_position
    ldaa nav_start+1
    staa nav_position+1
    ldaa nav_start+2
    staa nav_position+2
    ldaa nav_start+3
    staa nav_position+3
    dec page_remaining
    bne page_previous
page_previous_done
    ldaa nav_position
    staa screen_top
    ldaa nav_position+1
    staa screen_top+1
    ldaa nav_position+2
    staa screen_top+2
    ldaa nav_position+3
    staa screen_top+3
    ldaa nav_position
    staa e_cursor
    ldaa nav_position+1
    staa e_cursor+1
    ldaa nav_position+2
    staa e_cursor+2
    ldaa nav_position+3
    staa e_cursor+3
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
    ldaa nav_probe
    staa nav_start
    ldaa nav_probe+1
    staa nav_start+1
    ldaa nav_probe+2
    staa nav_start+2
    ldaa nav_probe+3
    staa nav_start+3
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
    ldaa nav_end
    staa nav_start
    ldaa nav_end+1
    staa nav_start+1
    ldaa nav_end+2
    staa nav_start+2
    ldaa nav_end+3
    staa nav_start+3
    jmp find_line_start
; Derive the column from the nearest known horizontal anchor when possible.
column_from_start
    clr nav_column
    clr nav_column+1
    clr nav_column+2
    clr nav_column+3
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
    jsr left_column_pointer
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
    ldaa nav_column+3
    oraa #7
    staa nav_column+3
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
    ldaa nav_column
    staa e_column
    ldaa nav_column+1
    staa e_column+1
    ldaa nav_column+2
    staa e_column+2
    ldaa nav_column+3
    staa e_column+3
    clra
    rts
cursor_to_column
    ldaa cursor_row
    jsr left_column_pointer
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
    clr nav_column+1
    clr nav_column+2
    clr nav_column+3
    ldaa cursor_row
    jsr line_pointer
    jsr q_load
    ldx #where
    jsr q_store
cursor_column_stream
    jsr stream_init
    bcs cursor_column_set
cursor_column_read
    ldaa where
    staa nav_saved
    ldaa where+1
    staa nav_saved+1
    ldaa where+2
    staa nav_saved+2
    ldaa where+3
    staa nav_saved+3
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
    ldaa q+3
    oraa #7
    staa q+3
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
    ldaa nav_saved
    staa where
    ldaa nav_saved+1
    staa where+1
    ldaa nav_saved+2
    staa where+2
    ldaa nav_saved+3
    staa where+3
cursor_column_set
    ldaa where
    staa e_cursor
    ldaa where+1
    staa e_cursor+1
    ldaa where+2
    staa e_cursor+2
    ldaa where+3
    staa e_cursor+3
    ldaa nav_column
    staa e_column
    ldaa nav_column+1
    staa e_column+1
    ldaa nav_column+2
    staa e_column+2
    ldaa nav_column+3
    staa e_column+3
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
    oraa q+1
    oraa q+2
    bne horizontal_right
    ldaa q+3
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
    ldaa q+3
    anda #$f8
    staa q+3
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
    ldaa e_cursor
    staa nav_start
    ldaa e_cursor+1
    staa nav_start+1
    ldaa e_cursor+2
    staa nav_start+2
    ldaa e_cursor+3
    staa nav_start+3
    jsr find_line_start
    tsta
    beq *+5
    jmp editor_error
    ldaa nav_start
    staa screen_top
    ldaa nav_start+1
    staa screen_top+1
    ldaa nav_start+2
    staa screen_top+2
    ldaa nav_start+3
    staa screen_top+3
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
    clr change_linebreak
    staa change_bytes
    ldaa #1
    staa change_add
    staa change_group
    clr change_delete
    ldaa e_cursor
    staa change_at
    ldaa e_cursor+1
    staa change_at+1
    ldaa e_cursor+2
    staa change_at+2
    ldaa e_cursor+3
    staa change_at+3
    tst overwrite
    beq text_change
    ldaa e_cursor
    staa where
    ldaa e_cursor+1
    staa where+1
    ldaa e_cursor+2
    staa where+2
    ldaa e_cursor+3
    staa where+3
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
    clr change_linebreak
    clr group_open
    clr desired_valid
    ldaa #9
    staa change_bytes
    ldaa #1
    staa change_add
    clr change_group
    clr change_delete
    ldaa e_cursor
    staa change_at
    ldaa e_cursor+1
    staa change_at+1
    ldaa e_cursor+2
    staa change_at+2
    ldaa e_cursor+3
    staa change_at+3
    jsr editor_change
    tsta
    beq *+5
    jmp editor_error
    ldx #e_column
    jsr q_load
    ldaa q+3
    oraa #7
    staa q+3
    jsr q_inc
    ldx #e_column
    jsr q_store
    jmp edit_one_line
key_newline
    ldaa #1
    staa change_linebreak
    clr group_open
    clr desired_valid
    clr change_group
    clr change_delete
    ldaa eol_length
    staa change_add
    ldaa eol_bytes
    staa change_bytes
    ldaa eol_bytes+1
    staa change_bytes+1
    ldaa e_cursor
    staa change_at
    ldaa e_cursor+1
    staa change_at+1
    ldaa e_cursor+2
    staa change_at+2
    ldaa e_cursor+3
    staa change_at+3
    jsr editor_change
    tsta
    beq *+5
    jmp editor_error
    clr horizontal
    clr horizontal+1
    clr horizontal+2
    clr horizontal+3
    jmp rebuild_cursor
key_delete
    clr change_linebreak
    clr group_open
    clr desired_valid
    clr change_group
    clr change_add
    ldaa e_cursor
    staa change_at
    ldaa e_cursor+1
    staa change_at+1
    ldaa e_cursor+2
    staa change_at+2
    ldaa e_cursor+3
    staa change_at+3
    ldaa e_cursor
    staa where
    ldaa e_cursor+1
    staa where+1
    ldaa e_cursor+2
    staa where+2
    ldaa e_cursor+3
    staa where+3
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
    staa change_linebreak
    jsr editor_change
    jmp editor_result_rebuild
key_backspace
    clr change_linebreak
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
    staa change_linebreak
    ldaa e_cursor
    staa nav_position
    ldaa e_cursor+1
    staa nav_position+1
    ldaa e_cursor+2
    staa nav_position+2
    ldaa e_cursor+3
    staa nav_position+3
    jsr previous_line
    tsta
    beq *+5
    jmp editor_error
    ldx #e_cursor
    jsr q_load
    ldx #nav_end
    jsr q_sub
    ldaa q+3
    staa change_delete
    ldaa nav_end
    staa change_at
    ldaa nav_end+1
    staa change_at+1
    ldaa nav_end+2
    staa change_at+2
    ldaa nav_end+3
    staa change_at+3
    tst cursor_row
    bne backspace_join
    ldaa nav_start
    staa screen_top
    ldaa nav_start+1
    staa screen_top+1
    ldaa nav_start+2
    staa screen_top+2
    ldaa nav_start+3
    staa screen_top+3
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
    staa edit_delta+3
    ldab #0
    tsta
    bpl edit_delta_high
    comb
edit_delta_high
    stab edit_delta
    stab edit_delta+1
    stab edit_delta+2
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
    ldx #exit_button_table
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
