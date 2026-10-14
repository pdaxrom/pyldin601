; BE32 accumulator. CMP preserves the usual unsigned carry/zero convention.
q_load
    ldaa 0,x
    staa q
    ldaa 1,x
    staa q+1
    ldaa 2,x
    staa q+2
    ldaa 3,x
    staa q+3
    rts
q_store
    ldaa q
    staa 0,x
    ldaa q+1
    staa 1,x
    ldaa q+2
    staa 2,x
    ldaa q+3
    staa 3,x
    rts
q_add
    ldaa q+3
    adda 3,x
    staa q+3
    ldaa q+2
    adca 2,x
    staa q+2
    ldaa q+1
    adca 1,x
    staa q+1
    ldaa q
    adca 0,x
    staa q
    rts
q_sub
    ldaa q+3
    suba 3,x
    staa q+3
    ldaa q+2
    sbca 2,x
    staa q+2
    ldaa q+1
    sbca 1,x
    staa q+1
    ldaa q
    sbca 0,x
    staa q
    rts
q_cmp
    ldaa q
    cmpa 0,x
    bne q_compared
    ldaa q+1
    cmpa 1,x
    bne q_compared
    ldaa q+2
    cmpa 2,x
    bne q_compared
    ldaa q+3
    cmpa 3,x
q_compared
    rts
q_inc
    inc q+3
    bne q_changed
    inc q+2
    bne q_changed
    inc q+1
    bne q_changed
    inc q
q_changed
    rts
q_dec
    ldaa q+3
    bne q_dec_low
    ldaa q+2
    bne q_dec_middle
    ldaa q+1
    bne q_dec_high
    dec q
q_dec_high
    dec q+1
q_dec_middle
    dec q+2
q_dec_low
    dec q+3
    rts
q_test
    ldaa q
    oraa q+1
    oraa q+2
    oraa q+3
    rts
q_512
    clra
    staa q
    staa q+1
    staa q+3
    ldaa #2
    staa q+2
    rts
