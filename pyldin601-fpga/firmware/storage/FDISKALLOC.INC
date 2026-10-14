; First-fit placement reads the resident 32-record list and the EBR chain.
; Existing partitions and table sectors are obstacles; no list is relocated.
ui_layout
    clr index
    clr ui_records
ui_layout_record
    jsr get_record
    tsta
    bne ui_layout_slots
    inc ui_records
    ldaa record+8
    cmpa #5
    bcc ui_layout_next
    ldaa record+9
    jsr extended_type
    bne ui_layout_next
    ldaa record+8
    staa ui_extpart
    ldx #ui_extbase
    stx pat
    ldx #record
    jsr ui_copy4
    jsr record_end
    ldx #ui_extend
    stx pat
    ldx #temp
    jsr ui_copy4
ui_layout_next
    inc index
    bra ui_layout_record
ui_layout_slots
    clr descriptor+2
    clr descriptor+3
    clr descriptor+4
    clr descriptor+5
    jsr read_table
    tsta
    beq ui_layout_mbr
    jmp finish_result
ui_layout_mbr
    clr slot
ui_layout_slot
    jsr entry_pointer
    tst 4,x
    beq ui_layout_free
    inc slot
    ldaa slot
    cmpa #4
    bcs ui_layout_slot
    ldaa #$ff
    staa ui_primary
    rts
ui_layout_free
    ldaa slot
    staa ui_primary
    rts
ui_allocate
    ldaa ui_records
    cmpa #32
    bcs ui_allocate_kind
    jmp ui_full
ui_allocate_kind
    ldaa ui_primary
    staa slot
    tst logical
    bne ui_allocate_logical
    cmpa #$ff
    bne ui_allocate_primary
    tst ui_extpart
    bne ui_allocate_fallback
    jmp ui_no_slot
ui_allocate_fallback
    inc logical
ui_allocate_logical
    ldaa kind
    jsr extended_type
    bne ui_allocate_data_kind
    jmp create_bad
ui_allocate_data_kind
    tst ui_extpart
    bne ui_allocate_existing
    ldaa ui_primary
    cmpa #$ff
    bne ui_allocate_new_container
    jmp ui_no_slot
ui_allocate_new_container
    ldaa ui_records
    cmpa #31
    bcs ui_allocate_new_ready
    jmp ui_full
ui_allocate_new_ready
    inc ui_make_ext
    ldaa #3
    staa ui_mode
    bra ui_allocate_initial
ui_allocate_existing
    ldaa #1
    staa ui_mode
    tst ui_explicit
    beq ui_allocate_initial
    inc ui_mode
    bra ui_allocate_initial
ui_allocate_primary
    clr ui_mode
ui_allocate_initial
    ldx #ui_limit
    stx pat
    ldx #capacity
    jsr ui_copy4
    ldx #ui_need
    stx pat
    ldx #ui_size
    jsr ui_copy4
    ldaa ui_mode
    bne ui_allocate_not_primary
    jmp ui_allocate_primary_begin
ui_allocate_not_primary
    cmpa #3
    beq ui_allocate_container_begin
    jsr ui_logical_limit
    ldx #ui_candidate
    stx pat
    ldx #ui_extbase
    jsr ui_copy4
    ldaa ui_mode
    cmpa #2
    beq ui_allocate_explicit_ebr
    jsr ui_align
    bra ui_allocate_add_gap
ui_allocate_explicit_ebr
    ldx #ui_end
    stx pat
    ldx #ui_limit
    stx ptr
    jsr ui_compare4
    bcc ui_allocate_explicit_end_ok
    jmp ui_no_space
ui_allocate_explicit_end_ok
    ldx #ui_limit
    stx pat
    ldx #ui_begin
    jsr ui_copy4
    ldx #ui_need
    stx pat
    ldx #ui_one
    jsr ui_copy4
    jmp ui_search
ui_allocate_container_begin
    tst ui_explicit
    beq ui_allocate_container_auto
    ldx #ui_candidate
    stx pat
    ldx #ui_begin
    jsr ui_copy4
    ldx #ui_candidate
    stx ptr
    ldx #ui_one
    stx pat
    jsr ui_sub4
    bcc ui_allocate_container_explicit
    jmp ui_no_space
