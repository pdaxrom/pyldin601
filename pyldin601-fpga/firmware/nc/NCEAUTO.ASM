; NCEAUTO: bounded-memory, rotating recovery snapshots. MC6800 only.
; Payload is the exact document; a CRC-protected 128-byte commit trailer
; follows it. Never overwrite the newest copy or the open original backing.
    .define NC_EDITOR
    include NCABI.INC
    public rec_api
    extern add_b
    extern base_path
    extern confirm
    extern copy_z
    extern doc_size
    extern dst
    extern filename
    extern file_sizes
    extern handles
    extern hex_digit
    extern io_table
    extern modified
    extern mouse_cancel
    extern mouse_context
    extern open_table
    extern v_open_tab_2
    extern v_io_table_2
    extern v_q_1
    extern v_q_2
    extern v_q_3
    extern opened
    extern owner
    extern q
    extern q_load
    extern q_store
    extern q_add
    extern q_sub
    extern q_cmp
    extern q_inc
    extern q_test
    extern path_char
    public save_buffer
    public split_buffer
    public save_backup
    extern save_handle
    extern save_length
    extern v_save_len_1
    extern save_open
    extern save_strea_2340
    extern save_temp
    extern src
    extern window_open
    extern window_line
    extern v_block_st_96
    extern v_block_st_100
    extern v_block_st_101
    extern v_block_st_102
    extern v_block_st_103
    extern v_block_st_104
    extern e_cursor
    extern editor_poll
    extern poll_count
    extern reopen_base
    section
rec_restored ds 1
rec_writing ds 1
rec_dirty ds 1
rec_disabled ds 1
rec_declined ds 1
rec_prev ds 1
rec_time ds 2
save_backup ds 80
rec_path equ save_backup
rec_tail ds 2
rec_slot ds 1
rec_last ds 1
rec_available ds 1
rec_skip ds 1
rec_bit ds 1
rec_handle ds 1
rec_error ds 1
rec_crc ds 2
rec_payload ds 2
rec_expect ds 2
rec_count ds 2
rec_length ds 4
rec_position ds 4
rec_generation ds 4
rec_candidate ds 4
split_buffer
save_buffer ds 256
rec_buffer equ save_buffer
    ends
rec_api
    cmpa #12
    bcs rec_api_valid
    ldaa #3
    rts
rec_api_valid
    pshb
    asla
    tab
    ldx #rec_api_table
    jsr add_b
    ldx 0,x
    pulb
    jmp 0,x
rec_api_table
    dw rec_open,rec_changed,rec_crc_write,rec_trailer
    dw rec_complete,rec_cleanup,rec_saved,rec_api_writing
    dw rec_api_restored,rec_checkpoint,rec_api_result,rec_idle
rec_api_writing
    ldaa rec_writing
    rts
rec_api_restored
    ldaa rec_restored
    rts
rec_api_result
    tba
    jmp rec_result

rec_128 db 0,0,0,128
rec_zero db 0,0,0,0
rec_name db 'NCR00000.RC0',0
rec_prompt db 'Restore recovery copy?',0
rec_title db 'Recovery copy',0
; CRC16/XMODEM. No document-sized allocation, bank or host dependency.
rec_crc_byte
    pshb
    eora rec_crc
    staa rec_crc
    ldab #8
rec_crc_bit
    asl rec_crc+1
    rol rec_crc
    bcc rec_crc_next
    ldaa rec_crc
    eora #$10
    staa rec_crc
    ldaa rec_crc+1
    eora #$21
    staa rec_crc+1
rec_crc_next
    decb
    bne rec_crc_bit
    pulb
    rts
rec_crc_block
rec_crc_loop
    ldaa 0,x
    jsr rec_crc_byte
    inx
    tst rec_count+1
    bne rec_crc_low
    dec rec_count
rec_crc_low
    dec rec_count+1
    ldaa rec_count
    oraa rec_count+1
    bne rec_crc_loop
