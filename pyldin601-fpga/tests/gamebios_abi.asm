; Real HD6303/MC6800 test program for production VHDL CPU + native dispatch.
    org $0800
    include GAMEBIOS.INC
start
    sei
    lds #$9fff
    ldaa #$a3
    staa $e6f0
    ldaa #18
    staa $e6f1
    clra
    int GB_INT
    cmpa #GB_ABI
    beq *+5
    jmp fail
    cpx #GB_CONTEXT_BYTES
    beq *+5
    jmp fail
    bitb #GB_FEATURE_BATCH
    bne *+5
    jmp fail
    ldaa $e6a0
    bita #2
    bne extended
    ldaa #GB_OPEN
    ldx #$5000
    int GB_INT
    cmpa #GB_NEED_HD6303
    beq *+5
    jmp fail
    jmp passed
fail
    ldaa #$de
    staa $070f
    bra fail
extended
    ldaa #1
    ldab #111
    ldx #banklease
    int $e5
    tsta
    beq *+5
    jmp fail
    ldaa #$5a
    staa $9000
    ldx #bankput
    ldaa #1
    int $e8
    tsta
    beq *+5
    jmp fail
    ldx #bankget
    ldaa #1
    int $e8
    tsta
    beq *+5
    jmp fail
    ldaa $9100
    cmpa #$5a
    beq *+5
    jmp fail
    ldaa #2
    ldx #banklease
    int $e5
    tsta
    beq *+5
    jmp fail
    ldx #$5000
    ldd #GB_CONTEXT_BYTES
    std 0,x
    ldaa #GB_ABI
    staa 2,x
    ldaa #GB_VIDEO+GB_AUDIO
    staa 3,x
    ldaa #GB_OPEN
    jsr call
    ldaa #GB_MODE
    ldab #1
    jsr call
    ldaa #GB_TARGET
    clrb
    jsr call
    ldaa #GB_RECT
    ldx #rectangle
    jsr call
    ldaa #GB_READPIX
    ldx #pixel
    jsr call
    cmpb #23
    beq *+5
    jmp fail
    ldaa #GB_PUTS
    ldx #text
    jsr call
    ldaa #GB_BATCH
    ldab #3
    ldx #batch
    jsr call
    cmpb #3
    beq *+5
    jmp fail
    cpx #batch
    beq *+5
    jmp fail
    ldaa #GB_TARGET
    clrb
    jsr call
    ldaa #GB_READPIX
    ldx #batch_pixel
    jsr call
    cmpb #42
    beq *+5
    jmp fail
    ldaa #GB_MODE
    ldab #7
    jsr call
    ldaa #GB_PIXEL
    ldx #pixel
    int GB_INT
    cmpa #GB_UNSUPPORTED
    beq *+5
    jmp fail
    ldaa #GB_NOTE
    ldx #note
    jsr call
    ldaa #GB_MODE
    ldab #1
    jsr call
    ldaa #GB_FRAME
    ldx #music
    jsr call
    ldaa #GB_PLAY
    ldab #1
    jsr call
    cli
wait_music
    ldaa #GB_STATUS
    jsr call
    cpx #6
    bcs wait_music
    ldx #bankirq
    ldaa #1
    int $e8
    tsta
    beq *+5
    jmp fail
    ldaa #GB_BATCH
    ldab #32
    ldx #batch_text
    jsr call
    ; A completed failed raw command must still be reported in the active
    ; context, but must not prevent CLOSE restoring the video owner.
    ldaa #$ff
    staa $e651
    ldaa #GB_MODE
    ldab #1
    int GB_INT
    cmpa #GB_HARDWARE
    beq *+5
    jmp fail
    ldaa #GB_CLOSE
    jsr call
passed
    ldaa $e6f0
    cmpa #$a3
    beq *+5
    jmp fail
    ldaa $e6f1
    cmpa #18
    beq *+5
    jmp fail
    ldaa #$a5
    staa $070f
halt
    bra halt
call
    int GB_INT
    tsta
    beq *+5
    jmp fail
    rts
rectangle dw -3,-4,8
    db 9,23
pixel dw 0,0
    db 33
text db 'OK',0
note db 1,46,0,4,10
music db 17,0,28,1,0,0,0,$38,3,4,5,0,0,$ff
batch
    db GB_TARGET,2
    dw 0
    db GB_RECT,0
    dw batch_rect
    db GB_COPY,0
    dw batch_copy
batch_rect dw 5,7,4
    db 2,42
batch_copy db 2,0,2,0
    dw 2245,2889,4
    db 2
batch_pixel dw 9,9
batch_text
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
    db GB_PUTC,'W'
    dw 0
bankput db $ff,110
    dw $9000,13,1
bankget db 110,$ff
    dw 13,$9100,1
bankirq db $ff,$ff
    dw $6000,$7000,4096
banklease ds 114
    end start
