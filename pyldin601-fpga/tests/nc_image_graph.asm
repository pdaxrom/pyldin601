; Real parent allocation: never point native video at ordinary address zero.
start
    int $13
    staa original_mode
    stab original_attr
    stx original_base
    int $45
    adda #'A'
    staa command
    int $60
    cpx #0
    beq done
    ldaa #3
    clrb
    int $12
    ldx #command
    int $39
    int $61
done
    ldaa original_mode
    oraa #$80
    ldab original_attr
    ldx original_base
    int $12
    int $38
command db 'A:\NC.PGM',0
    section
original_mode ds 1
original_attr ds 1
original_base ds 2
    ends
    end start
