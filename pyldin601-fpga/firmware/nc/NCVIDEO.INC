; Native text and packed graphics use the same ROM 8x8 glyphs, including the
; box-drawing set. Own glyph output avoids clipping/state in the DOS console.
colour
    staa ink
    ldx #pixels_paper
    cmpa #$07
    beq colour_table
    cmpa #$17
    beq colour_table
    ldx #pixels_white
    cmpa #$31
    bne colour_selection
    ldx #pixels_cyan
    bra colour_table
colour_selection
    cmpa #$03
    bne colour_table
    ldx #pixels_selected
colour_table
    stx gfx_table
    rts

position
    ldaa mode
    anda #3
    bne position_graphics
    ldx screen_base
    stx outptr
    ldaa text_stride
    staa stride
    ldab ui_y
position_row
    tstb
    beq position_col
    ldaa outptr+1
    adda stride
    staa outptr+1
    bcc position_row_carry
    inc outptr
position_row_carry
    decb
    bra position_row
position_col
    ldab ui_x
    tst mode
    bne position_add
    tst $fff7
    bpl position_add
    aslb
position_add
    ldx outptr
    jsr add_b
    stx outptr
    rts
position_graphics
    ; Each character row is 320 bytes (601) or 640 (601A).
    ldaa ui_y
    asla
    asla
    adda ui_y
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    tst $fff7
    bpl position_graphic_row
    asla
    rolb
position_graphic_row
    adda screen_base+1
    adcb screen_base
    staa outptr+1
    stab outptr
    ldaa ui_x
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    psha
    ldaa mode
    cmpa #2
    pula
    bne position_graphic_col
    asla
    rolb
position_graphic_col
    adda outptr+1
    adcb outptr
    staa outptr+1
    stab outptr
    rts
put
    staa output_char
    ldaa mode
    anda #3
    bne put_graphic
    ldx outptr
    tst mode
    bne put_native
    tst $fff7
    bpl put_native
    ldaa ink
    staa 0,x
    inx
put_native
    ldaa output_char
    staa 0,x
    inx
    stx outptr
    rts
put_graphic
    ldaa output_char
    cmpa #32
    bne put_font
    jmp put_blank
put_font
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    addb #$d8
    staa glyph_ptr+1
    stab glyph_ptr
    ldaa $e6f0
    staa font_saved_page
    ldaa $e6f1
    staa font_saved_group
    clr $e6f1
    ldaa #8
    staa $e6f0
    ldx glyph_ptr
    ldaa 0,x
    staa glyph
    ldaa 1,x
    staa glyph+1
    ldaa 2,x
    staa glyph+2
    ldaa 3,x
    staa glyph+3
    ldaa 4,x
    staa glyph+4
    ldaa 5,x
    staa glyph+5
    ldaa 6,x
    staa glyph+6
    ldaa 7,x
    staa glyph+7
    ldaa font_saved_group
    staa $e6f1
    ldaa font_saved_page
    staa $e6f0
    ldaa mode
    cmpa #2
    beq put_four_colours
    ldx outptr
    ldaa ink
    cmpa #$07
    beq put_mono_inverted
    cmpa #$17
    beq put_mono_inverted
    cmpa #$03
    beq put_mono_inverted
    ldaa glyph
    staa 0,x
    ldaa glyph+1
    staa 1,x
    ldaa glyph+2
    staa 2,x
    ldaa glyph+3
    staa 3,x
    ldaa glyph+4
    staa 4,x
    ldaa glyph+5
    staa 5,x
    ldaa glyph+6
    staa 6,x
    ldaa glyph+7
    staa 7,x
    bra put_advance_eight
put_mono_inverted
    ldaa glyph
    coma
    staa 0,x
    ldaa glyph+1
    coma
    staa 1,x
    ldaa glyph+2
    coma
    staa 2,x
    ldaa glyph+3
    coma
    staa 3,x
    ldaa glyph+4
    coma
    staa 4,x
    ldaa glyph+5
    coma
    staa 5,x
    ldaa glyph+6
    coma
    staa 6,x
    ldaa glyph+7
    coma
    staa 7,x
put_advance_eight
    ldab #8
    jsr add_b
    stx outptr
    rts

put_four_colours
    clr glyph_row
put_colour_row
    ldx #glyph
    ldab glyph_row
    jsr add_b
    ldaa 0,x
    staa glyph_bits
    jsr pack_pixels
    ldx outptr
    ldaa glyph_byte
    staa 0,x
    jsr pack_pixels
    ldx outptr
    ldaa glyph_byte
    staa 8,x
    inx
    stx outptr
    inc glyph_row
    ldaa glyph_row
    cmpa #8
    bcs put_colour_row
    ldab #8
    ldx outptr
    jsr add_b
    stx outptr
    rts
; Expand four font bits at a time instead of testing all eight pixels.
pack_pixels
    ldaa glyph_bits
    lsra
    lsra
    lsra
    lsra
    tab
    ldx gfx_table
    jsr add_b
    ldaa 0,x
    staa glyph_byte
    asl glyph_bits
    asl glyph_bits
    asl glyph_bits
    asl glyph_bits
    rts
; Blanks dominate panel padding. Fill their pixels without reading the font.
put_blank
    clra
    ldab ink
    cmpb #$07
    beq put_blank_paper
    cmpb #$17
    beq put_blank_paper
    cmpb #$03
    bne put_blank_value
    ldaa #$ff
    ldab mode
    cmpb #2
    bne put_blank_value
    ldaa #$55
    bra put_blank_value
put_blank_paper
    ldaa #$ff
put_blank_value
    ldx outptr
    staa 0,x
    staa 1,x
    staa 2,x
    staa 3,x
    staa 4,x
    staa 5,x
    staa 6,x
    staa 7,x
    ldab mode
    cmpb #2
    beq nc_long_ncvideo_2_302
    jmp put_advance_eight
nc_long_ncvideo_2_302
    staa 8,x
    staa 9,x
    staa 10,x
    staa 11,x
    staa 12,x
    staa 13,x
    staa 14,x
    staa 15,x
    ldab #16
    jsr add_b
    stx outptr
    rts
pixels_white
    db $00,$03,$0c,$0f,$30,$33,$3c,$3f,$c0,$c3,$cc,$cf,$f0,$f3,$fc,$ff
pixels_cyan
    db $00,$01,$04,$05,$10,$11,$14,$15,$40,$41,$44,$45,$50,$51,$54,$55
pixels_selected
    db $55,$54,$51,$50,$45,$44,$41,$40,$15,$14,$11,$10,$05,$04,$01,$00
pixels_paper
    db $ff,$fc,$f3,$f0,$cf,$cc,$c3,$c0,$3f,$3c,$33,$30,$0f,$0c,$03,$00
