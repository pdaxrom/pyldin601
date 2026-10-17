; NCEFILE: Disk cache, piece table, undo journal and saving.
    .define NC_EDITOR
    include NCABI.INC
    include NCBOX.INC
    public add_byte
    public append_block
    public block_dirty
    public block_get
    public change_new_3955
    public change_prepare
    public doc_byte
    public editor_cac_de58
    public editor_change
    public editor_close
    public editor_his_2705
    public editor_open
    public editor_save
    public editor_save_as
    public editor_stat
    public hex_digit
    public history_redo
    public history_resume
    public history_undo
    public pending_record
    public q_add
    public q_cmp
    public q_dec
    public q_inc
    public q_load
    public q_small
    public q_store
    public q_sub
    public q_test
    public reopen_base
    public save_meter_802e
    public save_progress
    public save_strea_2340
    public stream_block
    public stream_init
    public stream_next
    public v_pending__12
    public v_pending__16
    public v_pending__20
    public v_pending__24
    public v_pending__28
    public v_pending__4
    public v_pending__8
    public work_open
    extern rec_api
    extern v_find_tab_2
    extern v_find_tab_4
    extern v_file_siz_12
    extern v_open_tab_2
    extern mouse_cancel
    extern mouse_close
    extern add_b
    extern add_tail
    extern append_char
    extern apply_cursor
    extern apply_error
    extern apply_inse_8b0f
    extern apply_inse_9b8b
    extern apply_left
    extern apply_phase
    extern apply_pos
    extern base_closed
    extern base_is_backup
    extern base_path
    extern block_clos_a41c
    extern block_copy_b900
    extern block_left
    extern block_offset
    extern body_rows
    extern build_full
    extern build_line
    extern cache_buf
    extern cache_count
    extern cache_data
    extern cache_hand
    extern cache_lease
    extern cache_leased
    extern cache_tags
    section
cache_plain_count ds 1
cache_extra ds 2
    ends
    extern cancel_sav_fb1e
    extern change_add
    extern change_at
    extern change_bytes
    extern change_delete
    extern change_group
    extern change_index
    extern change_lin_2598
    extern colour
    extern column_fro_c274
    extern columns
    extern confirm
    extern const32
    extern copy_bytes
    extern copy_n
    extern copy_z
    extern cursor_row
    extern decimal_number
    extern dialog
    extern dir_entry
    extern disk_buffer
    extern divide_number
    extern doc_size
    extern dst
    extern e_cursor
    extern edit_delta
    extern editor_error
    extern editor_finish
    extern end_pointer
    extern ensure_hor_027b
    extern entry_base
    extern entry_ptr
    extern error_text
    extern field
    extern file_positions
    extern file_sizes
    extern filename
    extern find_state
    extern find_table
    extern full_table
    extern group_open
    extern handles
    extern history_count
    extern history_cursor
    extern history_mode
    extern history_po_08d6
    extern history_target
    extern horizontal_beef
    extern index_end
    extern input
    extern insert_len
    extern insert_off
    extern insert_ptr
    extern io_count
    extern io_file
    extern io_position
    extern io_table
    extern latest_backup
    extern leaf_id
    extern leaf_ptr
    extern leaf_slot
    extern leaf_start
    extern lease_group
    extern left_pointer
    extern line_pointer
    extern line_valid
    extern metadata_row
    extern mode
    extern modified
    extern new_handle
    extern next_leaf
    extern number
    extern number_divisor
    extern number_text
    extern old_group
    extern old_page
    extern open_table
    extern opened
    extern original_attr
    extern overwrite_text
    extern owner
    extern paint_line
    extern path_char
    extern path_tail
    extern piece_in
    extern piece_index
    extern position
    extern prefix_ptr
    extern put
    extern q
    extern rebuild_cursor
    extern remainder
    extern remaining
    extern remove_left
    extern remove_len
    extern remove_take
    extern rename_call
    extern rename_table
    extern render_row
    extern save_as_title
    extern save_attempt
    extern save_attributes
    extern save_backu_94f9
    extern save_backup
    extern save_bar_index
    extern save_bar_width
    extern save_buffer
    extern save_cells
    extern save_chunk
    extern save_done
    extern save_error
    extern save_exists
    extern save_handle
    extern save_length
    extern save_name
    extern save_next
    extern save_open
    extern save_ptr
    extern save_quantum
    extern save_renamed
    extern save_tail
    extern save_take
    extern save_target
    extern save_temp
    extern saved_cursor
    extern saved_history
    extern saved_tag
    extern saved_valid
    extern saving_title
    extern shift_end
    extern shift_meta_3672
    extern split_buffer
    extern split_bytes
    extern split_count
    extern split_has__2828
    extern split_index
    extern split_neig_366a
    extern split_neighbor
    extern split_next
    extern split_ptr
    extern split_total
    extern src
    extern stream_char
    extern stream_file
    extern stream_left
    extern stream_physical
    extern stream_ptr
    extern stream_rem_2015
    extern suffix_len
    extern total_label
    extern ui_x
    extern ui_y
    extern v_add_tail_2
    extern v_add_tail_3
    extern v_block_le_1
    extern v_block_of_1
    extern v_block_st_100
    extern v_block_st_101
    extern v_block_st_102
    extern v_block_st_103
    extern v_block_st_104
    extern v_block_st_108
    extern v_block_st_72
    extern v_block_st_73
    extern v_block_st_74
    extern v_block_st_75
    extern v_block_st_96
    extern v_cache_bu_1
    extern v_cache_le_3
    extern v_dir_entr_11
    extern v_entry_ba_1
    extern v_error_te_1
    extern v_error_te_2
    extern v_file_pos_1
    extern v_file_pos_2
    extern v_file_pos_3
    extern v_full_tab_2
    extern v_io_count_1
    extern v_io_posit_1
    extern v_io_posit_2
    extern v_io_posit_3
    extern v_io_table_2
    extern v_leaf_id_1
    extern v_leaf_id_2
    extern v_leaf_id_3
    extern v_leaf_sta_1
    extern v_leaf_sta_2
    extern v_leaf_sta_3
    extern v_q_1
    extern v_q_2
    extern v_q_3
    extern v_rename_c_2
    extern v_rename_t_2
    extern v_save_chu_1
    extern v_save_chu_2
    extern v_save_don_1
    extern v_save_don_2
    extern v_save_don_3
    extern v_save_len_1
    extern v_save_tak_1
    extern v_split_by_1
    extern v_split_to_1
    extern v_split_to_2
    extern v_split_to_3
    extern v_stream_l_1
    extern v_wanted_p_2
    extern v_wanted_p_3
    extern wanted_file
    extern wanted_pos
    extern where
    extern window_line
    extern window_open
    extern work_attempt
    extern work_created
    extern work_error
    extern work_extensions
    extern work_kind
    extern work_name
    extern work_path
    extern work_ready
    extern work_tail

ef_written db 'Written:',0
ef_rec_open
    ldaa #0
    jmp rec_api
ef_rec_changed
    ldaa #1
    jmp rec_api
ef_rec_crc_write
    ldaa #2
    jmp rec_api
ef_rec_trailer
    ldaa #3
    jmp rec_api
ef_rec_complete
    ldaa #4
    jmp rec_api
ef_rec_cleanup
    ldaa #5
    jmp rec_api
ef_rec_saved
    ldaa #6
    jmp rec_api
; BE32 accumulator. CMP preserves the usual unsigned carry/zero convention.
q_load
    ldaa 0,x
    staa q
    ldaa 1,x
    staa v_q_1
    ldaa 2,x
    staa v_q_2
    ldaa 3,x
    staa v_q_3
    rts
q_store
    ldaa q
    staa 0,x
    ldaa v_q_1
    staa 1,x
    ldaa v_q_2
    staa 2,x
    ldaa v_q_3
    staa 3,x
    rts
q_add
    ldaa v_q_3
    adda 3,x
    staa v_q_3
    ldaa v_q_2
    adca 2,x
    staa v_q_2
    ldaa v_q_1
    adca 1,x
    staa v_q_1
    ldaa q
    adca 0,x
    staa q
    rts
q_sub
    ldaa v_q_3
    suba 3,x
    staa v_q_3
    ldaa v_q_2
    sbca 2,x
    staa v_q_2
    ldaa v_q_1
    sbca 1,x
    staa v_q_1
    ldaa q
    sbca 0,x
    staa q
    rts
q_cmp
    ldaa q
    cmpa 0,x
    bne q_compared
    ldaa v_q_1
    cmpa 1,x
    bne q_compared
    ldaa v_q_2
    cmpa 2,x
    bne q_compared
    ldaa v_q_3
    cmpa 3,x
q_compared
    rts
q_inc
    inc v_q_3
    bne q_changed
    inc v_q_2
    bne q_changed
    inc v_q_1
    bne q_changed
    inc q
q_changed
    rts
q_dec
    ldaa v_q_3
    bne q_dec_low
    ldaa v_q_2
    bne q_dec_middle
    ldaa v_q_1
    bne q_dec_high
    dec q
q_dec_high
    dec v_q_1
