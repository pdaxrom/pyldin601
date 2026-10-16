    include DMA.INC
; Two immutable native PGM images in 1D4000..1DFFFF. The first 16K of
; page 1D belongs to the saved parent bitmap and is never touched here.
cache_fill
    ldaa DMA_COMMAND
    cmpa #'D'
    beq *+5
    jmp loader_bad
    ldx #$4000
    stx cache_address
    clr cache_index
cache_image
    ldx load_buffer
    cpx #$a55a
    beq *+5
    jmp loader_bad
    ldx load_buffer+6
    stx cache_code
    ldx load_buffer+10
    stx cache_ram
    tst cache_index
    beq cache_sizes
    ldx cache_code
    cpx load_code_size
    beq *+5
    jmp loader_bad
    ldx cache_ram
    cpx load_ram
    beq *+5
    jmp loader_bad
cache_sizes
    ldx cache_code
    stx load_code_size
    ldx cache_ram
    stx load_ram
    ldaa load_buffer+5
    adda cache_code+1
    staa cache_size+1
    ldaa load_buffer+4
    adca cache_code
    staa cache_size
    bcc *+5
    jmp loader_bad
    ldaa cache_address+1
    adda cache_size+1
    staa cache_next+1
    ldaa cache_address
    adca cache_size
    staa cache_next
    bcc *+5
    jmp loader_bad
    ldx #load_bases
    tst cache_index
    beq cache_base
    inx
    inx
cache_base
    ldaa cache_address
    ldab cache_address+1
    staa 0,x
    stab 1,x
    ldx #load_extents
    tst cache_index
    beq cache_extent
    inx
    inx
cache_extent
    ldaa cache_size
    ldab cache_size+1
    staa 0,x
    stab 1,x
    staa cache_left
    stab cache_left+1
    ldx load_payload
    stx load_position+2
    jsr loader_seek
    tsta
    beq *+5
    jmp loader_error
cache_chunk
    ldx #512
    ldaa cache_left
    cmpa #2
    bcc cache_chunk_size
    ldx cache_left
cache_chunk_size
    stx cache_count
    stx load_io+2
    stx move_count
    ldx #load_filebuf
    stx load_io
    stx move_source
    jsr loader_read
    tsta
    beq *+5
    jmp loader_error
    cpx cache_count
    beq *+5
    jmp loader_bad
    clr move_src_page
    ldaa #$1d
    staa move_dst_page
    ldx cache_address
    stx move_target
    jsr cache_move
    tsta
    beq *+5
    jmp loader_error
    ldaa cache_address+1
    adda cache_count+1
    staa cache_address+1
    ldaa cache_address
    adca cache_count
    staa cache_address
    ldaa cache_left+1
    suba cache_count+1
    staa cache_left+1
    ldaa cache_left
    sbca cache_count
    staa cache_left
    oraa cache_left+1
    bne cache_chunk
    inc cache_index
    ldaa cache_index
    cmpa #2
    beq cache_complete
    ldaa load_payload+1
    adda cache_size+1
    staa load_payload+1
    ldaa load_payload
    adca cache_size
    staa load_payload
    bcc *+5
    jmp loader_bad
    jsr loader_header
    tsta
    beq *+5
    jmp loader_error
    jmp cache_image
cache_complete
    ldaa load_handle
    int $4e
    clr load_live
    rts
loader_read
    tst load_cached
    bne cache_read
    ldaa load_handle
    ldx #load_io
    int $4c
    rts
cache_read
    ldaa load_cache_pos+1
    adda load_io+3
    staa cache_next+1
    ldaa load_cache_pos
    adca load_io+2
    staa cache_next
    bcc *+5
    jmp loader_bad
    jsr cache_range
    tsta
    beq *+5
    jmp loader_bad
    ldaa load_cache_base+1
    adda load_cache_pos+1
    staa move_source+1
    ldaa load_cache_base
    adca load_cache_pos
    staa move_source
    ldaa #$1d
    staa move_src_page
    clr move_dst_page
    ldx load_io
    stx move_target
    ldx load_io+2
    stx move_count
    jsr cache_move
    tsta
    bne cache_read_done
    ldx cache_next
    stx load_cache_pos
    ldx load_io+2
cache_read_done
    rts
cache_seek
    ldaa load_position
    oraa load_position+1
    beq *+5
    jmp loader_bad
    ldx load_position+2
    stx cache_next
    jsr cache_range
    tsta
    beq *+5
    jmp loader_bad
    ldx cache_next
    stx load_cache_pos
    clra
    rts
cache_range
    ldaa cache_next
    cmpa load_cache_size
    bcs cache_range_ok
    bne cache_range_bad
    ldaa cache_next+1
    cmpa load_cache_size+1
    bhi cache_range_bad
cache_range_ok
    clra
    rts
cache_range_bad
    ldaa #65
    rts
; Core tail-jumps here with A=next overlay (0 edit,1 files), B=action/result.
; Discard its call frames, retaining the original core allocation and BSS.
loader_switch
    clr load_recover
    staa load_current
    ; Dynamic bitmap/backend allocations have moved the live stack since
    ; startup. Keep them: only discard the edit caller's JSR return frame.
    tsta
    beq switch_stack
    ins
    ins
switch_stack
    sts load_stack
switch_resume
    stab load_api+5
    inca
    staa load_api+4
    deca
    asla
    tab
    ldx #load_bases
    tstb
    beq *+4
    inx
    inx
    ldx 0,x
    stx load_cache_base
    ldx #load_extents
    tstb
    beq *+4
    inx
    inx
    ldx 0,x
    stx load_cache_size
    ldx #0
    stx load_position+2
    jsr loader_seek
    jsr loader_header
    tsta
    beq *+5
    jmp loader_error
    jmp loader_validate
; Bounded native flat-DMA copy. All descriptor bytes are explicitly set.
cache_move
    jsr cache_wait
    cmpa #3
    beq cache_move_done
    clr DMA_INDEX
    ldab #DMA_BYTES
cache_clear
    clr DMA_DATA
    decb
    bne cache_clear
    clr DMA_INDEX
    ldaa move_source+1
    staa DMA_DATA
    ldaa move_source
    staa DMA_DATA
    ldaa move_src_page
    staa DMA_DATA
    ldaa move_target+1
    staa DMA_DATA
    ldaa move_target
    staa DMA_DATA
    ldaa move_dst_page
    staa DMA_DATA
    ldaa move_count+1
    staa DMA_DATA
    ldaa move_count
    staa DMA_DATA
    clr DMA_DATA
    ldaa #1
    staa DMA_DATA
    ldaa #2
    staa DMA_COMMAND
cache_wait
    ldx #$ffff
    stx move_timeout
cache_busy
    ldaa DMA_STATUS
    bpl cache_finished
    ldx move_timeout
    dex
    stx move_timeout
    bne cache_busy
    ldaa #3
    rts
cache_finished
    anda #DMA_ERROR
cache_move_done
    rts
