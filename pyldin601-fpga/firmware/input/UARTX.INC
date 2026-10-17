; XMODEM-CRC SOH/128. Disk I/O occurs only between whole packets.
x_file
    clr x_error
    clr x_finished
    clr x_started
    clr x_open
    clr x_cleanup_error
    clr x_temp_live
    clr x_retries
    clr x_had_blocks
    clr x_done
    clr x_done+1
    clr x_done+2
    clr x_done+3
    ldaa #1
    staa x_block
    ldx #ui_numbers_initial
    stx ui_text
    ldx #ui_numbers
    jsr x_copy
    ldx #ui_retry_initial
    stx ui_text
    ldx #ui_retry_text
    jsr x_copy
    jsr ui_begin
    jsr ui_filename
    bcc *+5
    jmp x_exit
    ldaa tx_head
    cmpa tx_tail
    beq x_terminal_drained
    ldx #x_busy_text
    jsr ui_result
    jmp x_cleanup
x_terminal_drained
    tst x_send
    beq x_prepare_receive
    ldx #input
    stx x_open_table
    ldx #0
    stx x_open_table+2
    ldaa #1
    ldx #x_open_table
    int $4a
    tsta
    beq *+5
    jmp x_disk_error
    stab x_handle
    inc x_open
    ldaa x_handle
    ldx #x_total
    int $51
    tsta
    beq *+5
    jmp x_disk_error
    bra x_begin
x_prepare_receive
    ldx #input
    jsr x_stat
    cmpa #11
    beq x_target_absent
    tsta
    bne *+5
    jmp x_exists
    jmp x_disk_error
x_target_absent
    jsr x_unique
    tsta
    beq *+5
    jmp x_disk_error
    ldx #x_temp
    stx x_open_table
    ldx #0
    stx x_open_table+2
    clra
    ldx #x_open_table
    int $4b
    tsta
    beq *+5
    jmp x_disk_error
    stab x_handle
    inc x_open
    inc x_temp_live
x_begin
    clr rx_head
    clr rx_tail
    clr tx_paused
    ldaa #1
    staa transfer
    ldaa #17
    jsr raw_send
    bcc *+5
    jmp x_failed
    jsr ui_progress
    tst x_send
    beq x_receive
    jsr x_transmit
    bra x_complete
x_receive
    jsr x_receive_loop
x_complete
    bcc *+5
    jmp x_failed
    ldaa x_handle
    int $4e
    clr x_open
    tsta
    beq *+5
    jmp x_disk_error
    tst x_send
    beq *+5
    jmp x_success
    ; Rename only a closed, complete file; use disposable DOS path copies.
    ldx #x_temp
    stx ui_text
    ldx #x_old
    jsr x_copy
    ldx #input
    stx ui_text
    ldx #x_new
    jsr x_copy
    ldx #x_old
    stx x_rename
    ldx #x_new
    stx x_rename+2
    ldx #x_rename
    int $56
    tsta
    bne x_disk_error
    clr x_temp_live
    ldaa #6
    jsr raw_send
    bcs x_failed
    ldaa #1
    staa x_finished

x_success
    ldx #x_ok
    jsr ui_result
    jmp x_cleanup
x_exists
    ldx #x_exists_text
    jsr ui_result
    jmp x_cleanup
x_disk_error
    staa x_dos_error
    ldaa #5
    staa x_error
x_failed
    jsr x_release
    tst transfer
    beq x_failed_message
    ldaa #24
    jsr raw_send
    ldaa #24
    jsr raw_send
x_failed_message
    tst x_cleanup_error
    beq x_failed_normal
    ldx #x_cleanup_text
    jmp x_failed_show
x_failed_normal
    ldx #x_fail_text
    ldaa x_error
    cmpa #2
    bne x_failed_remote
    ldx #x_cancel_text
x_failed_remote
    cmpa #3
    bne x_failed_disk
    ldx #x_remote_text
x_failed_disk
    cmpa #5
    bne x_failed_show
    ldx #x_disk_text
x_failed_show
    jsr ui_result
x_cleanup
    jsr x_release
    jmp x_exit
x_release
    tst x_open
    beq x_cleanup_temp
    ldaa x_handle
    int $4e
    clr x_open
    tsta
    beq x_cleanup_temp
    staa x_cleanup_error
