; Non-destructive system diagnostic: owns two RAMMAN banks, restores palette.
; MC6800 instructions only. Native relocatable PGM with ordinary BSS.
    include DMA.INC
start
    clr allocated
    clr palette_saved
    clr failed
    clr read_mode
    ldaa $e6f0
    staa saved_page
    ldaa $e6f1
    staa saved_group
    ldaa DMA_COMMAND
    cmpa #'D'
    beq *+5
    jmp unsupported
    ldaa DMA_STATUS
    anda #$6f
    cmpa #1
    beq *+5
    jmp unsupported
    ldaa #$e5
    int $2e
    cpx #0
    bne *+5
    jmp unsupported
    ldaa #1
    ldab #2
    ldx #lease
    int $e5
    tsta
    beq *+5
    jmp no_memory
    inc allocated
    ldx #intro
    int $23
    jsr parameters_clear
    ldaa lease+3
    ldx #parameters+DMA_DST
    jsr physical
    ldaa #$5a
    staa parameters+DMA_VALUE
    ldaa #DMA_FILL
    jsr run
    tsta
    beq *+5
    jmp test_failed
    jsr parameters_clear
    ldaa lease+3
    ldx #parameters+DMA_SRC
    jsr physical
    ldaa lease+4
    ldx #parameters+DMA_DST
    jsr physical
    ldaa #DMA_COPY
    jsr run
    tsta
    beq *+5
    jmp test_failed
    ldaa lease+4
    jsr select_bank
    ldx #$c000
verify_bank
    ldaa 0,x
    cmpa #$5a
    beq *+5
    jmp test_failed
    inx
    cpx #$e000
    bne verify_bank
    ldaa $e65e
    cmpa #'G'
    beq read_mode_saved
    inc read_mode
read_mode_saved
    clr $e652
    clr $e65d
    clr $e65f
    jsr parameters_clear
    ldaa #$5e
    staa parameters+DMA_SRC
    ldaa #$e6
    staa parameters+DMA_SRC+1
    ldaa lease+3
    ldx #parameters+DMA_DST
    jsr physical
    ldaa #DMA_SRC_PORT
    staa parameters+DMA_MODE
    ldaa #DMA_COPY
    jsr run
    tsta
    beq *+5
    jmp test_failed
    inc palette_saved
    jsr parameters_clear
    ldaa #$5e
    staa parameters+DMA_DST
    ldaa #$e6
    staa parameters+DMA_DST+1
    ldaa #DMA_DST_PORT
    staa parameters+DMA_MODE
    ldaa #21
    staa parameters+DMA_VALUE
    ldaa #DMA_FILL
    jsr run
    tsta
    beq *+5
    jmp test_failed
    ldaa #1
    staa $e65f
    clrb
verify_palette
    stab $e65d
    ldaa #127
    staa $e652
    ldaa $e65e
    cmpa #21
    beq *+5
    jmp test_failed
    incb
    cmpb #32
    bne verify_palette
    bra cleanup
test_failed
    inc failed
cleanup
    tst palette_saved
    beq release
    clr $e652
    clr $e65d
    clr $e65f
    jsr parameters_clear
    ldaa lease+3
    ldx #parameters+DMA_SRC
    jsr physical
    ldaa #$5e
    staa parameters+DMA_DST
    ldaa #$e6
    staa parameters+DMA_DST+1
    ldaa #DMA_DST_PORT
    staa parameters+DMA_MODE
    ldaa #DMA_COPY
    jsr run
    tsta
    beq palette_restored
    inc failed
    ; Even a failed DMA diagnostic must restore the display before exit.
    ldaa lease+3
    jsr select_bank
    clr $e652
    clr $e65d
    ldx #$c000
restore_cpu
    ldaa 0,x
    staa $e65e
    inx
    cpx #$e000
    bne restore_cpu
palette_restored
    ldaa read_mode
    staa $e65f
release
    ldaa saved_group
    staa $e6f1
    ldaa saved_page
    staa $e6f0
    tst allocated
    beq result
    ldx #lease
    ldaa #2
    int $e5
    tsta
    beq result
    inc failed
result
    ldx #pass_text
    tst failed
    beq message
    ldx #fail_text
message
    int $23
    ldaa failed
    int $38
unsupported
    inc failed
    ldx #need_dma
    bra message
no_memory
    inc failed
    ldx #need_memory
    bra message
parameters_clear
    ldx #parameters
    ldab #DMA_BYTES
clear_loop
    clr 0,x
    inx
    decb
    bne clear_loop
    ldaa #$20
    staa parameters+DMA_WIDTH+1
    ldaa #1
    staa parameters+DMA_HEIGHT
    rts
physical
    clr 0,x
    adda #17
    tab
    anda #7
    asla
    asla
    asla
    asla
    asla
    staa 1,x
    tba
    lsra
    lsra
    lsra
    staa 2,x
    rts
select_bank
    clrb
bank_group
    cmpa #6
    bcs bank_page
    suba #6
    incb
    bra bank_group
bank_page
    stab $e6f1
    inca
    staa $e6f0
    rts
run
    psha
    tpa
    psha
acquire
    sei
    tst DMA_STATUS
    bpl acquired
    tsx
    ldaa 0,x
    tap
    bra acquire
acquired
    clr DMA_INDEX
    ldx #parameters
    ldab #DMA_BYTES
send
    ldaa 0,x
    staa DMA_DATA
    inx
    decb
    bne send
    tsx
    ldaa 1,x
    staa DMA_COMMAND
    ldaa 0,x
    tap
    ins
    ins
wait
    ldaa DMA_STATUS
    bmi wait
    anda #DMA_ERROR
    rts
intro db 'DMATEST: two owned banks and PAL...',13,10,0
pass_text db 'PASS: DMA 8K copy/fill, PAL restored.',13,10,0
fail_text db 'FAIL: DMA verification.',13,10,0
need_dma db 'DMATEST: DMA FPGA + RAMMAN required.',13,10,0
need_memory db 'DMATEST: cannot allocate two banks.',13,10,0
    section
lease ds 5
parameters ds DMA_BYTES
saved_page ds 1
saved_group ds 1
allocated ds 1
palette_saved ds 1
failed ds 1
read_mode ds 1
    ends
    end start
