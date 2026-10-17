; NCMFILE: File operations and text viewer.
    include NCABI.INC
    include NCBOX.INC
    public file_action
    public make_directory
    public path_length
    public stat_path
    public viewer
    extern mouse_wait
    extern mouse_cancel
    extern progress_mode
    extern action_index
    extern action_record
    extern active
    extern add_b
    extern backup_active
    extern backup_path
    extern backup_tail
    extern backup_tries
    extern cancelled
    extern caret_hide
    extern choose_panel
    extern colour
    extern columns
    extern confirm
    extern copy_n
    extern copy_prompt
    extern copy_z
    extern delete_prompt
    extern dialog
    extern dst
    extern end_z
    extern entry_pointer
    extern error
    extern existing_target
    extern file_attributes
    extern file_stamp
    extern frame
    extern full_table
    extern group_marked
    extern input
    extern image_type
    extern image_request
    extern io_buffer
    extern io_error
    extern io_table
    extern line_text
    extern mkdir_pref_9e0e
    extern mkdir_prompt
    extern move_prompt
    extern name_record
    extern open_table
    extern operation
    extern overwrite__e43c
    extern padding
    extern pathptr
    extern pcount
    extern pcur
    extern position
    extern progress_a_cc75
    extern progress_cells
    extern progress_finish
    extern progress_items
    extern progress_start
    extern progress_update
    extern progress_v_0160
    extern put
    extern record_name
    extern redraw
    extern refresh
    extern remaining
    extern rename_call
    extern rename_source
    extern rename_table
    extern rename_target
    extern search_path
    extern selected
    extern selected_path
    extern set_workin_d418
    extern skipped
    extern source_handle
    extern source_open
    extern source_path
    extern src
    extern stat_entry
    extern stat_find
    extern stat_table
    extern target_handle
    extern target_open
    extern target_path
    extern temp_digits
    extern temp_name
    extern temp_path
    extern temp_tail
    extern temp_tries
    extern ui_x
    extern ui_y
    extern v_full_tab_2
    extern v_io_table_2
    extern v_open_tab_2
    extern v_rename_c_2
    extern v_rename_t_2
    extern v_stat_ent_11
    extern v_stat_tab_2
    extern v_stat_tab_4
    extern v_view_his_4
    extern v_view_pos_1
    extern v_view_pos_2
    extern v_view_pos_3
    extern v_walk_tab_2
    extern v_walk_tab_4
    extern view_eof
    extern view_handle
    extern view_history
    extern view_left
    extern view_page
    extern view_position
    extern view_ptr
    extern viewer_keys
    extern walk_depth
    extern walk_frames
    extern walk_table
    extern wildcard

; All filesystem access uses UniDOS; no direct FAT or SD writes.
make_directory
    clr input
    ldx #mkdir_prompt
    jsr dialog
    bcs mkdir_done
    tst input
    beq mkdir_done
    ldaa active
    jsr choose_panel
    ldx pathptr
    jsr path_length
    stab mkdir_pref_9e0e
    ldx #input
    jsr path_length
    bcs mkdir_invalid
    addb mkdir_pref_9e0e
    cmpb #64
    bcc mkdir_invalid
    ldx pathptr
    stx src
    ldx #source_path
    stx dst
    jsr copy_z
    ldx #input
    stx src
    jsr copy_z
    ldx #source_path
    int $48
    tsta
    beq mkdir_refresh
    jsr error
    bra mkdir_refresh
mkdir_invalid
    ldaa #19
    jsr error
mkdir_refresh
    jmp refresh
mkdir_done
    jmp redraw
file_action
    staa operation
    ldaa active
    jsr choose_panel
    ; Relative destinations and child resources follow the active panel.
    jsr set_workin_d418
    tsta
    beq action_directory_ready
    jsr error
    jmp redraw
action_directory_ready
    ; Never operate on the synthetic parent record.
    jsr selected
    ldaa 0,x
    cmpa #'.'
    bne action_prompt
    jmp redraw
action_prompt
    ldaa operation
    cmpa #3
    bne action_destination
    ldx #delete_prompt
    jsr confirm
    anda #$df
    cmpa #'Y'
    beq action_begin
    jmp redraw
