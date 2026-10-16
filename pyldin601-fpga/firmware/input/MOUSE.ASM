; Software PS/2 mouse driver, MC6800 ISA. No ROM/vector/global RAM ownership.
; Uses only E6B8..BF; commands are bit-banged through ordinary 0/Z pins.
; mouse_init: A=0 enabled, 1 absent/error. X/B destroyed, interrupt mask retained.
; mouse_poll: A=1 one complete event, 0 no event; X/B destroyed.
; Coordinates: x=0..639, y=0..mouse_height-1, y increases downwards.
; Event buttons/pressed/released are L/R/M bits0/1/2. No wheel negotiation.
    .ifdef MOUSE_OBJECT
    public mouse_init
    public mouse_poll
    public mouse_close
    public mouse_command
    public mouse_x
    public mouse_x_low
    public mouse_y_low
    public mouse_y
    public mouse_height
    public mouse_buttons
    public mouse_pressed
    public mouse_released
    public mouse_moved
    public mouse_present
    public mouse_show
    .endif
    .ifdef MOUSE_FIXED
    section $6000
    .else
    section
    .endif
mouse_present ds 1
mouse_phase ds 1
mouse_packet ds 1
mouse_dx ds 1
mouse_dy ds 1
mouse_x ds 1
mouse_x_low ds 1
mouse_y ds 1
mouse_y_low ds 1
mouse_height ds 1
mouse_buttons ds 1
mouse_pressed ds 1
mouse_released ds 1
mouse_moved ds 1
mouse_show ds 1
mouse_send ds 1
mouse_tick ds 1
mouse_parity ds 1
mouse_bits ds 1
mouse_result ds 1
mouse_changed ds 1
mouse_delta ds 2
mouse_new ds 2
mouse_levels ds 10
mouse_request ds 1
mouse_retries ds 1
    ends

mouse_init
    clr mouse_present
    clr mouse_buttons
    clr mouse_pressed
    clr mouse_released
    clr mouse_phase
    clr mouse_show
    clr $e6be
    ldx #320
    stx mouse_x
    ldx #100
    stx mouse_y
    ldaa #200
    staa mouse_height
    ldaa $e6b8
    cmpa #'M'
    beq *+5
    jmp mouse_missing
    ; F6 restores the standard stream defaults; F4 explicitly enables reports.
    ldaa #$f6
    jsr mouse_command
    tsta
    bne mouse_missing
    ldaa #$f4
    jsr mouse_command
    tsta
    bne mouse_missing
    ldaa #64
    staa $e6be
    ldx #mouse_arrow
    ldab #64
mouse_load_arrow
    ldaa 0,x
    staa $e6bf
    inx
    decb
    bne mouse_load_arrow
    inc mouse_present
    clra
    rts
mouse_missing
    ldaa #1
    rts
mouse_close
    clr mouse_show
    clr $e6be
    tst mouse_present
    beq mouse_closed
    ldaa #$f5
    jsr mouse_command
mouse_closed
    clr mouse_present
    clr mouse_buttons
    rts
mouse_command
    staa mouse_request
    ldaa #3
    staa mouse_retries
mouse_command_retry
    ldaa mouse_request
    jsr mouse_send_cmd
    tsta
    beq mouse_command_done
    dec mouse_retries
    beq mouse_command_done
    ldaa $e6bd
    staa mouse_tick
mouse_retry_delay
    ldaa $e6bd
    suba mouse_tick
    cmpa #200
    bcs mouse_retry_delay
    bra mouse_command_retry
mouse_command_done
    rts
mouse_send_cmd
    staa mouse_send
    ; Precompute the ten output levels so the 1-MHz edge loop has no shifts,
    ; table construction, subroutine calls or unbounded polling between bits.
    ldx #mouse_levels
    ldaa #8
    staa mouse_bits
    clr mouse_parity
mouse_prepare_bit
    ldab #6
    lsr mouse_send
    bcc mouse_prepare_zero
    inc mouse_parity
    ldab #4
mouse_prepare_zero
    stab 0,x
    inx
    dec mouse_bits
    bne mouse_prepare_bit
    ldab #4
    ldaa mouse_parity
    anda #1
    beq mouse_prepare_parity
    ldab #6
mouse_prepare_parity
    stab 0,x
    inx
    ldaa #4
    staa 0,x
    tpa
    psha
    sei
    ldaa #3
    staa $e6bb
    ldaa #5
    staa $e6bc
    ldaa $e6bd
    staa mouse_tick
mouse_inhibit
    ldaa $e6bd
    suba mouse_tick
    cmpa #110
    bcs mouse_inhibit
    ldaa #7
    staa $e6bc
    ldaa $e6bd
    staa mouse_tick
mouse_setup
    ldaa $e6bd
    suba mouse_tick
    cmpa #10
    bcs mouse_setup
    ; The software-owned countdown expires in 20.2..20.5 ms. BITB tests
    ; Clock and timeout in one read, keeping the critical loop below 30 us.
    ldaa #80
    staa $e6bd
    ldaa #6
    staa $e6bc
    ldx #mouse_levels
    ldab #$81
    ldaa 0,x
mouse_tx_fall
    bitb $e6bc
    beq mouse_tx_low
    bpl mouse_tx_fall
    jmp mouse_send_failed
mouse_tx_low
    staa $e6bc
mouse_tx_high
    bitb $e6bc
    bmi mouse_send_failed
    beq mouse_tx_high
    inx
    cpx #mouse_levels+10
    beq mouse_line_ack
    ldaa 0,x
    bra mouse_tx_fall
mouse_line_ack
    bitb $e6bc
    beq mouse_ack_low
    bpl mouse_line_ack
    bra mouse_send_failed
