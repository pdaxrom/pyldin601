; Private native-file data mapper. It does not use partition scratch and
; preserves the incoming SWI A/B/CCR. E9 guards calls when this ROM is absent.
; Two logical caches E000/E205 share data window E000..E1FF. Their native
; attributes E200/E405 remain separate; the second data area becomes headers.
file_service
    cmpa #12
    beq file_cache_initialize
    jsr file_cache_map
    stx $07
    rts

file_cache_initialize
    tst FS_AREA+FS_FILE_FLAG
    bne file_cache_ready
    dec FS_AREA+FS_FILE_FLAG
    ldaa FS_AREA+FS_BANK
    cmpa #1
    bne file_cache_ready
    ; Test this window independently of the FAT E700 copy probe. It runs
    ; before mounting any volume or opening files, so both keys are invalid.
    ldaa #$a5
    staa $e000
    ldaa #1
    staa FS_AREA+FS_FILE_TARGET
    clra
    jsr file_cache_copy
    tsta
    bne file_cache_ready
    clr $e000
    ldaa #1
    jsr file_cache_copy
    tsta
    bne file_cache_ready
    ldaa $e000
    cmpa #$a5
    bne file_cache_ready
    ldaa #1
    staa FS_AREA+FS_FILE_FLAG
file_cache_ready
    rts

file_cache_map
    ldaa FS_AREA+FS_FILE_FLAG
    cmpa #1
    bne file_cache_unmapped
    cpx #$e000
    bne file_cache_second
    ldaa #1
    bra file_cache_selected
file_cache_second
    cpx #$e205
    bne file_cache_unmapped
    ldaa #2
file_cache_selected
    staa FS_AREA+FS_FILE_TARGET
    cmpa FS_AREA+FS_FILE_OWNER
    beq file_cache_window
    tst FS_AREA+FS_FILE_OWNER
    beq file_cache_load
    ; Save all bytes, including a partially prepared directory. Disk dirty
    ; flags govern SD flush, independently of which cache owns the RAM window.
    ldaa FS_AREA+FS_FILE_OWNER
    staa FS_AREA+FS_FILE_TARGET
    clra
    jsr file_cache_copy
file_cache_load
    ldx $07
    ldaa #1
    cpx #$e000
    beq file_cache_load_selected
    inca
file_cache_load_selected
    staa FS_AREA+FS_FILE_TARGET
    ldaa #1
    jsr file_cache_copy
    ldaa FS_AREA+FS_FILE_TARGET
    staa FS_AREA+FS_FILE_OWNER
file_cache_window
    ldx #$e000
file_cache_unmapped
    rts

; A=0 save, A=1 restore. Reuse the system FAT lease: its upper 4 KiB were
; unused; the two file sectors occupy offsets 1000 and 1200. Fixed BIOS code
; performs the transfer on MC6800 and HD6303 and restores both selectors.
file_cache_copy
    psha
    ldaa FS_AREA+FS_FILE_TARGET
    deca
    asla
    adda #$d0
    staa FS_AREA+FS_COPY+2
    clr FS_AREA+FS_COPY+3
    ldx #$e000
    stx FS_AREA+FS_COPY
    pula
    tsta
    beq file_cache_bank
    ldx FS_AREA+FS_COPY+2
    stx FS_AREA+FS_COPY
    ldx #$e000
    stx FS_AREA+FS_COPY+2
file_cache_bank
    ldx FS_AREA+FS_LEASE
    ldaa 3,x
    clrb
file_cache_group
    cmpa #6
    bcs file_cache_page
    suba #6
    incb
    bra file_cache_group
file_cache_page
    inca
    staa FS_AREA+FS_COPY+4
    stab FS_AREA+FS_COPY+5
    ldx #FS_AREA+FS_COPY
    ldaa #4
    int $e8
    rts

; The reclaimed E205..E404 area holds metadata for drives C..G. H and the
; ordinary-RAM fallback retain heap allocations. Slot identity is permanent.
file_header_pointer
    ldaa FS_AREA+FS_FILE_FLAG
    cmpa #1
    bne file_header_unavailable
    ldaa PJ
    cmpa #7
    bcc file_header_unavailable
    suba #2
    tab
    ldx #FS_HEADER_POOL
    stx P0
    tstb
    beq file_header_ready
file_header_next
    ldaa P0+1
    adda #FS_HEADER_SIZE
    staa P0+1
    ldaa P0
    adca #0
    staa P0
    decb
    bne file_header_next
    ldx P0
file_header_ready
    rts
file_header_unavailable
    ldx #0
    rts
