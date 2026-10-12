; Standalone MC6800 SRAM diagnostic. No SD access, no ROM commit, repeats forever.
; The bottom 8 KiB hold its stack/UI. Font SRAM 61000-617FF is skipped so
; the seeded EBR font stays readable; all other physical bytes are tested.
; Each pattern fills the whole range before verification, detecting aliases.
    .ifdef SRAM_SMOKE
B_LIMIT_HIGH equ 0
B_LIMIT_MID equ $21
    .else
B_LIMIT_HIGH equ $20
B_LIMIT_MID equ 0
    .endif
B_LIMIT_LOW equ 0
B_ADDR equ $e6a4
B_STORE equ $e6a7
B_BUSY equ $e6a8
B_READ equ $e6ab
B_DEBUG equ $e6a1
B_POS equ $80
B_BANK equ $82
B_PAT equ $83
B_PHASE equ $84
B_EXPECT equ $85
B_ACTUAL equ $86
B_ROUNDS equ $87
B_DEST equ $89
B_TEXT equ $8b
B_SAVE equ $8d
    org $f000
    jmp start
start
    sei
    lds #$1fff
    clr $e629
    clr B_ROUNDS
    clr B_ROUNDS+1
    ldx #$400
    ldaa #' '
clear_screen
    staa 0,x
    inx
    cpx #$7c0
    bne clear_screen
    ldx #crtc_init
    clrb
init_crtc
    stab $e600
    ldaa 0,x
    staa $e601
    inx
    incb
    cmpb #16
    bne init_crtc
    ldx #$400
    stx B_DEST
    ldx #title
    jsr puts
    ldx #$4f0
    stx B_DEST
    ldx #range_text
    jsr puts
    ldx #$540
    stx B_DEST
    ldx #font_text
    jsr puts
    ldx #$590
    stx B_DEST
    ldx #running_text
    jsr puts
round
    clr B_PAT
next_pattern
    clr B_PHASE
    jsr scan
    inc B_PHASE
    jsr scan
    inc B_PAT
    ldaa B_PAT
    cmpa #5
    bne next_pattern
    ldx B_ROUNDS
    inx
    stx B_ROUNDS
    ldx #$5e0
    stx B_DEST
    ldx #pass_text
    jsr puts
    ldaa B_ROUNDS
    jsr hex
    ldaa B_ROUNDS+1
    jsr hex
    ldaa #$d1
    staa B_DEBUG
    bra round
scan
    clr B_BANK
    ldx #$2000
    jsr set_address
    jsr progress
scan_byte
    ; End is a 24-bit exclusive physical address; only test fixtures shorten it.
    ldaa B_BANK
    cmpa #B_LIMIT_HIGH
    bne in_range
    stx B_POS
    ldaa B_POS
    cmpa #B_LIMIT_MID
    bne in_range
    ldaa B_POS+1
    cmpa #B_LIMIT_LOW
    beq scan_done
in_range
    ; Keep the live font EBR unchanged during the destructive diagnostic.
    ldaa B_BANK
    cmpa #6
    bne test_byte
    cpx #$1000
    bne test_byte
    ldx #$1800
    jsr set_address
test_byte
    jsr pattern
    staa B_EXPECT
    tst B_PHASE
    bne read_byte
    staa B_STORE
    jsr wait_memory
    bra advance
read_byte
    clr B_READ
    jsr wait_memory
    ldaa B_READ
    staa B_ACTUAL
    cmpa B_EXPECT
    beq sram_branch_1
    jmp mismatch
sram_branch_1
advance
    inx
    bne scan_byte
    inc B_BANK
    jsr progress
    bra scan_byte
scan_done
    rts
set_address
    stx B_POS
    ldaa B_POS+1
    staa B_ADDR
    ldaa B_POS
    staa B_ADDR+1
    ldaa B_BANK
    staa B_ADDR+2
    rts
wait_memory
    ldaa B_BUSY
    bpl sram_branch_2
    jmp port_error
sram_branch_2
    bita #1
    bne wait_memory
    rts
pattern
    stx B_POS
    ldab B_PAT
    beq constant55
    decb
    beq constantaa
    decb
    beq address_low
    decb
    beq address_mid
    ldaa B_BANK
    rts
constant55
    ldaa #$55
    rts
constantaa
    ldaa #$aa
    rts
address_low
    ldaa B_POS+1
    rts
address_mid
    ldaa B_POS
    rts
progress
    stx B_SAVE
    ldx #$450
    stx B_DEST
    ldx #pattern_text
    jsr puts
    ldaa B_PAT
    jsr hex
    ldx #write_text
    tst B_PHASE
    beq phase_text
    ldx #read_text
phase_text
    jsr puts
    ldaa B_BANK
    jsr hex
    ldx B_SAVE
    rts
port_error
    stx B_POS
    ldx #$630
    stx B_DEST
    ldx #port_text
    jsr puts
    bra halt
mismatch
    stx B_POS
    ldx #$630
    stx B_DEST
    ldx #fault_text
    jsr puts
    ldaa B_BANK
    jsr hex
    ldaa B_POS
    jsr hex
    ldaa B_POS+1
    jsr hex
    ldx #expect_text
    jsr puts
    ldaa B_EXPECT
    jsr hex
    ldx #actual_text
    jsr puts
    ldaa B_ACTUAL
    jsr hex
halt
    ldaa #$ee
    staa B_DEBUG
stop
    bra stop
puts
    ldab 0,x
    beq string_done
    stx B_TEXT
    ldx B_DEST
    stab 0,x
    inx
    stx B_DEST
    ldx B_TEXT
    inx
    bra puts
string_done
    rts
hex
    psha
    lsra
    lsra
    lsra
    lsra
    jsr nibble
    pula
nibble
    anda #$0f
    cmpa #10
    bcs digit
    adda #7
digit
    adda #'0'
    ldx B_DEST
    staa 0,x
    inx
    stx B_DEST
    rts
crtc_init
    db 63,40,46,8,38,0,24,36,0,7,$20,7,4,0,0,0
title
    db "PYLDIN-601 SRAM TEST",0
range_text
    db "RANGE 002000-1FFFFF  2038 KiB",0
font_text
    db "SKIP STACK/UI AND FONT 061000-0617FF",0
running_text
    db "55 / AA / ADDRESS LOW / MID / HIGH",0
pass_text
    db "ALL FIVE PATTERNS OK. ROUNDS ",0
pattern_text
    db "PATTERN ",0
write_text
    db " WRITE BANK ",0
read_text
    db " READ  BANK ",0
fault_text
    db "FAIL AT ",0
expect_text
    db " EXPECT ",0
actual_text
    db " GOT ",0
port_text
    db "FAIL - SRAM PORT ERROR",0
    ds $fff8-*,$ff
    org $fff8
    dw port_error,port_error,port_error,$f000
    end
