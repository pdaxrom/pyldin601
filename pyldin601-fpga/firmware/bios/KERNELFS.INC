; Native kernel storage extension. State replaces the second FAT buffer.
fs_initialize
    ldaa #27
    int $e9
    rts

; A = drive, X = descriptor. Address arithmetic lives beside FAT algorithms.
fs_volume_addr
    tab
    ldaa #26
    int $e9
    rts
fs_volume
    cmpa #8
    bcc fs_volume_bad
    psha
    jsr fs_volume_addr
    pula
    staa FH_IO+2,x
    tst FH_FLAGS,x
    bne fs_volume_ok
    jsr get_head_addr
    bcs fs_volume_return
    ; Header address must survive descriptor lookup.
    stx legacytable
    ldx fs_bufptr
    ldaa legacytable
    staa FH_HEADER,x
    ldaa legacytable+1
    staa FH_HEADER+1,x
    ldaa #6
    int $e9
    tsta
    bne fs_volume_error
    ldx fs_bufptr
    ldaa #1
    staa FH_FLAGS,x
fs_volume_ok
    clra
    clc
fs_volume_return
    rts
fs_volume_bad
    ldaa #2
fs_volume_error
    sec
    rts

; INT EA: A=1/2, X -> buffer BE16, drive U8, sector BE32.
fs_transfer
    cmpa #1
    bcs fs_transfer_function
    cmpa #2
    bls fs_transfer_descriptor
fs_transfer_function
    ldaa #1
    jmp fs_transfer_result
fs_transfer_descriptor
    stx fs_bufptr
    ldx #fulltable
    stx legacytable
    ldab #7
fs_transfer_copy
    ldx fs_bufptr
    ldaa 0,x
    inx
    stx fs_bufptr
    ldx legacytable
    staa 0,x
    inx
    stx legacytable
    decb
    bne fs_transfer_copy
    ldaa fulltable+2
    jsr fs_volume
    bcs fs_transfer_result
    ; Full unsigned relative-sector < BPB total, including high words.
    ldaa fulltable+6
    suba FH_TOTAL+3,x
    ldaa fulltable+5
    sbca FH_TOTAL+2,x
    ldaa fulltable+4
    sbca FH_TOTAL+1,x
    ldaa fulltable+3
    sbca FH_TOTAL,x
    bcc fs_transfer_range
    ldaa FH_FLAGS,x
    bita #2
    beq fs_transfer_legacy
    ldx #fulltable
    ldaa swia
    adda #7
    int $e1
    bra fs_transfer_result
fs_transfer_legacy
    ldaa fulltable+3
    oraa fulltable+4
    bne fs_transfer_range
    ldx fulltable
    stx legacytable
    ldaa fulltable+2
    staa legacytable+2
    ldx fulltable+5
    stx legacytable+3
    ldx #legacytable
    ldaa swia
    int $40
    bra fs_transfer_result
fs_transfer_range
    ldaa #4
fs_transfer_result
    staa swia
    tsta
    beq fs_transfer_ok
    sec
    bra fs_transfer_cc
fs_transfer_ok
    clc
fs_transfer_cc
    tpa
    staa swic
    rts

; INT EB: 0 capabilities, 1 register SD BPB (B drive, X sector buffer),
; 2 flush (B drive), 3 descriptor (B drive), 4 unregister (B drive),
; 5 validate BPB without mounting (X sector buffer -> X normalized descriptor).
fs_control
    stx fulltable
    tsta
    bne fs_control_work
    ldaa #1
    ldab #3
    jmp $fff2
fs_control_work
    cmpa #6
    bne fs_control_geometry
    ldx fs_state
    ldaa #11
    int $e9
    jmp fs_control_result
fs_control_geometry
    cmpa #5
    beq fs_control_probe
    cmpb #8
    bcs fs_control_drive_ok
    ldaa #2
    jmp fs_control_result
fs_control_drive_ok
    tba
    jsr fs_volume_addr
    ldaa swia
    cmpa #1
    beq fs_control_register
    cmpa #4
    beq fs_control_remove
    ldaa swib
    jsr fs_volume
    bcs fs_control_result
    ldaa swia
    cmpa #3
    beq fs_control_pointer
    cmpa #2
    beq fs_control_flush
    ldaa #1
    bra fs_control_result