action_destination
    ldaa active
    eora #1
    jsr choose_panel
    ldx pathptr
    stx src
    ldx #input
    stx dst
    jsr copy_z
    ldx #copy_prompt
    ldaa operation
    cmpa #1
    beq action_ask
    ldx #move_prompt
action_ask
    jsr dialog
    bcc action_destination_ready
    jmp redraw
action_destination_ready
    tst input
    bne action_begin
    jmp redraw
action_begin
    ldaa active
    jsr choose_panel
    clr action_index
    clr group_marked
    clr cancelled
    clr walk_depth
    clr progress_v_0160
    clr progress_cells
    ldx #progress_items
    ldab #4
action_zero_progress
    clr 0,x
    inx
    decb
    bne action_zero_progress
    ; Decide group once. A selected group can contain files and directories.
action_mark_scan
    ldaa action_index
    cmpa pcount
    bcc action_mark_done
    jsr entry_pointer
    tst 12,x
    beq action_mark_next
    inc group_marked
action_mark_next
    inc action_index
    bra action_mark_scan
action_mark_done
    clr action_index
action_next
    ldaa active
    jsr choose_panel
    ldaa action_index
    cmpa pcount
    bcs action_get
    jmp action_finished
action_get
    jsr entry_pointer
    tst group_marked
    beq action_single
    tst 12,x
    bne *+5
    jmp action_advance
    bra action_chosen
action_single
    ldaa action_index
    cmpa pcur
    beq *+5
    jmp action_advance
action_chosen
    ldaa 0,x
    cmpa #'.'
    bne *+5
    jmp action_advance
    stx action_record
    ldx pathptr
    stx src
    ldx #source_path
    stx dst
    jsr copy_z
    ldx action_record
    jsr record_name
    ldx #input
    stx full_table
    ldx #target_path
    stx v_full_tab_2
    ldx #full_table
    int $3f
    tsta
    beq action_full_target
    jmp action_error
action_full_target
    ldaa operation
    cmpa #3
    beq action_walk
    ; Existing directory or trailing slash -> append selected filename.
    ldx #target_path
    jsr stat_path
    tsta
    bne action_target_tail
    bitb #16
    bne action_target_directory
action_target_tail
    ldx #target_path
    jsr end_z
    dex
    ldaa 0,x
    cmpa #'\'
    bne action_walk
action_target_directory
    ldx #target_path
    jsr end_z
    dex
    ldaa 0,x
    inx
    cmpa #'\'
    beq action_target_name
    ldaa #'\'
    staa 0,x
    inx
action_target_name
    stx dst
    ldx action_record
    jsr record_name
action_walk
    jsr validate_paths
    tsta
    bne action_error
    jsr walk
    tsta
    bne action_error
    bra action_advance
action_error
    cmpa #$ff
    beq action_finished
    jsr error
    bra action_finished
action_advance
    inc action_index
    jmp action_next
action_finished
    jmp refresh
; Reject long paths, same source/destination and copying a directory inside itself.
validate_paths
    ldx #source_path
    jsr path_length
    bcs invalid_path
    ldaa operation
    cmpa #3
    beq paths_valid
    ldx #target_path
    jsr path_length
    bcs invalid_path
    ldx #source_path
    stx src
    ldx #target_path
    stx dst
validate_prefix
    ldx src
    ldaa 0,x
    beq validate_end
    inx
    stx src
    ldx dst
    ldab 0,x
    inx
    stx dst
    jsr upper_pair
    cba
    beq validate_prefix
    bra paths_valid
validate_end
    ldx dst
    ldaa 0,x
    beq path_conflict
    cmpa #'\'
    beq path_conflict
paths_valid
    clra
    rts
path_conflict
    ldaa #70
    rts
invalid_path
    ldaa #19
    rts
upper_pair
    cmpa #'a'
    bcs upper_b
    cmpa #'z'
    bhi upper_b
    anda #$df
upper_b
    cmpb #'a'
    bcs upper_done
    cmpb #'z'
    bhi upper_done
    andb #$df
upper_done
    rts
path_length
    clrb
path_length_loop
    tst 0,x
    beq length_done
    inx
    incb
    cmpb #64
    bcs path_length_loop
    sec
    rts
