; LHA level-0, -lh0- or -lh5-. Native streaming HD6303 decompression.
; Canonical Huffman tables (no giant look-up tables), 8-KiB LZ dictionary.
; Original header checksum and CRC16 are checked before accepting the song.
load_lha
    ldaa header
    cmpa #22
    bcc long_lha5_6
    jmp lha_bad
long_lha5_6
    suba #2
    staa header_count
    ldx #header+4
    stx header_pointer
lha_header_read
    jsr file_byte
    ldx header_pointer
    staa 0,x
    inx
    stx header_pointer
    dec header_count
    bne lha_header_read
    ldx #header+2
    ldaa header
    staa header_count
    clrb
lha_header_sum
    addb 0,x
    inx
    dec header_count
    bne lha_header_sum
    cmpb header+1
    beq long_lha5_29
    jmp lha_bad
long_lha5_29
    ldaa header+4
    cmpa #'h'
    beq long_lha5_32
    jmp lha_bad
long_lha5_32
    ldaa header+6
    cmpa #'-'
    beq long_lha5_35
    jmp lha_bad
long_lha5_35
    tst header+20
    beq long_lha5_37
    jmp lha_bad
long_lha5_37
    ldaa header+5
    cmpa #'0'
    beq lha_method_ok
    cmpa #'5'
    beq long_lha5_42
    jmp lha_bad
long_lha5_42
lha_method_ok
    staa lha_method
    clra
    ldab header+21
    addd #22
    std compare
    ldaa header
    cmpa compare+1
    bcc long_lha5_51
    jmp lha_bad
long_lha5_51
    tst compare
    beq long_lha5_53
    jmp lha_bad
long_lha5_53
    ldx #header+22
    ldab header+21
    abx
    ldab 0,x
    ldaa 1,x
    std expected_crc
    ldaa header+14
    ldab header+13
    std song_size
    ldaa header+12
    ldab header+11
    std song_size+2
    jsr check_size
    ldd song_size
    std output_left
    ldd song_size+2
    std output_left+2
    ldaa header+10
    ldab header+9
    std packed_left
    ldaa header+8
    ldab header+7
    std packed_left+2
    ldx packed_left
    cpx file_left
    bls long_lha5_79
    jmp lha_bad
long_lha5_79
    blo packed_fits
    ldx packed_left+2
    cpx file_left+2
    bls long_lha5_83
    jmp lha_bad
long_lha5_83
packed_fits
    ldaa lha_method
    cmpa #'5'
    beq lh5_start
    ldx packed_left
    cpx song_size
    beq long_lha5_90
    jmp lha_bad
long_lha5_90
    ldx packed_left+2
    cpx song_size+2
    beq long_lha5_93
    jmp lha_bad
long_lha5_93
lh0_next
    jsr packed_byte
    jsr lha_output
    jsr output_remaining
    bne lh0_next
    jmp lha_check_crc
lha_bad
    jmp bad_file
lh5_start
    ldx #dictionary
    ldd #8192
    std clear_left
    ldaa #32
dictionary_clear
    staa 0,x
    inx
    psha
    ldd clear_left
    subd #1
    std clear_left
    pula
    bne dictionary_clear
lh5_next
    ldd block_left
    bne lh5_symbol
    ldaa #16
    jsr get_bits
    std block_left
    bne long_lha5_122
    jmp lha_bad
long_lha5_122
    ldd #19
    std tree_symbols
    ldaa #5
    staa pt_bits
    ldaa #3
    staa pt_special
    jsr read_pt
    jsr read_c
    ldd #14
    std tree_symbols
    ldaa #4
    staa pt_bits
    clr pt_special
    jsr read_pt
lh5_symbol
    ldd block_left
    subd #1
    std block_left
    ldx #c_tree
    jsr decode_symbol
    tsta
    bne lh5_match
    tba
    jsr dictionary_output
    bra lh5_continue
lh5_match
    subd #253
    std match_left
    ldx #pt_tree
    jsr decode_symbol
    stab distance_bits
    tstb
    beq distance_ready
    decb
    tba
    jsr get_bits
    std distance
    clra
    ldab distance_bits
    decb
    asld
    addd #distance_powers
    std table_pointer
    ldx table_pointer
    ldd 0,x
    addd distance
distance_ready
    addd #1
    std distance
    ldd dictionary_position
    subd distance
    anda #31
    std match_position
match_next
    ldd match_position
    addd #dictionary
    std table_pointer
    ldx table_pointer
    ldaa 0,x
    jsr dictionary_output
    ldd match_position
    addd #1
    anda #31
    std match_position
    ldd match_left
    subd #1
    std match_left
    bne match_next
lh5_continue
    jsr output_remaining
    bne long_lha5_193
    jmp lha_check_crc
long_lha5_193
    jmp lh5_next
lha_check_crc
    ldx crc
    cpx expected_crc
    beq long_lha5_198
    jmp lha_bad
long_lha5_198
    rts
