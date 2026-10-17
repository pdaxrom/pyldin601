    .ifdef PNT_TOOLS
    .define PNT_EDIT
    .endif
; PCX v5: 1-bit planar (one to four planes), 2-bit packed, 8-bit indexed.
; Rows stream through ordinary bounded buffers; no full file is resident.
    public pcx_read
    public pcx_write
    extern io_get
    extern io_put
    extern io_read
    extern io_write
    extern io_seek
    extern io_count
    extern io_size
    extern io_limit
    extern io_error
    extern q_left
    extern q_right
    extern q_value
    extern q_sub
    extern p_row
    extern p_encoded
    extern p_palette
    extern p_kind
    extern p_width
    extern file_header
    extern file_config
    extern file_store
    extern file_fetch
    extern file_row
    extern paint_idle
    public pcx_bits
    section
pcx_bits ds 1
pcx_planes ds 1
pcx_bpl ds 2
pcx_total ds 2
pcx_width ds 2
pcx_groups ds 1
pcx_group ds 1
pcx_plane ds 1
pcx_plane_bit ds 1
pcx_source ds 2
pcx_dest ds 2
pcx_base ds 2
pcx_left ds 2
pcx_index ds 1
pcx_shift ds 1
pcx_bits_left ds 1
pcx_run ds 1
pcx_value ds 1
pcx_position ds 4
pcx_palette_end ds 4
pcx_temp ds 1
pcx_kind ds 1
    ends
    .ifndef PNT_EDIT
pcx_read
    ldx #128
    stx io_count
    ldx #file_header
    jsr io_read
    bcc *+5
    jmp pcx_return
    ldx #file_header
    ldaa 0,x
    cmpa #10
    beq *+5
    jmp pcx_bad
    ldaa 2,x
    cmpa #1
    beq *+5
    jmp pcx_bad
    ldaa 3,x
    staa pcx_bits
    ldaa 65,x
    staa pcx_planes
    ldaa 66,x
    ldab 67,x
    staa pcx_bpl+1
    stab pcx_bpl
    ; Dimensions must match a supported complete canvas, starting at 0,0.
    ldaa 4,x
    oraa 5,x
    oraa 6,x
    oraa 7,x
    beq *+5
    jmp pcx_bad
    ldaa 10,x
    cmpa #199
    beq *+5
    jmp pcx_bad
    tst 11,x
    beq *+5
    jmp pcx_bad
    ldaa 8,x
    adda #1
    staa pcx_width+1
    ldaa 9,x
    adca #0
    staa pcx_width
    ldx pcx_width
    cpx #320
    beq pcx_width_ok
    cpx #640
    beq *+5
    jmp pcx_bad
    ldaa pcx_bits
    cmpa #1
    beq *+5
    jmp pcx_bad
    ldaa pcx_planes
    cmpa #1
    beq *+5
    jmp pcx_bad
pcx_width_ok
    ldaa pcx_bits
    cmpa #1
    beq pcx_planar
    cmpa #2
    beq pcx_two
    cmpa #8
    beq *+5
    jmp pcx_bad
    ldaa pcx_planes
    cmpa #1
    beq *+5
    jmp pcx_bad
    ldaa #3
    ldx #320
    bra pcx_format
pcx_two
    ldaa pcx_planes
    cmpa #1
    beq *+5
    jmp pcx_bad
    ldaa #2
    ldx #80
    bra pcx_format
pcx_planar
    ldaa pcx_planes
    bne *+5
    jmp pcx_bad
    cmpa #5
    bcs *+5
    jmp pcx_bad
    ldaa #3
    ldab pcx_planes
    cmpb #2
    bhi pcx_narrow_planar
    ldaa #2
    cmpb #1
    bne pcx_narrow_planar
    ldaa #0
pcx_narrow_planar
    ldx #40
    ; Width high is 1 for 320 and 2 for 640.
    ldaa pcx_width
    cmpa #2
    bne pcx_planar_kind
    ldaa #1
    ldx #80
    bra pcx_format
pcx_planar_kind
    ldaa #0
    ldab pcx_planes
    cmpb #1
    beq pcx_format
    ldaa #2
    cmpb #2
    beq pcx_format
    ldaa #3
pcx_format
    staa pcx_kind
    stx pcx_total
    ldaa pcx_bpl
    cmpa pcx_total
    bcc *+5
    jmp pcx_bad
    bhi pcx_bpl_valid
    ldaa pcx_bpl+1
    cmpa pcx_total+1
    bcc *+5
    jmp pcx_bad
