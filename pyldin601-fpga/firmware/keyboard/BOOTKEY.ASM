; Boot-only polling decoder: menus need navigation/DEL/ENTER/ESC, no layout.
; Runtime uses the complete KEYBOARD.ASM driver in FPGABIOS, both ISA modes.
B_BK_PREFIX equ $1e0
B_BK_SCAN equ $1e1
B_BK_EXT equ $1e2
B_BK_CODE equ $1e3
B_BK_INPUT equ $1e4
B_BK_INPUT_EXT equ $1e5
boot_keyboard_init
    clr B_BK_PREFIX
    clr B_BK_SCAN
    clr B_BK_EXT
    ldaa #$ff
    staa B_BK_CODE
    staa $e628
    ldaa #$63
    staa $e6b3
    rts
boot_keyboard_poll
    ldaa $e6b4
    cmpa #2
    beq long_branch_191
    jmp boot_keyboard_done
long_branch_191
boot_keyboard_loop
    ldaa $e6b1
    bita #$80
    bne long_branch_192
    jmp boot_keyboard_available
long_branch_192
    jsr boot_keyboard_init
    jmp boot_keyboard_loop
boot_keyboard_available
    bita #1
    bne long_branch_194
    jmp boot_keyboard_done
long_branch_194
    ldaa $e6b2
    cmpa #$e0
    beq long_branch_195
    jmp boot_keyboard_not_e0
long_branch_195
    ldab B_BK_PREFIX
    orab #1
    stab B_BK_PREFIX
    jmp boot_keyboard_loop
boot_keyboard_not_e0
    cmpa #$f0
    beq long_branch_197
    jmp boot_keyboard_scan
long_branch_197
    ldab B_BK_PREFIX
    orab #2
    stab B_BK_PREFIX
    jmp boot_keyboard_loop
boot_keyboard_scan
    ldab B_BK_PREFIX
    clr B_BK_PREFIX
    bitb #2
    bne long_branch_199
    jmp boot_keyboard_make
long_branch_199
    cmpa B_BK_SCAN
    beq long_branch_200
    jmp boot_keyboard_loop
long_branch_200
    andb #1
    cmpb B_BK_EXT
    beq long_branch_201
    jmp boot_keyboard_loop
long_branch_201
    ldaa #$ff
    staa B_BK_CODE
    staa $e628
    ; Expose release before processing a queued make of the same key.
    rts
boot_keyboard_make
    staa B_BK_INPUT
    andb #1
    stab B_BK_INPUT_EXT
    cmpa #$71
    beq long_branch_202
    jmp boot_keyboard_not_del
long_branch_202
    ldaa #$f9
    jmp boot_keyboard_publish
boot_keyboard_not_del
    cmpa #$75
    beq long_branch_204
    jmp boot_keyboard_not_up
long_branch_204
    ldaa #$c4
    jmp boot_keyboard_publish
boot_keyboard_not_up
    cmpa #$72
    beq long_branch_206
    jmp boot_keyboard_not_down
long_branch_206
    ldaa #$c3
    jmp boot_keyboard_publish
boot_keyboard_not_down
    cmpa #$6b
    beq long_branch_208
    jmp boot_keyboard_not_left
long_branch_208
    ldaa #$c1
    jmp boot_keyboard_publish
boot_keyboard_not_left
    cmpa #$74
    beq long_branch_210
    jmp boot_keyboard_not_right
long_branch_210
    ldaa #$c2
    jmp boot_keyboard_publish
boot_keyboard_not_right
    cmpa #$5a
    beq long_branch_212
    jmp boot_keyboard_not_enter
long_branch_212
    ldaa #$c0
    jmp boot_keyboard_publish
boot_keyboard_not_enter
    cmpa #$29
    beq long_branch_214
    jmp boot_keyboard_not_space
long_branch_214
    ldaa #' '
    jmp boot_keyboard_publish
boot_keyboard_not_space
    cmpa #$76
    beq long_branch_216
    jmp boot_keyboard_loop
long_branch_216
    ldaa #$1b
boot_keyboard_publish
    staa B_BK_CODE
    staa $e628
    ldaa B_BK_INPUT
    staa B_BK_SCAN
    ldaa B_BK_INPUT_EXT
    staa B_BK_EXT
    ; Expose make even if its break is already waiting in the raw FIFO.
    rts
boot_keyboard_done
    rts
boot_keyboard_end
