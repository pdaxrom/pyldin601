; Native YM/PSG/VTX/LH5 decoder reused from YPLAY, feeding GAMEBIOS FRAME.
; No IRQ hook here: GAMEBIOS owns audio; the application closes its context.
; Buffered file reader: bounded by the actual DOS size, not FAT allocation.
mus_file_byte
    ldd mus_file_left
    bne mus_file_available
    ldd mus_file_left+2
    bne mus_file_available
    jmp mus_bad_file
mus_file_available
    ldd mus_available
    bne mus_file_buffered
    ldd #512
    ldx mus_file_left
    bne mus_refill
    ldx mus_file_left+2
    cpx #512
    bcc mus_refill
    ldd mus_file_left+2
mus_refill
    std mus_io_table+2
    ldd #mus_input_buffer
    std mus_io_table
    ldaa mus_handle
    ldx #mus_io_table
    int $4c
    tsta
    beq my238
    jmp mus_io_failed_jump
my238
    cpx mus_io_table+2
    beq my240
    jmp mus_io_failed_jump
my240
    stx mus_available
    ldx #mus_input_buffer
    stx mus_input_pointer
    ; mus_loading can also be cancelled; this never runs in the IRQ handler.
    jsr mus_loading_key
    bra mus_file_buffered
mus_loading_key
    int $10
    cmpa #$ff
    beq mus_loading_key_done
    int $11
    cmpa #27
    bne mus_loading_key_done
    jmp mus_escaped
mus_loading_key_done
    rts
mus_io_failed_jump
    jmp mus_io_failed
mus_file_buffered
    ldd mus_file_left+2
    subd #1
    std mus_file_left+2
    ldd mus_file_left
    sbcb #0
    sbca #0
    std mus_file_left
    ldd mus_available
    subd #1
    std mus_available
    ldx mus_input_pointer
    ldaa 0,x
    inx
    stx mus_input_pointer
    rts

; Memory pointer = logical bank, reserved byte, big-endian CPU address.
; The allocation map permits fragmented physical banks; the IRQ uses only
; the conventional-RAM frame queue and never switches song banks.
mus_mem_read
    stx mus_access_pointer
    jsr mus_select_bank
    ldx 2,x
    ldaa 0,x
    psha
    ldx mus_access_pointer
    jsr mus_mem_advance
    pula
    rts
mus_mem_advance
    inc 3,x
    bne mus_mem_done
    inc 2,x
    ldaa 2,x
    cmpa #$e0
    bne mus_mem_done
    ldaa #$c0
    staa 2,x
    inc 0,x
mus_mem_done
    rts
mus_mem_write
    psha
    ldx #mus_write_pointer
    stx mus_access_pointer
    jsr mus_select_bank
    ldx 2,x
    pula
    staa 0,x
    ldx #mus_write_pointer
    jmp mus_mem_advance
mus_select_bank
    ldab 0,x
    cmpb mus_memory_lease+2
    bcs mus_select_bank_valid
    jmp mus_bad_file
mus_select_bank_valid
    ldx #mus_bank_groups
    abx
    ldaa 0,x
    staa mus_group
    ldx #mus_bank_pages
    abx
    ldaa 0,x
    staa mus_page
    ldx mus_access_pointer
    rts
mus_memory_byte
    ldd mus_read_left
    bne mus_memory_available
    ldd mus_read_left+2
    bne mus_memory_available
    jmp mus_bad_file
mus_memory_available
    ldd mus_read_left+2
    subd #1
    std mus_read_left+2
    ldd mus_read_left
    sbcb #0
    sbca #0
    std mus_read_left
    ldx #mus_read_pointer
    jmp mus_mem_read
mus_memory_reset
    ldd #0
    std mus_read_pointer
    ldd #$c000
    std mus_read_pointer+2
    ldd mus_song_size
    std mus_read_left
    ldd mus_song_size+2
    std mus_read_left+2
    rts
mus_load_song
    ldd #0
    std mus_write_pointer
    ldd #$c000
    std mus_write_pointer+2
    ; Read the signature first. LHA detection/decoder is in a separate module.
    ldx #mus_header
    stx mus_header_pointer
    ldaa #4
    staa mus_header_count
mus_load_signature
    jsr mus_file_byte
    ldx mus_header_pointer
    staa 0,x
    inx
    stx mus_header_pointer
    dec mus_header_count
    bne mus_load_signature
    ldaa mus_header
    oraa #$20
    cmpa #'a'
    bne mus_load_not_vtx
    ldaa mus_header+1
    oraa #$20
    cmpa #'y'
    bne mus_load_not_vtx
    jmp mus_load_vtx
mus_load_not_vtx
    ldaa mus_header+2
    cmpa #'-'
    bne mus_load_raw
    ldaa mus_header+3
    cmpa #'l'
    bne mus_load_raw
    jmp mus_load_lha
mus_load_raw
    ldd mus_file_size
    std mus_song_size
    ldd mus_file_size+2
    std mus_song_size+2
    jsr mus_check_size
    ldx #mus_header
    stx mus_header_pointer
    ldaa #4
    staa mus_header_count
mus_write_signature
    ldx mus_header_pointer
    ldaa 0,x
    inx
    stx mus_header_pointer
    jsr mus_mem_write
    dec mus_header_count
    bne mus_write_signature
mus_load_raw_next
    ldd mus_file_left
    bne mus_load_raw_byte
    ldd mus_file_left+2
    beq mus_load_complete
mus_load_raw_byte
    jsr mus_file_byte
    jsr mus_mem_write
    bra mus_load_raw_next
mus_load_complete
    rts
mus_check_size
    ldd mus_song_size
    std mus_compare
    ldx mus_compare
    cpx #13
    bls mus_size_high_ok
    jmp mus_too_large
mus_size_high_ok
    bne mus_size_valid
    ldd mus_song_size+2
    std mus_compare
    ldx mus_compare
    cpx #$e000
    bls mus_size_valid
    jmp mus_too_large
mus_size_valid
    ldd mus_song_size
    bne mus_size_valid_return
    ldd mus_song_size+2
    std mus_compare
    ldx mus_compare
    cpx #4
    bcc mus_size_valid_return
    jmp mus_bad_file
mus_size_valid_return
    ; ceil(size/8192), bounded by the preceding 888 KiB check.
    ldd mus_song_size+2
    subd #1
    std mus_offset+2
    ldd mus_song_size
    sbcb #0
    sbca #0
    std mus_offset
    ldaa mus_offset+1
    asla
    asla
    asla
    ldab mus_offset+2
    lsrb
    lsrb
    lsrb
    lsrb
    lsrb
    aba
    inca
    tab
    ldx #mus_memory_lease
    ldaa #1
    int $e5
    tsta
    beq mus_claim_ready
    jmp mus_finish
mus_claim_ready
    clr mus_map_index
mus_claim_map
    ldab mus_map_index
    ldx #mus_memory_lease+3
    abx
    ldaa 0,x
    clrb
