; MC6800 indexed row backend. FOUR is used for 601's extended-video fallback.
    include PNTABI.INC
    section
params ds 2
source ds 2
destination ds 2
remaining ds 2
mask ds 1
    ends
start
    bra enter
    db 'PNB1',13,1
enter
    staa params
    stab params+1
    cmpa #1
    bcs invalid
    cmpa #$c0
    bcc invalid
    ldx params
    ldx PB_MAGIC,x
    cpx #PNT_MAGIC
    bne invalid
    ldx params
    ldaa PB_ABI,x
    cmpa #PNT_ABI
    bne invalid
    tst PB_OPERATION,x
    bne invalid
    ldaa PB_KIND,x
    cmpa #PNT_MONO320
    beq mono
    cmpa #PNT_FOUR
    beq four
    cmpa #PNT_INDEXED
    bne invalid
    ldaa #$ff
    bra set_mask
mono
    ldaa #1
    bra set_mask
four
    ldaa #3
set_mask
    staa mask
    ldx PB_WIDTH,x
    cpx #320
    bne invalid
    stx remaining
    ldx params
    ldaa #1
    staa PB_BYTES,x
    ldaa #64
    staa PB_BYTES+1,x
    ldx PB_SOURCE,x
    stx source
    ldx params
    ldx PB_DEST,x
    stx destination
pixel
    ldx source
    ldaa 0,x
    inx
    stx source
    anda mask
    ldx destination
    staa 0,x
    inx
    stx destination
    ldx remaining
    dex
    stx remaining
    bne pixel
    clra
    rts
invalid
    ldaa #1
    rts
    end start
