; Real native BIOS IRQ/NMI/SWI, including three nested SWIs and an IRQ
; interrupted by NMI. Assemble with UniAS, run on the production VHDL core.
    org $0800
start
    sei
    lds #$bfff
    ldx #outer
    stx $efe0
    ldx #inner
    stx $efe2
    ldx #third
    stx $efe4
    ldx #$c000
    stx $efe6
    ldaa #$70
    staa $edf8
    ldaa #$19
    staa $edf9
    ldx #irq_handler
    stx $ee12
    ldaa #1
    staa $ed84
    ldx #nmi_handler
    stx $ee04
    clr $ed81
    ldaa #18
    staa $e6f1
    ldaa #$a3
    staa $e6f0
    ldaa #$a5
    ldab #$5a
    ldx #$8123
    psha
    ldaa #$d5
    tap
    pula
    int $f0
    psha
    tpa
    cmpa #$d5
    bne fail
    pula
    cmpa #$a5
    bne fail
    cmpb #$5a
    bne fail
    cpx #$8123
    bne fail
    tsx
    cpx #$c000
    bne fail
    ldaa $e6f0
    cmpa #$a3
    bne fail
    ldaa $e6f1
    cmpa #18
    bne fail
    tst $0705
    beq fail
    tst $0706
    beq fail
    tst $0707
    beq fail
    jsr fat_copy_check
    ldaa #$a5
    staa $070f
halt
    bra halt
fail
    ldaa #$de
    staa $070f
    bra halt

outer
    ldaa $e6f0
    cmpa #7
    bne fail
    tst $e6f1
    bne fail
    ldaa $c000
    cmpa #$27
    bne fail
    ldaa #9
    staa $e6f1
    ldaa #2
    staa $e6f0
    int $f1
    ldaa $e6f0
    cmpa #2
    bne fail
    ldaa $e6f1
    cmpa #9
    bne fail
    int $f3
    ldaa $e6f0
    cmpa #2
    bne fail
    ldaa $e6f1
    cmpa #9
    bne fail
    jsr chain_entry
    tst $0708
    bne chain_ok
    jmp fail
chain_ok
    ldaa $e6f0
    cmpa #7
    bne fail
    ldaa $e6f1
    cmpa #9
    bne fail
    jsr chain_null
    ldaa #2
    staa $e6f0
    ldaa #$a5
    ldab #$5a
    ldx #$8123
    jmp $fff0

; Real native INT37 changes its caller's stacked PC/page and restores the
; outer SWI parameters. A null target must still return with the correct SP.
chain_entry
    ldab #7
    ldx #chain_target
    int $37
    jmp fail
chain_null
    ldx #0
    int $37
    jmp fail
chain_target
    psha
    tpa
    cmpa #$d5
    beq chain_cc_ok
    jmp fail
chain_cc_ok
    pula
    cmpa #$a5
    beq chain_a_ok
    jmp fail
chain_a_ok
    cmpb #$5a
    beq chain_b_ok
    jmp fail
chain_b_ok
    cpx #$8123
    beq chain_x_ok
    jmp fail
chain_x_ok
    ldaa #1
    staa $0708
    rts

inner
    ldaa $e6f0
    cmpa #2
    beq inner_page_ok
    jmp fail
inner_page_ok
    ldaa $e6f1
    cmpa #9
    beq inner_group_ok
    jmp fail
inner_group_ok
    ldaa #14
    staa $e6f1
    ldaa #6
    staa $e6f0
    int $f2
    ldaa $e6f0
    cmpa #6
    beq inner_restored
    jmp fail
inner_restored
    ldaa $e6f1
    cmpa #14
    beq inner_return
    jmp fail
inner_return
    rts

third
    jsr group_zero_ram
    ldaa #17
    staa $e6f1
    ldaa #4
    staa $e6f0
    ldab #$6d
    ldx #$789a
    ldaa #1
    staa $0700
third_wait
    tst $0706
    beq third_wait
    ldaa $e6f0
    cmpa #4
    beq third_page_ok
    jmp fail
third_page_ok
    cmpb #$6d
    beq third_b_ok
    jmp fail
third_b_ok
    cpx #$789a
    beq third_x_ok
    jmp fail
third_x_ok
    ldaa $e6f1
    cmpa #17
    beq third_return
    jmp fail
third_return
    rts

irq_handler
    ldaa #1
    staa $0701
    jsr group_zero_ram
    ldaa #8
    staa $e6f1
    ldaa #5
    staa $e6f0
    ldab #$7c
    ldx #$3456
    ldaa #1
    staa $0702
irq_wait
    tst $0705
    beq irq_wait
    ldaa $e6f0
    cmpa #5
    beq irq_page_ok
    jmp fail
irq_page_ok
    cmpb #$7c
    beq irq_b_ok
    jmp fail
irq_b_ok
    cpx #$3456
    beq irq_x_ok
    jmp fail
irq_x_ok
    ldaa $e6f1
    cmpa #8
    beq irq_group_ok
    jmp fail
irq_group_ok
    ldaa #1
    staa $0706
    rts

nmi_handler
    ldaa $e6f0
    cmpa #5
    beq nmi_page_ok
    jmp fail
nmi_page_ok
    ldaa $e6f1
    cmpa #8
    beq nmi_group_ok
    jmp fail
nmi_group_ok
    ldaa #16
    staa $e6f1
    ldaa #6
    staa $e6f0
    ldab #$9f
    ldx #$5678
    ldaa #1
    staa $0705
    rts

group_zero_ram
    ldaa $e6f0
    cmpa #1
    beq zero_page_ok
    jmp fail
zero_page_ok
    tst $e6f1
    beq zero_group_ok
    jmp fail
zero_group_ok
    ldaa $c000
    cmpa #$41
    beq zero_return
    jmp fail
zero_return
    rts

; The kernel's private fixed-ROM gateway must work with both CPU ISAs.
; The simulated bank 110 contains AF. Check all 512 destination bytes,
; then transfer them back; the HDL bench checks all bank-window writes.
fat_copy_check
    ldx #$f640
    stx $efd0
    ldx #$c400
    stx $ead0
    ldx #$e700
    stx $ead2
    ldaa #3
    staa $ead4
    ldaa #18
    staa $ead5
    ldx #$ead0
    ldaa #4
    int $e8
    tsta
    bne fat_copy_fail
    ldx #$e700
fat_compare
    ldaa 0,x
    cmpa #$af
    bne fat_copy_fail
    inx
    cpx #$e900
    bne fat_compare
    ldx #$e700
    stx $ead0
    ldx #$c400
    stx $ead2
    ldx #$ead0
    ldaa #4
    int $e8
    tsta
    bne fat_copy_fail
    ldaa $e6f0
    cmpa #$a3
    bne fat_copy_fail
    ldaa $e6f1
    cmpa #18
    bne fat_copy_fail
    tsx
    cpx #$bffe
    bne fat_copy_fail
    rts
fat_copy_fail
    jmp fail
    end start
