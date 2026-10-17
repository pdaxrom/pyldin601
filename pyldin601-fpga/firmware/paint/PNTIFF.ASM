    .ifdef PNT_TOOLS
    .define PNT_EDIT
    .endif
; HAM8 ILBM: arbitrary 64-colour CMAP, eight bitplanes, raw or ByteRun1.
; Canonical RGB666 is decoded row by row; export encodes the visible HAM row.
    public iff_read
    public iff_write
    extern io_get
    extern io_put
    extern io_read
    extern io_write
    extern io_seek
    extern io_count
    extern io_position
    extern io_size
    extern io_limit
    extern io_error
    extern io_cancel
    extern q_left
    extern q_right
    extern q_value
    extern q_add
    extern q_sub
    extern q_compare
    extern p_row
    extern p_encoded
    extern p_palette
    extern file_header
    extern file_config
    extern file_store
    extern file_fetch
    extern file_row
    extern backend_encode
    extern paint_idle
    public iff_form_end
    section
iff_form_end ds 4
iff_chunk_end ds 4
iff_chunk_next ds 4
iff_body ds 4
iff_body_end ds 4
iff_bmhd ds 1
iff_cmap ds 1
iff_camg ds 1
iff_body_seen ds 1
iff_compressed ds 1
iff_source ds 2
iff_dest ds 2
iff_copy_src ds 2
iff_count ds 2
iff_run ds 1
iff_repeat ds 1
iff_value ds 1
iff_index ds 1
iff_offset ds 1
iff_mask ds 1
iff_plane ds 1
iff_command ds 1
iff_scan ds 2
iff_rgb ds 3
iff_pixels ds 2
iff_group ds 1
iff_bits ds 1
iff_shift ds 1
    ends
    .ifndef PNT_EDIT
iff_copy
    stx iff_copy_src
    ldaa 0,x
    ldab 1,x
    ldx iff_dest
    staa 0,x
    stab 1,x
    ldx iff_copy_src
    ldaa 2,x
    ldab 3,x
    ldx iff_dest
    staa 2,x
    stab 3,x
    rts
iff_read
    clr iff_bmhd
    clr iff_cmap
    clr iff_camg
    clr iff_body_seen
    ldx #12
    stx io_count
    ldx #file_header
    jsr io_read
    bcc *+5
    jmp iff_return
    ldx #file_header
    ldx 0,x
    cpx #$464f
    beq *+5
    jmp iff_bad
    ldx #file_header
    ldx 2,x
    cpx #$524d
    beq *+5
    jmp iff_bad
    ldx #file_header
    ldx 8,x
    cpx #$494c
    beq *+5
    jmp iff_bad
    ldx #file_header
    ldx 10,x
    cpx #$424d
    beq *+5
    jmp iff_bad
    jsr iff_length_ptr
    stx q_left
    ldx #iff_eight
    stx q_right
    jsr q_add
    bcc *+5
    jmp iff_bad
    ldx #iff_form_end
    stx iff_dest
    ldx #q_value
    jsr iff_copy
    ldx #iff_form_end
    stx q_left
    ldx #io_size
    stx q_right
    jsr q_compare
    bls *+5
    jmp iff_bad
    ldx #io_limit
    stx iff_dest
    ldx #iff_form_end
    jsr iff_copy
    ldx #iff_twelve
    jsr io_seek
    bcc *+5
    jmp iff_return
iff_scan_chunk
    ldx #io_position
    stx q_left
    ldx #iff_form_end
    stx q_right
    jsr q_compare
    bne *+5
    jmp iff_metadata_done
    bls *+5
    jmp iff_bad
    ldx #8
    stx io_count
    ldx #file_header
    jsr io_read
    bcc *+5
    jmp iff_return
    jsr iff_length_ptr
    stx q_right
    ldx #io_position
    stx q_left
    jsr q_add
    bcc *+5
    jmp iff_bad
    ldx #iff_chunk_end
    stx iff_dest
    ldx #q_value
    jsr iff_copy
    ldx #iff_chunk_next
    stx iff_dest
    ldx #q_value
    jsr iff_copy
    ldaa iff_chunk_next+3
    bita #1
    beq iff_chunk_aligned
    inc iff_chunk_next+3
    bne iff_chunk_aligned
    inc iff_chunk_next+2
    bne iff_chunk_aligned
    inc iff_chunk_next+1
    bne iff_chunk_aligned
    inc iff_chunk_next
    bne *+5
    jmp iff_bad
