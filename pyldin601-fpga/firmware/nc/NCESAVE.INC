; Publish a fully closed new file, retaining the original as a backing/backup.
; Working ADD/index/undo state survives Save; Undo remains available afterwards.
editor_save
    tst modified
    bne save_current
    clra
    rts
save_current
    ldx #filename
    stx src
    ldx #save_target
    stx dst
    jsr copy_z
    jmp save_begin
editor_save_as
    ldx #filename
    stx src
    ldx #input
    stx dst
    jsr copy_z
    ldx #save_as_title
    jsr dialog
    bcc *+5
    jmp save_cancelled
    tst input
    bne *+5
    jmp save_cancelled
    ldx #input
    jsr editor_path_length
    bcc save_input_length_ok
    ldaa #19
    rts
save_input_length_ok
    stab save_input_length
    ; Resolve relative names against the editor document's directory.
    ldx #input
    ldaa 1,x
    cmpa #':'
    beq save_resolve_input
    ldaa 0,x
    cmpa #'\'
    beq save_document_root
    ldx #filename
    stx src
    ldx #error_text
    stx dst
    jsr copy_z
    ldx #error_text
    stx path_tail
save_parent_scan
    ldaa 0,x
    beq save_parent_ready
    inx
    cmpa #'\'
    bne save_parent_scan
    stx path_tail
    bra save_parent_scan
save_parent_ready
    ldx #error_text
    clrb
save_parent_length
    cpx path_tail
    beq save_parent_counted
    inx
    incb
    bra save_parent_length
save_parent_counted
    addb save_input_length
    cmpb #64
    bcs save_parent_fits
    ldaa #19
    rts
save_parent_fits
    ldx path_tail
    stx dst
    ldx #input
    stx src
    jsr copy_z
    ldx #error_text
    bra save_resolve
save_document_root
    ldaa save_input_length
    cmpa #62
    bcs save_document_root_fits
    ldaa #19
    rts
save_document_root_fits
    ldaa filename
    staa error_text
    ldaa #':'
    staa error_text+1
    ldx #error_text+2
    stx dst
    ldx #input
    stx src
    jsr copy_z
    ldx #error_text
    bra save_resolve
save_resolve_input
    ldx #input
save_resolve
    stx full_table
    ldx #save_target
    stx full_table+2
    ldx #full_table
    int $3f
    tsta
    beq *+5
    jmp save_return
    ldx #save_target
    jsr editor_stat
    cmpa #11
    beq save_begin
    tsta
    beq *+5
    jmp save_return
    ldx #filename
    stx src
    ldx #save_target
    stx dst
    jsr same_path
    beq save_begin
    ldx #overwrite_text
    jsr confirm
    cmpa #'Y'
    beq save_begin
save_cancelled
    ldaa #$ff
    rts
save_begin
    tst save_open
    beq save_no_pending_handle
    ldaa save_handle
    int $4e
    tsta
    beq *+5
    jmp save_return
    clr save_open
    ldx #save_temp
    int $4f
save_no_pending_handle
    clr save_open
    clr save_renamed
    clr base_closed
    clr save_exists
    clr save_attributes
    ldx #save_target
    jsr editor_stat
    cmpa #11
    beq save_names
    tsta
    beq *+5
    jmp save_return
    ldaa dir_entry+11
    bita #17
    beq save_attribute_ok
    ldaa #3
    rts
save_attribute_ok
    staa save_attributes
    inc save_exists
save_names
    jsr save_unique
    tsta
    beq *+5
    jmp save_return
    jsr cache_flush
    tsta
    beq *+5
    jmp save_return
    ldx #save_temp
    stx open_table
    ldx #0
    stx open_table+2
    clra
    ldx #open_table
    int $4b
    tsta
    beq *+5
    jmp save_return
    stab save_handle
    inc save_open
    ldx #saving_title
    jsr window_open
    ldx #save_target
    ldaa #8
    jsr window_line
    ldx #cancel_save_text
    ldaa #16
    jsr window_line
    clr save_done
    clr save_done+1
    clr save_done+2
    clr save_done+3
    clr where
    clr where+1
    clr where+2
    clr where+3
    clr save_cells
    ldaa doc_size
    staa number
    ldaa doc_size+1
    staa number+1
    ldaa doc_size+2
    staa number+2
    ldaa doc_size+3
    staa number+3
    ldaa columns
    suba #12
    staa save_bar_width
    staa number_divisor
    jsr divide_number
    ldaa number
    staa save_quantum
    ldaa number+1
    staa save_quantum+1
    ldaa number+2
    staa save_quantum+2
    ldaa number+3
    staa save_quantum+3
    ldx #save_quantum
    jsr q_load
    tst remainder
    beq save_quantum_ready
    jsr q_inc
