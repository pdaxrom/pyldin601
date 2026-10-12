; MC6800 PS/2 translator, resident state allocated by native INT2A/2C.
; INT E7 vector doubles as the state pointer, like RAMBANKS INT E5.
; IRQ calls the resident JMP directly, never SWI (no shared SWI scratch).
; State: gateway 0..2, prefixes3,Pause4,modifiers5,head6,tail7,count8,
; active(code,scan,E0,down)9..12, input13/prefix14/code15, pointer17..18,
; iteration19..20, dropped21, queue32..63 (8 four-byte physical events).
B_K_STATE equ $efce
B_K_SIZE equ 64
keyboard_init
    ldaa $e6b4
    cmpa #2
    beq long_branch_1
    jmp keyboard_init_done
long_branch_1
    ldx #B_K_SIZE
    clrb
    int $2a
    cpx #0
    bne long_branch_2
    jmp keyboard_init_done
long_branch_2
    stx B_K_STATE
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
    ldx B_K_STATE
    inx
    inx
    inx
    ; Leave the resident gateway intact.
    ldab #61
keyboard_clear_bytes
    clr 0,x
    inx
    decb
    beq long_branch_3
    jmp keyboard_clear_bytes
long_branch_3
    ldx B_K_STATE
    ldaa #$ff
    staa 9,x
    staa $e628
    rts
keyboard_pump
    ldaa $e6b1
    bita #$40
    beq long_branch_4
    jmp keyboard_return
long_branch_4
    bita #$88
    bne long_branch_5
    jmp keyboard_drain
long_branch_5
    psha
    jsr keyboard_clear
    pula
    bita #$80
    bne long_branch_6
    jmp keyboard_ack_reset
long_branch_6
    ldaa #3
    staa $e6b3
keyboard_ack_reset
    ldaa #$20
    staa $e6b3
keyboard_drain
    ldaa $e6b1
    bita #1
    bne long_branch_7
    jmp keyboard_deliver
long_branch_7
    ldaa $e6b2
    ldx B_K_STATE
    staa 13,x
    jsr keyboard_byte
    jmp keyboard_drain
keyboard_return
    rts
keyboard_deliver
    ldx B_K_STATE
    ldaa 9,x
    cmpa #$ff
    bne long_branch_9
    jmp keyboard_next
long_branch_9
    ldaa $e6b1
    bita #4
    bne long_branch_10
    jmp keyboard_return
long_branch_10
    tst 12,x
    beq long_branch_11
    jmp keyboard_held
long_branch_11
    ldaa #$ff
    staa 9,x
    staa $e628
keyboard_next
    tst 8,x
    bne long_branch_12
    jmp keyboard_return
long_branch_12
    tst $ed09
    beq long_branch_13
    jmp keyboard_return
long_branch_13
    ldaa 6,x
    jsr keyboard_queue_address
    ldaa 0,x
    cmpa $ed31
    beq long_branch_14
    jmp keyboard_pop
long_branch_14
    tst $ed0b
    beq long_branch_15
    jmp keyboard_return
long_branch_15
keyboard_pop
    ldaa 0,x
    ldab 1,x
    psha
    pshb
    ldaa 2,x
    ldab 3,x
    ldx B_K_STATE
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
    jmp keyboard_publish
keyboard_held
    ldaa 9,x
    cmpa #$fb
    bne long_branch_17
    jmp keyboard_return
long_branch_17
    cmpa #$fc
    bne long_branch_18
    jmp keyboard_return
long_branch_18
    tst $ed09
    beq long_branch_19
    jmp keyboard_return
long_branch_19
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
    adda B_K_STATE+1
    staa 18,x
    ldaa B_K_STATE
    adca #0
    staa 17,x
    ldx 17,x
    rts
keyboard_byte
    tst 4,x
    bne long_branch_20
    jmp keyboard_prefix
long_branch_20
    dec 4,x
    rts
keyboard_prefix
    ldaa 13,x
    cmpa #$e1
    beq long_branch_21
    jmp keyboard_not_pause
long_branch_21
    ldab #7
    stab 4,x
    clr 3,x
    rts
keyboard_not_pause
    cmpa #$e0
    beq long_branch_22
    jmp keyboard_not_e0
long_branch_22
    ldab 3,x
    orab #1
    stab 3,x
    rts
keyboard_not_e0
    cmpa #$f0
    beq long_branch_23
    jmp keyboard_key
long_branch_23
    ldab 3,x
    orab #2
    stab 3,x
    rts
keyboard_key
    ldab 3,x
    stab 14,x
    clr 3,x
    bitb #1
    beq long_branch_24
    jmp keyboard_extended
long_branch_24
    cmpa #$12
    beq long_branch_25
    jmp keyboard_not_lshift
long_branch_25
    ldaa #1
    jmp keyboard_modifier
keyboard_not_lshift
    cmpa #$59
    beq long_branch_27
    jmp keyboard_extended
long_branch_27
    ldaa #2
    jmp keyboard_modifier
keyboard_extended
    cmpa #$14
    beq long_branch_29
    jmp keyboard_not_ctrl
long_branch_29
    ldaa #4
    bitb #1
    bne long_branch_30
    jmp keyboard_modifier
long_branch_30
    ldaa #8
keyboard_modifier
    bitb #2
    bne long_branch_31
    jmp keyboard_modifier_down
long_branch_31
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
    bne long_branch_32
    jmp keyboard_byte_return
long_branch_32
    cmpa #$77
    bne long_branch_33
    jmp keyboard_byte_return
