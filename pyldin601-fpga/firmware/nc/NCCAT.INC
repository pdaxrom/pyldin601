; A=panel. All pointers are process-local or explicitly parent-owned.
choose_panel
    anda #1
    staa requested_panel
    tst cache_valid
    beq choose_no_save
    cmpa cache_owner
    beq choose_no_save
    tst cache_lease_open
    bne choose_no_save
    jsr save_marks
choose_no_save
    ldaa requested_panel
    staa panel
    tab
    ldx #counts
    jsr add_b
    ldaa 0,x
    staa pcount
    ldab panel
    ldx #cursors
    jsr add_b
    ldaa 0,x
    staa pcur
    ldab panel
    ldx #tops
    jsr add_b
    ldaa 0,x
    staa ptop
    ldx #entries_left
    tst cache_lease_open
    beq choose_cache
    ldx #$c000
    tst panel
    beq choose_cache
    ldx #$d000
choose_cache
    stx cacheptr
    ldx owner
    ldab #S_PATHS
    jsr add_b
    tst panel
    beq choose_path
    ldab #PATH_SIZE
    jsr add_b
choose_path
    stx pathptr
    tst cache_valid
    beq choose_reload
    ldaa panel
    cmpa cache_owner
    beq choose_ready
choose_reload
    ldaa panel
    staa cache_owner
    ldaa #1
    staa cache_valid
    tst cache_lease_open
    beq choose_read
    ldab panel
    ldx #bank_valid
    jsr add_b
    tst 0,x
    beq choose_read
    bra choose_ready
choose_read
    jsr read_directory
    tst cache_lease_open
    beq choose_ready
    ldab panel
    ldx #bank_valid
    jsr add_b
    ldaa #1
    staa 0,x
choose_ready
    rts
save_marks
    ldaa cache_owner
    jsr mark_pointer
    ldab cache_owner
    ldx #counts
    jsr add_b
    ldaa 0,x
    staa mark_count
    clr mark_index
save_mark_loop
    ldaa mark_index
    cmpa mark_count
    bcc marks_done
    jsr entry_pointer
    ldaa 12,x
    staa mark_value
    ldab mark_index
    ldx marks_ptr
    jsr add_b
    ldaa mark_value
    staa 0,x
    inc mark_index
    bra save_mark_loop
restore_marks
    ldaa panel
    jsr mark_pointer
    clr mark_index
restore_mark_loop
    ldaa mark_index
    cmpa pcount
    bcc marks_done
    tab
    ldx marks_ptr
    jsr add_b
    ldaa 0,x
    staa mark_value
    ldaa mark_index
    jsr entry_pointer
    ldaa mark_value
    staa 12,x
    inc mark_index
    bra restore_mark_loop
marks_done
    rts
mark_pointer
    ldx #marks_left
    tsta
    beq mark_pointer_done
    ldx #marks_right
mark_pointer_done
    stx marks_ptr
    rts
store_cursor
    ldab panel
    ldx #cursors
    jsr add_b
    ldaa pcur
    staa 0,x
    rts
read_directory
    clr pcount
    clr had_overflow
    jsr page_flag_pointer
    ldaa 0,x
    staa paging_direction
    jsr page_pivot_pointer
    stx pivotptr
    ldx pathptr
    stx src
    ldx #search_path
    stx dst
    jsr copy_z
    ldx #wildcard
    stx src
    jsr copy_z
    ldx #find_state
    stx find_table
    ldx #dir_entry
    stx find_table+2
    ldx #search_path
    stx find_table+4
    ldx cacheptr
    ldab #ENTRY_SIZE
rd_clear_parent
    clr 0,x
    inx
    decb
    bne rd_clear_parent
    ldx cacheptr
    ldaa #' '
    ldab #11
rd_parent_pad
    staa 0,x
    inx
    decb
    bne rd_parent_pad
    ldx cacheptr
    ldaa #'.'
    staa 0,x
    staa 1,x
    ldaa #16
    staa 11,x
    inc pcount
    clra
    ldab #8
    ldx owner
    tst S_HIDDEN,x
    bne rd_first
    ldab #14
rd_first
    ldx #find_table
    int $42
rd_entry
    tsta
    bne rd_done
    ldaa dir_entry
    cmpa #'.'
    beq rd_next
    ldx #candidate
    stx dst
    ldx #dir_entry
    stx src
    ldab #13
    jsr copy_n
    ldx #candidate
    clr 12,x
    ldab #E_SIZE
    jsr add_b
    stx dst
    ldx #dir_entry+28
    stx src
    ldab #4
    jsr copy_n
    ldx #dir_entry+24
    stx src
    ldab #2
    jsr copy_n
    ldx #dir_entry+22
    stx src
    ldab #2
    jsr copy_n
    jsr catalog_insert
