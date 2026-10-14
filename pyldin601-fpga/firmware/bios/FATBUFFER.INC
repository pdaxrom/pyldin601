; Buffer cache records live after the private per-handle sector words:
; cell+54 = buffer key BE16, cell+56 = high relative-sector word, cell+58 drive.
; They form a separate map, independent of which handle owns a shared cache.
; Closing/reusing/moving a handle must not lose or duplicate buffer metadata.
fc_buffer_meta
    ldx $07
    ldaa 0,x
    ldab 1,x
    staa BUF
    stab BUF+1
    ldx 2,x
fc_buffer_lookup
    stx LBA
    ldx 54,x
    cpx BUF
    beq fc_buffer_result
    ldx LBA
    ldx 0,x
    bne fc_buffer_lookup
    ; Every active unique custom buffer has at least one disk handle. There
    ; are as many records as handles, so an unused/inactive key always exists.
    ldx $07
    ldx 2,x
fc_buffer_candidate
    stx LBA
    ldx 54,x
    beq fc_buffer_claim
    stx ARG
    ldx $07
    ldx 2,x
fc_buffer_active
    stx COUNT
    ldaa 2,x
    beq fc_buffer_active_next
    bita #4
    bne fc_buffer_active_next
    ldx 39,x
    cpx ARG
    beq fc_buffer_next_candidate
fc_buffer_active_next
    ldx COUNT
    ldx 0,x
    bne fc_buffer_active
    bra fc_buffer_claim
fc_buffer_next_candidate
    ldx LBA
    ldx 0,x
    bne fc_buffer_candidate
    jmp fc_meta_missing
fc_buffer_claim
    ldx LBA
    ldaa BUF
    staa 54,x
    ldaa BUF+1
    staa 55,x
    ; FFFF cannot be a high word of a supported volume-relative address.
    ; A new mapping therefore misses a stale native 16-bit cache key. On a
    ; post-read lookup the kernel immediately replaces this sentinel with
    ; the actual high word. Never touch an evicted caller buffer's memory.
    ldaa #$ff
    staa 56,x
    staa 57,x
fc_buffer_result
    ldaa BUF
    adda #2
    staa ARG
    ldaa BUF+1
    staa ARG+1
    ldx ARG
    ldaa 0,x
    ldx LBA
    staa 58,x
    ldx LBA
    ldab #56
fc_buffer_tail
    inx
    decb
    bne fc_buffer_tail
    clra
    rts

; Invalidating a volume touches owned records, never the memory of a caller
; buffer that may already have been freed. Other volumes' dirty keys survive.
fc_buffer_invalidate
    ldx $07
    ldaa FH_IO+2,x
    staa OP
    ldx FS_FILES
    beq fc_invalidate_done
fc_invalidate_next
    ldaa 58,x
    cmpa OP
    bne fc_invalidate_skip
    ldaa #$ff
    staa 56,x
    staa 57,x
fc_invalidate_skip
    ldx 0,x
    bne fc_invalidate_next
fc_invalidate_done
    clra
    rts

; Media-check/unmount must retain a dirty directory cache after a failed
; synchronous mutation. Flush it before invalidating native cache keys.
; With open files, COMMIT already orders its data -> FAT -> directory;
; this helper leaves other files' default buffers to their own commits.
fc_flush_idle
    ldx $07
    tst FH_FLAGS,x
    bne fc_idle_valid
    clra
    rts
fc_idle_valid
    jsr fc_flush
    tsta
    beq fc_idle_flushed
    rts
fc_idle_flushed
    ldx $07
    ldx FH_HEADER,x
    tst 13,x
    beq fc_idle_active
    jmp fc_idle_ok
fc_idle_active
    ldx $07
    clr FH_TMP+5,x
fc_idle_buffer
    jsr fc_idle_pointer
    stx BUF
    ldaa 0,x
    ldx $07
    cmpa FH_IO+2,x
    bne fc_idle_next
    ldx BUF
    tst 3,x
    beq fc_idle_next
    ldaa 1,x
    ldab 2,x
    ldx $07
    staa FH_IO+5,x
    stab FH_IO+6,x
    ldaa BUF
    suba #2
    staa FH_IO,x
    ldaa BUF+1
    staa FH_IO+1,x
    tst FH_TMP+5,x
    beq fc_idle_first_high
    ldaa FS_AREA+FS_BUFFERS+2
    ldab FS_AREA+FS_BUFFERS+3
    bra fc_idle_high
