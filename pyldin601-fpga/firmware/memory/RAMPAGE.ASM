; Destructive test of all 111 expansion pages. Conventional RAM, graphics,
; ROM and disks are retained. MC6800 code: also runs with HD6303 enabled.
; Real relocatable UniDOS PGM. The 50-Hz probe chains the native timer.
page equ $e6f0
group equ $e6f1
start
    ldaa $e6f2
    cmpa #'R'
    bne unsupported
    ldaa $e6f3
    cmpa #111
    bne unsupported
    ldaa page
    staa saved_page
    ldaa group
    staa saved_group
    ldx #intro
    int $23
    ldaa #5
    int $2e
    tstb
    beq native_timer
    ldx #foreign_timer
    jmp message_exit
unsupported
    ldx #need_memory
    jmp message_exit
native_timer
    stx old_vector
    sei
    ldx #irq_probe
    stx $ee0a
    ldx #0
    stx irq_ticks
    cli
    ; Pages 0 and 7 must refer to the same conventional RAM.
    ldaa #7
    staa page
    ldaa $c000
    staa base_first
    ldaa $dfff
    staa base_last
    clr page
    ldaa $c000
    cmpa base_first
    bne control_error
    ldaa $dfff
    cmpa base_last
    bne control_error
    ; Out-of-range group writes must leave the selected group unchanged.
    ldaa #9
    staa group
    ldab #19
bad_group
    stab group
    ldaa group
    cmpa #9
    bne control_error
    incb
    bne bad_group
    ; Last group's three invalid slots are open bus, with writes ignored.
    ldaa #18
    staa group
    ldab #4
invalid_slot
    stab page
    ldaa #$a5
    staa $c000
    staa $dfff
    ldaa $c000
    cmpa #$ff
    bne control_error
    ldaa $dfff
    cmpa #$ff
    bne control_error
    incb
    cmpb #7
    bne invalid_slot
    ldaa #7
    staa page
    ldaa $c000
    cmpa base_first
    bne control_error
    ldaa $dfff
    cmpa base_last
    beq controls_ok
control_error
    ldx #bad_controls
    jmp finish
controls_ok
    clr phase
phase_loop
    ldx #write_msg
    tst phase
    beq announce
    ldx #invert_msg
    ldaa phase
    cmpa #1
    beq announce
    ldx #read_msg
announce
    int $23
    clr bank
    clr selected_group
    ldaa #1
    staa selected_slot
bank_loop
    ldaa selected_group
    staa group
    ldaa selected_slot
    staa page
    ; A real SWI while RAM is selected must preserve both paging CSRs.
    int $1c
    ldaa page
    cmpa selected_slot
    bne bank_control_error
    ldaa group
    cmpa selected_group
    beq bank_ok
bank_control_error
    ldx #bad_context
    jmp finish
bank_ok
    ldx #$c000
block_loop
    stx address
    ldaa address
    eora bank
    staa seed
    ldaa phase
    cmpa #2
    bne seed_ready
    com seed
seed_ready
    clrb
byte_loop
    tba
    eora seed
    tst phase
    beq store_byte
    cmpa 0,x
    beq byte_ok
    staa expected
    ldaa 0,x
    staa actual
    stx address
    jmp memory_error
byte_ok
    ldaa phase
    cmpa #2
    beq next_byte
    tba
    eora seed
    coma
store_byte
    staa 0,x
next_byte
    inx
    incb
    bne byte_loop
    cpx #$e000
    bne block_loop
    ; A dot every sixteen pages keeps progress visible at 1 MHz.
    ldaa bank
    anda #15
    bne poll_key
    ldaa #'.'
    int $22
poll_key
    int $10
    cmpa #$ff
    beq next_bank
    int $11
    cmpa #27
    bne next_bank
    ldx #aborted
    jmp finish
next_bank
    inc bank
    ldaa bank
    cmpa #111
    beq next_phase
    inc selected_slot
    ldaa selected_slot
    cmpa #7
    beq new_group
    jmp bank_loop
new_group
    ldaa #1
    staa selected_slot
    inc selected_group
    jmp bank_loop
next_phase
    ldx #newline
    int $23
    inc phase
    ldaa phase
    cmpa #3
    beq passed
    jmp phase_loop
passed
    sei
    ldx irq_ticks
    cli
    cpx #0
    bne irq_seen
    ldx #no_irq
    jmp finish
irq_seen
    ldx #pass_msg
    int $23
    sei
    ldaa irq_ticks
    ldab irq_ticks+1
    cli
    pshb
    jsr hex
    pula
    jsr hex
    ldx #newline
    jmp finish
memory_error
    ldx #fail_msg
    int $23
    ldaa phase
    jsr hex
    ldx #bank_msg
    int $23
    ldaa bank
    jsr hex
    ldx #addr_msg
    int $23
    ldaa address
    jsr hex
    ldaa address+1
    jsr hex
    ldx #expected_msg
    int $23
    ldaa expected
    jsr hex
    ldx #actual_msg
    int $23
    ldaa actual
    jsr hex
    ldx #newline
finish
    int $23
    sei
    ldx old_vector
    stx $ee0a
    ldaa saved_group
    staa group
    ldaa saved_page
    staa page
    cli
return_to_dos
    int $38
message_exit
    int $23
    int $38
hex
    psha
    lsra
    lsra
    lsra
    lsra
    jsr digit
    pula
    anda #15
digit
    adda #'0'
    cmpa #'9'
    bls print_digit
    adda #7
print_digit
    int $22
    rts
irq_probe
    inc irq_ticks+1
    bne irq_changed
    inc irq_ticks
irq_changed
    ; Deliberately select an invalid RAM slot. BIOS must restore the caller
    ; after both this IRQ and the timer's nested INT 06 (once per second).
    ldaa #18
    staa group
    ldaa #6
    staa page
    ldx old_vector
    jmp 0,x
old_vector dw 0
irq_ticks dw 0
address dw 0
saved_page db 0
saved_group db 0
selected_group db 0
selected_slot db 0
base_first db 0
base_last db 0
bank db 0
phase db 0
seed db 0
expected db 0
actual db 0
intro db 'RAMPAGE: 111 x 8K = 888 KiB.',13,10,'Clears expansion RAM. ESC aborts.',13,10,0
write_msg db 'WRITE address pattern: ',0
invert_msg db 'CHECK and invert:      ',0
read_msg db 'CHECK inverted pattern:',0
pass_msg db 'PASS: 888 KiB, SWI/IRQ. IRQs=',0
fail_msg db 13,10,'FAIL phase=',0
bank_msg db ' bank=',0
addr_msg db 13,10,'address=',0
expected_msg db 13,10,'expected=',0
actual_msg db ' got=',0
bad_controls db 13,10,'FAIL: paging register/invalid slot.',13,10,0
bad_context db 13,10,'FAIL: E6F0/E6F1 context after SWI.',13,10,0
no_irq db 'FAIL: no 50-Hz IRQ during test.',13,10,0
aborted db 13,10,'RAMPAGE: aborted.',13,10,0
need_memory db 'RAMPAGE: update paged RAM FPGA/BIOS.',13,10,0
foreign_timer db 'RAMPAGE: custom INT05; remove hook.',13,10,0
newline db 13,10,0
    end start