rd_next
    ldx #find_table
    int $43
    bra rd_entry
rd_done
    cmpa #11
    beq rd_ok
    tsta
    beq rd_ok
    staa directory_error
rd_ok
    ldab panel
    ldx #counts
    jsr add_b
    ldaa pcount
    staa 0,x
    ldab panel
    ldx #has_previous
    jsr add_b
    clr 0,x
    tst paging_direction
    beq rd_forward_flags
    ldaa #1
    staa 0,x
    ldaa paging_direction
    cmpa #2
    bne rd_forward_flags
    ldaa had_overflow
    staa 0,x
    ldab panel
    ldx #has_next
    jsr add_b
    ldaa #1
    staa 0,x
    bra rd_marks
rd_forward_flags
    ldab panel
    ldx #has_next
    jsr add_b
    ldaa had_overflow
    staa 0,x
rd_marks
    jsr restore_marks
    ldaa pcur
    cmpa pcount
    bcs rd_cursor
    ldaa pcount
    deca
    staa pcur
rd_cursor
    jsr store_cursor
    jmp query_free_space
entry_pointer
    ; 24 bytes per record = index * 8 + index * 16.
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    staa ptr+1
    stab ptr
    asla
    rolb
    adda ptr+1
    adcb ptr
    adda cacheptr+1
    adcb cacheptr
    staa ptr+1
    stab ptr
    ldx ptr
    rts

selected
    ldaa pcur
    cmpa pcount
    bcc selected_none
    jsr entry_pointer
    clc
    rts
selected_none
    sec
    rts
; Keep a sorted window of entry_capacity-1 smallest entries after a pivot, or
; greatest entries before it. The full directory is always enumerated.
; This works in ordinary RAM too, without a catalogue-size limit or E5 lease.
catalog_insert
    tst paging_direction
    beq insert_capacity
    ldx #candidate
    stx cmp_left
    ldx pivotptr
    stx cmp_right
    jsr compare_entries
    bcc insert_pivot_less
    ldaa paging_direction
    cmpa #2
    bne *+5
    jmp insert_done
    bra insert_capacity
insert_pivot_less
    ldaa paging_direction
    cmpa #3
    bne insert_pivot_strict
    tst cmp_result
    beq insert_capacity
    jmp insert_done
insert_pivot_strict
    cmpa #2
    beq *+5
    jmp insert_done
    ; A strict backwards window excludes the pivot itself.
    tst cmp_result
    bne *+5
    jmp insert_done
insert_capacity
    ldaa pcount
    cmpa entry_capacity
    bcs insert_find
    ldaa #1
    staa had_overflow
    ldaa paging_direction
    cmpa #2
    bne insert_forward_full
    ldaa #1
    jsr entry_pointer
    stx cmp_right
    ldx #candidate
    stx cmp_left
    jsr compare_entries
    bcs *+5
    jmp insert_done
    ldaa #1
    staa shift_index
insert_drop_first
    ldaa shift_index
    jsr entry_pointer
    stx dst
    ldaa shift_index
    inca
    cmpa pcount
    bcc insert_drop_done
    jsr entry_pointer
    stx src
    ldab #ENTRY_SIZE
    jsr copy_n
    inc shift_index
    bra insert_drop_first
insert_drop_done
    dec pcount
    bra insert_find
insert_forward_full
    ldaa pcount
    deca
    jsr entry_pointer
    stx cmp_right
    ldx #candidate
    stx cmp_left
    jsr compare_entries
    bcc *+5
    jmp insert_done
insert_find
    ldaa #1
    staa insert_index
    ldaa pcount
    staa insert_high
insert_find_loop
    ldaa insert_index
    cmpa insert_high
    bcc insert_position
    adda insert_high
    rora
    staa insert_mid
    jsr entry_pointer
    stx cmp_left
    ldx #candidate
    stx cmp_right
    jsr compare_entries
    bcs insert_lower_half
    ldaa insert_mid
    inca
    staa insert_index
    bra insert_find_loop
insert_lower_half
    ldaa insert_mid
    staa insert_high
    bra insert_find_loop

insert_position
    ldaa insert_index
    cmpa entry_capacity
    bcs insert_position_valid
    rts
insert_position_valid
    ldaa pcount
    cmpa entry_capacity
    bcs insert_grow
    deca
    bra insert_shift_start
insert_grow
    inc pcount