iff_chunk_aligned
    ldx #iff_chunk_next
    stx q_left
    ldx #iff_form_end
    stx q_right
    jsr q_compare
    bls *+5
    jmp iff_bad
    ldx #file_header
    ldx 0,x
    cpx #$424d
    beq iff_chunk_bm
    cpx #$434d
    beq iff_chunk_cm
    cpx #$4341
    beq iff_chunk_ca
    cpx #$424f
    beq iff_chunk_bo
    bra iff_next
iff_chunk_bm
    ldx #file_header
    ldx 2,x
    cpx #$4844
    bne iff_next
    jsr iff_read_bmhd
    bra iff_chunk_result
iff_chunk_cm
    ldx #file_header
    ldx 2,x
    cpx #$4150
    bne iff_next
    jsr iff_read_cmap
    bra iff_chunk_result
iff_chunk_ca
    ldx #file_header
    ldx 2,x
    cpx #$4d47
    bne iff_next
    jsr iff_read_camg
    bra iff_chunk_result
iff_chunk_bo
    ldx #file_header
    ldx 2,x
    cpx #$4459
    bne iff_next
    tst iff_body_seen
    beq *+5
    jmp iff_bad
    inc iff_body_seen
    ldx #iff_body
    stx iff_dest
    ldx #io_position
    jsr iff_copy
    ldx #iff_body_end
    stx iff_dest
    ldx #iff_chunk_end
    jsr iff_copy
    bra iff_next
iff_chunk_result
    tsta
    beq *+5
    jmp iff_return
iff_next
    ldx #iff_chunk_next
    jsr io_seek
    bcc *+5
    jmp iff_return
    jsr io_cancel
    tsta
    beq *+5
    jmp iff_return
    jmp iff_scan_chunk
iff_metadata_done
    tst iff_bmhd
    bne *+5
    jmp iff_bad
    tst iff_cmap
    bne *+5
    jmp iff_bad
    tst iff_camg
    bne *+5
    jmp iff_bad
    tst iff_body_seen
    bne *+5
    jmp iff_bad
    ldx #iff_body_end
    stx q_left
    ldx #iff_body
    stx q_right
    jsr q_sub
    ldx #q_value
    tst 0,x
    beq *+5
    jmp iff_bad
    ldaa 1,x
    cmpa #4
    bcs *+5
    jmp iff_bad
    tst iff_compressed
    bne iff_body_size_ok
    tst 1,x
    beq *+5
    jmp iff_bad
    ldx 2,x
    cpx #64000
    beq *+5
    jmp iff_bad
iff_body_size_ok
    ldaa #4
    jsr file_config
    tsta
    beq *+5
    jmp iff_return
    ldx #io_limit
    stx iff_dest
    ldx #iff_body_end
    jsr iff_copy
    ldx #iff_body
    jsr io_seek
    bcc *+5
    jmp iff_return
    clr file_row
iff_read_row
    tst iff_compressed
    bne iff_read_rle
    ldx #320
    stx io_count
    ldx #p_encoded
    jsr io_read
    bcc *+5
    jmp iff_return
    bra iff_read_decode
iff_read_rle
    jsr iff_byterun
    tsta
    beq *+5
    jmp iff_return
iff_read_decode
    jsr iff_decode
    ldaa file_row
    jsr file_store
    tsta
    beq *+5
    jmp iff_return
    inc file_row
    ldaa file_row
    cmpa #200
    bne iff_read_row
    ldx #io_position
    stx q_left
    ldx #iff_body_end
    stx q_right
    jsr q_compare
    beq *+5
    jmp iff_bad
    clra
iff_return
    rts
iff_bad
    ldaa #65
    staa io_error
    rts
iff_length_ptr
    ldx #file_header
    inx
    inx
    inx
    inx
    rts
; A=min required payload size; the full chunk extent was already checked.
iff_minimum
    staa iff_value
    ldx #iff_chunk_end
    stx q_left
    ldx #io_position
    stx q_right
    jsr q_sub
    ldx #q_value
    ldaa 0,x
    oraa 1,x
    oraa 2,x
    bne iff_minimum_ok
    ldaa 3,x
    cmpa iff_value
    bcc *+5
    jmp iff_bad
iff_minimum_ok
    clra
    rts
