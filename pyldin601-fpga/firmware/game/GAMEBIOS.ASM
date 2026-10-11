; GAMEBIOS ABI1, linked after RAMBANKS in page E. Native BIOS stays intact.
    include GAMEBIOS.INC
    include GAMESTATE.INC
game_initialize
    ; No boot-time allocation: legacy GD needs the original contiguous heap.
    ldx #game_gateway
    stx G_STATE
    rts
; OPEN alone may activate the vector, using the tail of its caller context.
; Entry: original A/B/CCR are already saved on the dispatcher stack.
game_context_state
    ldx $07
    cpx #$100
    bcs game_context_bad
    cpx #$be00-GB_CONTEXT_BYTES
    bhi game_context_bad
    ldd 0,x
    subd #GB_CONTEXT_BYTES
    bne game_context_bad
    ldaa 2,x
    cmpa #GB_ABI
    bne game_context_bad
    ldd $07
    addd #GB_CONTEXT_BYTES-G_SIZE
    std G_STATE
    xgdx
    ldaa game_gateway
    staa 0,x
    ldaa game_gateway+1
    staa 1,x
    ldaa game_gateway+2
    staa 2,x
    inx
    inx
    inx
    ldab #G_SIZE-256
game_init_clear
    clr 0,x
    inx
    decb
    bne game_init_clear
    ldab #253
game_init_clear2
    clr 0,x
    inx
    decb
    bne game_init_clear2
    ldx G_STATE
    clc
    rts
game_context_bad
    sec
    rts
game_gateway
    jmp game_dispatch
game_info
    ldaa #GB_ABI
    staa $06
    ldab #63
    stab $05
    ldx #GB_CONTEXT_BYTES
    stx $07
    rts
game_dispatch
    tsta
    beq game_info
    cmpa #31
    bcs *+5
    jmp game_direct_argument
    psha
    ldaa $e6a0
    bita #2
    bne game_cpu_ok
    pula
    ldaa #GB_NEED_HD6303
    staa $06
    rts
game_cpu_ok
    pshb
    tpa
    psha
    sei
    ldx G_STATE
    cpx #$c000
    bcs game_active_state
    ; A on the stack selects the operation; CPU A still contains caller CCR.
    tsx
    ldaa 2,x
    cmpa #GB_OPEN
    bne game_absent
    jsr game_context_state
    bcc game_active_state
    pula
    pulb
    pula
    jmp game_direct_argument
game_active_state
    cpx #$100
    bcs game_absent
    cpx #$be00-G_SIZE
    bhi game_absent
    tst G_LOCK,x
    bne game_locked
    inc G_LOCK,x
    pula
    tap
    pulb
    pula
    staa G_OP,x
    stab G_INB,x
    ldd $07
    std G_PARM,x
    ldaa G_OP,x
    cmpa #GB_OPEN
    beq game_dispatch_call
    ldd G_OWNER,x
    beq game_no_owner
    subd $ec00
    bne game_foreign
game_dispatch_call
    ldx G_STATE
    ldab G_OP,x
    aslb
    ldx #game_functions
    abx
    ldx 0,x
    jsr 0,x
game_return
    staa $06
    sei
    ldx G_STATE
    ldaa G_OP,x
    cmpa #GB_STATUS
    beq game_return_unlock
    ldd G_PARM,x
    std $07
    ldaa G_OP,x
    cmpa #GB_READPIX
    beq game_return_unlock
    ldab G_INB,x
    stab $05
game_return_unlock
    clr G_LOCK,x
    ldd G_OWNER,x
    bne game_return_active
    ldx #game_gateway
    stx G_STATE
game_return_active
    rts
game_absent
    pula
    pulb
    pula
    ldaa #GB_UNAVAILABLE
    staa $06
    rts
game_locked
    pula
    pulb
    pula
    ldaa #GB_BUSY
    staa $06
    rts
game_no_owner
    ldaa #GB_UNAVAILABLE
    bra game_return
game_foreign
    ldaa #GB_OWNER
    bra game_return
game_direct_argument
    ldaa #GB_ARGUMENT
    staa $06
    rts
game_functions
    dw game_info,game_open,game_close,game_mode,game_target,game_flip
    dw game_palette,game_pixel,game_readpixel,game_rectangle,game_line
    dw game_copy,game_sprite,game_putc,game_puts,game_cursor,game_attr
    dw game_window,game_scroll,game_clear,game_note,game_frame,game_rate
    dw game_play,game_stop,game_ayreg,game_reserve,game_status,game_clock
    dw game_rawpixel,game_batch
