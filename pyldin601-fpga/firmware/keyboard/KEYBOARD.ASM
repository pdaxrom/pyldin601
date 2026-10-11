; MC6800 PS/2 translator, resident state allocated by native INT2A/2C.
; INT E7 vector doubles as the state pointer, like RAMBANKS INT E5.
; IRQ calls the resident JMP directly, never SWI (no shared SWI scratch).
; State: gateway 0..2, prefixes3,Pause4,modifiers5,head6,tail7,count8,
; active(code,scan,E0,down)9..12, input13/prefix14/code15, pointer17..18,
; iteration19..20, dropped21, queue32..63 (8 four-byte physical events).
K_STATE equ $efce
K_SIZE equ 64
keyboard_init
    ldaa $e6b4
    cmpa #2
    lbne keyboard_init_done
    ldx #K_SIZE
    clrb
    int $2a
    cpx #0
    lbeq keyboard_init_done
    stx K_STATE
    ldaa keyboard_gateway
    staa 0,x
    ldaa keyboard_gateway+1
    staa 1,x
    ldaa keyboard_gateway+2
    staa 2,x
    jsr keyboard_clear
    int $2c
    ldaa #$33
    staa $e6b3
keyboard_init_done
    rts
keyboard_gateway
    jmp keyboard_pump
keyboard_clear
    ldx K_STATE
    inx
    inx
    inx
    ; Leave the resident gateway intact.
    ldab #61
keyboard_clear_bytes
    clr 0,x
    inx
    decb
    lbne keyboard_clear_bytes
    ldx K_STATE
    ldaa #$ff
    staa 9,x
    staa $e628
    rts
keyboard_pump
    ldaa $e6b1
    bita #$40
    lbne keyboard_return
    bita #$88
    lbeq keyboard_drain
    psha
    jsr keyboard_clear
    pula
    bita #$80
    lbeq keyboard_ack_reset
    ldaa #3
    staa $e6b3
keyboard_ack_reset
    ldaa #$20
    staa $e6b3
keyboard_drain
    ldaa $e6b1
    bita #1
    lbeq keyboard_deliver
    ldaa $e6b2
    ldx K_STATE
    staa 13,x
    jsr keyboard_byte
    lbra keyboard_drain
keyboard_return
    rts
keyboard_deliver
    ldx K_STATE
    ldaa 9,x
    cmpa #$ff
    lbeq keyboard_next
    ldaa $e6b1
    bita #4
    lbeq keyboard_return
    tst 12,x
    lbne keyboard_held
    ldaa #$ff
    staa 9,x
    staa $e628
keyboard_next
    tst 8,x
    lbeq keyboard_return
    tst $ed09
    lbne keyboard_return
    ldaa 6,x
    jsr keyboard_queue_address
    ldaa 0,x
    cmpa $ed31
    lbne keyboard_pop
    tst $ed0b
    lbne keyboard_return
keyboard_pop
    ldaa 0,x
    ldab 1,x
    psha
    pshb
    ldaa 2,x
    ldab 3,x
    ldx K_STATE
    staa 11,x
    stab 12,x
    pulb
    pula
    staa 9,x
    stab 10,x
    dec 8,x
    ldaa 6,x
    inca
    anda #7
    staa 6,x
    lbra keyboard_publish
keyboard_held
    ldaa 9,x
    cmpa #$fb
    lbeq keyboard_return
    cmpa #$fc
    lbeq keyboard_return
    tst $ed09
    lbne keyboard_return
keyboard_publish
    ldaa 9,x
    staa $e628
    ldaa $e62a
    oraa #$80
    staa $e62a
    rts
keyboard_queue_address
    asla
    asla
    adda #32
    adda K_STATE+1
    staa 18,x
    ldaa K_STATE
    adca #0
    staa 17,x
    ldx 17,x
    rts
keyboard_byte
    tst 4,x
    lbeq keyboard_prefix
    dec 4,x
    rts
keyboard_prefix
    ldaa 13,x
    cmpa #$e1
    lbne keyboard_not_pause
    ldab #7
    stab 4,x
    clr 3,x
    rts
keyboard_not_pause
    cmpa #$e0
    lbne keyboard_not_e0
    ldab 3,x
    orab #1
    stab 3,x
    rts
keyboard_not_e0
    cmpa #$f0
    lbne keyboard_key
    ldab 3,x
    orab #2
    stab 3,x
    rts
keyboard_key
    ldab 3,x
    stab 14,x
    clr 3,x
    bitb #1
    lbne keyboard_extended
    cmpa #$12
    lbne keyboard_not_lshift
    ldaa #1
    lbra keyboard_modifier
keyboard_not_lshift
    cmpa #$59
    lbne keyboard_extended
    ldaa #2
    lbra keyboard_modifier
keyboard_extended
    cmpa #$14
    lbne keyboard_not_ctrl
    ldaa #4
    bitb #1
    lbeq keyboard_modifier
    ldaa #8
keyboard_modifier
    bitb #2
    lbeq keyboard_modifier_down
    coma
    anda 5,x
    staa 5,x
    rts