rec_crc_done
    rts
; Work directory follows the same setting as ADD/IDX/UND.
rec_paths
    ldx owner
    ldab #255
    jsr add_b
    ldab #52
    jsr add_b
    tst 0,x
    bne rec_directory
    ldx #filename
rec_directory
    stx src
    ldx #rec_path
    stx dst
    jsr copy_z
    ldx #rec_path
    stx rec_tail
rec_parent
    ldaa 0,x
    beq rec_parent_done
    inx
    cmpa #'\'
    bne rec_parent
    stx rec_tail
    bra rec_parent
rec_parent_done
    ldx #rec_name
    stx src
    ldx rec_tail
    stx dst
    jsr copy_z
    clr rec_crc
    clr rec_crc+1
    ldx #filename
rec_hash
    ldaa 0,x
    beq rec_hash_done
    cmpa #'a'
    bcs rec_hash_upper
    cmpa #'z'
    bhi rec_hash_upper
    suba #32
rec_hash_upper
    jsr rec_crc_byte
    inx
    bra rec_hash
rec_hash_done
    ldx rec_tail
    ldaa rec_crc
    lsra
    lsra
    lsra
    lsra
    jsr hex_digit
    staa 4,x
    ldaa rec_crc
    jsr hex_digit
    staa 5,x
    ldaa rec_crc+1
    lsra
    lsra
    lsra
    lsra
    jsr hex_digit
    staa 6,x
    ldaa rec_crc+1
    jsr hex_digit
    staa 7,x
    rts
rec_select
    ldx rec_tail
    ldaa rec_slot
    adda #'0'
    staa 11,x
    rts
rec_bit_for_slot
    ldaa #1
    ldab rec_slot
rec_bit_shift
    tstb
    beq rec_bit_done
    asla
    decb
    bra rec_bit_shift
rec_bit_done
    staa rec_bit
    rts
rec_close
    ldaa rec_handle
    int $4e
    rts
; Read and validate only the commit trailer. Errors never delete a file.
rec_header
    jsr rec_select
    ldx #rec_path
    stx open_table
    ldx #0
    stx v_open_tab_2
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    beq rec_header_open
    rts
rec_header_open
    stab rec_handle
    tba
    ldx #rec_position
    int $51
    tsta
    beq rec_header_size
    jmp rec_bad_close
rec_header_size
    ldx #rec_position
    jsr q_load
    ldx #rec_128
    jsr q_sub
    bcc rec_header_seek
    jmp rec_bad_close
rec_header_seek
    ldx #rec_position
    jsr q_store
    ldaa rec_handle
    clrb
    int $50
    tsta
    beq rec_header_read
    jmp rec_bad_close
rec_header_read
    ldx #rec_buffer
    stx io_table
    ldx #128
    jsr rec_read
    tsta
    beq rec_header_magic
    jmp rec_bad_close
rec_header_magic
    ldx rec_buffer
    cpx #$4e43
    beq *+5
    jmp rec_bad_close
    ldx rec_buffer+2
    cpx #$5231
    beq *+5
    jmp rec_bad_close
    ; The identity is fixed width and must be terminated inside its field.
    tst rec_buffer+83
    beq *+5
    jmp rec_bad_close
    ldx #rec_buffer+4
    stx src
    ldx #filename
    stx dst
    jsr rec_same_path
    beq *+5
    jmp rec_bad_close
    ldx rec_buffer+126
    stx rec_expect
    clr rec_crc
    clr rec_crc+1
    ldx #126
    stx rec_count
    ldx #rec_buffer
    jsr rec_crc_block
    ldx rec_crc
    cpx rec_expect
    beq *+5
    jmp rec_bad_close
    ldx #rec_buffer+88
    jsr q_load
    ldx #rec_position
    jsr q_cmp
    beq *+5
    jmp rec_bad_close
    ldx #rec_length
    jsr q_store
    ldx #rec_buffer+84
    jsr q_load
    ldx #rec_candidate
    jsr q_store
    ldx rec_buffer+96
    stx rec_payload
    clra
    rts
