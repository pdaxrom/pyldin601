; AY queue and tone effects. This IRQ uses only state 19..27,102..107,
; 116..119 and 120..383. No disk, RAM banks or graphics scratch.
G_IRQPTR equ 116
G_IRQNOTE equ 118
game_divider_set
    pshx
    jsr game_divider_wait
    pulx
    tsta
    beq *+3
    rts
    ldd 0,x
    std $e69b
    ldd 2,x
    std $e69d
    ldaa #1
    staa $e69f
    jmp game_divider_wait
game_divider_wait
    ldx #0
game_divider_poll
    ldaa G_AUDIOCTL
    bita #$20
    beq game_divider_done
    dex
    bne game_divider_poll
    jmp game_hardware
game_divider_done
    bita #$10
    beq *+5
    jmp game_hardware
    clra
    rts
game_clock
    jsr game_audio
    bcc *+5
    jmp game_unsupported
    tst G_PLAYING,x
    beq *+5
    jmp game_busy
    ldab G_INB,x
    cmpb #3
    bls *+5
    jmp game_argument
    aslb
    aslb
    ldx #game_dividers
    abx
    jsr game_divider_set
    tsta
    beq *+3
    rts
    ldx G_STATE
    ldaa G_INB,x
    staa G_CLOCKID,x
    clra
    rts
game_rate
    jsr game_audio
    bcc *+5
    jmp game_unsupported
    tst G_PLAYING,x
    beq *+5
    jmp game_busy
    ldd #4
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldd 0,x
    subd #$0003
    bcs game_rate_bad
    bhi game_rate_upper
    ldd 2,x
    subd #$a980
    bcs game_rate_bad
game_rate_upper
    ldd 0,x
    subd #$016e
    bhi game_rate_bad
    bcs game_rate_valid
    ldd 2,x
    subd #$3600
    bhi game_rate_bad
game_rate_valid
    ldd 0,x
    std $e692
    ldd 2,x
    std $e694
    ldaa #1
    staa $e696
    clra
    rts
game_rate_bad
    jmp game_argument
game_frame
    jsr game_audio
    bcc *+5
    jmp game_unsupported
    ldd #14
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldx G_STATE
    ldaa G_QUEUED,x
    cmpa #16
    bcs game_frame_space
    ldaa #GB_FULL
    rts
game_frame_space
    ldab G_TAIL,x
    ldaa #14
    mul
    addd #G_QUEUE
    addd G_STATE
    std G_TMP2,x
    ldd G_PARM,x
    std G_TMP,x
    ldaa #14
    staa G_CHAR,x
game_frame_copy
    ldx G_STATE
    ldx G_TMP,x
    ldaa 0,x
    inx
    stx $07
    ldx G_STATE
    psha
    ldd $07
    std G_TMP,x
    ldx G_TMP2,x
    pula
    staa 0,x
    inx
    stx $07
    ldx G_STATE
    ldd $07
    std G_TMP2,x
    dec G_CHAR,x
    bne game_frame_copy
    sei
    inc G_TAIL,x
    ldaa G_TAIL,x
    anda #15
    staa G_TAIL,x
    inc G_QUEUED,x
    ldaa #1
    staa G_STREAM,x
    clra
    rts
game_play
    jsr game_audio
    bcc *+5
    jmp game_unsupported
    ldab G_INB,x
    cmpb #1
    bls *+5
    jmp game_argument
    sei
    stab G_PLAYING,x
    tstb
    beq game_pause
    ldaa #5
    staa G_AUDIOCTL
    clra
    rts
game_pause
    clr G_AUDIOCTL
    jsr game_silence
    clra
    rts
game_stop
    jsr game_audio
    bcc *+5
    jmp game_unsupported
    sei
    jsr game_stop_inner
    clra
    rts
game_stop_inner
    clr G_AUDIOCTL
    ldx G_STATE
    clr G_PLAYING,x
    clr G_QUEUED,x
    clr G_HEAD,x
    clr G_TAIL,x
    clr G_ACTIVE,x
    clr G_MANUAL,x
    clr G_STREAM,x
    ldaa #$3f
    staa G_SHADOW+7,x
    clr G_SHADOW+8,x
    clr G_SHADOW+9,x
    clr G_SHADOW+10,x
    ldaa #$ff
    staa G_SHADOW+13,x
game_silence
    ldaa #$3f
    staa G_AY+7
    clr G_AY+8
    clr G_AY+9
    clr G_AY+10
    rts
game_status
    jsr game_audio
    bcc *+5
    jmp game_unsupported
    sei
    ldab G_QUEUED,x
    stab $05
    ldd G_TICKS,x
    std $07
    clra
    rts
game_ayreg
    jsr game_audio
    bcc *+5
    jmp game_unsupported
    tst G_STREAM,x
    beq *+5
    jmp game_busy
    ldd #2
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldab 0,x
    cmpb #13
    bls *+5
    jmp game_argument
    ldaa 1,x
    psha
    ldd G_STATE
    addd #G_SHADOW
    std $07
    ldx G_STATE
    ldx G_PARM,x
    ldab 0,x
    ldx $07
    abx
    pula
    sei
    staa 0,x
    jsr game_audio_output
    clra
    rts
game_reserve
    jsr game_audio
    bcc *+5
    jmp game_unsupported
    ldab G_INB,x
    cmpb #7
    bls *+5
    jmp game_argument
    sei
    stab G_MANUAL,x
    jsr game_audio_output
    clra
    rts
