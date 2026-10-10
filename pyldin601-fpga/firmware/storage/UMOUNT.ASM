start
    int $3b
    cmpa #2
    beq get_target
    jmp usage
get_target
    ldaa #1
    jsr argument
    ldaa argtext+1
    cmpa #':'
    bne partition_target
    tst argtext+2
    bne partition_target
    ldaa argtext
    suba #'A'
    cmpa #7
    bls drive_target
    jmp usage
drive_target
    tab
    ldaa #4
    int $e1
    jmp finish_result
partition_target
    jsr parse_device
    bcc valid_target
    jmp usage
valid_target
    ldab part
    ldaa #3
    int $e1
    jmp finish_result
    include COMMON.INC
usage_msg db "UMOUNT SD0:PARTn | A:..H:",13,10,0
ok_msg db "Unmounted.",13,10,0
