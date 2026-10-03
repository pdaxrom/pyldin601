; SLP wakes on the board's normal PAL IRQ, with I clear and with I set.
; Video continues; the masked phase acknowledges PAL ticks itself.
        org $0100
        tpa
        staa entry_cc
        sts entry_sp
        ldaa $e6a0
        bita #2
        bne begin_test
        ldx #wrong_cpu
        int $23
        int $38
begin_test
        ldx #banner
        int $23
        ldaa #$e1
        staa wanted_cc
        clr phase
next_phase
        ldaa #32
        staa remaining
sleep_again
        sei
        ldaa $e62b
        ldx #$5678
        ldab #$34
        ldaa #$12
        psha
        ldaa wanted_cc
        tap
        pula
        slp
        psha
        tpa
        staa actual_cc
        pula
        std actual_d
        stx actual_x
        sts actual_sp
        sei
        ldaa $e62b
        ldx actual_d
        cpx #$1234
        bne failed
        ldx actual_x
        cpx #$5678
        bne failed
        ldx actual_sp
        cpx entry_sp
        bne failed
        ldaa actual_cc
        cmpa wanted_cc
        bne failed
        dec remaining
        bne sleep_again
        tst phase
        bne passed
        inc phase
        ldaa #$f1
        staa wanted_cc
        bra next_phase
passed
        ldaa entry_cc
        tap
        ldx #success
        int $23
        int $38
failed
        lds entry_sp
        ldaa entry_cc
        tap
        ldx #fail_message
        int $23
        ldaa phase
        jsr print_byte
        ldx #cc_message
        int $23
        ldaa actual_cc
        jsr print_byte
        ldx #newline
        int $23
        int $38
@@PRINT@@
entry_cc db 0
entry_sp dw 0
phase db 0
remaining db 0
wanted_cc db 0
actual_d dw 0
actual_x dw 0
actual_sp dw 0
actual_cc db 0
wrong_cpu db 'SKIP: select HD6303 in the boot menu',13,10,0
banner db 'HDSLEEP: 32 IRQ + 32 masked IRQ wakes',13,10,0
success db 'PASS HDSLEEP: 64 wakes, D/X/CCR/SP preserved',13,10,0
fail_message db 'FAIL HDSLEEP phase=',0
cc_message db ' CC=',0
newline db 13,10,0
        end