game_note
    jsr game_audio
    bcc *+5
    jmp game_unsupported
    ldd #5
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldaa 0,x
    cmpa #2
    bls *+5
    jmp game_argument
    ldaa 1,x
    cmpa #72
    bls *+5
    jmp game_argument
    ldaa 4,x
    cmpa #15
    bls *+5
    jmp game_argument
    sei
    ldx G_STATE
    ldx G_PARM,x
    ldab 0,x
    ldx G_STATE
    stab G_CH,x
    ldaa #8
    mul
    addd G_STATE
    addd #G_NOTES
    std G_IRQNOTE,x
    ldx G_PARM,x
    ldd 2,x
    psha
    pshb
    ldaa 4,x
    psha
    ldaa 1,x
    beq game_note_rest
    deca
    tab
    aslb
    clra
    psha
    pshb
    ldx G_STATE
    ldaa #144
    ldab G_CLOCKID,x
    mul
    addd #game_notes
    std $07
    pulb
    pula
    addd $07
    std $07
    ldx $07
    ldd 0,x
    bra game_note_period
game_note_rest
    ldd #0
game_note_period
    ldx G_STATE
    ldx G_IRQNOTE,x
    std 0,x
    pula
    staa 4,x
    pulb
    pula
    std 2,x
    ldx G_STATE
    ldab G_CH,x
    ldx #game_masks
    abx
    ldaa 0,x
    ldx G_STATE
    staa G_MASK,x
    ldx G_PARM,x
    tst 1,x
    bne game_note_enable
    ldd 2,x
    bne game_note_enable
    ldx G_STATE
    ldaa G_MASK,x
    coma
    anda G_ACTIVE,x
    staa G_ACTIVE,x
    bra game_note_output
game_note_enable
    ldx G_STATE
    ldaa G_MASK,x
    oraa G_ACTIVE,x
    staa G_ACTIVE,x
game_note_output
    jsr game_audio_output
    clra
    rts
game_irq
    ldx G_STATE
    tst G_PLAYING,x
    bne *+3
    rts
    inc G_TICKS+1,x
    bne game_irq_frames
    inc G_TICKS,x
game_irq_frames
    tst G_QUEUED,x
    beq game_irq_empty
    ldab G_HEAD,x
    ldaa #14
    mul
    addd G_STATE
    addd #G_QUEUE
    std G_IRQPTR,x
    clrb
game_irq_copy
    ldx G_STATE
    ldx G_IRQPTR,x
    abx
    ldaa 0,x
    ldx G_STATE
    abx
    staa G_SHADOW,x
    incb
    cmpb #14
    bne game_irq_copy
    ldx G_STATE
    inc G_HEAD,x
    ldaa G_HEAD,x
    anda #15
    staa G_HEAD,x
    dec G_QUEUED,x
    bra game_irq_notes
game_irq_empty
    tst G_STREAM,x
    beq game_irq_notes
    inc G_UNDERRUN+1,x
    bne game_irq_notes
    inc G_UNDERRUN,x
game_irq_notes
    clr G_CH,x
game_irq_note
    ldaa #8
    ldab G_CH,x
    mul
    addd G_STATE
    addd #G_NOTES
    std G_IRQNOTE,x
    ldx G_IRQNOTE,x
    ldd 2,x
    beq game_irq_note_next
    subd #1
    std 2,x
    bne game_irq_note_next
    ldx G_STATE
    ldab G_CH,x
    ldx #game_masks
    abx
    ldaa 0,x
    coma
    ldx G_STATE
    anda G_ACTIVE,x
    staa G_ACTIVE,x
game_irq_note_next
    ldx G_STATE
    inc G_CH,x
    ldaa G_CH,x
    cmpa #3
    bne game_irq_note
    jmp game_audio_output
game_audio_output
    clrb
game_audio_write
    ldx G_STATE
    abx
    ldaa G_SHADOW,x
    ldx #G_AY
    abx
    staa 0,x
    incb
    cmpb #13
    bne game_audio_write
    ldx G_STATE
    ldaa G_SHADOW+13,x
    cmpa #$ff
    beq game_audio_effects
    staa G_AY+13
    ldaa #$ff
    staa G_SHADOW+13,x
game_audio_effects
    ldaa G_ACTIVE,x
    oraa G_MANUAL,x
    bne *+3
    rts
    ldaa G_SHADOW+7,x
    staa G_MIX,x
    clr G_CH,x
game_audio_effect
    ldaa #8
    ldab G_CH,x
    mul
    addd G_STATE
    addd #G_NOTES
    std G_IRQNOTE,x
    ldab G_CH,x
    ldx #game_masks
    abx
    ldaa 0,x
    ldx G_STATE
    staa G_MASK,x
    ldaa G_ACTIVE,x
    oraa G_MANUAL,x
    bita G_MASK,x
    beq game_audio_effect_next
    ldaa G_MASK,x
    oraa G_MIX,x
    staa G_MIX,x
    ldaa G_MASK,x
    asla
    asla
    asla
    oraa G_MIX,x
    staa G_MIX,x
    ldab G_CH,x
    ldx #G_AY+8
    abx
    clr 0,x
    ldx G_STATE
    ldaa G_ACTIVE,x
    bita G_MASK,x
    beq game_audio_effect_next
    ldx G_IRQNOTE,x
    ldd 0,x
    beq game_audio_effect_next
    psha
    pshb
    ldaa 4,x
    psha
    ldx G_STATE
    ldab G_CH,x
    ldx #G_AY+8
    abx
    pula
    staa 0,x
    ldx G_STATE
    ldab G_CH,x
    aslb
    ldx #G_AY
    abx
    pulb
    pula
    stab 0,x
    staa 1,x
    ldx G_STATE
    ldaa G_MASK,x
    coma
    anda G_MIX,x
    staa G_MIX,x
game_audio_effect_next
    ldx G_STATE
    inc G_CH,x
    ldaa G_CH,x
    cmpa #3
    bne game_audio_effect
    ldaa G_MIX,x
    staa G_AY+7
    rts
game_masks
    db 1,2,4
