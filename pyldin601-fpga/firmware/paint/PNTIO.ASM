; Bounded buffered UniDOS streams. The dead loader prefix supplies 512 bytes;
; the current image is never the destination of an input file operation.
    public io_handle
    public io_live
    public io_error
    public io_writing
    public io_position
    public io_limit
    public io_size
    public io_count
    public io_begin
    public io_get
    public io_put
    public io_read
    public io_write
    public io_flush
    public io_close
    public io_seek
    public io_cancel
    public q_left
    public q_right
    public q_value
    public q_add
    public q_sub
    public q_compare
    extern p_file_buffer
    extern mouse_cancel
    section
io_handle ds 1
io_live ds 1
io_error ds 1
io_writing ds 1
io_position ds 4
io_limit ds 4
io_size ds 4
io_count ds 2
io_left ds 2
io_pointer ds 2
io_table ds 4
io_transfer ds 2
io_walk ds 2
io_byte ds 1
io_result ds 1
io_seek_ptr ds 2
q_left ds 2
q_right ds 2
q_value ds 4
q_a ds 4
q_b ds 4
    ends
; Caller owns a successfully opened io_handle. A=0 input,1 output.
io_begin
    staa io_writing
    inc io_live
    clr io_error
    ldx #io_position
    ldab #4
io_position_zero
    clr 0,x
    inx
    decb
    bne io_position_zero
    ldx #0
    stx io_left
    ldx p_file_buffer
    stx io_pointer
    tst io_writing
    bne io_begin_ok
    ldaa io_handle
    ldx #io_size
    int $51
    staa io_error
    bne io_begin_return
    ldx #io_size
    stx q_left
    ldx #io_limit
    jsr q_copy_four
io_begin_ok
    clra
io_begin_return
    rts
; X=destination, q_left=source; no shared UI scratch used by disk streams.
q_copy_four
    stx q_right
    ldx q_left
    ldaa 0,x
    ldab 1,x
    ldx q_right
    staa 0,x
    stab 1,x
    ldx q_left
    ldaa 2,x
    ldab 3,x
    ldx q_right
    staa 2,x
    stab 3,x
    rts
q_operands
    ldx q_left
    ldaa 0,x
    ldab 1,x
    staa q_a
    stab q_a+1
    ldaa 2,x
    ldab 3,x
    staa q_a+2
    stab q_a+3
    ldx q_right
    ldaa 0,x
    ldab 1,x
    staa q_b
    stab q_b+1
    ldaa 2,x
    ldab 3,x
    staa q_b+2
    stab q_b+3
    rts
q_add
    jsr q_operands
    ldaa q_a+3
    adda q_b+3
    staa q_value+3
    ldaa q_a+2
    adca q_b+2
    staa q_value+2
    ldaa q_a+1
    adca q_b+1
    staa q_value+1
    ldaa q_a
    adca q_b
    staa q_value
    rts
q_sub
    jsr q_operands
    ldaa q_a+3
    suba q_b+3
    staa q_value+3
    ldaa q_a+2
    sbca q_b+2
    staa q_value+2
    ldaa q_a+1
    sbca q_b+1
    staa q_value+1
    ldaa q_a
    sbca q_b
    staa q_value
    rts
; Carry/zero from an unsigned, lexicographic comparison of two BE32 values.
q_compare
    jsr q_operands
    ldaa q_a
    cmpa q_b
    bne q_return
    ldaa q_a+1
    cmpa q_b+1
    bne q_return
    ldaa q_a+2
    cmpa q_b+2
    bne q_return
    ldaa q_a+3
    cmpa q_b+3
q_return
    rts
io_advance
    inc io_position+3
    bne advance_done
    inc io_position+2
    bne advance_done
    inc io_position+1
    bne advance_done
    inc io_position
advance_done
    rts
io_get
    tst io_error
    beq *+5
    jmp io_fail
    ldx io_left
    cpx #0
    bne io_get_buffered
    ldx #io_limit
    stx q_left
    ldx #io_position
    stx q_right
    jsr q_sub
    bcs io_eof
    ldaa q_value
    oraa q_value+1
    oraa q_value+2
    oraa q_value+3
    beq io_eof
    ldx #512
    ldaa q_value
    oraa q_value+1
    bne io_get_count
    ldaa q_value+2
    cmpa #2
    bcc io_get_count
    ldx q_value+2
io_get_count
    stx io_table+2
    stx io_transfer
    ldx p_file_buffer
    stx io_table
    stx io_pointer
    ldaa io_handle
    ldx #io_table
    int $4c
    tsta
    beq *+5
    jmp io_set_error
    stx io_left
    cpx io_transfer
    bne io_eof
io_get_buffered
    ldx io_pointer
    ldaa 0,x
    staa io_byte
    inx
    stx io_pointer
    ldx io_left
    dex
    stx io_left
    jsr io_advance
    ldaa io_byte
    clc
    rts
io_eof
    ldaa #65
io_set_error
    staa io_error
io_fail
    ldaa io_error
    sec
    rts
io_put
    staa io_byte
    tst io_error
    beq *+5
    jmp io_fail
    ldx io_pointer
    staa 0,x
    inx
    stx io_pointer
    ldx io_left
    inx
    stx io_left
    jsr io_advance
    cpx #512
    beq io_flush
    clra
    clc
    rts
io_flush
    tst io_error
    beq *+5
    jmp io_fail
    ldx io_left
    cpx #0
    beq io_flush_ok
    stx io_table+2
    stx io_transfer
    ldx p_file_buffer
    stx io_table
    ldaa io_handle
    ldx #io_table
    int $4d
    tsta
    beq *+5
    jmp io_set_error
    cpx io_transfer
    bne io_short_write
    ldx #0
    stx io_left
    ldx p_file_buffer
    stx io_pointer
io_flush_ok
    clra
    clc
    rts
io_short_write
    ldaa #12
    bra io_set_error
; X=buffer, io_count=BE16 length; carry set on error.
io_read
    stx io_walk
io_read_next
    ldx io_count
    cpx #0
    beq io_flush_ok
    jsr io_get
    bcc *+5
    jmp io_fail
    ldx io_walk
    staa 0,x
    inx
    stx io_walk
    ldx io_count
    dex
    stx io_count
    bra io_read_next
io_write
    stx io_walk
io_write_next
    ldx io_count
    cpx #0
    beq io_flush_ok
    ldx io_walk
    ldaa 0,x
    inx
    stx io_walk
    jsr io_put
    bcc *+5
    jmp io_fail
    ldx io_count
    dex
    stx io_count
    bra io_write_next
; X=BE32 absolute offset. Discard prefetched bytes only after a valid seek.
io_seek
    stx io_seek_ptr
    ldaa io_handle
    clrb
    int $50
    tsta
    beq *+5
    jmp io_set_error
    ldx io_seek_ptr
    stx q_left
    ldx #io_position
    jsr q_copy_four
    ldx #0
    stx io_left
    ldx p_file_buffer
    stx io_pointer
    clr io_error
    clra
    clc
    rts
io_close
    tst io_live
    beq io_close_return
    tst io_writing
    beq io_close_handle
    jsr io_flush
io_close_handle
    ldaa io_error
    staa io_result
    ldaa io_handle
    int $4e
    clr io_live
    ldab io_result
    bne io_close_previous
    staa io_error
    rts
io_close_previous
    stab io_error
io_close_return
    ldaa io_error
    rts
io_cancel
    ldaa #1
    jsr mouse_cancel
    cmpa #27
    beq io_cancel_yes
    clra
    rts
io_cancel_yes
    ldaa #255
    staa io_error
    rts
    end
