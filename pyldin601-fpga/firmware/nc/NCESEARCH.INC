; KMP search streams arbitrary-length documents, preserving the last pattern.
; Its prefix table reuses the line-construction buffer while the modal owns UI.
editor_search
    ldx #search_text
    stx src
    ldx #input
    stx dst
    jsr copy_z
    ldx #search_title
    jsr dialog
    bcc *+5
    jmp search_cancel
    tst input
    bne *+5
    jmp search_cancel
    ldx #input
    stx src
    ldx #search_text
    stx dst
    jsr copy_z
    clr search_skip
    bra search_begin
editor_search_next
    tst search_text
    beq editor_search
    ldaa #1
    staa search_skip
search_begin
    clr search_length
    ldx #search_text
search_count
    tst 0,x
    beq search_prefix
    inx
    inc search_length
    bra search_count
search_prefix
    clr search_prefix_table
    clr search_j
    ldaa #1
    staa search_i
search_prefix_loop
    ldaa search_i
    cmpa search_length
    bcc search_open
    tab
    ldx #search_text
    jsr add_b
    ldaa 0,x
    staa search_char
search_prefix_compare
    ldab search_j
    ldx #search_text
    jsr add_b
    ldaa 0,x
    cmpa search_char
    beq search_prefix_match
    tst search_j
    beq search_prefix_store
    ldab search_j
    decb
    ldx #search_prefix_table
    jsr add_b
    ldaa 0,x
    staa search_j
    bra search_prefix_compare
search_prefix_match
    inc search_j
search_prefix_store
    ldab search_i
    ldx #search_prefix_table
    jsr add_b
    ldaa search_j
    staa 0,x
    inc search_i
    bra search_prefix_loop
search_open
    ldx #search_title
    jsr window_open
    ldx #search_text
    ldaa #8
    jsr window_line
    ldx #cancel_save_text
    ldaa #16
    jsr window_line
    ldaa e_cursor
    staa where
    ldaa e_cursor+1
    staa where+1
    ldaa e_cursor+2
    staa where+2
    ldaa e_cursor+3
    staa where+3
    tst search_skip
    beq search_position
    ldx #where
    jsr q_load
    ldx #doc_size
    jsr q_cmp
    bcc search_position
    jsr q_inc
    ldx #where
    jsr q_store
search_position
    ldaa where
    staa search_start
    ldaa where+1
    staa search_start+1
    ldaa where+2
    staa search_start+2
    ldaa where+3
    staa search_start+3
    clr search_wrapped
search_stream
    clr search_j
    jsr stream_init
    bcc *+5
    jmp search_end
search_byte
    tst search_wrapped
    beq search_read
    ldx #where
    jsr q_load
    ldx #search_start
    jsr q_cmp
    bcs *+5
    jmp search_not_found
search_read
    jsr stream_next
    bcc *+5
    jmp search_end
    staa search_char
search_compare
    ldab search_j
    ldx #search_text
    jsr add_b
    ldaa 0,x
    cmpa search_char
    beq search_match
    tst search_j
    beq search_advance
    ldab search_j
    decb
    ldx #search_prefix_table
    jsr add_b
    ldaa 0,x
    staa search_j
    bra search_compare
search_match
    inc search_j
    ldaa search_j
    cmpa search_length
    beq search_found
search_advance
    jsr editor_poll
    tsta
    beq *+5
    jmp search_return
    ldaa where+2
    anda #15
    oraa where+3
    bne search_byte
    ldaa where
    staa number
    ldaa where+1
    staa number+1
    ldaa where+2
    staa number+2
    ldaa where+3
    staa number+3
    jsr decimal_number
    ldx #number_text
    ldaa #11
    jsr window_line
    jmp search_byte
search_end
    tsta
    beq *+5
    jmp search_return
    tst search_wrapped
    bne search_not_found
    inc search_wrapped
    clr where
    clr where+1
    clr where+2
    clr where+3
    jmp search_stream
search_found
    ldaa search_length
    jsr q_small
    ldx #search_amount
    jsr q_store
    ldx #where
    jsr q_load
    ldx #search_amount
    jsr q_sub
    ldx #e_cursor
    jsr q_store
    ldx #nav_start
    jsr q_store
    jsr find_line_start
    tsta
    beq *+5
    jmp search_return
    ldaa nav_start
    staa screen_top
    ldaa nav_start+1
    staa screen_top+1
    ldaa nav_start+2
    staa screen_top+2
    ldaa nav_start+3
    staa screen_top+3
    clr horizontal
    clr horizontal+1
    clr horizontal+2
    clr horizontal+3
    jsr build_view
    tsta
    beq *+5
    jmp search_return
    jsr ensure_horizontal
    clra
search_return
    rts
search_not_found
    ldx #not_found_text
    jsr message
    clra
    rts
search_cancel
    ldaa #$ff
    rts
