; Complete UniDOS shell in one ROM page, MC6800/HD6303 compatible.
; Uniload LZ format recovered from native/RAMROMDiskPipnet/str$0a.roz.
; SHELLPACK.INC is generated from the owned, UniAS-assembled UNIDOS.ASM.
; SP reads packed ROM/backrefs with IRQ masked. Save every borrowed byte of
; zero page and restore the ordinary stack and incoming IRQ mask before RTS.
flags_lo equ $80
flags_hi equ $81
bits_left equ $82
saved_a equ $83
destination equ $84
copy_length equ $86
backref equ $88
packed_stack equ $8a
caller_stack equ $8c
    org $c000
    dw $5aa5
    db "UniShell"
    jmp shell_init
    jmp shell_init
    db $01
    dw shell_start
    db $e3
    dw shell_copy
    db 0
shell_init
    rts
shell_start
    jsr shell_copy
    jmp $1000
shell_copy
    tpa
    psha
    sei
    ldx #flags_lo
    ldab #14
save_scratch
    ldaa 0,x
    psha
    inx
    decb
    bne save_scratch
    sts caller_stack
    lds #shell_bytes-1
    pula
    staa flags_lo
    pula
    staa flags_hi
    ldaa #16
    staa bits_left
    ldx #$1000
save_destination
    stx destination
    ldx #literal_test
    bra get_bit
literal_test
    bcc reference
    ldx destination
    pula
    staa 0,x
    inx
    bra save_destination
reference
    ldx #kind_test
    bra get_bit
kind_test
    bcs long_reference
    clrb
    ldx #short_length_high
    bra get_bit
short_length_high
    rolb
    ldx #short_length_low
    bra get_bit
short_length_low
    rolb
    addb #2
    stab copy_length
    ldaa #$ff
    pulb
    jmp calculate_reference
long_reference
    pulb
    stab backref
    pula
    tab
    asra
    asra
    asra
    oraa #$e0
    andb #7
    bne adjust_length
    pulb
    tstb
    beq finished
    decb
    decb
adjust_length
    incb
    incb
    stab copy_length
    ldab backref
calculate_reference
    addb destination+1
    adca destination
    staa backref
    stab backref+1
    sts packed_stack
    lds backref
    des
    ldx destination
copy_reference
    pula
    staa 0,x
    inx
    dec copy_length
    bne copy_reference
    lds packed_stack
    bra save_destination
get_bit
    staa saved_a
    ldaa bits_left
    deca
    staa bits_left
    bita #8
    beq shift_high
    asr flags_lo
    bra shifted
shift_high
    asr flags_hi
shifted
    tpa
    tst bits_left
    bne restore_flags
    tap
    pula
    staa flags_lo
    pula
    staa flags_hi
    ldaa #16
    staa bits_left
    tpa
restore_flags
    tap
    ldaa saved_a
    jmp 0,x
finished
    lds caller_stack
    ldx #flags_lo+14
    ldab #14
restore_scratch
    dex
    pula
    staa 0,x
    decb
    bne restore_scratch
    pula
    tap
shell_return
    rts
shell_bytes
    include SHELLPACK.INC
shell_end
    error */$e000
    ds $dfff-*,$ff
    checksum
    end
