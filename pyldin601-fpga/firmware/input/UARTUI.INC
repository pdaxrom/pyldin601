; Modal windows preserve all terminal cells and keep serial RX serviced.
ui_status
    ldaa #24
    ldx #ui_keys
    tst local_echo
    beq ui_status_ready
    ldx #ui_keys_on
ui_status_ready
    jmp ui_line
ui_line
    stx ui_text
    staa t_row
    clr t_col
    ldaa columns
    staa ui_left
    tst ui_active
    beq ui_line_address
    ldaa t_row
    cmpa #5
    bcs ui_line_address
    cmpa #20
    bcc ui_line_address
    ldaa #2
    staa t_col
    ldaa columns
    suba #4
    staa ui_left
ui_line_address
    jsr vt_address
    stx ui_dest
ui_line_loop
    ldx ui_text
    ldaa 0,x
    beq ui_line_space
    inx
    stx ui_text
    bra ui_line_char
ui_line_space
    ldaa #' '
ui_line_char
    staa ui_char
    ldx ui_dest
    ldaa cell_bytes
    cmpa #2
    bne ui_line_plain
    ldaa #$17
    staa 0,x
    inx
ui_line_plain
    ldaa ui_char
    staa 0,x
    inx
    stx ui_dest
    tst transfer
    bne ui_line_no_pump
    jsr pump
ui_line_no_pump
    dec ui_left
    beq *+5
    jmp ui_line_loop
    rts
ui_begin
    inc ui_active
    ldaa #19
    jsr raw_send
    ldaa #1
    staa flow_stopped
    ldx screen
    stx t_move+2
    ldx #ui_saved
    stx t_move+4
    ldaa #25
    jsr vt_dma_rows
    tsta
    beq ui_begin_frame
    ldx screen
    stx ui_source
    ldx #ui_saved
    stx ui_target
    ldaa #25
    staa ui_rows
ui_save_row
    ldaa pitch
    staa ui_left
ui_save_byte
    ldx ui_source
    ldaa 0,x
    inx
    stx ui_source
    ldx ui_target
    staa 0,x
    inx
    stx ui_target
    jsr pump
    dec ui_left
    bne ui_save_byte
    dec ui_rows
    bne ui_save_row
ui_begin_frame
    ldaa #5
    staa ui_row
ui_frame_row
    ldaa ui_row
    staa t_row
    jsr ui_frame
    inc ui_row
    ldaa ui_row
    cmpa #20
    bcs ui_frame_row
    ldaa #5
    ldx #ui_title
    jsr ui_line
    ldaa #19
    ldx #ui_cancel
    jsr ui_line
    rts
ui_frame
    clr t_col
    jsr vt_address
    ldaa #$d3
    ldab t_row
    cmpb #5
    bne ui_frame_left_bottom
    ldaa #$da
ui_frame_left_bottom
    cmpb #19
    bne ui_frame_left
    ldaa #$c0
ui_frame_left
    jsr ui_emit
    ldaa columns
    suba #2
    staa ui_left
    ldaa #' '
    ldab t_row
    cmpb #5
    beq ui_frame_horizontal
    cmpb #19
    bne ui_frame_fill
ui_frame_horizontal
    ldaa #$c4
ui_frame_fill
    staa ui_fill
ui_frame_next
    ldaa ui_fill
    jsr ui_emit
    jsr pump
    dec ui_left
    bne ui_frame_next
    ldaa #$d3
    ldab t_row
    cmpb #5
    bne ui_frame_right_bottom
    ldaa #$cf
ui_frame_right_bottom
    cmpb #19
    bne ui_emit
    ldaa #$d9
ui_emit
    staa ui_char
    ldaa cell_bytes
    cmpa #2
    bne ui_emit_plain
    ldaa #$17
    staa 0,x
    inx
ui_emit_plain
    ldaa ui_char
    staa 0,x
    inx
    rts

ui_end
    clr transfer
    clr x_finished
    ldx #ui_saved
    stx t_move+2
    ldx screen
    stx t_move+4
    ldaa #25
    jsr vt_dma_rows
    tsta
    beq ui_end_done
    ldx #ui_saved
    stx ui_source
    ldx screen
    stx ui_target
    ldaa #25
    staa ui_rows
ui_restore_row
    ldaa pitch
    staa ui_left
ui_restore_byte
    ldx ui_source
    ldaa 0,x
    inx
    stx ui_source
    ldx ui_target
    staa 0,x
    inx
    stx ui_target
    jsr pump
    dec ui_left
    bne ui_restore_byte
    dec ui_rows
    bne ui_restore_row