q_dec_middle
    dec v_q_2
q_dec_low
    dec v_q_3
    rts
q_test
    ldaa q
    oraa v_q_1
    oraa v_q_2
    oraa v_q_3
    rts
q_512
    clra
    staa q
    staa v_q_1
    staa v_q_3
    ldaa #2
    staa v_q_2
    rts
; One ordinary cache block, plus 16 in an optional RAMMAN bank. Without
; RAMMAN the unused BIOS bounce buffer supplies a second ordinary block.
; Another ordinary block is allocated when the conventional heap fits.
; Splits flush the old leaf before loading its neighbor; two slots suffice.
; Tags are separate from data, and BIOS/font/IRQ mapping restores selectors.
; A=logical file, Q=byte offset. X=byte pointer, block_left=bytes to boundary.
block_get
    staa wanted_file
    ldx #wanted_pos
    jsr q_store
    ldaa v_q_2
    anda #1
    staa block_offset
    ldaa v_q_3
    staa v_block_of_1
    ldaa v_wanted_p_2
    anda #$fe
    staa v_wanted_p_2
    clr v_wanted_p_3
    clr cache_slot
block_find
    jsr cache_tag
    tst 0,x
    beq block_find_next
    ldaa 2,x
    cmpa wanted_file
    bne block_find_next
    stx saved_tag
    ldx #wanted_pos
    jsr q_load
    ldx saved_tag
    inx
    inx
    inx
    inx
    jsr q_cmp
    bne *+5
    jmp block_hit
block_find_next
    inc cache_slot
    ldaa cache_slot
    cmpa cache_count
    bcs block_find
    ldaa cache_hand
    staa cache_slot
    inc cache_hand
    ldaa cache_hand
    cmpa cache_count
    bcs block_victim
    clr cache_hand
block_victim
    tst work_ready
    bne block_victim_ready
    tst cache_slot
    bne block_victim_ready
    inc cache_slot
    ldaa #1
    staa cache_hand
block_victim_ready
    jsr cache_flush_slot
    tsta
    beq *+5
    jmp block_failure
    jsr cache_tag
    clr 0,x
    clr 1,x
    ldaa wanted_file
    staa 2,x
    stx saved_tag
    ldx #wanted_pos
    jsr q_load
    ldx saved_tag
    inx
    inx
    inx
    inx
    jsr q_store
    jsr cache_buffer
    stx cache_buf
    ldx #512
    stx block_left
    ldx cache_buf
block_clear
    clr 0,x
    inx
    dec v_block_le_1
    bne block_clear
    dec block_left
    bne block_clear
    ldx #wanted_pos
    jsr q_load
    ldaa wanted_file
    jsr size_pointer
    jsr q_cmp
    bcc block_loaded
    ldaa wanted_file
    staa io_file
    ldx #wanted_pos
    jsr q_load
    ldx #io_position
    jsr q_store
    jsr file_seek
    tsta
    beq *+5
    jmp block_failure
    ldx cache_buf
    ldaa cache_slot
    cmpa cache_plain_count
    bcs block_read_buffer
    ldx #disk_buffer
block_read_buffer
    stx io_table
    ldx #512
    stx v_io_table_2
    jsr io_handle
    ldx #io_table
    int $4c
    tsta
    beq *+5
    jmp block_failure
    stx io_count
    cpx #0
    beq block_loaded
    stx split_bytes
    ldaa cache_slot
    cmpa cache_plain_count
    bcs block_direct_loaded
    ldx #disk_buffer
    stx src
    ldx cache_buf
    stx dst
    jsr copy_bytes
block_direct_loaded
    jsr file_advance
block_loaded
    jsr cache_tag
    ldaa #1
    staa 0,x
block_hit
    jsr cache_buffer
    stx cache_buf
    ldaa v_cache_bu_1
    adda v_block_of_1
    staa cache_byte+1
    ldaa cache_buf
    adca block_offset
    staa cache_byte
    ldaa #0
    suba v_block_of_1
    staa v_block_le_1
    ldaa #2
    sbca block_offset
    staa block_left
    ldx cache_byte
    clra
block_failure
    rts
block_dirty
    jsr cache_tag
    ldaa #1
    staa 1,x
    rts
cache_tag
    ldab cache_slot
    aslb
    aslb
    aslb
    ldx #cache_tags
    jmp add_b
cache_buffer
    ldaa cache_slot
    cmpa cache_plain_count
    bcs cache_plain
    suba cache_plain_count
    asla
    adda #$c0
    staa cache_byte
    clr cache_byte+1
    ldx cache_byte
    rts
cache_plain
    tsta
    beq cache_plain_static
    cmpa #1
    bne cache_plain_extra
    tst cache_leased
    bne cache_plain_extra
    ldx #disk_buffer
    stx cache_byte
    rts
cache_plain_extra
    ldx cache_extra
    stx cache_byte
    rts
cache_plain_static
    ldx cache_data
    stx cache_byte
    ldx cache_byte
    rts
cache_flush_slot
    jsr cache_tag
    tst 0,x
    beq cache_clean
    tst 1,x
    beq cache_clean
    ldaa 2,x
    staa io_file
    ldaa 4,x
    staa io_position
    ldaa 5,x
    staa v_io_posit_1
    ldaa 6,x
    staa v_io_posit_2
    ldaa 7,x
    staa v_io_posit_3
    jsr file_seek
    tsta
    bne cache_flush_return
    ; UniDOS maps its own ROM while copying file data. Its caller's banked
    ; C000 buffer is not writable until return, so use an ordinary-RAM bounce.
    jsr cache_buffer
    stx io_table
    ldaa cache_slot
    cmpa cache_plain_count
    bcs cache_write_buffer
    stx src
    ldx #disk_buffer
    stx dst
    ldx #512
    stx split_bytes
    jsr copy_bytes
    ldx #disk_buffer
    stx io_table
cache_write_buffer
    ldx #512
    stx v_io_table_2
    jsr io_handle
    ldx #io_table
    int $4d
    tsta
    bne cache_flush_error
    cpx #512
    beq cache_written
    ldaa #12
    bra cache_flush_error
cache_written
    stx io_count
    jsr file_advance
    ldaa io_file
    jsr size_pointer
    jsr q_cmp
    bls cache_size_ready
    jsr q_store
cache_size_ready
    jsr cache_tag
    clr 1,x
cache_clean
    clra
cache_flush_return
    rts
cache_flush_error
    psha
    ldaa io_file
    jsr position_pointer
    ldaa #$ff
    staa 0,x
    staa 1,x
    staa 2,x
    staa 3,x
    pula
    rts
cache_flush
    ldaa cache_slot
    psha
    clr cache_slot
cache_flush_loop
    jsr cache_flush_slot
    tsta
    bne cache_flushed
    inc cache_slot
    ldaa cache_slot
    cmpa cache_count
    bcs cache_flush_loop
    clra
cache_flushed
    tab
    pula
    staa cache_slot
    tba
    rts
; Sequential reads/writes skip LSEEK entirely. Cold seeks retain the native API.
file_seek
    ldx #io_position
    jsr q_load
    ldaa io_file
    jsr position_pointer
    jsr q_cmp
    beq file_seek_ready
    jsr io_handle
    clrb
    ldx #io_position
    int $50
    tsta
    bne file_seek_return
    ldx #io_position
    jsr q_load
    ldaa io_file
    jsr position_pointer
    jsr q_store
file_seek_ready
    clra
file_seek_return
    rts
file_advance
    ldx #io_position
    jsr q_load
    ldaa v_q_3
    adda v_io_count_1
    staa v_q_3
    ldaa v_q_2
    adca io_count
    staa v_q_2
    ldaa v_q_1
    adca #0
    staa v_q_1
    ldaa q
    adca #0
    staa q
    ldaa io_file
    jsr position_pointer
    jmp q_store
io_handle
    ldab io_file
    ldx #handles
    jsr add_b
    ldaa 0,x
    rts
position_pointer
    asla
    asla
    tab
    ldx #file_positions
    jmp add_b
size_pointer
    asla
    asla
    tab
    ldx #file_sizes
    jmp add_b
editor_cache_open
    ldaa #2
    staa cache_count
    staa cache_plain_count
    ; INT2A's original one-page stack guard wraps below 0100. Do not ask
    ; for an optional 512-byte block when even that minimum cannot fit.
    tsx
    stx cache_extra
    ldaa cache_extra
    cmpa #4
    bcs editor_cache_no_extra
    ldx #512
    clrb
    int $2a
    cpx #0
    beq editor_cache_no_extra
    stx cache_extra
    inc cache_count
    inc cache_plain_count
    bra editor_cache_optional
editor_cache_no_extra
    ldx #0
    stx cache_extra
editor_cache_optional
    ldaa #$e5
    int $2e
    cpx #0
    beq editor_cache_ready
    ldaa #1
    ldab #1
    ldx #cache_lease
    int $e5
    tsta
    bne editor_cache_ready
    inc cache_leased
    ldaa $e6f0
    staa old_page
    ldaa $e6f1
    staa old_group
    ldaa v_cache_le_3
    clr lease_group