length_done
    clc
    rts
; Each recursive directory owns a find table and entry, independent of the
; caller and both panel caches. Maximum depth is also bounded by DOS paths.
walk
    jsr poll_cancel
    bcc walk_continue
    ldaa #$ff
    rts
walk_continue
    ldaa walk_depth
    cmpa #24
    bcs walk_depth_ok
    ldaa #19
    rts
walk_depth_ok
    jsr frame_pointer
    stx frame
    ldx #source_path
    jsr path_length
    bcc walk_src_length
    ldaa #19
    rts
walk_src_length
    ldx frame
    stab 0,x
    ldx #target_path
    jsr path_length
    bcc walk_dst_length
    ldaa #19
    rts
walk_dst_length
    ldx frame
    stab 1,x
    ldx #source_path
    jsr stat_path
    tsta
    beq walk_attr
    rts
walk_attr
    ldx frame
    stab 2,x
    bitb #16
    bne walk_directory
    jsr copy_file
    rts
walk_directory
    jsr progress_a_cc75
    ldaa operation
    cmpa #3
    beq walk_enumerate
    ldx #target_path
    jsr stat_path
    tsta
    bne walk_make_target
    bitb #16
    bne walk_enumerate
    ldaa #29
    rts
walk_make_target
    ldx #target_path
    int $48
    tsta
    beq walk_enumerate
    cmpa #21
    beq walk_enumerate
    rts
walk_enumerate
    ; Construct wildcard without changing the permanent source path.
    ldx #source_path
    stx src
    ldx #search_path
    stx dst
    jsr copy_z
    ldx dst
    ldaa #'\'
    staa 0,x
    inx
    stx dst
    ldx #wildcard
    stx src
    jsr copy_z
    jsr walk_find_table
    clra
    ldab #8
    ldx #walk_table
    int $42
walk_item
    tsta
    beq walk_have_item
    cmpa #11
    bne *+5
    jmp walk_directory_done
    rts
walk_have_item
    ldx frame
    ldab #23
    jsr add_b
    ldaa 0,x
    cmpa #'.'
    beq walk_find_next
    stx name_record
    ; Paths are limited before appending an 8.3 component.
    ldx #source_path
    jsr end_z
    ldaa #'\'
    staa 0,x
    inx
    stx dst
    ldx name_record
    jsr record_name
    ldaa operation
    cmpa #3
    beq walk_child
    ldx frame
    ldab #23
    jsr add_b
    stx name_record
    ldx #target_path
    jsr end_z
    ldaa #'\'
    staa 0,x
    inx
    stx dst
    ldx name_record
    jsr record_name
walk_child
    inc walk_depth
    jsr walk
    psha
    dec walk_depth
    jsr frame_pointer
    stx frame
    ldab 0,x
    ldx #source_path
    jsr add_b
    clr 0,x
    ldx frame
    ldab 1,x
    ldx #target_path
    jsr add_b
    clr 0,x
    pula
    tsta
    bne walk_return
walk_find_next
    jsr walk_find_table
    ldx #walk_table
    int $43
    jmp walk_item
walk_directory_done
    jsr progress_a_cc75
    ldaa operation
    cmpa #1
    beq walk_success
    ldx #source_path
    int $49
    tsta
    bne walk_return
    bra walk_success
walk_return
    rts
walk_success
    jsr progress_finish
    clra
    rts
walk_find_table
    ldx frame
    ldab #4
    jsr add_b
    stx walk_table
    ldx frame
    ldab #23
    jsr add_b
    stx v_walk_tab_2
    ldx #search_path
    stx v_walk_tab_4
    rts
frame_pointer
    ldx #walk_frames
    ldaa walk_depth
frame_loop
    tsta
    beq frame_done
    ldab #56
    jsr add_b
    deca
    bra frame_loop
frame_done
    rts
poll_cancel
    ldaa progress_mode
    jsr mouse_cancel
    cmpa #3
    beq copy_cancelled
    cmpa #27
    bne not_cancelled
copy_cancelled
    sec
    rts
not_cancelled
    clc
    rts
