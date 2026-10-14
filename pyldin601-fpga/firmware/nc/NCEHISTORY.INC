; Buffered append store. This is also the backing store for removed text.
add_byte
    staa append_char
    ldaa add_tail+2
    anda #1
    oraa add_tail+3
    bne append_get
    ldx #add_tail
    jsr q_load
    jsr q_test
    beq append_get
    jsr cache_flush
    tsta
    bne append_return
append_get
    ldx #add_tail
    jsr q_load
    ldaa #2
    jsr block_get
    tsta
    bne append_return
    ldaa append_char
    staa 0,x
    jsr block_dirty
    ldx #add_tail
    jsr q_load
    jsr q_inc
    ldx #add_tail
    jsr q_store
    clra
append_return
    rts

; A small edit is prepared before it is published. The pending operation
; records enough progress to resume an interrupted undo/delete after I/O errors.
change_prepare
    ldx #change_at
    jsr q_load
    ldx #where
    jsr q_store
    jsr doc_locate
    tsta
    bne change_prepared
    ldx leaf_ptr
    ldaa 8,x
    cmpa #27
    bcs change_prepare_end
    jsr leaf_split
    tsta
    bne change_prepared
change_prepare_end
    ldaa change_delete
    jsr q_small
    ldx #change_at
    jsr q_add
    ldx #where
    jsr q_store
    ldx #doc_size
    jsr q_cmp
    bcc change_prepare_start
    jsr doc_locate
    tsta
    bne change_prepared
    ldx leaf_ptr
    ldaa 8,x
    cmpa #27
    bcs change_prepare_start
    jsr leaf_split
    tsta
    bne change_prepared
change_prepare_start
    ldx #change_at
    jsr q_load
    ldx #where
    jsr q_store
    jmp doc_locate
change_prepared
    rts
editor_change
    jsr work_open
    tsta
    beq *+5
    jmp change_return
    jsr change_prepare
    tsta
    beq *+5
    jmp change_return
    ldx #change_at
    jsr q_load
    ldx #pending_record
    jsr q_store
    ldx #add_tail
    jsr q_load
    ldx #pending_record+4
    jsr q_store
    ldaa change_delete
    jsr q_small
    ldx #pending_record+8
    jsr q_store
    clr change_index
change_collect
    ldaa change_index
    cmpa change_delete
    bcc change_new_text
    jsr q_small
    ldx #change_at
    jsr q_add
    ldx #where
    jsr q_store
    jsr doc_byte
    bcc *+5
    jmp change_return
    jsr add_byte
    tsta
    beq *+5
    jmp change_return
    inc change_index
    bra change_collect
change_new_text
    ldx #add_tail
    jsr q_load
    ldx #pending_record+12
    jsr q_store
    ldaa change_add
    jsr q_small
    ldx #pending_record+16
    jsr q_store
    clr change_index
change_append
    ldaa change_index
    cmpa change_add
    bcc change_record
    tab
    ldx #change_bytes
    jsr add_b
    ldaa 0,x
    jsr add_byte
    tsta
    beq *+5
    jmp change_return
    inc change_index
    bra change_append
change_record
    ldx #e_cursor
    jsr q_load
    ldx #pending_record+20
    jsr q_store
    ldaa change_add
    jsr q_small
    ldx #change_at
    jsr q_add
    ldx #pending_record+24
    jsr q_store
    ldaa change_linebreak
    staa pending_record+29
    ldaa change_group
    staa pending_record+28
    clr history_mode
    ldx #history_cursor
    jsr q_load
    ldx #history_position
    jsr q_store
    ldx #history_cursor
    jsr q_load
    ldx #const32
    jsr q_add
    ldx #history_target
    jsr q_store
    tst group_open
    bne *+5
    jmp change_new_record
    tst change_group
    bne *+5
    jmp change_new_record
    tst change_delete
    beq *+5
    jmp change_new_record
    ldx #history_cursor
    jsr q_load
    ldx #history_count
    jsr q_cmp
    beq *+5
    jmp change_new_record
    ldx #const32
    jsr q_sub
    ldx #history_position
    jsr q_store
    jsr history_get
    tsta
    beq *+5
    jmp change_return
    ldaa history_record+28
    bne *+5
    jmp change_new_record
    ldx #history_record
    jsr q_load
    ldx #history_record+16
    jsr q_add
    ldx #change_at
    jsr q_cmp
    beq *+5
    jmp change_new_record
    ldx #history_record+12
    jsr q_load
    ldx #history_record+16
    jsr q_add
    ldx #pending_record+12
    jsr q_cmp
    beq *+5
    jmp change_new_record
    ldx #history_record+16
    jsr q_load
    ldx #pending_record+16
    jsr q_add
    ldx #history_record+16
    jsr q_store
    ldx #pending_record+24
    jsr q_load
    ldx #history_record+24
    jsr q_store
    ldx #history_cursor
    jsr q_load
    ldx #history_target
    jsr q_store
    bra change_write_record
change_new_record
    ldx #history_cursor
    jsr q_load
    ldx #history_position
    jsr q_store
    ldx #pending_record
    stx src
    ldx #history_record
    stx dst
    ldab #32
    jsr copy_n