mouse_ack_low
    ldaa $e6bc
    bita #2
    bne mouse_send_failed
mouse_ack_high
    bitb $e6bc
    bmi mouse_send_failed
    beq mouse_ack_high
    clr $e6bc
    ; Hardware RX handles the reply. Restore the caller's interrupt mask
    ; while awaiting FA, so the 50-Hz BIOS clock can continue normally.
    tsx
    ldaa 0,x
    tap
    ldaa #80
    staa $e6bd
mouse_ack_wait
    ldaa $e6b9
    lsra
    bcs mouse_ack_byte
    ldaa $e6bc
    bpl mouse_ack_wait
    bra mouse_send_failed
mouse_ack_byte
    ldaa $e6ba
    cmpa #$fa
    beq mouse_send_ok
    cmpa #$fe
    beq mouse_send_failed
    cmpa #$fc
    beq mouse_send_failed
    ldaa $e6bc
    bpl mouse_ack_wait
mouse_send_failed
    clr $e6bc
    ldaa #1
    bra mouse_send_return
mouse_send_ok
    clra
mouse_send_return
    staa mouse_result
    clr $e6bd
    pula
    tap
    ldaa mouse_result
    rts

mouse_poll
    clr mouse_pressed
    clr mouse_released
    clr mouse_moved
    tst mouse_present
    bne *+5
    jmp mouse_no_event
    ldaa $e6b9
    bita #$c0
    beq mouse_poll_bytes
    ldaa #3
    staa $e6bb
    clr mouse_phase
    ; A lost release must not leave a drag/button latched indefinitely.
    ldaa mouse_buttons
    staa mouse_released
    clr mouse_buttons
    ldaa #1
    rts
mouse_poll_bytes
    ldaa $e6b9
    lsra
    bcs *+5
    jmp mouse_no_event
    ldaa $e6ba
    ldab mouse_phase
    bne *+5
    jmp mouse_header
    decb
    bne *+5
    jmp mouse_delta_x
    staa mouse_dy
    clr mouse_phase
    ldaa mouse_packet
    anda #7
    tab
    eora mouse_buttons
    staa mouse_changed
    andb mouse_changed
    stab mouse_pressed
    ldaa mouse_buttons
    anda mouse_changed
    staa mouse_released
    ldaa mouse_packet
    anda #7
    staa mouse_buttons
    ldaa mouse_dx
    staa mouse_delta+1
    clrb
    ldaa mouse_packet
    bita #$10
    beq mouse_x_positive
    decb
mouse_x_positive
    stab mouse_delta
    bita #$40
    beq mouse_x_add
    ldaa #$ff
    tstb
    beq mouse_x_overflow
    ldaa #1
mouse_x_overflow
    staa mouse_delta+1
mouse_x_add
    ldaa mouse_x+1
    adda mouse_delta+1
    staa mouse_new+1
    ldaa mouse_x
    adca mouse_delta
    bmi mouse_x_min
    cmpa #2
    bcs mouse_x_store
    bne mouse_x_max
    ldab mouse_new+1
    cmpb #128
    bcs mouse_x_store
mouse_x_max
    ldx #639
    bra mouse_x_ready
mouse_x_min
    ldx #0
    bra mouse_x_ready
mouse_x_store
    staa mouse_new
    ldx mouse_new
mouse_x_ready
    cpx mouse_x
    beq mouse_x_same
    inc mouse_moved
mouse_x_same
    stx mouse_x
    ldaa mouse_dy
    staa mouse_delta+1
    clrb
    ldaa mouse_packet
    bita #$20
    beq mouse_y_positive
    decb
mouse_y_positive
    stab mouse_delta
    bita #$80
    beq mouse_y_subtract
    ldaa #$ff
    tstb
    beq mouse_y_overflow
    ldaa #1
mouse_y_overflow
    staa mouse_delta+1
mouse_y_subtract
    ldaa mouse_y+1
    suba mouse_delta+1
    staa mouse_new+1
    ldaa mouse_y
    sbca mouse_delta
    bmi mouse_y_min
    tsta
    bne mouse_y_max
    ldaa mouse_new+1
    cmpa mouse_height
    bcs mouse_y_store
mouse_y_max
    ldaa mouse_height
    deca
    bra mouse_y_store
mouse_y_min
    clra
mouse_y_store
    cmpa mouse_y+1
    beq mouse_y_same
    inc mouse_moved
mouse_y_same
    staa mouse_y+1
    clr mouse_y
    ldaa mouse_show
    staa $e6be
    ldaa mouse_x+1
    staa $e6bf
    ldaa mouse_x
    staa $e6bf
    ldaa mouse_y+1
    staa $e6bf
    ldaa mouse_y
    staa $e6bf
    ldaa #1
    rts
mouse_header
    bita #8
    bne *+5
    jmp mouse_poll_bytes
    staa mouse_packet
    inc mouse_phase
    jmp mouse_poll_bytes
mouse_delta_x
    staa mouse_dx
    inc mouse_phase
    jmp mouse_poll_bytes
mouse_no_event
    clra
    rts
; Replaceable 16x16 2bpp shape; loaded by software, never baked into FPGA.
mouse_arrow
    db $40,0,0,0, $50,0,0,0, $64,0,0,0, $69,0,0,0
    db $6a,$40,0,0, $6a,$90,0,0, $6a,$a4,0,0, $6a,$a9,0,0
    db $6a,$aa,$40,0, $6a,$aa,$90,0, $6a,$95,$50,0, $69,$64,0,0
    db $64,$69,0,0, $50,$1a,$40,0, $40,$06,$90,0, 0,$01,$50,0
