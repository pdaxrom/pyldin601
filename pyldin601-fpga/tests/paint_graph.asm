; Parent owns the native framebuffer while the Paint child reuses it.
start
    int $13
    staa original_mode
    stab original_attr
    stx original_base
    int $60
    cpx #0
    beq failed
    stx parent_frame
    ldaa #3
    .ifdef COLOUR
    ldaa #2
    .endif
    ldab #2
    int $12
    ldx #command
    int $39
parent_return
    int $61
    ldaa original_mode
    oraa #$80
    ldab original_attr
    ldx original_base
    int $12
failed
    int $38
command db 'B:PAINTUI.PGM',0
    section
parent_frame ds 2
original_mode ds 1
original_attr ds 1
original_base ds 2
    ends
    end start
