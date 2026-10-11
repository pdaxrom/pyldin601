; Foreground-only indexed drawing. IRQ never touches these temporaries.
game_pixel
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    bra game_pixel_parse
game_rawpixel
    jsr game_video
    bcc *+5
    jmp game_unsupported
    tst G_MODE,x
    bne *+5
    jmp game_unsupported
game_pixel_parse
    ldd #5
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldd 0,x
    psha
    pshb
    ldd 2,x
    psha
    pshb
    ldaa 4,x
    ldx G_STATE
    staa G_COLOUR,x
    pulb
    pula
    std G_Y,x
    pulb
    pula
    std G_X,x
    jmp game_dot
game_coordinates
    ldx G_STATE
    ldd G_X,x
    subd #320
    bcc game_coordinates_bad
    ldd G_Y,x
    subd #200
    bcc game_coordinates_bad
    clc
    rts
game_coordinates_bad
    sec
    rts
game_offset
    ldx G_STATE
    ldaa #64
    ldab G_Y+1,x
    mul
    std G_TMP,x
    asld
    asld
    addd G_TMP,x
    addd G_X,x
    std G_SOURCE,x
    rts
game_dot
    jsr game_coordinates
    bcc *+5
    jmp game_ok
    jsr game_offset
    jsr game_wait
    tsta
    beq *+3
    rts
    ldx G_STATE
    ldaa G_TARGET,x
    staa $e655
    ldd G_SOURCE,x
    staa $e659
    stab $e658
    ldaa G_COLOUR,x
    staa $e653
    ldaa #4
    staa $e651
    jmp game_wait
game_readpixel
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldd #4
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldd 0,x
    psha
    pshb
    ldd 2,x
    ldx G_STATE
    std G_Y,x
    pulb
    pula
    std G_X,x
    jsr game_coordinates
    bcc *+5
    jmp game_argument
    jsr game_offset
    jsr game_wait
    tsta
    beq *+3
    rts
    ldx G_STATE
    ldaa G_TARGET,x
    staa $e654
    ldd G_SOURCE,x
    staa $e657
    stab $e656
    ldaa #5
    staa $e651
    jsr game_wait
    tsta
    beq *+3
    rts
    ldab $e65d
    stab $05
    clra
    rts
game_rectangle
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldd #8
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldd 0,x
    psha
    pshb
    ldd 2,x
    psha
    pshb
    ldd 4,x
    psha
    pshb
    ldaa 6,x
    psha
    ldaa 7,x
    ldx G_STATE
    staa G_COLOUR,x
    pula
    staa G_H,x
    pulb
    pula
    std G_W,x
    pulb
    pula
    std G_Y,x
    pulb
    pula
    std G_X,x
    ldd G_W,x
    beq game_rect_bad
    subd #321
    bcc game_rect_bad
    ldaa G_H,x
    beq game_rect_bad
    cmpa #201
    bcc game_rect_bad
    ldd G_X,x
    bpl game_rect_right
    addd G_W,x
    ble game_rect_empty
    std G_W,x
    clr G_X,x
    clr G_X+1,x
game_rect_right
    ldd #320
    subd G_X,x
    ble game_rect_empty
    subd G_W,x
    bcc game_rect_top
    ldd #320
    subd G_X,x
    std G_W,x
game_rect_top
    ldd G_Y,x
    bpl game_rect_bottom
    clra
    ldab G_H,x
    addd G_Y,x
    ble game_rect_empty
    stab G_H,x
    clr G_Y,x
    clr G_Y+1,x
game_rect_bottom
    ldd #200
    subd G_Y,x
    ble game_rect_empty
    cmpb G_H,x
    bcc game_rect_draw
    stab G_H,x
game_rect_draw
    jsr game_offset
    jmp game_fill
game_rect_bad
    jmp game_argument
game_rect_empty
    clra
    rts
game_fill
    jsr game_wait
    tsta
    beq *+3
    rts
    ldx G_STATE
    ldaa G_TARGET,x
    staa $e655
    ldd G_SOURCE,x
    staa $e659
    stab $e658
    ldd G_W,x
    staa $e65b
    stab $e65a
    ldaa G_H,x
    staa $e65c
    ldaa G_COLOUR,x
    staa $e653
    ldaa #1
    staa $e651
    jmp game_wait
game_copy
    jsr game_video
    bcc *+5
    jmp game_unsupported
    ldd #11
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldaa #3
    int $e0
    rts
