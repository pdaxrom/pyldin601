; Boot-only polling decoder: menus need navigation/DEL/ENTER/ESC, no layout.
; Runtime uses the complete KEYBOARD.ASM driver in FPGABIOS, both ISA modes.
BK_PREFIX equ $1e0
BK_SCAN equ $1e1
BK_EXT equ $1e2
BK_CODE equ $1e3
BK_INPUT equ $1e4
BK_INPUT_EXT equ $1e5
boot_keyboard_init
    clr BK_PREFIX
    clr BK_SCAN
    clr BK_EXT
    ldaa #$ff
    staa BK_CODE
    staa $e628
    ldaa #$63
    staa $e6b3
    rts
boot_keyboard_poll
    ldaa $e6b4
    cmpa #2
    lbne boot_keyboard_done
boot_keyboard_loop
    ldaa $e6b1
    bita #$80
    lbeq boot_keyboard_available
    jsr boot_keyboard_init
    lbra boot_keyboard_loop
boot_keyboard_available
    bita #1
    lbeq boot_keyboard_done
    ldaa $e6b2
    cmpa #$e0
    lbne boot_keyboard_not_e0
    ldab BK_PREFIX
    orab #1
    stab BK_PREFIX
    lbra boot_keyboard_loop
boot_keyboard_not_e0
    cmpa #$f0
    lbne boot_keyboard_scan
    ldab BK_PREFIX
    orab #2
    stab BK_PREFIX
    lbra boot_keyboard_loop
boot_keyboard_scan
    ldab BK_PREFIX
    clr BK_PREFIX
    bitb #2
    lbeq boot_keyboard_make
    cmpa BK_SCAN
    lbne boot_keyboard_loop
    andb #1
    cmpb BK_EXT
    lbne boot_keyboard_loop
    ldaa #$ff
    staa BK_CODE
    staa $e628
    ; Expose release before processing a queued make of the same key.
    rts
boot_keyboard_make
    staa BK_INPUT
    andb #1
    stab BK_INPUT_EXT
    cmpa #$71
    lbne boot_keyboard_not_del
    ldaa #$f9
    lbra boot_keyboard_publish
boot_keyboard_not_del
    cmpa #$75
    lbne boot_keyboard_not_up
    ldaa #$c4
    lbra boot_keyboard_publish
boot_keyboard_not_up
    cmpa #$72
    lbne boot_keyboard_not_down
    ldaa #$c3
    lbra boot_keyboard_publish
boot_keyboard_not_down
    cmpa #$6b
    lbne boot_keyboard_not_left
    ldaa #$c1
    lbra boot_keyboard_publish
boot_keyboard_not_left
    cmpa #$74
    lbne boot_keyboard_not_right
    ldaa #$c2
    lbra boot_keyboard_publish
boot_keyboard_not_right
    cmpa #$5a
    lbne boot_keyboard_not_enter
    ldaa #$c0
    lbra boot_keyboard_publish
boot_keyboard_not_enter
    cmpa #$29
    lbne boot_keyboard_not_space
    ldaa #' '
    lbra boot_keyboard_publish
boot_keyboard_not_space
    cmpa #$76
    lbne boot_keyboard_loop
    ldaa #$1b
boot_keyboard_publish
    staa BK_CODE
    staa $e628
    ldaa BK_INPUT
    staa BK_SCAN
    ldaa BK_INPUT_EXT
    staa BK_EXT
    ; Expose make even if its break is already waiting in the raw FIFO.
    rts
boot_keyboard_done
    rts
boot_keyboard_end