mus_claim_group
    cmpa #6
    bcs mus_claim_page
    suba #6
    incb
    bra mus_claim_group
mus_claim_page
    inca
    pshb
    ldab mus_map_index
    ldx #mus_bank_pages
    abx
    staa 0,x
    ldx #mus_bank_groups
    abx
    pulb
    stab 0,x
    inc mus_map_index
    ldaa mus_map_index
    cmpa mus_memory_lease+2
    bcs mus_claim_map
    rts
mus_oversized
    jmp mus_too_large
mus_file_invalid
    jmp mus_bad_file
; Native VTX AY parser, per V_Soft's VTX format and libayemu vtxfile.c.
; Little-endian fixed mus_header, five bounded strings, bare LH5 payload.
; No LHA wrapper/mus_crc exists in VTX. Reject truncated streams and sizes
; before playback; the decoded planar register block uses the YM engine.
; AY hardware plays a mono mix; the file's stereo order is mus_validated.
mus_load_vtx
    inc mus_vtx_mode
    ldx #mus_header+4
    stx mus_header_pointer
    ldaa #12
    staa mus_header_count
mus_vtx_header
    jsr mus_file_byte
    ldx mus_header_pointer
    staa 0,x
    inx
    stx mus_header_pointer
    dec mus_header_count
    bne mus_vtx_header
    ldaa mus_header+2
    cmpa #6
    bls mus_vtx_stereo_valid
    jmp mus_bad_file
mus_vtx_stereo_valid
    ldaa mus_header+4
    ldab mus_header+3
    std mus_loop_frame
    clra
    ldab mus_header+9
    beq mus_vtx_invalid
    cmpb #100
    bhi mus_vtx_invalid
    std mus_rate
    ldaa mus_header+8
    staa mus_header+22
    ldaa mus_header+7
    staa mus_header+23
    ldaa mus_header+6
    staa mus_header+24
    ldaa mus_header+5
    staa mus_header+25
    jsr mus_ym_clock
    ldaa mus_header+15
    ldab mus_header+14
    std mus_song_size
    ldaa mus_header+13
    ldab mus_header+12
    std mus_song_size+2
    jsr mus_check_size
    ldd mus_song_size
    std mus_division
    std mus_output_left
    ldd mus_song_size+2
    std mus_division+2
    std mus_output_left+2
    jsr mus_divide_fourteen
    ldd mus_division
    bne mus_vtx_invalid
    ldd mus_division+2
    beq mus_vtx_invalid
    std mus_frames
    ldaa #5
    staa mus_string_count
mus_vtx_string
    ldaa #255
    staa mus_header_count
mus_vtx_string_byte
    jsr mus_file_byte
    tsta
    beq mus_vtx_string_end
    dec mus_header_count
    bne mus_vtx_string_byte
mus_vtx_invalid
    jmp mus_bad_file
mus_vtx_string_end
    dec mus_string_count
    bne mus_vtx_string
    ldd mus_file_left
    std mus_packed_left
    ldd mus_file_left+2
    std mus_packed_left+2
    ; Same bounded streaming LH5 decoder as YM/LHA, no host conversion.
    jmp mus_lh5_start
mus_parse_vtx
    ldaa #1
    staa mus_kind
    staa mus_interleaved
    ldaa #14
    staa mus_stride
    ldd #0
    std mus_data_offset
    std mus_data_offset+2
    jmp mus_validate_ym

; Parse/validate the original file stored in SRAM. YM3b loop is little
; endian (StSound Ymload.cpp); YM5/6 numbers are big endian.
mus_parse_song
    tst mus_vtx_mode
    beq mus_parse_regular
    jmp mus_parse_vtx
mus_parse_regular
    jsr mus_memory_reset
    ldx #mus_header
    stx mus_header_pointer
    ldaa #4
    staa mus_header_count
    jsr mus_read_header
    ldx mus_header
    cpx #$5053
    bne mus_parse_ym
    ldx mus_header+2
    cpx #$471a
    beq ml_ymread_14
    jmp mus_format_bad
ml_ymread_14
    jmp mus_parse_psg
mus_parse_ym
    cpx #$594d
    beq ml_ymread_18
    jmp mus_format_bad
ml_ymread_18
    ldaa mus_header+2
    cmpa #'3'
    beq ml_ymread_21
    jmp mus_ym_later
ml_ymread_21
    ldaa mus_header+3
    cmpa #'!'
    beq mus_ym_three
    cmpa #'b'
    beq ml_ymread_26
    jmp mus_format_bad
ml_ymread_26
    inc mus_has_loop
mus_ym_three
    ldd #256
    std mus_clock_factor
    ldaa #1
    staa mus_interleaved
    staa mus_kind
    ldaa #14
    staa mus_stride
    ldd mus_song_size
    std mus_division
    ldd mus_song_size+2
    subd #4
    std mus_division+2
    ldd mus_division
    sbcb #0
    sbca #0
    std mus_division
    tst mus_has_loop
    beq mus_ym_three_count
    ldd mus_division+2
    subd #4
    std mus_division+2
    ldd mus_division
    sbcb #0
    sbca #0
    std mus_division
mus_ym_three_count
    jsr mus_divide_fourteen
    ldd mus_division
    beq ml_ymread_57
    jmp mus_format_bad
ml_ymread_57
    ldd mus_division+2
    std mus_frames
    bne ml_ymread_60
    jmp mus_format_bad
ml_ymread_60
    ldd #0
    std mus_data_offset
    ldd #4
    std mus_data_offset+2
    tst mus_has_loop
    bne ml_ymread_66
    jmp mus_validate_ym
ml_ymread_66
    ldd mus_song_size+2
    subd #4
    std mus_offset+2
    ldd mus_song_size
    sbcb #0
    sbca #0
    std mus_offset
    jsr mus_make_pointer
    ldd mus_computed
    std mus_read_pointer
    ldd mus_computed+2
    std mus_read_pointer+2
    ldd #0
    std mus_read_left
    ldd #4
    std mus_read_left+2
    jsr mus_memory_byte
    staa mus_loop_frame+1
    jsr mus_memory_byte
    staa mus_loop_frame
    jsr mus_memory_byte
    tsta
    beq ml_ymread_89
    jmp mus_format_bad
ml_ymread_89
    jsr mus_memory_byte
    tsta
    beq ml_ymread_92
    jmp mus_format_bad
ml_ymread_92
    jmp mus_validate_ym
mus_format_bad
    jmp mus_bad_file
mus_ym_later
    cmpa #'5'
    beq mus_ym_five_six
    cmpa #'6'
    beq ml_ymread_100
    jmp mus_format_bad
ml_ymread_100
mus_ym_five_six
    ldaa mus_header+3
    cmpa #'!'
    beq ml_ymread_104
    jmp mus_format_bad
ml_ymread_104
    ldaa #30
    staa mus_header_count
    jsr mus_read_header
    ldx mus_header+4
    cpx #$4c65
    beq ml_ymread_110
    jmp mus_format_bad