pcx_bpl_valid
    ldx #0
    stx pcx_total
    ldab pcx_planes
pcx_add_plane
    ldaa pcx_total+1
    adda pcx_bpl+1
    staa pcx_total+1
    ldaa pcx_total
    adca pcx_bpl
    staa pcx_total
    bcc *+5
    jmp pcx_bad
    decb
    bne pcx_add_plane
    ldaa pcx_total
    cmpa #2
    bcs pcx_total_valid
    beq *+5
    jmp pcx_bad
    ldaa pcx_total+1
    cmpa #129
    bcs *+5
    jmp pcx_bad
pcx_total_valid
    jsr pcx_palette
    tsta
    beq *+5
    jmp pcx_return
    ldaa pcx_kind
    jsr file_config
    tsta
    beq *+5
    jmp pcx_return
    clr pcx_position
    clr pcx_position+1
    clr pcx_position+2
    ldaa #128
    staa pcx_position+3
    ldx #pcx_position
    jsr io_seek
    bcc *+5
    jmp pcx_return
    clr pcx_run
    clr file_row
pcx_read_row
    ldx #p_encoded
    stx pcx_dest
    ldx pcx_total
    stx pcx_left
pcx_rle_byte
    tst pcx_run
    bne pcx_run_byte
    jsr io_get
    bcc *+5
    jmp pcx_return
    staa pcx_value
    anda #$c0
    cmpa #$c0
    bne pcx_literal
    ldaa pcx_value
    anda #63
    bne *+5
    jmp pcx_bad
    staa pcx_run
    jsr io_get
    bcc *+5
    jmp pcx_return
    staa pcx_value
    bra pcx_run_byte
pcx_literal
    inc pcx_run
pcx_run_byte
    dec pcx_run
    ldx pcx_dest
    ldaa pcx_value
    staa 0,x
    inx
    stx pcx_dest
    ldx pcx_left
    dex
    stx pcx_left
    bne pcx_rle_byte
    jsr pcx_unpack
    ldaa file_row
    jsr file_store
    tsta
    beq *+5
    jmp pcx_return
    inc file_row
    ldaa file_row
    cmpa #200
    bne pcx_read_row
    tst pcx_run
    beq *+5
    jmp pcx_bad
    clra
pcx_return
    rts
pcx_bad
    ldaa #65
    staa io_error
    rts
pcx_palette
    ldx #p_palette
    stx pcx_dest
    ldx #768
    stx pcx_left
pcx_palette_zero
    ldx pcx_dest
    clr 0,x
    inx
    stx pcx_dest
    ldx pcx_left
    dex
    stx pcx_left
    bne pcx_palette_zero
    ldx #p_palette
    stx pcx_dest
    ldaa pcx_bits
    cmpa #8
    beq pcx_large_palette
    ldx #file_header
    ldab #16
pcx_header_palette
    inx
    decb
    bne pcx_header_palette
    stx pcx_source
    ldaa #48
    staa pcx_index
pcx_small_colour
    ldx pcx_source
    ldaa 0,x
    inx
    stx pcx_source
    lsra
    lsra
    ldx pcx_dest
    staa 0,x
    inx
    stx pcx_dest
    dec pcx_index
    bne pcx_small_colour
    clra
    rts
pcx_large_palette
    ldx #io_size
    stx q_left
    ldx #palette_suffix
    stx q_right
    jsr q_sub
    bcc *+5
    jmp pcx_bad
    ldx #q_value
    ldaa 0,x
    ldab 1,x
    staa pcx_palette_end
    stab pcx_palette_end+1
    ldaa 2,x
    ldab 3,x
    staa pcx_palette_end+2
    stab pcx_palette_end+3
    ldx #pcx_palette_end
    jsr io_seek
    bcc *+5
    jmp pcx_return
    jsr io_get
    bcc *+5
    jmp pcx_return
    cmpa #12
    beq *+5
    jmp pcx_bad
    ldx #768
    stx pcx_left
pcx_large_colour
    jsr io_get
    bcc *+5
    jmp pcx_return
    lsra
    lsra
    ldx pcx_dest
    staa 0,x
    inx
    stx pcx_dest
    ldx pcx_left
    dex
    stx pcx_left
    bne pcx_large_colour
    ldx #io_limit
    ldaa pcx_palette_end
    ldab pcx_palette_end+1
    staa 0,x
    stab 1,x
    ldaa pcx_palette_end+2
    ldab pcx_palette_end+3
    staa 2,x
    stab 3,x
    clra
    rts
