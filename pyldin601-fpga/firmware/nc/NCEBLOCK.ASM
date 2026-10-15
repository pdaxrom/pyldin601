; NCEBLOCK: Text selection, clipboard and block editing.
    .define NC_EDITOR
    include NCABI.INC
    include NCBOX.INC
    public block_cach_8b13
    public block_canc_33d4
    public block_clos_a41c
    public block_copy_b900
    public block_dispatch
    public block_finish
    public block_mark_dc41
    public block_put
    public block_row
    public v_block_st_100
    public v_block_st_101
    public v_block_st_102
    public v_block_st_103
    public v_block_st_104
    public v_block_st_105
    public v_block_st_106
    public v_block_st_107
    public v_block_st_108
    public v_block_st_24
    public v_block_st_28
    public v_block_st_29
    public v_block_st_30
    public v_block_st_31
    public v_block_st_32
    public v_block_st_33
    public v_block_st_34
    public v_block_st_35
    public v_block_st_36
    public v_block_st_72
    public v_block_st_73
    public v_block_st_74
    public v_block_st_75
    public v_block_st_90
    public v_block_st_91
    public v_block_st_96
    extern add_b
    extern add_byte
    extern add_tail
    extern block_dirty
    extern block_get
    extern block_left
    extern body_rows
    extern change_at
    extern change_bytes
    extern change_delete
    extern change_group
    extern change_new_3955
    extern change_prepare
    extern columns
    extern const32
    extern copy_bytes
    extern copy_n
    extern copy_z
    extern desired_valid
    extern doc_size
    extern dst
    extern e_column
    extern e_cursor
    extern editor_error
    extern editor_nat_5e73
    extern editor_poll
    extern editor_res_c671
    extern editor_stat
    extern end_pointer
    extern eol_bytes
    extern eol_length
    extern filename
    extern find_line_start
    extern group_open
    extern hex_digit
    extern history_cursor
    extern history_mode
    extern history_target
    extern horizontal
    extern ink
    extern io_table
    extern key_ignored
    extern last_key
    extern line_pointer
    extern line_valid
    extern move_docum_6b40
    extern nav_start
    extern new_line
    extern open_table
    extern output_char
    extern owner
    extern paint_line
    extern pending_record
    extern poll_count
    extern put
    extern q
    extern q_add
    extern q_cmp
    extern q_load
    extern q_store
    extern q_sub
    extern q_test
    extern rebuild_cursor
    extern render_row
    extern save_attempt
    extern save_buffer
    extern save_done
    extern save_handle
    extern save_meter_802e
    extern save_next
    extern save_open
    extern save_progress
    extern save_strea_2340
    extern save_tail
    extern save_target
    extern save_temp
    extern screen_pointer
    extern screen_top
    extern split_bytes
    extern src
    extern stream_block
    extern stream_init
    extern stream_left
    extern stream_ptr
    extern ui_x
    extern v_block_le_1
    extern v_change_b_1
    extern v_eol_byte_1
    extern v_horizont_1
    extern v_horizont_2
    extern v_horizont_3
    extern v_io_table_2
    extern v_open_tab_2
    extern v_pending__12
    extern v_pending__16
    extern v_pending__20
    extern v_pending__24
    extern v_pending__28
    extern v_pending__29
    extern v_pending__4
    extern v_pending__8
    extern v_q_1
    extern v_q_2
    extern v_q_3
    extern v_stream_l_1
    extern where
    extern window_line
    extern window_open
    extern window_title
    extern work_open