ui_allocate_container_explicit
    ldx #ui_need
    stx ptr
    ldx #ui_one
    stx pat
    jsr ui_add4
    bcc ui_search
    jmp ui_no_space
ui_allocate_container_auto
    ldx #ui_candidate
    stx pat
    ldx #ui_gap
    jsr ui_copy4
ui_allocate_add_gap
    ldx #ui_need
    stx ptr
    ldx #ui_gap
    stx pat
    jsr ui_add4
    bcc ui_search
    jmp ui_no_space
ui_allocate_primary_begin
    ldx #ui_candidate
    stx pat
    ldx #ui_gap
    tst ui_explicit
    beq ui_allocate_primary_copy
    ldx #ui_begin
ui_allocate_primary_copy
    jsr ui_copy4
ui_search
    ldaa ui_candidate
    oraa ui_candidate+1
    oraa ui_candidate+2
    oraa ui_candidate+3
    bne ui_search_nonzero
    jmp ui_no_space
ui_search_nonzero
    ldx #ui_range_end
    stx pat
    ldx #ui_candidate
    jsr ui_copy4
    ldx #ui_range_end
    stx ptr
    ldx #ui_need
    stx pat
    jsr ui_add4
    bcc ui_search_end
    jmp ui_no_space
ui_search_end
    ldx #ui_limit
    stx ptr
    ldx #ui_range_end
    stx pat
    jsr ui_compare4
    bcc ui_search_records
    jmp ui_no_space
ui_search_records
    clr index
ui_search_record
    jsr get_record
    tsta
    beq ui_search_present
    jmp ui_search_tables
ui_search_present
    ldaa ui_mode
    beq ui_search_primary_record
    cmpa #3
    beq ui_search_primary_record
    ldaa record+9
    jsr extended_type
    beq ui_search_record_next
    bra ui_search_data_record
ui_search_primary_record
    ldaa record+8
    cmpa #5
    bcc ui_search_record_next
ui_search_data_record
    jsr record_end
    ldaa ui_mode
    cmpa #2
    bne ui_search_candidate_record
    ; Fixed data bounds must also be free while we look for an EBR sector.
    ldx #ui_begin
    stx ptr
    ldx #temp
    stx pat
    jsr ui_compare4
    bcc ui_search_candidate_record
    ldx #record
    stx ptr
    ldx #ui_end
    stx pat
    jsr ui_compare4
    bcc ui_search_candidate_record
    jmp ui_no_space
ui_search_candidate_record
    ldx #ui_candidate
    stx ptr
    ldx #temp
    stx pat
    jsr ui_compare4
    bcc ui_search_record_next
    ldx #record
    stx ptr
    ldx #ui_range_end
    stx pat
    jsr ui_compare4
    bcc ui_search_record_next
    ldx #ui_next
    stx pat
    ldx #temp
    jsr ui_copy4
    jmp ui_advance
ui_search_record_next
    inc index
    jmp ui_search_record
ui_search_tables
    ldaa ui_mode
    bne ui_search_tables_logical
    jmp ui_selected
ui_search_tables_logical
    cmpa #3
    bne ui_search_tables_existing
    jmp ui_selected
ui_search_tables_existing
    clr ui_reuse
    clr ui_tables
    clr ui_empty_table
    clr ui_empty_table+1
    clr ui_empty_table+2
    clr ui_empty_table+3
    ldx #ui_table
    stx pat
    ldx #ui_extbase
    jsr ui_copy4
ui_table_loop
    inc ui_tables
    ldaa ui_tables
    cmpa #32
    bls ui_table_read
    jmp ui_full
ui_table_read
    ldx #ui_table
    jsr set_lba
    jsr read_table
    tsta
    beq ui_table_valid
    jmp finish_result
ui_table_valid
    ; An empty earlier link can hold a new volume elsewhere in the container.
    ; Reuse it even when all 32 EBR links already exist.
    tst sector+450
    bne ui_table_data_check
    ldx #ui_table
    stx ptr
    ldx #ui_candidate
    stx pat
    jsr ui_compare4
    bcc ui_table_data_check
    ldaa ui_empty_table
    oraa ui_empty_table+1
    oraa ui_empty_table+2
    oraa ui_empty_table+3
    bne ui_table_data_check
    ldx #ui_empty_table
    stx pat
    ldx #ui_table
    jsr ui_copy4