output_remaining
    ldd output_left
    bne output_exists
    ldd output_left+2
output_exists
    rts
dictionary_output
    psha
    ldd dictionary_position
    addd #dictionary
    std table_pointer
    ldx table_pointer
    pula
    staa 0,x
    psha
    ldd dictionary_position
    addd #1
    anda #31
    std dictionary_position
    tst dictionary_position+1
    bne dictionary_key_checked
    jsr loading_key
dictionary_key_checked
    pula
lha_output
    psha
    jsr output_remaining
    beq output_overflow
    ldd output_left+2
    subd #1
    std output_left+2
    ldd output_left
    sbcb #0
    sbca #0
    std output_left
    pula
    psha
    eora crc+1
    tab
    clra
    asld
    addd #crc_table
    std table_pointer
    ldx table_pointer
    ldd 0,x
    eorb crc
    std crc
    pula
    jmp mem_write
output_overflow
    jmp bad_file
packed_byte
    ldd packed_left
    bne packed_exists
    ldd packed_left+2
    bne packed_exists
    jmp bad_file
packed_exists
    ldd packed_left+2
    subd #1
    std packed_left+2
    ldd packed_left
    sbcb #0
    sbca #0
    std packed_left
    jmp file_byte
get_bit
    tst bits_left
    bne bit_ready
    jsr packed_byte
    staa reservoir
    ldaa #8
    staa bits_left
bit_ready
    asl reservoir
    dec bits_left
    rts
get_bits
    staa bits_needed
    clr bit_value
    clr bit_value+1
    tsta
    beq bits_done
bits_next
    jsr get_bit
    rol bit_value+1
    rol bit_value
    dec bits_needed
    bne bits_next
bits_done
    ldd bit_value
    rts

; Tree layout: constant flag/reserved/symbol, 17 counts, 17 first codes,
; 17 first symbol indices, then a sorted array of 16-bit symbol numbers.
read_pt
    ldx #pt_lengths
    ldd tree_symbols
    std clear_left
pt_clear
    clr 0,x
    inx
    ldd clear_left
    subd #1
    std clear_left
    bne pt_clear
    ldaa pt_bits
    jsr get_bits
    std lengths_count
    ldx lengths_count
    cpx tree_symbols
    bls long_lha5_313
    jmp tree_bad
long_lha5_313
    ldd #0
    std length_index
    ldd lengths_count
    bne long_lha5_317
    jmp pt_constant
long_lha5_317
pt_next
    ldaa #3
    jsr get_bits
    stab length_value
    cmpb #7
    bne pt_length_ready
pt_extended
    jsr get_bit
    bcc pt_length_ready
    inc length_value
    ldaa length_value
    cmpa #16
    bls long_lha5_330
    jmp tree_bad
long_lha5_330
    bra pt_extended
pt_length_ready
    ldd #pt_lengths
    addd length_index
    std length_pointer
    ldx length_pointer
    ldaa length_value
    staa 0,x
    ldd length_index
    addd #1
    std length_index
    tst pt_special
    beq pt_continue
    cmpb pt_special
    bne pt_continue
    ldaa #2
    jsr get_bits
    addd length_index
    std length_index
pt_continue
    ldx length_index
    cpx tree_symbols
    bls pt_skip_fits
    jmp tree_bad
pt_skip_fits
    cpx lengths_count
    blo pt_next
    ldd #pt_lengths
    std lengths_base
    ldd #pt_tree
    std tree_base
    jmp build_tree
pt_constant
    ldaa pt_bits
    jsr get_bits
    std pt_tree+2
    ldx pt_tree+2
    cpx tree_symbols
    bcs long_lha5_366
    jmp tree_bad
long_lha5_366
    ldaa #1
    staa pt_tree
    rts
tree_bad
    jmp bad_file
read_c
    ldx #c_lengths
    ldd #510
    std clear_left
c_clear
    clr 0,x
    inx
    ldd clear_left
    subd #1
    std clear_left
    bne c_clear
    ldaa #9
    jsr get_bits
    std lengths_count
    ldx lengths_count
    cpx #510
    bls long_lha5_388
    jmp tree_bad
long_lha5_388
    ldd #0
    std length_index
    ldd lengths_count
    bne long_lha5_392
    jmp c_constant
long_lha5_392
c_next
    ldx #pt_tree
    jsr decode_symbol
    cmpb #2
    bls c_zeroes
    subb #2
    stab length_value
    ldd #c_lengths
    addd length_index
    std length_pointer
    ldx length_pointer
    ldaa length_value
    staa 0,x
    ldd length_index
    addd #1
    std length_index
    bra c_continue
c_zeroes
    tstb
    beq c_one_zero
    cmpb #1
    bne c_long_zeroes
    ldaa #4
    jsr get_bits
    addd #3
    bra c_skip_zeroes
c_long_zeroes
    ldaa #9
    jsr get_bits
    addd #20
    bra c_skip_zeroes
c_one_zero
    ldd #1
c_skip_zeroes
    addd length_index
    std length_index
