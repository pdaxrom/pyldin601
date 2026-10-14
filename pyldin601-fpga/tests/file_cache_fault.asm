; Test-only E8 handler: reject/no-op file-window copies while allowing the
; existing FAT E700 gateway. Result byte 0305 is 1 (failure) or 0 (bad copy).
    org $0306
    psha
    ldx $07
    ldaa 0,x
    cmpa #$e0
    beq file_copy_fault
    ldaa 2,x
    cmpa #$e0
    beq file_copy_fault
    pula
    jmp $f640
file_copy_fault
    pula
    ldaa $0305
    staa $06
    rts
    end