change_write_record
    jsr history_put
    tsta
    beq *+5
    jmp change_return
    ; Refill/presplit both touched leaves after appending the payload/log.
    jsr change_prepare
    tsta
    beq *+5
    jmp change_return
    ldaa change_group
    staa group_open
    ldx #pending_record
    jsr q_load
    ldx #apply_pos
    jsr q_store
    ldx #pending_record+8
    jsr q_load
    ldx #apply_left
    jsr q_store
    ldx #pending_record+12
    jsr q_load
    ldx #apply_insert_off
    jsr q_store
    ldx #pending_record+16
    jsr q_load
    ldx #apply_insert_len
    jsr q_store
    ldx #pending_record+24
    jsr q_load
    ldx #apply_cursor
    jsr q_store
    ldaa #1
    staa apply_phase
    jmp history_resume
change_return
    rts
history_get
    ldx #history_position
    jsr q_load
    ldaa #3
    jsr block_get
    tsta
    beq *+5
    jmp history_io_return
    stx src
    ldx #history_record
    stx dst
    ldab #32
    jsr copy_n
    clra
history_io_return
    rts
history_put
    ldx #history_position
    jsr q_load
    ldx #file_sizes+12
    jsr q_cmp
    bls history_put_block
    jsr cache_flush
    tsta
    beq *+5
    jmp history_io_return
history_put_block
    ldx #history_position
    jsr q_load
    ldaa #3
    jsr block_get
    tsta
    beq *+5
    jmp history_io_return
    stx dst
    ldx #history_record
    stx src
    ldab #32
    jsr copy_n
    jsr block_dirty
    clra
    rts
history_undo
    clr group_open
    ldx #history_cursor
    jsr q_load
    jsr q_test
    beq history_io_return
    ldx #const32
    jsr q_sub
    ldx #history_position
    jsr q_store
    ldx #history_target
    jsr q_store
    jsr history_get
    tsta
    beq *+5
    jmp history_io_return
    ldaa #1
    staa history_mode
    ldx #history_record
    jsr q_load
    ldx #apply_pos
    jsr q_store
    ldx #history_record+16
    jsr q_load
    ldx #apply_left
    jsr q_store
    ldx #history_record+4
    jsr q_load
    ldx #apply_insert_off
    jsr q_store
    ldx #history_record+8
    jsr q_load
    ldx #apply_insert_len
    jsr q_store
    ldx #history_record+20
    jsr q_load
    ldx #apply_cursor
    jsr q_store
    ldaa #1
    staa apply_phase
    jmp history_resume
history_redo
    clr group_open
    ldx #history_cursor
    jsr q_load
    ldx #history_count
    jsr q_cmp
    bcs *+5
    jmp history_nothing
    ldx #history_position
    jsr q_store
    ldx #const32
    jsr q_add
    ldx #history_target
    jsr q_store
    jsr history_get
    tsta
    beq *+5
    jmp history_io_return
    ldaa #2
    staa history_mode
    ldx #history_record
    jsr q_load
    ldx #apply_pos
    jsr q_store
    ldx #history_record+8
    jsr q_load
    ldx #apply_left
    jsr q_store
    ldx #history_record+12
    jsr q_load
    ldx #apply_insert_off
    jsr q_store
    ldx #history_record+16
    jsr q_load
    ldx #apply_insert_len
    jsr q_store
    ldx #history_record+24
    jsr q_load
    ldx #apply_cursor
    jsr q_store
    ldaa #1
    staa apply_phase
history_resume
    ldaa apply_phase
    cmpa #1
    bne history_insert
    ldx #apply_pos
    jsr q_load
    ldx #where
    jsr q_store
    ldx #apply_left
    jsr q_load
    ldx #remove_left
    jsr q_store
    jsr delete_more
    staa apply_error
    ldx #remove_left
    jsr q_load
    ldx #apply_left
    jsr q_store
    ldaa apply_error
    beq *+5
    jmp history_io_return
    ldaa #2
    staa apply_phase
history_insert
    ldx #apply_pos
    jsr q_load
    ldx #where
    jsr q_store
    ldx #apply_insert_off
    jsr q_load
    ldx #insert_off
    jsr q_store
    ldx #apply_insert_len
    jsr q_load
    ldx #insert_len
    jsr q_store
    jsr doc_insert
    tsta
    beq *+5
    jmp history_io_return
    ldx #apply_cursor
    jsr q_load
    ldx #e_cursor
    jsr q_store
    tst history_mode
    bne history_move_cursor
    ; A new edit after Undo discards the redo tail, including a saved marker.
    ldx #history_cursor
    jsr q_load
    ldx #saved_history
    jsr q_cmp
    bcc history_keep_saved
    clr saved_valid
history_keep_saved
    ldx #history_target
    jsr q_load
    ldx #history_count
    jsr q_store
history_move_cursor
    ldx #history_target
    jsr q_load
    ldx #history_cursor
    jsr q_store
    clr apply_phase
    ldaa #1
    staa modified
    tst saved_valid
    beq history_applied
    ldx #history_cursor
    jsr q_load
    ldx #saved_history
    jsr q_cmp
    bne history_applied
    clr modified
history_applied
    clra
    rts
history_nothing
    clra
    rts
q_small
    staa q+3
    clr q
    clr q+1
    clr q+2
    rts
