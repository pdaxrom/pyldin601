; Native VTX AY parser, per V_Soft's VTX format and libayemu vtxfile.c.
; Little-endian fixed header, five bounded strings, bare LH5 payload.
; No LHA wrapper/CRC exists in VTX. Reject truncated streams and sizes
; before playback; the decoded planar register block uses the YM engine.
; AY hardware plays a mono mix; the file's stereo order is validated.
load_vtx
    inc vtx_mode
    ldx #header+4
    stx header_pointer
    ldaa #12
    staa header_count
vtx_header
    jsr file_byte
    ldx header_pointer
    staa 0,x
    inx
    stx header_pointer
    dec header_count
    bne vtx_header
    ldaa header+2
    cmpa #6
    bls vtx_stereo_valid
    jmp bad_file
vtx_stereo_valid
    ldaa header+4
    ldab header+3
    std loop_frame
    clra
    ldab header+9
    beq vtx_invalid
    cmpb #100
    bhi vtx_invalid
    std rate
    ldaa header+8
    staa header+22
    ldaa header+7
    staa header+23
    ldaa header+6
    staa header+24
    ldaa header+5
    staa header+25
    jsr ym_clock
    ldaa header+15
    ldab header+14
    std song_size
    ldaa header+13
    ldab header+12
    std song_size+2
    jsr check_size
    ldd song_size
    std division
    std output_left
    ldd song_size+2
    std division+2
    std output_left+2
    jsr divide_fourteen
    ldd division
    bne vtx_invalid
    ldd division+2
    beq vtx_invalid
    std frames
    ldaa #5
    staa string_count
vtx_string
    ldaa #255
    staa header_count
vtx_string_byte
    jsr file_byte
    tsta
    beq vtx_string_end
    dec header_count
    bne vtx_string_byte
vtx_invalid
    jmp bad_file
vtx_string_end
    dec string_count
    bne vtx_string
    ldd file_left
    std packed_left
    ldd file_left+2
    std packed_left+2
    ; Same bounded streaming LH5 decoder as YM/LHA, no host conversion.
    jmp lh5_start
parse_vtx
    ldaa #1
    staa kind
    staa interleaved
    ldaa #14
    staa stride
    ldd #0
    std data_offset
    std data_offset+2
    jmp validate_ym
