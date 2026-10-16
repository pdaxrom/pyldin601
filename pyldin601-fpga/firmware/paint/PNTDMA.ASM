; Flat physical DMA for the Paint canvas and palette. IRQs may run while
; waiting; painting/file operations never start another job from paint_idle.
    include DMA.INC
    public paint_dma
    public dma_reset
    public dma_run
    public dma_wait
    extern paint_idle
    section
paint_dma ds DMA_BYTES
dma_command_byte ds 1
dma_timeout ds 2
    ends
dma_reset
    ldx #paint_dma
    ldab #DMA_BYTES
dma_zero
    clr 0,x
    inx
    decb
    bne dma_zero
    inc paint_dma+DMA_HEIGHT
    rts
; A=command; parameters remain stable until completion. A=0,2 error,3 timeout.
dma_run
    staa dma_command_byte
dma_acquire
    jsr dma_wait
    cmpa #3
    beq dma_return
    tpa
    psha
    sei
    ldaa DMA_STATUS
    bpl dma_program
    pula
    tap
    bra dma_acquire
dma_program
    clr DMA_INDEX
    ldx #paint_dma
    ldab #DMA_BYTES
dma_parameters
    ldaa 0,x
    staa DMA_DATA
    inx
    decb
    bne dma_parameters
    ldaa dma_command_byte
    staa DMA_COMMAND
    pula
    tap
    jmp dma_wait
dma_wait
    ldx #$ffff
    stx dma_timeout
dma_pending
    ldaa DMA_STATUS
    bpl dma_finished
    jsr paint_idle
    ldx dma_timeout
    dex
    stx dma_timeout
    bne dma_pending
    ldaa #3
    rts
dma_finished
    bita #DMA_ERROR
    bne dma_bad
    clra
dma_return
    rts
dma_bad
    ldaa #2
    rts
    public v_paint_dma_0
v_paint_dma_0 equ paint_dma+0
    public v_paint_dma_11
v_paint_dma_11 equ paint_dma+11
    public v_paint_dma_14
v_paint_dma_14 equ paint_dma+14
    public v_paint_dma_3
v_paint_dma_3 equ paint_dma+3
    public v_paint_dma_6
v_paint_dma_6 equ paint_dma+6
    public v_paint_dma_9
v_paint_dma_9 equ paint_dma+9
    public v_paint_dma_1
v_paint_dma_1 equ paint_dma+1
    public v_paint_dma_10
v_paint_dma_10 equ paint_dma+10
    public v_paint_dma_2
v_paint_dma_2 equ paint_dma+2
    public v_paint_dma_4
v_paint_dma_4 equ paint_dma+4
    public v_paint_dma_5
v_paint_dma_5 equ paint_dma+5
    public v_paint_dma_7
v_paint_dma_7 equ paint_dma+7
    public v_paint_dma_8
v_paint_dma_8 equ paint_dma+8
    end
