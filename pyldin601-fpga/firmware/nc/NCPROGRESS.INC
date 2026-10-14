; Per-file byte progress uses actual successful writes and unsigned 32-bit
; thresholds. Directory traversal/deletion show activity and completed items.
progress_open
    tst progress_visible
    bne progress_open_done
    ldaa #1
    staa progress_visible
    ldaa columns
    suba #18
    staa progress_width
    ldab operation
    decb
    aslb
    ldx #progress_titles
    jsr add_b
    ldx 0,x
    jsr window_open
    ldaa #$07
    jsr colour
    ldx #cancel_button
    ldaa #16
    jsr window_line
progress_open_done
    rts
progress_activity
    jsr progress_open
    clr progress_mode
    ldaa #8
    ldx #source_path
    jsr progress_path
    ldaa operation
    cmpa #3
    beq progress_activity_draw
    ldaa #10
    ldx #target_path
    jsr progress_path
progress_activity_draw
    jmp progress_draw
progress_path
    stx window_text
    staa ui_y
    ldaa #6
    staa ui_x
    ldaa #$07
    jsr colour
    jsr position
    ldaa columns
    suba #12
    staa remaining
    ldx #progress_from
    ldaa ui_y
    cmpa #8
    beq progress_path_label
    ldx #progress_to
progress_path_label
    jsr text_field
    ldx window_text
    jsr path_length
    cmpb remaining
    bcs progress_path_full
    subb remaining
    ldx window_text
    jsr add_b
    bra progress_path_text
progress_path_full
    ldx window_text
progress_path_text
    jmp field
progress_start
    ldaa source_handle
    ldx #progress_total
    int $51
    tsta
    beq progress_size_ready
    rts
progress_size_ready
    ldx #progress_done
    ldab #4
progress_clear_done
    clr 0,x
    inx
    decb
    bne progress_clear_done
    clr progress_cells
    jsr progress_activity
    ldaa #1
    staa progress_mode
    ldx #progress_total
    jsr progress_number
    ldaa progress_width
    staa number_divisor
    jsr divide_number
    tst remainder
    beq progress_round_done
    inc number+3
    bne progress_round_done
    inc number+2
    bne progress_round_done
    inc number+1
    bne progress_round_done
    inc number
progress_round_done
    ldx #number
    stx src
    ldx #progress_quantum
    stx dst
    ldab #4
    jsr copy_n
    ldx #progress_quantum
    stx src
    ldx #progress_next
    stx dst
    ldab #4
    jsr copy_n
    jsr progress_draw
    clra
    rts
; X=successful write length. Preserve no transient file-I/O pointers.
progress_update
    stx progress_bytes
    ldaa progress_done+3
    adda progress_bytes+1
    staa progress_done+3
    ldaa progress_done+2
    adca progress_bytes
    staa progress_done+2
    ldaa progress_done+1
    adca #0
    staa progress_done+1
    ldaa progress_done
    adca #0
    staa progress_done
    ldaa progress_cells
    staa progress_painted
progress_threshold
    ldaa progress_cells
    cmpa progress_width
    bcc progress_update_done
    ldx #progress_done
    stx src
    ldx #progress_next
    stx dst
    ldab #4
progress_compare
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    cmpa 0,x
    bcs progress_update_done
    bhi progress_advance
    inx
    stx dst
    decb
    bne progress_compare
progress_advance
    inc progress_cells
    ldaa progress_next+3
    adda progress_quantum+3
    staa progress_next+3
    ldaa progress_next+2
    adca progress_quantum+2
    staa progress_next+2
    ldaa progress_next+1
    adca progress_quantum+1
    staa progress_next+1
    ldaa progress_next
    adca progress_quantum
    staa progress_next
    bcc progress_threshold
    ldx #progress_next
    ldab #4
    ldaa #$ff
progress_saturate
    staa 0,x
    inx
    decb
    bne progress_saturate
progress_update_done
    ldaa progress_cells
    cmpa progress_painted
    beq progress_no_draw
    jmp progress_draw
progress_no_draw
    rts
progress_finish
    inc progress_items+3
    bne progress_finished_count
    inc progress_items+2
    bne progress_finished_count
    inc progress_items+1
    bne progress_finished_count
    inc progress_items
progress_finished_count
    ldaa progress_width
    tst progress_mode
    bne progress_finish_cells
    ldaa progress_cells
    adda #4
    cmpa progress_width
    bcs progress_finish_cells
    clra
progress_finish_cells
    staa progress_cells
progress_draw
    ldaa #6
    staa ui_x
    ldaa #12
    staa ui_y
    ldaa #$71
    jsr colour
    jsr position
    ldaa #'['
    jsr put
    clr progress_index
progress_bar_cell
    ldaa #' '
    ldab progress_index
    cmpb progress_cells
    bcc progress_bar_empty
    ldaa #$db
progress_bar_empty
    jsr put
    inc progress_index
    ldaa progress_index
    cmpa progress_width
    bcs progress_bar_cell
    ldaa #']'
    jsr put
    ldaa #6
    staa ui_x
    ldaa #14
    staa ui_y
    ldaa #$07
    jsr colour
    jsr position
    ldaa columns
    suba #12
    staa remaining
    ldx #progress_items
    tst progress_mode
    beq progress_item_count
    ldx #progress_done
    jsr progress_number
    jsr decimal_number
    ldx #number_text
    jsr text_field
    ldx #progress_slash
    jsr text_field
    ldx #progress_total
    bra progress_amount
progress_item_count
    ldx #progress_item_label
    jsr text_field
    ldx #progress_items
progress_amount
    jsr progress_number
    jsr decimal_number
    ldx #number_text
    jmp field
progress_number
    ldaa 0,x
    staa number
    ldaa 1,x
    staa number+1
    ldaa 2,x
    staa number+2
    ldaa 3,x
    staa number+3
    rts