insert_shift_start
    staa shift_index
insert_shift
    ldaa shift_index
    cmpa insert_index
    beq insert_store
    jsr entry_pointer
    stx dst
    ldaa shift_index
    deca
    jsr entry_pointer
    stx src
    ldab #ENTRY_SIZE
    jsr copy_n
    dec shift_index
    bra insert_shift
insert_store
    ldaa insert_index
    jsr entry_pointer
    stx dst
    ldx #candidate
    stx src
    ldab #ENTRY_SIZE
    jsr copy_n
insert_done
    rts
page_flag_pointer
    ldx owner
    ldab #S_PAGEFLAGS
    jsr add_b
    ldab panel
    jmp add_b
page_pivot_pointer
    ldx owner
    ldab #S_PIVOTS
    jsr add_b
    tst panel
    beq page_pivot_done
    ldab #ENTRY_SIZE
    jsr add_b
page_pivot_done
    rts

compare_entries
    ldx cmp_right
    ldaa 11,x
    anda #16
    staa cmp_attr
    ldx cmp_left
    ldaa 11,x
    anda #16
    cmpa cmp_attr
    bne cmp_dirs
    ldx owner
    ldaa S_SORT,x
    cmpa #2
    beq cmp_size
    cmpa #3
    beq cmp_date
    cmpa #1
    bne cmp_name
    ldab #8
    ldaa #3
    jsr cmp_bytes
    tst cmp_result
    bne cmp_return
    bra cmp_name
cmp_size
    ldab #E_SIZE+3
    ldaa #4
    jsr cmp_reverse_bytes
    tst cmp_result
    bne cmp_return
    bra cmp_name
cmp_date
    ldab #E_DATE+1
    ldaa #2
    jsr cmp_reverse_bytes
    tst cmp_result
    bne cmp_return
    ldab #E_TIME+1
    ldaa #2
    jsr cmp_reverse_bytes
    tst cmp_result
    bne cmp_return
cmp_name
    clrb
    ldaa #11
    jsr cmp_bytes
cmp_return
    ldaa cmp_result
    cmpa #1
    beq cmp_greater
    clc
    rts
cmp_dirs
    ; A directory precedes an ordinary file.
    bhi cmp_less
cmp_greater
    ldaa #1
    staa cmp_result
    sec
    rts
cmp_less
    ldaa #$ff
    staa cmp_result
    clc
    rts
cmp_bytes
    staa cmp_count
    stab cmp_offset
    ldaa #1
    staa cmp_step
    bra cmp_loop
cmp_reverse_bytes
    staa cmp_count
    stab cmp_offset
    ldaa #$ff
    staa cmp_step
cmp_loop
    ldx cmp_right
    ldab cmp_offset
    jsr add_b
    ldaa 0,x
    staa cmp_char
    ldx cmp_left
    ldab cmp_offset
    jsr add_b
    ldaa 0,x
    cmpa cmp_char
    bhi cmp_result_greater
    bcs cmp_result_less
    ldaa cmp_offset
    adda cmp_step
    staa cmp_offset
    dec cmp_count
    bne cmp_loop
    clr cmp_result
    rts
cmp_result_greater
    ldaa #1
    staa cmp_result
    rts
cmp_result_less
    ldaa #$ff
    staa cmp_result
    rts
selected_path
    jsr selected
    stx name_record
    ldx pathptr
    stx src
    ldx #source_path
    stx dst
    jsr copy_z
    ldx name_record
    jmp record_name
record_name
    stx name_record
    clr name_index
name_base
    ldx name_record
    ldab name_index
    jsr add_b
    ldaa 0,x
    cmpa #' '
    beq name_ext
    jsr append_a
    inc name_index
    ldaa name_index
    cmpa #8
    bcs name_base
name_ext
    ldx name_record
    ldaa 8,x
    cmpa #' '
    beq name_finish
    ldaa #'.'
    jsr append_a
    ldaa #8
    staa name_index
name_extension
    ldx name_record
    ldab name_index
    jsr add_b
    ldaa 0,x
    cmpa #' '
    beq name_finish
    jsr append_a
    inc name_index
    ldaa name_index
    cmpa #11
    bcs name_extension
name_finish
    ldx dst
    clr 0,x
    rts
append_a
    ldx dst
    staa 0,x
    inx
    stx dst
    rts
set_working_directory
    ldx pathptr
    ldaa 0,x
    suba #'A'
    int $44
    tsta
    bne work_done
    ldx pathptr
    int $46
work_done
    rts
    include NCUTIL.INC

    include NCOCTETS.INC
