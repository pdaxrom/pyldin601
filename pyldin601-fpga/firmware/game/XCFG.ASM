; XONIX.CFG: up to ten relative paths, 63 bytes per line. CRLF/LF,
; surrounding spaces, empty lines, #/; comments and DOS Ctrl-Z accepted.
; Only a missing or empty file defaults to LENA.IFF; malformed/I/O errors
; unwind and close the handle. Reuse the later IFF input buffer at startup.
xc_load
    sts xc_sp
    ldx #xo_config_name
    jsr hs_asset_path
    stx xc_ot
    clr xc_ot+2
    clr xc_ot+3
    ldx #xc_ot
    ldaa #1
    int $4a
    tsta
    beq xc_open
    ; Native UniDOS reports missing pathname components as 11, including
    ; an absent final filename; the shell's translated Not Found is 73.
    cmpa #11
    bne *+5
    jmp xc_default
    cmpa #73
    bne *+5
    jmp xc_default
    jmp xc_error
xc_open
    stab xc_h
    inc xc_op
    ldaa xc_h
    ldx #xc_sz
    int $51
    tsta
    beq *+5
    jmp xc_error
    ldd xc_sz
    beq *+5
    jmp xc_error
    ldd xc_sz+2
    std xc_left
    subd #4096
    bls *+5
    jmp xc_error
xc_next
    jsr xc_get
    bcs xc_end
    cmpa #26
    beq xc_end
    cmpa #13
    beq xc_nl
    cmpa #10
    beq xc_nl
    tst xc_c
    bne xc_next
    cmpa #'#'
    beq xc_comment
    cmpa #';'
    beq xc_comment
    cmpa #9
    bne xc_tab
    ldaa #' '
xc_tab
    cmpa #32
    bcc *+5
    jmp xc_error
    tst xc_len
    bne xc_append
    cmpa #' '
    beq xc_next
    ldab xc_n
    cmpb #10
    bcs *+5
    jmp xc_error
    psha
    ldaa #64
    mul
    addd #xc_names
    std xc_dst
    pula
xc_append
    ldab xc_len
    cmpb #63
    bcs *+5
    jmp xc_error
    ldx xc_dst
    staa 0,x
    inx
    stx xc_dst
    inc xc_len
    bra xc_next
xc_comment
    inc xc_c
    bra xc_next
xc_nl
    jsr xc_line
    clr xc_c
    bra xc_next
xc_end
    jsr xc_line
    jsr xc_close
    tst xc_n
    beq xc_default
    clra
    rts
xc_line
    tst xc_len
    beq xc_done
    ldx xc_dst
xc_trim
    dex
    ldaa 0,x
    cmpa #' '
    bne xc_kept
    dec xc_len
    bne xc_trim
    bra xc_done
xc_kept
    inx
    clr 0,x
    inc xc_n
xc_done
    clr xc_len
    rts
xc_default
    ldx #xo_picture_name
    stx xc_ptr
    ldx #xc_names
xc_copy
    pshx
    ldx xc_ptr
    ldaa 0,x
    inx
    stx xc_ptr
    pulx
    staa 0,x
    inx
    tsta
    bne xc_copy
    ldaa #1
    staa xc_n
    clra
    rts
xc_get
    ldd xc_av
    bne xc_buf
    ldd xc_left
    beq xc_eof
    subd #512
    bcc xc_full
    ldd xc_left
    bra xc_refill
xc_full
    ldd #512
xc_refill
    std xc_io+2
    ldd #hi_buf
    std xc_io
    ldaa xc_h
    ldx #xc_io
    int $4c
    tsta
    beq *+5
    jmp xc_error
    cpx xc_io+2
    beq *+5
    jmp xc_error
    stx xc_av
    ldd xc_left
    subd xc_av
    std xc_left
    ldd #hi_buf
    std xc_ptr
xc_buf
    ldx xc_ptr
    ldaa 0,x
    inx
    stx xc_ptr
    psha
    ldd xc_av
    subd #1
    std xc_av
    pula
    clc
    rts
xc_eof
    sec
    rts
xc_error
    lds xc_sp
    jsr xc_close
    ldaa #1
    rts
xc_close
    tst xc_op
    beq xc_closed
    ldaa xc_h
    int $4e
    clr xc_op
xc_closed
    rts