rec_bad_close
    jsr rec_close
    ldaa #$fe
    rts
rec_read
    stx rec_count
    stx v_io_table_2
    ldaa rec_handle
    ldx #io_table
    int $4c
    tsta
    bne rec_io_return
    cpx rec_count
    beq rec_io_return
    ldaa #3
rec_io_return
    rts
rec_scan
    ldaa #$ff
    staa rec_last
    clr rec_available
    clr rec_slot
    ldx #rec_zero
    jsr q_load
    ldx #rec_generation
    jsr q_store
rec_scan_slot
    jsr rec_bit_for_slot
    jsr rec_header
    cmpa #11
    beq rec_scan_available
    tsta
    bne rec_scan_next
    jsr rec_close
    ldaa rec_available
    oraa rec_bit
    staa rec_available
    ldaa rec_skip
    bita rec_bit
    bne rec_scan_next
    ldx #rec_candidate
    jsr q_load
    ldx #rec_generation
    jsr q_cmp
    bcs rec_scan_next
    jsr q_store
    ldaa rec_slot
    staa rec_last
    bra rec_scan_next
rec_scan_available
    ldaa rec_available
    oraa rec_bit
    staa rec_available
rec_scan_next
    inc rec_slot
    ldaa rec_slot
    cmpa #4
    bcs rec_scan_slot
    rts
; Verify the full payload before offering it. Try the older copy after a
; bad/truncated newest one; the interrupted file remains available for diagnosis.
rec_open
    jsr rec_paths
rec_open_scan
    jsr rec_scan
    ldaa rec_last
    cmpa #$ff
    bne *+5
    jmp rec_open_none
    staa rec_slot
    jsr rec_header
    tsta
    beq *+5
    jmp rec_open_skip
    ldx #rec_buffer+92
    jsr q_load
    ldx #rec_candidate
    jsr q_store
    ldaa rec_handle
    clrb
    ldx #rec_zero
    int $50
    tsta
    beq *+5
    jmp rec_open_bad
    clr rec_crc
    clr rec_crc+1
    ldx #rec_length
    jsr q_load
    ldx #rec_position
    jsr q_store
rec_verify
    ldx #rec_position
    jsr q_load
    jsr q_test
    beq rec_verified
    ldx #256
    ldaa rec_position
    oraa rec_position+1
    bne rec_verify_read
    ldaa rec_position+2
    cmpa #1
    bcc rec_verify_read
    ldx rec_position+2
rec_verify_read
    stx rec_count
    ldx #save_buffer
    stx io_table
    ldx rec_count
    jsr rec_read
    tsta
    beq *+5
    jmp rec_open_bad
    ldx rec_count
    stx save_length
    ldx #save_buffer
    jsr rec_crc_block
    ldx #rec_position
    jsr q_load
    ldaa v_q_3
    suba v_save_len_1
    staa v_q_3
    ldaa v_q_2
    sbca save_length
    staa v_q_2
    ldaa v_q_1
    sbca #0
    staa v_q_1
    ldaa q
    sbca #0
    staa q
    ldx #rec_position
    jsr q_store
    ldaa #$ff
    staa poll_count
    jsr editor_poll
    tsta
    beq *+5
    jmp rec_open_decline
    bra rec_verify
rec_verified
    ldx rec_crc
    cpx rec_payload
    beq *+5
    jmp rec_open_bad
    ldx #rec_prompt
    jsr confirm
    cmpa #'Y'
    bne rec_open_decline
    ldaa rec_handle
    staa handles
    inc opened
    inc rec_restored
    inc modified
    ldx #rec_path
    stx src
    ldx #base_path
    stx dst
    jsr copy_z
    ldx #rec_length
    jsr q_load
    ldx #file_sizes
    jsr q_store
    ldx #doc_size
    jsr q_store
    ldx #rec_candidate
    jsr q_load
    ldx #doc_size
    jsr q_cmp
    bls rec_restore_cursor
    ldx #rec_zero
    jsr q_load
