; HD6303 application library. Include after the application's exit path.
; Include GAMEBIOS.INC first, GAMESDTA.INC at the end of its BSS.
; sdk_open: B=flags, A=status. sdk_close: A=status. One context per process.
sdk_open
    stab sdk_flags
    pshb
    ldaa $e6a0
    bita #2
    bne sdk_cpu
    pulb
    ldaa #GB_NEED_HD6303
    rts
sdk_cpu
    ldaa #GB_INT
    int $2e
    tstb
    bne sdk_present
    pulb
    ldaa #GB_UNAVAILABLE
    rts
sdk_present
    clra
    int GB_INT
    cmpa #GB_ABI
    bne sdk_missing
    cpx #GB_CONTEXT_BYTES
    bne sdk_missing
    pulb
    ldx #sdk_context
    ldd #GB_CONTEXT_BYTES
    std 0,x
    ldaa #GB_ABI
    staa 2,x
    ldaa sdk_flags
    staa 3,x
    ldaa #GB_OPEN
    int GB_INT
    rts
sdk_missing
    pulb
    ldaa #GB_UNAVAILABLE
    rts
sdk_close
    ldaa #GB_CLOSE
    int GB_INT
    rts
; Raw PS/2 set 2 input, separate from the native UniBIOS character queue.
; sdk_input_reset: flush stale bytes and clear physical state before play.
; sdk_input: A=status, B=held logical mask, X preserved; sdk_pressed contains
; make edges since this call, including a tap released before the next frame.
; Arrows/WASD and both CTRL/SHIFT aliases have separate physical state.
; Overflow cannot leave a stuck key: clear state/queue and return GB_HARDWARE.
sdk_input_reset
    pshx
    ldaa GB_PS2_IDENT
    cmpa #'R'
    beq *+5
    jmp sdk_input_missing
    jsr sdk_input_clear
    clra
    pulx
    rts
sdk_input_clear
    ldaa #GB_PS2_FLUSH+GB_PS2_CLEAR
    staa GB_PS2_CONTROL
    clr sdk_prefix
    clr sdk_pause
    clr sdk_held
    clr sdk_pressed
    ldx #sdk_keys
    ldab #14
sdk_input_zero
    clr 0,x
    inx
    decb
    bne sdk_input_zero
    rts
sdk_input
    pshx
    ldaa GB_PS2_IDENT
    cmpa #'R'
    beq *+5
    jmp sdk_input_missing
    clr sdk_pressed
    ldaa #GB_PS2_CAPACITY
    staa sdk_limit
sdk_input_next
    ldaa GB_PS2_STATUS
    bita #GB_PS2_OVERFLOW
    beq *+5
    jmp sdk_input_overflow
    bita #GB_PS2_AVAILABLE
    bne *+5
    jmp sdk_input_done
    ldaa GB_PS2_DATA
    tst sdk_pause
    beq sdk_input_prefix
    dec sdk_pause
    jmp sdk_input_continue
sdk_input_prefix
    cmpa #$e1
    bne sdk_input_e0
    ldaa #7
    staa sdk_pause
    clr sdk_prefix
    jmp sdk_input_continue
sdk_input_e0
    cmpa #$e0
    bne sdk_input_f0
    ldaa sdk_prefix
    oraa #1
    staa sdk_prefix
    jmp sdk_input_continue
sdk_input_f0
    cmpa #$f0
    bne sdk_input_code
    ldaa sdk_prefix
    oraa #2
    staa sdk_prefix
    jmp sdk_input_continue
sdk_input_code
    ; Only set 2 key bytes are mapped; ACK/error bytes and Print Screen's
    ; fake E0 SHIFT do not affect modifiers. Pause's seven bytes are skipped.
    tsta
    bmi sdk_input_unknown
    ldab sdk_prefix
    bitb #1
    beq sdk_input_find
    oraa #$80
sdk_input_find
    ldx #sdk_key_codes
    clrb
sdk_input_lookup
    cmpa 0,x
    beq sdk_input_key
    inx
    inx
    incb
    cmpb #14
    bne sdk_input_lookup
sdk_input_unknown
    clr sdk_prefix
    jmp sdk_input_continue
sdk_input_key
    ldaa 1,x
    staa sdk_key_mask
    ldx #sdk_keys
    abx
    ldaa sdk_prefix
    bita #2
    beq sdk_input_make
    clr 0,x
    bra sdk_input_merge
sdk_input_make
    ldaa sdk_key_mask
    staa 0,x
sdk_input_merge
    clr sdk_prefix
    ldx #sdk_keys
    clra
    ldab #14
sdk_input_or
    oraa 0,x
    inx
    decb
    bne sdk_input_or
    tab
    ldaa sdk_held
    coma
    staa sdk_key_mask
    tba
    anda sdk_key_mask
    oraa sdk_pressed
    staa sdk_pressed
    stab sdk_held
sdk_input_continue
    dec sdk_limit
    beq sdk_input_done
    jmp sdk_input_next
