; Parse/validate the original file stored in SRAM. YM3b loop is little
; endian (StSound Ymload.cpp); YM5/6 numbers are big endian.
parse_song
    jsr memory_reset
    ldx #header
    stx header_pointer
    ldaa #4
    staa header_count
    jsr read_header
    ldx header
    cpx #$5053
    bne parse_ym
    ldx header+2
    cpx #$471a
    beq long_ymread_14
    jmp format_bad
long_ymread_14
    jmp parse_psg
parse_ym
    cpx #$594d
    beq long_ymread_18
    jmp format_bad
long_ymread_18
    ldaa header+2
    cmpa #'3'
    beq long_ymread_21
    jmp ym_later
long_ymread_21
    ldaa header+3
    cmpa #'!'
    beq ym_three
    cmpa #'b'
    beq long_ymread_26
    jmp format_bad
long_ymread_26
    inc has_loop
ym_three
    ldd #256
    std clock_factor
    ldaa #1
    staa interleaved
    staa kind
    ldaa #14
    staa stride
    ldd song_size
    std division
    ldd song_size+2
    subd #4
    std division+2
    ldd division
    sbcb #0
    sbca #0
    std division
    tst has_loop
    beq ym_three_count
    ldd division+2
    subd #4
    std division+2
    ldd division
    sbcb #0
    sbca #0
    std division
ym_three_count
    jsr divide_fourteen
    ldd division
    beq long_ymread_57
    jmp format_bad
long_ymread_57
    ldd division+2
    std frames
    bne long_ymread_60
    jmp format_bad
long_ymread_60
    ldd #0
    std data_offset
    ldd #4
    std data_offset+2
    tst has_loop
    bne long_ymread_66
    jmp validate_ym
long_ymread_66
    ldd song_size+2
    subd #4
    std offset+2
    ldd song_size
    sbcb #0
    sbca #0
    std offset
    jsr make_pointer
    ldd computed
    std read_pointer
    ldd computed+2
    std read_pointer+2
    ldd #0
    std read_left
    ldd #4
    std read_left+2
    jsr memory_byte
    staa loop_frame+1
    jsr memory_byte
    staa loop_frame
    jsr memory_byte
    tsta
    beq long_ymread_89
    jmp format_bad
long_ymread_89
    jsr memory_byte
    tsta
    beq long_ymread_92
    jmp format_bad
long_ymread_92
    jmp validate_ym
format_bad
    jmp bad_file
ym_later
    cmpa #'5'
    beq ym_five_six
    cmpa #'6'
    beq long_ymread_100
    jmp format_bad
long_ymread_100
ym_five_six
    ldaa header+3
    cmpa #'!'
    beq long_ymread_104
    jmp format_bad
long_ymread_104
    ldaa #30
    staa header_count
    jsr read_header
    ldx header+4
    cpx #$4c65
    beq long_ymread_110
    jmp format_bad
long_ymread_110
    ldx header+6
    cpx #$4f6e
    beq long_ymread_113
    jmp format_bad
long_ymread_113
    ldx header+8
    cpx #$4172
    beq long_ymread_116
    jmp format_bad
long_ymread_116
    ldx header+10
    cpx #$4421
    beq long_ymread_119
    jmp format_bad
long_ymread_119
    ldd header+12
    beq long_ymread_121
    jmp format_bad
long_ymread_121
    ldd header+14
    bne long_ymread_123
    jmp format_bad
long_ymread_123
    std frames
    ldd header+16
    beq long_ymread_126
    jmp format_bad
long_ymread_126
    tst header+18
    beq long_ymread_128
    jmp format_bad
long_ymread_128
    ldaa header+19
    cmpa #7
    bls long_ymread_131
    jmp format_bad
long_ymread_131
    anda #1
    staa interleaved
    ldd header+20
    beq no_drums
    jmp unsupported_effect
no_drums
    ldd header+26
    bne long_ymread_139
    jmp format_bad
long_ymread_139
    cpx #0
    std rate
    ldx rate
    cpx #100
    bls long_ymread_144
    jmp format_bad
long_ymread_144
    ldd header+28
    beq long_ymread_146
    jmp format_bad
long_ymread_146
    ldd header+30
    std loop_frame
    jsr ym_clock
    ldaa #16
    staa stride
    ldaa #1
    staa kind
    ldd header+32
    std skip_count
skip_extra
    ldd skip_count
    beq strings_start
    subd #1
    std skip_count
    jsr memory_byte
    bra skip_extra