save_quantum_ready
    jsr q_test
    bne save_quantum_store
    jsr q_inc
save_quantum_store
    ldx #save_quantum
    jsr q_store
    ldx #save_next
    jsr q_store
    jsr save_progress
    clr where
    clr where+1
    clr where+2
    clr where+3
    jsr stream_init
    bcc *+5
    jmp save_stream_end
save_fill
    ldx #save_buffer
    stx save_ptr
    clr save_length
    clr save_length+1
save_read_byte
    jsr stream_block
    bcc *+5
    jmp save_read_end
    ldaa #0
    suba save_length+1
    staa save_take+1
    ldaa #2
    sbca save_length
    staa save_take
    ldaa stream_left
    cmpa save_take
    bne save_compare_take
    ldaa stream_left+1
    cmpa save_take+1
save_compare_take
    bcc save_take_ready
    ldx stream_left
    stx save_take
save_take_ready
    ldx stream_ptr
    stx src
    ldx save_ptr
    stx dst
    ldx save_take
    stx split_bytes
    jsr copy_bytes
    ldx src
    stx stream_ptr
    ldx dst
    stx save_ptr
    clr save_chunk
    clr save_chunk+1
    ldx save_take
    stx save_chunk+2
    ldx #stream_remaining
    jsr q_load
    ldx #save_chunk
    jsr q_sub
    ldx #stream_remaining
    jsr q_store
    ldx #where
    jsr q_load
    ldx #save_chunk
    jsr q_add
    ldx #where
    jsr q_store
    ldaa stream_left+1
    suba save_take+1
    staa stream_left+1
    ldaa stream_left
    sbca save_take
    staa stream_left
    ldaa save_length+1
    adda save_take+1
    staa save_length+1
    ldaa save_length
    adca save_take
    staa save_length
    cmpa #2
    bcc *+5
    jmp save_read_byte
    jsr save_write
    tsta
    beq *+5
    jmp save_fail
    jmp save_fill

save_read_end
    tsta
    beq *+5
    jmp save_fail
    ldx save_length
    cpx #0
    beq save_stream_end
    jsr save_write
    tsta
    beq *+5
    jmp save_fail
save_stream_end
    tsta
    beq *+5
    jmp save_fail
    ldaa save_handle
    int $4e
    tsta
    beq *+5
    jmp save_fail
    clr save_open
    tst save_exists
    beq save_publish
    ldx #base_path
    stx src
    ldx #save_target
    stx dst
    jsr same_path
    bne save_backup_target
    ldaa handles
    int $4e
    tsta
    beq *+5
    jmp save_fail
    inc base_closed
save_backup_target
    ldx #save_target
    stx rename_table
    ldx #save_backup
    stx rename_table+2
    jsr editor_rename
    tsta
    beq *+5
    jmp save_reopen_failure
    inc save_renamed
save_publish
    ldx #save_temp
    stx rename_table
    ldx #save_target
    stx rename_table+2
    jsr editor_rename
    tsta
    beq *+5
    jmp save_rollback
    tst base_closed
    beq save_keep_backup
    ldx #save_backup
    stx src
    ldx #base_path
    stx dst
    jsr copy_z
    inc base_is_backup
    jsr reopen_base
    tsta
    beq *+5
    jmp save_return
    bra save_published
save_keep_backup
    tst save_renamed
    beq save_published
    ; Keep the latest previous version as well as the open original backing.
    tst latest_backup
    beq save_record_backup
    ldx #latest_backup
    int $4f
