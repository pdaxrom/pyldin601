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
    ldaa change_at
    staa where
    ldaa change_at+1
    staa where+1
    ldaa change_at+2
    staa where+2
    ldaa change_at+3
    staa where+3
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
    ldaa change_at
    staa where
    ldaa change_at+1
    staa where+1
    ldaa change_at+2
    staa where+2
    ldaa change_at+3
    staa where+3
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
    ldaa change_at
    staa pending_record
    ldaa change_at+1
    staa pending_record+1
    ldaa change_at+2
    staa pending_record+2
    ldaa change_at+3
    staa pending_record+3
    ldaa add_tail
    staa pending_record+4
    ldaa add_tail+1
    staa pending_record+4+1
    ldaa add_tail+2
    staa pending_record+4+2
    ldaa add_tail+3
    staa pending_record+4+3
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
    ldaa add_tail
    staa pending_record+12
    ldaa add_tail+1
    staa pending_record+12+1
    ldaa add_tail+2
    staa pending_record+12+2
    ldaa add_tail+3
    staa pending_record+12+3
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
    ldaa e_cursor
    staa pending_record+20
    ldaa e_cursor+1
    staa pending_record+20+1
    ldaa e_cursor+2
    staa pending_record+20+2
    ldaa e_cursor+3
    staa pending_record+20+3
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
    ldaa history_cursor
    staa history_position
    ldaa history_cursor+1
    staa history_position+1
    ldaa history_cursor+2
    staa history_position+2
    ldaa history_cursor+3
    staa history_position+3
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
    ldaa pending_record+24
    staa history_record+24
    ldaa pending_record+24+1
    staa history_record+24+1
    ldaa pending_record+24+2
    staa history_record+24+2
    ldaa pending_record+24+3
    staa history_record+24+3
    ldaa history_cursor
    staa history_target
    ldaa history_cursor+1
    staa history_target+1
    ldaa history_cursor+2
    staa history_target+2
    ldaa history_cursor+3
    staa history_target+3
    bra change_write_record
change_new_record
    ldaa history_cursor
    staa history_position
    ldaa history_cursor+1
    staa history_position+1
    ldaa history_cursor+2
    staa history_position+2
    ldaa history_cursor+3
    staa history_position+3
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
    ldaa pending_record
    staa apply_pos
    ldaa pending_record+1
    staa apply_pos+1
    ldaa pending_record+2
    staa apply_pos+2
    ldaa pending_record+3
    staa apply_pos+3
    ldaa pending_record+8
    staa apply_left
    ldaa pending_record+8+1
    staa apply_left+1
    ldaa pending_record+8+2
    staa apply_left+2
    ldaa pending_record+8+3
    staa apply_left+3
    ldaa pending_record+12
    staa apply_insert_off
    ldaa pending_record+12+1
    staa apply_insert_off+1
    ldaa pending_record+12+2
    staa apply_insert_off+2
    ldaa pending_record+12+3
    staa apply_insert_off+3
    ldaa pending_record+16
    staa apply_insert_len
    ldaa pending_record+16+1
    staa apply_insert_len+1
    ldaa pending_record+16+2
    staa apply_insert_len+2
    ldaa pending_record+16+3
    staa apply_insert_len+3
    ldaa pending_record+24
    staa apply_cursor
    ldaa pending_record+24+1
    staa apply_cursor+1
    ldaa pending_record+24+2
    staa apply_cursor+2
    ldaa pending_record+24+3
    staa apply_cursor+3
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
    ldaa history_record
    staa apply_pos
    ldaa history_record+1
    staa apply_pos+1
    ldaa history_record+2
    staa apply_pos+2
    ldaa history_record+3
    staa apply_pos+3
    ldaa history_record+16
    staa apply_left
    ldaa history_record+16+1
    staa apply_left+1
    ldaa history_record+16+2
    staa apply_left+2
    ldaa history_record+16+3
    staa apply_left+3
    ldaa history_record+4
    staa apply_insert_off
    ldaa history_record+4+1
    staa apply_insert_off+1
    ldaa history_record+4+2
    staa apply_insert_off+2
    ldaa history_record+4+3
    staa apply_insert_off+3
    ldaa history_record+8
    staa apply_insert_len
    ldaa history_record+8+1
    staa apply_insert_len+1
    ldaa history_record+8+2
    staa apply_insert_len+2
    ldaa history_record+8+3
    staa apply_insert_len+3
    ldaa history_record+20
    staa apply_cursor
    ldaa history_record+20+1
    staa apply_cursor+1
    ldaa history_record+20+2
    staa apply_cursor+2
    ldaa history_record+20+3
    staa apply_cursor+3
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
    ldaa history_record
    staa apply_pos
    ldaa history_record+1
    staa apply_pos+1
    ldaa history_record+2
    staa apply_pos+2
    ldaa history_record+3
    staa apply_pos+3
    ldaa history_record+8
    staa apply_left
    ldaa history_record+8+1
    staa apply_left+1
    ldaa history_record+8+2
    staa apply_left+2
    ldaa history_record+8+3
    staa apply_left+3
    ldaa history_record+12
    staa apply_insert_off
    ldaa history_record+12+1
    staa apply_insert_off+1
    ldaa history_record+12+2
    staa apply_insert_off+2
    ldaa history_record+12+3
    staa apply_insert_off+3
    ldaa history_record+16
    staa apply_insert_len
    ldaa history_record+16+1
    staa apply_insert_len+1
    ldaa history_record+16+2
    staa apply_insert_len+2
    ldaa history_record+16+3
    staa apply_insert_len+3
    ldaa history_record+24
    staa apply_cursor
    ldaa history_record+24+1
    staa apply_cursor+1
    ldaa history_record+24+2
    staa apply_cursor+2
    ldaa history_record+24+3
    staa apply_cursor+3
    ldaa #1
    staa apply_phase
