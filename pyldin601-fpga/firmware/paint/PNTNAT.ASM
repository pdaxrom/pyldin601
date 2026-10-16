; MC6800 native packed mono/four-colour row encoder.
    include PNTABI.INC
    section
params ds 2
source ds 2
destination ds 2
groups ds 1
bits ds 1
mask ds 1
pixels ds 1
pixel_count ds 1
packed ds 1
idle_count ds 1
    ends
start
    bra enter
    db 'PNB1',7,1
enter
    staa params
    stab params+1
    cmpa #1
    bcc *+5
    jmp invalid
    cmpa #$c0
    bcs *+5
    jmp invalid
    ldx params
    ldx PB_MAGIC,x
    cpx #PNT_MAGIC
    beq *+5
    jmp invalid
    ldx params
    ldaa PB_ABI,x
    cmpa #PNT_ABI
    beq *+5
    jmp invalid
    tst PB_OPERATION,x
    beq *+5
    jmp invalid
    ldaa PB_KIND,x
    cmpa #PNT_FOUR
    bls *+5
    jmp invalid
    cmpa #PNT_MONO640
    beq wide
    ldx PB_WIDTH,x
    cpx #320
    beq *+5
    jmp invalid
    ldaa #40
    staa groups
    ldaa #1
    staa bits
    staa mask
    ldaa #8
    staa pixels
    ldx params
    ldaa PB_KIND,x
    cmpa #PNT_FOUR
    bne ready
    ldaa #80
    staa groups
    ldaa #2
    staa bits
    ldaa #3
    staa mask
    ldaa #4
    staa pixels
    bra ready
wide
    ldx PB_WIDTH,x
    cpx #640
    beq *+5
    jmp invalid
    ldaa #80
    staa groups
    ldaa #1
    staa bits
    staa mask
    ldaa #8
    staa pixels
ready
    clr idle_count
    ldx params
    clr PB_BYTES,x
    ldaa groups
    staa PB_BYTES+1,x
    ldx PB_SOURCE,x
    stx source
    ldx params
    ldx PB_DEST,x
    stx destination
group
    clr packed
    ldaa pixels
    staa pixel_count
pixel
    asl packed
    ldaa bits
    cmpa #2
    bne one_bit
    asl packed
one_bit
    ldx source
    ldaa 0,x
    inx
    stx source
    anda mask
    oraa packed
    staa packed
    dec pixel_count
    bne pixel
    ldx destination
    staa 0,x
    inx
    stx destination
    dec groups
    beq done
    inc idle_count
    ldaa idle_count
    anda #7
    bne group
    ldx params
    ldx PB_IDLE,x
    cpx #0
    beq group
    jsr 0,x
    bra group
done
    clra
    rts
invalid
    ldaa #1
    rts
    end start
