; Permanent INT E8, DMA ABI1, MC6800/HD6303. Requires the current DMA FPGA.
; A=0 INFO -> A=1,B=7,X=8192. Other calls preserve public B/X and CCR.
; A=1 memmove, X=8 ordinary bytes: banks, srcBE,dstBE,lenBE.
; A=2 PAL -> bank B; A=3 bank B -> PAL, all 8192 samples.
; A=0 OK,1 argument,2 DMA/peripheral error. No CPU copy fallback.
; Frame: banks, srcBE,dstBE,lenBE,flags,saved CCR (10 bytes).
; No persistent RAM, no bank window changes; short SEI during setup only.
    global bank_copy
    ds $f640-*,$ff
bank_copy
    cmpa #4
    bne dma_public
    jmp bc_system_fat
dma_public
    tsta
    bne *+5
    jmp dma_info
    cmpa #4
    bcc dma_argument
    ldaa SWIA
    cmpa #1
    beq *+5
    jmp dma_palette
    ; MC6800 CPX leaves C unchanged: use saved X bytes for unsigned bounds.
    ldaa swix
    beq dma_argument
    cmpa #$be
    bcc dma_argument
    cmpa #$bd
    bne dma_descriptor_valid
    ldaa swix+1
    cmpa #$f8
    bhi dma_argument
dma_descriptor_valid
    ; SWI dispatch enables IRQ; SWIC retains the actual caller mask.
    ldaa swic
    psha
    clra
    psha
    ldab #8
dma_descriptor_end
    inx
    decb
    bne dma_descriptor_end
    ldab #8
dma_descriptor
    dex
    ldaa 0,x
    psha
    decb
    bne dma_descriptor
    tsx
    ldaa 6,x
    cmpa #$20
    bhi dma_invalid
    bne dma_length_ok
    tst 7,x
    bne dma_invalid
dma_length_ok
    ; Both endpoints validated before programming the engine.
    ldaa 0,x
    bsr dma_range_common
    bcs dma_invalid
    ldaa 2,x
    ldab 3,x
    pshb
    psha
    ldaa 4,x
    ldab 5,x
    staa 2,x
    stab 3,x
    ldaa 1,x
    bsr dma_range_common
    pula
    pulb
    staa 2,x
    stab 3,x
    bcs dma_invalid
    jmp dma_launch

dma_argument
    ldaa #1
    staa SWIA
    rts
dma_invalid
    ldaa #1
    jmp dma_return

; X -> frame. Endpoint validation uses no physical access and retains X.
dma_range_common
    cmpa #$ff
    beq dma_ordinary
    cmpa #111
    bcc dma_range_bad
    ldaa 2,x
    cmpa #$20
    bcc dma_range_bad
    ldab #$20
    bra dma_range_end
dma_ordinary
    ldaa 2,x
    beq dma_range_bad
    cmpa #$be
    bcc dma_range_bad
    ldab #$be
dma_range_end
    stab 8,x
    ldab 3,x
    addb 7,x
    ldaa 2,x
    adca 6,x
    bcs dma_range_bad
    cmpa 8,x
    bcs dma_range_valid
    bne dma_range_bad
    tstb
    bne dma_range_bad
dma_range_valid
    clr 8,x
    clc
    rts
dma_range_bad
    sec
    rts

dma_palette
    ldab SWIB
    cmpb #111
    bcs *+5
    jmp dma_argument
    ; SWI dispatch enables IRQ; SWIC retains the actual caller mask.
    ldaa swic
    psha
    ldaa SWIA
    deca
    psha
    clra
    psha
    ldaa #$20
    psha
    clra
    psha
    psha
    ldaa #$5e
    psha
    ldaa #$e6
    psha
    ldab SWIB
    pshb
    ldab #$ff
    pshb
    tsx
    ldaa 8,x
    cmpa #1
    bne *+5
    jmp dma_launch
    ; Restore: bank -> palette, swap both endpoint triples.
    ldaa 0,x
    ldab 1,x
    stab 0,x
    staa 1,x
    ldaa 2,x
    ldab 3,x
    pshb
    psha
    ldaa 4,x
    ldab 5,x
    staa 2,x
    stab 3,x
    pula
    pulb
    staa 4,x
    stab 5,x
    jmp dma_launch
; Program the indexed hardware descriptor atomically; leave IRQ enabled while
; waiting for autonomous completion. All temporary bytes are on the SWI stack.
dma_launch
    sei
    tst $e6e0
    bpl dma_acquired
    ldaa 9,x
    tap
    bra dma_launch
dma_acquired
    tst 8,x
    beq dma_parameters
    clr $e65f
    ldaa $e65e
    cmpa #'G'
    bne dma_missing
    clr $e652
    clr $e65d
dma_parameters
    clr $e6e2
    ldaa 3,x
    staa $e6e3
    ldaa 0,x
    ldab 2,x
    bsr dma_address
    ldaa 5,x
    staa $e6e3
    ldaa 1,x
    ldab 4,x
    bsr dma_address
    ldaa 7,x
    staa $e6e3
    ldaa 6,x
    staa $e6e3
    clr $e6e3
    ldaa #1
    staa $e6e3
    clr $e6e3
    ldab #6
dma_clear_pitch
    clr $e6e3
    decb
    bne dma_clear_pitch
    ldaa 8,x
    staa $e6e3
    clr $e6e3
    ldaa #2
    staa $e6e1
    ldaa 9,x
    tap
dma_wait
    ldaa $e6e0
    bmi dma_wait
    bita #$10
    bne dma_missing
    clra
    bra dma_return
dma_missing
    ldaa #2
dma_return
    staa SWIA
    ldaa 9,x
    tap
    ldab #10
dma_unstack
    ins
    decb
    bne dma_unstack
    rts
; A=bank (FF=base), B=offset high. Low byte was already emitted.
; physical = 22000 + bank*2000 + offset, no bank window changes.
dma_address
    cmpa #$ff
    beq dma_base
    adda #17
    psha
    anda #7
    asla
    asla
    asla
    asla
    asla
    aba
    staa $e6e3
    pula
    lsra
    lsra
    lsra
    staa $e6e3
    rts
dma_base
    stab $e6e3
    clr $e6e3
    rts

dma_info
    ldaa #1
    staa swia
    ldaa #7
    staa swib
    ldx #8192
    stx swix
    rts

; Private kernel gateway. Only the fixed EAD0 FAT/file descriptor is legal.
bc_system_fat
    cpx #$ead0
    bne dma_argument_far
    jmp native_fat_copy
dma_argument_far
    jmp dma_argument
native_fat_copy_done
    pula
    staa $e6f1
    pula
    staa $e6f0
    clr swia
    rts