; Linear selection and disk clipboard. Only visible row intervals live in RAM.
; block_state layout (BE32 unless noted):
; 0 anchor,4 anchor column,8 start,12 end,16 start column,20 end column;
; 24 active,25 F3 marking,26 navigation,27 repaint,28 modal underlay;
; 29/30 new first/end,31/32 old first/end,33/34 new/old ink,
; 35 header selection,36 caret body ink,37 Shift,38 row,39 spare;
; 40/44 spare;48 snapshot ADD offset,52 source position,56 remaining,
; 60 total,64 chunk u16,66 buffer pointer,68 append left u16,70 take u16,
; 72 scratch,76 insertion ADD offset,80 insertion length,84 prior cursor;
; 88 small insertion length,89 transfer error,90 mono text,91 marked row;
; 93 transfer progress;96 save total,100 save source,104 transfer kind
; (0 document output,1 clipboard output,2 clipboard reader/block staging);
; 105 header valid,106 header modified,107 header overwrite,108 path length.
block_dispatch
    ldaa last_key
    cmpa #3
    bne *+5
    jmp block_copy_key
    cmpa #$18
    bne *+5
    jmp block_cut_key
    cmpa #$16
    bne *+5
    jmp block_paste_key
    cmpa #1
    bne *+5
    jmp block_all_key
    cmpa #$cb
    bne *+5
    jmp block_mark_key
    cmpa #27
    bne block_not_escape
    tst block_state+24
    beq block_not_escape
    jsr selection_clear
    jmp key_ignored
block_not_escape
    cmpa #$c1
    bcs block_not_navigation
    cmpa #$c9
    bcc *+5
    jmp block_navigation
    cmpa #$f5
    bne *+5
    jmp block_navigation
    cmpa #$f6
    bne *+5
    jmp block_navigation
block_not_navigation
    cmpa #$1a
    beq block_clear_key
    cmpa #$19
    beq block_clear_key
    cmpa #$cf
    beq block_clear_key
    cmpa #$db
    beq block_clear_key
    tst block_state+24
    beq block_native_key
    jsr block_normalize
    ldx #block_state+8
    jsr q_load
    ldx #block_state+12
    jsr q_cmp
    beq block_empty_edit
    ldaa last_key
    cmpa #$f9
    bne *+5
    jmp block_erase_key
    cmpa #127
    bne *+5
    jmp block_erase_key
    cmpa #8
    bne *+5
    jmp block_erase_key
    cmpa #$c0
    bne *+5
    jmp block_enter_key
    cmpa #13
    bne *+5
    jmp block_enter_key
    cmpa #$ed
    bne *+5
    jmp block_tab_key
    cmpa #32
    bcs block_native_key
    cmpa #$c0
    bcc *+5
    jmp block_type_key
    bra block_native_key
block_empty_edit
    ldaa last_key
    cmpa #127
    beq block_clear_key
    cmpa #8
    beq block_clear_key
    cmpa #$f9
    beq block_clear_key
    cmpa #32
    bcs block_native_key
    cmpa #$c0
    bcs block_clear_key
    cmpa #$c0
    beq block_clear_key
    cmpa #$ed
    bne block_native_key
block_clear_key
    jsr selection_clear
block_native_key
    jmp editor_nat_5e73
block_navigation
    clr block_state+37
    ; Read the current FPGA keyboard state only when its v2 raw interface and
    ; ordinary-RAM JMP gateway are present. Never call or modify private E7.
    ldaa $e6b4
    cmpa #2
    bne block_nav_mode
    ldaa $efce
    cmpa #1
    bcs block_nav_mode
    cmpa #$be
    bcc block_nav_mode
    cmpa #$bd
    bne block_nav_pointer
    ldaa $efcf
    cmpa #$c0
    bcc block_nav_mode
block_nav_pointer
    ldx $efce
    ldaa 0,x
    cmpa #$7e
    bne block_nav_mode
    ldaa 5,x
    anda #3
    staa block_state+37
    beq block_nav_mode
    ; Native Shift+arrows become Home/End/PgUp/PgDn. Recover the physical
    ; Set-2 arrow while Shift is held; F3 is the BIOS-only marking fallback.
    ldaa 10,x
    ldx #block_nav_table
    ldab #8
block_nav_scan
    cmpa 0,x
    beq block_nav_found
    inx
    inx
    decb
    bne block_nav_scan
    bra block_nav_mode
block_nav_found
    ldaa last_key
    cmpa #$f5
    beq block_nav_mode
    cmpa #$f6
    beq block_nav_mode
    ldaa 1,x
    staa last_key
block_nav_mode
    ldaa block_state+25
    oraa block_state+37
    beq block_nav_clear
    ldaa #1
    staa block_state+26
    tst block_state+24
    bne block_native_key
    jsr block_anchor
    bra block_native_key
block_nav_clear
    jsr selection_clear
    bra block_native_key
