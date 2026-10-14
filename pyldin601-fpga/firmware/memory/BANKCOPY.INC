; Fixed native BIOS service, INT E8, ABI1. No permanent RAM or copied code.
; A=0 INFO -> A=1,B=7,X=8192. Other calls preserve public B/X and CCR.
; A=1 memmove, X=8 ordinary bytes: src/dst bank (FF=ordinary RAM),
; sourceBE,destinationBE,lengthBE. Bank addresses are offsets 0..1FFF.
; Ordinary ranges: 0100..BDFF. Length 0..8192; no crossing a bank boundary.
; A=2 PAL -> bank B; A=3 bank B -> PAL, complete 8192-byte waveform table.
; Result A=0 OK,1 argument,2 missing hardware,3 needs HD6303.
; Caller owns banks, code/stack/descriptor outside C000..DFFF. No allocation.
; Stack frame is private; IRQs remain enabled and retain both page selectors.
    global bank_copy
    ds $f640-*,$ff
bank_copy
    cmpa #4
    bne bc_public
    jmp bc_system_fat
bc_public
    tsta
    beq bc_info
    cmpa #4
    bcc bc_arg
    ldaa $e6a0
    bita #2
    bne bc_cpu
    ldaa #3
    staa swia
    rts
bc_info
    ldaa #1
    staa swia
    ldaa #7
    staa swib
    ldx #8192
    stx swix
    rts
bc_arg
    ldaa #1
    staa swia
    rts
bc_cpu
    ldaa $e6f2
    cmpa #'R'
    beq bc_hw
    ldaa #2
    staa swia
    rts
bc_hw
    ldaa swia
    cmpa #1
    beq bc_move
    jmp bc_pal
bc_move
    cpx #$100
    bcs bc_arg
    cpx #$be00-8
    bhi bc_arg
    ; Push the descriptor backwards, then reserve eight stack-local bytes.
    ldab #8
    abx
bc_desc
    dex
    ldaa 0,x
    psha
    decb
    bne bc_desc
    ldab #8
bc_space
    des
    decb
    bne bc_space
    tsx
    ldaa $e6f1
    staa 4,x
    ldaa $e6f0
    staa 5,x
    clr 6,x
    clr 7,x
    ldd 14,x
    subd #8192
    bls bc_length
    jmp bc_bad
bc_length
    ldaa 8,x
    jsr bc_map
    bcc *+5
    jmp bc_bad
    staa 0,x
    stab 1,x
    ldaa 9,x
    jsr bc_map
    bcc *+5
    jmp bc_bad
    staa 2,x
    stab 3,x
    ; Validate all ranges before any write. X continues to point at frame.
    ldaa 10,x
    ldab 8,x
    jsr bc_range
    bcc *+5
    jmp bc_bad
    ldaa 12,x
    ldab 9,x
    jsr bc_range
    bcc *+5
    jmp bc_bad
    ldd 14,x
    bne *+5
    jmp bc_done
    ldaa 8,x
    cmpa #$ff
    beq bc_dst
    ldaa 10,x
    adda #$c0
    staa 10,x
bc_dst
    ldaa 9,x
    cmpa #$ff
    beq bc_overlap
    ldaa 12,x
    adda #$c0
    staa 12,x
bc_overlap
    ldaa 8,x
    cmpa 9,x
    bne bc_next
    ldd 12,x
    subd 10,x
    bls bc_next
    inc 6,x
    ldd 10,x
    addd 14,x
    subd #1
    std 10,x
    ldd 12,x
    addd 14,x
    subd #1
    std 12,x
bc_next
    ldaa 0,x
    staa $e6f1
    ldaa 1,x
    staa $e6f0
    ldx 10,x
    ldaa 0,x
    tsx
    staa 7,x
    ldaa 2,x
    staa $e6f1
    ldaa 3,x
    staa $e6f0
    ldaa 7,x
    ldx 12,x
    staa 0,x
    tsx
    ldd 14,x
    subd #1
    std 14,x
    beq bc_done
    tst 6,x
    beq bc_forward
    ldd 10,x
    subd #1
    std 10,x
    ldd 12,x
    subd #1
    std 12,x
    bra bc_next
