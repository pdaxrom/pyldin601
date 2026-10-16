; NCEDIT: Editor startup and command dispatch.
    .define NC_EDITOR
    include NCABI.INC
    include NCBOX.INC
    public owner
    extern screen_head
    extern editor_screen
    extern mouse_init
    extern mouse_height
    extern mouse_show
    extern add_b
    extern base_path
    extern body_rows
    extern bss_end
    extern columns
    extern copy_z
    extern dst
    extern editor_cac_de58
    extern editor_close
    extern editor_open
    extern editor_redraw
    extern eol_bytes
    extern eol_length
    extern error
    extern file_positions
    extern filename
    extern input
    extern mode
    extern original_attr
    extern saved_cursor
    extern saved_valid
    extern screen_base
    extern src
    extern standalone_cbac
    extern text_stride
    extern ui_command
    extern ui_keys
    extern v_block_st_90
    extern v_eol_byte_1
    extern v_screen_b_1

    section
bss_start
owner ds 2
    ends
; Pyldin Commander's streamed editor. MC6800 ISA and public UniDOS calls.
start
    bra editor_start
    db 'NCE1'
editor_start
    psha
    pshb
    ldx #bss_start
editor_zero
    clr 0,x
    inx
    cpx #bss_end
    bne editor_zero
    ldx #screen_head
    pulb
    stab 1,x
    pula
    staa 0,x
    ldx #file_positions
    ldab #16
    ldaa #$ff
editor_no_position
    staa 0,x
    inx
    decb
    bne editor_no_position
    int $3b
    cmpa #2
    beq editor_argument
    jmp editor_bad_parent
editor_argument
    ldaa #1
    ldx #input
    int $3c
    ldx #input
    ldab #4
editor_hex
    ldaa 0,x
    inx
    suba #'0'
    cmpa #9
    bls editor_digit
    suba #7
    cmpa #15
    bls *+5
    jmp editor_bad_parent
editor_digit
    pshb
    ldab #4
editor_shift
    asl owner+1
    rol owner
    decb
    bne editor_shift
    oraa owner+1
    staa owner+1
    pulb
    decb
    bne editor_hex
    tst 0,x
    beq *+5
    jmp editor_bad_parent
    ldx owner
    ldx 0,x
    cpx #$4e43
    beq *+5
    jmp editor_bad_parent
    ldx owner
    ldab #S_COMMAND
    jsr add_b
    stx src
    ldx #filename
    stx dst
    jsr copy_z
    ldx #filename
    stx src
    ldx #base_path
    stx dst
    jsr copy_z
    int $13
    staa mode
    stab original_attr
    stx screen_base
    ldaa $ed1d
    staa saved_cursor
    anda #$1f
    staa $ed1d
    int $6d
    staa columns
    ldaa #25
    staa ui_keys
    ldaa mode
    anda #3
    beq editor_layout
    dec ui_keys
editor_layout
    ldaa ui_keys
    staa ui_command
    deca
    staa body_rows
    ldaa #2
    staa eol_length
    ldaa #13
    staa eol_bytes
    ldaa #10
    staa v_eol_byte_1
    ldaa mode
    cmpa #2
    bne editor_pitch
    ldaa #6
    int $22
    clra
    int $22
editor_pitch
    tpa
    psha
    sei
    ldaa $e600
    psha
    ldaa #1
    staa $e600
    ldaa $e601
    staa text_stride
    ldaa mode
    anda #3
    bne editor_pitch_done
    ldaa #12
    staa $e600
    ldaa $e601
    staa screen_base
    ldaa #13
    staa $e600
    ldaa $e601
    staa v_screen_b_1
editor_pitch_done
    pula
    staa $e600
    pula
    tap
    ldaa mode
    cmpa #4
    beq block_video_mono
    anda #3
    bne block_video_ready
    tst $fff7
    bmi block_video_ready
block_video_mono
    inc v_block_st_90
block_video_ready
    ldx #ignore_break
    clrb
    ldaa #4
    int $2f
    ldx #fail_io
    clrb
    ldaa #7
    int $2f
    jsr editor_screen
    tsta
    beq editor_screen_ready
    jsr error
    jmp editor_close
editor_screen_ready
    jsr editor_cac_de58
    jsr editor_open
    tsta
    beq editor_ready
    jsr error
    jmp editor_close
editor_ready
    jsr mouse_init
    ldaa ui_keys
    inca
    asla
    asla
    asla
    staa mouse_height
    ldaa #$80
    staa mouse_show
    ldaa #1
    staa saved_valid
    jmp editor_redraw
editor_bad_parent
    ldx #standalone_cbac
    int $23
    int $38
ignore_break
    rts
fail_io
    ldaa #3
    staa $06
    rts
    end start