editor_cache_divide
    cmpa #6
    bcs editor_cache_map
    suba #6
    inc lease_group
    bra editor_cache_divide
editor_cache_map
    inca
    staa $e6f0
    ldaa lease_group
    staa $e6f1
    ; Ordinary fallback can use the bounce buffer as its second cache block.
    ; With a bank mapped it is reserved exclusively for BIOS transfers.
    dec cache_plain_count
    ldaa cache_plain_count
    adda #16
    staa cache_count
editor_cache_ready
    rts
editor_cache_close
    tst cache_leased
    beq editor_cache_released
    ldaa old_group
    staa $e6f1
    ldaa old_page
    staa $e6f0
    ldaa #2
    ldx #cache_lease
    int $e5
    clr cache_leased
editor_cache_released
    rts
; Disk-backed unrolled piece list. Each 512-byte leaf holds 31 descriptors.
; Header: next BE32 (FFFFFFFF=end), byte total BE32, count byte, padding.
; Descriptor: backing offset BE32, length BE32, backing file (0/2), padding.
; Finger navigation keeps nearby reads local; no descriptor-count RAM limit.
; X = leaf base, A = entry number (0..31), including the 512-byte end.
leaf_entry
    stx entry_base
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    adda #16
    adcb #0
    adda v_entry_ba_1
    adcb entry_base
    staa v_entry_ba_1
    stab entry_base
    ldx entry_base
    rts
leaf_get
    ldx #leaf_id
    jsr q_load
    ldaa #1
    jsr block_get
    tsta
    bne leaf_return
    stx leaf_ptr
    ldaa cache_slot
    staa leaf_slot
    clra
leaf_return
    rts
leaf_mark
    ldaa leaf_slot
    staa cache_slot
    jsr block_dirty
    clra
    rts
; WHERE is a logical byte position, including EOF. Relative result PIECE_IN.
doc_locate
    ldx #where
    jsr q_load
    ldx #leaf_start
    jsr q_sub
    bcc locate_leaf
locate_back
    jsr leaf_get
    tsta
    beq *+5
    jmp locate_return
    ldx leaf_ptr
    ldab #12
    jsr add_b
    ldaa 0,x
    anda 1,x
    anda 2,x
    anda 3,x
    cmpa #$ff
    beq locate_head
    jsr q_load
    ldx #leaf_id
    jsr q_store
    jsr leaf_get
    tsta
    beq *+5
    jmp locate_return
    ldx #leaf_start
    jsr q_load
    ldx leaf_ptr
    ldab #4
    jsr add_b
    jsr q_sub
    ldx #leaf_start
    jsr q_store
    ldx #where
    jsr q_load
    ldx #leaf_start
    jsr q_sub
    bcs locate_back
    bra locate_leaf
locate_head
    clr leaf_id
    clr v_leaf_id_1
    clr v_leaf_id_2
    clr v_leaf_id_3
    clr leaf_start
    clr v_leaf_sta_1
    clr v_leaf_sta_2
    clr v_leaf_sta_3

locate_leaf
    jsr leaf_get
    tsta
    beq *+5
    jmp locate_return
    ldx #where
    jsr q_load
    ldx #leaf_start
    jsr q_sub
    ldx #piece_in
    jsr q_store
    ldx leaf_ptr
    inx
    inx
    inx
    inx
    jsr q_cmp
    bcs locate_entries
    ldx leaf_ptr
    ldaa 0,x
    anda 1,x
    anda 2,x
    anda 3,x
    cmpa #$ff
    beq locate_entries
    jsr q_load
    ldx #next_leaf
    jsr q_store
    ldx #leaf_start
    jsr q_load
    ldx leaf_ptr
    inx
    inx
    inx
    inx
    jsr q_add
    ldx #leaf_start
    jsr q_store
    ldx #next_leaf
    jsr q_load
    ldx #leaf_id
    jsr q_store
    bra locate_leaf
locate_entries
    clr piece_index
    ldx leaf_ptr
    ldab #16
    jsr add_b
    stx entry_ptr
    ldx #piece_in
    jsr q_load
locate_entry
    ldx leaf_ptr
    ldaa piece_index
    cmpa 8,x
    beq locate_found
    ldx entry_ptr
    inx
    inx
    inx
    inx
    jsr q_cmp
    bcs locate_found
    jsr q_sub
    ldx entry_ptr
    ldab #16
    jsr add_b
    stx entry_ptr
    inc piece_index
    bra locate_entry
locate_found
    ldx #piece_in
    jsr q_store
    clra
locate_return
    rts
; Insert one descriptor-sized gap at ENTRY_PTR. Current leaf has spare room.
leaf_gap
    ldx leaf_ptr
    ldaa 8,x
    inc 8,x
    jsr leaf_entry
leaf_gap_byte
    cpx entry_ptr
    beq leaf_gap_done
    dex
    ldaa 0,x
    staa 16,x
    bra leaf_gap_byte
leaf_gap_done
    jmp leaf_mark
leaf_remove
    ldx leaf_ptr
    dec 8,x
    ldaa 8,x
    jsr leaf_entry
    stx shift_end
    ldx entry_ptr
leaf_remove_byte
    cpx shift_end
    beq leaf_gap_done
    ldaa 16,x
    staa 0,x
    inx
    bra leaf_remove_byte
; Split only when two free descriptors cannot be guaranteed. The new leaf
; is fully written before publishing the old leaf's link to it.
leaf_room
    ldx leaf_ptr
    ldaa 8,x
    cmpa #29
    bcc leaf_split
    clra
    rts
leaf_split
    jsr cache_flush
    tsta
    beq *+5
    jmp split_return
    ldx leaf_ptr
    ldab #$f0
    jsr add_b
    ldab #16
    jsr add_b
    stx src
    ldx #split_buffer
    stx dst
    ldx leaf_ptr
    ldaa 8,x
    suba #15
    staa split_count
    staa split_bytes
    clr v_split_by_1
    ; count * 16, 16-bit count (up to 256 bytes).
    ldaa split_count
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    staa v_split_by_1
    stab split_bytes
    jsr copy_wide
    ldx leaf_ptr
    jsr q_load
    ldx #split_next
    jsr q_store
    ldx #index_end
    jsr q_load
    ldaa #1
    jsr block_get
    tsta
    beq *+5
    jmp split_return
    stx split_ptr
    ldx #split_buffer
    stx src
    ldx split_ptr
    ldab #16
    jsr add_b
    stx dst
    ldaa split_count
    clrb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    asla
    rolb
    staa v_split_by_1
    stab split_bytes
    jsr copy_wide
    ldx #split_next
    jsr q_load
    ldx split_ptr
    jsr q_store
    ldx #leaf_id
    jsr q_load
    ldx split_ptr
    ldab #12
    jsr add_b
    jsr q_store
    ldx split_ptr
    ldaa split_count
    staa 8,x
    clr split_index
    clr split_total
    clr v_split_to_1
    clr v_split_to_2
    clr v_split_to_3
split_sum
    ldx #split_total
    jsr q_load
    ldaa split_index
    ldx split_ptr
    jsr leaf_entry
    ldab #4
    jsr add_b
    jsr q_add
    ldx #split_total
    jsr q_store
    inc split_index
    ldaa split_index
    cmpa split_count
    bcs split_sum
    ldx #split_total
    jsr q_load
    ldx split_ptr
    ldab #4
    jsr add_b
    jsr q_store
    jsr block_dirty
    jsr cache_flush
    tsta
    beq *+5
    jmp split_return
split_no_neighbor
    jsr leaf_get
    tsta
    beq *+5
    jmp split_return
    ldx #index_end
    jsr q_load
    ldx leaf_ptr
    jsr q_store
    ldx leaf_ptr
    ldaa #15
    staa 8,x
    ldab #4
    jsr add_b
    jsr q_load
    ldx #split_total
    jsr q_sub
    ldx leaf_ptr
    ldab #4
    jsr add_b
    jsr q_store
    jsr leaf_mark
    jsr cache_flush
    tsta
    beq *+5
    jmp split_return
    ldx #split_next
    jsr q_load
    ldaa q
    anda v_q_1
    anda v_q_2
    anda v_q_3
    cmpa #$ff
    beq split_links_ready
    ldaa #1
    jsr block_get
    tsta
    beq *+5
    jmp split_return
    stx split_neighbor
    ldx #index_end
    jsr q_load
    ldx split_neighbor
    ldab #12
    jsr add_b
    jsr q_store
    jsr block_dirty
split_links_ready
    jsr q_512
    ldx #index_end
    jsr q_add
    ldx #index_end
    jsr q_store
    jsr doc_locate
split_return
    rts
; Copy SPLIT_BYTES bytes. Used only for bounded leaf halves, never a document.
copy_wide
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    staa 0,x
    inx
    stx dst
    ldaa v_split_by_1
    bne copy_wide_low
    dec split_bytes
copy_wide_low
    dec v_split_by_1
    ldaa split_bytes
    oraa v_split_by_1
    bne copy_wide
    rts