sdk_input_done
    ldab sdk_held
    clra
    pulx
    rts
sdk_input_missing
    clrb
    ldaa #GB_UNSUPPORTED
    pulx
    rts
sdk_input_overflow
    jsr sdk_input_clear
    clrb
    ldaa #GB_HARDWARE
    pulx
    rts
; Encoded key (bit 7 = E0), logical mask. Independent physical aliases.
sdk_key_codes
    db $eb,GB_KEY_LEFT,$f4,GB_KEY_RIGHT,$f5,GB_KEY_UP,$f2,GB_KEY_DOWN
    db $1c,GB_KEY_LEFT,$23,GB_KEY_RIGHT,$1d,GB_KEY_UP,$1b,GB_KEY_DOWN
    db $29,GB_KEY_SPACE,$76,GB_KEY_ESC,$14,GB_KEY_CTRL,$94,GB_KEY_CTRL
    db $12,GB_KEY_SHIFT,$59,GB_KEY_SHIFT
; Synchronous 8x8 opaque tile from an 8x8-tile atlas in a framebuffer page.
; X: srcpage,dstpage,tile(0..63),column(0..39),row(0..24).
sdk_tile
    ldaa 0,x
    cmpa #15
    bls *+5
    jmp sdk_tile_bad
    staa sdk_blit+2
    ldaa 1,x
    cmpa #15
    bls *+5
    jmp sdk_tile_bad
    staa sdk_blit+3
    ldaa 2,x
    cmpa #63
    bls *+5
    jmp sdk_tile_bad
    staa sdk_tile_id
    ldaa 3,x
    cmpa #39
    bls *+5
    jmp sdk_tile_bad
    staa sdk_tile_x
    ldab 4,x
    cmpb #24
    bls *+5
    jmp sdk_tile_bad
    ldaa #8
    mul
    ; row * 8 * 320 = row * 2560.
    asld
    asld
    asld
    asld
    asld
    asld
    std sdk_offset
    asld
    asld
    addd sdk_offset
    std sdk_offset
    clra
    ldab sdk_tile_x
    asld
    asld
    asld
    addd sdk_offset
    std sdk_blit+6
    ldaa #64
    ldab sdk_tile_id
    lsrb
    lsrb
    lsrb
    aslb
    aslb
    aslb
    mul
    std sdk_offset
    asld
    asld
    addd sdk_offset
    std sdk_offset
    clra
    ldab sdk_tile_id
    andb #7
    asld
    asld
    asld
    addd sdk_offset
    std sdk_blit+4
    ldaa #2
    staa sdk_blit
    clr sdk_blit+1
    ldd #8
    std sdk_blit+8
    stab sdk_blit+10
    ldx #sdk_blit
    ldaa #GB_COPY
    int GB_INT
    rts
sdk_tile_bad
    ldaa #GB_ARGUMENT
    rts
; Visible map window. X points to 12 bytes:
; mapBE,mapW,mapH,cameraX,cameraY,viewW,viewH,left,top,atlasPage,destPage.
; All dimensions are in tiles. Map IDs 0..63. No pixel data copied by CPU.
; Returned A=status. May be used to redraw a whole window or a dirty subwindow.
sdk_map
    stx sdk_map_ptr
    jsr sdk_map_validate
    tsta
    beq *+3
    rts
    clr sdk_map_y
    jmp sdk_map_row
sdk_map_validate
    ldaa 6,x
    bne *+5
    jmp sdk_map_bad
    adda 8,x
    bcc *+5
    jmp sdk_map_bad
    cmpa #40
    bls *+5
    jmp sdk_map_bad
    ldaa 7,x
    bne *+5
    jmp sdk_map_bad
    adda 9,x
    bcc *+5
    jmp sdk_map_bad
    cmpa #25
    bls *+5
    jmp sdk_map_bad
    ldaa 4,x
    adda 6,x
    bcc *+5
    jmp sdk_map_bad
    cmpa 2,x
    bls *+5
    jmp sdk_map_bad
    ldaa 5,x
    adda 7,x
    bcc *+5
    jmp sdk_map_bad
    cmpa 3,x
    bls *+5
    jmp sdk_map_bad
    ; Entire byte-ID map must be ordinary unbanked RAM.
    ldd 0,x
    subd #$100
    bcc *+5
    jmp sdk_map_bad
    ldaa 2,x
    ldab 3,x
    mul
    addd 0,x
    bcc *+5
    jmp sdk_map_bad
    subd #$be00
    bls *+5
    jmp sdk_map_bad
    clra
    rts
sdk_map_row
    clr sdk_map_x