; Execute a bounded graphics list under the existing foreground lock. The
; musical IRQ remains enabled. Save outer arguments even on partial failure.
game_batch
    ldx G_STATE
    ldab G_INB,x
    cmpb #32
    bls *+5
    jmp game_argument
    tstb
    bne *+5
    jmp game_ok
    stab G_BATCHLEFT,x
    clra
    asld
    asld
    jsr game_buffer
    bcc *+5
    jmp game_argument
    stx $07
    ldx G_STATE
    ldd G_PARM,x
    psha
    pshb
    ldab G_INB,x
    pshb
    ldd $07
    std G_BATCHPTR,x
game_batch_next
    ldx G_STATE
    ldx G_BATCHPTR,x
    ldaa 0,x
    cmpa #GB_TARGET
    beq game_batch_allowed
    cmpa #GB_PIXEL
    beq game_batch_allowed
    cmpa #GB_RAWPIX
    beq game_batch_allowed
    cmpa #GB_RECT
    bcs game_batch_bad
    cmpa #GB_CLEAR
    bhi game_batch_bad
game_batch_allowed
    psha
    ldd 2,x
    psha
    pshb
    ldab 1,x
    inx
    inx
    inx
    inx
    stx $07
    ldx G_STATE
    stab G_INB,x
    pulb
    pula
    std G_PARM,x
    ldd $07
    std G_BATCHPTR,x
    pulb
    aslb
    ldx #game_functions
    abx
    ldx 0,x
    jsr 0,x
    tsta
    bne game_batch_restore
    ldx G_STATE
    dec G_BATCHLEFT,x
    bne game_batch_next
    bra game_batch_restore
game_batch_bad
    ldaa #GB_ARGUMENT
game_batch_restore
    ldx G_STATE
    staa G_BATCHOP,x
    pulb
    stab G_INB,x
    pulb
    pula
    std G_PARM,x
    ldaa G_BATCHOP,x
    rts
game_ok
    clra
    rts
game_argument
    ldaa #GB_ARGUMENT
    rts
game_hardware
    ldaa #GB_HARDWARE
    rts
game_busy
    ldaa #GB_BUSY
    rts
game_unsupported
    ldaa #GB_UNSUPPORTED
    rts
; Validate a whole caller buffer before touching it. D=length, P=current X.
game_buffer
    ldx G_STATE
    std G_TMP,x
    ldd G_PARM,x
    subd #$100
    bcs game_buffer_bad
    ldd G_PARM,x
    addd G_TMP,x
    bcs game_buffer_bad
    subd #$be00
    bhi game_buffer_bad
    ldx G_PARM,x
    clc
    rts
game_buffer_bad
    sec
    rts
game_video
    ldx G_STATE
    ldaa G_FLAGS,x
    bita #GB_VIDEO
    beq game_video_bad
    clc
    rts
game_video_bad
    sec
    rts
game_indexed
    jsr game_video
    bcs game_indexed_bad
    ldaa G_MODE,x
    cmpa #1
    bne game_indexed_bad
    clc
    rts
game_indexed_bad
    sec
    rts
game_audio
    ldx G_STATE
    ldaa G_FLAGS,x
    bita #GB_AUDIO
    beq game_video_bad
    clc
    rts
game_open
    ldx G_STATE
    ldd G_OWNER,x
    beq *+5
    jmp game_busy
    ldd #GB_CONTEXT_BYTES
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldd 0,x
    subd #GB_CONTEXT_BYTES
    beq *+5
    jmp game_argument
    ldaa 2,x
    cmpa #GB_ABI
    beq *+5
    jmp game_argument
    ldaa 3,x
    bne *+5
    jmp game_argument
game_open_flags
    cmpa #3
    bls *+5
    jmp game_argument
    ldx G_STATE
    staa G_FLAGS,x
    bita #GB_VIDEO
    beq game_open_audio
    ldaa $e65e
    cmpa #'G'
    beq *+5
    jmp game_hardware
    ldaa $e65f
    cmpa #5
    bcc *+5
    jmp game_hardware
    ldaa G_GFX
    bita #$81
    beq *+5
    jmp game_busy
    ; OPEN may follow a process whose completed DMA command failed. A
    ; read-only command acknowledges that sticky error without changing
    ; the framebuffer or front page. Active-context errors remain strict.
    jsr game_recover
    tsta
    beq *+3
    rts
    ldx G_STATE
