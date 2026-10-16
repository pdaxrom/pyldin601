; Portable RGB666 -> HAM8 row encoder. One greedy step considers the nearest
; RGB222 cube colour and all three component commands. Canonical RGB stays
; separate, so repeated editing never decodes a previously quantized preview.
    include PNTABI.INC
    section
params ds 2
source ds 2
destination ds 2
remaining ds 2
red ds 1
green ds 1
blue ds 1
held_red ds 1
held_green ds 1
held_blue ds 1
error_red ds 1
error_green ds 1
error_blue ds 1
cube_red ds 1
cube_green ds 1
cube_blue ds 1
best_error ds 1
best_code ds 1
best_kind ds 1
quant_value ds 1
quant_code ds 1
quant_level ds 1
idle_count ds 1
operation ds 1
seed ds 2
    ends
start
    bra enter
    db 'PNB1',16,1
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
    ldaa PB_OPERATION,x
    cmpa #2
    bcs *+5
    jmp invalid
    staa operation
    ldx PB_BYTES,x
    stx seed
    ldx params
    ldaa PB_KIND,x
    cmpa #PNT_HAM8
    beq *+5
    jmp invalid
    ldx PB_WIDTH,x
    stx remaining
    tst operation
    bne partial_width
    cpx #320
    beq *+5
    jmp invalid
    bra width_ready
partial_width
    ldaa remaining
    cmpa #1
    bcs partial_small
    beq *+5
    jmp invalid
    ldaa remaining+1
    cmpa #65
    bcs width_ready
    jmp invalid
partial_small
    tst remaining+1
    bne *+5
    jmp invalid
width_ready
    ldx params
    ldaa remaining
    staa PB_BYTES,x
    ldaa remaining+1
    staa PB_BYTES+1,x
    ldx PB_SOURCE,x
    stx source
    ldx params
    ldx PB_DEST,x
    stx destination
    clr held_red
    clr held_green
    clr held_blue
    clr idle_count
    tst operation
    beq pixel
    ldx seed
    cpx #0
    beq pixel
    ldaa 0,x
    anda #63
    staa held_red
    ldaa 1,x
    anda #63
    staa held_green
    ldaa 2,x
    anda #63
    staa held_blue
pixel
    ldx source
    ldaa 0,x
    anda #63
    staa red
    ldaa 1,x
    anda #63
    staa green
    ldaa 2,x
    anda #63
    staa blue
    inx
    inx
    inx
    stx source
    ldaa red
    ldab held_red
    jsr distance
    staa error_red
    ldaa green
    ldab held_green
    jsr distance
    staa error_green
    ldaa blue
    ldab held_blue
    jsr distance
    staa error_blue
    ; The nearest cube colour minimizes the separable absolute error.
    clr best_kind
    ldaa red
    jsr quantize
    staa best_error
    ldab quant_level
    stab cube_red
    ldaa quant_code
    asla
    asla
    asla
    asla
    staa best_code
    ldaa green
    jsr quantize
    adda best_error
    staa best_error
    ldab quant_level
    stab cube_green
    ldaa quant_code
    asla
    asla
    oraa best_code
    staa best_code
    ldaa blue
    jsr quantize
    adda best_error
    staa best_error
    ldab quant_level
    stab cube_blue
    ldaa quant_code
    oraa best_code
    staa best_code
    ldaa error_red
    adda error_green
    cmpa best_error
    bcc try_red
    staa best_error
    ldaa blue
    oraa #$40
    staa best_code
    ldaa #1
    staa best_kind
try_red
    ldaa error_green
    adda error_blue
    cmpa best_error
    bcc try_green
    staa best_error
    ldaa red
    oraa #$80
    staa best_code
    ldaa #2
    staa best_kind
try_green
    ldaa error_red
    adda error_blue
    cmpa best_error
    bcc emit
    ldaa green
    oraa #$c0
    staa best_code
    ldaa #3
    staa best_kind
emit
    ldx destination
    ldaa best_code
    staa 0,x
    inx
    stx destination
    ldaa best_kind
    beq hold_cube
    deca
    beq hold_blue
    deca
    beq hold_red
    ldaa green
    staa held_green
    bra advance
hold_blue
    ldaa blue
    staa held_blue
    bra advance
hold_red
    ldaa red
    staa held_red
    bra advance
hold_cube
    ldaa cube_red
    staa held_red
    ldaa cube_green
    staa held_green
    ldaa cube_blue
    staa held_blue
advance
    ldx remaining
    dex
    stx remaining
    beq done
    inc idle_count
    ldaa idle_count
    anda #7
    bne *+5
    jsr idle
    jmp pixel
done
    clra
    rts
invalid
    ldaa #1
    rts
idle
    ldx params
    ldx PB_IDLE,x
    cpx #0
    beq idle_done
    jsr 0,x
idle_done
    rts
distance
    sba
    bcc distance_done
    nega
distance_done
    rts
; A RGB6 -> nearest cube level/code and absolute error in A.
quantize
    staa quant_value
    cmpa #11
    bcs quant_zero
    cmpa #32
    bcs quant_one
    cmpa #53
    bcs quant_two
    ldaa #3
    ldab #63
    bra quant_ready
quant_zero
    clra
    clrb
    bra quant_ready
quant_one
    ldaa #1
    ldab #21
    bra quant_ready
quant_two
    ldaa #2
    ldab #42
quant_ready
    staa quant_code
    stab quant_level
    ldaa quant_value
    bra distance
    end start
