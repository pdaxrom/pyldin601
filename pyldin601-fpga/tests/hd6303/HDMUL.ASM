; Exhaust all 65536 unsigned A*B products and MUL's CCR preservation.
; Software expectation advances by addition, never by another multiply.
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
        clr test_a
outer
        clr test_b
        clr expected_d
        clr expected_d+1
multiply
        ldx #$5678
        ldab test_b
        ldaa test_a
        psha
        ldaa #$2e
        tap
        pula
        mul
        psha
        tpa
        staa actual_cc
        pula
        std actual_d
        stx actual_x
        sts actual_sp
        ldx actual_d
        cpx expected_d
        bne failed
        ldx actual_x
        cpx #$5678
        bne failed
        ldx actual_sp
        cpx entry_sp
        bne failed
        ldaa expected_d+1
        bmi carry_one
        ldaa #$ee
        bra check_cc
carry_one
        ldaa #$ef
check_cc
        cmpa actual_cc
        bne failed
        ldaa expected_d+1
        adda test_a
        staa expected_d+1
        ldaa expected_d
        adca #0
        staa expected_d
        inc test_b
        beq next_a
        jmp multiply
next_a
        inc test_a
        beq passed
        jmp outer
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
        ldaa test_a
        jsr print_byte
        ldaa #' '
        int $22
        ldaa test_b
        jsr print_byte
        ldx #actual_message
        int $23
        ldx actual_d
        jsr print_word
        ldx #expected_message
        int $23
        ldx expected_d
        jsr print_word
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
test_a db 0
test_b db 0
expected_d dw 0
actual_d dw 0
actual_x dw 0
actual_sp dw 0
actual_cc db 0
wrong_cpu db 'SKIP: select HD6303 in the boot menu',13,10,0
banner db 'HDMUL: testing 65536 products; please wait',13,10,0
success db 'PASS HDMUL: 65536 products, CCR/X/SP preserved',13,10,0
fail_message db 'FAIL HDMUL A/B=',0
actual_message db ' D=',0
expected_message db ' EXPECTED=',0
cc_message db ' CC=',0
newline db 13,10,0
        end