block_anchor
    ldx #e_cursor
    jsr q_load
    ldx #block_state
    jsr q_store
    ldx #e_column
    jsr q_load
    ldx #block_state+4
    jsr q_store
    ldaa #1
    staa block_state+24
    staa block_state+27
    rts
selection_clear
    tst block_state+24
    beq *+5
    inc block_state+27
    clr block_state+24
    clr block_state+25
    rts
block_mark_key
    tst block_state+25
    beq block_mark_begin
    clr block_state+25
    jmp key_ignored
block_mark_begin
    jsr block_anchor
    inc block_state+25
    jmp key_ignored
block_all_key
    jsr block_anchor
    ldx #block_state
    ldab #8
block_all_zero
    clr 0,x
    inx
    decb
    bne block_all_zero
    clr block_state+25
    inc block_state+26
    jmp move_docum_6b40
block_normalize
    ldx #block_state
    jsr q_load
    ldx #e_cursor
    jsr q_cmp
    bhi block_reverse
    ldx #block_state
    jsr q_load
    ldx #block_state+8
    jsr q_store
    ldx #e_cursor
    jsr q_load
    ldx #block_state+12
    jsr q_store
    ldx #block_state+4
    jsr q_load
    ldx #block_state+16
    jsr q_store
    ldx #e_column
    jsr q_load
    ldx #block_state+20
    jsr q_store
    rts
block_reverse
    ldx #e_cursor
    jsr q_load
    ldx #block_state+8
    jsr q_store
    ldx #block_state
    jsr q_load
    ldx #block_state+12
    jsr q_store
    ldx #e_column
    jsr q_load
    ldx #block_state+16
    jsr q_store
    ldx #block_state+4
    jsr q_load
    ldx #block_state+20
    jsr q_store
    rts
; Map the normalized byte range to one contiguous visible interval per row.
block_row
    clr block_state+29
    clr block_state+30
    tst block_state+24
    beq block_row_done
    ldab render_row
    ldx #line_valid
    jsr add_b
    tst 0,x
    beq block_row_done
    ldaa render_row
    jsr line_pointer
    jsr q_load
    ldx #block_state+12
    jsr q_cmp
    bcc block_row_done
    ldaa render_row
    jsr end_pointer
    jsr q_load
    ldx #block_state+8
    jsr q_cmp
    bcs block_row_done
    ldaa render_row
    jsr line_pointer
    jsr q_load
    ldx #block_state+8
    jsr q_cmp
    bcc block_row_end
    ldx #block_state+16
    jsr q_load
    jsr block_visible_column
    staa block_state+29
block_row_end
    ldaa columns
    staa block_state+30
    ldaa render_row
    jsr end_pointer
    jsr q_load
    ldx #block_state+12
    jsr q_cmp
    bcs block_row_done
    ldx #block_state+20
    jsr q_load
    jsr block_visible_column
    staa block_state+30
block_row_done
    rts
block_visible_column
    ldx #horizontal
    jsr q_sub
    bcs block_column_zero
    ldaa q
    oraa v_q_1
    oraa v_q_2
    bne block_column_full
    ldaa v_q_3
    cmpa columns
    bcs block_row_done
block_column_full
    ldaa columns
    rts
block_column_zero
    clra
    rts
block_mark_pointer
    ldab render_row
    aslb
    ldx #block_marks
    jmp add_b
; A = ink for the cached cell at (render_row, ui_x), used by modal restore
; and by the graphics caret. A selected caret reverses back to body colours.
block_cached_ink
    jsr block_mark_pointer
    ldaa ui_x
    cmpa 0,x
    bcs block_normal_ink
    cmpa 1,x
    bcc block_normal_ink
    ldaa #$03
    rts
block_normal_ink
    ldaa #$71
    rts
; Native monochrome text has no per-cell attributes. Show selection endpoints
; with brackets without changing the document or its cached original glyphs.
block_put
    staa output_char
    tst block_state+90
    beq block_put_original
block_put_mono
    ldaa ink
    cmpa #$03
    bne block_put_original
    jsr block_mark_pointer
    ldaa 1,x
    deca
    cmpa 0,x
    bne block_put_bracket
    ldaa #'*'
    jmp put
block_put_bracket
    ldaa ui_x
    cmpa 0,x
    bne block_put_right
    ldaa #'['
    jmp put
