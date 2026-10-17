; Native ANSI terminal and XMODEM-CRC. MC6800 ISA, 601/601A.
; All executable bytes are produced by UniAS. No ROM/FPGA change required.
start
    ldaa $e644
    cmpa #'U'
    beq *+5
    jmp unsupported
    ldaa #7
    staa baud_code
    ldx #default_rate
    stx rate_text
    int $3b
    cmpa #1
    bne *+5
    jmp configured
    cmpa #2
    beq argument
    jmp usage
argument
    ldaa #1
    ldx #input
    int $3c
    ldx #rates
next_rate
    ldab 0,x
    cmpb #$ff
    bne *+5
    jmp usage
    stab baud_code
    inx
    stx rate_text
    stx rate_pointer
    ldx #input
    stx input_pointer
compare_rate
    ldx input_pointer
    ldaa 0,x
    inx
    stx input_pointer
    ldx rate_pointer
    cmpa 0,x
    bne skip_rate
    inx
    stx rate_pointer
    tsta
    bne compare_rate
    bra configured
skip_rate
    ldaa 0,x
    inx
    tsta
    bne skip_rate
    jmp next_rate
usage
    ldx #usage_text
    int $23
    int $38
configured
    int $13
    staa saved_mode
    stab saved_attribute
    stx saved_base
    anda #3
    beq keep_text
    clra
    ldab #$70
keep_text
    int $12
    int $6d
    staa columns
    ldaa #1
    staa cell_bytes
    tst $fff7
    bpl monochrome
    tst $ed12
    bne monochrome
    inc cell_bytes
monochrome
    ldaa $e600
    staa saved_crtc
    ldaa #1
    staa $e600
    ldaa $e601
    staa pitch
    ; A private text framebuffer is readable ordinary RAM. The DOS default
    ; F000 screen sits under system ROM and cannot be read by CPU scrolls.
    ldx #terminal_screen
    stx screen
    ldaa #12
    staa $e600
    ldaa screen
    staa $e601
    ldaa #13
    staa $e600
    ldaa screen+1
    staa $e601
    ldaa saved_crtc
    staa $e600
    ldaa #3
    staa $e646
    ldaa baud_code
    staa $e645
    ldaa #$15
    staa $e646
    clr errors
    clr rx_head
    clr rx_tail
    clr tx_head
    clr tx_tail
    clr flow_stopped
    clr tx_paused
    clr local_echo
    clr transfer
    clr ui_active
    ldx #ignore_break
    clrb
    ldaa #4
    int $2f
    ldx #fail_io
    clrb
    ldaa #7
    int $2f
    jsr vt_reset
    jsr ui_status
terminal
    jsr pump
    ldaa rx_head
    cmpa rx_tail
    beq terminal_key
    ldab rx_tail
    ldx #rx_ring
    jsr add_b
    ldaa 0,x
    inc rx_tail
    jsr vt_byte
    jsr vt_cursor
terminal_key
    jsr pump
    int $10
    cmpa #$ff
    beq terminal
    int $11
    cmpa #$d2
    bne *+5
    jmp leave
    cmpa #$c9
    beq show_help
    cmpa #$ca
    beq toggle_echo
    cmpa #$cb
    beq receive_file
    cmpa #$cc
    beq send_file
    jsr vt_key
    jsr vt_cursor
    jmp terminal
show_help
    jsr ui_help
    jmp terminal
toggle_echo
    ldaa local_echo
    eora #1
    staa local_echo
    jsr ui_status
    jmp terminal
receive_file
    clr x_send
    jsr x_file
    jmp terminal
send_file
    ldaa #1
    staa x_send
    jsr x_file
    jmp terminal
leave
    ldaa tx_head
    cmpa tx_tail
    beq leave_release
    ldaa errors
    oraa #$20
    staa errors
leave_release
    ; Release a host paused by terminal flow control before returning to DOS.
    ldaa #17
    jsr raw_send
    ldaa saved_mode
    ldab saved_attribute
    ldx saved_base
    int $12
    ldx #done_text
    int $23
    ldaa errors
    beq finished
    ldx #error_text
    int $23
    ldaa errors
    psha
    lsra
    lsra
    lsra
    lsra
    jsr print_hex
    pula
    jsr print_hex
finished
    int $38
print_hex
    anda #15
    adda #'0'
    cmpa #'9'
    bls hex_ready
    adda #7
hex_ready
    int $22
    rts
unsupported
    ldx #no_uart
    int $23
    int $38

; Add unsigned B to X in constant time. A preserved, B destroyed.
add_b
    stx pointer
    psha
    ldaa pointer+1
    aba
    staa pointer+1
    bcc add_done
    inc pointer
add_done
    ldx pointer
    pula
    rts

; Drain hardware into a 255-byte ring. Called within slow screen operations.
; X/A/B preserved. XON/XOFF applies only to terminal mode, never file bytes.
pump
    psha
    pshb
    stx pump_x