long_branch_33
    bitb #2
    bne long_branch_34
    jmp keyboard_make
long_branch_34
    jmp keyboard_break
keyboard_byte_return
    rts
keyboard_make
    bitb #1
    bne long_branch_35
    jmp keyboard_table_scan
long_branch_35
    cmpa #$1f
    bne long_branch_36
    jmp keyboard_windows
long_branch_36
    cmpa #$27
    beq long_branch_37
    jmp keyboard_table_scan
long_branch_37
keyboard_windows
    ldab #$46
    jmp keyboard_translate
keyboard_table_scan
    staa 18,x
    ldaa #/keyboard_set2
    staa 17,x
    ldx 17,x
    ldab 0,x
    cmpb #$ff
    bne long_branch_39
    jmp keyboard_byte_return
long_branch_39
    ldx B_K_STATE
keyboard_translate
    ; Mode bits: Cyrillic,Ctrl,Shift. Tables are native 8 x 128 bytes.
    stab 15,x
    clr 16,x
    ldaa $e629
    bita #1
    beq long_branch_40
    jmp keyboard_latin
long_branch_40
    ldab #4
    stab 16,x
keyboard_latin
    ldaa 5,x
    bita #12
    bne long_branch_41
    jmp keyboard_no_ctrl
long_branch_41
    ldab 16,x
    orab #2
    stab 16,x
keyboard_no_ctrl
    bita #3
    bne long_branch_42
    jmp keyboard_no_shift
long_branch_42
    inc 16,x
keyboard_no_shift
    ldaa 16,x
    lsra
    adda #/keyboard_translate_table
    staa 17,x
    ldaa 16,x
    anda #1
    bne long_branch_43
    jmp keyboard_translate_low
long_branch_43
    ldaa #$80
keyboard_translate_low
    oraa 15,x
    staa 18,x
    ldx 17,x
    ldaa 0,x
    cmpa #$ff
    bne long_branch_44
    jmp keyboard_byte_return
long_branch_44
    ldx B_K_STATE
    staa 15,x
    ; Suppress hardware typematic for every still-down physical event.
    tst 12,x
    bne long_branch_45
    jmp keyboard_search_queue
long_branch_45
    ldab 13,x
    cmpb 10,x
    beq long_branch_46
    jmp keyboard_search_queue
long_branch_46
    ldaa 14,x
    anda #1
    cmpa 11,x
    bne long_branch_47
    jmp keyboard_byte_return
long_branch_47
keyboard_search_queue
    ldaa 6,x
    staa 19,x
    ldaa 8,x
    staa 20,x
keyboard_search_loop
    tst 20,x
    bne long_branch_48
    jmp keyboard_enqueue
long_branch_48
    ldaa 19,x
    jsr keyboard_queue_address
    tst 3,x
    bne long_branch_49
    jmp keyboard_search_next
long_branch_49
    ldab 1,x
    ldaa 2,x
    ldx B_K_STATE
    cmpb 13,x
    beq long_branch_50
    jmp keyboard_search_advance
long_branch_50
    eora 14,x
    bita #1
    bne long_branch_51
    jmp keyboard_byte_return
long_branch_51
keyboard_search_next
    ldx B_K_STATE
keyboard_search_advance
    dec 20,x
    ldaa 19,x
    inca
    anda #7
    staa 19,x
    jmp keyboard_search_loop
keyboard_enqueue
    ldaa 8,x
    cmpa #8
    beq long_branch_53
    jmp keyboard_enqueue_room
long_branch_53
    inc 21,x
    rts
keyboard_enqueue_room
    ldaa 7,x
    jsr keyboard_queue_address
    ; Retain queue destination on the stack while loading state fields.
    ; MC6800 has no PSHX: use the private pointer, then push its bytes.
    ldx B_K_STATE
    ldaa 17,x
    ldab 18,x
    psha
    pshb
    ldaa 15,x
    ldab 13,x
    ldx 17,x
    staa 0,x
    stab 1,x
    ldx B_K_STATE
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
    ldx B_K_STATE
    inc 8,x
    ldaa 7,x
    inca
    anda #7
    staa 7,x
    rts
keyboard_break
    ldab 13,x
    cmpb 10,x
    beq long_branch_54
    jmp keyboard_break_queue
long_branch_54
    ldaa 14,x
    anda #1
    cmpa 11,x
    beq long_branch_55
    jmp keyboard_break_queue
long_branch_55
    clr 12,x
keyboard_break_queue
    ldaa 6,x
    staa 19,x
    ldaa 8,x
    staa 20,x
keyboard_break_loop
    tst 20,x
    bne long_branch_56
    jmp keyboard_byte_return
long_branch_56
    ldaa 19,x
    jsr keyboard_queue_address
    ldab 1,x
    ldaa 2,x
    ldx B_K_STATE
    cmpb 13,x
    beq long_branch_57
    jmp keyboard_break_next
long_branch_57
    eora 14,x
    bita #1
    beq long_branch_58
    jmp keyboard_break_next
long_branch_58
    ldx 17,x
    clr 3,x
    ldx B_K_STATE
keyboard_break_next
    dec 20,x
    ldaa 19,x
    inca
    anda #7
    staa 19,x
    jmp keyboard_break_loop
keyboard_code_end
    ; Real UniAS assembles the code and table data; input mapping is shared
    ; with the existing independent emulator oracle and the CSV Set 2 map.
    ds ((*+$ff)&$ff00)-*,$ff
keyboard_set2
    include KEYSET2.INC
keyboard_translate_table
    include KEYTRANSLATE.INC
keyboard_image_end