game_sprite
    jsr game_video
    bcc *+5
    jmp game_unsupported
    ldd #12
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldaa #4
    int $e0
    rts
game_line
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldd #9
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldd 0,x
    psha
    pshb
    ldd 2,x
    psha
    pshb
    ldd 4,x
    psha
    pshb
    ldd 6,x
    psha
    pshb
    ldaa 8,x
    ldx G_STATE
    staa G_COLOUR,x
    pulb
    pula
    std G_EY,x
    pulb
    pula
    std G_EX,x
    pulb
    pula
    std G_Y,x
    pulb
    pula
    std G_X,x
    ldd G_X,x
    addd #320
    subd #960
    bcs *+5
    jmp game_line_bad
    ldd G_EX,x
    addd #320
    subd #960
    bcs *+5
    jmp game_line_bad
    ldd G_Y,x
    addd #200
    subd #600
    bcs *+5
    jmp game_line_bad
    ldd G_EY,x
    addd #200
    subd #600
    bcs *+5
    jmp game_line_bad
    ldd #1
    std G_SX,x
    std G_SY,x
    ldd G_EX,x
    subd G_X,x
    bpl game_line_dx
    ldd #-1
    std G_SX,x
    ldd G_X,x
    subd G_EX,x
game_line_dx
    std G_DX,x
    ldd G_EY,x
    subd G_Y,x
    bpl game_line_dy
    ldd #-1
    std G_SY,x
    ldd G_Y,x
    subd G_EY,x
game_line_dy
    std G_DY,x
    ldd G_DX,x
    subd G_DY,x
    std G_ERROR,x
game_line_loop
    jsr game_dot
    tsta
    beq *+3
    rts
    ldx G_STATE
    ldd G_X,x
    subd G_EX,x
    bne game_line_next
    ldd G_Y,x
    subd G_EY,x
    bne game_line_next
    clra
    rts
game_line_next
    ldd G_ERROR,x
    asld
    std G_TMP2,x
    addd G_DY,x
    ble game_line_y
    ldd G_ERROR,x
    subd G_DY,x
    std G_ERROR,x
    ldd G_X,x
    addd G_SX,x
    std G_X,x
game_line_y
    ldd G_TMP2,x
    subd G_DX,x
    bge game_line_loop
    ldd G_ERROR,x
    addd G_DX,x
    std G_ERROR,x
    ldd G_Y,x
    addd G_SY,x
    std G_Y,x
    bra game_line_loop
game_line_bad
    jmp game_argument
game_cursor
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldd #2
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldd 0,x
    ldx G_STATE
    cmpa G_LEFT,x
    bcs game_cursor_bad
    cmpb G_TOP,x
    bcs game_cursor_bad
    suba G_LEFT,x
    cmpa G_WIDTH,x
    bcc game_cursor_bad
    subb G_TOP,x
    cmpb G_HEIGHT,x
    bcc game_cursor_bad
    adda G_LEFT,x
    addb G_TOP,x
    staa G_CX,x
    stab G_CY,x
    clra
    rts
game_cursor_bad
    jmp game_argument
game_attr
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldd #2
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldd 0,x
    ldx G_STATE
    staa G_FG,x
    stab G_BG,x
    clra
    rts
game_window
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldd #4
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldaa 2,x
    beq game_window_bad
    adda 0,x
    bcs game_window_bad
    cmpa #40
    bhi game_window_bad
    ldaa 3,x
    beq game_window_bad
    adda 1,x
    bcs game_window_bad
    cmpa #25
    bhi game_window_bad
    ldd 0,x
    psha
    pshb
    ldd 2,x
    ldx G_STATE
    staa G_WIDTH,x
    stab G_HEIGHT,x
    pulb
    pula
    staa G_LEFT,x
    staa G_CX,x
    stab G_TOP,x
    stab G_CY,x
    clra
    rts
game_window_bad
    jmp game_argument
game_clear
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldaa G_LEFT,x
    staa G_CX,x
    ldaa G_TOP,x
    staa G_CY,x
    ldaa G_HEIGHT,x
    staa G_H,x
    jsr game_window_rectangle
    jmp game_fill
game_window_rectangle
    clra
    ldab G_LEFT,x
    asld
    asld
    asld
    std G_X,x
    clra
    ldab G_WIDTH,x
    asld
    asld
    asld
    std G_W,x
    ldaa G_H,x
    asla
    asla
    asla
    staa G_H,x
    clra
    ldab G_TOP,x
    asld
    asld
    asld
    std G_Y,x
    ldaa G_BG,x
    staa G_COLOUR,x
    jmp game_offset