ml_ymread_110
    ldx mus_header+6
    cpx #$4f6e
    beq ml_ymread_113
    jmp mus_format_bad
ml_ymread_113
    ldx mus_header+8
    cpx #$4172
    beq ml_ymread_116
    jmp mus_format_bad
ml_ymread_116
    ldx mus_header+10
    cpx #$4421
    beq ml_ymread_119
    jmp mus_format_bad
ml_ymread_119
    ldd mus_header+12
    beq ml_ymread_121
    jmp mus_format_bad
ml_ymread_121
    ldd mus_header+14
    bne ml_ymread_123
    jmp mus_format_bad
ml_ymread_123
    std mus_frames
    ldd mus_header+16
    beq ml_ymread_126
    jmp mus_format_bad
ml_ymread_126
    tst mus_header+18
    beq ml_ymread_128
    jmp mus_format_bad
ml_ymread_128
    ldaa mus_header+19
    cmpa #7
    bls ml_ymread_131
    jmp mus_format_bad
ml_ymread_131
    anda #1
    staa mus_interleaved
    ldd mus_header+20
    beq mus_no_drums
    jmp mus_unsupported
mus_no_drums
    ldd mus_header+26
    bne ml_ymread_139
    jmp mus_format_bad
ml_ymread_139
    cpx #0
    std mus_rate
    ldx mus_rate
    cpx #100
    bls ml_ymread_144
    jmp mus_format_bad
ml_ymread_144
    ldd mus_header+28
    beq ml_ymread_146
    jmp mus_format_bad
ml_ymread_146
    ldd mus_header+30
    std mus_loop_frame
    jsr mus_ym_clock
    ldaa #16
    staa mus_stride
    ldaa #1
    staa mus_kind
    ldd mus_header+32
    std mus_skip_count
mus_skip_extra
    ldd mus_skip_count
    beq mus_strings_start
    subd #1
    std mus_skip_count
    jsr mus_memory_byte
    bra mus_skip_extra
mus_strings_start
    ldaa #3
    staa mus_string_count
mus_skip_string
    jsr mus_memory_byte
    tsta
    bne mus_skip_string
    dec mus_string_count
    bne mus_skip_string
    ldd mus_song_size+2
    subd mus_read_left+2
    std mus_data_offset+2
    ldd mus_song_size
    sbcb mus_read_left+1
    sbca mus_read_left
    std mus_data_offset
    ; Exactly mus_frames*16 plus End!, no unbounded arithmetic/trailing garbage.
    ldd mus_frames
    std mus_offset+2
    ldd #0
    std mus_offset
    ldaa #4
    staa mus_shift_count
mus_payload_shift
    asl mus_offset+3
    rol mus_offset+2
    rol mus_offset+1
    rol mus_offset
    dec mus_shift_count
    bne mus_payload_shift
    ldd mus_offset+2
    addd #4
    std mus_offset+2
    ldd mus_offset
    adcb #0
    adca #0
    std mus_offset
    ldx mus_offset
    cpx mus_read_left
    beq ml_ymread_202
    jmp mus_format_bad_jump
ml_ymread_202
    ldx mus_offset+2
    cpx mus_read_left+2
    beq ml_ymread_205
    jmp mus_format_bad_jump
ml_ymread_205
    ldd mus_song_size+2
    subd #4
    std mus_offset+2
    ldd mus_song_size
    sbcb #0
    sbca #0
    std mus_offset
    jsr mus_make_pointer
    ldd mus_computed
    std mus_read_pointer
    ldd mus_computed+2
    std mus_read_pointer+2
    ldd #0
    std mus_read_left
    ldd #4
    std mus_read_left+2
    ldx #mus_header
    stx mus_header_pointer
    ldaa #4
    staa mus_header_count
    jsr mus_read_header
    ldx mus_header
    cpx #$456e
    beq ml_ymread_229
    jmp mus_format_bad_jump
ml_ymread_229
    ldx mus_header+2
    cpx #$6421
    beq ml_ymread_232
    jmp mus_format_bad_jump
ml_ymread_232
mus_validate_ym
    ldx mus_loop_frame
    cpx mus_frames
    bcs ml_ymread_236
    jmp mus_format_bad_jump
ml_ymread_236
    ldaa mus_looping
    staa mus_saved_looping
    clr mus_looping
    jsr mus_ym_reset
mus_validate_next
    jsr mus_ym_frame
    tst mus_current_frame+1
    bne mus_validate_key_checked
    jsr mus_loading_key
mus_validate_key_checked
    tst mus_decode_status
    bne mus_validated
    tst mus_vtx_mode
    bne mus_validate_next
    ldaa mus_raw_frame+1
    oraa mus_raw_frame+3
    bita #$30
    beq mus_validate_next
    jmp mus_unsupported
mus_validated
    clr mus_decode_status
    ldaa mus_saved_looping
    staa mus_looping
    ldd #0
    std mus_current_frame
    jsr mus_ym_reset
    rts
mus_format_bad_jump
    jmp mus_bad_file
mus_read_header
    jsr mus_memory_byte
    ldx mus_header_pointer
    staa 0,x
    inx
    stx mus_header_pointer
    dec mus_header_count
    bne mus_read_header
    rts
mus_ym_clock
    ldx mus_header+22
    cpx #$001e
    bne mus_not_two_mhz
    ldx mus_header+24
    cpx #$8480
    beq ml_ymread_275
    jmp mus_clock_bad
ml_ymread_275
    ldd #256
    std mus_clock_factor
    rts
mus_not_two_mhz
    cpx #$000f
    bne mus_not_one_mhz
    ldx mus_header+24
    cpx #$4240
    beq ml_ymread_284
    jmp mus_clock_bad
ml_ymread_284
    ldd #512
    std mus_clock_factor
    rts
mus_not_one_mhz
    cpx #$001b
    beq ml_ymread_290
    jmp mus_clock_bad
ml_ymread_290
    ldx mus_header+24
    cpx #$0f58
    bne mus_not_spectrum_clock
    ldd #289
    std mus_clock_factor
    rts
mus_not_spectrum_clock
    cpx #$4f4d
    beq ml_ymread_299
    jmp mus_clock_bad
ml_ymread_299
    ldd #286
    std mus_clock_factor
    rts
mus_clock_bad
    jmp mus_bad_file
; Divide a 32-bit payload length by fourteen, requiring an exact quotient.
mus_divide_fourteen
    clr mus_remainder
    ldaa #32
    staa mus_shift_count
mus_divide_bit
    asl mus_division+3
    rol mus_division+2
    rol mus_division+1
    rol mus_division
    rol mus_remainder
    ldaa mus_remainder
    cmpa #14
    bcs mus_divide_next
    suba #14
    staa mus_remainder
    inc mus_division+3
mus_divide_next
    dec mus_shift_count
    bne mus_divide_bit
    tst mus_remainder
    beq ml_ymread_326
    jmp mus_clock_bad
