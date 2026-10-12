; Shared foreground decoder. All error paths unwind to the public caller;
; original BIOS page/group and IRQ-enable state are retained by native SWIs.
; mus_load X=absolute song filename; A=0 loaded, 1 unavailable/invalid.
mus_page equ $e6f0
mus_group equ $e6f1
mus_load
    stx mus_name_arg
    sts mus_return_sp
    ldx #mus_state_begin
mus_zero_state
    clr 0,x
    inx
    cpx #mus_state_end
    bne mus_zero_state
    ldaa $e6f0
    staa mus_saved_page
    ldaa $e6f1
    staa mus_saved_group
    ldd #50
    std mus_rate
    ldd #289
    std mus_clock_factor
    ldaa #1
    staa mus_looping
    ldaa #$e5
    int $2e
    tstb
    beq mus_load_failed
    ldd mus_name_arg
    std mus_io_table
    ldx #mus_io_table
    ldaa #1
    int $4a
    tsta
    bne mus_load_failed
    stab mus_handle
    inc mus_opened
    ldaa mus_handle
    ldx #mus_file_size
    int $51
    tsta
    bne mus_load_failed
    ldd mus_file_size
    std mus_file_left
    ldd mus_file_size+2
    std mus_file_left+2
    jsr mus_load_song
    jsr mus_close_song
    jsr mus_parse_song
    jsr mus_restore_bank
    inc mus_loaded
    clra
    rts
mus_load_failed
    jmp mus_bad_file
mus_start
    sts mus_return_sp
    ldaa $e6f0
    staa mus_saved_page
    ldaa $e6f1
    staa mus_saved_group
    tst mus_loaded
    beq mus_start_done
    ldaa #GB_PLAY
    clrb
    int GB_INT
    ldaa #GB_STOP
    int GB_INT
    ldd mus_clock_factor
    subd #256
    beq mus_clock_atari
    ldd mus_clock_factor
    subd #512
    beq mus_clock_cpc
    ldd mus_clock_factor
    subd #289
    beq mus_clock_spectrum
    ldab #3
    bra mus_clock_ready
mus_clock_atari
    clrb
    bra mus_clock_ready
mus_clock_cpc
    ldab #1
    bra mus_clock_ready
mus_clock_spectrum
    ldab #2
mus_clock_ready
    ldaa #GB_CLOCK
    int GB_INT
    tsta
    bne mus_start_done
    jsr mus_timer_calculate
    ldx #mus_timer_period
    ldaa #GB_RATE
    int GB_INT
    tsta
    bne mus_start_done
    ldd #0
    std mus_current_frame
    clr mus_decode_status
    tst mus_kind
    beq mus_restart_psg
    jsr mus_ym_reset
    bra mus_start_fill
mus_restart_psg
    jsr mus_memory_reset
    jsr mus_parse_psg
mus_start_fill
    jsr mus_fill
    ldaa #GB_PLAY
    ldab #1
    int GB_INT
mus_start_done
    rts
mus_fill
    tst mus_loaded
    beq mus_fill_done
    sts mus_return_sp
    ldaa $e6f0
    staa mus_saved_page
    ldaa $e6f1
    staa mus_saved_group
    ldaa #GB_STATUS
    int GB_INT
    negb
    addb #16
    stab mus_needed
    beq mus_fill_done
mus_fill_next
    tst mus_kind
    beq mus_fill_psg
    jsr mus_ym_frame
    bra mus_fill_decoded
mus_fill_psg
    jsr mus_psg_frame
mus_fill_decoded
    tst mus_decode_status
    bne mus_bad_file
    ldaa #GB_FRAME
    ldx #mus_raw_frame
    int GB_INT
    tsta
    bne mus_fill_restore
    dec mus_needed
    bne mus_fill_next
mus_fill_restore
    jsr mus_restore_bank
mus_fill_done
    rts
mus_close_song
    tst mus_opened
    beq mus_closed
    ldaa mus_handle
    int $4e
    clr mus_opened
mus_closed
    rts
mus_release
    tst mus_memory_lease+2
    beq mus_release_done
    ldaa #2
    ldx #mus_memory_lease
    int $e5
mus_release_done
    clr mus_loaded
    rts
mus_restore_bank
    ldaa mus_saved_group
    staa $e6f1
    ldaa mus_saved_page
    staa $e6f0
    rts
mus_bad_file
mus_too_large
mus_io_failed
mus_escaped
mus_unsupported
mus_finish
    lds mus_return_sp
    jsr mus_close_song
    jsr mus_restore_bank
    jsr mus_release
    ldaa #1
    rts
