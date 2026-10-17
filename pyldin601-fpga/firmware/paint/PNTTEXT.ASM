; ROM-font text and palette editing live in the tools overlay.
; Work is row ordered: even HAM needs only eight row encodes per inscription.
    include PNTDEF.INC
    public text_state
    public text_run
    public text_stamp
    public palette_edit
    extern input
    extern dialog
    extern ui_enter
    extern ui_leave
    extern ui_swatch
    extern ui_rgb
    extern p_ui_result
    extern p_kind
    extern p_fg
    extern p_fg_rgb
    extern p_palette
    extern p_x0
    extern p_y0
    extern p_width
    extern p_cached_y
    extern p_row_dirty
    extern p_stroke_saved
    extern draw_x
    extern draw_y
    extern draw_pixel
    extern draw_flush
    extern tools_poll
    extern canvas_snapshot
    extern palette_index
    extern add_b
    .ifdef PNT_TOOLS
    .define TEXT_CODE
    .endif
    .ifndef PNT_EDIT
    .ifndef PNT_FILES
    .define TEXT_CODE
    .endif
    .endif
    section
text_state
text_row ds 1
text_y ds 1
text_x ds 2
text_pointer ds 2
text_glyph ds 2
text_bits ds 1
text_columns ds 1
text_left ds 1
text_page ds 1
text_group ds 1
text_status ds 1
text_index ds 1
text_fg ds 1
text_rgb ds 3
    ends
    .ifdef TEXT_CODE
text_run
    jsr ui_enter
    tsta
    beq *+3
    rts
    clr input
    clr p_ui_result
    ldx #text_caption
    jsr dialog
    bcs text_leave
    inc p_ui_result
text_leave
    jsr ui_leave
    tsta
    beq *+3
    rts
    tst p_ui_result
    bne text_stamp
    clra
text_return
    rts
; input=zero-terminated native character bytes, p_x0/p_y0=logical anchor.
; Transparent background; brush size does not scale the 8x8 ROM glyph.
text_stamp
    clr text_row
text_line
    ldaa p_y0
    adda text_row
    cmpa #200
    bcs *+5
    jmp text_done
    staa text_y
    ldx p_x0
    stx text_x
    ldx #input
    stx text_pointer
    ldaa #79
    staa text_left
text_character
    ldaa text_x
    cmpa p_width
    bcs text_read
    bls *+5
    jmp text_flush
    ldaa text_x+1
    ldx #p_width
    cmpa 1,x
    bcs *+5
    jmp text_flush
text_read
    ldx text_pointer
    ldaa 0,x
    bne *+5
    jmp text_flush
    inx
    stx text_pointer
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    adda text_row
    adcb #$d8
    staa text_glyph+1
    stab text_glyph
    ldaa $e6f0
    staa text_page
    ldaa $e6f1
    staa text_group
    clr $e6f1
    ldaa #8
    staa $e6f0
    ldx text_glyph
    ldaa 0,x
    staa text_bits
    ldaa text_group
    staa $e6f1
    ldaa text_page
    staa $e6f0
    ldaa #8
    staa text_columns
text_pixel
    ldx text_x
    cpx p_width
    bne *+5
    jmp text_flush
    asl text_bits
    bcc text_next_pixel
    stx draw_x
    ldaa text_y
    staa draw_y
    jsr draw_pixel
    tsta
    beq *+3
    rts
text_next_pixel
    ldx text_x
    inx
    stx text_x
    dec text_columns
    bne text_pixel
    jsr tools_poll
    tsta
    beq *+3
    rts
    dec text_left
    bne *+5
    jmp text_flush
    jmp text_character
text_flush
    jsr draw_flush
    tsta
    beq *+3
    rts
    inc text_row
    ldaa text_row
    cmpa #8
    beq text_done
    jmp text_line
text_done
    clra
    rts
palette_edit
    ldaa p_kind
    cmpa #3
    beq palette_choose
    cmpa #4
    beq palette_choose
    ldaa #65
    rts
palette_choose
    ldaa p_fg
    staa text_fg
    jsr ui_swatch
    staa text_status
    ldaa p_fg
    staa text_index
    ldaa text_fg
    staa p_fg
    ldaa text_status
    tsta
    beq *+3
    rts
    tst p_ui_result
    beq text_done
    jsr text_palette_pointer
    ldaa 0,x
    ldab 1,x
    staa text_rgb
    stab text_rgb+1
    ldaa 2,x
    staa text_rgb+2
    jsr ui_enter
    tsta
    beq *+3
    rts
    ldx #text_rgb
    jsr ui_rgb
    tst p_ui_result
    beq palette_leave
    ldaa p_kind
    cmpa #4
    bne palette_document
    ldx #p_fg_rgb
    ldaa text_rgb
    ldab text_rgb+1
    staa 0,x
    stab 1,x
    ldaa text_rgb+2
    staa 2,x
palette_document
    jsr text_palette_pointer
    ldaa 0,x
    cmpa text_rgb
    bne palette_change
    ldaa 1,x
    cmpa text_rgb+1
    bne palette_change
    ldaa 2,x
    cmpa text_rgb+2
    beq palette_leave
palette_change
    ldaa p_kind
    cmpa #4
    beq palette_store
    jsr canvas_snapshot
    tsta
    bne palette_failed
    inc p_stroke_saved
palette_store
    jsr text_palette_pointer
    ldaa text_rgb
    ldab text_rgb+1
    staa 0,x
    stab 1,x
    ldaa text_rgb+2
    staa 2,x
    ldaa p_kind
    cmpa #4
    beq palette_leave
    ldaa #$ff
    staa p_cached_y
    clr p_row_dirty
    jsr palette_index
    tsta
    bne palette_failed
palette_leave
    jmp ui_leave
palette_failed
    staa text_status
    jsr ui_leave
    ldaa text_status
    rts
text_palette_pointer
    ldx #p_palette
    ldab text_index
    jsr add_b
    ldab text_index
    jsr add_b
    ldab text_index
    jmp add_b
text_caption db 'Text (ROM 8x8)',0
    .else
text_run
text_stamp
palette_edit
    clra
    rts
    .endif
    end
