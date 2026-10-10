start
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
    bcc type_ok
    jmp usage
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
valid
    ldab part
    .ifdef FORMAT_TOOL
    ldaa #6
    .else
    ldaa #2
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
    jmp finish_result
    .endif
    include COMMON.INC
    .ifdef FORMAT_TOOL
usage_msg db "FORMAT [/T:FAT12] SD0:PARTn",13,10,"Unmount first. Formatting destroys this partition's files.",13,10,0
ok_msg db "FAT12 formatted.",13,10,0
    .else
usage_msg db "MOUNT [/T:FAT12] SD0:PARTn",13,10,0
ok_msg db "Mounted.",13,10,0
mounted_msg db "Mounted as ",0
result_drive db 0
    .endif