ml_ymread_326
    rts
; Convert bounded linear mus_offset to a logical-bank/window address.
mus_make_pointer
    ldaa mus_offset+1
    asla
    asla
    asla
    ldab mus_offset+2
    lsrb
    lsrb
    lsrb
    lsrb
    lsrb
    aba
    staa mus_computed
    clr mus_computed+1
    ldaa mus_offset+2
    anda #31
    oraa #$c0
    staa mus_computed+2
    ldaa mus_offset+3
    staa mus_computed+3
    rts
mus_ym_reset
    ldd mus_data_offset
    std mus_offset
    ldd mus_data_offset+2
    addd mus_current_frame
    std mus_offset+2
    ldd mus_offset
    adcb #0
    adca #0
    std mus_offset
    tst mus_interleaved
    bne mus_pointer_base_ready
    ; For planar=0, frame index has a sixteen-byte mus_stride.
    ldd mus_current_frame
    std mus_seek_delta+2
    clr mus_seek_delta
    clr mus_seek_delta+1
    ldaa #4
    staa mus_shift_count
mus_seek_shift
    asl mus_seek_delta+3
    rol mus_seek_delta+2
    rol mus_seek_delta+1
    rol mus_seek_delta
    dec mus_shift_count
    bne mus_seek_shift
    ldd mus_data_offset+2
    addd mus_seek_delta+2
    std mus_offset+2
    ldd mus_data_offset
    adcb mus_seek_delta+1
    adca mus_seek_delta
    std mus_offset
mus_pointer_base_ready
    ldx #mus_ym_pointers
    stx mus_table_pointer
    ldaa #14
    staa mus_pointer_count
mus_pointer_next
    jsr mus_make_pointer
    ldx mus_table_pointer
    ldd mus_computed
    std 0,x
    ldd mus_computed+2
    std 2,x
    ldab #4
    abx
    stx mus_table_pointer
    ldd #1
    tst mus_interleaved
    beq mus_pointer_stride
    ldd mus_frames
mus_pointer_stride
    addd mus_offset+2
    std mus_offset+2
    ldd mus_offset
    adcb #0
    adca #0
    std mus_offset
    dec mus_pointer_count
    bne mus_pointer_next
    rts
mus_ym_frame
    ldx mus_current_frame
    cpx mus_frames
    bcs mus_ym_read_frame
    tst mus_looping
    bne ml_ymread_426
    jmp mus_song_ended
ml_ymread_426
    ldd mus_loop_frame
    std mus_current_frame
    jsr mus_ym_reset
mus_ym_read_frame
    ldx #mus_ym_pointers
    stx mus_table_pointer
    ldx #mus_raw_frame
    stx mus_output_pointer
    ldaa #14
    staa mus_pointer_count
mus_ym_register
    ldx mus_table_pointer
    jsr mus_mem_read
    psha
    tst mus_interleaved
    bne mus_ym_pointer_done
    ldd 2,x
    addd #15
    cmpa #$e0
    bcs mus_ym_stride_ready
    suba #$20
    inc 0,x
mus_ym_stride_ready
    std 2,x
mus_ym_pointer_done
    ldx mus_table_pointer
    ldab #4
    abx
    stx mus_table_pointer
    pula
    ldx mus_output_pointer
    staa 0,x
    inx
    stx mus_output_pointer
    dec mus_pointer_count
    bne mus_ym_register
    ldd mus_current_frame
    addd #1
    std mus_current_frame
    rts
mus_song_ended
    ldaa #1
    staa mus_decode_status
    rts

mus_parse_psg
    ldx #mus_header+4
    stx mus_header_pointer
    ldaa #12
    staa mus_header_count
    jsr mus_read_header
    ldaa mus_header+5
    bne mus_psg_rate
    ldaa #50
mus_psg_rate
    cmpa #50
    beq mus_psg_rate_ok
    cmpa #60
    beq ml_ymread_484
    jmp mus_clock_bad_jump
ml_ymread_484
mus_psg_rate_ok
    tab
    clra
    std mus_rate
    ldaa mus_looping
    staa mus_saved_looping
    clr mus_looping
    jsr mus_compact_psg
    jsr mus_psg_reset
mus_validate_psg
    jsr mus_psg_frame
    jsr mus_loading_key
    tst mus_decode_status
    beq mus_validate_psg
    ldaa mus_decode_status
    cmpa #1
    beq ml_ymread_499
    jmp mus_clock_bad_jump
ml_ymread_499
    ldaa mus_saved_looping
    staa mus_looping
    clr mus_decode_status
    jmp mus_psg_reset
mus_clock_bad_jump
    jmp mus_bad_file
mus_psg_reset
    jsr mus_memory_reset
    ldd #$c010
    std mus_read_pointer+2
    ldd mus_read_left+2
    subd #16
    std mus_read_left+2
    ldd mus_read_left
    sbcb #0
    sbca #0
    std mus_read_left
    bcc ml_ymread_517
    jmp mus_clock_bad_jump
ml_ymread_517
    ldd #0
    std mus_psg_delay
    ldx #mus_raw_frame
    ldaa #14
mus_psg_clear
    clr 0,x
    inx
    deca
    bne mus_psg_clear
    ldaa #$3f
    staa mus_raw_frame+7
    rts
mus_psg_frame
    ldaa #$ff
    staa mus_raw_frame+13
    ldd mus_psg_delay
    beq mus_psg_commands
    subd #1
    std mus_psg_delay
    rts
mus_psg_commands
    ldaa #64
    staa mus_command_budget
mus_psg_command
    ldd mus_read_left
    bne mus_psg_get_command
    ldd mus_read_left+2
    bne ml_ymread_545
    jmp mus_psg_end
ml_ymread_545
mus_psg_get_command
    jsr mus_memory_byte
    cmpa #$fd
    bne ml_ymread_549
    jmp mus_psg_end
ml_ymread_549
    cmpa #$ff
    beq mus_psg_return
    cmpa #$fe
    beq mus_psg_wait
    cmpa #16
    bcc mus_psg_invalid
    staa mus_psg_register
    ldd mus_read_left
    bne mus_psg_value
    ldd mus_read_left+2
    beq mus_psg_invalid
mus_psg_value
    jsr mus_memory_byte
    ldab mus_psg_register
    cmpb #14
    bcc mus_psg_next_command
    psha
    ldx #mus_raw_frame
    abx
    pula
    staa 0,x
mus_psg_next_command
    dec mus_command_budget
    bne mus_psg_command
mus_psg_invalid
    ldaa #2
    staa mus_decode_status
    rts
mus_psg_wait
    ldd mus_read_left
    bne mus_psg_wait_byte
    ldd mus_read_left+2
    beq mus_psg_invalid
mus_psg_wait_byte
    jsr mus_memory_byte
    tsta
    beq mus_psg_invalid
    tab
    clra
    asld
    asld
    subd #1
    std mus_psg_delay
mus_psg_return
    rts