x_cleanup_temp
    tst x_temp_live
    beq x_release_done
    ldx #x_temp
    int $4f
    tsta
    beq x_temp_removed
    staa x_cleanup_error
    rts
x_temp_removed
    clr x_temp_live
x_release_done
    rts

x_exit
    clr x_error
    jmp ui_end
raw_receive
    jsr deadline
raw_wait
    ldaa $e646
    tab
    andb #$70
    orab x_packet_bad
    stab x_packet_bad
    orab errors
    stab errors
    bita #1
    bne raw_ready
    jsr raw_cancel
    bcs raw_return
    jsr expired
    bcc raw_wait
    ldaa #1
    staa x_error
    sec
raw_return
    rts
raw_ready
    ldaa $e647
    clc
    rts
raw_cancel
    int $10
    cmpa #$ff
    beq raw_not_cancel
    int $11
    cmpa #27
    beq raw_abort
    cmpa #$d2
    bne raw_not_cancel
raw_abort
    ldaa #2
    staa x_error
    sec
    rts
raw_not_cancel
    clc
    rts
raw_send
    staa x_tx
    ldaa #2
    jsr deadline
raw_send_wait
    ldaa $e646
    bita #2
    bne raw_send_ready
    jsr raw_cancel
    bcc *+5
    jmp raw_return
    jsr expired
    bcc raw_send_wait
    ldaa #1
    staa x_error
    sec
    rts
raw_send_ready
    ldaa x_tx
    staa $e647
    clc
    rts
x_retry
    inc x_retries
    inc x_attempts
    ldaa x_error
    cmpa #2
    beq x_retry_fail
    ldaa x_attempts
    cmpa #10
    bcc x_retry_fail
    clc
    rts
x_retry_fail
    sec
    rts
x_remote_cancel
    ldaa #1
    jsr raw_receive
    bcs x_retry_fail
    cmpa #24
    bne x_protocol_error
    ldaa #3
    staa x_error
    sec
    rts
x_protocol_error
    ldaa #4
    staa x_error
    sec
    rts
x_purge
    clr x_purge_count
x_purge_byte
    ldaa #1
    jsr raw_receive
    bcs x_purge_end
    inc x_purge_count
    bne x_purge_byte
x_purge_end
    rts
x_receive_loop
    clr x_attempts
    ldaa #'C'
x_receive_request
    jsr raw_send
    bcc *+5
    jmp x_receive_return
x_receive_header
    clr x_packet_bad
    ldaa #10
    jsr raw_receive
    bcc *+5
    jmp x_receive_retry_purge
    cmpa #1
    beq x_receive_packet
    cmpa #2
    bne *+5
    jmp x_receive_fatal
    cmpa #4
    beq x_receive_eot
    cmpa #24
    beq *+5
    jmp x_receive_retry_purge
    jsr x_remote_cancel
    ldaa x_error
    cmpa #3
    bne *+5
    jmp x_receive_return
    jmp x_receive_retry_purge
x_receive_eot
    clc
    rts
x_receive_packet
    ldaa #1
    staa x_started
    ldx #x_packet
    stx x_ptr
    ldaa #132
    staa x_left
x_receive_byte
    ldaa #1
    jsr raw_receive
    bcc *+5
    jmp x_receive_retry_purge
    ldx x_ptr
    staa 0,x
    inx
    stx x_ptr
    dec x_left
    bne x_receive_byte
    tst x_packet_bad
    beq *+5
    jmp x_receive_retry
    ldaa x_packet
    coma
    cmpa x_packet+1
    beq *+5
    jmp x_receive_retry
    jsr x_crc
    ldx x_crc_value
    cpx x_packet+130
    beq *+5
    jmp x_receive_retry
    ldaa x_packet
    cmpa x_block
    beq x_receive_new
    tst x_had_blocks
    bne *+5
    jmp x_receive_retry
    inca
    cmpa x_block
    beq *+5
    jmp x_receive_fatal
    ldaa #6
    jmp x_receive_request