ui_end_done
    clr ui_active
    jsr vt_cursor
    jsr pump
    rts
ui_poll
    tst x_finished
    beq ui_poll_pump
    ldaa $e646
    bita #1
    beq ui_poll_pump
    ldaa $e647
    cmpa #4
    bne ui_poll_pump
    ldaa #6
    jsr raw_send
ui_poll_pump
    tst transfer
    bne ui_poll_key
    jsr pump
ui_poll_key
    int $10
    cmpa #$ff
    beq ui_poll
    int $11
    rts
ui_help
    jsr ui_begin
    ldaa #7
    ldx #ui_help1
    jsr ui_line
    ldaa #9
    ldx #ui_help2
    jsr ui_line
    ldaa #11
    ldx #ui_help3
    jsr ui_line
    ldaa #13
    ldx #ui_help4
    jsr ui_line
    ldaa #15
    ldx #ui_help5
    jsr ui_line
    jsr ui_poll
    jmp ui_end
ui_filename
    clr input
    clr ui_length
    ldaa #7
    ldx #ui_rx
    tst x_send
    beq ui_filename_label
    ldx #ui_tx
ui_filename_label
    jsr ui_line
    ldaa #9
    ldx #ui_path
    jsr ui_line
ui_filename_draw
    ldaa ui_length
    clr ui_offset
    ldab columns
    subb #5
    sba
    bcs ui_filename_offset
    staa ui_offset
ui_filename_offset
    ldx #input
    ldab ui_offset
    jsr add_b
    ldaa #11
    jsr ui_line
    ldaa #11
    staa t_row
    ldaa ui_length
    suba ui_offset
    adda #2
    cmpa columns
    bcs ui_filename_visible
    ldaa columns
    deca
ui_filename_visible
    staa t_col
    jsr vt_address
    ldaa cell_bytes
    cmpa #2
    bne ui_filename_mono
    inx
ui_filename_mono
    tst $fff7
    bmi ui_filename_caret
    inx
    inx
ui_filename_caret
    jsr vt_cursor_write
    jsr ui_poll
    cmpa #27
    bne *+5
    jmp ui_filename_cancel
    cmpa #$c0
    bne *+5
    jmp ui_filename_enter
    cmpa #127
    beq ui_filename_back
    cmpa #8
    beq ui_filename_back
    cmpa #32
    bcc *+5
    jmp ui_filename_draw
    cmpa #127
    bcs *+5
    jmp ui_filename_draw
    ldab ui_length
    cmpb #79
    bcs *+5
    jmp ui_filename_draw
    ldx #input
    jsr add_b
    staa 0,x
    clr 1,x
    inc ui_length
    jmp ui_filename_draw
ui_filename_back
    tst ui_length
    bne *+5
    jmp ui_filename_draw
    dec ui_length
    ldab ui_length
    ldx #input
    jsr add_b
    clr 0,x
    jmp ui_filename_draw
ui_filename_enter
    tst ui_length
    bne *+5
    jmp ui_filename_draw
    clc
    rts
ui_filename_cancel
    sec
    rts
ui_result
    ; X=message. Explicit acknowledgement keeps a transfer error readable.
    ldaa #15
    jsr ui_line
    ldaa #19
    ldx #ui_any
    jsr ui_line
    jsr ui_poll
    rts
ui_progress
    ldx #ui_meter
    ldaa #'['
    staa 0,x
    inx
    ldaa #30
    staa ui_left
ui_meter_blank
    ldaa #'.'
    staa 0,x
    inx
    dec ui_left
    bne ui_meter_blank
    ldaa #']'
    staa 0,x
    clr 1,x
    tst x_send
    bne ui_meter_send
    ; Receive length is unknown: moving marker plus exact byte counter.
    ldaa x_block
    anda #15
    asla
    cmpa #30
    bcs ui_meter_receive_index
    clra
ui_meter_receive_index
    tab
    ldx #ui_meter+1
    jsr add_b
    ldaa #'#'
    staa 0,x
    bra ui_meter_ready
ui_meter_send
    jsr ui_fraction
    ldx #ui_meter+1
    ldab ui_filled
    beq ui_meter_ready
ui_meter_fill
    ldaa #'#'
    staa 0,x
    inx
    decb
    bne ui_meter_fill