mus_psg_end
    tst mus_looping
    beq mus_psg_finished
    jsr mus_psg_reset
    ; Avoid an empty file mus_looping forever with interrupts masked.
    tst mus_loop_guard
    bne mus_psg_invalid
    inc mus_loop_guard
    jsr mus_psg_commands
    clr mus_loop_guard
    rts
mus_psg_finished
    jmp mus_song_ended

; Collapse repeated register writes before buffered playback. This is in-place:
; each output frame has at most 14 pairs and never exceeds consumed input.
; Frame preparation stays bounded even for dense PSG logs at 1 MHz.
mus_compact_psg
    jsr mus_psg_reset
    ldd #0
    std mus_write_pointer
    ldd #$c010
    std mus_write_pointer+2
    ldd #0
    std mus_compact_size
    ldd #16
    std mus_compact_size+2
    jsr mus_compact_clear
mus_compact_next
    tst mus_read_pointer+3
    bne mus_compact_key_checked
    jsr mus_loading_key
mus_compact_key_checked
    ldd mus_read_left
    bne mus_compact_read
    ldd mus_read_left+2
    bne mus_compact_long_716
    jmp mus_compact_end
mus_compact_long_716
mus_compact_read
    jsr mus_memory_byte
    cmpa #$fd
    bne mus_compact_long_720
    jmp mus_compact_mark_end
mus_compact_long_720
    cmpa #$ff
    beq mus_compact_tick
    cmpa #$fe
    beq mus_compact_wait
    cmpa #16
    bcs mus_compact_long_726
    jmp mus_compact_bad
mus_compact_long_726
    staa mus_psg_register
    ldd mus_read_left
    bne mus_compact_value
    ldd mus_read_left+2
    bne mus_compact_long_731
    jmp mus_compact_bad
mus_compact_long_731
mus_compact_value
    jsr mus_memory_byte
    ldab mus_psg_register
    cmpb #14
    bcc mus_compact_next
    psha
    ldx #mus_raw_frame
    abx
    pula
    staa 0,x
    ldx #mus_compact_touched
    abx
    ldaa #1
    staa 0,x
    jmp mus_compact_next
mus_compact_tick
    jsr mus_compact_flush
    ldaa #$ff
    jsr mus_compact_emit
    jmp mus_compact_next
mus_compact_wait
    ldd mus_read_left
    bne mus_compact_delay_read
    ldd mus_read_left+2
    bne mus_compact_long_756
    jmp mus_compact_bad
mus_compact_long_756
mus_compact_delay_read
    jsr mus_memory_byte
    tsta
    bne mus_compact_long_760
    jmp mus_compact_bad
mus_compact_long_760
    staa mus_compact_delay
    jsr mus_compact_flush
    ldaa #$fe
    jsr mus_compact_emit
    ldaa mus_compact_delay
    jsr mus_compact_emit
    jmp mus_compact_next
mus_compact_bad
    jmp mus_bad_file
mus_compact_mark_end
    ldaa #$fd
    jsr mus_compact_emit
mus_compact_end
    ldd mus_compact_size
    std mus_song_size
    ldd mus_compact_size+2
    std mus_song_size+2
    rts
mus_compact_emit
    psha
    ldd mus_compact_size+2
    addd #1
    std mus_compact_size+2
    ldd mus_compact_size
    adcb #0
    adca #0
    std mus_compact_size
    pula
    jmp mus_mem_write
mus_compact_flush
    clr mus_compact_register
mus_compact_each
    ldx #mus_compact_touched
    ldab mus_compact_register
    abx
    tst 0,x
    beq mus_compact_skip
    clr 0,x
    ldaa mus_compact_register
    jsr mus_compact_emit
    ldx #mus_raw_frame
    ldab mus_compact_register
    abx
    ldaa 0,x
    jsr mus_compact_emit
mus_compact_skip
    inc mus_compact_register
    ldaa mus_compact_register
    cmpa #14
    bcs mus_compact_each
    rts
mus_compact_clear
    ldx #mus_compact_touched
    ldab #14
mus_compact_clear_next
    clr 0,x
    inx
    decb
    bne mus_compact_clear_next
    rts

; LHA level-0, -lh0- or -lh5-. Native streaming HD6303 decompression.
; Two temporary banks hold the 8-KiB dictionary and Huffman tables.
; Original mus_header checksum and CRC16 are checked before accepting the song.
mus_dictionary equ $c000
mus_c_lengths equ $c000
mus_pt_lengths equ $c1fe
mus_c_tree equ $c211
mus_pt_tree equ $c677
ml_claim
    ldaa #1
    ldab #2
    ldx #ml_lease
    int $e5
    tsta
    beq ml_maps
    jmp mus_finish
ml_maps
    clr mus_map_index
ml_map
    ldab mus_map_index
    ldx #ml_lease+3
    abx
    ldaa 0,x
    clrb
ml_group
    cmpa #6
    bcs ml_page
    suba #6
    incb
    bra ml_group
ml_page
    inca
    psha
    pshb
    ldab mus_map_index
    aslb
    ldx #ml_sel
    abx
    pulb
    stab 0,x
    pula
    staa 1,x
    inc mus_map_index
    ldaa mus_map_index
    cmpa #2
    bcs ml_map
    rts
ml_free
    tst ml_lease+2
    beq ml_freed
    ldaa #2
    ldx #ml_lease
    int $e5
ml_freed
    rts
ml_dic
    psha
    ldaa ml_sel
    staa mus_group
    ldaa ml_sel+1
    staa mus_page
    pula
    rts
ml_tab
    psha
    ldaa ml_sel+2
    staa mus_group
    ldaa ml_sel+3
    staa mus_page
    pula
    rts
mus_load_lha
    ldaa mus_header
    cmpa #22
    bcc mh6
    jmp mus_lha_bad
mh6
    suba #2
    staa mus_header_count
    ldx #mus_header+4
    stx mus_header_pointer
mus_lha_header_read
    jsr mus_file_byte
    ldx mus_header_pointer
    staa 0,x
    inx
    stx mus_header_pointer
    dec mus_header_count
    bne mus_lha_header_read
    ldx #mus_header+2
    ldaa mus_header
    staa mus_header_count
    clrb
mus_lha_header_sum
    addb 0,x
    inx
    dec mus_header_count
    bne mus_lha_header_sum
    cmpb mus_header+1
    beq mh29
    jmp mus_lha_bad
mh29
    ldaa mus_header+4
    cmpa #'h'
    beq mh32
    jmp mus_lha_bad
mh32
    ldaa mus_header+6
    cmpa #'-'
    beq mh35
    jmp mus_lha_bad
mh35
    tst mus_header+20
    beq mh37
    jmp mus_lha_bad
mh37
    ldaa mus_header+5
    cmpa #'0'
    beq mus_lha_method_ok
    cmpa #'5'
    beq mh42
    jmp mus_lha_bad