c_continue
    ldx length_index
    cpx lengths_count
    bls long_lha5_432
    jmp tree_bad
long_lha5_432
    blo c_next
    ldd #510
    std tree_symbols
    ldd #c_lengths
    std lengths_base
    ldd #c_tree
    std tree_base
    jmp build_tree
c_constant
    ldaa #9
    jsr get_bits
    std c_tree+2
    ldx c_tree+2
    cpx #510
    bcs long_lha5_447
    jmp tree_bad
long_lha5_447
    ldaa #1
    staa c_tree
    rts
build_tree
    ldx tree_base
    clr 0,x
    ldab #4
    abx
    ldab #102
tree_clear
    clr 0,x
    inx
    decb
    bne tree_clear
    ldd #0
    std symbol_index
count_length
    ldd lengths_base
    addd symbol_index
    std length_pointer
    ldx length_pointer
    ldab 0,x
    beq next_length
    cmpb #16
    bls long_lha5_472
    jmp tree_bad_jump
long_lha5_472
    clra
    asld
    addd tree_base
    addd #4
    std length_pointer
    ldx length_pointer
    ldd 0,x
    addd #1
    std 0,x
next_length
    ldd symbol_index
    addd #1
    std symbol_index
    ldx symbol_index
    cpx tree_symbols
    bcs count_length
    ldd #0
    std canonical_code
    std canonical_index
    ldaa #2
    staa length_offset
canonical_next
    clra
    ldab length_offset
    addd tree_base
    std length_pointer
    ldx length_pointer
    ldd canonical_code
    std 38,x
    ldd canonical_index
    std 72,x
    addd 4,x
    std canonical_index
    ldx length_pointer
    ; Canonical codes use modulo 16 bits for unused lengths after a
    ; complete shorter tree. A separate Kraft check rejects bad tables.
    ldd canonical_code
    addd 4,x
    asld
    std canonical_code
    inc length_offset
    inc length_offset
    ldaa length_offset
    cmpa #34
    bcs canonical_next
    ldd #1
    std canonical_code
    ldaa #2
    staa length_offset
kraft_next
    clra
    ldab length_offset
    addd tree_base
    std length_pointer
    ldx length_pointer
    ldd canonical_code
    asld
    bcc long_lha5_530
    jmp tree_bad_jump
long_lha5_530
    subd 4,x
    bcc long_lha5_532
    jmp tree_bad_jump
long_lha5_532
    std canonical_code
    inc length_offset
    inc length_offset
    ldaa length_offset
    cmpa #34
    bcs kraft_next
    ldd canonical_code
    beq long_lha5_540
    jmp tree_bad_jump
long_lha5_540
    ldx canonical_index
    cpx tree_symbols
    bls long_lha5_543
    jmp tree_bad_jump
long_lha5_543
    ldd #0
    std symbol_index
sort_next
    ldd lengths_base
    addd symbol_index
    std length_pointer
    ldx length_pointer
    ldab 0,x
    beq sort_continue
    clra
    asld
    addd tree_base
    std length_pointer
    ldx length_pointer
    ldd 72,x
    asld
    addd tree_base
    addd #106
    std sort_pointer
    ldd 72,x
    addd #1
    std 72,x
    ldx sort_pointer
    ldd symbol_index
    std 0,x
sort_continue
    ldd symbol_index
    addd #1
    std symbol_index
    ldx symbol_index
    cpx tree_symbols
    bcs sort_next
    ; Restore first symbol indices after using them as insertion cursors.
    ldd #0
    std canonical_index
    ldaa #2
    staa length_offset
restore_index
    clra
    ldab length_offset
    addd tree_base
    std length_pointer
    ldx length_pointer
    ldd canonical_index
    std 72,x
    addd 4,x
    std canonical_index
    inc length_offset
    inc length_offset
    ldaa length_offset
    cmpa #34
    bcs restore_index
    rts
tree_bad_jump
    jmp bad_file
decode_symbol
    stx decode_tree
    tst 0,x
    beq decode_start
    ldd 2,x
    rts
decode_start
    clr decode_code
    clr decode_code+1
    ldaa #2
    staa decode_length
decode_bit
    jsr get_bit
    rol decode_code+1
    rol decode_code
    clra
    ldab decode_length
    addd decode_tree
    std decode_pointer
    ldx decode_pointer
    ldd decode_code
    subd 38,x
    bcs decode_more
    std decode_delta
    ldd 4,x
    std compare
    ldx decode_delta
    cpx compare
    bcc decode_more
    ldx decode_pointer
    ldd decode_delta
    addd 72,x
    asld
    addd decode_tree
    addd #106
    std decode_pointer
    ldx decode_pointer
    ldd 0,x
    rts
decode_more
    inc decode_length
    inc decode_length
    ldaa decode_length
    cmpa #34
    bcs decode_bit
    jmp bad_file
distance_powers dw 1,2,4,8,16,32,64,128,256,512,1024,2048,4096
    include CRCTABLE.INC