rec_restore_cursor
    ldx #e_cursor
    jsr q_store
rec_open_none
    clra
    rts
rec_open_decline
    inc rec_declined
    jsr rec_close
    bra rec_open_none
rec_open_bad
    jsr rec_close
rec_open_skip
    jsr rec_bit_for_slot
    ldaa rec_skip
    oraa rec_bit
    staa rec_skip
    jmp rec_open_scan
; A cheap idle hook; no disk access or window from inside mouse_wait.
rec_changed
    ldaa #1
    staa rec_dirty
    ldx #6000
    stx rec_time
    ldaa $18
    staa rec_prev
    rts
rec_idle
    ldaa mouse_context
    cmpa #1
    bne rec_idle_none
    tst rec_disabled
    bne rec_idle_none
    tst rec_dirty
    beq rec_idle_none
    tst modified
    beq rec_idle_none
    ldaa $18
    tab
    suba rec_prev
    bcc rec_idle_delta
    adda #100
rec_idle_delta
    stab rec_prev
    tab
    ldaa rec_time+1
    sba
    staa rec_time+1
    bcc rec_idle_test
    tst rec_time
    beq rec_idle_due
    dec rec_time
rec_idle_test
    ldaa rec_time
    oraa rec_time+1
    bne rec_idle_none
rec_idle_due
    ldaa #$d1
    rts
rec_idle_none
    ldaa #$ff
    rts
rec_checkpoint
    tst modified
    bne rec_checkpoint_start
    clra
    rts
rec_checkpoint_start
    clr rec_writing
    tst save_open
    beq rec_checkpoint_free
    ldaa #3
    rts
rec_checkpoint_free
    jsr rec_paths
    ; Recheck ownership before CREATE, including files added through HG.
    clr rec_skip
    jsr rec_scan
    clr rec_slot
rec_choose
    ldaa rec_slot
    cmpa rec_last
    beq rec_choose_next
    jsr rec_bit_for_slot
    ldaa rec_available
    bita rec_bit
    beq rec_choose_next
    jsr rec_select
    ldx #rec_path
    stx src
    ldx #base_path
    stx dst
    jsr rec_same_path
    bne rec_choose_ready
rec_choose_next
    inc rec_slot
    ldaa rec_slot
    cmpa #4
    bcs rec_choose
    ldaa #12
    rts
rec_choose_ready
    ldx #rec_generation
    jsr q_load
    jsr q_inc
    ldx #rec_generation
    jsr q_store
    ldx #rec_path
    stx src
    ldx #save_temp
    stx dst
    jsr copy_z
    ldx #save_temp
    stx open_table
    ldx #0
    stx v_open_tab_2
    clra
    ldx #open_table
    int $4b
    tsta
    beq rec_checkpoint_created
    rts
rec_checkpoint_created
    stab save_handle
    inc save_open
    inc rec_writing
    clr rec_crc
    clr rec_crc+1
    ldaa #3
    staa v_block_st_104
    clr v_block_st_100
    clr v_block_st_101
    clr v_block_st_102
    clr v_block_st_103
    ldx #doc_size
    jsr q_load
    ldx #v_block_st_96
    jsr q_store
    ldx #rec_title
    jsr window_open
    ldx #filename
    ldaa #8
    jsr window_line
    jmp save_strea_2340
rec_crc_write
    ldx save_length
    stx rec_count
    ldx #save_buffer
    jmp rec_crc_block
rec_trailer
    ldx rec_crc
    stx rec_payload
    ldx #rec_buffer
    ldab #128