save_record_backup
    ldx #save_backup
    stx src
    ldx #latest_backup
    stx dst
    jsr copy_z
save_published
    ldaa #1
    ldab save_attributes
    orab #32
    ldx #save_target
    int $54
    tsta
    beq *+5
    jmp save_return
    ldx #save_target
    stx src
    ldx #filename
    stx dst
    jsr copy_z
    ldaa history_cursor
    staa saved_history
    ldaa history_cursor+1
    staa saved_history+1
    ldaa history_cursor+2
    staa saved_history+2
    ldaa history_cursor+3
    staa saved_history+3
    ldaa #1
    staa saved_valid
    clr modified
    clr save_renamed
    clra
save_return
    rts
save_write
    ldx #save_buffer
    stx io_table
    ldx save_length
    stx io_table+2
    ldaa save_handle
    ldx #io_table
    int $4d
    tsta
    beq *+5
    jmp save_return
    cpx save_length
    beq save_write_counted
    ldaa #12
    rts
save_write_counted
    ldx #save_done
    jsr q_load
    ldaa q+3
    adda save_length+1
    staa q+3
    ldaa q+2
    adca save_length
    staa q+2
    ldaa q+1
    adca #0
    staa q+1
    ldaa q
    adca #0
    staa q
    ldx #save_done
    jsr q_store
    ldx #save_next
    jsr q_cmp
    bcs save_poll
    jsr save_progress
save_poll
    int $10
    cmpa #$ff
    beq save_write_ok
    int $11
    cmpa #27
    bne *+5
    jmp save_cancelled
    cmpa #3
    bne *+5
    jmp save_cancelled
save_write_ok
    clra
    rts
save_fail
    staa save_error
    tst save_open
    beq save_remove_temp
    ldaa save_handle
    int $4e
    tsta
    beq save_failed_handle_closed
    ldaa save_error
    rts
save_failed_handle_closed
    clr save_open
save_remove_temp
    ldx #save_temp
    int $4f
    ldaa save_error
    rts
save_rollback
    staa save_error
    tst save_renamed
    beq save_reopen_error
    ldx #save_backup
    stx rename_table
    ldx #save_target
    stx rename_table+2
    jsr editor_rename
    tsta
    beq save_reopen_error
    ; Failed rollback retains the backup and points the backing handle to it.
    tst base_closed
    beq save_reopen_error
    ldx #save_backup
    stx src
    ldx #base_path
    stx dst
    jsr copy_z
    inc base_is_backup
save_reopen_error
    tst base_closed
    beq save_remove_temp
    jsr reopen_base
    jmp save_remove_temp
save_reopen_failure
    staa save_error
    tst base_closed
    beq save_remove_temp
    jsr reopen_base
    jmp save_remove_temp
reopen_base
    ldx #base_path
    stx open_table
    ldx #0
    stx open_table+2
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    bne reopen_return
    stab handles
    ldaa #$ff
    staa file_positions
    staa file_positions+1
    staa file_positions+2
    staa file_positions+3
    clr base_closed
    clra
reopen_return
    rts
save_unique
    ldx #save_target
    stx src
    ldx #save_temp
    stx dst
    jsr copy_z
    ldx #save_temp
    stx save_tail
save_tail_scan
    ldaa 0,x
    beq save_tail_ready
    inx
    cmpa #'\'
    bne save_tail_scan
    stx save_tail
    bra save_tail_scan
save_tail_ready
    ldx save_tail
    stx dst
    ldx #save_name
    stx src
    jsr copy_z
    ldx #save_temp
    stx src
    ldx #save_backup
    stx dst
    jsr copy_z
    ldx #save_temp
    clrb
save_prefix_length
    cpx save_tail
    beq save_backup_pointer_ready
    inx
    incb
    bra save_prefix_length
save_backup_pointer_ready
    ldx #save_backup
    jsr add_b
    stx save_backup_tail
    ldaa #'B'
    staa 9,x
    ldaa #'A'
    staa 10,x
    ldaa #'K'
    staa 11,x
    clr save_attempt