x_receive_new
    ldx #x_packet+2
    stx x_io
    ldx #128
    stx x_io+2
    ldaa x_handle
    ldx #x_io
    int $4d
    tsta
    bne x_receive_disk
    cpx #128
    bne x_receive_disk
    ldaa #1
    staa x_had_blocks
    inc x_block
    jsr x_add_done
    clr x_attempts
    jsr ui_progress
    ldaa #6
    jmp x_receive_request
x_receive_disk
    ldaa #5
    staa x_error
    sec
    rts
x_receive_fatal
    jmp x_protocol_error
x_receive_retry_purge
    ldaa x_error
    cmpa #2
    beq x_receive_return
    jsr x_purge
x_receive_retry
    jsr x_retry
    bcs x_receive_return
    jsr ui_progress
    ldaa #21
    tst x_started
    bne x_receive_nak
    ldaa #'C'
x_receive_nak
    jmp x_receive_request
x_receive_return
    sec
    rts
x_transmit
    clr x_attempts
x_sender_start
    ldaa #10
    jsr raw_receive
    bcs x_sender_retry
    cmpa #'C'
    beq x_send_read
    cmpa #24
    bne x_sender_retry
    jsr x_remote_cancel
    ldaa x_error
    cmpa #3
    bne *+5
    jmp x_send_return
x_sender_retry
    jsr x_retry
    bcc x_sender_start
    sec
    rts
x_send_read
    ldx #x_packet+2
    stx x_io
    ldx #128
    stx x_io+2
    ldaa x_handle
    ldx #x_io
    int $4c
    tsta
    beq *+5
    jmp x_receive_disk
    cpx #0
    bne *+5
    jmp x_send_eot_start
    stx x_actual
    ldx #x_packet+2
    ldab x_actual+1
    jsr add_b
    ldaa #128
    suba x_actual+1
    staa x_left
    beq x_send_full
x_send_pad
    ldaa #26
    staa 0,x
    inx
    dec x_left
    bne x_send_pad
x_send_full
    ldaa x_block
    staa x_packet
    coma
    staa x_packet+1
    jsr x_crc
    ldx x_crc_value
    stx x_packet+130
    clr x_attempts
x_send_packet
    ldaa #1
    jsr raw_send
    bcc *+5
    jmp x_send_retry
    ldx #x_packet
    stx x_ptr
    ldaa #132
    staa x_left
x_send_byte
    ldx x_ptr
    ldaa 0,x
    inx
    stx x_ptr
    jsr raw_send
    bcs x_send_retry
    dec x_left
    bne x_send_byte
    ldaa #10
    jsr raw_receive
    bcs x_send_retry
    cmpa #6
    beq x_send_ack
    cmpa #24
    bne x_send_retry
    jsr x_remote_cancel
    ldaa x_error
    cmpa #3
    bne *+5
    jmp x_send_return
x_send_retry
    jsr x_retry
    bcc *+5
    jmp x_send_return
    jsr ui_progress
    jmp x_send_packet
x_send_ack
    inc x_block
    jsr x_add_done
    jsr ui_progress
    jmp x_send_read
x_send_eot_start
    clr x_attempts
x_send_eot
    ldaa #4
    jsr raw_send
    bcs x_eot_retry
    ldaa #10
    jsr raw_receive
    bcs x_eot_retry
    cmpa #6
    beq x_send_success
    cmpa #24
    bne x_eot_retry
    jsr x_remote_cancel
    ldaa x_error
    cmpa #3
    beq x_send_return
x_eot_retry
    jsr x_retry
    bcc x_send_eot
x_send_return
    sec
    rts
x_send_success
    clc
    rts
x_add_done
    ldaa x_done+3
    adda #128
    staa x_done+3
    bcc x_add_return
    inc x_done+2
    bne x_add_return
    inc x_done+1
    bne x_add_return
    inc x_done
x_add_return
    rts
; CRC-16/XMODEM: polynomial 1021, init 0000, high byte first.
x_crc
    clr x_crc_value
    clr x_crc_value+1
    ldx #x_packet+2
    stx x_crc_ptr
    ldaa #128
    staa x_crc_left
x_crc_byte
    ldx x_crc_ptr
    ldaa 0,x
    eora x_crc_value
    staa x_crc_value
    inx
    stx x_crc_ptr
    ldab #8