block_put_right
    inca
    cmpa 1,x
    bne block_put_original
    ldaa #']'
    jmp put
block_put_original
    ldaa output_char
    jmp put

block_finish
    ldaa block_state+26
    oraa block_state+27
    beq block_finish_done
    tst block_state+24
    beq block_repaint
    jsr block_normalize
block_repaint
    clr block_state+38
block_repaint_row
    ldaa block_state+38
    staa render_row
    jsr screen_pointer
    stx src
    ldx #new_line
    stx dst
    ldab columns
    jsr copy_n
    jsr paint_line
    inc block_state+38
    ldaa block_state+38
    cmpa body_rows
    bcs block_repaint_row
    clr block_state+26
    clr block_state+27
block_finish_done
    clra
    rts
; Copy uses the existing bounded Save stream, publishing a new .CLP only
; after close. The supervisor owns its pathname across F4 unload/reload.
block_clip_pointer
    ldx owner
    ldab #255
    jsr add_b
    ldab #146
    jmp add_b
block_copy_key
    jsr block_copy
    jmp editor_res_c671
block_copy
    jsr block_close_pending
    tsta
    beq *+5
    jmp block_clip_return
    tst block_state+24
    beq block_finish_done
    jsr block_normalize
    ldx #block_state+12
    jsr q_load
    ldx #block_state+8
    jsr q_sub
    jsr q_test
    beq block_finish_done
    ldx #block_state+96
    jsr q_store
    ldx #block_state+8
    jsr q_load
    ldx #block_state+100
    jsr q_store
    clr group_open
    clr block_state+25
    ldx owner
    ldab #255
    jsr add_b
    ldab #52
    jsr add_b
    tst 0,x
    bne block_clip_directory
    ldx #filename
block_clip_directory
    stx src
    ldx #save_temp
    stx dst
    jsr copy_z
    ldx #save_temp
    stx save_tail
block_clip_tail
    ldaa 0,x
    beq block_clip_name
    inx
    cmpa #'\'
    bne block_clip_tail
    stx save_tail
    bra block_clip_tail
block_clip_name
    ldx save_tail
    stx dst
    ldx #block_clip_name_text
    stx src
    jsr copy_z
    clr save_attempt
block_clip_unique
    ldx save_tail
    ldaa save_attempt
    lsra
    lsra
    lsra
    lsra
    jsr hex_digit
    staa 6,x
    ldaa save_attempt
    jsr hex_digit
    staa 7,x
    ldx #save_temp
    jsr editor_stat
    cmpa #11
    beq block_clip_create
    tsta
    beq *+5
    jmp block_clip_return
    inc save_attempt
    bne block_clip_unique
    ldaa #12
    rts
block_clip_create
    ldx #save_temp
    stx open_table
    ldx #0
    stx v_open_tab_2
    clra
    ldx #open_table
    int $4b
    tsta
    beq *+5
    jmp block_clip_return
    stab save_handle
    ldaa #1
    staa save_open
    staa block_state+104
    staa block_state+28
    ldx #block_copy_title
    jsr window_open
    ldx #filename
    ldaa #8
    jsr window_line
    jmp save_strea_2340
; Retry a pending native close before reusing the shared transfer handle.
; Kind 2 is a clipboard reader, whose source must never be deleted.
block_close_pending
    tst save_open
    beq block_clip_ok
    ldaa save_handle
    int $4e
    tsta
    beq *+5
    jmp block_clip_return
    clr save_open
    ldaa block_state+104
    cmpa #2
    beq block_clip_ok
    ldx #save_temp
    int $4f
    clra
    rts

block_copy_commit
    jsr block_clip_pointer
    stx src
    ldx #save_target
    stx dst
    jsr copy_z
    jsr block_clip_pointer
    stx dst
    ldx #save_temp
    stx src
    jsr copy_z
    tst save_target
    beq block_clip_ok
    ldx #save_target
    int $4f
block_clip_ok
    clra
block_clip_return
    rts