save_unique_try
    ldaa save_attempt
    lsra
    lsra
    lsra
    lsra
    jsr hex_digit
    ldx save_tail
    staa 6,x
    ldx save_backup_tail
    staa 6,x
    ldaa save_attempt
    jsr hex_digit
    ldx save_tail
    staa 7,x
    ldx save_backup_tail
    staa 7,x
    ldx #save_temp
    jsr editor_stat
    cmpa #11
    bne save_unique_next
    ldx #save_backup
    jsr editor_stat
    cmpa #11
    beq save_unique_ready
save_unique_next
    tsta
    bne save_unique_error
    inc save_attempt
    bne save_unique_try
    ldaa #12
    rts
save_unique_error
    cmpa #11
    beq save_unique_advance
    rts
save_unique_advance
    inc save_attempt
    bne save_unique_try
    ldaa #12
    rts
save_unique_ready
    clra
    rts
editor_stat
    stx find_table+4
    ldx #find_state
    stx find_table
    ldx #dir_entry
    stx find_table+2
    clra
    clrb
    ldx #find_table
    int $42
    rts
editor_rename
    ldx rename_table
    stx src
    ldx #input
    stx dst
    jsr copy_z
    ldx rename_table+2
    stx src
    ldx #error_text
    stx dst
    jsr copy_z
    ldx #input
    stx rename_call
    ldx #error_text
    stx rename_call+2
    ldx #rename_call
    int $56
    rts
same_path
    ldx src
    ldaa 0,x
    inx
    stx src
    cmpa #'a'
    bcs same_path_left
    cmpa #'z'
    bhi same_path_left
    anda #$df
same_path_left
    staa path_char
    ldx dst
    ldaa 0,x
    inx
    stx dst
    cmpa #'a'
    bcs same_path_compare
    cmpa #'z'
    bhi same_path_compare
    anda #$df
same_path_compare
    cmpa path_char
    bne same_path_done
    tsta
    bne same_path
same_path_done
    rts
save_progress
    ldx #save_done
    jsr q_load
    ldx #doc_size
    jsr q_cmp
    bcs save_progress_cells
    ldaa save_bar_width
    staa save_cells
    jmp save_progress_draw

save_progress_cells
    ldx #save_next
    jsr q_cmp
    bcs save_progress_draw
    ldaa save_cells
    cmpa save_bar_width
    bcc save_progress_draw
    inc save_cells
    ldx #save_next
    jsr q_load
    ldx #save_quantum
    jsr q_add
    ldx #save_next
    jsr q_store
    ldx #save_done
    jsr q_load
    bra save_progress_cells
save_progress_draw
    ldaa #$07
    jsr colour
    ldx #written_label
    ldaa #11
    jsr window_line
    ldx #save_done
    jsr q_load
    ldx #number
    jsr q_store
    jsr decimal_number
    ldaa #14
    staa ui_x
    ldaa #11
    staa ui_y
    jsr position
    ldaa columns
    suba #20
    staa remaining
    ldx #number_text
    jsr field
    ldx #total_label
    ldaa #12
    jsr window_line
    ldx #doc_size
    jsr q_load
    ldx #number
    jsr q_store
    jsr decimal_number
    ldaa #14
    staa ui_x
    ldaa #12
    staa ui_y
    jsr position
    ldaa columns
    suba #20
    staa remaining
    ldx #number_text
    jsr field
    ldaa #6
    staa ui_x
    ldaa #14
    staa ui_y
    ldaa #$03
    jsr colour
    jsr position
    clr save_bar_index
save_bar_cell
    ldaa #' '
    ldab save_bar_index
    cmpb save_cells
    bcc save_bar_put
    ldaa #'#'
save_bar_put
    jsr put
    inc save_bar_index
    ldaa save_bar_index
    cmpa save_bar_width
    bcs save_bar_cell
    rts

; The DOS pathname interface accepts at most 63 bytes plus its terminator.
editor_path_length
    clrb
editor_path_byte
    tst 0,x
    beq editor_path_valid
    inx
    incb
    cmpb #64
    bcs editor_path_byte
    sec
    rts
editor_path_valid
    clc
    rts
