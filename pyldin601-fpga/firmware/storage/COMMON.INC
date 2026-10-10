; Shared MC6800 utility code. All variables belong to this relocatable PGM.
; Arguments are copied by native UniDOS INT3C, never read from DOS scratch.
argument
    ldx #argtext
    int $3c
    ldx #argtext
argument_upper
    ldaa 0,x
    beq argument_done
    cmpa #'a'
    bcs argument_next
    cmpa #'z'
    bhi argument_next
    suba #32
    staa 0,x
argument_next
    inx
    bra argument_upper
argument_done
    ldx #argtext
    rts
; X input, PT output string. C clear for an exact match.
match
    stx ptr
match_loop
    ldx ptr
    ldaa 0,x
    inx
    stx ptr
    ldx pat
    cmpa 0,x
    bne match_bad
    inx
    stx pat
    tsta
    bne match_loop
    clc
    rts
match_bad
    sec
    rts
parse_device
    ldx #device_name
    stx pat
    ldx #argtext
    ldab #8
parse_prefix
    ldaa 0,x
    inx
    stx ptr
    ldx pat
    cmpa 0,x
    bne parse_bad
    inx
    stx pat
    ldx ptr
    decb
    bne parse_prefix
    jsr parse_decimal
    bcc common_skip_000
    jmp parse_bad
common_skip_000
    ldaa number+1
    oraa number+2
    oraa number+3
    bne parse_bad
    ldaa number
    bne common_skip_001
    jmp parse_bad
common_skip_001
    cmpa #36
    bhi parse_bad
    staa part
    clc
    rts
parse_bad
    sec
    rts
; Unsigned decimal LE32, overflow detected. X advances through the full token.
parse_decimal
    stx ptr
    clr number
    clr number+1
    clr number+2
    clr number+3
    clr digits
parse_digit
    ldx ptr
    ldaa 0,x
    bne common_skip_002
    jmp decimal_done
common_skip_002
    cmpa #'0'
    bcc common_skip_003
    jmp parse_bad
common_skip_003
    cmpa #'9'
    bhi parse_bad
    suba #'0'
    staa digit
    inx
    stx ptr
    inc digits
    ldaa number
    staa temp
    ldaa number+1
    staa temp+1
    ldaa number+2
    staa temp+2
    ldaa number+3
    staa temp+3
    asl number
    rol number+1
    rol number+2
    rol number+3
    bcc common_skip_004
    jmp parse_bad
common_skip_004
    asl temp
    rol temp+1
    rol temp+2
    rol temp+3
    bcc common_skip_005
    jmp parse_bad
common_skip_005
    asl temp
    rol temp+1
    rol temp+2
    rol temp+3
    bcc common_skip_006
    jmp parse_bad
common_skip_006
    asl temp
    rol temp+1
    rol temp+2
    rol temp+3
    bcc common_skip_007
    jmp parse_bad
common_skip_007
    ldaa number
    adda temp
    staa number
    ldaa number+1
    adca temp+1
    staa number+1
    ldaa number+2
    adca temp+2
    staa number+2
    ldaa number+3
    adca temp+3
    staa number+3
    bcc common_skip_008
    jmp parse_bad
common_skip_008
    ldaa number
    adda digit
    staa number
    ldaa number+1
    adca #0
    staa number+1
    ldaa number+2
    adca #0
    staa number+2
    ldaa number+3
    adca #0
    staa number+3
    bcc common_skip_009
    jmp parse_bad
common_skip_009
    jmp parse_digit
decimal_done
    tst digits
    bne common_skip_010
    jmp parse_bad
common_skip_010
    clc
    rts
print_hex
    psha
    lsra
    lsra
    lsra
    lsra
    jsr print_nibble
    pula
    anda #15
print_nibble
    adda #'0'
    cmpa #'9'
    bls nibble_out
    adda #7
nibble_out
    int $22
    rts
print_number
    clrb
print_tens
    cmpa #10
    bcs print_units
    suba #10
    incb
    bra print_tens
print_units
    psha
    tba
    adda #'0'
    int $22
    pula
    adda #'0'
    int $22
    rts
finish_result
    tsta
    beq success
    staa error
    ldx #error_msg
    int $23
    ldaa error
    jsr print_hex
    ldx #newline
    int $23
    int $38
success
    ldx #ok_msg
    int $23
    int $38
usage
    ldx #usage_msg
    int $23
    int $38
ptr dw 0
pat dw 0
number ds 4
temp ds 4
digits db 0
digit db 0
part db 0
error db 0
argc db 0
argtext ds 81
record ds 24
device_name db "SD0:PART"
type_name db "/T:FAT12",0
newline db 13,10,0
error_msg db "SD: error $",0