pcx_unpack
    ldx #p_encoded
    stx pcx_source
    ldx #p_row
    stx pcx_dest
    ldaa pcx_bits
    cmpa #8
    bne *+5
    jmp pcx_copy_indices
    cmpa #2
    bne *+5
    jmp pcx_unpack_two
    ldx pcx_width
    stx pcx_left
pcx_clear_row
    ldx pcx_dest
    clr 0,x
    inx
    stx pcx_dest
    ldx pcx_left
    dex
    stx pcx_left
    bne pcx_clear_row
    clr pcx_plane
    ldaa #1
    staa pcx_plane_bit
    ldaa pcx_width+1
    ldab pcx_width
    lsrb
    rora
    lsrb
    rora
    lsrb
    rora
    staa pcx_groups
pcx_unpack_plane
    ldx pcx_source
    stx pcx_base
    ldx #p_row
    stx pcx_dest
    ldaa pcx_groups
    staa pcx_group
pcx_unpack_group
    ldx pcx_source
    ldaa 0,x
    staa pcx_shift
    inx
    stx pcx_source
    ldaa #8
    staa pcx_bits_left
pcx_unpack_bit
    ldx pcx_dest
    asl pcx_shift
    bcc pcx_unpack_zero
    ldaa 0,x
    oraa pcx_plane_bit
    staa 0,x
pcx_unpack_zero
    inx
    stx pcx_dest
    dec pcx_bits_left
    bne pcx_unpack_bit
    jsr paint_idle
    dec pcx_group
    bne pcx_unpack_group
    ldaa pcx_base+1
    adda pcx_bpl+1
    staa pcx_source+1
    ldaa pcx_base
    adca pcx_bpl
    staa pcx_source
    asl pcx_plane_bit
    inc pcx_plane
    ldaa pcx_plane
    cmpa pcx_planes
    bne pcx_unpack_plane
    rts
pcx_copy_indices
    ldx pcx_width
    stx pcx_left
pcx_copy_next
    ldx pcx_source
    ldaa 0,x
    inx
    stx pcx_source
    ldx pcx_dest
    staa 0,x
    inx
    stx pcx_dest
    ldx pcx_left
    dex
    stx pcx_left
    bne pcx_copy_next
    rts
pcx_unpack_two
    ldaa #80
    staa pcx_group
pcx_two_group
    ldx pcx_source
    ldaa 0,x
    staa pcx_shift
    inx
    stx pcx_source
    ldaa #4
    staa pcx_bits_left
pcx_two_pixel
    ldaa pcx_shift
    lsra
    lsra
    lsra
    lsra
    lsra
    lsra
    ldx pcx_dest
    staa 0,x
    inx
    stx pcx_dest
    asl pcx_shift
    asl pcx_shift
    dec pcx_bits_left
    bne pcx_two_pixel
    jsr paint_idle
    dec pcx_group
    bne pcx_two_group
    rts
; Save 1bpp mono, 1bpp x2 planar four colours, or 8bpp indexed.
pcx_write
    ldx #file_header
    ldab #128
pcx_write_clear
    clr 0,x
    inx
    decb
    bne pcx_write_clear
    ldx #file_header
    ldaa #10
    staa 0,x
    ldaa #5
    staa 1,x
    ldaa #1
    staa 2,x
    staa 3,x
    staa 65,x
    staa 68,x
    staa pcx_planes
    staa pcx_bits
    ldaa p_kind
    cmpa #3
    beq pcx_write_indexed
    cmpa #2
    bne pcx_write_mono
    ldaa #2
    staa 65,x
    staa pcx_planes
pcx_write_mono
    ldx #p_width
    ldaa 1,x
    ldab 0,x
    lsrb
    rora
    lsrb
    rora
    lsrb
    rora
    staa pcx_bpl+1
    clr pcx_bpl
    bra pcx_write_dimensions
pcx_write_indexed
    ldaa #8
    staa pcx_bits
    ldx #320
    stx pcx_bpl
pcx_write_dimensions
    ldx p_width
    stx pcx_width
    dex
    stx pcx_left
    ldx #file_header
    ldaa pcx_left+1
    staa 8,x
    ldaa pcx_left
    staa 9,x
    ldaa #199
    staa 10,x
    ldaa pcx_bpl+1
    staa 66,x
    ldaa pcx_bpl
    staa 67,x
    ldaa pcx_bits
    staa 3,x
    ldx #file_header
    ldab #16
pcx_write_palette_start
    inx
    decb
    bne pcx_write_palette_start
    stx pcx_dest
    ldx #p_palette
    stx pcx_source
    ldaa #48
    staa pcx_index
