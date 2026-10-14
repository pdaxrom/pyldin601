; Read-only MC6800 ROM module: CRC-16/CCITT-FALSE, polynomial 1021.
; INIT: X -> eight persistent bytes, no allocations or vector changes.
; ED A=0 -> A=1 ABI, B=1 functions, X=8 descriptor bytes.
; ED A=1, X -> sourceBE,lengthBE,seedBE,resultBE; A=0 success,1 argument.
; All scratch is stack-local. The ROM image is never written.
    org $c000
    dw $a55a
    .ifdef SECOND_MODULE
    db 'CRCALT  '
    .else
    db 'CRC16   '
    .endif
    jmp initialize
    jmp version
    .ifdef SECOND_MODULE
    db $ee
    .else
    db $ed
    .endif
    dw crc_service
    db 0
initialize
    .ifdef INIT_FAIL
    ldaa #9
    staa $06
    rts
    .else
    inc 0,x
    clra
    staa $06
    .endif
version
    rts
crc_service
    tsta
    bne *+5
    jmp CRC_INFO
    .ifdef SECOND_MODULE
    cmpa #2
    bne crc_function
    ldaa #1
    int $ed
    staa $06
    rts
crc_function
    .endif
    cmpa #1
    beq *+5
    jmp CRC_BAD
    ; Validate the descriptor and complete ordinary-RAM input range first.
    ldaa $07
    cmpa #1
    bcc *+5
    jmp CRC_BAD
    cmpa #$be
    bcs *+5
    jmp CRC_BAD
    ldaa $08
    adda #8
    ldaa $07
    adca #0
    cmpa #$be
    bls *+5
    jmp CRC_BAD
    bcs crc_descriptor_ok
    ldaa $08
    adda #8
    beq *+5
    jmp CRC_BAD
crc_descriptor_ok
    ldaa 0,x
    cmpa #1
    bcc *+5
    jmp CRC_BAD
    cmpa #$be
    bcs *+5
    jmp CRC_BAD
    ldaa 1,x
    adda 3,x
    ldaa 0,x
    adca 2,x
    bcc *+5
    jmp CRC_BAD
    cmpa #$be
    bls *+5
    jmp CRC_BAD
    bcs crc_frame
    ldaa 1,x
    adda 3,x
    beq *+5
    jmp CRC_BAD
crc_frame
    ; Retain the original descriptor below all stack-local scratch.
    ldaa $08
    psha
    ldaa $07
    psha
    ; Stack: remainingBE, sourceBE, crcBE, bit counter; seven bytes.
    ldaa 5,x
    psha
    ldaa 4,x
    psha
    ldaa 1,x
    psha
    ldaa 0,x
    psha
    ldaa 3,x
    psha
    ldaa 2,x
    psha
    des
crc_next
    tsx
    ldaa 1,x
    oraa 2,x
    beq crc_done
    ldx 3,x
    ldaa 0,x
    inx
    stx $07
    tsx
    eora 5,x
    staa 5,x
    ldaa $07
    staa 3,x
    ldaa $08
    staa 4,x
    ; Restore the request pointer from the private stack before the next IRQ.
    ldaa #8
    staa 0,x
crc_bit
    asl 6,x
    rol 5,x
    bcc crc_bit_next
    ldaa 5,x
    eora #$10
    staa 5,x
    ldaa 6,x
    eora #$21
    staa 6,x
crc_bit_next
    dec 0,x
    bne crc_bit
    ldaa 2,x
    suba #1
    staa 2,x
    ldaa 1,x
    sbca #0
    staa 1,x
    bra crc_next
crc_done
    ; The original descriptor pointer is passed separately on entry's stack.
    ldaa 5,x
    ldab 6,x
    ins
    ins
    ins
    ins
    ins
    ins
    ins
    tsx
    ldx 0,x
    staa 6,x
    stab 7,x
    stx $07
    ins
    ins
    clra
    staa $06
    rts
crc_info
    ldaa #1
    staa $06
    staa $05
    ldx #8
    stx $07
    rts
crc_bad
    ldaa #1
    staa $06
    rts
crc_image_end
    checksum
    ds $e000-*,$ff
    end
