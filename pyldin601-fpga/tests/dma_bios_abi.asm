; Execute direct DMA and permanent BIOS INT E8 on both CPUs.
    org $0800
start
    sei
    lds #$9fff
    clr $070e
    clr $070f
    ldx #irq_handler
    stx $efc8
    ldaa $edf2
    anda #15
    staa $edf2
    clr $e692
    ldaa #3
    staa $e693
    ldaa #$a9
    staa $e694
    ldaa #$80
    staa $e695
    ldaa #1
    staa $e696
    staa $e690
    cli
    ldx #fill_bank
    ldaa #1
    jsr submit
    ldx #copy_bank
    ldaa #2
    jsr submit
    ldaa #18
    staa $e6f1
    ldaa #3
    staa $e6f0
    ldaa $c000
    cmpa #$39
    beq *+5
    jmp fail
    ldaa #$19
    staa $c000
    ldaa #$27
    staa $dfff
    clr $e6f1
    ldaa #1
    staa $e6f0
    ldaa $c000
    cmpa #$39
    beq *+5
    jmp fail
    ldaa $dfff
    cmpa #$39
    beq *+5
    jmp fail
    clra
    int $e8
    cmpa #1
    beq *+5
    jmp fail
    cmpb #7
    beq *+5
    jmp fail
    jmp extended
fail
    ldaa #$de
    staa $070f
    bra fail
extended
    ldaa #18
    staa $e6f1
    ldaa #$a3
    staa $e6f0
    ldx #bank_to_bank
    jsr move
    ldx #bank_to_ram
    jsr move
    ldx #overlap
    jsr move
    ldaa $4007
    cmpa #$19
    beq *+5
    jmp fail
    ldaa $5fff
    cmpa #$39
    beq *+5
    jmp fail
    ldaa $e6f1
    cmpa #18
    beq *+5
    jmp fail
    ldaa $e6f0
    cmpa #$a3
    beq *+5
    jmp fail
    ldaa #111
    staa bank_to_bank
    ldx #bank_to_bank
    ldaa #1
    int $e8
    cmpa #1
    beq *+5
    jmp fail
    clr $e652
    clr $e65d
    clr $e65f
    ldx #fill_palette
    ldaa #1
    jsr submit
    ldab #110
    ldaa #2
    int $e8
    tsta
    beq *+5
    jmp fail
    ldaa #35
    staa fill_palette+18
    ldx #fill_palette
    ldaa #1
    jsr submit
    ; Caller SEI must survive during the entire autonomous PAL restore.
    sei
    inc $070c
    ldab #110
    ldaa #3
    int $e8
    clr $070c
    cli
    tsta
    beq *+5
    jmp fail
    ldaa #1
    staa $e65f
    clrb
pal_check
    stab $e65d
    ldaa #127
    staa $e652
    ldaa $e65e
    cmpa #21
    beq *+5
    jmp fail
    incb
    cmpb #32
    bne pal_check
    clr $e65f
    ldaa $070d
    beq *+5
    jmp fail
done
    tst $070e
    beq done
    clr $e690
    ldaa #$a5
    staa $070f
halt
    bra halt
move
    ldaa #1
    int $e8
    tsta
    beq *+5
    jmp fail
    rts
; Register reads do not advance index: CLR DATA is safe on the real 6800.
submit
    psha
    tpa
    psha
    sei
    clr $e6e2
    ldab #19
parameters
    ldaa 0,x
    staa $e6e3
    inx
    decb
    bne parameters
    pula
    tab
    pula
    staa $e6e1
    tba
    tap
wait_dma
    ldaa $e6e0
    bmi wait_dma
    bita #$10
    beq *+5
    jmp fail
    rts
irq_handler
    ldaa #3
    staa $e690
    inc $070e
    ldx #irq_move
    ldaa #1
    int $e8
    tsta
    beq irq_return
    inc $070d
irq_return
    rts
fill_bank
    db 0,0,0,$00,$e0,$0f,$00,$20,0,1,0,0,0,0,0,0,0,0,$39
copy_bank
    db $00,$e0,$0f,$00,$20,$02,$00,$20,0,1,0,0,0,0,0,0,0,0,0
fill_palette
    db 0,0,0,$5e,$e6,0,$00,$20,0,1,0,0,0,0,0,0,0,2,21
bank_to_bank
    db 110,0
    dw 0,0,8192
bank_to_ram
    db 0,$ff
    dw 0,$4000,8192
overlap
    db $ff,$ff
    dw $4000,$4007,8185
irq_move
    db $ff,$ff
    dw $6000,$6100,1
    end start