fs_control_flush
    ldaa #19
    int $e9
    bra fs_control_result
fs_control_remove
    ldaa #18
    int $e9
    clr FH_FLAGS,x
    clr FH_VALID,x
    clr FH_DIRTY,x
    clra
    bra fs_control_result
fs_control_register
    ldaa swib
    jsr get_head_addr
    bcs fs_control_result
    stx legacytable
    ldx fs_bufptr
    ldaa legacytable
    staa FH_HEADER,x
    ldaa legacytable+1
    staa FH_HEADER+1,x
    ldaa swib
    staa FH_IO+2,x
    bra fs_control_normalize
fs_control_probe
    ldaa fs_state+1
    adda #FS_PROBE
    staa fs_bufptr+1
    ldaa fs_state
    adca #/FS_PROBE
    staa fs_bufptr
    ldx fs_bufptr
    clr FH_HEADER,x
    clr FH_HEADER+1,x
fs_control_normalize
    ldaa fulltable
    staa FH_IO,x
    ldaa fulltable+1
    staa FH_IO+1,x
    clra
    int $e9
    tsta
    bne fs_control_result
    ldx fs_bufptr
    ldaa #3
    staa FH_FLAGS,x
fs_control_pointer
    ldx fs_bufptr
    clra
    tpa
    staa swic
    clra
    jmp $fff0
fs_control_result
    jmp fs_transfer_result

; X native handle -> private tail: directory/data high, separate cache record.
fs_handle
    ldaa #13
fs_metadata
    stx fulltable
    psha
    ldx file_handles
    stx fulltable+2
    ldx #fulltable
    pula
    int $e9
    rts
fs_dir_save
    jsr fs_handle
    ldaa sec_hi
    staa 0,x
    ldaa sec_hi+1
    staa 1,x
    rts
fs_data_save
    jsr fs_handle
    ldaa sec_hi
    staa 2,x
    ldaa sec_hi+1
    staa 3,x
    rts
fs_dir_load
    jsr fs_handle
    ldx 0,x
    stx sec_hi
    rts
fs_data_load
    jsr fs_handle
    ldx 2,x
    stx sec_hi
    rts
; X cache buffer -> high-word storage; custom buffers are attached to handles.
fs_buffer
    stx fs_bufptr
    cpx buff1_addr
    beq fs_buffer_first
    cpx buff2_addr
    beq fs_buffer_second
    ldaa #14
    jmp fs_metadata
fs_buffer_first
    ldab #0
    bra fs_buffer_builtin
fs_buffer_second
    ldab #2
fs_buffer_builtin
    ldx #FS_AREA+FS_BUFFERS
    tstb
    beq fs_buffer_done
    inx
    inx
fs_buffer_done
    rts
fs_buffer_meta
    stx fs_bufptr
    ldaa fs_bufptr
    suba #2
    staa fs_bufptr
    ldx fs_bufptr
    jmp fs_buffer
fs_check_cluster
    staa fat_value+1
    stab fat_value
    ldaa fat_drive
    jsr fs_volume
    bcs fs_check_return
    ldaa fat_value
    staa FH_VALUE,x
    ldaa fat_value+1
    staa FH_VALUE+1,x
    ldaa #7
    int $e9
    tsta
    beq fs_check_ok
    sec
fs_check_return
    rts
fs_check_ok
    clc
    rts

fs_validate_dir
    ldx ff_table
    ldaa find_drive,x
    staa fat_drive
    ldx find_cluster,x
fs_validate_chain
    stx fat_offset
    pshb
    ldaa fat_drive
    jsr fs_volume
    bcs fs_validate_return
    ldaa fat_offset
    staa FH_CLUSTER,x
    ldaa fat_offset+1
    staa FH_CLUSTER+1,x
    ldaa #9
    int $e9
    tsta
    beq fs_validate_return
    sec
fs_validate_return
    ldx fat_offset
    pulb
    rts

; Logical default buffers retain their native metadata addresses. Only data
; pointers are mapped into the shared window; explicit user buffers pass through.
fs_map1
    ldx buff1_addr
    bra fs_map
fs_map2
    ldx buff2_addr
fs_map
    psha
    ldaa #21
    int $e9
    pula
    rts
