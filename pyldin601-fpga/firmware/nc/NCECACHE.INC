; Four ordinary 512-byte blocks; one optional RAMMAN bank adds 16 blocks.
; Tags are separate from data, and BIOS/font/IRQ mapping restores selectors.
; A=logical file, Q=byte offset. X=byte pointer, block_left=bytes to boundary.
block_get
    staa wanted_file
    ldx #wanted_pos
    jsr q_store
    ldaa q+2
    anda #1
    staa block_offset
    ldaa q+3
    staa block_offset+1
    ldaa wanted_pos+2
    anda #$fe
    staa wanted_pos+2
    clr wanted_pos+3
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
    ldaa #2
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
    dec block_left+1
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
    ldx #disk_buffer
    stx io_table
    ldx #512
    stx io_table+2
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
    ldx #disk_buffer
    stx src
    ldx cache_buf
    stx dst
    jsr copy_bytes
    jsr file_advance
block_loaded
    jsr cache_tag
    ldaa #1
    staa 0,x
block_hit
    jsr cache_buffer
    stx cache_buf
    ldaa cache_buf+1
    adda block_offset+1
    staa cache_byte+1
    ldaa cache_buf
    adca block_offset
    staa cache_byte
    ldaa #0
    suba block_offset+1
    staa block_left+1
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
    cmpa #4
    bcs cache_plain
    suba #4
    asla
    adda #$c0
    staa cache_byte
    clr cache_byte+1
    ldx cache_byte
    rts
cache_plain
    ldx #cache_data
    stx cache_byte
    asla
    adda cache_byte
    staa cache_byte
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
    staa io_position+1
    ldaa 6,x
    staa io_position+2
    ldaa 7,x
    staa io_position+3
    jsr file_seek
    tsta
    bne cache_flush_return
    ; UniDOS maps its own ROM while copying file data. Its caller's banked
    ; C000 buffer is not writable until return, so use an ordinary-RAM bounce.
    jsr cache_buffer
    stx src
    ldx #disk_buffer
    stx dst
    ldx #512
    stx split_bytes
    jsr copy_bytes
    ldx #disk_buffer
    stx io_table
    ldx #512
    stx io_table+2
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
    ldaa q+3
    adda io_count+1
    staa q+3
    ldaa q+2
    adca io_count
    staa q+2
    ldaa q+1
    adca #0
    staa q+1
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
    ldaa #4
    staa cache_count
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
    ldaa cache_lease+3
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
    ldaa #20
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