game_scroll
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldab G_INB,x
    tstb
    bne *+5
    jmp game_ok
game_scroll_inner
    cmpb G_HEIGHT,x
    bls *+5
    jmp game_argument
    stab G_GC,x
    cmpb G_HEIGHT,x
    beq game_scroll_whole
    ldaa G_HEIGHT,x
    sba
    staa G_H,x
    jsr game_window_rectangle
    jsr game_wait
    tsta
    beq *+3
    rts
    ldx G_STATE
    ldaa G_TARGET,x
    staa $e654
    staa $e655
    ldd G_SOURCE,x
    staa $e659
    stab $e658
    ldab G_GC,x
    aslb
    aslb
    aslb
    ldaa #64
    mul
    std G_TMP2,x
    asld
    asld
    addd G_TMP2,x
    addd G_SOURCE,x
    staa $e657
    stab $e656
    ldd G_W,x
    staa $e65b
    stab $e65a
    ldaa G_H,x
    staa $e65c
    ldaa #2
    staa $e651
    jsr game_wait
    tsta
    beq *+3
    rts
    ldx G_STATE
game_scroll_clear
    ldaa G_GC,x
    asla
    asla
    asla
    staa G_H,x
    clra
    ldab G_TOP,x
    addb G_HEIGHT,x
    subb G_GC,x
    asld
    asld
    asld
    std G_Y,x
    ldaa G_BG,x
    staa G_COLOUR,x
    jsr game_offset
    jmp game_fill
game_scroll_whole
    ldaa G_HEIGHT,x
    staa G_H,x
    jsr game_window_rectangle
    jmp game_fill
game_putc
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldaa G_INB,x
    jmp game_character
game_puts
    jsr game_indexed
    bcc *+5
    jmp game_unsupported
    ldd G_PARM,x
    std G_STRING,x
game_puts_loop
    ldx G_STATE
    ldd G_STRING,x
    subd #$100
    bcs game_puts_bad
    subd #$bd00
    bcc game_puts_bad
    ldx G_STRING,x
    ldaa 0,x
    beq game_puts_done
    inx
    stx $07
    ldx G_STATE
    psha
    ldd $07
    std G_STRING,x
    pula
    jsr game_character
    tsta
    beq game_puts_loop
    rts
game_puts_bad
    jmp game_argument
game_puts_done
    clra
    rts
game_character
    ldx G_STATE
    cmpa #13
    bne *+5
    jmp game_carriage
    cmpa #10
    bne *+5
    jmp game_newline
    cmpa #8
    bne *+5
    jmp game_backspace
    cmpa #12
    bne *+5
    jmp game_clear
    cmpa #32
    bcc *+5
    jmp game_ok
    staa G_CHAR,x
    clra
    ldab G_CHAR,x
    asld
    asld
    asld
    addd #game_font
    std G_FONT,x
    clra
    ldab G_CX,x
    asld
    asld
    asld
    std G_X,x
    clra
    ldab G_CY,x
    asld
    asld
    asld
    std G_Y,x
    ldd #8
    std G_W,x
    stab G_H,x
    ldaa G_BG,x
    staa G_COLOUR,x
    jsr game_offset
    ldd G_SOURCE,x
    std G_ROW,x
    jsr game_fill
    tsta
    beq *+3
    rts
    ldx G_STATE
    ldaa G_FG,x
    cmpa G_BG,x
    beq game_glyph_advance
    staa G_COLOUR,x
    ldaa #1
    staa G_H,x
    clr G_GR,x
game_glyph_row
    ldx G_STATE
    ldx G_FONT,x
    ldaa 0,x
    inx
    stx $07
    ldx G_STATE
    staa G_BITS,x
    ldd $07
    std G_FONT,x
    clr G_GC,x
game_glyph_scan
    tst G_BITS,x
    bpl game_glyph_skip
    clra
    ldab G_GC,x
    addd G_ROW,x
    std G_SOURCE,x
    ldd #0
    std G_W,x
game_glyph_run
    inc G_W+1,x
    inc G_GC,x
    asl G_BITS,x
    bmi game_glyph_run
    jsr game_fill
    tsta
    beq *+3
    rts
    ldx G_STATE
    bra game_glyph_next
game_glyph_skip
    asl G_BITS,x
    inc G_GC,x
