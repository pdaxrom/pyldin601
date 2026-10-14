; The mount mode is private state, never inferred from an old caller's X.
mount_number
    jsr state_pointer
    clr 45,x
    bra mount_mode
mount_readonly
    jsr state_pointer
    ldaa #1
    staa 45,x
mount_mode
    jsr find_number
    bcc mount_found
    rts
mount_found
    ldx PR
    ldaa 11,x
    cmpa #$ff
    beq mount_new
    staa SWIB
    ldaa 23,x
    psha
    jsr state_pointer
    pula
    cmpa 45,x
    beq mount_existing_mode
    ldaa #15
    rts
mount_existing_mode
    clra
    rts
mount_new
    jsr state_pointer
    clr 44,x
    ldx PR
    ldaa 9,x
    jsr supported_fat_type
    bne mount_bad
mount_branch_1
    jsr volume_read
    bcc mount_branch_2
    jmp mount_return
mount_branch_2
    jsr bpb_validate
    bcc mount_branch_3
    jmp mount_bad
mount_branch_3
    ; Find first unused DOS drive without changing the current drive.
    ldx #HEAD_TABLE
    clr PJ
mount_slot
    stx PP
    ldx 0,x
    cpx #0
    beq mount_free_slot
    inc PJ
    ldaa PJ
    cmpa #8
    bcc mount_full
    ldx PP
    inx
    inx
    bra mount_slot
mount_full
    ldaa #27
    rts
mount_bad
    ldaa #9
    rts
mount_return
    rts
mount_free_slot
    ; Headers and buffers belong to DOS drive slots, not partition records.
    ; Reusing an unmounted slot must not alias a header still used elsewhere.
    ldaa PJ
    cmpa #2
    bcc mount_private_slot
    jsr state_pointer
    ldaa PJ
    beq mount_kernel_a
    ldx 34,x
    jmp mount_have_header
mount_kernel_a
    ldx 32,x
    jmp mount_have_header
mount_private_slot
    jsr private_slot_pointer
    ldx 0,x
    cpx #0
    beq mount_allocate
    jmp mount_have_header
private_slot_pointer
    jsr state_pointer
    ldaa PJ
    suba #2
    asla
    adda #48
    adda PT+1
    staa PP+1
    ldaa PT
    adca #0
    staa PP
    ldx PP
    rts
mount_allocate
    jsr file_header_pointer
    cpx #0
    bne mount_pooled
    ldx #605
    ldaa FS_AREA+FS_BANK
    cmpa #1
    bne mount_allocate_size
    ldx #93
mount_allocate_size
    clrb
    int $2a
    cpx #0
    bne mount_allocated
    ldaa #6
    rts
mount_allocated
    stx P0
    jsr state_pointer
    inc 44,x
    ldx P0
mount_pooled
    stx P0
    jsr private_slot_pointer
    ldaa P0
    staa 0,x
    ldaa P0+1
    staa 1,x
    ldx P0
    stx PT
    ldx PR
    ldaa PT
    staa 12,x
    ldaa PT+1
    staa 13,x
    ; New private buffer + current directory after the 27-byte header.
    ldaa PT+1
    adda #27
    staa P0+1
    ldaa PT
    adca #0
    staa P0
    ldx PT
    ldaa FS_AREA+FS_BANK
    cmpa #1
    bne mount_ordinary_buffer
    ldaa #$e7
    staa 7,x
    clr 8,x
    ldaa P0
    staa 9,x
    ldaa P0+1
    staa 10,x
    bra mount_have_header
mount_ordinary_buffer
    ldaa P0
    staa 7,x
    ldaa P0+1
    staa 8,x
    ldaa P0
    adda #2
    staa 9,x
    ldaa P0+1
    staa 10,x
    ldx PT
