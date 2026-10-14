; X=32-bit little-endian integer -> zero-terminated decimal, no 64K truncation.
decimal_le
    ldaa 3,x
    staa number
    ldaa 2,x
    staa number+1
    ldaa 1,x
    staa number+2
    ldaa 0,x
    staa number+3
decimal_number
    ldaa #10
    staa number_divisor
    ldx #number_text+10
    clr 0,x
    stx number_ptr
decimal_digit
    jsr divide_number
    ldaa remainder
    adda #'0'
    ldx number_ptr
    dex
    staa 0,x
    stx number_ptr
    ldaa number
    oraa number+1
    oraa number+2
    oraa number+3
    bne decimal_digit
    ; Stop when the quotient reaches zero, rather than doing ten complete
    ; 32-bit divisions for every small file on every newly exposed row.
    ldx number_ptr
    stx src
    ldx #number_text
    stx dst
    jsr copy_z
    rts
; Unsigned BE32 / byte, quotient in number, remainder in remainder.
divide_number
    clr remainder
    ldx #number
    ldab #4
decimal_byte
    pshb
    ldab #8
decimal_bit
    asl 0,x
    rol remainder
    ldaa remainder
    cmpa number_divisor
    bcs decimal_less
    suba number_divisor
    staa remainder
    inc 0,x
decimal_less
    decb
    bne decimal_bit
    inx
    pulb
    decb
    bne decimal_byte
    rts
