; Command front end. All arithmetic is LE32; no private partition table.
ui_start
    ldaa #1
    staa ui_base
    ldaa argc
    cmpa #2
    bcc ui_option
    jmp usage
ui_option
    ldaa #1
    jsr argument
    ldx #ui_hex_name
    stx pat
    ldx #argtext
    jsr match
    bcs ui_device
    inc ui_hex
    inc ui_base
    ldaa argc
    cmpa #3
    bcc ui_device
    jmp usage
ui_device
    ldaa ui_base
    jsr argument
    ldx #sd_name
    stx pat
    ldx #argtext
    jsr match
    bcc ui_device_ready
    jmp usage
ui_device_ready
    ldx #capacity
    clra
    int $e2
    tsta
    beq ui_operation
    jmp finish_result
ui_operation
    ldaa ui_base
    inca
    staa ui_op
    cmpa argc
    bne ui_operation_token
    jmp list_begin
ui_operation_token
    jsr argument
    ldx #list_name
    stx pat
    ldx #argtext
    jsr match
    bcs ui_dispatch_add
    ldaa ui_op
    inca
    cmpa argc
    beq ui_list_ready
    jmp usage
ui_list_ready
    jmp list_begin
ui_dispatch_add
    ldx #ui_add_name
    stx pat
    ldx #argtext
    jsr match
    bcs ui_dispatch_del
    jmp ui_add
ui_dispatch_del
    ldx #ui_del_name
    stx pat
    ldx #argtext
    jsr match
    bcs ui_legacy
    jmp ui_del
ui_legacy
    tst ui_hex
    beq ui_legacy_ready
    jmp usage
ui_legacy_ready
    jmp fd_operation
ui_del
    ldaa ui_op
    adda #2
    cmpa argc
    beq ui_del_argument
    jmp usage
ui_del_argument
    deca
    jsr argument
    ldx #argtext
    ldaa 0,x
    cmpa #'P'
    bne ui_del_bad
    ldaa 1,x
    cmpa #'A'
    bne ui_del_bad
    ldaa 2,x
    cmpa #'R'
    bne ui_del_bad
    ldaa 3,x
    cmpa #'T'
    bne ui_del_bad
    inx
    inx
    inx
    inx
    jsr ui_integer
    bcs ui_del_bad
    ldaa number+1
    oraa number+2
    oraa number+3
    bne ui_del_bad
    ldaa number
    beq ui_del_bad
    cmpa #36
    bhi ui_del_bad
    staa target
    jmp delete_argument
ui_del_bad
    jmp usage
ui_add
    ldaa #1
    staa kind
    ldaa ui_op
    inca
    staa ui_arg
    cmpa argc
    bcs ui_add_token
    jmp usage
ui_add_token
    jsr argument
    ldx #logical_name
    stx pat
    ldx #argtext
    jsr match
    bcs ui_add_range
    inc logical
    inc ui_arg
    ldaa ui_arg
    cmpa argc
    bcs ui_add_logical_range
    jmp usage
ui_add_logical_range
    jsr argument
ui_add_range
    ldx #argtext
    ldaa 0,x
    cmpa #'+'
    bne ui_add_explicit
    inx
    jsr ui_size_token
    bcc ui_add_size
    jmp ui_bad_number
ui_add_explicit
    inc ui_explicit
    jsr ui_integer
    bcc ui_add_begin
    jmp ui_bad_number
ui_add_begin
    ldx #ui_begin
    stx pat
    ldx #number
    jsr ui_copy4
    inc ui_arg
    ldaa ui_arg
    cmpa argc
    bcs ui_add_end_token
    jmp usage
ui_add_end_token
    jsr argument
    ldx #argtext
    jsr ui_integer
    bcc ui_add_end
    jmp ui_bad_number
ui_add_end
    ; User's end sector is inclusive; editor bounds are exclusive.
    ldx #number
    stx ptr
    ldx #ui_begin
    stx pat
    jsr ui_compare4
    bcc ui_add_end_order
    jmp ui_bad_number
ui_add_end_order
    ldx #ui_one
    stx pat
    jsr ui_add4
    bcc ui_add_end_valid
    jmp ui_bad_number
