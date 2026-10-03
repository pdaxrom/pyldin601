; Standalone MC6800 SRAM diagnostic. No SD access, no ROM commit, repeats forever.
; The bottom 8 KiB hold its stack/UI. Font SRAM 61000-617FF is skipped so
; the seeded EBR font stays readable; all other physical bytes are tested.
; Each pattern fills the whole range before verification, detecting aliases.
LIMIT_HIGH equ $20
LIMIT_MID equ 0
LIMIT_LOW equ 0
ADDR equ $e6a4
STORE equ $e6a7
BUSY equ $e6a8
READ equ $e6ab
DEBUG equ $e6a1
POS equ $80
BANK equ $82
PAT equ $83
PHASE equ $84
EXPECT equ $85
ACTUAL equ $86
ROUNDS equ $87
DEST equ $89
TEXT equ $8b
SAVE equ $8d
    org $f000
    jmp start
start:
    sei
    lds #$1fff
    clr $e629
    clr ROUNDS
    clr ROUNDS+1
    ldx #$400
    ldaa #' '
clear_screen:
    staa 0,x
    inx
    cpx #$7c0
    bne clear_screen
    ldx #crtc_init
    clrb
init_crtc:
    stab $e600
    ldaa 0,x
    staa $e601
    inx
    incb
    cmpb #16
    bne init_crtc
    ldx #$400
    stx DEST
    ldx #title
    jsr puts
    ldx #$4f0
    stx DEST
    ldx #range_text
    jsr puts
    ldx #$540
    stx DEST
    ldx #font_text
    jsr puts
    ldx #$590
    stx DEST
    ldx #running_text
    jsr puts
round:
    clr PAT
next_pattern:
    clr PHASE
    jsr scan
    inc PHASE
    jsr scan
    inc PAT
    ldaa PAT
    cmpa #5
    bne next_pattern
    ldx ROUNDS
    inx
    stx ROUNDS
    ldx #$5e0
    stx DEST
    ldx #pass_text
    jsr puts
    ldaa ROUNDS
    jsr hex
    ldaa ROUNDS+1
    jsr hex
    ldaa #$d1
    staa DEBUG
    bra round
scan:
    clr BANK
    ldx #$2000
    jsr set_address
    jsr progress
scan_byte:
    ; End is a 24-bit exclusive physical address; only test fixtures shorten it.
    ldaa BANK
    cmpa #LIMIT_HIGH
    bne in_range
    stx POS
    ldaa POS
    cmpa #LIMIT_MID
    bne in_range
    ldaa POS+1
    cmpa #LIMIT_LOW
    beq scan_done
in_range:
    ; Keep the live font EBR unchanged during the destructive diagnostic.
    ldaa BANK
    cmpa #6
    bne test_byte
    cpx #$1000
    bne test_byte
    ldx #$1800
    jsr set_address
test_byte:
    jsr pattern
    staa EXPECT
    tst PHASE
    bne read_byte
    staa STORE
    jsr wait_memory
    bra advance
read_byte:
    clr READ
    jsr wait_memory
    ldaa READ
    staa ACTUAL
    cmpa EXPECT
    lbne mismatch
advance:
    inx
    bne scan_byte
    inc BANK
    jsr progress
    bra scan_byte
scan_done:
    rts
set_address:
    stx POS
    ldaa POS+1
    staa ADDR
    ldaa POS
    staa ADDR+1
    ldaa BANK
    staa ADDR+2
    rts
wait_memory:
    ldaa BUSY
    lbmi port_error
    bita #1
    bne wait_memory
    rts
pattern:
    stx POS
    ldab PAT
    beq constant55
    decb
    beq constantaa
    decb
    beq address_low
    decb
    beq address_mid
    ldaa BANK
    rts
constant55:
    ldaa #$55
    rts
constantaa:
    ldaa #$aa
    rts
address_low:
    ldaa POS+1
    rts
address_mid:
    ldaa POS
    rts
progress:
    stx SAVE
    ldx #$450
    stx DEST
    ldx #pattern_text
    jsr puts
    ldaa PAT
    jsr hex
    ldx #write_text
    tst PHASE
    beq phase_text
    ldx #read_text
phase_text:
    jsr puts
    ldaa BANK
    jsr hex
    ldx SAVE
    rts
port_error:
    stx POS
    ldx #$630
    stx DEST
    ldx #port_text
    jsr puts
    bra halt
mismatch:
    stx POS
    ldx #$630
    stx DEST
    ldx #fault_text
    jsr puts
    ldaa BANK
    jsr hex
    ldaa POS
    jsr hex
    ldaa POS+1
    jsr hex
    ldx #expect_text
    jsr puts
    ldaa EXPECT
    jsr hex
    ldx #actual_text
    jsr puts
    ldaa ACTUAL
    jsr hex
halt:
    ldaa #$ee
    staa DEBUG
stop:
    bra stop
puts:
    ldab 0,x
    beq string_done
    stx TEXT
    ldx DEST
    stab 0,x
    inx
    stx DEST
    ldx TEXT
    inx
    bra puts
string_done:
    rts
hex:
    psha
    lsra
    lsra
    lsra
    lsra
    jsr nibble
    pula
nibble:
    anda #$0f
    cmpa #10
    bcs digit
    adda #7
digit:
    adda #'0'
    ldx DEST
    staa 0,x
    inx
    stx DEST
    rts
crtc_init:
    db 63,40,46,8,38,0,24,36,0,7,$20,7,4,0,0,0
title:
    db "PYLDIN-601 SRAM TEST",0
range_text:
    db "RANGE 002000-1FFFFF  2038 KiB",0
font_text:
    db "SKIP STACK/UI AND FONT 061000-0617FF",0
running_text:
    db "55 / AA / ADDRESS LOW / MID / HIGH",0
pass_text:
    db "ALL FIVE PATTERNS OK. ROUNDS ",0
pattern_text:
    db "PATTERN ",0
write_text:
    db " WRITE BANK ",0
read_text:
    db " READ  BANK ",0
fault_text:
    db "FAIL AT ",0
expect_text:
    db " EXPECT ",0
actual_text:
    db " GOT ",0
port_text:
    db "FAIL - SRAM PORT ERROR",0
    org $fff8
    dw port_error,port_error,port_error,$f000