copy_file
    jsr progress_a_cc75
    ldaa operation
    cmpa #3
    bne copy_open
    ldx #source_path
    int $4f
    tsta
    bne copy_delete_return
    jsr progress_finish
    clra
copy_delete_return
    rts
copy_open
    ldx frame
    ldaa 2,x
    anda #$27
    staa file_attributes
    clr backup_active
    clr source_open
    clr target_open
    clr existing_target
    clr skipped
    ldx #target_path
    jsr stat_path
    tsta
    bne copy_create_temp
    ldx #overwrite__e43c
    jsr confirm
    clr progress_v_0160
    anda #$df
    cmpa #'Y'
    beq copy_overwrite
    ldaa #1
    staa skipped
    clra
    rts
copy_overwrite
    inc existing_target
copy_create_temp
    ldaa operation
    cmpa #2
    bne copy_need_data
    tst existing_target
    bne copy_need_data
    ldx #source_path
    stx rename_table
    ldx #target_path
    stx v_rename_t_2
    ldx #rename_table
    jsr dos_rename
    tsta
    bne move_other_device
    jsr progress_finish
    clra
    rts
move_other_device
    cmpa #28
    beq copy_need_data
    rts
copy_need_data
    jsr temporary_name
    tsta
    beq copy_temp_ready
    rts
copy_temp_ready
    ldx #source_path
    stx open_table
    ldx #0
    stx v_open_tab_2
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    beq copy_source_ready
    rts
copy_source_ready
    stab source_handle
    inc source_open
    ldx #temp_path
    stx open_table
    clra
    ldx #open_table
    int $4b
    tsta
    beq *+5
    jmp copy_fail
    stab target_handle
    inc target_open
    jsr progress_start
    tsta
    beq copy_block
    jmp copy_fail
copy_block
    jsr poll_cancel
    bcc copy_read
    ldaa #$ff
    jmp copy_fail
copy_read
    ldx #io_buffer
    stx io_table
    ldx #512
    stx v_io_table_2
    ldaa source_handle
    ldx #io_table
    int $4c
    tsta
    beq *+5
    jmp copy_fail
    cpx #0
    beq copy_complete
    stx v_io_table_2
    ldaa target_handle
    ldx #io_table
    int $4d
    tsta
    beq *+5
    jmp copy_fail
    cpx v_io_table_2
    bne copy_short_write
    jsr progress_update
    jmp copy_block
copy_short_write
    ldaa #17
    jmp copy_fail
copy_complete
    ldaa #0
    ldab source_handle
    ldx #file_stamp
    int $55
    tsta
    beq *+5
    jmp copy_fail
    ldaa #1
    ldab target_handle
    ldx #file_stamp
    int $55
    tsta
    beq *+5
    jmp copy_fail
    ldaa target_handle
    int $4e
    clr target_open
    tsta
    beq *+5
    jmp copy_fail
    ldaa source_handle
    int $4e
    clr source_open
    tsta
    beq *+5
    jmp copy_fail
    ; Keep the old destination under a backup name until publication succeeds.
    tst existing_target
    beq copy_publish
    jsr backup_name
    tsta
    beq copy_backup_name
    jmp copy_fail
copy_backup_name
    ldx #target_path
    stx rename_table
    ldx #backup_path
    stx v_rename_t_2
    ldx #rename_table
    jsr dos_rename
    tsta
    beq copy_backup_ready
    jmp copy_fail
copy_backup_ready
    inc backup_active
copy_publish
    ldx #temp_path
    stx rename_table
    ldx #target_path
    stx v_rename_t_2
    ldx #rename_table
    jsr dos_rename
    tsta
    beq *+5
    jmp copy_fail
    tst backup_active
    beq copy_attributes
    clr backup_active
    ldx #backup_path
    int $4f
    tsta
    beq copy_attributes
    jmp copy_fail
copy_attributes
    ldaa #1
    ldab file_attributes
    ldx #target_path
    int $54
    tsta
    beq copy_published
    jmp copy_fail
copy_published
    ldaa operation
    cmpa #2
    bne copy_success
    ldx #source_path
    int $4f
    tsta
    bne copy_move_return
    jsr progress_finish
    clra
copy_move_return
    rts
copy_success
    jsr progress_finish
    clra
    rts
