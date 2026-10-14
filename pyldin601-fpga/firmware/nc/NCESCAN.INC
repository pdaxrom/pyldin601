; Once a line's visible slice is drawn, scan ordinary off-screen runs in
; blocks. CR/LF/TAB and the cursor boundary return to the character parser.
scan_line_tail
    jsr stream_block
    bcc *+5
    jmp scan_tail_return
    ldx stream_left
    stx view_tail+0
    ldx #e_cursor
    jsr q_load
    ldx #where
    jsr q_sub
    bcs scan_tail_limit
    jsr q_test
    bne *+5
    jmp scan_tail_ok
    ldaa q
    oraa q+1
    bne scan_tail_limit
    ldaa q+2
    cmpa view_tail+0
    bne scan_tail_compare
    ldaa q+3
    cmpa view_tail+0+1
scan_tail_compare
    bcc scan_tail_limit
    ldx q+2
    stx view_tail+0
scan_tail_limit
    ldx stream_ptr
    stx view_tail+2
    ldaa view_tail+2+1
    adda view_tail+0+1
    staa view_tail+4+1
    ldaa view_tail+2
    adca view_tail+0
    staa view_tail+4
scan_run_byte
    ldaa 0,x
    cmpa #9
    beq scan_run_done
    cmpa #10
    beq scan_run_done
    cmpa #13
    beq scan_run_done
    inx
    cpx view_tail+4
    bne scan_run_byte
scan_run_done
    stx stream_ptr
    stx view_tail+4
    clr view_tail+6
    clr view_tail+6+1
    ldaa view_tail+4+1
    suba view_tail+2+1
    staa view_tail+6+3
    ldaa view_tail+4
    sbca view_tail+2
    staa view_tail+6+2
    ldaa view_tail+6+2
    oraa view_tail+6+3
    bne *+5
    jmp scan_tail_ok
    ldx #stream_remaining
    jsr q_load
    ldx #view_tail+6
    jsr q_sub
    ldx #stream_remaining
    jsr q_store
    ldx #where
    jsr q_load
    ldx #view_tail+6
    jsr q_add
    ldx #where
    jsr q_store
    ldx #view_scan+2
    jsr q_load
    ldx #view_tail+6
    jsr q_add
    ldx #view_scan+2
    jsr q_store
    ldaa stream_left+1
    suba view_tail+6+3
    staa stream_left+1
    ldaa stream_left
    sbca view_tail+6+2
    staa stream_left
    ldaa #$ff
    staa poll_count
    jmp editor_poll
scan_tail_ok
    clra
scan_tail_return
    rts