mount_have_header
    stx P0
    jsr state_pointer
    ldaa 45,x
    ldx PR
    staa 23,x
    ldx P0
    stx PT
    ldx PR
    ldaa PT
    staa 12,x
    ldaa PT+1
    staa 13,x
    ldaa PJ
    staa 11,x
    ; Keep each header's existing fat and directory pointers.
    ldx PT
    ldaa #/driver_init
    staa 0,x
    ldaa #driver_init
    staa 1,x
    ldaa #/driver_read
    staa 2,x
    ldaa #driver_read
    staa 3,x
    ldaa #/driver_write
    staa 4,x
    ldaa #driver_write
    staa 5,x
    ldaa $e6f0
    anda #15
    staa 6,x
    clr 12,x
    clr 13,x
    ldaa #$ff
    staa 11,x
    ldaa #2
    staa 14,x
    clr 15,x
    ; Copy the validated BPB into the native big-endian driver header.
    ; Restore header and set the noncontiguous/byte-sized BPB fields.
    ldx PR
    ldx 12,x
    stx PT
    ldx PS
    ldaa 13,x
    ldx PT
    staa 16,x
    ldx PS
    ldaa 14,x
    ldx PT
    staa 17,x
    ldx PS
    ldaa 16,x
    ldx PT
    staa 18,x
    ldx PS
    ldaa 18,x
    ldx PT
    staa 19,x
    ldx PS
    ldaa 17,x
    ldx PT
    staa 20,x
    ldx PS
    ldaa 21,x
    ldx PT
    staa 23,x
    ldx PS
    ldaa 22,x
    ldx PT
    staa 24,x
    ldx PS
    ldaa 24,x
    ldx PT
    staa 25,x
    ldx PS
    ldaa 26,x
    ldx PT
    staa 26,x
    ldx PR
    ldaa 14,x
    ldab 15,x
    ldx PT
    staa 21,x
    stab 22,x
    ldab $e6f0
    andb #15
    int $5d
    tsta
    bne mount_install_failed
    ldab PJ
    ldx PS
    ldaa #1
    int $eb
    tsta
    bne mount_install_failed
    ; Register the same protection bit with the native filesystem descriptor.
    stx PA
    ldx PR
    tst 23,x
    beq mount_registered
    ldx PA
    ldaa FH_FLAGS,x
    oraa #FH_READONLY
    staa FH_FLAGS,x
mount_registered
    ; Only a new allocation changes residency; remount must not retain the
    ; calling utility on every invocation.
    jsr state_pointer
    tst 44,x
    beq mount_keep_residency
    int $2c
mount_keep_residency
    ldaa PJ
    staa SWIB
    clra
    clc
    rts
mount_install_failed
    ldx PR
    clr 23,x
    ldaa #$ff
    staa 11,x
    ldaa #27
    rts

; Native INT40 descriptors use relative BE16 sectors. They never use CHS.
driver_read
    ldaa #1
    bra driver_transfer
driver_write
    ldaa #2
driver_transfer
    ; A disk callback may be nested inside this ROM's unmount/flush operation.
    ; Preserve the caller's service variables explicitly across that callback.
    psha
    ldx #PI
    ldab #17
driver_save
    ldaa 0,x
    psha
    inx
    decb
    bne driver_save
    ldaa P0
    psha
    ldaa P0+1
    psha
    ldaa PL
    psha
    tsx
    ldaa 20,x
    staa PL
    ldx $07
    stx PA
    ldaa 2,x
    staa PB
    jsr find_drive
    bcc driver_found
    jmp driver_result
driver_found
    ldx PR
    tst 23,x
    beq driver_access_ok
    ldaa PL
    cmpa #2
    beq driver_protected
    cmpa #9
    bne driver_access_ok
driver_protected
    ldaa #3
    jmp driver_result
driver_access_ok
    ldaa PL
    cmpa #8
    bcs driver_legacy
    jmp driver_full
