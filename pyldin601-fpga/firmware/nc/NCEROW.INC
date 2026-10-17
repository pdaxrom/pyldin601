; Character rows in GPU scratch 1FE000..1FF7FF, one row per 256 bytes.
; This cache does not touch the native screen, palette or leased RAMMAN banks.
    include DMA.INC
    section
row_cached ds 1
row_request ds 1
row_direction ds 1
row_error ds 1
row_tags ds 24
    ends
row_invalidate
    ldaa #$ff
    staa row_cached
    ldx #row_tags
    ldab #24
row_invalidate_tag
    clr 0,x
    inx
    decb
    bne row_invalidate_tag
    rts
row_pointer
    ldaa render_row
    cmpa row_cached
    bne row_switch
    ldx screen_chars
    rts
row_switch
    staa row_request
    tst row_error
    bne row_failed
    ldaa row_cached
    cmpa #$ff
    beq row_load
    clr row_direction
    jsr row_transfer
    tsta
    bne row_failed
    ldab row_cached
    ldx #row_tags
    jsr add_b
    ldaa #1
    staa 0,x
row_load
    ldaa row_request
    staa row_cached
    tab
    ldx #row_tags
    jsr add_b
    tst 0,x
    beq row_clear
    ldaa #1
    staa row_direction
    jsr row_transfer
    tsta
    bne row_failed
    ldx screen_chars
    rts
row_failed
    inc row_error
    ldaa row_request
    staa row_cached
row_clear
    ldx screen_chars
    ldab columns
    ldaa #$ff
row_clear_byte
    staa 0,x
    inx
    decb
    bne row_clear_byte
    ldx screen_chars
    rts
; All descriptor bytes are set under SEI; IRQs resume while DMA is BUSY.
; A corrupt/absent engine is bounded and reported before the next key wait.
row_transfer
    jsr row_wait
    cmpa #3
    beq row_return
    tpa
    psha
    sei
    clr DMA_INDEX
    ldab #DMA_BYTES
row_descriptor_zero
    clr DMA_DATA
    decb
    bne row_descriptor_zero
    clr DMA_INDEX
    tst row_direction
    bne row_read_descriptor
    jsr row_ram
    jsr row_gpu
    bra row_descriptor_end
row_read_descriptor
    jsr row_gpu
    jsr row_ram
row_descriptor_end
    ldaa columns
    staa DMA_DATA
    clr DMA_DATA
    clr DMA_DATA
    ldaa #1
    staa DMA_DATA
    ldaa #DMA_COPY
    staa DMA_COMMAND
    pula
    tap
row_wait
    ldx #$ffff
row_busy
    ldaa DMA_STATUS
    bpl row_finished
    dex
    bne row_busy
    ldaa #3
    rts
row_finished
    anda #DMA_ERROR
row_return
    rts
row_ram
    ldx #screen_chars
    ldaa 1,x
    staa DMA_DATA
    ldaa 0,x
    staa DMA_DATA
    clr DMA_DATA
    rts
row_gpu
    clr DMA_DATA
    ldaa row_cached
    adda #$e0
    staa DMA_DATA
    ldaa #$1f
    staa DMA_DATA
    rts