ui_table_data_check
    ldaa ui_mode
    cmpa #2
    bne ui_table_candidate
    ldx #ui_table
    stx ptr
    ldx #ui_begin
    stx pat
    jsr ui_compare4
    bcs ui_table_candidate
    ldx #ui_end
    stx pat
    jsr ui_compare4
    bcc ui_table_candidate
    jmp ui_no_space
ui_table_candidate
    ldx #ui_table
    stx ptr
    ldx #ui_candidate
    stx pat
    jsr ui_compare4
    bcs ui_table_link
    ldx #ui_range_end
    stx pat
    jsr ui_compare4
    bcc ui_table_link
    ldaa ui_table
    eora ui_candidate
    staa ui_diff
    ldaa ui_table+1
    eora ui_candidate+1
    oraa ui_diff
    staa ui_diff
    ldaa ui_table+2
    eora ui_candidate+2
    oraa ui_diff
    staa ui_diff
    ldaa ui_table+3
    eora ui_candidate+3
    oraa ui_diff
    bne ui_table_obstacle
    tst sector+450
    bne ui_table_obstacle
    inc ui_reuse
    bra ui_table_link
ui_table_obstacle
    ldx #ui_next
    stx pat
    ldx #ui_table
    jsr ui_copy4
    ldx #ui_next
    stx ptr
    ldx #ui_one
    stx pat
    jsr ui_add4
    bcc ui_table_advance
    jmp ui_no_space
ui_table_advance
    jmp ui_advance
ui_table_link
    tst sector+466
    beq ui_table_complete
    ldx #ui_table
    stx pat
    ldx #sector+470
    jsr ui_copy4
    ldx #ui_table
    stx ptr
    ldx #ui_extbase
    stx pat
    jsr ui_add4
    bcc ui_table_loop_jump
    jmp ui_no_space
ui_table_loop_jump
    jmp ui_table_loop
ui_table_complete
    ldaa ui_tables
    cmpa #32
    bcs ui_selected
    tst ui_reuse
    bne ui_selected
    ldaa ui_empty_table
    oraa ui_empty_table+1
    oraa ui_empty_table+2
    oraa ui_empty_table+3
    bne ui_selected
    jmp ui_full
ui_selected
    ldaa ui_mode
    cmpa #2
    beq ui_selected_ebr
    ldx #ui_end
    stx pat
    ldx #ui_range_end
    jsr ui_copy4
    ldaa ui_mode
    beq ui_selected_primary
    tst ui_explicit
    bne ui_selected_ebr
    ldx #ui_begin
    stx pat
    ldx #ui_candidate
    jsr ui_copy4
    ldx #ui_begin
    stx ptr
    ldx #ui_gap
    stx pat
    jsr ui_add4
    jmp ui_selected_ebr
ui_selected_primary
    ldx #ui_begin
    stx pat
    ldx #ui_candidate
    jsr ui_copy4
    rts
ui_selected_ebr
    ldx #ebr
    stx pat
    ldx #ui_candidate
    ldaa ui_mode
    cmpa #1
    bne ui_selected_ebr_copy
    ldaa ui_empty_table
    oraa ui_empty_table+1
    oraa ui_empty_table+2
    oraa ui_empty_table+3
    beq ui_selected_ebr_copy
    ldx #ui_empty_table
ui_selected_ebr_copy
    jsr ui_copy4
    rts
ui_advance
    tst ui_explicit
    beq ui_advance_copy
    ldaa ui_mode
    cmpa #2
    beq ui_advance_copy
    jmp ui_no_space
ui_advance_copy
    ldx #ui_candidate
    stx pat
    ldx #ui_next
    jsr ui_copy4
    tst ui_explicit
    bne ui_advance_restart
    jsr ui_align
ui_advance_restart
    jmp ui_search