driver_legacy
    ldx PA
    ldaa 3,x
    staa P0
    ldaa 4,x
    staa P0+1
    ldx PR
    ldaa P0+1
    suba 15,x
    ldaa P0
    sbca 14,x
    bcc driver_bad
    jsr state_pointer
    stx PP
    ldx PA
    ldaa 0,x
    ldx PP
    staa 0,x
    ldx PA
    ldaa 1,x
    ldx PP
    staa 1,x
    ; Relative sector + physical partition base, with carry and capacity guard.
    ldx PR
    ldaa 0,x
    adda P0+1
    ldx PP
    staa 2,x
    ldx PR
    ldaa 1,x
    adca P0
    ldx PP
    staa 3,x
    ldx PR
    ldaa 2,x
    adca #0
    ldx PP
    staa 4,x
    ldx PR
    ldaa 3,x
    adca #0
    ldx PP
    staa 5,x
    bcs driver_bad
    ldaa PL
    int $e2
    bra driver_result
driver_bad
    ldaa #7
driver_result
    staa SWIA
    pula
    staa PL
    pula
    staa P0+1
    pula
    staa P0
    ldx #PE+3
    ldab #17
driver_restore
    pula
    staa 0,x
    dex
    decb
    bne driver_restore
    ins
    ldaa SWIA
    tsta
    beq driver_ok
    sec
    rts
driver_init
    clr SWIA
driver_ok
    clc
    rts

; INT E1 A=8/9: explicit 7-byte relative BE32 descriptor. Kernel INT EA
; separately checks the BPB extent; this layer guards the physical partition.
driver_full
    suba #7
    staa PL
    ldx PA
    ldaa 6,x
    staa PE
    ldaa 5,x
    staa PE+1
    ldaa 4,x
    staa PE+2
    ldaa 3,x
    staa PE+3
    ldx PR
    ldaa PE
    suba 4,x
    ldaa PE+1
    sbca 5,x
    ldaa PE+2
    sbca 6,x
    ldaa PE+3
    sbca 7,x
    bcc driver_full_bad
    jsr state_pointer
    stx PP
    ldx PA
    ldaa 0,x
    ldx PP
    staa 0,x
    ldx PA
    ldaa 1,x
    ldx PP
    staa 1,x
    ldx PR
    ldaa PE
    adda 0,x
    ldx PP
    staa 2,x
    ldx PR
    ldaa PE+1
    adca 1,x
    ldx PP
    staa 3,x
    ldx PR
    ldaa PE+2
    adca 2,x
    ldx PP
    staa 4,x
    ldx PR
    ldaa PE+3
    adca 3,x
    ldx PP
    staa 5,x
    bcs driver_full_bad
    ldaa PL
    int $e2
    jmp driver_result
driver_full_bad
    ldaa #7
    jmp driver_result

; Unmount refuses open files and the current drive. Header/buffers are kept
; for reuse, so remount neither leaks heap nor moves any running program.
unmount
    ldx PR
    ldaa 11,x
    cmpa #$ff
    beq unmount_missing
    cmpa CURRENT_DRIVE
    beq unmount_busy
    staa PJ
    ldx 12,x
    tst 13,x
    bne unmount_busy
    jsr flush_header
    tsta
    bne unmount_return
    ldaa PJ
    int $5c
    tsta
    bne unmount_return
    ldx #HEAD_TABLE
    ldab PJ
    beq unmount_slot
unmount_find_slot
    inx
    inx
    decb
    bne unmount_find_slot
unmount_slot
    clr 0,x
    clr 1,x
    ldab PJ
    ldaa #4
    int $eb
    ldx PR
    ldaa #$ff
    staa 11,x
    clr 23,x
    clra
unmount_return
    rts
unmount_missing
    ldaa #2
    rts
unmount_busy
    ldaa #15
    rts
; On the supported UniDOS kernel closed files commit directory/data buffers.
; Explicitly commit a dirty cached FAT to every FAT copy before invalidation.
flush_header
    ldab PJ
    ldaa #2
    int $eb
    rts