copy_fail
    staa io_error
    tst backup_active
    beq copy_failure_close
    ldx #backup_path
    stx rename_table
    ldx #target_path
    stx v_rename_t_2
    ldx #rename_table
    jsr dos_rename
    clr backup_active
copy_failure_close
    tst target_open
    beq copy_close_source
    ldaa target_handle
    int $4e
    clr target_open
copy_close_source
    tst source_open
    beq copy_remove_temp
    ldaa source_handle
    int $4e
    clr source_open
copy_remove_temp
    ldx #temp_path
    int $4f
    ldaa io_error
    rts
temporary_name
    ; Generate a non-existing 8.3 name in the target directory.
    ldx #target_path
    stx src
    ldx #temp_path
    stx dst
    jsr copy_z
    ldx #temp_path
    stx temp_tail
temp_scan
    ldaa 0,x
    beq temp_tail_ready
    inx
    cmpa #'\'
    bne temp_scan
    stx temp_tail
    bra temp_scan
temp_tail_ready
    ldx temp_tail
    stx dst
    ldx #temp_name
    stx src
    jsr copy_z
    ldx temp_tail
    stx temp_digits
    clr temp_tries
temp_try
    ldx temp_digits
    ldaa temp_tries
    anda #15
    adda #'A'
    staa 6,x
    ldx #temp_path
    jsr stat_path
    cmpa #11
    beq temp_available
    tsta
    bne temp_return
    inc temp_tries
    ldaa temp_tries
    cmpa #16
    bcs temp_try
    ldaa #29
temp_return
    rts
temp_available
    clra
    rts

; GETATTR rejects directory entries in the historical kernel. FindFirst with
; an exact-name mask is the portable stat operation for both files and dirs.
stat_path
    stx v_stat_tab_4
    ldx #stat_find
    stx stat_table
    ldx #stat_entry
    stx v_stat_tab_2
    clra
    ldab #$88
    ldx #stat_table
    int $42
    ldab v_stat_ent_11
    rts

backup_name
    ldx #temp_path
    stx src
    ldx #backup_path
    stx dst
    jsr copy_z
    ldx #backup_path
    stx backup_tail
backup_scan
    ldaa 0,x
    beq backup_tail_ready
    inx
    cmpa #'\'
    bne backup_scan
    stx backup_tail
    bra backup_scan
backup_tail_ready
    ldx backup_tail
    ldaa #'B'
    staa 0,x
    clr backup_tries
backup_try
    ldx backup_tail
    ldaa backup_tries
    adda #'A'
    staa 6,x
    ldx #backup_path
    jsr stat_path
    cmpa #11
    beq backup_available
    tsta
    bne backup_return
    inc backup_tries
    ldaa backup_tries
    cmpa #16
    bcs backup_try
    ldaa #29
backup_return
    rts
backup_available
    clra
    rts

; UniDOS RENAME temporarily terminates the destination at its last slash.
; Pass disposable copies so recursive paths and publication names stay valid.
dos_rename
    ldx rename_table
    stx src
    ldx #rename_source
    stx dst
    jsr copy_z
    ldx v_rename_t_2
    stx src
    ldx #rename_target
    stx dst
    jsr copy_z
    ldx #rename_source
    stx rename_call
    ldx #rename_target
    stx v_rename_c_2
    ldx #rename_call
    int $56
    rts
; Streaming text viewer. Only one 512-byte disk buffer, 32-bit offsets.
viewer
    ldaa active
    jsr choose_panel
    jsr selected
    bcs viewer_redraw
    ldaa 11,x
    bita #16
    bne viewer_redraw
    jsr image_type
    tsta
    beq viewer_text
    ldaa #5
    jmp image_request
viewer_text
    jsr selected_path
    ldx #source_path
    stx open_table
    ldx #0
    stx v_open_tab_2
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    beq viewer_opened
    jsr error
viewer_redraw
    jmp redraw
viewer_opened
    stab view_handle
    jsr caret_hide
    ldx #view_position
    ldab #4
viewer_zero
    clr 0,x
    inx
    decb
    bne viewer_zero
    clr view_page