block_cut_key
    jsr block_copy
    tsta
    beq *+5
    jmp block_clip_error
    tst block_state+24
    bne *+5
    jmp block_native_ignored
    ldx #block_state+8
    jsr q_load
    ldx #block_state+12
    jsr q_cmp
    bne *+5
    jmp block_native_ignored
    clr block_state+80
    clr block_state+81
    clr block_state+82
    clr block_state+83
    bra block_replace_key
block_erase_key
    clr block_state+80
    clr block_state+81
    clr block_state+82
    clr block_state+83
    bra block_replace_key
block_enter_key
    ldaa eol_bytes
    staa change_bytes
    ldaa v_eol_byte_1
    staa v_change_b_1
    ldaa eol_length
    bra block_small_key
block_tab_key
    ldaa #9
block_type_key
    staa change_bytes
    ldaa #1
block_small_key
    staa block_state+88
    jsr work_open
    tsta
    beq *+5
    jmp block_clip_error
    ldx #add_tail
    jsr q_load
    ldx #block_state+76
    jsr q_store
    clr block_state+80
    clr block_state+81
    clr block_state+82
    ldaa block_state+88
    staa block_state+83
    ldaa change_bytes
    jsr add_byte
    tsta
    beq *+5
    jmp block_clip_error
    ldaa block_state+88
    cmpa #2
    bne block_replace_key
    ldaa v_change_b_1
    jsr add_byte
    tsta
    beq *+5
    jmp block_clip_error
block_replace_key
    jsr block_replace
    tsta
    beq *+5
    jmp block_clip_error
    jsr selection_clear
    clr desired_valid
    clr horizontal
    clr v_horizont_1
    clr v_horizont_2
    clr v_horizont_3
    ldx #e_cursor
    jsr q_load
    ldx #nav_start
    jsr q_store
    jsr find_line_start
    tsta
    beq *+5
    jmp block_clip_error
    ldx #nav_start
    jsr q_load
    ldx #screen_top
    jsr q_store
    jmp rebuild_cursor
block_native_ignored
    jmp key_ignored
block_clip_error
    jmp editor_error
block_paste_key
    jsr block_close_pending
    tsta
    beq *+5
    jmp block_clip_error
    jsr block_clip_pointer
    tst 0,x
    bne *+5
    jmp block_native_ignored
    stx open_table
    ldx #0
    stx v_open_tab_2
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    beq *+5
    jmp block_clip_error
    stab save_handle
    inc save_open
    ldaa #2
    staa block_state+104
    tba
    ldx #block_state+80
    int $51
    tsta
    bne block_paste_close
    jsr work_open
    tsta
    bne block_paste_close
    ldx #add_tail
    jsr q_load
    ldx #block_state+76
    jsr q_store
    ldx #block_state+80
    jsr q_load
    ldx #block_state+56
    jsr q_store
    ldx #block_paste_title
    jsr block_meter
block_paste_read
    ldx #block_state+56
    jsr q_load
    jsr q_test
    beq block_paste_close
    jsr block_take
    ldx block_state+64
    stx v_io_table_2
    ldx #save_buffer
    stx io_table
    ldaa save_handle
    ldx #io_table
    int $4c
    tsta
    bne block_paste_close
    cpx block_state+64
    beq *+5
    jmp block_paste_short
    jsr block_append
    tsta
    bne block_paste_close
    jsr block_transferred
    tsta
    beq block_paste_read
block_paste_close
    staa block_state+89
    ldaa save_handle
    int $4e
    tsta
    beq *+5
    jmp block_clip_error
    clr save_open
    ldaa block_state+89
    tsta
    beq *+5
    jmp block_clip_error
    jmp block_replace_key
block_paste_short
    ldaa #3
    bra block_paste_close
; Arbitrary-length replacement is one normal history record. Payloads are
; fully staged before history_resume starts mutating the piece directory.
block_replace
    clr group_open
    ldx #e_cursor
    jsr q_load
    ldx #block_state+84
    jsr q_store
    tst block_state+24
    bne block_replace_selected
    ldx #e_cursor
    jsr q_load
    ldx #block_state+8
    jsr q_store
    ldx #e_cursor
    jsr q_load
    ldx #block_state+12
    jsr q_store