iff_read_bmhd
    ldaa #20
    jsr iff_minimum
    tsta
    beq *+5
    jmp iff_return
    ldx #20
    stx io_count
    ldx #file_header
    jsr io_read
    bcc *+5
    jmp iff_return
    ldx #file_header
    ldx 0,x
    cpx #320
    beq *+5
    jmp iff_bad
    ldx #file_header
    ldx 2,x
    cpx #200
    beq *+5
    jmp iff_bad
    ldx #file_header
    ldaa 8,x
    cmpa #8
    beq *+5
    jmp iff_bad
    tst 9,x
    beq *+5
    jmp iff_bad
    ldaa 10,x
    cmpa #2
    bcs *+5
    jmp iff_bad
    staa iff_compressed
    inc iff_bmhd
    clra
    rts
iff_read_camg
    ldaa #4
    jsr iff_minimum
    tsta
    beq *+5
    jmp iff_return
    ldx #4
    stx io_count
    ldx #file_header
    jsr io_read
    bcc *+5
    jmp iff_return
    ldx #file_header
    ldaa 2,x
    anda #8
    staa iff_camg
    clra
    rts
iff_read_cmap
    ldaa #192
    jsr iff_minimum
    tsta
    beq *+5
    jmp iff_return
    ldx #p_palette
    stx iff_dest
    ldx #768
    stx iff_count
iff_palette_clear
    ldx iff_dest
    clr 0,x
    inx
    stx iff_dest
    ldx iff_count
    dex
    stx iff_count
    bne iff_palette_clear
    ldx #p_palette
    stx iff_dest
    ldaa #192
    staa iff_run
iff_palette_byte
    jsr io_get
    bcc *+5
    jmp iff_return
    lsra
    lsra
    ldx iff_dest
    staa 0,x
    inx
    stx iff_dest
    dec iff_run
    bne iff_palette_byte
    inc iff_cmap
    clra
    rts
iff_byterun
    ldx #320
    stx iff_count
    ldx #p_encoded
    stx iff_dest
iff_control
    jsr io_get
    bcc *+5
    jmp iff_return
    cmpa #128
    beq iff_noop
    bcs iff_literal_control
    ldab #1
    stab iff_repeat
    nega
    bra iff_literals
iff_literal_control
    clr iff_repeat
iff_literals
    inca
    staa iff_run
    tst iff_count
    bne iff_run_size_ok
    cmpa iff_count+1
    bls *+5
    jmp iff_bad
iff_run_size_ok
    tst iff_repeat
    beq iff_run_byte
    jsr io_get
    bcc *+5
    jmp iff_return
    staa iff_value
iff_run_byte
    tst iff_repeat
    bne iff_repeat_byte
    jsr io_get
    bcc *+5
    jmp iff_return
    bra iff_store_byte
iff_repeat_byte
    ldaa iff_value
iff_store_byte
    ldx iff_dest
    staa 0,x
    inx
    stx iff_dest
    ldx iff_count
    dex
    stx iff_count
    dec iff_run
    bne iff_run_byte
    cpx #0
    beq iff_line_complete
iff_noop
    jsr io_cancel
    tsta
    beq *+5
    jmp iff_return
    jsr paint_idle
    bra iff_control
iff_line_complete
    clra
    rts
; Reconstruct a HAM command from its eight planes, then expand RGB forward.
iff_decode
    clr iff_offset
    ldaa #$80
    staa iff_mask
    clr iff_rgb
    clr iff_rgb+1
    clr iff_rgb+2
    ldx #320
    stx iff_pixels
    ldx #p_row
    stx iff_dest
iff_decode_pixel
    ldx #p_encoded
    stx iff_scan
    ldaa iff_scan+1
    adda iff_offset
    staa iff_scan+1
    bcc iff_scan_ready
    inc iff_scan
iff_scan_ready
    clr iff_command
    ldaa #1
    staa iff_plane
iff_decode_plane
    ldx iff_scan
    ldaa 0,x
    bita iff_mask
    beq iff_plane_zero
    ldaa iff_command
    oraa iff_plane
    staa iff_command
iff_plane_zero
    ldaa iff_scan+1
    adda #40
    staa iff_scan+1
    bcc iff_next_plane
    inc iff_scan