mh42
mus_lha_method_ok
    staa mus_lha_method
    clra
    ldab mus_header+21
    addd #22
    std mus_compare
    ldaa mus_header
    cmpa mus_compare+1
    bcc mh51
    jmp mus_lha_bad
mh51
    tst mus_compare
    beq mh53
    jmp mus_lha_bad
mh53
    ldx #mus_header+22
    ldab mus_header+21
    abx
    ldab 0,x
    ldaa 1,x
    std mus_expected_crc
    ldaa mus_header+14
    ldab mus_header+13
    std mus_song_size
    ldaa mus_header+12
    ldab mus_header+11
    std mus_song_size+2
    jsr mus_check_size
    ldd mus_song_size
    std mus_output_left
    ldd mus_song_size+2
    std mus_output_left+2
    ldaa mus_header+10
    ldab mus_header+9
    std mus_packed_left
    ldaa mus_header+8
    ldab mus_header+7
    std mus_packed_left+2
    ldx mus_packed_left
    cpx mus_file_left
    bls mh79
    jmp mus_lha_bad
mh79
    blo mus_packed_fits
    ldx mus_packed_left+2
    cpx mus_file_left+2
    bls mh83
    jmp mus_lha_bad
mh83
mus_packed_fits
    ldaa mus_lha_method
    cmpa #'5'
    beq mus_lh5_start
    ldx mus_packed_left
    cpx mus_song_size
    beq mh90
    jmp mus_lha_bad
mh90
    ldx mus_packed_left+2
    cpx mus_song_size+2
    beq mh93
    jmp mus_lha_bad
mh93
mus_lh0_next
    jsr mus_packed_byte
    jsr mus_lha_output
    jsr mus_output_remaining
    bne mus_lh0_next
    jmp mus_lha_check_crc
mus_lha_bad
    jmp mus_bad_file
mus_lh5_start
    jsr ml_claim
    jsr ml_dic
    ldx #mus_dictionary
    ldd #8192
    std mus_clear_left
    ldaa #32
mus_dictionary_clear
    staa 0,x
    inx
    psha
    ldd mus_clear_left
    subd #1
    std mus_clear_left
    pula
    bne mus_dictionary_clear
    jsr ml_tab
mus_lh5_next
    ldd mus_block_left
    bne mus_lh5_symbol
    ldaa #16
    jsr mus_get_bits
    std mus_block_left
    bne mh122
    jmp mus_lha_bad
mh122
    ldd #19
    std mus_tree_symbols
    ldaa #5
    staa mus_pt_bits
    ldaa #3
    staa mus_pt_special
    jsr mus_read_pt
    jsr mus_read_c
    ldd #14
    std mus_tree_symbols
    ldaa #4
    staa mus_pt_bits
    clr mus_pt_special
    jsr mus_read_pt
mus_lh5_symbol
    ldd mus_block_left
    subd #1
    std mus_block_left
    ldx #mus_c_tree
    jsr mus_decode_symbol
    tsta
    bne mus_lh5_match
    tba
    jsr mus_dictionary_output
    bra mus_lh5_continue
mus_lh5_match
    subd #253
    std mus_match_left
    ldx #mus_pt_tree
    jsr mus_decode_symbol
    stab mus_distance_bits
    tstb
    beq mus_distance_ready
    decb
    tba
    jsr mus_get_bits
    std mus_distance
    clra
    ldab mus_distance_bits
    decb
    asld
    addd #mus_distance_powers
    std mus_table_pointer
    ldx mus_table_pointer
    ldd 0,x
    addd mus_distance
mus_distance_ready
    addd #1
    std mus_distance
    ldd mus_dictionary_position
    subd mus_distance
    anda #31
    std mus_match_position
mus_match_next
    jsr ml_dic
    ldd mus_match_position
    addd #mus_dictionary
    std mus_table_pointer
    ldx mus_table_pointer
    ldaa 0,x
    jsr mus_dictionary_output
    ldd mus_match_position
    addd #1
    anda #31
    std mus_match_position
    ldd mus_match_left
    subd #1
    std mus_match_left
    bne mus_match_next
mus_lh5_continue
    jsr mus_output_remaining
    bne mh193
    jmp mus_lha_check_crc
mh193
    jmp mus_lh5_next
mus_lha_check_crc
    tst mus_vtx_mode
    beq mus_lha_has_crc
    rts
mus_lha_has_crc
    ldx mus_crc
    cpx mus_expected_crc
    beq mh198
    jmp mus_lha_bad
mh198
    rts
mus_output_remaining
    ldd mus_output_left
    bne mus_output_exists
    ldd mus_output_left+2
mus_output_exists
    rts
mus_dictionary_output
    psha
    jsr ml_dic
    ldd mus_dictionary_position
    addd #mus_dictionary
    std mus_table_pointer
    ldx mus_table_pointer
    pula
    staa 0,x
    psha
    ldd mus_dictionary_position
    addd #1
    anda #31
    std mus_dictionary_position
    tst mus_dictionary_position+1
    bne mus_dictionary_key_checked
    jsr mus_loading_key
mus_dictionary_key_checked
    pula
    jsr mus_lha_output
    jmp ml_tab
mus_lha_output
    psha
    jsr mus_output_remaining
    beq mus_output_overflow
    ldd mus_output_left+2
    subd #1
    std mus_output_left+2
    ldd mus_output_left
    sbcb #0
    sbca #0
    std mus_output_left
    pula
    psha
    eora mus_crc+1
    tab
    clra
    asld
    addd #mus_crc_table
    std mus_table_pointer
    ldx mus_table_pointer
    ldd 0,x
    eorb mus_crc
    std mus_crc
    pula
    jmp mus_mem_write
mus_output_overflow
    jmp mus_bad_file
mus_packed_byte
    ldd mus_packed_left
    bne mus_packed_exists
    ldd mus_packed_left+2
    bne mus_packed_exists
    jmp mus_bad_file
mus_packed_exists
    ldd mus_packed_left+2
    subd #1
    std mus_packed_left+2
    ldd mus_packed_left
    sbcb #0
    sbca #0
    std mus_packed_left
    jmp mus_file_byte
mus_get_bit
    tst mus_bits_left
    bne mus_bit_ready
    jsr mus_packed_byte
    staa mus_reservoir
    ldaa #8
    staa mus_bits_left
mus_bit_ready
    asl mus_reservoir
    dec mus_bits_left
    rts
mus_get_bits
    staa mus_bits_needed
    clr mus_bit_value
    clr mus_bit_value+1
    tsta
    beq mus_bits_done
mus_bits_next
    jsr mus_get_bit
    rol mus_bit_value+1
    rol mus_bit_value
    dec mus_bits_needed
    bne mus_bits_next
mus_bits_done
    ldd mus_bit_value
    rts

; Tree layout: constant flag/reserved/symbol, 17 counts, 17 first codes,
; 17 first symbol indices, then a sorted array of 16-bit symbol numbers.
mus_read_pt
    ldx #mus_pt_lengths
    ldd mus_tree_symbols
    std mus_clear_left