pump_rx
    ldaa $e646
    tab
    andb #$70
    orab errors
    stab errors
    bita #1
    bne *+5
    jmp pump_flow
    ldaa $e647
    cmpa #19
    bne pump_xon
    ldaa #1
    staa tx_paused
    bra pump_rx
pump_xon
    cmpa #17
    bne pump_store
    clr tx_paused
    bra pump_rx
pump_store
    staa pump_char
    ldaa rx_head
    inca
    cmpa rx_tail
    beq pump_overflow
    ldab rx_head
    ldx #rx_ring
    jsr add_b
    ldaa pump_char
    staa 0,x
    inc rx_head
    jmp pump_rx
pump_overflow
    ldaa errors
    oraa #$20
    staa errors
    jmp pump_rx
pump_flow
    ldaa $e646
    bita #2
    beq pump_done
    ldaa rx_head
    suba rx_tail
    tst flow_stopped
    bne pump_resume
    cmpa #128
    bcs pump_transmit
    ldaa #19
    staa $e647
    inc flow_stopped
    bra pump_done
pump_resume
    tst ui_active
    bne pump_transmit
    cmpa #32
    bcc pump_transmit
    ldaa #17
    staa $e647
    clr flow_stopped
pump_transmit
    tst tx_paused
    bne pump_done
    ldaa $e646
    bita #2
    beq pump_done
    ldaa tx_head
    cmpa tx_tail
    beq pump_done
    ldx #tx_ring
    ldab tx_tail
    jsr add_b
    ldaa 0,x
    staa $e647
    ldaa tx_tail
    inca
    anda #127
    staa tx_tail

pump_done
    ldx pump_x
    pulb
    pula
    rts

; Queue outgoing terminal bytes. A remote XOFF must not lose keyboard
; input or prevent F10/UI operation; packet transfers bypass this queue.
term_send
    staa tx_char
    ldaa tx_head
    inca
    anda #127
    cmpa tx_tail
    beq term_send_full
    ldx #tx_ring
    ldab tx_head
    jsr add_b
    ldaa tx_char
    staa 0,x
    ldaa tx_head
    inca
    anda #127
    staa tx_head
    jsr pump
    tst local_echo
    beq term_send_done
    ldaa tx_char
    jsr vt_byte
term_send_done
    rts
term_send_full
    ldaa errors
    oraa #$20
    staa errors
    rts
; X=zero-terminated terminal reply; replies must not be locally echoed.
reply
    stx reply_ptr
    ldaa local_echo
    psha
    clr local_echo
reply_loop
    ldx reply_ptr
    ldaa 0,x
    beq reply_done
    inx
    stx reply_ptr
    jsr term_send
    bra reply_loop
reply_done
    pula
    staa local_echo
    rts

; Real BIOS 100-Hz clock; independent of CPU speed. A=seconds (1..10).
deadline
    tab
    clr time_left
    clr time_left+1
deadline_add
    ldaa time_left+1
    adda #100
    staa time_left+1
    bcc deadline_no_carry
    inc time_left
deadline_no_carry
    decb
    bne deadline_add
    ldaa $18
    staa time_prev
    rts
expired
    ldaa $18
    tab
    suba time_prev
    bcc expired_delta
    adda #100
expired_delta
    stab time_prev
    tab
    ldaa time_left+1
    sba
    staa time_left+1
    bcc expired_low_ok
    tst time_left
    beq expired_yes
    dec time_left
expired_low_ok
    ldaa time_left
    oraa time_left+1
    beq expired_yes
    clc
    rts
expired_yes
    clr time_left
    clr time_left+1
    sec
    rts

ignore_break
    rts
fail_io
    ldaa #3
    staa $06
    rts

    include UARTVT.INC
    include UARTUI.INC
    include UARTX.INC

done_text db 13,10,'UART closed.',13,10,0
error_text db 'UART RX errors (parity/overrun/framing): $',0
no_uart db 13,10,'UART hardware is unavailable.',13,10,0
usage_text db 'UART [150..115200]',13,10,'Rates: 150 300 600 1200 2400 4800 9600 19200 38400 57600 115200',13,10,0
rates
    db 0,'150',0,1,'300',0,2,'600',0,3,'1200',0,4,'2400',0
    db 5,'4800',0,6,'9600',0,7
default_rate db '19200',0
    db 8,'38400',0,9,'57600',0,10,'115200',0,$ff
    section
baud_code ds 1
rate_text ds 2
rate_pointer ds 2
input_pointer ds 2
input ds 80
saved_mode ds 1
saved_attribute ds 1
saved_base ds 2
saved_crtc ds 1
columns ds 1
pitch ds 1
cell_bytes ds 1
screen ds 2
terminal_screen ds 2200
pointer ds 2
pump_x ds 2
pump_char ds 1
errors ds 1
rx_head ds 1
rx_tail ds 1
rx_ring ds 256
flow_stopped ds 1
tx_paused ds 1
local_echo ds 1
tx_char ds 1
tx_head ds 1
tx_tail ds 1
tx_ring ds 128
reply_ptr ds 2
time_prev ds 1
time_left ds 2
    ends
    end start