ui_add_end_valid
    ldx #ui_end
    stx pat
    ldx #number
    jsr ui_copy4
    ldx #number
    stx ptr
    ldx #ui_begin
    stx pat
    jsr ui_sub4
ui_add_size
    ldaa number
    oraa number+1
    oraa number+2
    oraa number+3
    bne ui_add_size_valid
    jmp ui_bad_number
ui_add_size_valid
    ldx #ui_size
    stx pat
    ldx #number
    jsr ui_copy4
    inc ui_arg
    ldaa ui_arg
    cmpa argc
    beq ui_add_type_done
    inca
    cmpa argc
    beq ui_add_type_token
    jmp usage
ui_add_type_token
    ldaa ui_arg
    jsr argument
    ldx #ui_fat12_name
    stx pat
    ldx #argtext
    jsr match
    bcc ui_add_type_done
    ldx #ui_fat16_name
    stx pat
    ldx #argtext
    jsr match
    bcs ui_add_type_extended
    ldaa #$0e
    staa kind
    bra ui_add_type_done
ui_add_type_extended
    ldx #extended_name
    stx pat
    ldx #argtext
    jsr match
    bcs ui_add_type_raw
    ldaa #$0f
    staa kind
    bra ui_add_type_done
ui_add_type_raw
    ldx #argtext
    jsr ui_integer
    bcc ui_add_type_byte
    jmp usage
ui_add_type_byte
    ldaa number+1
    oraa number+2
    oraa number+3
    beq ui_add_type_low
    jmp usage
ui_add_type_low
    ldaa number
    bne ui_add_type_store
    jmp usage
ui_add_type_store
    staa kind
ui_add_type_done
    ldaa kind
    jsr extended_type
    bne ui_add_type_normal
    ldaa #$0f
    staa kind
ui_add_type_normal
    ldaa kind
    staa ui_kind
    jsr ui_layout
    jsr ui_allocate
    tst ui_make_ext
    beq ui_add_commit
    ; Create the container through the same bounds/rollback path, then its
    ; first logical volume. Only this intermediate editor call returns.
    ldx #first
    stx pat
    ldx #ebr
    jsr ui_copy4
    ldx #number
    stx pat
    ldx #ui_end
    jsr ui_copy4
    ldx #number
    stx ptr
    ldx #ebr
    stx pat
    jsr ui_sub4
    ldaa #$0f
    staa kind
    clr logical
    inc ui_return
    jsr create_bounds
    clr ui_return
    tsta
    beq ui_add_container_ready
    jmp finish_result
ui_add_container_ready
    ldaa #1
    staa logical
ui_add_commit
    inc ui_added
    ldaa ui_kind
    staa kind
    ldx #first
    stx pat
    ldx #ui_begin
    jsr ui_copy4
    ldx #number
    stx pat
    ldx #ui_size
    jsr ui_copy4
    jmp create_bounds
ui_finish
    tsta
    bne ui_finish_normal
    tst ui_added
    beq ui_finish_normal
    clr index
ui_added_record
    jsr get_record
    tsta
    bne ui_added_missing
    ldaa record+9
    cmpa ui_kind
    bne ui_added_next
    ldaa record
    eora ui_begin
    staa ui_diff
    ldaa record+1
    eora ui_begin+1
    oraa ui_diff
    staa ui_diff
    ldaa record+2
    eora ui_begin+2
    oraa ui_diff
    staa ui_diff
    ldaa record+3
    eora ui_begin+3
    oraa ui_diff
    bne ui_added_next
    ldx #ok_msg
    int $23
    ldx #ui_added_msg
    int $23
    ldaa record+8
    staa ui_part_out
    clr ui_part_out+1
    clr ui_part_out+2
    clr ui_part_out+3
    ldx #ui_part_out
    jsr ui_print32
    ldx #newline
    int $23
    int $38
ui_added_next
    inc index
    bra ui_added_record
ui_added_missing
    clra
ui_finish_normal
    jmp finish_result
ui_bad_number
    ldx #ui_bad_number_msg
    int $23
    int $38
ui_no_space
    ldx #ui_no_space_msg
    int $23
    int $38