block_replace_selected
    jsr work_open
    tsta
    beq *+5
    jmp block_replace_return
    ldx #block_state+12
    jsr q_load
    ldx #block_state+8
    jsr q_sub
    ldx #block_state+60
    jsr q_store
    ldx #doc_size
    jsr q_load
    ldx #block_state+60
    jsr q_sub
    ldx #block_state+80
    jsr q_add
    bcc *+5
    jmp block_full
    ldx #block_state+8
    jsr q_load
    ldx #block_state+52
    jsr q_store
    ldx #block_state+60
    jsr q_load
    ldx #block_state+56
    jsr q_store
    jsr block_snapshot
    tsta
    beq *+5
    jmp block_replace_return
    clr change_delete
    ldx #block_state+12
    jsr q_load
    ldx #change_at
    jsr q_store
    jsr change_prepare
    tsta
    beq *+5
    jmp block_replace_return
    ldx #block_state+8
    jsr q_load
    ldx #change_at
    jsr q_store
    ldx #block_state+8
    jsr q_load
    ldx #pending_record
    jsr q_store
    ldx #block_state+48
    jsr q_load
    ldx #v_pending__4
    jsr q_store
    ldx #block_state+60
    jsr q_load
    ldx #v_pending__8
    jsr q_store
    ldx #block_state+76
    jsr q_load
    ldx #v_pending__12
    jsr q_store
    ldx #block_state+80
    jsr q_load
    ldx #v_pending__16
    jsr q_store
    ldx #block_state+84
    jsr q_load
    ldx #v_pending__20
    jsr q_store
    ldx #block_state+8
    jsr q_load
    ldx #block_state+80
    jsr q_add
    ldx #v_pending__24
    jsr q_store
    clr change_group
    clr v_pending__28
    ldaa #1
    staa v_pending__29
    clr history_mode
    ldx #history_cursor
    jsr q_load
    ldx #const32
    jsr q_add
    ldx #history_target
    jsr q_store
    jmp change_new_3955
block_full
    ldaa #12
block_replace_return
    rts
; Snapshot document bytes to ADD, one bounded bounce at a time. Reopen the
; logical stream after appending: ADD/cache eviction can replace its last slot.
block_snapshot
    ldx #add_tail
    jsr q_load
    ldx #block_state+48
    jsr q_store
    ldx #block_edit_title
    jsr block_meter
block_snapshot_more
    ldx #block_state+56
    jsr q_load
    jsr q_test
    beq block_replace_return
    ldx #block_state+52
    jsr q_load
    ldx #where
    jsr q_store
    jsr stream_init
    bcs block_snapshot_end
    jsr stream_block
    bcs block_snapshot_end
    ldx #block_state+56
    jsr q_load
    jsr block_take
    ldaa stream_left
    cmpa block_state+64
    bne block_snapshot_compare
    ldaa v_stream_l_1
    cmpa block_state+65
block_snapshot_compare
    bcc block_snapshot_copy
    ldx stream_left
    stx block_state+64
block_snapshot_copy
    ldx stream_ptr
    stx src
    ldx #save_buffer
    stx dst
    ldx block_state+64
    stx split_bytes
    jsr copy_bytes
    jsr block_append
    tsta
    beq *+5
    jmp block_replace_return
    jsr block_transferred
    tsta
    beq block_snapshot_more
    rts
block_snapshot_end
    tsta
    beq *+5
    jmp block_replace_return
    ldaa #3
    rts
; chunk=min(remaining,512). Buffer append handles an unaligned ADD tail.
block_take
    ldx #512
    stx block_state+64
    ldaa q
    oraa v_q_1
    beq *+5
    jmp block_replace_return
    ldaa v_q_2
    cmpa #2
    bcs *+5
    jmp block_replace_return
    ldx v_q_2
    stx block_state+64
    rts
block_append
    ldx #save_buffer
    stx block_state+66
    ldx block_state+64
    stx block_state+68
block_append_more
    ldx #add_tail
    jsr q_load
    ldaa #2
    jsr block_get
    tsta
    beq *+5
    jmp block_replace_return
    stx dst
    ldx block_state+66
    stx src
    ldx block_state+68
    stx block_state+70
    ldaa block_left
    cmpa block_state+70
    bne block_append_compare
    ldaa v_block_le_1
    cmpa block_state+71
block_append_compare
    bcc block_append_copy
    ldx block_left
    stx block_state+70