rec_trailer_clear
    clr 0,x
    inx
    decb
    bne rec_trailer_clear
    ldx #$4e43
    stx rec_buffer
    ldx #$5231
    stx rec_buffer+2
    ldx #filename
    stx src
    ldx #rec_buffer+4
    stx dst
    jsr copy_z
    ldx #rec_generation
    jsr q_load
    ldx #rec_buffer+84
    jsr q_store
    ldx #doc_size
    jsr q_load
    ldx #rec_buffer+88
    jsr q_store
    ldx #e_cursor
    jsr q_load
    ldx #rec_buffer+92
    jsr q_store
    ldx rec_payload
    stx rec_buffer+96
    clr rec_crc
    clr rec_crc+1
    ldx #126
    stx rec_count
    ldx #rec_buffer
    jsr rec_crc_block
    ldx rec_crc
    stx rec_buffer+126
    ldx #rec_buffer
    stx io_table
    ldx #128
    stx v_io_table_2
    ldaa save_handle
    ldx #io_table
    int $4d
    tsta
    bne rec_trailer_return
    cpx #128
    beq rec_trailer_return
    ldaa #12
rec_trailer_return
    rts
rec_complete
    clr rec_writing
    clr rec_dirty
    clr rec_disabled
    clr rec_declined
    ldaa rec_slot
    staa rec_last
    clra
    rts
; Called after the backing file is closed on a normal editor exit.
rec_cleanup
    tst rec_declined
    bne rec_cleanup_done
    jsr rec_paths
    clr rec_slot
rec_cleanup_slot
    jsr rec_header
    tsta
    bne rec_cleanup_next
    jsr rec_close
    ldx #rec_path
    int $4f
rec_cleanup_next
    inc rec_slot
    ldaa rec_slot
    cmpa #4
    bcs rec_cleanup_slot
    tst rec_restored
    beq rec_cleanup_done
    ; A Save invalidates this trailer but the immutable payload remained open.
    ldx #base_path
    int $4f
rec_cleanup_done
    rts
rec_saved
    ; Remove obsolete recovery offers after Save, including Save As. Invalidate
    ; only the trailer of an open backing; its payload and Undo remain intact.
    clr rec_dirty
    clr rec_declined
    jsr rec_paths
    clr rec_slot
rec_saved_slot
    jsr rec_header
    tsta
    bne rec_saved_next
    jsr rec_close
    ldx #rec_path
    stx src
    ldx #base_path
    stx dst
    jsr rec_same_path
    beq rec_saved_backing
    ldx #rec_path
    int $4f
    bra rec_saved_next
rec_saved_backing
    ldx #rec_path
    stx open_table
    ldx #0
    stx v_open_tab_2
    ldaa #3
    ldx #open_table
    int $4a
    tsta
    bne rec_saved_next
    stab rec_handle
    tba
    clrb
    ldx #rec_position
    int $50
    tsta
    bne rec_saved_close
    clr rec_buffer
    ldx #rec_buffer
    stx io_table
    ldx #1
    stx v_io_table_2
    ldaa rec_handle
    ldx #io_table
    int $4d
rec_saved_close
    jsr rec_close
rec_saved_next
    inc rec_slot
    ldaa rec_slot
    cmpa #4
    bcs rec_saved_slot
    rts
rec_result
    clr rec_writing
    tsta
    beq rec_result_done
    inc rec_disabled
rec_result_done
    rts
rec_same_path
    ldx src
    ldaa 0,x
    inx
    stx src
    cmpa #'a'
    bcs rec_same_path_left
    cmpa #'z'
    bhi rec_same_path_left
    anda #$df
rec_same_path_left
    staa path_char
    ldx dst
    ldaa 0,x
    inx
    stx dst
    cmpa #'a'
    bcs rec_same_path_compare
    cmpa #'z'
    bhi rec_same_path_compare
    anda #$df
rec_same_path_compare
    cmpa path_char
    bne rec_same_path_done
    tsta
    bne rec_same_path
rec_same_path_done
    rts
    end