; WHERE, INSERT_OFF/LEN describe an ADD-file fragment. No payload is copied.
doc_insert
    ldx #insert_len
    jsr q_load
    jsr q_test
    bne *+5
    jmp insert_return
    ldx #doc_size
    jsr q_add
    bcc insert_size_ok
    ldaa #12
    rts
insert_size_ok
    jsr doc_locate
    tsta
    beq *+5
    jmp insert_return
    jsr leaf_room
    tsta
    beq *+5
    jmp insert_return
    ldx #piece_in
    jsr q_load
    jsr q_test
    beq insert_boundary
    ; Split the containing span into prefix and suffix.
    ldx entry_ptr
    stx prefix_ptr
    ldab #16
    jsr add_b
    stx entry_ptr
    jsr leaf_gap
    ldx prefix_ptr
    stx src
    ldx entry_ptr
    stx dst
    ldab #16
    jsr copy_n
    ldx entry_ptr
    jsr q_load
    ldx #piece_in
    jsr q_add
    ldx entry_ptr
    jsr q_store
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_load
    ldx #piece_in
    jsr q_sub
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_store
    ldx #piece_in
    jsr q_load
    ldx prefix_ptr
    ldab #4
    jsr add_b
    jsr q_store
    inc piece_index
insert_boundary
    ; Coalesce sequential typing into the preceding ADD span.
    tst piece_index
    beq insert_new
    ldx entry_ptr
    stx insert_ptr
    dex
    dex
    dex
    dex
    dex
    dex
    dex
    dex
    ldaa 0,x
    cmpa #2
    bne insert_restore
    dex
    dex
    dex
    dex
    dex
    dex
    dex
    dex
    stx prefix_ptr
    jsr q_load
    ldx prefix_ptr
    ldab #4
    jsr add_b
    jsr q_add
    ldx #insert_off
    jsr q_cmp
    bne insert_restore
    ldx prefix_ptr
    ldab #4
    jsr add_b
    jsr q_load
    ldx #insert_len
    jsr q_add
    ldx prefix_ptr
    ldab #4
    jsr add_b
    jsr q_store
    bra insert_totals
insert_restore
    ldx insert_ptr
    stx entry_ptr
insert_new
    jsr leaf_gap
    ldx #insert_off
    jsr q_load
    ldx entry_ptr
    jsr q_store
    ldx #insert_len
    jsr q_load
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_store
    ldx entry_ptr
    ldaa #2
    staa 8,x
insert_totals
    ldx leaf_ptr
    ldab #4
    jsr add_b
    jsr q_load
    ldx #insert_len
    jsr q_add
    ldx leaf_ptr
    ldab #4
    jsr add_b
    jsr q_store
    ldx #doc_size
    jsr q_load
    ldx #insert_len
    jsr q_add
    ldx #doc_size
    jsr q_store
    jmp leaf_mark
insert_return
    rts
; Remove REMOVE_LEN bytes at WHERE. Trims whole spans in one step.
doc_delete
    ldx #remove_len
    jsr q_load
    ldx #remove_left
    jsr q_store
delete_more
    ldx #remove_left
    jsr q_load
    jsr q_test
    bne *+5
    jmp delete_return
    jsr doc_locate
    tsta
    beq *+5
    jmp delete_return
    jsr leaf_room
    tsta
    beq *+5
    jmp delete_return
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_load
    ldx #piece_in
    jsr q_sub
    ldx #remove_left
    jsr q_cmp
    bls delete_take
    ldx #remove_left
    jsr q_load
delete_take
    ldx #remove_take
    jsr q_store
    ldx #piece_in
    jsr q_load
    jsr q_test
    bne delete_inside
    ldx entry_ptr
    jsr q_load
    ldx #remove_take
    jsr q_add
    ldx entry_ptr
    jsr q_store
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_load
    ldx #remove_take
    jsr q_sub
    jsr q_test
    beq delete_whole
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_store
    jmp delete_totals
delete_whole
    jsr leaf_remove
    jmp delete_totals
delete_inside
    ldx entry_ptr
    stx prefix_ptr
    ldab #4
    jsr add_b
    jsr q_load
    ldx #piece_in
    jsr q_sub
    ldx #remove_take
    jsr q_sub
    jsr q_test
    beq delete_prefix
    ldx #suffix_len
    jsr q_store
    ldx prefix_ptr
    ldab #16
    jsr add_b
    stx entry_ptr
    jsr leaf_gap
    ldx prefix_ptr
    stx src
    ldx entry_ptr
    stx dst
    ldab #16
    jsr copy_n
    ldx prefix_ptr
    jsr q_load
    ldx #piece_in
    jsr q_add
    ldx #remove_take
    jsr q_add
    ldx entry_ptr
    jsr q_store
    ldx #suffix_len
    jsr q_load
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_store
delete_prefix
    ldx #piece_in
    jsr q_load
    ldx prefix_ptr
    ldab #4
    jsr add_b
    jsr q_store
delete_totals
    ldx leaf_ptr
    ldab #4
    jsr add_b
    jsr q_load
    ldx #remove_take
    jsr q_sub
    ldx leaf_ptr
    ldab #4
    jsr add_b
    jsr q_store
    ldx #doc_size
    jsr q_load
    ldx #remove_take
    jsr q_sub
    ldx #doc_size
    jsr q_store
    ldx #remove_left
    jsr q_load
    ldx #remove_take
    jsr q_sub
    ldx #remove_left
    jsr q_store
    jsr leaf_mark
    jmp delete_more
delete_return
    rts
; Logical stream: map a span once, then consume cached bytes without seeking.
stream_init
    clr stream_left
    clr v_stream_l_1
    ldx #where
    jsr q_load
    ldx #doc_size
    jsr q_cmp
    bcs stream_locate
    clra
    sec
    rts
stream_locate
    jsr doc_locate
    tsta
    beq *+5
    jmp stream_error
    ldx entry_ptr
    ldaa 8,x
    staa stream_file
    jsr q_load
    ldx #piece_in
    jsr q_add
    ldx #stream_physical
    jsr q_store
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_load
    ldx #piece_in
    jsr q_sub
    ldx #stream_rem_2015
    jsr q_store
    clra
    clc
    rts
stream_next
    ldx stream_left
    beq *+5
    jmp stream_cached
    jsr stream_block
    bcc *+5
    jmp stream_error
    jmp stream_cached
; Expose a contiguous cached span without consuming bytes. Bulk Save can
; copy it and advance all four-byte positions once per chunk.
stream_block
    ldx stream_left
    beq *+5
    jmp stream_block_ready
    ldx #stream_rem_2015
    jsr q_load
    jsr q_test
    bne stream_refill
    jsr stream_init
    bcc *+5
    jmp stream_error

stream_refill
    ldx #stream_physical
    jsr q_load
    ldaa stream_file
    jsr block_get
    tsta
    beq *+5
    jmp stream_error
    stx stream_ptr
    ldx #stream_rem_2015
    jsr q_load
    ldaa q
    oraa v_q_1
    bne stream_full
    ldaa v_q_2
    cmpa block_left
    bne stream_compare
    ldaa v_q_3
    cmpa v_block_le_1
stream_compare
    bcc stream_full
    ldx v_q_2
    stx block_left
stream_full
    ldx block_left
    stx stream_left
    ldx #stream_physical
    jsr q_load
    ldaa v_q_3
    adda v_block_le_1
    staa v_q_3
    ldaa v_q_2
    adca block_left
    staa v_q_2
    ldaa v_q_1
    adca #0
    staa v_q_1
    ldaa q
    adca #0
    staa q
    ldx #stream_physical
    jsr q_store
stream_block_ready
    clra
    clc
    rts
stream_cached
    ldx stream_ptr
    ldaa 0,x
    staa stream_char
    inx
    stx stream_ptr
    ldx stream_left
    dex
    stx stream_left
    ldx #stream_rem_2015
    jsr q_load
    jsr q_dec
    ldx #stream_rem_2015
    jsr q_store
    ldx #where
    jsr q_load
    jsr q_inc
    ldx #where
    jsr q_store
    ldaa stream_char
    clc
    rts
stream_error
    sec
    rts
doc_byte
    jsr stream_init
    bcc *+5
    jmp stream_error
    jmp stream_next
; Open original read-only. Workspace creation is deferred until the first edit.
editor_open
    jsr ef_rec_open
    tsta
    beq *+5
    jmp editor_open_return
    ldaa #8
    jsr rec_api
    tsta
    beq *+5
    jmp editor_seed
    ldx #filename
    stx open_table
    ldx #0
    stx v_open_tab_2
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    beq *+5
    jmp editor_open_return
    stab handles
    ldaa #1
    staa opened
    tba
    ldx #file_sizes
    int $51
    tsta
    beq *+5
    jmp editor_open_return
    ldx #file_sizes
    jsr q_load
    ldx #doc_size
    jsr q_store
editor_seed
    ; Seed a pinned RAM-only index leaf, so read-only viewing needs no scratch.
    clr cache_slot
    jsr cache_buffer
    stx leaf_ptr
    ; The first cache block reuses dead loader code, rather than zeroed BSS.
    ; Empty files also need an explicitly empty entry count and descriptors.
    ldaa #2
    clrb