keyboard_modifier_down
    oraa 5,x
    staa 5,x
    rts
keyboard_not_ctrl
    cmpa #$11
    lbeq keyboard_byte_return
    cmpa #$77
    lbeq keyboard_byte_return
    bitb #2
    lbeq keyboard_make
    jmp keyboard_break
keyboard_byte_return
    rts
keyboard_make
    bitb #1
    lbeq keyboard_table_scan
    cmpa #$1f
    lbeq keyboard_windows
    cmpa #$27
    lbne keyboard_table_scan
keyboard_windows
    ldab #$46
    lbra keyboard_translate
keyboard_table_scan
    staa 18,x
    ldaa #/keyboard_set2
    staa 17,x
    ldx 17,x
    ldab 0,x
    cmpb #$ff
    lbeq keyboard_byte_return
    ldx K_STATE
keyboard_translate
    ; Mode bits: Cyrillic,Ctrl,Shift. Tables are native 8 x 128 bytes.
    stab 15,x
    clr 16,x
    ldaa $e629
    bita #1
    lbne keyboard_latin
    ldab #4
    stab 16,x
keyboard_latin
    ldaa 5,x
    bita #12
    lbeq keyboard_no_ctrl
    ldab 16,x
    orab #2
    stab 16,x
keyboard_no_ctrl
    bita #3
    lbeq keyboard_no_shift
    inc 16,x
keyboard_no_shift
    ldaa 16,x
    lsra
    adda #/keyboard_translate_table
    staa 17,x
    ldaa 16,x
    anda #1
    lbeq keyboard_translate_low
    ldaa #$80
keyboard_translate_low
    oraa 15,x
    staa 18,x
    ldx 17,x
    ldaa 0,x
    cmpa #$ff
    lbeq keyboard_byte_return
    ldx K_STATE
    staa 15,x
    ; Suppress hardware typematic for every still-down physical event.
    tst 12,x
    lbeq keyboard_search_queue
    ldab 13,x
    cmpb 10,x
    lbne keyboard_search_queue
    ldaa 14,x
    anda #1
    cmpa 11,x
    lbeq keyboard_byte_return
keyboard_search_queue
    ldaa 6,x
    staa 19,x
    ldaa 8,x
    staa 20,x
keyboard_search_loop
    tst 20,x
    lbeq keyboard_enqueue
    ldaa 19,x
    jsr keyboard_queue_address
    tst 3,x
    lbeq keyboard_search_next
    ldab 1,x
    ldaa 2,x
    ldx K_STATE
    cmpb 13,x
    lbne keyboard_search_advance
    eora 14,x
    bita #1
    lbeq keyboard_byte_return
keyboard_search_next
    ldx K_STATE
keyboard_search_advance
    dec 20,x
    ldaa 19,x
    inca
    anda #7
    staa 19,x
    lbra keyboard_search_loop
keyboard_enqueue
    ldaa 8,x
    cmpa #8
    lbne keyboard_enqueue_room
    inc 21,x
    rts
keyboard_enqueue_room
    ldaa 7,x
    jsr keyboard_queue_address
    ; Retain queue destination on the stack while loading state fields.
    ; MC6800 has no PSHX: use the private pointer, then push its bytes.
    ldx K_STATE
    ldaa 17,x
    ldab 18,x
    psha
    pshb
    ldaa 15,x
    ldab 13,x
    ldx 17,x
    staa 0,x
    stab 1,x
    ldx K_STATE
    ldaa 14,x
    anda #1
    pulb
    stab 18,x
    pulb
    stab 17,x
    ldx 17,x
    staa 2,x
    ldaa #1
    staa 3,x
    ldx K_STATE
    inc 8,x
    ldaa 7,x
    inca
    anda #7
    staa 7,x
    rts
keyboard_break
    ldab 13,x
    cmpb 10,x
    lbne keyboard_break_queue
    ldaa 14,x
    anda #1
    cmpa 11,x
    lbne keyboard_break_queue
    clr 12,x
keyboard_break_queue
    ldaa 6,x
    staa 19,x
    ldaa 8,x
    staa 20,x
keyboard_break_loop
    tst 20,x
    lbeq keyboard_byte_return
    ldaa 19,x
    jsr keyboard_queue_address
    ldab 1,x
    ldaa 2,x
    ldx K_STATE
    cmpb 13,x
    lbne keyboard_break_next
    eora 14,x
    bita #1
    lbne keyboard_break_next
    ldx 17,x
    clr 3,x
    ldx K_STATE
keyboard_break_next
    dec 20,x
    ldaa 19,x
    inca
    anda #7
    staa 19,x
    lbra keyboard_break_loop
keyboard_code_end
    ; Real UniAS assembles the code and table data; input mapping is shared
    ; with the existing independent emulator oracle and the CSV Set 2 map.
    ds ((*+$ff)&$ff00)-*,$ff
keyboard_set2
    include KEYSET2.INC
keyboard_translate_table
    include KEYTRANSLATE.INC
keyboard_image_end