pcx_write_palette
    ldx pcx_source
    ldaa 0,x
    jsr pcx_expand
    ldx pcx_dest
    staa 0,x
    inx
    stx pcx_dest
    ldx pcx_source
    inx
    stx pcx_source
    dec pcx_index
    bne pcx_write_palette
    ldx #128
    stx io_count
    ldx #file_header
    jsr io_write
    bcc *+5
    jmp pcx_return
    clr file_row
pcx_write_row
    ldaa file_row
    jsr file_fetch
    tsta
    beq *+5
    jmp pcx_return
    ldaa pcx_bits
    cmpa #8
    beq pcx_rle_indices
    jsr pcx_pack
    ldx #p_encoded
    stx pcx_source
    ldx pcx_bpl
    stx pcx_left
    ldaa pcx_planes
    cmpa #2
    bne pcx_rle_start
    asl pcx_left+1
    rol pcx_left
    bra pcx_rle_start
pcx_rle_indices
    ldx #p_row
    stx pcx_source
    ldx #320
    stx pcx_left
pcx_rle_start
    jsr pcx_rle_write
    tsta
    beq *+5
    jmp pcx_return
    inc file_row
    ldaa file_row
    cmpa #200
    bne pcx_write_row
    ldaa pcx_bits
    cmpa #8
    beq pcx_write_trailer
    clra
    rts
pcx_write_trailer
    ldaa #12
    jsr io_put
    bcc *+5
    jmp pcx_return
    ldx #p_palette
    stx pcx_source
    ldx #768
    stx pcx_left
pcx_trailer_byte
    ldx pcx_source
    ldaa 0,x
    jsr pcx_expand
    jsr io_put
    bcc *+5
    jmp pcx_return
    ldx pcx_source
    inx
    stx pcx_source
    ldx pcx_left
    dex
    stx pcx_left
    bne pcx_trailer_byte
    clra
    rts
pcx_expand
    staa pcx_temp
    asla
    asla
    staa pcx_value
    ldaa pcx_temp
    lsra
    lsra
    lsra
    lsra
    oraa pcx_value
    rts
pcx_pack
    ldx #p_encoded
    stx pcx_dest
    clr pcx_plane
    ldaa #1
    staa pcx_plane_bit
pcx_pack_plane
    ldx #p_row
    stx pcx_source
    ldaa pcx_bpl+1
    staa pcx_group
pcx_pack_group
    clr pcx_shift
    ldaa #8
    staa pcx_bits_left
pcx_pack_bit
    asl pcx_shift
    ldx pcx_source
    ldaa 0,x
    bita pcx_plane_bit
    beq pcx_pack_zero
    inc pcx_shift
pcx_pack_zero
    inx
    stx pcx_source
    dec pcx_bits_left
    bne pcx_pack_bit
    ldx pcx_dest
    ldaa pcx_shift
    staa 0,x
    inx
    stx pcx_dest
    jsr paint_idle
    dec pcx_group
    bne pcx_pack_group
    asl pcx_plane_bit
    inc pcx_plane
    ldaa pcx_plane
    cmpa pcx_planes
    bne pcx_pack_plane
    rts
pcx_rle_write
    ldx pcx_source
    ldaa 0,x
    staa pcx_value
    ldaa #1
    staa pcx_run
    inx
    stx pcx_source
    ldx pcx_left
    dex
    stx pcx_left
pcx_rle_extend
    ldx pcx_left
    cpx #0
    beq pcx_rle_emit
    ldaa pcx_run
    cmpa #63
    bcc pcx_rle_emit
    ldx pcx_source
    ldaa 0,x
    cmpa pcx_value
    bne pcx_rle_emit
    inx
    stx pcx_source
    ldx pcx_left
    dex
    stx pcx_left
    inc pcx_run
    bra pcx_rle_extend
pcx_rle_emit
    ldaa pcx_run
    cmpa #1
    bne pcx_rle_prefix
    ldaa pcx_value
    anda #$c0
    cmpa #$c0
    bne pcx_rle_literal
pcx_rle_prefix
    ldaa pcx_run
    oraa #$c0
    jsr io_put
    bcc *+5
    jmp pcx_return
pcx_rle_literal
    ldaa pcx_value
    jsr io_put
    bcc *+5
    jmp pcx_return
    ldx pcx_left
    cpx #0
    bne pcx_rle_write
    clra
    rts
palette_suffix db 0,0,3,1
    .else
pcx_read
pcx_write
    ldaa #65
    rts
    .endif
    end