game_open_audio
    ldaa G_FLAGS,x
    bita #GB_AUDIO
    beq game_open_claim
    ldaa $e691
    cmpa #$59
    beq *+5
    jmp game_hardware
    ldaa G_AUDIOCTL
    bita #$21
    beq *+5
    jmp game_busy
    ldaa #$e4
    int $2e
    stx $07
    ldx G_STATE
    stab G_OLDPAGE,x
    ldd $07
    std G_OLDIRQ,x
game_open_claim
    ldx G_STATE
    ldd $ec00
    bne *+5
    jmp game_argument
    std G_OWNER,x
    ldd G_PARM,x
    std G_CONTEXT,x
    clr G_MODE,x
    clr G_TARGET,x
    clr G_CX,x
    clr G_CY,x
    clr G_LEFT,x
    clr G_TOP,x
    clr G_BG,x
    ldaa #255
    staa G_FG,x
    ldaa #40
    staa G_WIDTH,x
    ldaa #25
    staa G_HEIGHT,x
    clr G_PLAYING,x
    clr G_QUEUED,x
    clr G_HEAD,x
    clr G_TAIL,x
    clr G_MANUAL,x
    clr G_ACTIVE,x
    clr G_STREAM,x
    clr G_CLOCKID,x
    clr G_TICKS,x
    clr G_TICKS+1,x
    clr G_UNDERRUN,x
    clr G_UNDERRUN+1,x
    ldaa G_FLAGS,x
    bita #GB_VIDEO
    beq game_open_claim_audio
    ldaa G_GFX
    anda #7
    staa G_OLDMODE,x
    ldaa $e652
    staa G_OLDFRONT,x
    jsr game_palette_save
game_open_claim_audio
    jsr game_audio
    bcs game_open_done
    ldd $e692
    std G_PERIOD,x
    ldd $e694
    std G_PERIOD+2,x
    ldd $e69b
    std G_DIVIDER,x
    ldd $e69d
    std G_DIVIDER+2,x
    ldab #14
    ldx #G_AY
game_olday_loop
    ldaa 0,x
    psha
    inx
    decb
    bne game_olday_loop
    ldx G_STATE
    ldab #G_OLDAY+14
    abx
    ldab #14
game_olday_store
    dex
    pula
    staa 0,x
    decb
    bne game_olday_store
    jsr game_stop_inner
    ldx G_STATE
    ldab #G_SHADOW
    abx
    ldab #14
game_shadow_clear
    clr 0,x
    inx
    decb
    bne game_shadow_clear
    ldx G_STATE
    ldaa #$3f
    staa G_SHADOW+7,x
    ldaa #$ff
    staa G_SHADOW+13,x
    clr $e692
    ldaa #7
    staa $e693
    ldaa #$53
    staa $e694
    clr $e695
    ldaa #1
    staa $e696
    ldx #game_dividers
    jsr game_divider_set
    tsta
    beq game_open_hook
    psha
    jsr game_close
    pula
    rts
game_open_hook
    sei
    ldaa #$e4
    ldab #14
    ldx #game_irq
    int $2f
game_open_done
    clra
    rts
game_close
    ldx G_STATE
    clr G_TMP,x
    jsr game_audio
    bcs game_close_video
    sei
    jsr game_stop_inner
    ldx G_STATE
    ldd G_PERIOD,x
    std $e692
    ldd G_PERIOD+2,x
    std $e694
    ldaa #1
    staa $e696
    ldd G_STATE
    addd #G_DIVIDER
    xgdx
    jsr game_divider_set
    ldx G_STATE
    staa G_TMP,x
    ldd G_OLDIRQ,x
    std $efc8
    ldaa $edf2
    anda #15
    ldab G_OLDPAGE,x
    aslb
    aslb
    aslb
    aslb
    aba
    staa $edf2
    ldd G_STATE
    addd #G_OLDAY
    std G_SOURCE,x
    clrb
game_restore_ay
    pshb
    ldx G_STATE
    ldx G_SOURCE,x
    abx
    ldaa 0,x
    ldx #G_AY
    abx
    staa 0,x
    pulb
    incb
    cmpb #14
    bne game_restore_ay
