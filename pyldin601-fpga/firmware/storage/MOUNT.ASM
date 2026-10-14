start
    .ifdef FORMAT_TOOL
    ldaa #12
    staa fs_type
    int $3b
    staa argc
    cmpa #2
    beq plain
    cmpa #3
    beq with_type
    jmp usage
with_type
    ldaa #1
    jsr argument
    ldx #type_name
    stx pat
    ldx #argtext
    jsr match
    bcc type12_ok
    ldx #type16_name
    stx pat
    ldx #argtext
    jsr match
    bcc type16_ok
    jmp usage
type12_ok
    ldaa #12
    bra type_store
type16_ok
    ldaa #16
type_store
    staa fs_type
type_ok
    ldaa #2
    bra get_partition
plain
    ldaa #1
get_partition
    jsr argument
    jsr parse_device
    bcc valid
    jmp usage
    .else
    clr fs_type
    clr mount_ro
    clr part
    int $3b
    staa argc
    cmpa #2
    bcs mount_usage
    cmpa #4
    bhi mount_usage
    ldaa #1
    jsr argument
    ldx #list_name
    stx pat
    ldx #argtext
    jsr match
    bcs mount_arguments
    ldaa argc
    cmpa #2
    bne mount_usage
    jmp mount_list
mount_usage
    jmp usage
mount_arguments
    ldaa #1
    staa arg_index
mount_argument
    ldaa arg_index
    jsr argument
    ldx #readonly_name
    stx pat
    ldx #argtext
    jsr match
    bcs mount_arg_type
    tst mount_ro
    bne mount_usage
    inc mount_ro
    bra mount_arg_next
mount_arg_type
    ldx #type_name
    stx pat
    ldx #argtext
    jsr match
    bcc mount_arg12
    ldx #type16_name
    stx pat
    ldx #argtext
    jsr match
    bcc mount_arg16
    tst part
    bne mount_usage
    ldx #argtext
    jsr parse_device
    bcs mount_usage
    bra mount_arg_next
mount_arg12
    ldaa #12
    bra mount_arg_store
mount_arg16
    ldaa #16
mount_arg_store
    tst fs_type
    bne mount_usage
    staa fs_type
mount_arg_next
    inc arg_index
    ldaa arg_index
    cmpa argc
    bcs mount_argument
    tst part
    beq mount_usage
    .endif
valid
    .ifndef FORMAT_TOOL
    tst fs_type
    beq mount_detect
    clr scan_index
mount_check_type
    ldab scan_index
    ldx #record
    ldaa #1
    int $e1
    tsta
    bne mount_type_error
    ldaa record+8
    cmpa part
    beq mount_type_record
    inc scan_index
    bra mount_check_type
mount_type_record
    ldaa record+22
    cmpa fs_type
    beq mount_detect
mount_type_error
    ldaa #9
    jmp finish_result
mount_detect
    .endif
    ldab part
    .ifdef FORMAT_TOOL
    ldaa fs_type
    cmpa #16
    bne format12_call
    ldaa #10
    bra format_call
format12_call
    ldaa #6
format_call
    .else
    ldaa #2
    tst mount_ro
    beq mount_call
    ldaa #13
mount_call
    .endif
    int $e1
    tsta
    beq mount_skip_000
    jmp finish_result
mount_skip_000
    .ifndef FORMAT_TOOL
    stab result_drive
    ldx #mounted_msg
    int $23
    ldaa result_drive
    adda #'A'
    int $22
    ldx #newline
    int $23
    int $38
    .else
    ldaa fs_type
    cmpa #16
    bne format12_message
    ldx #ok16_msg
    int $23
    int $38
format12_message
    clra
    jmp finish_result
    .endif
    .ifndef FORMAT_TOOL
; List only mounted records, including the boot-selected A/B/C mappings.
mount_list
    clr scan_index
    ldx #list_heading
    int $23
mount_list_next
    ldab scan_index
    ldx #record
    ldaa #1
    int $e1
    tsta
    beq mount_list_record
    cmpa #2
    beq mount_list_end
    jmp finish_result
mount_list_record
    ldaa record+11
    cmpa #$ff
    beq mount_list_skip
    adda #'A'
    int $22
    ldx #list_device
    int $23
    ldaa record+8
    cmpa #10
    bcc mount_list_number
    adda #'0'
    int $22
    bra mount_list_type
mount_list_number
    jsr print_number
mount_list_type
    ldx #list_fat
    int $23
    ldaa record+22
    jsr print_number
    ldx #rw_name
    tst record+23
    beq mount_list_mode
    ldx #ro_name
mount_list_mode
    int $23
mount_list_skip
    inc scan_index
    bra mount_list_next
mount_list_end
    int $38
    .endif
    include COMMON.INC
    .ifdef FORMAT_TOOL
usage_msg db "FORMAT [/T:FAT12|/T:FAT16] SD0:PARTn",13,10,"Unmount first. Formatting destroys this partition's files.",13,10,0
ok_msg db "FAT12 formatted.",13,10,0
ok16_msg db "FAT16 formatted.",13,10,0
    .else
usage_msg db "MOUNT [/R] [/T:FAT12|/T:FAT16] SD0:PARTn",13,10,"MOUNT /L",13,10,0
ok_msg db "Mounted.",13,10,0
mounted_msg db "Mounted as ",0
list_name db "/L",0
readonly_name db "/R",0
list_heading db "DRIVE PARTITION FAT MODE",13,10,0
list_device db ": SD0:PART",0
list_fat db " FAT",0
ro_name db " RO",13,10,0
rw_name db " RW",13,10,0
mount_ro db 0
arg_index db 0
result_drive db 0
    .endif
fs_type db 0
scan_index db 0