strings_start
    ldaa #3
    staa string_count
skip_string
    jsr memory_byte
    tsta
    bne skip_string
    dec string_count
    bne skip_string
    ldd song_size+2
    subd read_left+2
    std data_offset+2
    ldd song_size
    sbcb read_left+1
    sbca read_left
    std data_offset
    ; Exactly frames*16 plus End!, no unbounded arithmetic/trailing garbage.
    ldd frames
    std offset+2
    ldd #0
    std offset
    ldaa #4
    staa shift_count
payload_shift
    asl offset+3
    rol offset+2
    rol offset+1
    rol offset
    dec shift_count
    bne payload_shift
    ldd offset+2
    addd #4
    std offset+2
    ldd offset
    adcb #0
    adca #0
    std offset
    ldx offset
    cpx read_left
    beq long_ymread_202
    jmp format_bad_jump
long_ymread_202
    ldx offset+2
    cpx read_left+2
    beq long_ymread_205
    jmp format_bad_jump
long_ymread_205
    ldd song_size+2
    subd #4
    std offset+2
    ldd song_size
    sbcb #0
    sbca #0
    std offset
    jsr make_pointer
    ldd computed
    std read_pointer
    ldd computed+2
    std read_pointer+2
    ldd #0
    std read_left
    ldd #4
    std read_left+2
    ldx #header
    stx header_pointer
    ldaa #4
    staa header_count
    jsr read_header
    ldx header
    cpx #$456e
    beq long_ymread_229
    jmp format_bad_jump
long_ymread_229
    ldx header+2
    cpx #$6421
    beq long_ymread_232
    jmp format_bad_jump
long_ymread_232
validate_ym
    ldx loop_frame
    cpx frames
    bcs long_ymread_236
    jmp format_bad_jump
long_ymread_236
    ldaa looping
    staa saved_looping
    clr looping
    jsr ym_reset
validate_next
    jsr ym_frame
    tst current_frame+1
    bne validate_key_checked
    jsr loading_key
validate_key_checked
    tst decode_status
    bne validated
    ldaa raw_frame+1
    oraa raw_frame+3
    bita #$30
    beq validate_next
    jmp unsupported_effect
validated
    clr decode_status
    ldaa saved_looping
    staa looping
    ldd #0
    std current_frame
    jsr ym_reset
    rts
format_bad_jump
    jmp bad_file
read_header
    jsr memory_byte
    ldx header_pointer
    staa 0,x
    inx
    stx header_pointer
    dec header_count
    bne read_header
    rts
ym_clock
    ldx header+22
    cpx #$001e
    bne not_two_mhz
    ldx header+24
    cpx #$8480
    beq long_ymread_275
    jmp clock_bad
long_ymread_275
    ldd #256
    std clock_factor
    rts
not_two_mhz
    cpx #$000f
    bne not_one_mhz
    ldx header+24
    cpx #$4240
    beq long_ymread_284
    jmp clock_bad
long_ymread_284
    ldd #512
    std clock_factor
    rts
not_one_mhz
    cpx #$001b
    beq long_ymread_290
    jmp clock_bad
long_ymread_290
    ldx header+24
    cpx #$0f58
    bne not_spectrum_clock
    ldd #289
    std clock_factor
    rts
not_spectrum_clock
    cpx #$4f4d
    beq long_ymread_299
    jmp clock_bad
long_ymread_299
    ldd #286
    std clock_factor
    rts
clock_bad
    jmp bad_file
; Divide a 32-bit payload length by fourteen, requiring an exact quotient.
divide_fourteen
    clr remainder
    ldaa #32
    staa shift_count
divide_bit
    asl division+3
    rol division+2
    rol division+1
    rol division
    rol remainder
    ldaa remainder
    cmpa #14
    bcs divide_next
    suba #14
    staa remainder
    inc division+3
divide_next
    dec shift_count
    bne divide_bit
    tst remainder
    beq long_ymread_326
    jmp clock_bad
long_ymread_326
    rts
; Convert bounded linear offset to a group/slot/window address.
make_pointer
    ldaa offset+1
    asla
    asla
    asla
    ldab offset+2
    lsrb
    lsrb
    lsrb
    lsrb
    lsrb
    aba
    clrb
divide_group
    cmpa #6
    bcs group_ready
    suba #6
    incb
    bra divide_group