ui_meter_ready
    ldaa #10
    ldx #ui_meter
    jsr ui_line
    ldx #ui_numbers+8
    ldaa x_done
    jsr ui_hex_byte
    ldaa x_done+1
    jsr ui_hex_byte
    ldaa x_done+2
    jsr ui_hex_byte
    ldaa x_done+3
    jsr ui_hex_byte
    ldaa #12
    ldx #ui_numbers
    jsr ui_line
    ldx #ui_retry_text+9
    ldaa x_retries
    jsr ui_hex_byte
    ldaa #14
    ldx #ui_retry_text
    jsr ui_line
    rts
; floor(done*30/total) without overflowing 32-bit file lengths. At most
; thirty additions; the extra carry byte holds the 33-bit intermediate.
ui_fraction
    clr ui_filled
    ldaa x_done
    cmpa x_total
    bne ui_fraction_compare
    ldaa x_done+1
    cmpa x_total+1
    bne ui_fraction_compare
    ldaa x_done+2
    cmpa x_total+2
    bne ui_fraction_compare
    ldaa x_done+3
    cmpa x_total+3
ui_fraction_compare
    bcs ui_fraction_start
    ldaa #30
    staa ui_filled
    rts
ui_fraction_start
    ldx #0
    stx ui_fraction_value
    stx ui_fraction_value+2
    clr ui_fraction_value+4
    ldaa #30
    staa ui_iterations
ui_fraction_add
    ldaa ui_fraction_value+4
    adda x_done+3
    staa ui_fraction_value+4
    ldaa ui_fraction_value+3
    adca x_done+2
    staa ui_fraction_value+3
    ldaa ui_fraction_value+2
    adca x_done+1
    staa ui_fraction_value+2
    ldaa ui_fraction_value+1
    adca x_done
    staa ui_fraction_value+1
    bcc ui_fraction_no_carry
    inc ui_fraction_value
ui_fraction_no_carry
    tst ui_fraction_value
    bne ui_fraction_subtract
    ldaa ui_fraction_value+1
    cmpa x_total
    bne ui_fraction_test
    ldaa ui_fraction_value+2
    cmpa x_total+1
    bne ui_fraction_test
    ldaa ui_fraction_value+3
    cmpa x_total+2
    bne ui_fraction_test
    ldaa ui_fraction_value+4
    cmpa x_total+3
ui_fraction_test
    bcs ui_fraction_next
ui_fraction_subtract
    inc ui_filled
    ldaa ui_fraction_value+4
    suba x_total+3
    staa ui_fraction_value+4
    ldaa ui_fraction_value+3
    sbca x_total+2
    staa ui_fraction_value+3
    ldaa ui_fraction_value+2
    sbca x_total+1
    staa ui_fraction_value+2
    ldaa ui_fraction_value+1
    sbca x_total
    staa ui_fraction_value+1
    ldaa ui_fraction_value
    sbca #0
    staa ui_fraction_value
ui_fraction_next
    dec ui_iterations
    beq *+5
    jmp ui_fraction_add
    rts

ui_hex_byte
    tab
    lsra
    lsra
    lsra
    lsra
    bsr ui_hex_nibble
    tba
ui_hex_nibble
    anda #15
    adda #'0'
    cmpa #'9'
    bls ui_hex_store
    adda #7
ui_hex_store
    staa 0,x
    inx
    rts
ui_keys db 'F1Help F2Echo:Off F3Rx F4Tx F10Exit',0
ui_keys_on db 'F1Help F2Echo:On  F3Rx F4Tx F10Exit',0
ui_title db '--- UART / XMODEM-CRC ---',0
ui_blank db 0
ui_cancel db 'Esc: cancel transfer',0
ui_any db 'Press a key to return to terminal',0
ui_help1 db 'ANSI/VT100, 24 rows; XON/XOFF.',0
ui_help2 db 'Esc and arrows go to remote host.',0
ui_help3 db 'F2: local echo; F3: receive file.',0
ui_help4 db 'F4: send file; F10: exit UART.',0
ui_help5 db 'XMODEM: 128 bytes, CRC, pad kept.',0
ui_rx db 'Receive XMODEM-CRC (128 bytes)',0
ui_tx db 'Send XMODEM-CRC (128 bytes)',0
ui_path db 'File path (existing files protected):',0
    section
ui_active ds 1
ui_text ds 2
ui_dest ds 2
ui_char ds 1
ui_left ds 1
ui_source ds 2
ui_target ds 2
ui_rows ds 1
ui_row ds 1
ui_length ds 1
ui_offset ds 1
ui_fill ds 1
ui_fraction_value ds 5
ui_filled ds 1
ui_iterations ds 1
ui_saved ds 2200
ui_meter ds 33
ui_numbers ds 25
ui_retry_text ds 16
    ends
