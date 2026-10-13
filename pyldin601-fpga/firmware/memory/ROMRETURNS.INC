; Stored in the native SWI trampoline's former padding. Each BSR is a
; two-byte continuation for one E6F1 group (0..18). The handler sees exactly
; the legacy return PC, E6F0 and seven-byte CPU frame; no resident RAM needed.
    global swi_returns,irq_returns
swi_returns
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
    bsr swi_group_return
swi_group_return
    sei
    pula
    pula
    suba #(swi_returns+2)
    lsra
    staa $e6f1
    pulb
    stab rompage
    tsx
    jsr exchregs
    dec indos
    rti
irq_returns
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
    bsr irq_group_return
irq_group_return
    sei
    pula
    pula
    suba #(irq_returns+2)
    lsra
    staa $e6f1
    pula
    staa rompage
    rti