group_ready
    stab computed
    inca
    staa computed+1
    ldaa offset+2
    anda #31
    oraa #$c0
    staa computed+2
    ldaa offset+3
    staa computed+3
    rts
ym_reset
    ldd data_offset
    std offset
    ldd data_offset+2
    addd current_frame
    std offset+2
    ldd offset
    adcb #0
    adca #0
    std offset
    tst interleaved
    bne pointer_base_ready
    ; For planar=0, frame index has a sixteen-byte stride.
    ldd current_frame
    std seek_delta+2
    clr seek_delta
    clr seek_delta+1
    ldaa #4
    staa shift_count
seek_shift
    asl seek_delta+3
    rol seek_delta+2
    rol seek_delta+1
    rol seek_delta
    dec shift_count
    bne seek_shift
    ldd data_offset+2
    addd seek_delta+2
    std offset+2
    ldd data_offset
    adcb seek_delta+1
    adca seek_delta
    std offset
pointer_base_ready
    ldx #ym_pointers
    stx table_pointer
    ldaa #14
    staa pointer_count
pointer_next
    jsr make_pointer
    ldx table_pointer
    ldd computed
    std 0,x
    ldd computed+2
    std 2,x
    ldab #4
    abx
    stx table_pointer
    ldd #1
    tst interleaved
    beq pointer_stride
    ldd frames
pointer_stride
    addd offset+2
    std offset+2
    ldd offset
    adcb #0
    adca #0
    std offset
    dec pointer_count
    bne pointer_next
    rts
ym_frame
    ldx current_frame
    cpx frames
    bcs ym_read_frame
    tst looping
    bne long_ymread_426
    jmp song_ended
long_ymread_426
    ldd loop_frame
    std current_frame
    jsr ym_reset
ym_read_frame
    ldx #ym_pointers
    stx table_pointer
    ldx #raw_frame
    stx output_pointer
    ldaa #14
    staa pointer_count
ym_register
    ldx table_pointer
    jsr mem_read
    psha
    tst interleaved
    bne ym_pointer_done
    ldd 2,x
    addd #15
    cmpa #$e0
    bcs ym_stride_ready
    suba #$20
    inc 1,x
    psha
    ldaa 1,x
    cmpa #7
    bne ym_stride_slot
    ldaa #1
    staa 1,x
    inc 0,x
ym_stride_slot
    pula
ym_stride_ready
    std 2,x
ym_pointer_done
    ldx table_pointer
    ldab #4
    abx
    stx table_pointer
    pula
    ldx output_pointer
    staa 0,x
    inx
    stx output_pointer
    dec pointer_count
    bne ym_register
    ldd current_frame
    addd #1
    std current_frame
    rts
song_ended
    ldaa #1
    staa decode_status
    rts

parse_psg
    ldx #header+4
    stx header_pointer
    ldaa #12
    staa header_count
    jsr read_header
    ldaa header+5
    bne psg_rate
    ldaa #50
psg_rate
    cmpa #50
    beq psg_rate_ok
    cmpa #60
    beq long_ymread_484
    jmp clock_bad_jump
long_ymread_484
psg_rate_ok
    tab
    clra
    std rate
    ldaa looping
    staa saved_looping
    clr looping
    jsr compact_psg
    jsr psg_reset
validate_psg
    jsr psg_frame
    jsr loading_key
    tst decode_status
    beq validate_psg
    ldaa decode_status
    cmpa #1
    beq long_ymread_499
    jmp clock_bad_jump
long_ymread_499
    ldaa saved_looping
    staa looping
    clr decode_status
    jmp psg_reset
clock_bad_jump
    jmp bad_file
psg_reset
    jsr memory_reset
    ldd #$c010
    std read_pointer+2
    ldd read_left+2
    subd #16
    std read_left+2
    ldd read_left
    sbcb #0
    sbca #0
    std read_left
    bcc long_ymread_517
    jmp clock_bad_jump
long_ymread_517
    ldd #0
    std psg_delay
    ldx #raw_frame
    ldaa #14
psg_clear
    clr 0,x
    inx
    deca
    bne psg_clear
    ldaa #$3f
    staa raw_frame+7
    rts
psg_frame
    ldaa #$ff
    staa raw_frame+13
    ldd psg_delay
    beq psg_commands
    subd #1
    std psg_delay
    rts
psg_commands
    ldaa #64
    staa command_budget