game_close_video
    ; Restore caller I before the long palette copy. Own timer is disabled.
    ldaa $04
    tap
    jsr game_video
    bcs game_close_result
    clr G_GFX
    ; A completed failed job must not prevent palette/front restoration.
    ; A still-busy engine is a real timeout and remains an error.
    jsr game_wait_idle
    ldx G_STATE
    tsta
    beq game_close_palette
    staa G_TMP,x
game_close_palette
    jsr game_palette_restore
    ldx G_STATE
    tst G_TMP,x
    bne game_close_mode
    ldaa G_OLDFRONT,x
    staa $e655
    ldaa #3
    staa $e651
    jsr game_wait
    ldx G_STATE
    staa G_TMP,x
game_close_mode
    ldaa G_OLDMODE,x
    staa G_GFX
game_close_result
    ldaa G_TMP,x
game_close_clear
    ldx G_STATE
    clr G_OWNER,x
    clr G_OWNER+1,x
    clr G_CONTEXT,x
    clr G_CONTEXT+1,x
    clr G_FLAGS,x
    rts
game_palette_save
    ldx G_STATE
    ldd G_CONTEXT,x
    addd #32
    std G_SOURCE,x
    ldd #8192
    std G_COUNT,x
    clr $e652
    clr $e65d
    ldaa #1
    staa $e65f
game_palette_save_loop
    ldx G_STATE
    ldx G_SOURCE,x
    ldaa $e65e
    staa 0,x
    inx
    xgdx
    ldx G_STATE
    std G_SOURCE,x
    ldaa #3
    staa $e65f
    ldd G_COUNT,x
    subd #1
    std G_COUNT,x
    bne game_palette_save_loop
    clr $e65f
    rts
game_palette_restore
    ldx G_STATE
    ldd G_CONTEXT,x
    addd #32
    std G_SOURCE,x
    ldd #8192
    std G_COUNT,x
    clr $e652
    clr $e65d
    clr $e65f
game_palette_restore_loop
    ldx G_STATE
    ldx G_SOURCE,x
    ldaa 0,x
    staa $e65e
    inx
    xgdx
    ldx G_STATE
    std G_SOURCE,x
    ldd G_COUNT,x
    subd #1
    std G_COUNT,x
    bne game_palette_restore_loop
    rts
game_wait
    ldx #0
game_wait_loop
    ldaa G_GFX
    bpl game_wait_done
    dex
    bne game_wait_loop
    jmp game_hardware
game_wait_done
    bita #$30
    beq *+5
    jmp game_hardware
    clra
    rts
game_wait_idle
    ldx #0
game_idle_loop
    ldaa G_GFX
    bpl game_idle_done
    dex
    bne game_idle_loop
    jmp game_hardware
game_idle_done
    clra
    rts
game_recover
    ldaa G_GFX
    bita #$10
    bne *+5
    jmp game_ok
    ldaa $e652
    staa $e654
    clr $e656
    clr $e657
    ldaa #5
    staa $e651
    jmp game_wait
game_mode
    jsr game_video
    bcc *+5
    jmp game_unsupported
    ldab $05
    beq game_mode_valid
    cmpb #1
    beq game_mode_valid
    cmpb #7
    beq *+5
    jmp game_argument
game_mode_valid
    jsr game_wait
    tsta
    beq *+3
    rts
    ldx G_STATE
    ldab $05
    stab G_MODE,x
    cmpb #7
    bne game_mode_set
    jsr game_components
game_mode_set
    ldab $05
    stab G_GFX
    clra
    rts
game_target
    jsr game_video
    bcc *+5
    jmp game_unsupported
    ldab G_INB,x
    cmpb #15
    bls *+5
    jmp game_argument
    stab G_TARGET,x
    clra
    rts
game_flip
    jsr game_video
    bcc *+5
    jmp game_unsupported
    ldab $05
    cmpb #15
    bls *+5
    jmp game_argument
    jsr game_wait
    tsta
    beq *+3
    rts
    ldab $05
    stab $e655
    ldaa #3
    staa $e651
    jmp game_wait
    include GAMEGFX.ASM
    include GAMEAY.ASM
game_coefficients
    include PALCOEF.ASM
game_font
    include GAMEFONT.INC
game_notes
    include GAMENOTES.INC
game_dividers
    db $01,$80,$00,$00,$03,$00,$00,$00,$01,$b1,$11,$01,$01,$ad,$1a,$cd