editor_seed_clear
    clr 0,x
    inx
    decb
    bne editor_seed_clear
    deca
    bne editor_seed_clear
    ldx leaf_ptr
    ldaa #$ff
    staa 0,x
    staa 1,x
    staa 2,x
    staa 3,x
    staa 12,x
    staa 13,x
    staa 14,x
    staa 15,x
    ldx #doc_size
    jsr q_load
    ldx leaf_ptr
    ldab #4
    jsr add_b
    jsr q_store
    jsr q_test
    beq editor_empty
    ldx leaf_ptr
    ldaa #1
    staa 8,x
    clra
    jsr leaf_entry
    stx entry_ptr
    clr 0,x
    clr 1,x
    clr 2,x
    clr 3,x
    clr 8,x
    ldx #doc_size
    jsr q_load
    ldx entry_ptr
    ldab #4
    jsr add_b
    jsr q_store
editor_empty
    jsr cache_tag
    ldaa #1
    staa 0,x
    staa 2,x
    ldaa #1
    staa cache_hand
    jsr q_512
    ldx #index_end
    jsr q_store
    clra
editor_open_return
    rts
; Three unique 8.3 work files: NCEhhhhh.IDX / .ADD / .UND.
; All three names are checked before CREATE; existing files are never truncated.
work_open
    tst work_ready
    beq *+5
    jmp work_success
    ldx owner
    ldab #255
    jsr add_b
    ldab #52
    jsr add_b
    tst 0,x
    bne work_directory
    ldx #filename
work_directory
    stx src
    ldx #work_path
    stx dst
    jsr copy_z
    ldx #work_path
    stx work_tail
work_tail_scan
    ldaa 0,x
    beq work_tail_found
    inx
    cmpa #'\'
    bne work_tail_scan
    stx work_tail
    bra work_tail_scan
work_tail_found
    ; A configured directory ends with a slash; a source pathname doesn't.
    ldx work_tail
    stx dst
    ldx #work_name
    stx src
    jsr copy_z
    clr work_attempt
work_unique
    ldx work_tail
    ldaa work_attempt
    lsra
    lsra
    lsra
    lsra
    jsr hex_digit
    staa 6,x
    ldaa work_attempt
    anda #15
    jsr hex_digit
    staa 7,x
    clr work_kind
work_check_names
    jsr work_extension
    ldx #work_path
    stx v_find_tab_4
    ldx #find_state
    stx find_table
    ldx #dir_entry
    stx v_find_tab_2
    clra
    clrb
    ldx #find_table
    int $42
    cmpa #11
    beq work_name_free
    tsta
    bne work_return
    inc work_attempt
    bne work_unique
    ldaa #12
    rts
work_name_free
    inc work_kind
    ldaa work_kind
    cmpa #3
    bcs work_check_names
    clr work_kind
work_create
    jsr work_extension
    ldx #work_path
    stx open_table
    ldx #0
    stx v_open_tab_2
    clra
    ldx #open_table
    int $4b
    tsta
    bne work_failed
    tba
    int $4e
    tsta
    bne work_failed
    ldaa #3
    ldx #open_table
    int $4a
    tsta
    bne work_failed
    stab new_handle
    ldaa work_kind
    inca
    staa io_file
    tab
    ldx #handles
    jsr add_b
    ldaa new_handle
    staa 0,x
    inc work_created
    inc opened
    inc work_kind
    ldaa work_kind
    cmpa #3
    bcs work_create
    inc work_ready
    clr cache_slot
    jsr block_dirty
    jsr cache_flush
    tsta
    bne work_return
work_success
    clra
work_return
    rts
work_failed
    staa work_error
    jsr work_cleanup
    ldaa work_error
    rts
work_extension
    ldaa work_kind
    asla
    asla
    tab
    ldx #work_extensions
    jsr add_b
    stx src
    ldx work_tail
    ldab #9
    jsr add_b
    stx dst
    jmp copy_z
work_cleanup
    clr work_kind
work_cleanup_loop
    ldaa work_kind
    cmpa work_created
    bcc work_cleanup_done
    inca
    tab
    ldx #handles
    jsr add_b
    ldaa 0,x
    int $4e
    jsr work_extension
    ldx #work_path
    int $4f
    inc work_kind
    bra work_cleanup_loop
work_cleanup_done
    clr work_created
    clr work_ready
    rts
editor_close
    jsr mouse_close
    tst save_open
    beq editor_work_close
    ldaa save_handle
    int $4e
editor_work_close
    jsr work_cleanup
    ldaa handles
    int $4e
    ; The latest backup supersedes the first backing version once Undo ends.
    tst base_is_backup
    beq editor_keep_backups
    tst latest_backup
    beq editor_keep_backups
    ldx #base_path
    int $4f
editor_keep_backups
    jsr ef_rec_cleanup
    jsr editor_cache_close
    ldaa saved_cursor
    staa $ed1d
    ldaa mode
    cmpa #2
    bne editor_close_video
    ldaa #6
    int $22
    ldaa original_attr
    int $22
editor_close_video
    ldab original_attr
    int $16
    int $38
hex_digit
    anda #15
    adda #'0'
    cmpa #'9'
    bls hex_ready
    adda #7
hex_ready
    rts
; Buffered append store. This is also the backing store for removed text.
add_byte
    staa append_char
    jsr append_block
    tsta
    bne append_return
    ldaa append_char
    staa 0,x
    jsr block_dirty
    ldx #add_tail
    jsr q_load
    jsr q_inc
    ldx #add_tail
    jsr q_store
    clra
append_return
    rts
; Byte edits and bulk Paste share this append-boundary rule. UniDOS cannot
; seek beyond EOF: finish the preceding ADD sector before starting the next,
; independent of replacement hand position or the available cache count.
append_block
    ldaa v_add_tail_2
    anda #1
    oraa v_add_tail_3
    bne append_get
    ldx #add_tail
    jsr q_load
    jsr q_test
    beq append_get
    jsr cache_flush
    tsta
    bne append_return
append_get
    ldx #add_tail
    jsr q_load
    ldaa #2
    jmp block_get

; A small edit is prepared before it is published. The pending operation
; records enough progress to resume an interrupted undo/delete after I/O errors.
change_prepare
    ldx #change_at
    jsr q_load
    ldx #where
    jsr q_store
    jsr doc_locate
    tsta
    bne change_prepared
    ldx leaf_ptr
    ldaa 8,x
    cmpa #27
    bcs change_prepare_end
    jsr leaf_split
    tsta
    bne change_prepared
change_prepare_end
    ldaa change_delete
    jsr q_small
    ldx #change_at
    jsr q_add
    ldx #where
    jsr q_store
    ldx #doc_size
    jsr q_cmp
    bcc change_prepare_start
    jsr doc_locate
    tsta
    bne change_prepared
    ldx leaf_ptr
    ldaa 8,x
    cmpa #27
    bcs change_prepare_start
    jsr leaf_split
    tsta
    bne change_prepared
change_prepare_start
    ldx #change_at
    jsr q_load
    ldx #where
    jsr q_store
    jmp doc_locate
change_prepared
    rts
editor_change
    jsr work_open
    tsta
    beq *+5
    jmp change_return
    jsr change_prepare
    tsta
    beq *+5
    jmp change_return
    ldx #change_at
    jsr q_load
    ldx #pending_record
    jsr q_store
    ldx #add_tail
    jsr q_load
    ldx #pending_record+4
    jsr q_store
    ldaa change_delete
    jsr q_small
    ldx #pending_record+8
    jsr q_store
    clr change_index
change_collect
    ldaa change_index
    cmpa change_delete
    bcc change_new_text
    jsr q_small
    ldx #change_at
    jsr q_add
    ldx #where
    jsr q_store
    jsr doc_byte
    bcc *+5
    jmp change_return
    jsr add_byte
    tsta
    beq *+5
    jmp change_return
    inc change_index
    bra change_collect
change_new_text
    ldx #add_tail
    jsr q_load
    ldx #pending_record+12
    jsr q_store
    ldaa change_add
    jsr q_small
    ldx #pending_record+16
    jsr q_store
    clr change_index
change_append
    ldaa change_index
    cmpa change_add
    bcc change_record
    tab
    ldx #change_bytes
    jsr add_b
    ldaa 0,x
    jsr add_byte
    tsta
    beq *+5
    jmp change_return
    inc change_index
    bra change_append