psg_command
    ldd read_left
    bne psg_get_command
    ldd read_left+2
    bne long_ymread_545
    jmp psg_end
long_ymread_545
psg_get_command
    jsr memory_byte
    cmpa #$fd
    bne long_ymread_549
    jmp psg_end
long_ymread_549
    cmpa #$ff
    beq psg_return
    cmpa #$fe
    beq psg_wait
    cmpa #16
    bcc psg_invalid
    staa psg_register
    ldd read_left
    bne psg_value
    ldd read_left+2
    beq psg_invalid
psg_value
    jsr memory_byte
    ldab psg_register
    cmpb #14
    bcc psg_next_command
    psha
    ldx #raw_frame
    abx
    pula
    staa 0,x
psg_next_command
    dec command_budget
    bne psg_command
psg_invalid
    ldaa #2
    staa decode_status
    rts
psg_wait
    ldd read_left
    bne psg_wait_byte
    ldd read_left+2
    beq psg_invalid
psg_wait_byte
    jsr memory_byte
    tsta
    beq psg_invalid
    tab
    clra
    asld
    asld
    subd #1
    std psg_delay
psg_return
    rts
psg_end
    tst looping
    beq psg_finished
    jsr psg_reset
    ; Avoid an empty file looping forever with interrupts masked.
    tst loop_guard
    bne psg_invalid
    inc loop_guard
    jsr psg_commands
    clr loop_guard
    rts
psg_finished
    jmp song_ended

; Collapse repeated register writes before buffered playback. This is in-place:
; each output frame has at most 14 pairs and never exceeds consumed input.
; Frame preparation stays bounded even for dense PSG logs at 1 MHz.
compact_psg
    jsr psg_reset
    ldd #1
    std write_pointer
    ldd #$c010
    std write_pointer+2
    ldd #0
    std compact_size
    ldd #16
    std compact_size+2
    jsr compact_clear
compact_next
    tst read_pointer+3
    bne compact_key_checked
    jsr loading_key
compact_key_checked
    ldd read_left
    bne compact_read
    ldd read_left+2
    bne compact_long_716
    jmp compact_end
compact_long_716
compact_read
    jsr memory_byte
    cmpa #$fd
    bne compact_long_720
    jmp compact_mark_end
compact_long_720
    cmpa #$ff
    beq compact_tick
    cmpa #$fe
    beq compact_wait
    cmpa #16
    bcs compact_long_726
    jmp compact_bad
compact_long_726
    staa psg_register
    ldd read_left
    bne compact_value
    ldd read_left+2
    bne compact_long_731
    jmp compact_bad
compact_long_731
compact_value
    jsr memory_byte
    ldab psg_register
    cmpb #14
    bcc compact_next
    psha
    ldx #raw_frame
    abx
    pula
    staa 0,x
    ldx #compact_touched
    abx
    ldaa #1
    staa 0,x
    jmp compact_next
compact_tick
    jsr compact_flush
    ldaa #$ff
    jsr compact_emit
    jmp compact_next
compact_wait
    ldd read_left
    bne compact_delay_read
    ldd read_left+2
    bne compact_long_756
    jmp compact_bad
compact_long_756
compact_delay_read
    jsr memory_byte
    tsta
    bne compact_long_760
    jmp compact_bad
compact_long_760
    staa compact_delay
    jsr compact_flush
    ldaa #$fe
    jsr compact_emit
    ldaa compact_delay
    jsr compact_emit
    jmp compact_next
compact_bad
    jmp bad_file
compact_mark_end
    ldaa #$fd
    jsr compact_emit
compact_end
    ldd compact_size
    std song_size
    ldd compact_size+2
    std song_size+2
    rts
compact_emit
    psha
    ldd compact_size+2
    addd #1
    std compact_size+2
    ldd compact_size
    adcb #0
    adca #0
    std compact_size
    pula
    jmp mem_write
compact_flush
    clr compact_register
compact_each
    ldx #compact_touched
    ldab compact_register
    abx
    tst 0,x
    beq compact_skip
    clr 0,x
    ldaa compact_register
    jsr compact_emit
    ldx #raw_frame
    ldab compact_register
    abx
    ldaa 0,x
    jsr compact_emit
compact_skip
    inc compact_register
    ldaa compact_register
    cmpa #14
    bcs compact_each
    rts
compact_clear
    ldx #compact_touched
    ldab #14
compact_clear_next
    clr 0,x
    inx
    decb
    bne compact_clear_next
    rts
