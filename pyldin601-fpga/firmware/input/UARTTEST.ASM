; Binary FTDI-B diagnostic, MC6800 ISA. Host: tools/uart_board_test.py.
; Header at 19200: 55 AA rate lengthBE16 xor(all previous bytes).
; Switch rate, receive A5, send 5A, echo length bytes, send D/errors/rate.
; Host sends CC after draining TX; return to 19200 for the next header.
start
    ldaa $e644
    cmpa #'U'
    beq *+5
    jmp missing
    ldx #heading
    int $23
baseline
    ldaa #7
    jsr configure
    clr errors
    clr checksum
sync
    jsr receive
    cmpa #$55
    bne sync
    staa checksum
    jsr receive
    cmpa #$aa
    bne sync
    eora checksum
    staa checksum
    jsr receive
    cmpa #11
    bcc baseline
    staa rate
    eora checksum
    staa checksum
    jsr receive
    staa remaining
    eora checksum
    staa checksum
    jsr receive
    staa remaining+1
    eora checksum
    staa checksum
    jsr receive
    cmpa checksum
    bne baseline
    ldx remaining
    cpx #0
    beq baseline
    ldaa rate
    jsr configure
    clr errors
    jsr receive
    cmpa #$a5
    bne baseline
    ldaa #$5a
    jsr transmit
echo
    jsr receive
    jsr transmit
    ldx remaining
    dex
    stx remaining
    bne echo
    ldaa #'D'
    jsr transmit
    ldaa errors
    jsr transmit
    ldaa rate
    jsr transmit
    ; The host ACK proves the last stop bit has left the FPGA before reset.
    jsr receive
    cmpa #$cc
    jmp baseline
configure
    psha
    ldaa #3
    staa $e646
    pula
    staa $e645
    ldaa #$15
    staa $e646
    rts
receive
    ldaa $e646
    tab
    andb #$70
    orab errors
    stab errors
    bita #1
    bne received
    int $10
    cmpa #$ff
    beq receive
    int $11
    cmpa #27
    bne receive
    ; Discard the nested return addresses by terminating through UniDOS.
    ldaa #7
    jsr configure
    ldx #done
    int $23
    int $38
received
    ldaa $e647
    rts
transmit
    psha
tx_wait
    ldaa $e646
    bita #2
    beq tx_wait
    pula
    staa $e647
    rts
missing
    ldx #unavailable
    int $23
    int $38
heading db 13,10,'UARTTEST: FTDI B binary test; Esc exits.',13,10
    db 'Run uart_board_test.py on host. Waiting at 19200 8N1.',13,10,0
done db 13,10,'UARTTEST closed.',13,10,0
unavailable db 13,10,'UART hardware is unavailable.',13,10,0
    section
rate ds 1
remaining ds 2
checksum ds 1
errors ds 1
    ends
    end start