block_append_copy
    ldx block_state+70
    stx split_bytes
    jsr copy_bytes
    ldx src
    stx block_state+66
    jsr block_dirty
    clr block_state+72
    clr block_state+73
    ldx block_state+70
    stx block_state+74
    ldx #add_tail
    jsr q_load
    ldx #block_state+72
    jsr q_add
    ldx #add_tail
    jsr q_store
    ldaa block_state+69
    suba block_state+71
    staa block_state+69
    ldaa block_state+68
    sbca block_state+70
    staa block_state+68
    oraa block_state+69
    bne block_append_more
    clra
    rts
block_transferred
    clr block_state+72
    clr block_state+73
    ldx block_state+64
    stx block_state+74
    ldx #block_state+56
    jsr q_load
    ldx #block_state+72
    jsr q_sub
    ldx #block_state+56
    jsr q_store
    ldx #block_state+52
    jsr q_load
    ldx #block_state+72
    jsr q_add
    ldx #block_state+52
    jsr q_store
    tst block_state+93
    beq block_transfer_poll
    ldx #block_state+96
    jsr q_load
    ldx #block_state+56
    jsr q_sub
    ldx #save_done
    jsr q_store
    ldx #save_next
    jsr q_cmp
    bcs block_transfer_poll
    jsr save_progress
block_transfer_poll
    ldaa #$ff
    staa poll_count
    jmp editor_poll
block_meter
    stx window_title
    clr block_state+93
    ldx #block_state+56
    jsr q_load
    ldaa q
    oraa v_q_1
    bne block_meter_open
    ldaa v_q_2
    cmpa #2
    bcs block_cancel_done
block_meter_open
    ldx #block_state+96
    jsr q_store
    ldaa #1
    staa block_state+28
    staa block_state+93
    ldaa #2
    staa block_state+104
    ldx window_title
    jsr window_open
    ldx #filename
    ldaa #8
    jsr window_line
    jmp save_meter_802e
; A held cancellation key must not also clear the block and then exit the
; editor. Drain only Esc/Ctrl+C repeats until native BIOS observes release;
; leave a different queued key available for the normal input loop.
block_cancel_release
    int $10
    cmpa #27
    beq block_cancel_consume
    cmpa #3
    beq block_cancel_consume
    cmpa #$ff
    bne block_cancel_done
    ldaa $ed31
    cmpa #27
    beq block_cancel_release
    cmpa #3
    beq block_cancel_release
block_cancel_done
    clra
    rts
block_cancel_consume
    int $11
    bra block_cancel_release

block_nav_table db $6b,$c1,$74,$c2,$75,$c4,$72,$c3,$6c,$c5,$69,$c6,$7d,$c8,$7a,$c7
block_clip_name_text db 'NCE00000.CLP',0
block_copy_title db 'Copy block',0

block_paste_title db 'Paste block',0
block_edit_title db 'Edit block',0
    section
block_state ds 112
block_marks ds 48
    ends
block_cach_8b13 equ block_cached_ink
block_canc_33d4 equ block_cancel_release
block_clos_a41c equ block_close_pending
block_copy_b900 equ block_copy_commit
block_mark_dc41 equ block_mark_pointer
v_block_st_100 equ block_state+100
v_block_st_101 equ block_state+101
v_block_st_102 equ block_state+102
v_block_st_103 equ block_state+103
v_block_st_104 equ block_state+104
v_block_st_105 equ block_state+105
v_block_st_106 equ block_state+106
v_block_st_107 equ block_state+107
v_block_st_108 equ block_state+108
v_block_st_24 equ block_state+24
v_block_st_28 equ block_state+28
v_block_st_29 equ block_state+29
v_block_st_30 equ block_state+30
v_block_st_31 equ block_state+31
v_block_st_32 equ block_state+32
v_block_st_33 equ block_state+33
v_block_st_34 equ block_state+34
v_block_st_35 equ block_state+35
v_block_st_36 equ block_state+36
v_block_st_72 equ block_state+72
v_block_st_73 equ block_state+73
v_block_st_74 equ block_state+74
v_block_st_75 equ block_state+75
v_block_st_90 equ block_state+90
v_block_st_91 equ block_state+91
v_block_st_96 equ block_state+96
    end
