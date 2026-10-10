; MC6800-compatible native BIOS paging dispatch. E6F0 and E6F1 are saved
; on the interrupted stack, including nested SWI/IRQ/NMI. Vector page zero
; preserves BOTH registers. Nonzero vectors use their native page in group 0.
; Based on the original BIOS.ASM SWI register exchange and call convention.
    global paged_irq,paged_swi,audio_irq_dispatch,audio_irq_rti
; New audio hardware has a latched, separately acknowledged IRQ. Check the
; signature first so these ROMs remain safe with an older FPGA (open bus FF).
; INT E4 is its vector; native INT05 remains exactly the PAL system tick.
audio_irq_dispatch
    ldaa $e691
    cmpa #$59
    bne audio_irq_native
    ldaa $e690
    bpl audio_irq_native
    ldaa #3
    staa $e690
    ldab swipag+$72
    lsrb
    lsrb
    lsrb
    lsrb
    ldx swivec+$1c8
    jmp paged_irq
audio_irq_native
    ; Service a latched PAL tick before keyboard soundkey reads PIACRB.
    ; Otherwise a simultaneous key IRQ can acknowledge and lose the tick.
    tst $e62b
    bpl audio_irq_keyboard
    tst $e629
    ldab swipag+2
    ldx swivec+10
    jmp paged_irq
audio_irq_keyboard
    ldab swipag+4
    jmp audio_native_irq
paged_irq
    ldaa rompage
    psha
    ldaa $e6f1
    psha
    andb #$0f
    beq irq_call
    clr $e6f1
    stab rompage
irq_call
    cpx #0
    beq irq_return
    jsr 0,x
irq_return
    sei
    pula
    staa $e6f1
    pula
    staa rompage
audio_irq_rti
    rti

paged_swi
    sei
    inc indos
    tsx
    lds 5,x
    des
    pula
    ins
    sts 5,x
    txs
    psha
    jsr exchregs
    pula
    ldab rompage
    pshb
    ldab $e6f1
    pshb
    tab
    lsrb
    stab swihndl_x+1
    ldab #/swipag
    stab swihndl_x
    ldx swihndl_x
    ldab swipag,x
    bcs swi_page
    lsrb
    lsrb
    lsrb
    lsrb
swi_page
    andb #$0f
    beq swi_vector
    clr $e6f1
    stab rompage
swi_vector
    ldab #$77
    asla
    rolb
    staa swihndl_x+1
    stab swihndl_x
    ldx swihndl_x
    ldaa swivec+1,x
    ldab swivec,x
    beq swi_return
    jsr swi_call
swi_return
    sei
    pulb
    stab $e6f1
    pulb
    stab rompage
    tsx
    jsr exchregs
    dec indos
    rti
exchregs
    ldaa 1,x
    ldab swib
    staa swib
    stab 1,x
    ldaa 2,x
    ldab swia
    staa swia
    stab 2,x
    ldaa 3,x
    ldab swix
    staa swix
    stab 3,x
    ldaa 4,x
    ldab swix+1
    staa swix+1
    stab 4,x
    ldaa 0,x
    ldab swic
    staa swic
    stab 0,x
    rts
swi_call
    psha
    pshb
    ldaa swic
    tap
    ldx swix
    ldab swib
    ldaa swia
    cli
    rts