sdk_map_column
    ldx sdk_map_ptr
    ldab sdk_map_y
    addb 5,x
    ldaa 2,x
    mul
    addd 0,x
    addb sdk_map_x
    adca #0
    std sdk_offset
    clra
    ldab 4,x
    addd sdk_offset
    xgdx
    ldaa 0,x
    staa sdk_tile_desc+2
    ldx sdk_map_ptr
    ldd 10,x
    std sdk_tile_desc
    ldaa 8,x
    adda sdk_map_x
    staa sdk_tile_desc+3
    ldaa 9,x
    adda sdk_map_y
    staa sdk_tile_desc+4
    ldx #sdk_tile_desc
    jsr sdk_tile
    tsta
    beq *+3
    rts
    inc sdk_map_x
    ldx sdk_map_ptr
    ldaa sdk_map_x
    cmpa 6,x
    bne sdk_map_column
    inc sdk_map_y
    ldaa sdk_map_y
    cmpa 7,x
    bne sdk_map_row
    clra
    rts
sdk_map_bad
    ldaa #GB_ARGUMENT
    rts
; Scroll the map window by one tile. B=0 left,1 right,2 up,3 down.
; COPY moves existing pixels; only the exposed strip is redrawn from the map.
; At a map boundary this is a successful no-op. Caller descriptor is updated.
sdk_scroll
    cmpb #3
    bls *+5
    jmp sdk_map_bad
    stab sdk_direction
    stx sdk_map_ptr
    jsr sdk_map_validate
    tsta
    beq *+3
    rts
    ldx sdk_map_ptr
    ldab sdk_direction
    bitb #2
    bne sdk_scroll_y
    bitb #1
    bne sdk_scroll_right
    tst 4,x
    bne *+5
    jmp sdk_scroll_noop
    dec 4,x
    bra sdk_scroll_move
sdk_scroll_right
    ldaa 4,x
    adda 6,x
    cmpa 2,x
    bcs *+5
    jmp sdk_scroll_noop
    inc 4,x
    bra sdk_scroll_move
sdk_scroll_y
    bitb #1
    bne sdk_scroll_down
    tst 5,x
    bne *+5
    jmp sdk_scroll_noop
    dec 5,x
    bra sdk_scroll_move
sdk_scroll_down
    ldaa 5,x
    adda 7,x
    cmpa 3,x
    bcs *+5
    jmp sdk_scroll_noop
    inc 5,x
sdk_scroll_move
    ldaa 11,x
    staa sdk_blit+2
    staa sdk_blit+3
    ldaa #64
    ldab 9,x
    aslb
    aslb
    aslb
    mul
    std sdk_offset
    asld
    asld
    addd sdk_offset
    std sdk_offset
    clra
    ldab 8,x
    asld
    asld
    asld
    addd sdk_offset
    std sdk_blit+4
    std sdk_blit+6
    clra
    ldab 6,x
    asld
    asld
    asld
    std sdk_blit+8
    ldaa 7,x
    asla
    asla
    asla
    staa sdk_blit+10
    ldab sdk_direction
    bitb #2
    bne sdk_scroll_vertical
    ldd sdk_blit+8
    subd #8
    std sdk_blit+8
    beq sdk_scroll_edge
    ldd #8
    bra sdk_scroll_delta
sdk_scroll_vertical
    ldaa sdk_blit+10
    suba #8
    staa sdk_blit+10
    beq sdk_scroll_edge
    ldd #2560
sdk_scroll_delta
    ; Reload the direction after forming the 16-bit pixel delta.
    psha
    pshb
    ldab sdk_direction
    bitb #1
    pulb
    pula
    beq sdk_scroll_dest
    addd sdk_blit+4
    std sdk_blit+4
    bra sdk_scroll_copy
sdk_scroll_dest
    addd sdk_blit+6
    std sdk_blit+6
sdk_scroll_copy
    ldaa #2
    staa sdk_blit
    clr sdk_blit+1
    ldx #sdk_blit
    ldaa #GB_COPY
    int GB_INT
    tsta
    beq sdk_scroll_edge
    rts
sdk_scroll_noop
    clra
    rts
sdk_scroll_edge
    ; Preserve the public descriptor and render a temporary one-row/column view.
    ldx sdk_map_ptr
    ldd 0,x
    std sdk_edge
    ldd 2,x
    std sdk_edge+2
    ldd 4,x
    std sdk_edge+4
    ldd 6,x
    std sdk_edge+6
    ldd 8,x
    std sdk_edge+8
    ldd 10,x
    std sdk_edge+10
    ldab sdk_direction
    bitb #2
    bne sdk_edge_row
    bitb #1
    beq sdk_edge_column_start
    ldaa sdk_edge+6
    deca
    adda sdk_edge+4
    staa sdk_edge+4
    ldaa sdk_edge+6
    deca
    adda sdk_edge+8
    staa sdk_edge+8
sdk_edge_column_start
    ldaa #1
    staa sdk_edge+6
    bra sdk_edge_draw
sdk_edge_row
    bitb #1
    beq sdk_edge_row_start
    ldaa sdk_edge+7
    deca
    adda sdk_edge+5
    staa sdk_edge+5
    ldaa sdk_edge+7
    deca
    adda sdk_edge+9
    staa sdk_edge+9
sdk_edge_row_start
    ldaa #1
    staa sdk_edge+7
sdk_edge_draw
    ldx #sdk_edge
    jmp sdk_map