fc_idle_first_high
    ldaa FS_AREA+FS_BUFFERS
    ldab FS_AREA+FS_BUFFERS+1
fc_idle_high
    staa FH_IO+3,x
    stab FH_IO+4,x
    ldaa FS_AREA+FS_FILE_FLAG
    cmpa #1
    bne fc_idle_mapped
    ldx FH_IO,x
    ldaa #11
    int $e1
    stx COUNT
    ldx $07
    ldaa COUNT
    staa FH_IO,x
    ldaa COUNT+1
    staa FH_IO+1,x
fc_idle_mapped
    jsr fc_io_pointer
    ldaa #2
    inc FS_WRITE_CONTEXT
    int $ea
    dec FS_WRITE_CONTEXT
    tsta
    bne fc_idle_return
    jsr fc_idle_pointer
    clr 3,x
fc_idle_next
    ldx $07
    inc FH_TMP+5,x
    ldaa FH_TMP+5,x
    cmpa #2
    bcs fc_idle_buffer
fc_idle_ok
    clra
fc_idle_return
    rts
fc_idle_pointer
    ldx $07
    tst FH_TMP+5,x
    beq fc_idle_first
    ldx #$e405
    rts
fc_idle_first
    ldx #$e200
    rts

; X is the native 48-byte disk handle body. A failed CREATE has already
; reserved a default/caller buffer and incremented the volume's open count.
; Release those reservations while keeping the directory cache retryable.
fc_abort_create
    ldx $07
    clr 0,x
    ldaa 33,x
    staa COUNT
    ldaa 37,x
    adda #2
    staa BUF
    ldaa 38,x
    staa BUF+1
    ldx BUF
    dec 4,x
    clra
    ldab COUNT
    aslb
    addb #3
    adca #$eb
    staa ARG
    stab ARG+1
    ldx ARG
    ldx 0,x
    dec 13,x
    clra
    rts

; These pointer operations preserve A/B/CCR in the SWI frame. They have no
; dependency on PARTS when the banked file cache was unavailable at startup.
fc_file_map
    ldaa FS_AREA+FS_FILE_FLAG
    cmpa #1
    bne fc_file_map_return
    ldaa #11
    int $e1
    stx $07
fc_file_map_return
    ldx $07
    rts
fc_file_pointer
    ldx $07
    ldx 37,x
    stx $07
    jsr fc_file_map
    ldaa $08
    adda $eb64
    staa $08
    ldaa $07
    adca $eb63
    staa $07
    ldx $07
    rts

; MKDIR overwrites logical buffer 2 without a read. Preserve its pending file
; data before allocating a cluster, including when it belongs to another drive.
fc_directory_allocate
    tst $e408
    beq fc_directory_clean
    ldx #$e205
    stx FS_AREA+FS_FILE_IO
    ldaa $e405
    staa FS_AREA+FS_FILE_IO+2
    ldx FS_AREA+FS_BUFFERS+2
    stx FS_AREA+FS_FILE_IO+3
    ldx $e406
    stx FS_AREA+FS_FILE_IO+5
    ldaa FS_AREA+FS_FILE_FLAG
    cmpa #1
    bne fc_directory_buffer
    ldx #$e205
    ldaa #11
    int $e1
    stx FS_AREA+FS_FILE_IO
fc_directory_buffer
    ldx #FS_AREA+FS_FILE_IO
    ldaa #2
    inc FS_WRITE_CONTEXT
    int $ea
    dec FS_WRITE_CONTEXT
    tsta
    beq fc_directory_written
    jmp fc_return
fc_directory_written
    clr $e408
fc_directory_clean
    ldx #FS_AREA
    ldaa $68
    beq fc_directory_volume
fc_directory_offset
    ldab #FH_SIZE
fc_directory_step
    inx
    decb
    bne fc_directory_step
    deca
    bne fc_directory_offset
fc_directory_volume
    stx $07
    jsr fc_allocate
    tsta
    beq fc_directory_cluster
    jmp fc_return
fc_directory_cluster
    ldx $07
    ldx FH_CLUSTER,x
    stx $07
    clra
    jmp fc_return