change_record
    ldx #e_cursor
    jsr q_load
    ldx #pending_record+20
    jsr q_store
    ldaa change_add
    jsr q_small
    ldx #change_at
    jsr q_add
    ldx #pending_record+24
    jsr q_store
    ldaa change_lin_2598
    staa pending_record+29
    ldaa change_group
    staa pending_record+28
    clr history_mode
    ldx #history_cursor
    jsr q_load
    ldx #history_po_08d6
    jsr q_store
    ldx #history_cursor
    jsr q_load
    ldx #const32
    jsr q_add
    ldx #history_target
    jsr q_store
    tst group_open
    bne *+5
    jmp change_new_record
    tst change_group
    bne *+5
    jmp change_new_record
    tst change_delete
    beq *+5
    jmp change_new_record
    ldx #history_cursor
    jsr q_load
    ldx #history_count
    jsr q_cmp
    beq *+5
    jmp change_new_record
    ldx #const32
    jsr q_sub
    ldx #history_po_08d6
    jsr q_store
    jsr history_get
    tsta
    beq *+5
    jmp change_return
    ldaa history_record+28
    bne *+5
    jmp change_new_record
    ldx #history_record
    jsr q_load
    ldx #history_record+16
    jsr q_add
    ldx #change_at
    jsr q_cmp
    beq *+5
    jmp change_new_record
    ldx #history_record+12
    jsr q_load
    ldx #history_record+16
    jsr q_add
    ldx #pending_record+12
    jsr q_cmp
    beq *+5
    jmp change_new_record
    ldx #history_record+16
    jsr q_load
    ldx #pending_record+16
    jsr q_add
    ldx #history_record+16
    jsr q_store
    ldx #pending_record+24
    jsr q_load
    ldx #history_record+24
    jsr q_store
    ldx #history_cursor
    jsr q_load
    ldx #history_target
    jsr q_store
    bra change_write_record
change_new_record
    ldx #history_cursor
    jsr q_load
    ldx #history_po_08d6
    jsr q_store
    ldx #pending_record
    stx src
    ldx #history_record
    stx dst
    ldab #32
    jsr copy_n
change_write_record
    jsr history_put
    tsta
    beq *+5
    jmp change_return
    ; Refill/presplit both touched leaves after appending the payload/log.
    jsr change_prepare
    tsta
    beq *+5
    jmp change_return
    ldaa change_group
    staa group_open
    ldx #pending_record
    jsr q_load
    ldx #apply_pos
    jsr q_store
    ldx #pending_record+8
    jsr q_load
    ldx #apply_left
    jsr q_store
    ldx #pending_record+12
    jsr q_load
    ldx #apply_inse_9b8b
    jsr q_store
    ldx #pending_record+16
    jsr q_load
    ldx #apply_inse_8b0f
    jsr q_store
    ldx #pending_record+24
    jsr q_load
    ldx #apply_cursor
    jsr q_store
    ldaa #1
    staa apply_phase
    jmp history_resume
change_return
    rts
history_get
    ldx #history_po_08d6
    jsr q_load
    ldaa #3
    jsr block_get
    tsta
    beq *+5
    jmp history_io_return
    stx src
    ldx #history_record
    stx dst
    ldab #32
    jsr copy_n
    clra
history_io_return
    rts
history_put
    ldx #history_po_08d6
    jsr q_load
    ldx #v_file_siz_12
    jsr q_cmp
    bls history_put_block
    jsr cache_flush
    tsta
    beq *+5
    jmp history_io_return
history_put_block
    ldx #history_po_08d6
    jsr q_load
    ldaa #3
    jsr block_get
    tsta
    beq *+5
    jmp history_io_return
    stx dst
    ldx #history_record
    stx src
    ldab #32
    jsr copy_n
    jsr block_dirty
    clra
    rts
history_undo
    clr group_open
    ldx #history_cursor
    jsr q_load
    jsr q_test
    beq history_io_return
    ldx #const32
    jsr q_sub
    ldx #history_po_08d6
    jsr q_store
    ldx #history_target
    jsr q_store
    jsr history_get
    tsta
    beq *+5
    jmp history_io_return
    ldaa #1
    staa history_mode
    ldx #history_record
    jsr q_load
    ldx #apply_pos
    jsr q_store
    ldx #history_record+16
    jsr q_load
    ldx #apply_left
    jsr q_store
    ldx #history_record+4
    jsr q_load
    ldx #apply_inse_9b8b
    jsr q_store
    ldx #history_record+8
    jsr q_load
    ldx #apply_inse_8b0f
    jsr q_store
    ldx #history_record+20
    jsr q_load
    ldx #apply_cursor
    jsr q_store
    ldaa #1
    staa apply_phase
    jmp history_resume
history_redo
    clr group_open
    ldx #history_cursor
    jsr q_load
    ldx #history_count
    jsr q_cmp
    bcs *+5
    jmp history_nothing
    ldx #history_po_08d6
    jsr q_store
    ldx #const32
    jsr q_add
    ldx #history_target
    jsr q_store
    jsr history_get
    tsta
    beq *+5
    jmp history_io_return
    ldaa #2
    staa history_mode
    ldx #history_record
    jsr q_load
    ldx #apply_pos
    jsr q_store
    ldx #history_record+8
    jsr q_load
    ldx #apply_left
    jsr q_store
    ldx #history_record+12
    jsr q_load
    ldx #apply_inse_9b8b
    jsr q_store
    ldx #history_record+16
    jsr q_load
    ldx #apply_inse_8b0f
    jsr q_store
    ldx #history_record+24
    jsr q_load
    ldx #apply_cursor
    jsr q_store
    ldaa #1
    staa apply_phase
history_resume
    ldaa apply_phase
    cmpa #1
    bne history_insert
    ldx #apply_pos
    jsr q_load
    ldx #where
    jsr q_store
    ldx #apply_left
    jsr q_load
    ldx #remove_left
    jsr q_store
    jsr delete_more
    staa apply_error
    ldx #remove_left
    jsr q_load
    ldx #apply_left
    jsr q_store
    ldaa apply_error
    beq *+5
    jmp history_io_return
    ldaa #2
    staa apply_phase
history_insert
    ldx #apply_pos
    jsr q_load
    ldx #where
    jsr q_store
    ldx #apply_inse_9b8b
    jsr q_load
    ldx #insert_off
    jsr q_store
    ldx #apply_inse_8b0f
    jsr q_load
    ldx #insert_len
    jsr q_store
    jsr doc_insert
    tsta
    beq *+5
    jmp history_io_return
    ldx #apply_cursor
    jsr q_load
    ldx #e_cursor
    jsr q_store
    tst history_mode
    bne history_move_cursor
    ; A new edit after Undo discards the redo tail, including a saved marker.
    ldx #history_cursor
    jsr q_load
    ldx #saved_history
    jsr q_cmp
    bcc history_keep_saved
    clr saved_valid
history_keep_saved
    ldx #history_target
    jsr q_load
    ldx #history_count
    jsr q_store
history_move_cursor
    ldx #history_target
    jsr q_load
    ldx #history_cursor
    jsr q_store
    clr apply_phase
    ldaa #1
    staa modified
    tst saved_valid
    beq history_applied
    ldx #history_cursor
    jsr q_load
    ldx #saved_history
    jsr q_cmp
    bne history_applied
    clr modified
history_applied
    jsr ef_rec_changed
    clra
    rts
history_nothing
    clra
    rts
q_small
    staa v_q_3
    clr q
    clr v_q_1
    clr v_q_2
    rts
; A grouped Undo inside the visible line does not rescan a very long prefix.
history_fast_update
    tst history_record+29
    bne history_full_view
    clr metadata_row
history_find_row
    ldx #line_valid
    ldab metadata_row
    jsr add_b
    tst 0,x
    beq history_full_view
    ldx #apply_pos
    jsr q_load
    ldaa metadata_row
    jsr line_pointer
    jsr q_cmp
    bcs history_next_row
    ldaa metadata_row
    jsr end_pointer
    jsr q_cmp
    bls history_row_found
history_next_row
    inc metadata_row
    ldaa metadata_row
    cmpa body_rows
    bcs history_find_row
history_full_view
    ldaa #1
    rts
history_row_found
    ldx #apply_pos
    jsr q_load
    ldaa metadata_row
    jsr left_pointer
    jsr q_cmp
    bcs history_full_view
    ldaa history_mode
    cmpa #1
    beq history_undo_delta
    ldx #apply_pos
    jsr q_load
    ldx #history_record+8
    jsr q_add
    ldaa metadata_row
    jsr end_pointer
    jsr q_cmp
    bhi history_full_view
    ldx #history_record+16
    jsr q_load
    ldx #history_record+8
    jsr q_sub
    bra history_delta_ready
history_undo_delta
    ldx #apply_pos
    jsr q_load
    ldx #history_record+16
    jsr q_add
    ldaa metadata_row
    jsr end_pointer
    jsr q_cmp
    bhi history_full_view
    ldx #history_record+8
    jsr q_load
    ldx #history_record+16
    jsr q_sub
history_delta_ready
    ldx #edit_delta
    jsr q_store
    ldaa metadata_row
    staa cursor_row
    jsr shift_meta_3672
    jsr column_fro_c274
    tsta
    bne history_fast_return
    jsr ensure_hor_027b
    tsta
    beq history_fast_line
    jmp horizontal_beef
history_fast_line
    ldaa cursor_row
    staa render_row
    clr build_full
    jsr build_line
    tsta
    bne history_fast_return
    jsr paint_line
    clra
history_fast_return
    rts
editor_history_result
    tsta
    bne history_fast_error
    jsr history_fast_update
    cmpa #1
    beq history_fast_rebuild
    jmp editor_finish
history_fast_rebuild
    jmp rebuild_cursor
