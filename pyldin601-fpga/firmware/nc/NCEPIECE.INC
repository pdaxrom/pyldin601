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
    adda entry_base+1
    adcb entry_base
    staa entry_base+1
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
    clr leaf_id+1
    clr leaf_id+2
    clr leaf_id+3
    clr leaf_start
    clr leaf_start+1
    clr leaf_start+2
    clr leaf_start+3

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
    ldaa next_leaf
    staa leaf_id
    ldaa next_leaf+1
    staa leaf_id+1
    ldaa next_leaf+2
    staa leaf_id+2
    ldaa next_leaf+3
    staa leaf_id+3
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
    clr split_bytes+1
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
    staa split_bytes+1
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
    staa split_bytes+1
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
    clr split_total+1
    clr split_total+2
    clr split_total+3
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
    clr split_has_neighbor
    ldx #split_next
    jsr q_load
    ldaa q
    anda q+1
    anda q+2
    anda q+3
    cmpa #$ff
    beq split_no_neighbor
    ldaa #1
    jsr block_get
    tsta
    beq *+5
    jmp split_return
    stx split_neighbor
    ldaa cache_slot
    staa split_neighbor_slot
    inc split_has_neighbor
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
    tst split_has_neighbor
    beq split_links_ready
    ldx #index_end
    jsr q_load
    ldx split_neighbor
    ldab #12
    jsr add_b
    jsr q_store
    ldaa split_neighbor_slot
    staa cache_slot
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
    ldaa split_bytes+1
    bne copy_wide_low
    dec split_bytes
copy_wide_low
    dec split_bytes+1
    ldaa split_bytes
    oraa split_bytes+1
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
    ldaa remove_len
    staa remove_left
    ldaa remove_len+1
    staa remove_left+1
    ldaa remove_len+2
    staa remove_left+2
    ldaa remove_len+3
    staa remove_left+3
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
    clr stream_left+1
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
    ldx #stream_remaining
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
    ldx #stream_remaining
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
    ldx #stream_remaining
    jsr q_load
    ldaa q
    oraa q+1
    bne stream_full
    ldaa q+2
    cmpa block_left
    bne stream_compare
    ldaa q+3
    cmpa block_left+1
stream_compare
    bcc stream_full
    ldx q+2
    stx block_left
stream_full
    ldx block_left
    stx stream_left
    ldx #stream_physical
    jsr q_load
    ldaa q+3
    adda block_left+1
    staa q+3
    ldaa q+2
    adca block_left
    staa q+2
    ldaa q+1
    adca #0
    staa q+1
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
    ldx #stream_remaining
    jsr q_load
    jsr q_dec
    ldx #stream_remaining
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
