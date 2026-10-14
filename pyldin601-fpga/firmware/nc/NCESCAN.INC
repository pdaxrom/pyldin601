; Once a line's visible slice is drawn, scan ordinary off-screen runs in
; blocks. CR/LF/TAB and the cursor boundary return to the character parser.
scan_line_tail
    jsr stream_block
    bcc *+5
    jmp scan_tail_return
    ldx stream_left
    stx scan_take
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
    cmpa scan_take
    bne scan_tail_compare
    ldaa q+3
    cmpa scan_take+1
scan_tail_compare
    bcc scan_tail_limit
    ldx q+2
    stx scan_take
scan_tail_limit
    ldx stream_ptr
    stx scan_run_start
    ldaa scan_run_start+1
    adda scan_take+1
    staa scan_run_end+1
    ldaa scan_run_start
    adca scan_take
    staa scan_run_end
scan_run_byte
    ldaa 0,x
    cmpa #9
    beq scan_run_done
    cmpa #10
    beq scan_run_done
    cmpa #13
    beq scan_run_done
    inx
    cpx scan_run_end
    bne scan_run_byte
scan_run_done
    stx stream_ptr
    stx scan_run_end
    clr scan_advance
    clr scan_advance+1
    ldaa scan_run_end+1
    suba scan_run_start+1
    staa scan_advance+3
    ldaa scan_run_end
    sbca scan_run_start
    staa scan_advance+2
    ldaa scan_advance+2
    oraa scan_advance+3
    bne *+5
    jmp scan_tail_ok
    ldx #stream_remaining
    jsr q_load
    ldx #scan_advance
    jsr q_sub
    ldx #stream_remaining
    jsr q_store
    ldx #where
    jsr q_load
    ldx #scan_advance
    jsr q_add
    ldx #where
    jsr q_store
    ldx #scan_column
    jsr q_load
    ldx #scan_advance
    jsr q_add
    ldx #scan_column
    jsr q_store
    ldaa stream_left+1
    suba scan_advance+3
    staa stream_left+1
    ldaa stream_left
    sbca scan_advance+2
    staa stream_left
    ldaa #$ff
    staa poll_count
    jmp editor_poll
scan_tail_ok
    clra
scan_tail_return
    rts
