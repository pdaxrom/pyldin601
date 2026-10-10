; INT E2 raw SD block API, MC6800, no geometry or partition assumptions.
; A=0 capacity (X points to four LE bytes); A=1 read / A=2 write.
; Read/write descriptor X: buffer BE16, physical LBA LE32. One 512-byte sector.
; A returns native DOS errors: 0 OK, 4 range, 5 data/CRC, 6 I/O, 3 protection.
; X/B/page/SP are preserved by BIOS SWI. Caller interrupt mask is honored.
CAPACITY equ $bf9c
rawsd
    stx PARAM
    staa OP
    tsta
    beq raw_capacity
    cmpa #2
    bls raw_rw
    jmp raw_bad
raw_capacity
    jsr capacity_read
    tst STATUS
    beq raw_capacity_ok
    jmp raw_finish
raw_capacity_ok
    ldx PARAM
    ldaa CAPACITY
    staa 0,x
    ldaa CAPACITY+1
    staa 1,x
    ldaa CAPACITY+2
    staa 2,x
    ldaa CAPACITY+3
    staa 3,x
    bra raw_finish
raw_rw
    ldx PARAM
    ldaa 2,x
    staa LBA
    ldaa 3,x
    staa LBA+1
    ldaa 4,x
    staa LBA+2
    ldaa 5,x
    staa LBA+3
    ldx 0,x
    stx BUF
    ; End-exclusive capacity comparison, with all four address bytes.
    ldaa LBA
    suba CAPACITY
    ldaa LBA+1
    sbca CAPACITY+1
    ldaa LBA+2
    sbca CAPACITY+2
    ldaa LBA+3
    sbca CAPACITY+3
    bcc raw_bad
    ldaa BUF
    cmpa #1
    bcs raw_bad
    cmpa #$be
    bcs raw_buffer_ok
    beq raw_buffer_edge
    cmpa #$e0
    bcs raw_bad
    cmpa #$e4
    bcs raw_buffer_ok
    beq raw_buffer_edge
    cmpa #$e7
    bcs raw_bad
    cmpa #$ee
    bcs raw_buffer_ok
    bne raw_bad
raw_buffer_edge
    tst BUF+1
    bne raw_bad
raw_buffer_ok
    ldaa $04
    bita #$10
    bne raw_masked
    cli
raw_masked
    ldaa OP
    cmpa #1
    bne raw_write
    ldaa #'R'
    jsr indicator
    jsr sector_read
    bra raw_finish
raw_write
    ldaa #'W'
    jsr indicator
    jsr sector_write
raw_finish
    sei
    jsr release
    clra
    jsr indicator
    ldaa STATUS
    beq raw_return
    cmpa #4
    beq raw_return
    cmpa #$10
    bne raw_not_crc
    ldaa #5
    bra raw_return
raw_not_crc
    cmpa #$40
    bne raw_io_error
    ldaa #3
    bra raw_return
raw_io_error
    ldaa #6
raw_return
    staa SWIA
    rts
raw_bad
    ldaa #4
    staa STATUS
    jmp raw_finish

; CMD9: acquire and validate CSD including CRC, then calculate 512-byte count.
; Temporary CSD storage is on the stack; BF9C-BF9F retains only capacity.
capacity_read
    clr STATUS
    clr CAPACITY
    clr CAPACITY+1
    clr CAPACITY+2
    clr CAPACITY+3
    sts SAVED_SP
    sts BUF
    ldaa BUF+1
    suba #16
    staa BUF+1
    ldaa BUF
    sbca #0
    staa BUF
    lds BUF
    tsx
    stx INIT_BUF
    clr ARG
    clr ARG+1
    clr ARG+2
    clr ARG+3
    ldaa #$49
    staa CMD
    jsr command
    tst STATUS
    beq cap_command_ok
    jmp cap_done
cap_command_ok
    tsta
    beq cap_token_start
    jmp cap_fail
cap_token_start
    ldx #$ffff
    stx COUNT
cap_token
    jsr spi_read
    bcs cap_fail
    cmpa #$fe
    beq cap_bytes_start
    cmpa #$ff
    bne cap_fail
    ldx COUNT
    dex
    stx COUNT
    bne cap_token
    bra cap_fail
cap_bytes_start
    clr CRC
    clr CRC+1
    ldx INIT_BUF
    stx BUF
    ldaa #16
    staa COUNT+1
cap_bytes
    jsr spi_read
    bcs cap_fail
    ldx BUF
    staa 0,x
    inx
    stx BUF
    jsr crc_byte
    dec COUNT+1
    bne cap_bytes
    jsr spi_read
    bcs cap_fail
    cmpa CRC
    bne cap_fail
    jsr spi_read
    bcs cap_fail
    cmpa CRC+1
    bne cap_fail
    ldx INIT_BUF
    ldaa 0,x
    anda #$c0
    beq cap_v1
    cmpa #$40
    bne cap_fail
    ldaa SD_INFO
    bita #1
    beq cap_fail
    ; CSD v2 C_SIZE, then (C_SIZE+1)*1024.
    ldaa 9,x
    staa CAPACITY
    ldaa 8,x
    staa CAPACITY+1
    ldaa 7,x
    anda #$3f
    staa CAPACITY+2
    ldaa #10
    staa FORMAT_LEFT
    bra cap_increment
cap_fail
    ldaa #$80
    staa STATUS
cap_done
    lds SAVED_SP
    rts
cap_v1
    ldaa SD_INFO
    bita #1
    bne cap_fail
    ; 12-bit C_SIZE in bits 73..62.
    ldaa 8,x
    lsra
    lsra
    lsra
    lsra
    lsra
    lsra
    staa CAPACITY
    ldaa 7,x
    asla
    asla
    oraa CAPACITY
    staa CAPACITY
    ldaa 7,x
    lsra
    lsra
    lsra
    lsra
    lsra
    lsra
    staa CAPACITY+1
    ldaa 6,x
    anda #3
    asla
    asla
    oraa CAPACITY+1
    staa CAPACITY+1
    clr CAPACITY+2
    ; READ_BL_LEN + C_SIZE_MULT - 7 is sectors' power of two.
    ldaa 10,x
    lsra
    lsra
    lsra
    lsra
    lsra
    lsra
    lsra
    staa FORMAT_LEFT
    ldaa 9,x
    anda #3
    asla
    oraa FORMAT_LEFT
    staa FORMAT_LEFT
    ldaa 5,x
    anda #15
    adda FORMAT_LEFT
    suba #7
    bcs cap_fail
    cmpa #24
    bhi cap_fail
    staa FORMAT_LEFT
cap_increment
    inc CAPACITY
    bne cap_shift_start
    inc CAPACITY+1
    bne cap_shift_start
    inc CAPACITY+2
    bne cap_shift_start
    inc CAPACITY+3
    beq cap_fail
cap_shift_start
    tst FORMAT_LEFT
    beq cap_done
cap_shift
    asl CAPACITY
    rol CAPACITY+1
    rol CAPACITY+2
    rol CAPACITY+3
    bcc cap_shift_ok
    jmp cap_fail
cap_shift_ok
    dec FORMAT_LEFT
    bne cap_shift
    jmp cap_done
