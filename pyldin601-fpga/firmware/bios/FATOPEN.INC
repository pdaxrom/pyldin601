; Validate before reserving a handle or a caller's file buffer.
; X explicitly points to native FindFirst (19 bytes) + directory entry (32).
; That contains the drive, LE cluster and LE file size. Geometry was already
; normalized by FindFirst/media-check. A failed open changes no handle state.
fc_validate_open
    stx BUF
    ldab 11,x
    cmpb #8
    bcs fc_open_drive
    ldaa #2
    rts
fc_open_drive
    stab COUNT
    ldaa 45,x
    oraa 46,x
    bne fc_open_cluster
    ldaa 47,x
    oraa 48,x
    oraa 49,x
    oraa 50,x
    beq fc_open_cluster
    ldaa #10
    rts
fc_open_cluster
    ldaa $07
    psha
    ldaa $08
    psha
    ldaa #/FS_AREA
    ldab #FS_AREA
    tst COUNT
    beq fc_open_descriptor
fc_open_volume
    addb #FH_SIZE
    adca #0
    dec COUNT
    bne fc_open_volume
fc_open_descriptor
    staa $07
    stab $08
    ldaa $eb52
    bita #2
    beq fc_open_readable
    jsr fc_write_allowed
    tsta
    bne fc_open_return
fc_open_readable
    ldx BUF
    ldaa 45,x
    ldab 46,x
    ldx $07
    staa FH_CLUSTER+1,x
    stab FH_CLUSTER,x
    jsr fc_validate_chain
fc_open_return
    tab
    pula
    staa $08
    pula
    staa $07
    tba
    rts

; A legacy media-check callback may replace its header geometry. Rebuild it
; after the old dirty FAT was flushed, while retaining SD's full BPB geometry.
fc_media_refresh
    jsr fc_buffer_invalidate
    ldx $07
    clr FH_VALID,x
    ldaa FH_FLAGS,x
    cmpa #1
    beq fc_media_legacy
    clra
    rts
fc_media_legacy
    clr FH_FLAGS,x
    jsr fc_legacy
    tsta
    bne fc_media_return
    ldx $07
    inc FH_FLAGS,x
fc_media_return
    rts

; B = drive. Same 50-byte arithmetic as the kernel, with a fixed RAM pointer.
fc_volume_address
    tba
    aslb
    asla
    asla
    asla
    asla
    staa FS_DESCRIPTOR_PTR
    asla
    aba
    adda FS_DESCRIPTOR_PTR
    ldab #/FS_AREA
    adcb #0
    staa FS_DESCRIPTOR_PTR+1
    stab FS_DESCRIPTOR_PTR
    ldx FS_DESCRIPTOR_PTR
    rts

; One permission predicate for FAT, directory buffers and handle metadata.
fc_write_allowed
    ldx $07
fc_descriptor_writable
    ldaa FH_FLAGS,x
    bita #FH_READONLY
    beq fc_write_ok
    ldaa #3
    rts
fc_write_ok
    clra
    rts

; Legacy BPB translation is outside the main algorithm/CRC-table area.
fc_legacy
    ldaa #15
    int $e1
    ldx $07
    ldx FH_HEADER,x
    ldaa 16,x
    ldab 18,x
    ldx $07
    staa FH_SPC,x
    stab FH_NOF,x
    ldx FH_HEADER,x
    ldaa 17,x
    ldab 24,x
    ldx $07
    clr FH_RESERVED,x
    staa FH_RESERVED+1,x
    clr FH_SPF,x
    stab FH_SPF+1,x
    ldx FH_HEADER,x
    ldaa 21,x
    ldab 22,x
    ldx $07
    clr FH_TOTAL,x
    clr FH_TOTAL+1,x
    staa FH_TOTAL+2,x
    stab FH_TOTAL+3,x
    ldx FH_HEADER,x
    ldaa 19,x
    ldab 20,x
    ldx $07
    staa FH_ROOT,x
    stab FH_ROOT+1,x
    jmp fc_total_ready

; Keep these small kernel services after the CRC tables, leaving room in the
; main algorithm area for both ordinary and FAT_RAMMAN firmware variants.
fc_kernel_service
    cmpa #25
    bne fc_kernel_address
    bra fc_kernel_write_drive
fc_kernel_address
    cmpa #26
    bne fc_kernel_initialize
    jsr fc_volume_address
    stx $07
    clra
    jmp fc_return
fc_kernel_initialize
    cmpa #27
    bne fc_kernel_handle
    ldx #FS_AREA
    stx FS_STATE_PTR
fc_initialize_zero
    clr 0,x
    inx
    cpx #FS_AREA+FS_BYTES
    bne fc_initialize_zero
    ldaa #19
    int $e1
    jmp fc_return
fc_kernel_handle
    cmpa #28
    bne fc_kernel_invalid
    ldab 33,x
fc_kernel_write_drive
    cmpb #8
    bcc fc_kernel_invalid
    jsr fc_volume_address
    jsr fc_descriptor_writable
    jmp fc_return
fc_kernel_invalid
    ldaa #1
    jmp fc_return
