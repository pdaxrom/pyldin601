; Pyldin Commander's streamed editor. MC6800 ISA and public UniDOS calls.
    include NCABI.INC
    include NCBOX.INC
start
    bra editor_start
    db 'NCE1'
editor_start
    ldx #bss_start
editor_zero
    clr 0,x
    inx
    cpx #bss_end
    bne editor_zero
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
    staa eol_bytes+1
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
    staa screen_base+1
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
    inc block_state+90
block_video_ready
    ldx #ignore_break
    clrb
    ldaa #4
    int $2f
    ldx #fail_io
    clrb
    ldaa #7
    int $2f
    jsr editor_cache_open
    jsr editor_open
    tsta
    beq editor_ready
    jsr error
    jmp editor_close
editor_ready
    ldaa #1
    staa saved_valid
    jmp editor_redraw
editor_bad_parent
    ldx #standalone_message
    int $23
    int $38
ignore_break
    rts
fail_io
    ldaa #3
    staa $06
    rts
    include NCE32.INC
    include NCECACHE.INC
    include NCEPIECE.INC
    include NCEFILES.INC
    include NCEHISTORY.INC
    include NCUTIL.INC
    include NCOCTETS.INC
    include NCECOPY.INC
    include NCVIDEO.INC
    include NCFIELDS.INC
    include NCNUMBER.INC
    include NCWINDOW.INC
    include NCEUI.INC
    include NCESCAN.INC
    include NCENAV.INC
    include NCEHORIZ.INC
    include NCEUNDOUI.INC
    include NCESAVE.INC
    include NCESEARCH.INC
    include NCEBLOCK.INC
    include NCEDATA.INC
    end start