bc_forward
    ldd 10,x
    addd #1
    std 10,x
    ldd 12,x
    addd #1
    std 12,x
    bra bc_next
bc_bad
    ldaa #1
    bra bc_return
bc_done
    clra
bc_return
    staa swia
    ldaa 4,x
    staa $e6f1
    ldaa 5,x
    staa $e6f0
    ldab #16
bc_unstack
    ins
    decb
    bne bc_unstack
    rts
; A=bank ID -> A=group,B=page,C=0. FF denotes ordinary memory below BE00.
bc_map
    cmpa #$ff
    bne bc_bank
    clra
    ldab #7
    rts
bc_bank
    cmpa #111
    bcc bc_invalid
    clrb
bc_div
    cmpa #6
    bcs bc_mapped
    suba #6
    incb
    bra bc_div
bc_mapped
    inca
    psha
    tba
    pulb
    clc
    rts
bc_invalid
    sec
    rts
; A=address high,B=selector,X=frame. Byte 7 selects source/destination.
; Reload the full pointer for the end check; reject before any write.
bc_range
    ; B is selector, A retained address high. Validate high first.
    cmpb #$ff
    bne bc_rbank
    tsta
    beq bc_invalid
    cmpa #$be
    bcc bc_invalid
    bra bc_rend
bc_rbank
    cmpa #$20
    bcc bc_invalid
bc_rend
    ; Push selector while calculating the 16-bit end; carry detects wrap.
    pshb
    ldaa 7,x
    beq bc_rsrc
    ldd 12,x
    bra bc_rsum
bc_rsrc
    ldd 10,x
bc_rsum
    addd 14,x
    pulb
    bcs bc_invalid
    cmpb #$ff
    bne bc_rbend
    cmpa #$be
    bra bc_requal
bc_rbend
    cmpa #$20
bc_requal
    bcs bc_valid
    bne bc_invalid
    ; At the exact high limit only a zero low byte is legal.
    ; Recompute end low without losing the comparison.
    ldaa 7,x
    beq bc_rlsrc
    ldd 12,x
    bra bc_rlsum
bc_rlsrc
    ldd 10,x
bc_rlsum
    addd 14,x
    tstb
    bne bc_invalid
bc_valid
    clc
    inc 7,x
    rts
bc_pal
    ; FF is not a PAL bank, even though ordinary transfers accept it.
    ldaa swib
    cmpa #111
    bcc bc_arg_far
    clr $e65f
    ldaa $e65e
    cmpa #'G'
    beq bc_pal_hw
    ldaa #2
    staa swia
    rts
bc_pal_hw
    ldaa swib
    jsr bc_map
    pshb
    psha
    ldaa $e6f0
    psha
    ldaa $e6f1
    psha
    tsx
    ldaa 2,x
    staa $e6f1
    ldaa 3,x
    staa $e6f0
    clr $e652
    clr $e65d
    clr $e65f
    ldx #$c000
    ldaa swia
    cmpa #2
    bne bc_pal_write
    ldaa #1
    staa $e65f
bc_pal_read
    ldaa $e65e
    staa 0,x
    inx
    ldaa #3
    staa $e65f
    cpx #$e000
    bne bc_pal_read
    bra bc_pal_done
bc_pal_write
    ldaa 0,x
    staa $e65e
    inx
    cpx #$e000
    bne bc_pal_write
bc_pal_done
    clr $e65f
    pula
    staa $e6f1
    pula
    staa $e6f0
    ins
    ins
    clr swia
    rts
bc_arg_far
    jmp bc_arg

; Private MC6800-compatible transfer of the kernel's fixed E700 FAT buffer.
; Only the owned descriptor at EAD0 is accepted. RAMMAN supplies the lease;
; the kernel checks hardware before using it. Public operations 0..3 retain
; their former ABI and ISA requirements.
bc_system_fat
    cpx #$ead0
    bne bc_arg_far
    jmp native_fat_copy
native_fat_copy_done
    pula
    staa $e6f1
    pula
    staa $e6f0
    clr swia
    rts
