; Common keyboard/mouse wait and modal hit testing. No resident hook or IRQ.
    include NCABI.INC
    public mouse_wait
    public mouse_cancel
    public mouse_context
    public mouse_column
    public mouse_row
    public mouse_focus
    public mouse_bar_key
    extern mouse_poll
    extern mouse_event
    extern mouse_refocus
    extern mouse_present
    extern mouse_x
    extern mouse_x_low
    extern mouse_y_low
    extern mouse_y
    extern mouse_pressed
    extern columns
    extern window_left
    extern window_inner
    extern window_focus
    extern button_focus
    extern edit_cursor
    extern edit_offset
    extern edit_length
    section
mouse_context ds 1
mouse_column ds 1
mouse_row ds 1
mouse_focus ds 1
mouse_bar_left ds 1
mouse_bar_code ds 1
mouse_wait_x ds 2
mouse_wait_b ds 1
mouse_cancel_button ds 1
    ends
; A=0 panels,1 editor,2 input,3 confirmation,4 message,5 menu,6 settings,
; 7 drive list,8 viewer,9 editor Save/Discard/Cancel. Returns a native key.
mouse_wait
    ; BIOS INT11 preserves B/X. Keep the same contract for every caller,
    ; including modal windows; callbacks never nest this wait routine.
    stx mouse_wait_x
    stab mouse_wait_b
    staa mouse_context
    ; INT10 only peeks; reproduce INT11's waiting shape without blocking
    ; inside BIOS, so the program can keep receiving ordinary mouse bytes.
    tpa
    psha
    sei
    ldaa $e600
    psha
    ldaa #10
    staa $e600
    ldaa $ed1d
    oraa $ed1f
    staa $e601
    ldaa #11
    staa $e600
    ldaa $ed1e
    staa $e601
    pula
    staa $e600
    pula
    tap
mouse_wait_loop
    jsr mouse_poll
    tsta
    beq mouse_key_poll
    jsr mouse_cell
    ldaa mouse_context
    cmpa #2
    bcs mouse_application
    cmpa #5
    bcc mouse_application
    jsr mouse_modal
    bra mouse_result_key
mouse_cell
    ldaa mouse_x
    ldab mouse_x_low
    lsra
    rorb
    lsra
    rorb
    lsra
    rorb
    ldaa columns
    cmpa #80
    bcc mouse_column_ready
    lsrb
mouse_column_ready
    stab mouse_column
    ldaa mouse_y_low
    lsra
    lsra
    lsra
    staa mouse_row
    rts
mouse_application
    jsr mouse_event
mouse_result_key
    cmpa #$ff
    beq mouse_wait_loop
    bra mouse_wait_return
mouse_key_poll
    int $10
    cmpa #$ff
    beq mouse_wait_loop
    int $11
mouse_key_ready
    psha
    tst mouse_focus
    beq mouse_key_return
    clr mouse_focus
    ldaa mouse_context
    cmpa #2
    bcc mouse_key_return
    jsr mouse_refocus
mouse_key_return
    pula
mouse_wait_return
    ldx mouse_wait_x
    ldab mouse_wait_b
    rts
; Nonblocking cancellation during disk operations and long editor scans.
; Keep receiving packets and moving the graphics sprite while the UI is busy.
; A!=0 enables the modal Cancel button; right-click is always accepted.
; Returns a pending key, Esc for right-click/Cancel, or FF; preserves B/X.
mouse_cancel
    stx mouse_wait_x
    stab mouse_wait_b
    staa mouse_cancel_button
    jsr mouse_poll
    tsta
    beq mouse_cancel_key
    jsr mouse_cell
    ldaa mouse_pressed
    bita #2
    bne mouse_cancel_yes
    bita #1
    beq mouse_cancel_key
    tst mouse_cancel_button
    beq mouse_cancel_key
    ldaa mouse_row
    cmpa #16
    bne mouse_cancel_key
    ldaa mouse_column
    cmpa window_left
    bcs mouse_cancel_key
    suba window_left
    cmpa window_inner
    bhi mouse_cancel_key
mouse_cancel_yes
    ldaa #27
    bra mouse_wait_return
mouse_cancel_key
    int $10
    cmpa #$ff
    beq mouse_wait_return
    int $11
    bra mouse_wait_return
mouse_modal
    ldaa mouse_pressed
    bita #2
    beq mouse_modal_left
    ldaa #27
    rts
mouse_modal_left
    bita #1
    beq mouse_modal_none
    ldaa mouse_column
    cmpa window_left
    bcs mouse_modal_none
    suba window_left
    cmpa window_inner
    bhi mouse_modal_none
    ldaa mouse_context
    cmpa #2
    bne mouse_modal_button
    ldaa mouse_row
    cmpa #10
    bne mouse_modal_button
    ldaa mouse_column
    suba #6
    bcs mouse_modal_none
    adda edit_offset
    cmpa edit_length
    bls mouse_modal_cursor
    ldaa edit_length
mouse_modal_cursor
    staa edit_cursor
    clr window_focus
    ldaa #$fe
    rts
mouse_modal_button
    ldaa mouse_row
    cmpa #16
    bne mouse_modal_none
    ldaa mouse_column
    ldab columns
    lsrb
    cba
    ldaa #0
    bcs mouse_modal_chosen
    inca
mouse_modal_chosen
    staa button_focus
    inca
    staa window_focus
    ldaa #$c0
    rts
mouse_modal_none
    ldaa #$ff
    rts
; X=the displayed function-key string; use its actual character positions.
mouse_bar_key
    ldaa mouse_column
    staa mouse_bar_left
    ldaa #$ff
    staa mouse_bar_code
mouse_bar_scan
    ldaa 0,x
    beq mouse_modal_none
    cmpa #'1'
    bcs mouse_bar_character
    cmpa #'9'
    bhi mouse_bar_character
    suba #'1'
    adda #$c9
    staa mouse_bar_code
    cmpa #$c9
    bne mouse_bar_character
    ldaa 1,x
    cmpa #'0'
    bne mouse_bar_character
    ldaa #$d2
    staa mouse_bar_code
mouse_bar_character
    tst mouse_bar_left
    beq mouse_bar_done
    dec mouse_bar_left
    inx
    bra mouse_bar_scan
mouse_bar_done
    ldaa mouse_bar_code
    rts
    end