x_crc_bit
    asl x_crc_value+1
    rol x_crc_value
    bcc x_crc_next_bit
    ldaa x_crc_value
    eora #$10
    staa x_crc_value
    ldaa x_crc_value+1
    eora #$21
    staa x_crc_value+1
x_crc_next_bit
    decb
    bne x_crc_bit
    dec x_crc_left
    bne x_crc_byte
    rts
x_stat
    stx x_find+4
    ldx #x_find_state
    stx x_find
    ldx #x_dir
    stx x_find+2
    clra
    clrb
    ldx #x_find
    int $42
    rts
x_copy
    stx x_copy_dst
x_copy_loop
    ldx ui_text
    ldaa 0,x
    inx
    stx ui_text
    ldx x_copy_dst
    staa 0,x
    inx
    stx x_copy_dst
    tsta
    bne x_copy_loop
    rts
x_unique
    ldx #input
    stx ui_text
    ldx #x_temp
    jsr x_copy
    ldx #x_temp
    stx x_tail
x_tail_loop
    ldaa 0,x
    beq x_tail_ready
    inx
    cmpa #92
    beq x_tail_mark
    cmpa #':'
    bne x_tail_loop
x_tail_mark
    stx x_tail
    bra x_tail_loop
x_tail_ready
    ldx #0
    stx x_nonce
x_unique_next
    ldx x_tail
    ldaa #'U'
    staa 0,x
    ldaa #'T'
    staa 1,x
    inx
    inx
    ldaa x_nonce
    jsr ui_hex_byte
    ldaa x_nonce+1
    jsr ui_hex_byte
    ldaa #'.'
    staa 0,x
    ldaa #'T'
    staa 1,x
    ldaa #'M'
    staa 2,x
    ldaa #'P'
    staa 3,x
    clr 4,x
    ldx #input
    stx ui_text
    ldx #x_temp
x_unique_compare
    ldaa 0,x
    staa x_compare
    inx
    stx x_ptr
    ldx ui_text
    ldaa 0,x
    oraa #$20
    staa x_compare+1
    ldaa x_compare
    oraa #$20
    cmpa x_compare+1
    bne x_unique_stat
    inx
    stx ui_text
    ldx x_ptr
    tst x_compare
    bne x_unique_compare
    jmp x_unique_increment

x_unique_stat
    ldx #x_temp
    jsr x_stat
    cmpa #11
    beq x_unique_found
    tsta
    bne x_unique_return
x_unique_increment
    ldx x_nonce
    inx
    stx x_nonce
    cpx #0
    beq *+5
    jmp x_unique_next
    ldaa #17
x_unique_return
    rts
x_unique_found
    clra
    rts
ui_numbers_initial db 'Bytes: $00000000',0
ui_retry_initial db 'Retries: 00',0
x_busy_text db 'Pending terminal TX; wait for XON.',0
x_ok db 'Complete. Received padding is kept.',0
x_fail_text db 'Transfer failed (timeout/protocol).',0
x_cancel_text db 'Cancelled; partial receive removed.',0
x_remote_text db 'Remote cancelled; partial removed.',0
x_disk_text db 'Disk error; transfer stopped.',0
x_cleanup_text db 'Cleanup failed; check UTxxxx.TMP.',0
x_exists_text db 'Destination exists. Choose new name.',0
    section
transfer ds 1
x_send ds 1
x_error ds 1
x_dos_error ds 1
x_cleanup_error ds 1
x_total ds 4
x_open ds 1
x_handle ds 1
x_temp_live ds 1
x_retries ds 1
x_attempts ds 1
x_had_blocks ds 1
x_started ds 1
x_finished ds 1
x_block ds 1
x_done ds 4
x_tx ds 1
x_packet_bad ds 1
x_purge_count ds 1
x_packet ds 132
x_ptr ds 2
x_left ds 1
x_actual ds 2
x_crc_value ds 2
x_crc_ptr ds 2
x_crc_left ds 1
x_io ds 4
x_open_table ds 4
x_rename ds 4
x_find ds 6
x_find_state ds 19
x_dir ds 32
x_temp ds 96
x_old ds 96
x_new ds 96
x_tail ds 2
x_nonce ds 2
x_compare ds 2
x_copy_dst ds 2
    ends