ui_no_slot
    ldx #ui_no_slot_msg
    int $23
    int $38
ui_full
    ldx #ui_full_msg
    int $23
    int $38
; Decimal or explicitly prefixed hexadecimal, checked unsigned LE32.
ui_integer
    ldaa 0,x
    cmpa #'0'
    bne ui_integer_decimal
    ldaa 1,x
    cmpa #'X'
    beq ui_integer_hex
ui_integer_decimal
    jmp parse_decimal
ui_integer_hex
    inx
    inx
    stx ptr
    clr number
    clr number+1
    clr number+2
    clr number+3
    clr digits
ui_hex_digit
    ldx ptr
    ldaa 0,x
    beq ui_hex_done
    cmpa #'0'
    bcs ui_integer_bad
    cmpa #'9'
    bls ui_hex_decimal_digit
    cmpa #'A'
    bcs ui_integer_bad
    cmpa #'F'
    bhi ui_integer_bad
    suba #'A'-10
    bra ui_hex_value
ui_hex_decimal_digit
    suba #'0'
ui_hex_value
    staa digit
    inx
    stx ptr
    inc digits
    ldab #4
ui_hex_shift
    asl number
    rol number+1
    rol number+2
    rol number+3
    bcs ui_integer_bad
    decb
    bne ui_hex_shift
    ldaa number
    oraa digit
    staa number
    bra ui_hex_digit
ui_hex_done
    tst digits
    beq ui_integer_bad
    clc
    rts
ui_integer_bad
    sec
    rts
; +integer[K|M|G], K by default. Shift directly into sectors to avoid a
; 32-bit byte-size ceiling: G means 2^21 sectors, not 2^30 byte arithmetic.
ui_size_token
    stx ui_token_ptr
    ldaa #1
    staa ui_shift
ui_size_tail
    ldaa 0,x
    beq ui_size_suffix
    inx
    bra ui_size_tail
ui_size_suffix
    dex
    ldaa 0,x
    cmpa #'K'
    beq ui_size_cut
    cmpa #'M'
    bne ui_size_g
    ldaa #11
    staa ui_shift
    bra ui_size_cut
ui_size_g
    cmpa #'G'
    bne ui_size_parse
    ldaa #21
    staa ui_shift
ui_size_cut
    clr 0,x
ui_size_parse
    ldx ui_token_ptr
    jsr ui_integer
    bcs ui_size_done
ui_size_shift
    asl number
    rol number+1
    rol number+2
    rol number+3
    bcs ui_integer_bad
    dec ui_shift
    bne ui_size_shift
    clc
ui_size_done
    rts
ui_copy4
    stx ptr
    ldab #4
ui_copy_byte
    ldx ptr
    ldaa 0,x
    inx
    stx ptr
    ldx pat
    staa 0,x
    inx
    stx pat
    decb
    bne ui_copy_byte
    rts
ui_hex_name db "/HEX",0
ui_add_name db "ADD",0
ui_del_name db "DEL",0
ui_fat12_name db "FAT12",0
ui_fat16_name db "FAT16",0
ui_bad_number_msg db "Invalid sector or size.",13,10,0
ui_no_space_msg db "No free range for this size.",13,10,0
ui_no_slot_msg db "No free primary slot or extended container.",13,10,0
ui_full_msg db "Partition table full (32 records).",13,10,0
ui_added_msg db "Added SD0:PART",0
ui_base db 0
ui_op db 0
ui_arg db 0
ui_hex db 0
ui_explicit db 0
ui_make_ext db 0
ui_return db 0
ui_added db 0
ui_kind db 0
ui_primary db 0
ui_extpart db 0
ui_records db 0
ui_shift db 0
ui_token_ptr dw 0
ui_print_ptr dw 0
ui_size ds 4
ui_part_out ds 4
ui_begin ds 4
ui_end ds 4
ui_candidate ds 4
ui_limit ds 4
ui_range_end ds 4
ui_extbase ds 4
ui_extend ds 4
ui_table ds 4
ui_next ds 4
ui_reuse db 0
ui_tables db 0
ui_one db 1,0,0,0
ui_gap db 0,8,0,0
