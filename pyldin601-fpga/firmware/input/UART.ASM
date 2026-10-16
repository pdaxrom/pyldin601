; FT2232 channel-B terminal. Native MC6800 code; both computer models/CPUs.
; The existing keyboard/video BIOS remains in charge of console focus.
start
    clr pending
    clr local_echo
    clr errors
    clr changed_mode
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
    beq configured
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
    beq usage
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
    bra next_rate
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
    beq console_ready
    inc changed_mode
    clra
    clrb
    int $12
console_ready
    ldaa #3
    staa $e646
    ldaa baud_code
    staa $e645
    ldaa #$15
    staa $e646
    ldx #heading
    int $23
    ldx rate_text
    int $23
    ldx #keys
    int $23
terminal
    ldaa $e646
    tab
    andb #$70
    orab errors
    stab errors
    lsra
    bcc keyboard
    ldaa $e647
    int $22
keyboard
    tst pending
    bne transmit
    int $10
    cmpa #$ff
    beq terminal
    int $11
    cmpa #27
    beq leave
    cmpa #$ca
    beq toggle_echo
    cmpa #$c0
    bne not_enter
    ldaa #13
not_enter
    cmpa #$ed
    bne not_tab
    ldaa #9
not_tab
    cmpa #127
    bne not_backspace
    ldaa #8
not_backspace
    cmpa #$c0
    bcc terminal
    staa character
    inc pending
transmit
    ldaa $e646
    bita #2
    beq terminal
    ldaa character
    staa $e647
    clr pending
    tst local_echo
    beq terminal
    int $22
    bra terminal
toggle_echo
    ldaa local_echo
    eora #1
    staa local_echo
    bra terminal
leave
    tst changed_mode
    beq report
    ldaa saved_mode
    ldab saved_attribute
    ldx saved_base
    int $12
report
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
    bsr hex
    pula
    bsr hex
finished
    int $38

hex
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
heading db 13,10,'FTDI channel B UART, ',0
keys db ' baud 8N1',13,10,'Esc Exit; F2 Local echo on/off',13,10,0
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
pending ds 1
character ds 1
local_echo ds 1
errors ds 1
baud_code ds 1
rate_text ds 2
rate_pointer ds 2
input_pointer ds 2
input ds 80
changed_mode ds 1
saved_mode ds 1
saved_attribute ds 1
saved_base ds 2
    ends
    end start