iff_next_plane
    asl iff_plane
    bne iff_decode_plane
    ldaa iff_command
    cmpa #64
    bcc iff_modify
    staa iff_value
    asla
    adda iff_value
    staa iff_value
    ldx #p_palette
    stx iff_source
    ldaa iff_source+1
    adda iff_value
    staa iff_source+1
    bcc iff_base_ready
    inc iff_source
iff_base_ready
    ldx iff_source
    ldaa 0,x
    ldab 1,x
    staa iff_rgb
    stab iff_rgb+1
    ldaa 2,x
    staa iff_rgb+2
    bra iff_rgb_ready
iff_modify
    anda #63
    staa iff_value
    ldaa iff_command
    anda #$c0
    cmpa #$40
    beq iff_blue
    cmpa #$80
    beq iff_red
    ldaa iff_value
    staa iff_rgb+1
    bra iff_rgb_ready
iff_blue
    ldaa iff_value
    staa iff_rgb+2
    bra iff_rgb_ready
iff_red
    ldaa iff_value
    staa iff_rgb
iff_rgb_ready
    ldx iff_dest
    ldaa iff_rgb
    ldab iff_rgb+1
    staa 0,x
    stab 1,x
    ldaa iff_rgb+2
    staa 2,x
    inx
    inx
    inx
    stx iff_dest
    lsr iff_mask
    bne iff_pixel_next
    ldaa #$80
    staa iff_mask
    inc iff_offset
    jsr paint_idle
iff_pixel_next
    ldx iff_pixels
    dex
    stx iff_pixels
    beq *+5
    jmp iff_decode_pixel
    rts
iff_write
    ldx #48
    stx io_count
    ldx #iff_header
    jsr io_write
    bcc *+5
    jmp iff_return
    clr iff_index
iff_cmap_write
    ldaa iff_index
    lsra
    lsra
    lsra
    lsra
    jsr iff_level
    jsr io_put
    bcc *+5
    jmp iff_return
    ldaa iff_index
    lsra
    lsra
    jsr iff_level
    jsr io_put
    bcc *+5
    jmp iff_return
    ldaa iff_index
    jsr iff_level
    jsr io_put
    bcc *+5
    jmp iff_return
    inc iff_index
    ldaa iff_index
    cmpa #64
    bne iff_cmap_write
    ldx #20
    stx io_count
    ldx #iff_footer
    jsr io_write
    bcc *+5
    jmp iff_return
    clr file_row
iff_write_row
    ldaa file_row
    jsr file_fetch
    tsta
    beq *+5
    jmp iff_return
    jsr backend_encode
    tsta
    beq *+5
    jmp iff_return
    jsr iff_pack
    ldx #320
    stx io_count
    ldx #p_row
    jsr io_write
    bcc *+5
    jmp iff_return
    inc file_row
    ldaa file_row
    cmpa #200
    bne iff_write_row
    clra
    rts
iff_level
    anda #3
    tab
    ldx #iff_levels
iff_level_offset
    tstb
    beq iff_level_ready
    inx
    decb
    bra iff_level_offset
iff_level_ready
    ldaa 0,x
    rts
iff_pack
    ldx #p_row
    stx iff_dest
    ldaa #1
    staa iff_plane
iff_pack_plane
    ldx #p_encoded
    stx iff_source
    ldaa #40
    staa iff_group
iff_pack_group
    clr iff_shift
    ldaa #8
    staa iff_bits
iff_pack_bit
    asl iff_shift
    ldx iff_source
    ldaa 0,x
    bita iff_plane
    beq iff_pack_zero
    inc iff_shift
iff_pack_zero
    inx
    stx iff_source
    dec iff_bits
    bne iff_pack_bit
    ldx iff_dest
    ldaa iff_shift
    staa 0,x
    inx
    stx iff_dest
    jsr paint_idle
    dec iff_group
    bne iff_pack_group
    asl iff_plane
    bne iff_pack_plane
    rts
iff_eight db 0,0,0,8
iff_twelve db 0,0,0,12
iff_levels db 0,85,170,255
iff_header
    db 'FORM'
    dw 0,64252
    db 'ILBM','BMHD'
    dw 0,20,320,200,0,0
    db 8,0,0,0
    dw 0
    db 1,1
    dw 320,200
    db 'CMAP'
    dw 0,192
iff_footer
    db 'CAMG'
    dw 0,4,0,$0800
    db 'BODY'
    dw 0,64000
    .else
iff_read
iff_write
    ldaa #65
    rts
    .endif
    end
