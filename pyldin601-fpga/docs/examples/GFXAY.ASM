; Documentation example: indexed graphics, native font, timed AY NOTE.
; Assemble with the real UniAS; GAME_MUSIC is not defined for this example.
    include GAMEBIOS.INC
start
    ldx #bss_start
example_zero
    clr 0,x
    inx
    cpx #bss_end
    bne example_zero
    ldab #GB_VIDEO+GB_AUDIO
    jsr sdk_open
    tsta
    beq example_opened
    jmp example_failed
example_opened
    inc opened
    ldaa #GB_MODE
    ldab #1
    jsr example_call
    ldaa #GB_TARGET
    clrb
    jsr example_call
    ldaa #GB_ATTR
    ldx #attributes
    jsr example_call
    ldaa #GB_CLEAR
    jsr example_call
    ldaa #GB_RECT
    ldx #rectangle
    jsr example_call
    ldaa #GB_CURSOR
    ldx #position
    jsr example_call
    ldaa #GB_PUTS
    ldx #caption
    jsr example_call
    ldaa #GB_FLIP
    clrb
    jsr example_call
    ldaa #GB_CLOCK
    clrb                 ; AY master 2 MHz, unrelated to CPU clock
    jsr example_call
    ldaa #GB_RATE
    ldx #timer_period
    jsr example_call
    ldaa #GB_PLAY
    ldab #1              ; IRQ must run for timed NOTE to expire
    jsr example_call
    jsr sdk_input_reset
    tsta
    beq example_loop
    jmp example_failed
example_loop
    jsr sdk_input
    tsta
    beq example_keys
    jmp example_failed
example_keys
    ldaa sdk_pressed
    bita #GB_KEY_ESC
    bne example_exit
    bita #GB_KEY_SPACE
    beq example_loop
    ldaa #GB_NOTE
    ldx #note
    jsr example_call
    bra example_loop
example_exit
    jsr sdk_close
    clra
    int $38
example_call
    int GB_INT
    tsta
    beq example_ok
    jmp example_failed
example_ok
    rts
example_failed
    tst opened
    beq example_message
    jsr sdk_close
example_message
    ldx #failure
    int $23              ; native text only after CLOSE
    ldaa #1
    int $38
    include GAMESDK.ASM
attributes db 255,0
position db 3,3
caption db 'PYLDIN: GRAPHICS + AY',13,10
    db 'SPACE: NOTE  ESC: UNIDOS',0
rectangle dw -8,80,80
    db 24,224            ; clipped rectangle, indexed red
timer_period db $00,$07,$53,$00 ; 480000 clocks / 24 MHz = 50 Hz
note db 2,49             ; channel C, C5 (C1=1)
    dw 25                ; half a second at 50 Hz
    db 12
failure db 'GFXAY: GAMEBIOS/input failed.',13,10,0
bss_start
opened ds 1
    include GAMESDTA.INC
bss_end
    end start