ui_align
    ; Ceil to a 2048-sector boundary, rejecting wrap.
    ldx #ui_candidate
    stx ptr
    ldx #ui_round
    stx pat
    jsr ui_add4
    bcc ui_align_mask
    jmp ui_no_space
ui_align_mask
    clr ui_candidate
    ldaa ui_candidate+1
    anda #$f8
    staa ui_candidate+1
    rts
ui_logical_limit
    ; A container may grow until the next primary, never across one to reach
    ; an otherwise empty range beyond it.
    clr index
ui_limit_record
    jsr get_record
    tsta
    bne ui_limit_done
    ldaa record+8
    cmpa #5
    bcc ui_limit_next
    cmpa ui_extpart
    beq ui_limit_next
    ldx #record
    stx ptr
    ldx #ui_extbase
    stx pat
    jsr ui_compare4
    bcs ui_limit_next
    ldx #ui_limit
    stx pat
    jsr ui_compare4
    bcc ui_limit_next
    ldx #ui_limit
    stx pat
    ldx #record
    jsr ui_copy4
ui_limit_next
    inc index
    bra ui_limit_record
ui_limit_done
    rts
ui_compare4
    ldx ptr
    ldaa 0,x
    ldx pat
    suba 0,x
    ldx ptr
    ldaa 1,x
    ldx pat
    sbca 1,x
    ldx ptr
    ldaa 2,x
    ldx pat
    sbca 2,x
    ldx ptr
    ldaa 3,x
    ldx pat
    sbca 3,x
    rts
ui_add4
    ldx ptr
    ldaa 0,x
    ldx pat
    adda 0,x
    ldx ptr
    staa 0,x
    ldx ptr
    ldaa 1,x
    ldx pat
    adca 1,x
    ldx ptr
    staa 1,x
    ldx ptr
    ldaa 2,x
    ldx pat
    adca 2,x
    ldx ptr
    staa 2,x
    ldx ptr
    ldaa 3,x
    ldx pat
    adca 3,x
    ldx ptr
    staa 3,x
    rts
ui_sub4
    ldx ptr
    ldaa 0,x
    ldx pat
    suba 0,x
    ldx ptr
    staa 0,x
    ldx ptr
    ldaa 1,x
    ldx pat
    sbca 1,x
    ldx ptr
    staa 1,x
    ldx ptr
    ldaa 2,x
    ldx pat
    sbca 2,x
    ldx ptr
    staa 2,x
    ldx ptr
    ldaa 3,x
    ldx pat
    sbca 3,x
    ldx ptr
    staa 3,x
    rts
; Compact full-width decimal output, independent of the legacy INT24 word.
ui_print32
    stx ui_print_ptr
    ldx #ui_print_value
    stx pat
    ldx ui_print_ptr
    jsr ui_copy4
    clr ui_started
    ldx #ui_powers
    stx ui_power
ui_print_digit
    clr ui_digit
ui_print_subtract
    ldx #ui_print_value
    stx ptr
    ldx ui_power
    stx pat
    jsr ui_compare4
    bcs ui_print_character
    jsr ui_sub4
    inc ui_digit
    bra ui_print_subtract
ui_print_character
    tst ui_digit
    bne ui_print_visible
    tst ui_started
    bne ui_print_visible
    ldx ui_power
    cpx #ui_powers_end-4
    bne ui_print_advance
ui_print_visible
    inc ui_started
    ldaa ui_digit
    adda #'0'
    int $22
ui_print_advance
    ldx ui_power
    inx
    inx
    inx
    inx
    stx ui_power
    cpx #ui_powers_end
    bne ui_print_digit
    rts
ui_mode db 0
ui_empty_table ds 4
ui_diff db 0
ui_need ds 4
ui_round db $ff,7,0,0
ui_print_value ds 4
ui_power dw 0
ui_digit db 0
ui_started db 0
ui_powers
    db 0,$ca,$9a,$3b
    db 0,$e1,$f5,5
    db $80,$96,$98,0
    db $40,$42,$f,0
    db $a0,$86,1,0
    db $10,$27,0,0
    db $e8,3,0,0
    db $64,0,0,0
    db $a,0,0,0
    db 1,0,0,0
ui_powers_end
