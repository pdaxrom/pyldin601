; Open original read-only. Workspace creation is deferred until the first edit.
editor_open
    ldx #filename
    stx open_table
    ldx #0
    stx open_table+2
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    beq *+5
    jmp editor_open_return
    stab handles
    ldaa #1
    staa opened
    tba
    ldx #file_sizes
    int $51
    tsta
    beq *+5
    jmp editor_open_return
    ldaa file_sizes
    staa doc_size
    ldaa file_sizes+1
    staa doc_size+1
    ldaa file_sizes+2
    staa doc_size+2
    ldaa file_sizes+3
    staa doc_size+3
    ; Seed a pinned RAM-only index leaf, so read-only viewing needs no scratch.
    clr cache_slot
    jsr cache_buffer
    stx leaf_ptr
    ldaa #$ff
    staa 0,x
    staa 1,x
    staa 2,x
    staa 3,x
    staa 12,x
    staa 13,x
    staa 14,x
    staa 15,x
    ldx #doc_size
    jsr q_load
    ldx leaf_ptr
    ldab #4
    jsr add_b
    jsr q_store
    jsr q_test
    beq editor_empty
    ldx leaf_ptr
    ldaa #1
    staa 8,x
    clra
    jsr leaf_entry
    stx entry_ptr
    clr 0,x
    clr 1,x
    clr 2,x
    clr 3,x
    clr 8,x
    ldx #doc_size
    jsr q_load
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_store
editor_empty
    jsr cache_tag
    ldaa #1
    staa 0,x
    staa 2,x
    ldaa #1
    staa cache_hand
    jsr q_512
    ldx #index_end
    jsr q_store
    clra
editor_open_return
    rts
; Three unique 8.3 work files: NCEhhhhh.IDX / .ADD / .UND.
; All three names are checked before CREATE; existing files are never truncated.
work_open
    tst work_ready
    beq *+5
    jmp work_success
    ldx owner
    ldab #255
    jsr add_b
    ldab #52
    jsr add_b
    tst 0,x
    bne work_directory
    ldx #filename
work_directory
    stx src
    ldx #work_path
    stx dst
    jsr copy_z
    ldx #work_path
    stx work_tail
work_tail_scan
    ldaa 0,x
    beq work_tail_found
    inx
    cmpa #'\'
    bne work_tail_scan
    stx work_tail
    bra work_tail_scan
work_tail_found
    ; A configured directory ends with a slash; a source pathname doesn't.
    ldx work_tail
    stx dst
    ldx #work_name
    stx src
    jsr copy_z
    clr work_attempt
work_unique
    ldx work_tail
    ldaa work_attempt
    lsra
    lsra
    lsra
    lsra
    jsr hex_digit
    staa 6,x
    ldaa work_attempt
    anda #15
    jsr hex_digit
    staa 7,x
    clr work_kind
work_check_names
    jsr work_extension
    ldx #work_path
    stx find_table+4
    ldx #find_state
    stx find_table
    ldx #dir_entry
    stx find_table+2
    clra
    clrb
    ldx #find_table
    int $42
    cmpa #11
    beq work_name_free
    tsta
    bne work_return
    inc work_attempt
    bne work_unique
    ldaa #12
    rts
work_name_free
    inc work_kind
    ldaa work_kind
    cmpa #3
    bcs work_check_names
    clr work_kind
work_create
    jsr work_extension
    ldx #work_path
    stx open_table
    ldx #0
    stx open_table+2
    clra
    ldx #open_table
    int $4b
    tsta
    bne work_failed
    tba
    int $4e
    tsta
    bne work_failed
    ldaa #3
    ldx #open_table
    int $4a
    tsta
    bne work_failed
    stab new_handle
    ldaa work_kind
    inca
    staa io_file
    tab
    ldx #handles
    jsr add_b
    ldaa new_handle
    staa 0,x
    inc work_created
    inc opened
    inc work_kind
    ldaa work_kind
    cmpa #3
    bcs work_create
    inc work_ready
    clr cache_slot
    jsr block_dirty
    jsr cache_flush
    tsta
    bne work_return
work_success
    clra
work_return
    rts
work_failed
    staa work_error
    jsr work_cleanup
    ldaa work_error
    rts
work_extension
    ldaa work_kind
    asla
    asla
    tab
    ldx #work_extensions
    jsr add_b
    stx src
    ldx work_tail
    ldab #9
    jsr add_b
    stx dst
    jmp copy_z
work_cleanup
    clr work_kind
work_cleanup_loop
    ldaa work_kind
    cmpa work_created
    bcc work_cleanup_done
    inca
    tab
    ldx #handles
    jsr add_b
    ldaa 0,x
    int $4e
    jsr work_extension
    ldx #work_path
    int $4f
    inc work_kind
    bra work_cleanup_loop
work_cleanup_done
    clr work_created
    clr work_ready
    rts
editor_close
    tst save_open
    beq editor_work_close
    ldaa save_handle
    int $4e
editor_work_close
    jsr work_cleanup
    ldaa handles
    int $4e
    ; The latest backup supersedes the first backing version once Undo ends.
    tst base_is_backup
    beq editor_keep_backups
    tst latest_backup
    beq editor_keep_backups
    ldx #base_path
    int $4f
editor_keep_backups
    jsr editor_cache_close
    ldaa saved_cursor
    staa $ed1d
    ldaa mode
    cmpa #2
    bne editor_close_video
    ldaa #6
    int $22
    ldaa original_attr
    int $22
editor_close_video
    ldab original_attr
    int $16
    int $38
hex_digit
    anda #15
    adda #'0'
    cmpa #'9'
    bls hex_ready
    adda #7
hex_ready
    rts
