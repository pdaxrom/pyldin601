    org $c000
    dw $5aa5
    db "UniShell"
    jmp shell_init
    jmp shell_init
    db $e3
    dw shell_copy
    db 0
shell_init
    rts
shell_copy
    ldx #shell_bytes
    stx $bf8c
    ldx #$1000
    stx $bf9a
shell_loop
    ldx $bf8c
    ldaa 0,x
    inx
    stx $bf8c
    ldx $bf9a
    staa 0,x
    inx
    stx $bf9a
    cpx #$1000+8000
    bne shell_loop
    rts
shell_bytes
    include SHELLHEAD.INC
    checksum
    ds $e000-*,$ff
    end