mus_pt_clear
    clr 0,x
    inx
    ldd mus_clear_left
    subd #1
    std mus_clear_left
    bne mus_pt_clear
    ldaa mus_pt_bits
    jsr mus_get_bits
    std mus_lengths_count
    ldx mus_lengths_count
    cpx mus_tree_symbols
    bls mh313
    jmp mus_tree_bad
mh313
    ldd #0
    std mus_length_index
    ldd mus_lengths_count
    bne mh317
    jmp mus_pt_constant
mh317
mus_pt_next
    ldaa #3
    jsr mus_get_bits
    stab mus_length_value
    cmpb #7
    bne mus_pt_length_ready
mus_pt_extended
    jsr mus_get_bit
    bcc mus_pt_length_ready
    inc mus_length_value
    ldaa mus_length_value
    cmpa #16
    bls mh330
    jmp mus_tree_bad
mh330
    bra mus_pt_extended
mus_pt_length_ready
    ldd #mus_pt_lengths
    addd mus_length_index
    std mus_length_pointer
    ldx mus_length_pointer
    ldaa mus_length_value
    staa 0,x
    ldd mus_length_index
    addd #1
    std mus_length_index
    tst mus_pt_special
    beq mus_pt_continue
    cmpb mus_pt_special
    bne mus_pt_continue
    ldaa #2
    jsr mus_get_bits
    addd mus_length_index
    std mus_length_index
mus_pt_continue
    ldx mus_length_index
    cpx mus_tree_symbols
    bls mus_pt_skip_fits
    jmp mus_tree_bad
mus_pt_skip_fits
    cpx mus_lengths_count
    blo mus_pt_next
    ldd #mus_pt_lengths
    std mus_lengths_base
    ldd #mus_pt_tree
    std mus_tree_base
    jmp mus_build_tree
mus_pt_constant
    ldaa mus_pt_bits
    jsr mus_get_bits
    std mus_pt_tree+2
    ldx mus_pt_tree+2
    cpx mus_tree_symbols
    bcs mh366
    jmp mus_tree_bad
mh366
    ldaa #1
    staa mus_pt_tree
    rts
mus_tree_bad
    jmp mus_bad_file
mus_read_c
    ldx #mus_c_lengths
    ldd #510
    std mus_clear_left
mus_c_clear
    clr 0,x
    inx
    ldd mus_clear_left
    subd #1
    std mus_clear_left
    bne mus_c_clear
    ldaa #9
    jsr mus_get_bits
    std mus_lengths_count
    ldx mus_lengths_count
    cpx #510
    bls mh388
    jmp mus_tree_bad
mh388
    ldd #0
    std mus_length_index
    ldd mus_lengths_count
    bne mh392
    jmp mus_c_constant
mh392
mus_c_next
    ldx #mus_pt_tree
    jsr mus_decode_symbol
    cmpb #2
    bls mus_c_zeroes
    subb #2
    stab mus_length_value
    ldd #mus_c_lengths
    addd mus_length_index
    std mus_length_pointer
    ldx mus_length_pointer
    ldaa mus_length_value
    staa 0,x
    ldd mus_length_index
    addd #1
    std mus_length_index
    bra mus_c_continue
mus_c_zeroes
    tstb
    beq mus_c_one_zero
    cmpb #1
    bne mus_c_long_zeroes
    ldaa #4
    jsr mus_get_bits
    addd #3
    bra mus_c_skip_zeroes
mus_c_long_zeroes
    ldaa #9
    jsr mus_get_bits
    addd #20
    bra mus_c_skip_zeroes
mus_c_one_zero
    ldd #1
mus_c_skip_zeroes
    addd mus_length_index
    std mus_length_index
mus_c_continue
    ldx mus_length_index
    cpx mus_lengths_count
    bls mh432
    jmp mus_tree_bad
mh432
    blo mus_c_next
    ldd #510
    std mus_tree_symbols
    ldd #mus_c_lengths
    std mus_lengths_base
    ldd #mus_c_tree
    std mus_tree_base
    jmp mus_build_tree
mus_c_constant
    ldaa #9
    jsr mus_get_bits
    std mus_c_tree+2
    ldx mus_c_tree+2
    cpx #510
    bcs mh447
    jmp mus_tree_bad
mh447
    ldaa #1
    staa mus_c_tree
    rts
mus_build_tree
    ldx mus_tree_base
    clr 0,x
    ldab #4
    abx
    ldab #102
mus_tree_clear
    clr 0,x
    inx
    decb
    bne mus_tree_clear
    ldd #0
    std mus_symbol_index
mus_count_length
    ldd mus_lengths_base
    addd mus_symbol_index
    std mus_length_pointer
    ldx mus_length_pointer
    ldab 0,x
    beq mus_next_length
    cmpb #16
    bls mh472
    jmp mus_tree_bad_jump
mh472
    clra
    asld
    addd mus_tree_base
    addd #4
    std mus_length_pointer
    ldx mus_length_pointer
    ldd 0,x
    addd #1
    std 0,x
mus_next_length
    ldd mus_symbol_index
    addd #1
    std mus_symbol_index
    ldx mus_symbol_index
    cpx mus_tree_symbols
    bcs mus_count_length
    ldd #0
    std mus_canonical_code
    std mus_canonical_index
    ldaa #2
    staa mus_length_offset
mus_canonical_next
    clra
    ldab mus_length_offset
    addd mus_tree_base
    std mus_length_pointer
    ldx mus_length_pointer
    ldd mus_canonical_code
    std 38,x
    ldd mus_canonical_index
    std 72,x
    addd 4,x
    std mus_canonical_index
    ldx mus_length_pointer
    ; Canonical codes use modulo 16 bits for unused lengths after a
    ; complete shorter tree. A separate Kraft check rejects bad tables.
    ldd mus_canonical_code
    addd 4,x
    asld
    std mus_canonical_code
    inc mus_length_offset
    inc mus_length_offset
    ldaa mus_length_offset
    cmpa #34
    bcs mus_canonical_next
    ldd #1
    std mus_canonical_code
    ldaa #2
    staa mus_length_offset
mus_kraft_next
    clra
    ldab mus_length_offset
    addd mus_tree_base
    std mus_length_pointer
    ldx mus_length_pointer
    ldd mus_canonical_code
    asld
    bcc mh530
    jmp mus_tree_bad_jump
mh530
    subd 4,x
    bcc mh532
    jmp mus_tree_bad_jump
mh532
    std mus_canonical_code
    inc mus_length_offset
    inc mus_length_offset
    ldaa mus_length_offset
    cmpa #34
    bcs mus_kraft_next
    ldd mus_canonical_code
    beq mh540
    jmp mus_tree_bad_jump
mh540
    ldx mus_canonical_index
    cpx mus_tree_symbols
    bls mh543
    jmp mus_tree_bad_jump
mh543
    ldd #0
    std mus_symbol_index