history_fast_error
    jmp editor_error
; Publish a fully closed new file, retaining the original as a backing/backup.
; Working ADD/index/undo state survives Save; Undo remains available afterwards.
editor_save
    tst modified
    bne save_current
    clra
    rts
save_current
    ldx #filename
    stx src
    ldx #save_target
    stx dst
    jsr copy_z
    jmp save_begin
editor_save_as
    ldx #filename
    stx src
    ldx #input
    stx dst
    jsr copy_z
    ldx #save_as_title
    jsr dialog
    bcc *+5
    jmp save_cancelled
    tst input
    bne *+5
    jmp save_cancelled
    ldx #input
    jsr editor_path_length
    bcc save_input_length_ok
    ldaa #19
    rts
save_input_length_ok
    stab v_block_st_108
    ; Resolve relative names against the editor document's directory.
    ldx #input
    ldaa 1,x
    cmpa #':'
    beq save_resolve_input
    ldaa 0,x
    cmpa #'\'
    beq save_document_root
    ldx #filename
    stx src
    ldx #error_text
    stx dst
    jsr copy_z
    ldx #error_text
    stx path_tail
save_parent_scan
    ldaa 0,x
    beq save_parent_ready
    inx
    cmpa #'\'
    bne save_parent_scan
    stx path_tail
    bra save_parent_scan
save_parent_ready
    ldx #error_text
    clrb
save_parent_length
    cpx path_tail
    beq save_parent_counted
    inx
    incb
    bra save_parent_length
save_parent_counted
    addb v_block_st_108
    cmpb #64
    bcs save_parent_fits
    ldaa #19
    rts
save_parent_fits
    ldx path_tail
    stx dst
    ldx #input
    stx src
    jsr copy_z
    ldx #error_text
    bra save_resolve
save_document_root
    ldaa v_block_st_108
    cmpa #62
    bcs save_document_root_fits
    ldaa #19
    rts
save_document_root_fits
    ldaa filename
    staa error_text
    ldaa #':'
    staa v_error_te_1
    ldx #v_error_te_2
    stx dst
    ldx #input
    stx src
    jsr copy_z
    ldx #error_text
    bra save_resolve
save_resolve_input
    ldx #input
save_resolve
    stx full_table
    ldx #save_target
    stx v_full_tab_2
    ldx #full_table
    int $3f
    tsta
    beq *+5
    jmp save_return
    ldx #save_target
    jsr editor_stat
    cmpa #11
    beq save_begin
    tsta
    beq *+5
    jmp save_return
    ldx #filename
    stx src
    ldx #save_target
    stx dst
    jsr same_path
    beq save_begin
    ldx #overwrite_text
    jsr confirm
    cmpa #'Y'
    beq save_begin
save_cancelled
    ldaa #$ff
    rts
save_begin
    jsr block_clos_a41c
    tsta
    beq *+5
    jmp save_return
    clr v_block_st_104
    clr v_block_st_100
    clr v_block_st_101
    clr v_block_st_102
    clr v_block_st_103
    ldx #doc_size
    jsr q_load
    ldx #v_block_st_96
    jsr q_store

save_no_pending_handle
    clr save_open
    clr save_renamed
    clr base_closed
    clr save_exists
    clr save_attributes
    ldx #save_target
    jsr editor_stat
    cmpa #11
    beq save_names
    tsta
    beq *+5
    jmp save_return
    ldaa v_dir_entr_11
    bita #17
    beq save_attribute_ok
    ldaa #3
    rts
save_attribute_ok
    staa save_attributes
    inc save_exists
save_names
    jsr save_unique
    tsta
    beq *+5
    jmp save_return
    jsr cache_flush
    tsta
    beq *+5
    jmp save_return
    ldx #save_temp
    stx open_table
    ldx #0
    stx v_open_tab_2
    clra
    ldx #open_table
    int $4b
    tsta
    beq *+5
    jmp save_return
    stab save_handle
    inc save_open
    ldx #saving_title
    jsr window_open
    ldx #save_target
    ldaa #8
    jsr window_line
save_stream_begin
    jsr save_meter_begin
    ldx #v_block_st_100
    jsr q_load
    ldx #where
    jsr q_store
    jsr stream_init
    bcc *+5
    jmp save_stream_end
save_fill
    ldx #save_buffer
    stx save_ptr
    clr save_length
    clr v_save_len_1
save_read_byte
    clr save_chunk
    clr v_save_chu_1
    ldx save_length
    stx v_save_chu_2
    ldx #v_block_st_96
    jsr q_load
    ldx #save_done
    jsr q_sub
    ldx #save_chunk
    jsr q_sub
    jsr q_test
    bne *+5
    jmp save_read_end
    ldx #v_block_st_72
    jsr q_store
    jsr stream_block
    bcc *+5
    jmp save_read_end
    ldaa #0
    suba v_save_len_1
    staa v_save_tak_1
    ldaa #1
    sbca save_length
    staa save_take
    ldaa stream_left
    cmpa save_take
    bne save_compare_take
    ldaa v_stream_l_1
    cmpa v_save_tak_1
save_compare_take
    bcc save_take_ready
    ldx stream_left
    stx save_take
save_take_ready
    ldaa v_block_st_72
    oraa v_block_st_73
    bne save_range_ready
    ldaa v_block_st_74
    cmpa save_take
    bne save_range_compare
    ldaa v_block_st_75
    cmpa v_save_tak_1
save_range_compare
    bcc save_range_ready
    ldx v_block_st_74
    stx save_take
save_range_ready
    ldx stream_ptr
    stx src
    ldx save_ptr
    stx dst
    ldx save_take
    stx split_bytes
    jsr copy_bytes
    ldx src
    stx stream_ptr
    ldx dst
    stx save_ptr
    clr save_chunk
    clr v_save_chu_1
    ldx save_take
    stx v_save_chu_2
    ldx #stream_rem_2015
    jsr q_load
    ldx #save_chunk
    jsr q_sub
    ldx #stream_rem_2015
    jsr q_store
    ldx #where
    jsr q_load
    ldx #save_chunk
    jsr q_add
    ldx #where
    jsr q_store
    ldaa v_stream_l_1
    suba v_save_tak_1
    staa v_stream_l_1
    ldaa stream_left
    sbca save_take
    staa stream_left
    ldaa v_save_len_1
    adda v_save_tak_1
    staa v_save_len_1
    ldaa save_length
    adca save_take
    staa save_length
    cmpa #1
    bcc *+5
    jmp save_read_byte
    jsr save_write
    tsta
    beq *+5
    jmp save_fail
    jmp save_fill

save_read_end
    tsta
    beq *+5
    jmp save_fail
    ldx save_length
    cpx #0
    beq save_stream_end
    jsr save_write
    tsta
    beq *+5
    jmp save_fail
save_stream_end
    tsta
    beq *+5
    jmp save_fail
    ldaa #7
    jsr rec_api
    tsta
    beq save_close_output
    jsr ef_rec_trailer
    tsta
    beq *+5
    jmp save_fail
save_close_output
    ldaa save_handle
    int $4e
    tsta
    beq *+5
    jmp save_fail
    clr save_open
    ldaa #7
    jsr rec_api
    tsta
    beq save_normal_output
    jmp ef_rec_complete
save_normal_output
    tst v_block_st_104
    beq *+5
    jmp block_copy_b900
    tst save_exists
    beq save_publish
    ldx #base_path
    stx src
    ldx #save_target
    stx dst
    jsr same_path
    bne save_backup_target
    ldaa handles
    int $4e
    tsta
    beq *+5
    jmp save_fail
    inc base_closed
save_backup_target
    ldx #save_target
    stx rename_table
    ldx #save_backup
    stx v_rename_t_2
    jsr editor_rename
    tsta
    beq *+5
    jmp save_reopen_failure
    inc save_renamed
save_publish
    ldx #save_temp
    stx rename_table
    ldx #save_target
    stx v_rename_t_2
    jsr editor_rename
    tsta
    beq *+5
    jmp save_rollback
    tst base_closed
    beq save_keep_backup
    ldx #save_backup
    stx src
    ldx #base_path
    stx dst
    jsr copy_z
    inc base_is_backup
    jsr reopen_base
    tsta
    beq *+5
    jmp save_return
    bra save_published
save_keep_backup
    tst save_renamed
    beq save_published
    ; Keep the latest previous version as well as the open original backing.
    tst latest_backup
    beq save_record_backup
    ldx #latest_backup
    int $4f
save_record_backup
    ldx #save_backup
    stx src
    ldx #latest_backup
    stx dst
    jsr copy_z
save_published
    ldaa #1
    ldab save_attributes
    orab #32
    ldx #save_target
    int $54
    tsta
    beq *+5
    jmp save_return
    jsr ef_rec_saved
    ldx #save_target
    stx src
    ldx #filename
    stx dst
    jsr copy_z
    ldx #history_cursor
    jsr q_load
    ldx #saved_history
    jsr q_store
    ldaa #1
    staa saved_valid
    clr modified
    clr save_renamed
    clra
save_return
    rts