history_resume
    ldaa apply_phase
    cmpa #1
    bne history_insert
    ldaa apply_pos
    staa where
    ldaa apply_pos+1
    staa where+1
    ldaa apply_pos+2
    staa where+2
    ldaa apply_pos+3
    staa where+3
    ldaa apply_left
    staa remove_left
    ldaa apply_left+1
    staa remove_left+1
    ldaa apply_left+2
    staa remove_left+2
    ldaa apply_left+3
    staa remove_left+3
    jsr delete_more
    staa apply_error
    ldaa remove_left
    staa apply_left
    ldaa remove_left+1
    staa apply_left+1
    ldaa remove_left+2
    staa apply_left+2
    ldaa remove_left+3
    staa apply_left+3
    ldaa apply_error
    beq *+5
    jmp history_io_return
    ldaa #2
    staa apply_phase
history_insert
    ldaa apply_pos
    staa where
    ldaa apply_pos+1
    staa where+1
    ldaa apply_pos+2
    staa where+2
    ldaa apply_pos+3
    staa where+3
    ldaa apply_insert_off
    staa insert_off
    ldaa apply_insert_off+1
    staa insert_off+1
    ldaa apply_insert_off+2
    staa insert_off+2
    ldaa apply_insert_off+3
    staa insert_off+3
    ldaa apply_insert_len
    staa insert_len
    ldaa apply_insert_len+1
    staa insert_len+1
    ldaa apply_insert_len+2
    staa insert_len+2
    ldaa apply_insert_len+3
    staa insert_len+3
    jsr doc_insert
    tsta
    beq *+5
    jmp history_io_return
    ldaa apply_cursor
    staa e_cursor
    ldaa apply_cursor+1
    staa e_cursor+1
    ldaa apply_cursor+2
    staa e_cursor+2
    ldaa apply_cursor+3
    staa e_cursor+3
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
    ldaa history_target
    staa history_count
    ldaa history_target+1
    staa history_count+1
    ldaa history_target+2
    staa history_count+2
    ldaa history_target+3
    staa history_count+3
history_move_cursor
    ldaa history_target
    staa history_cursor
    ldaa history_target+1
    staa history_cursor+1
    ldaa history_target+2
    staa history_cursor+2
    ldaa history_target+3
    staa history_cursor+3
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