mus_sort_next
    ldd mus_lengths_base
    addd mus_symbol_index
    std mus_length_pointer
    ldx mus_length_pointer
    ldab 0,x
    beq mus_sort_continue
    clra
    asld
    addd mus_tree_base
    std mus_length_pointer
    ldx mus_length_pointer
    ldd 72,x
    asld
    addd mus_tree_base
    addd #106
    std mus_sort_pointer
    ldd 72,x
    addd #1
    std 72,x
    ldx mus_sort_pointer
    ldd mus_symbol_index
    std 0,x
mus_sort_continue
    ldd mus_symbol_index
    addd #1
    std mus_symbol_index
    ldx mus_symbol_index
    cpx mus_tree_symbols
    bcs mus_sort_next
    ; Restore first symbol indices after using them as insertion cursors.
    ldd #0
    std mus_canonical_index
    ldaa #2
    staa mus_length_offset
mus_restore_index
    clra
    ldab mus_length_offset
    addd mus_tree_base
    std mus_length_pointer
    ldx mus_length_pointer
    ldd mus_canonical_index
    std 72,x
    addd 4,x
    std mus_canonical_index
    inc mus_length_offset
    inc mus_length_offset
    ldaa mus_length_offset
    cmpa #34
    bcs mus_restore_index
    rts
mus_tree_bad_jump
    jmp mus_bad_file
mus_decode_symbol
    stx mus_decode_tree
    tst 0,x
    beq mus_decode_start
    ldd 2,x
    rts
mus_decode_start
    clr mus_decode_code
    clr mus_decode_code+1
    ldaa #2
    staa mus_decode_length
mus_decode_bit
    jsr mus_get_bit
    rol mus_decode_code+1
    rol mus_decode_code
    clra
    ldab mus_decode_length
    addd mus_decode_tree
    std mus_decode_pointer
    ldx mus_decode_pointer
    ldd mus_decode_code
    subd 38,x
    bcs mus_decode_more
    std mus_decode_delta
    ldd 4,x
    std mus_compare
    ldx mus_decode_delta
    cpx mus_compare
    bcc mus_decode_more
    ldx mus_decode_pointer
    ldd mus_decode_delta
    addd 72,x
    asld
    addd mus_decode_tree
    addd #106
    std mus_decode_pointer
    ldx mus_decode_pointer
    ldd 0,x
    rts
mus_decode_more
    inc mus_decode_length
    inc mus_decode_length
    ldaa mus_decode_length
    cmpa #34
    bcs mus_decode_bit
    jmp mus_bad_file
mus_distance_powers dw 1,2,4,8,16,32,64,128,256,512,1024,2048,4096
; CRC16/A001, initial zero: table[index] for eight LSB-first steps.
mus_crc_table
    dw $0000,$c0c1,$c181,$0140,$c301,$03c0,$0280,$c241
    dw $c601,$06c0,$0780,$c741,$0500,$c5c1,$c481,$0440
    dw $cc01,$0cc0,$0d80,$cd41,$0f00,$cfc1,$ce81,$0e40
    dw $0a00,$cac1,$cb81,$0b40,$c901,$09c0,$0880,$c841
    dw $d801,$18c0,$1980,$d941,$1b00,$dbc1,$da81,$1a40
    dw $1e00,$dec1,$df81,$1f40,$dd01,$1dc0,$1c80,$dc41
    dw $1400,$d4c1,$d581,$1540,$d701,$17c0,$1680,$d641
    dw $d201,$12c0,$1380,$d341,$1100,$d1c1,$d081,$1040
    dw $f001,$30c0,$3180,$f141,$3300,$f3c1,$f281,$3240
    dw $3600,$f6c1,$f781,$3740,$f501,$35c0,$3480,$f441
    dw $3c00,$fcc1,$fd81,$3d40,$ff01,$3fc0,$3e80,$fe41
    dw $fa01,$3ac0,$3b80,$fb41,$3900,$f9c1,$f881,$3840
    dw $2800,$e8c1,$e981,$2940,$eb01,$2bc0,$2a80,$ea41
    dw $ee01,$2ec0,$2f80,$ef41,$2d00,$edc1,$ec81,$2c40
    dw $e401,$24c0,$2580,$e541,$2700,$e7c1,$e681,$2640
    dw $2200,$e2c1,$e381,$2340,$e101,$21c0,$2080,$e041
    dw $a001,$60c0,$6180,$a141,$6300,$a3c1,$a281,$6240
    dw $6600,$a6c1,$a781,$6740,$a501,$65c0,$6480,$a441
    dw $6c00,$acc1,$ad81,$6d40,$af01,$6fc0,$6e80,$ae41
    dw $aa01,$6ac0,$6b80,$ab41,$6900,$a9c1,$a881,$6840
    dw $7800,$b8c1,$b981,$7940,$bb01,$7bc0,$7a80,$ba41
    dw $be01,$7ec0,$7f80,$bf41,$7d00,$bdc1,$bc81,$7c40
    dw $b401,$74c0,$7580,$b541,$7700,$b7c1,$b681,$7640
    dw $7200,$b2c1,$b381,$7340,$b101,$71c0,$7080,$b041
    dw $5000,$90c1,$9181,$5140,$9301,$53c0,$5280,$9241
    dw $9601,$56c0,$5780,$9741,$5500,$95c1,$9481,$5440
    dw $9c01,$5cc0,$5d80,$9d41,$5f00,$9fc1,$9e81,$5e40
    dw $5a00,$9ac1,$9b81,$5b40,$9901,$59c0,$5880,$9841
    dw $8801,$48c0,$4980,$8941,$4b00,$8bc1,$8a81,$4a40
    dw $4e00,$8ec1,$8f81,$4f40,$8d01,$4dc0,$4c80,$8c41
    dw $4400,$84c1,$8581,$4540,$8701,$47c0,$4680,$8641
    dw $8201,$42c0,$4380,$8341,$4100,$81c1,$8081,$4040
mus_timer_calculate
    ldd #$016e
    std mus_timer_period
    ldd #$3600
    std mus_timer_period+2
    ldd #0
    std mus_timer_remainder
    ldaa #32
    staa mus_shift_count
mus_timer_divide
    asl mus_timer_period+3
    rol mus_timer_period+2
    rol mus_timer_period+1
    rol mus_timer_period
    rol mus_timer_remainder+1
    rol mus_timer_remainder
    ldd mus_timer_remainder
    subd mus_rate
    bcs mus_timer_bit
    std mus_timer_remainder
    inc mus_timer_period+3
mus_timer_bit
    dec mus_shift_count
    bne mus_timer_divide
    ldd mus_timer_remainder
    asld
    subd mus_rate
    bcs mus_timer_ready
    inc mus_timer_period+3
    bne mus_timer_ready
    inc mus_timer_period+2
    bne mus_timer_ready
    inc mus_timer_period+1
    bne mus_timer_ready
    inc mus_timer_period
mus_timer_ready
    rts