viewer_page
    jsr view_seek
    tsta
    beq *+5
    jmp viewer_error
    clr ui_x
    clr ui_y
    ldaa #$06
    jsr colour
    jsr position
    ldx #source_path
    jsr line_text
    ldaa #$71
    jsr colour
    ldaa #1
    staa ui_y
    clr ui_x
    jsr position
    clr view_eof
viewer_character
    jsr view_byte
    bcs viewer_end_page
    cmpa #13
    beq viewer_character
    cmpa #26
    beq viewer_end_page
    cmpa #10
    beq viewer_newline
    cmpa #9
    beq viewer_tab
    cmpa #32
    bcc viewer_print
    ldaa #'.'
viewer_print
    jsr put
    inc ui_x
    ldaa ui_x
    cmpa columns
    bcs viewer_character
    bra viewer_line_full
viewer_tab
    ldaa #' '
    jsr put
    inc ui_x
    ldaa ui_x
    cmpa columns
    bcc viewer_line_full
    anda #7
    bne viewer_tab
    bra viewer_character
viewer_newline
    ldaa columns
    suba ui_x
    staa remaining
    jsr padding
viewer_line_full
    inc ui_y
    clr ui_x
    ldaa ui_y
    cmpa #23
    bcc viewer_end_page
    jsr position
    bra viewer_character
viewer_end_page
    ldaa columns
    suba ui_x
    staa remaining
    jsr padding
viewer_clear_tail
    inc ui_y
    ldaa ui_y
    cmpa #24
    bcc viewer_footer
    clr ui_x
    jsr position
    ldaa columns
    staa remaining
    jsr padding
    bra viewer_clear_tail
viewer_footer
    clr ui_x
    ldaa #24
    staa ui_y
    ldaa #$06
    jsr colour
    jsr position
    ldx #viewer_keys
    jsr line_text
viewer_key
    ldaa #4
    jsr mouse_wait
    cmpa #3
    beq viewer_close
    cmpa #27
    beq viewer_close
    cmpa #$c5
    beq viewer_home
    cmpa #$c8
    beq viewer_previous
    cmpa #$c7
    beq viewer_next
    cmpa #32
    beq viewer_next
    bra viewer_key
viewer_home
    clr view_page
    ldx #view_position
    ldab #4
viewer_home_zero
    clr 0,x
    inx
    decb
    bne viewer_home_zero
    jmp viewer_page
viewer_previous
    tst view_page
    beq viewer_home
    dec view_page
    jsr view_history_pointer
    stx src
    ldx #view_position
    stx dst
    ldab #4
    jsr copy_n
    jmp viewer_page
viewer_next
    tst view_eof
    bne viewer_key
    ldaa view_page
    cmpa #63
    bcs viewer_grow_history
    ldx #v_view_his_4
    stx src
    ldx #view_history
    stx dst
    ldab #252
    jsr copy_n
    bra viewer_store_history
viewer_grow_history
    inc view_page
viewer_store_history
    jsr view_history_pointer
    stx dst
    ldx #view_position
    stx src
    ldab #4
    jsr copy_n
    jmp viewer_page
viewer_error
    jsr error
viewer_close
    ldaa view_handle
    int $4e
    jmp redraw
view_history_pointer
    ldaa view_page
    asla
    asla
    tab
    ldx #view_history
    jmp add_b
view_seek
    ldaa view_handle
    clrb
    ldx #view_position
    int $50
    ldx #0
    stx view_left
    rts
view_byte
    ldx view_left
    bne view_buffered
    ldx #io_buffer
    stx io_table
    ldx #512
    stx v_io_table_2
    ldaa view_handle
    ldx #io_table
    int $4c
    tsta
    bne view_no_byte
    stx view_left
    cpx #0
    beq view_no_byte
    ldx #io_buffer
    stx view_ptr
view_buffered
    ldx view_ptr
    ldaa 0,x
    inx
    stx view_ptr
    ldx view_left
    dex
    stx view_left
    inc v_view_pos_3
    bne view_byte_done
    inc v_view_pos_2
    bne view_byte_done
    inc v_view_pos_1
    bne view_byte_done
    inc view_position
view_byte_done
    clc
    rts
view_no_byte
    inc view_eof
    sec
    rts
    end