game_glyph_next
    ldaa G_GC,x
    cmpa #8
    bne game_glyph_scan
    ldd G_ROW,x
    addd #320
    std G_ROW,x
    inc G_GR,x
    ldaa G_GR,x
    cmpa #8
    bne game_glyph_row
game_glyph_advance
    inc G_CX,x
    ldaa G_CX,x
    suba G_LEFT,x
    cmpa G_WIDTH,x
    bcs game_character_done
    ldaa G_LEFT,x
    staa G_CX,x
    bra game_newline
game_carriage
    ldaa G_LEFT,x
    staa G_CX,x
    clra
    rts
game_newline
    inc G_CY,x
    ldaa G_CY,x
    suba G_TOP,x
    cmpa G_HEIGHT,x
    bcs game_character_done
    dec G_CY,x
    ldab #1
    jmp game_scroll_inner
game_backspace
    ldaa G_CX,x
    cmpa G_LEFT,x
    beq game_character_done
    dec G_CX,x
game_character_done
    clra
    rts
game_palette
    jsr game_video
    bcc *+5
    jmp game_unsupported
    ldaa G_MODE,x
    cmpa #7
    bne *+5
    jmp game_unsupported
    ldd #4
    jsr game_buffer
    bcc *+5
    jmp game_argument
    ldaa 0,x
    psha
    ldaa 1,x
    psha
    ldaa 2,x
    psha
    ldaa 3,x
    ldx G_STATE
    staa G_RGB+2,x
    pula
    staa G_RGB+1,x
    pula
    staa G_RGB,x
    pula
    clrb
    lsra
    rorb
    lsra
    rorb
    lsra
    rorb
    staa $e65d
    stab $e652
    clr $e65f
    ldd #game_coefficients
    std G_GAIN,x
    ldaa #32
    staa G_PHASE,x
game_palette_phase
    ldd #7936
    std G_ACC,x
    clr G_GC,x
game_palette_channel
    ldd G_STATE
    addd #G_RGB
    std G_SOURCE,x
    ldx G_STATE
    ldab G_GC,x
    ldx G_SOURCE,x
    abx
    ldab 0,x
    ldx G_STATE
    ldx G_GAIN,x
    ldaa 0,x
    inx
    stx $07
    ldx G_STATE
    pshb
    psha
    ldd $07
    std G_GAIN,x
    pula
    pulb
    tsta
    bmi game_palette_negative
    mul
    addd G_ACC,x
    bra game_palette_added
game_palette_negative
    nega
    mul
    std G_PRODUCT,x
    ldd G_ACC,x
    subd G_PRODUCT,x
game_palette_added
    std G_ACC,x
    inc G_GC,x
    ldaa G_GC,x
    cmpa #3
    bne game_palette_channel
    ldaa G_ACC,x
    lsra
    staa $e65e
    dec G_PHASE,x
    bne game_palette_phase
    clra
    rts
game_components
    clr G_GFX
    clr $e652
    clr $e65d
    clr $e65f
    ldx G_STATE
    clr G_GR,x
game_component_channel
    clr G_GC,x
game_component_level
    ldaa G_GC,x
    lsra
    lsra
    lsra
    lsra
    staa G_CHAR,x
    ldaa G_GC,x
    asla
    asla
    oraa G_CHAR,x
    staa G_RGB,x
    clra
    ldab G_GR,x
    addd #game_coefficients
    std G_GAIN,x
    ldaa #32
    staa G_PHASE,x
game_component_phase
    ldd #6400
    ldaa G_GR,x
    cmpa #1
    bne game_component_bias12
    ldd #768
    bra game_component_bias
game_component_bias12
    ldd #6400
game_component_bias
    std G_ACC,x
    ldab G_RGB,x
    ldx G_GAIN,x
    ldaa 0,x
    inx
    inx
    inx
    stx $07
    ldx G_STATE
    pshb
    psha
    ldd $07
    std G_GAIN,x
    pula
    pulb
    tsta
    bmi game_component_negative
    mul
    addd G_ACC,x
    bra game_component_value
game_component_negative
    nega
    mul
    std G_PRODUCT,x
    ldd G_ACC,x
    subd G_PRODUCT,x
game_component_value
    lsra
    staa $e65e
    dec G_PHASE,x
    bne game_component_phase
    inc G_GC,x
    ldaa G_GC,x
    cmpa #64
    bne game_component_level
    inc G_GR,x
    ldaa G_GR,x
    cmpa #3
    bne game_component_channel
    rts