save_write
    ldaa #7
    jsr rec_api
    tsta
    beq save_write_output
    jsr ef_rec_crc_write
save_write_output
    ldx #save_buffer
    stx io_table
    ldx save_length
    stx v_io_table_2
    ldaa save_handle
    ldx #io_table
    int $4d
    tsta
    beq *+5
    jmp save_return
    cpx save_length
    beq save_write_counted
    ldaa #12
    rts
save_write_counted
    ldx #save_done
    jsr q_load
    ldaa v_q_3
    adda v_save_len_1
    staa v_q_3
    ldaa v_q_2
    adca save_length
    staa v_q_2
    ldaa v_q_1
    adca #0
    staa v_q_1
    ldaa q
    adca #0
    staa q
    ldx #save_done
    jsr q_store
    ldx #save_next
    jsr q_cmp
    bcs save_poll
    jsr save_progress
save_poll
    ldaa #1
    jsr mouse_cancel
    cmpa #27
    bne *+5
    jmp save_cancelled
    cmpa #3
    bne *+5
    jmp save_cancelled
save_write_ok
    clra
    rts
save_fail
    staa save_error
    tst save_open
    beq save_remove_temp
    ldaa save_handle
    int $4e
    tsta
    beq save_failed_handle_closed
    ldaa save_error
    rts
save_failed_handle_closed
    clr save_open
save_remove_temp
    ldx #save_temp
    int $4f
    ldaa save_error
    rts
save_rollback
    staa save_error
    tst save_renamed
    beq save_reopen_error
    ldx #save_backup
    stx rename_table
    ldx #save_target
    stx v_rename_t_2
    jsr editor_rename
    tsta
    beq save_reopen_error
    ; Failed rollback retains the backup and points the backing handle to it.
    tst base_closed
    beq save_reopen_error
    ldx #save_backup
    stx src
    ldx #base_path
    stx dst
    jsr copy_z
    inc base_is_backup
save_reopen_error
    tst base_closed
    beq save_remove_temp
    jsr reopen_base
    jmp save_remove_temp
save_reopen_failure
    staa save_error
    tst base_closed
    beq save_remove_temp
    jsr reopen_base
    jmp save_remove_temp
reopen_base
    ldx #base_path
    stx open_table
    ldx #0
    stx v_open_tab_2
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    bne reopen_return
    stab handles
    ldaa #$ff
    staa file_positions
    staa v_file_pos_1
    staa v_file_pos_2
    staa v_file_pos_3
    clr base_closed
    clra
reopen_return
    rts
save_unique
    ldx #save_target
    stx src
    ldx #save_temp
    stx dst
    jsr copy_z
    ldx #save_temp
    stx save_tail
save_tail_scan
    ldaa 0,x
    beq save_tail_ready
    inx
    cmpa #'\'
    bne save_tail_scan
    stx save_tail
    bra save_tail_scan
save_tail_ready
    ldx save_tail
    stx dst
    ldx #save_name
    stx src
    jsr copy_z
    ldx #save_temp
    stx src
    ldx #save_backup
    stx dst
    jsr copy_z
    ldx #save_temp
    clrb
save_prefix_length
    cpx save_tail
    beq save_backup_pointer_ready
    inx
    incb
    bra save_prefix_length
save_backup_pointer_ready
    ldx #save_backup
    jsr add_b
    stx save_backu_94f9
    ldaa #'B'
    staa 9,x
    ldaa #'A'
    staa 10,x
    ldaa #'K'
    staa 11,x
    clr save_attempt
save_unique_try
    ldaa save_attempt
    lsra
    lsra
    lsra
    lsra
    jsr hex_digit
    ldx save_tail
    staa 6,x
    ldx save_backu_94f9
    staa 6,x
    ldaa save_attempt
    jsr hex_digit
    ldx save_tail
    staa 7,x
    ldx save_backu_94f9
    staa 7,x
    ldx #save_temp
    jsr editor_stat
    cmpa #11
    bne save_unique_next
    ldx #save_backup
    jsr editor_stat
    cmpa #11
    beq save_unique_ready
save_unique_next
    tsta
    bne save_unique_error
    inc save_attempt
    bne save_unique_try
    ldaa #12
    rts
save_unique_error
    cmpa #11
    beq save_unique_advance
    rts
save_unique_advance
    inc save_attempt
    bne save_unique_try
    ldaa #12
    rts
save_unique_ready
    clra
    rts
editor_stat
    stx v_find_tab_4
    ldx #find_state
    stx find_table
    ldx #dir_entry
    stx v_find_tab_2
    clra
    clrb
    ldx #find_table
    int $42
    rts
editor_rename
    ldx rename_table
    stx src
    ldx #input
    stx dst
    jsr copy_z
    ldx v_rename_t_2
    stx src
    ldx #error_text
    stx dst
    jsr copy_z
    ldx #input
    stx rename_call
    ldx #error_text
    stx v_rename_c_2
    ldx #rename_call
    int $56
    rts
same_path
    ldx src
    ldaa 0,x
    inx
    stx src
    cmpa #'a'
    bcs same_path_left
    cmpa #'z'
    bhi same_path_left
    anda #$df
same_path_left
    staa path_char
    ldx dst
    ldaa 0,x
    inx
    stx dst
    cmpa #'a'
    bcs same_path_compare
    cmpa #'z'
    bhi same_path_compare
    anda #$df
same_path_compare
    cmpa path_char
    bne same_path_done
    tsta
    bne same_path
same_path_done
    rts
save_progress
    ldx #save_done
    jsr q_load
    ldx #v_block_st_96
    jsr q_cmp
    bcs save_progress_cells
    ldaa save_bar_width
    staa save_cells
    jmp save_progress_draw

save_progress_cells
    ldx #save_next
    jsr q_cmp
    bcs save_progress_draw
    ldaa save_cells
    cmpa save_bar_width
    bcc save_progress_draw
    inc save_cells
    ldx #save_next
    jsr q_load
    ldx #save_quantum
    jsr q_add
    ldx #save_next
    jsr q_store
    ldx #save_done
    jsr q_load
    bra save_progress_cells
save_progress_draw
    ldaa #$07
    jsr colour
    ldx #ef_written
    ldaa #11
    jsr window_line
    ldx #save_done
    jsr q_load
    ldx #number
    jsr q_store
    jsr decimal_number
    ldaa #14
    staa ui_x
    ldaa #11
    staa ui_y
    jsr position
    ldaa columns
    suba #20
    staa remaining
    ldx #number_text
    jsr field
    ldx #total_label
    ldaa #12
    jsr window_line
    ldx #v_block_st_96
    jsr q_load
    ldx #number
    jsr q_store
    jsr decimal_number
    ldaa #14
    staa ui_x
    ldaa #12
    staa ui_y
    jsr position
    ldaa columns
    suba #20
    staa remaining
    ldx #number_text
    jsr field
    ldaa #6
    staa ui_x
    ldaa #14
    staa ui_y
    ldaa #$03
    jsr colour
    jsr position
    clr save_bar_index
save_bar_cell
    ldaa #' '
    ldab save_bar_index
    cmpb save_cells
    bcc save_bar_put
    ldaa #'#'
save_bar_put
    jsr put
    inc save_bar_index
    ldaa save_bar_index
    cmpa save_bar_width
    bcs save_bar_cell
    rts

; The DOS pathname interface accepts at most 63 bytes plus its terminator.
editor_path_length
    clrb
editor_path_byte
    tst 0,x
    beq editor_path_valid
    inx
    incb
    cmpb #64
    bcs editor_path_byte
    sec
    rts
editor_path_valid
    clc
    rts

; Shared progress initialization for Save, Copy and large block transfers.
save_meter_begin
    ldx #cancel_sav_fb1e
    ldaa #16
    jsr window_line
    clr save_done
    clr v_save_don_1
    clr v_save_don_2
    clr v_save_don_3
    clr save_cells
    ldx #v_block_st_96
    jsr q_load
    ldx #number
    jsr q_store
    ldaa columns
    suba #12
    staa save_bar_width
    staa number_divisor
    jsr divide_number
    ldx #number
    jsr q_load
    ldx #save_quantum
    jsr q_store
    ldx #save_quantum
    jsr q_load
    tst remainder
    beq save_quantum_ready
    jsr q_inc
save_quantum_ready
    jsr q_test
    bne save_quantum_store
    jsr q_inc
save_quantum_store
    ldx #save_quantum
    jsr q_store
    ldx #save_next
    jsr q_store
    jsr save_progress
    rts
    section
cache_slot ds 1
cache_byte ds 2
pending_record ds 32
history_record ds 32
    ends
change_new_3955 equ change_new_record
editor_cac_de58 equ editor_cache_open
editor_his_2705 equ editor_history_result
save_meter_802e equ save_meter_begin
save_strea_2340 equ save_stream_begin
v_pending__12 equ pending_record+12
v_pending__16 equ pending_record+16
v_pending__20 equ pending_record+20
v_pending__24 equ pending_record+24
v_pending__28 equ pending_record+28
v_pending__29 equ pending_record+29
v_pending__4 equ pending_record+4
v_pending__8 equ pending_record+8
    end
