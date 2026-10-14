; Keep the edited filename selected, including after size/date sorting moves it
; outside the old catalogue window. Direction 3 is an inclusive forward pivot.
editor_state_name
    ldx owner
    ldab #255
    jsr add_b
    ldab #132
    jmp add_b
restore_edited
    jsr editor_state_name
    tst 0,x
    bne *+5
    jmp edited_return
    stx edited_name_ptr
    ldaa active
    jsr choose_panel
    ldaa pcur
    staa previous_cursor
    ldaa ptop
    staa previous_top
    clr edited_retry
edited_scan
    clr pcur
edited_entry
    ldaa pcur
    cmpa pcount
    bcc edited_not_cached
    jsr entry_pointer
    stx cmp_left
    ldx edited_name_ptr
    stx cmp_right
    clrb
    ldaa #11
    jsr cmp_bytes
    tst cmp_result
    bne *+5
    jmp edited_found
    inc pcur
    bra edited_entry
edited_not_cached
    tst edited_retry
    beq *+5
    jmp edited_restore_cursor
    inc edited_retry
    ldx owner
    ldab #S_COMMAND
    jsr add_b
    jsr stat_path
    tsta
    beq *+5
    jmp edited_restore_cursor
    ldx #stat_entry
    stx src
    ldx #candidate
    stx dst
    ldab #13
    jsr copy_n
    clr candidate+12
    ldx #stat_entry+28
    stx src
    ldx #candidate+E_SIZE
    stx dst
    ldab #4
    jsr copy_n
    ldx #stat_entry+24
    stx src
    ldx #candidate+E_DATE
    stx dst
    ldab #2
    jsr copy_n
    ldx #stat_entry+22
    stx src
    ldx #candidate+E_TIME
    stx dst
    ldab #2
    jsr copy_n
    jsr page_pivot_pointer
    stx dst
    ldx #candidate
    stx src
    ldab #ENTRY_SIZE
    jsr copy_n
    jsr page_flag_pointer
    ldaa #3
    staa 0,x
    clr cache_valid
    ldaa panel
    ldab panel
    ldx #bank_valid
    jsr add_b
    clr 0,x
    jsr choose_panel
    ldaa #1
    staa ptop
    jmp edited_scan
edited_found
    ldaa pcur
    cmpa ptop
    bcs edited_top
    ldaa ptop
    adda ui_rows
    cmpa pcur
    bhi edited_store
    ldaa pcur
    suba ui_rows
    inca
edited_top
    staa ptop
edited_store
    jsr store_cursor
    ldx #tops
    ldab panel
    jsr add_b
    ldaa ptop
    staa 0,x
    bra edited_clear
edited_restore_cursor
    ldaa previous_cursor
    staa pcur
    ldaa previous_top
    staa ptop
edited_clear
    ldx edited_name_ptr
    clr 0,x
edited_return
    rts
