; Shared native UniDOS high scores. Caller constants: hs_id, hs_title,
; hs_primary_name, hs_backup_name. Two generation slots preserve the last
; valid table when media is full, read-only, removed, or a write is torn.
; File: PHS1, sequenceBE, gameID, 10; 10*(scoreBE,name[13]); sum16BE.
; hs_init resolves argv[0] once; never changes any drive/current directory.
hs_init
    ; DOS normally asks Abort/Retry/Ignore/Fail on physical I/O errors.
    ; Keep the caller's handler, return Fail for our bounded file operations.
    ldaa #7
    int $2e
    stab hs_error_page
    stx hs_error_address
    ldaa #7
    ldab #7
    ldx #hs_io_error
    int $2f
    inc hs_hooked
    clra
    ldx #hs_argument
    int $3c
    ldd #hs_argument
    std hs_io
    ldd #hs_path
    std hs_io+2
    ldx #hs_io
    int $3f
    tsta
    beq hs_path_ok
    ldaa #1
    staa hs_unwritable
    ldx #hs_path
    clr 0,x
hs_path_ok
    ldx #hs_path
    stx hs_directory_end
hs_scan_path
    ldaa 0,x
    beq hs_path_end
    inx
    cmpa #'\'
    beq hs_separator
    cmpa #':'
    bne hs_scan_path
hs_separator
    stx hs_directory_end
    bra hs_scan_path
hs_path_end
    ldx #hs_table
    ldab #160
hs_empty
    clr 0,x
    inx
    decb
    bne hs_empty
    ldd #$5048
    std hs_table
    ldd #$5331
    std hs_table+2
    ldaa #hs_id
    staa hs_table+6
    ldaa #10
    staa hs_table+7
    ldaa #$ff
    staa hs_active
    ldx #hs_primary_name
    jsr hs_asset_path
    jsr hs_read
    tsta
    bne hs_try_backup
    jsr hs_accept
    clr hs_active
hs_try_backup
    ldx #hs_backup_name
    jsr hs_asset_path
    jsr hs_read
    tsta
    bne hs_init_done
    ldaa hs_active
    cmpa #$ff
    beq hs_use_backup
    ldd hs_probe+4
    subd hs_table+4
    ble hs_init_done
hs_use_backup
    jsr hs_accept
    ldaa #1
    staa hs_active
hs_init_done
    rts
; X=NUL basename; returns X=absolute name in hs_path (capacity 146).
hs_asset_path
    stx hs_source
    ldx hs_directory_end
    stx hs_destination
hs_path_copy
    ldx hs_source
    ldaa 0,x
    inx
    stx hs_source
    ldx hs_destination
    staa 0,x
    inx
    stx hs_destination
    tsta
    bne hs_path_copy
    ldx #hs_path
    rts
hs_read
    ldd #hs_path
    std hs_io
    clr hs_io+2
    clr hs_io+3
    ldx #hs_io
    ldaa #1
    int $4a
    tsta
    bne hs_read_bad
    stab hs_handle
    ldaa hs_handle
    ldx #hs_size
    int $51
    tsta
    bne hs_read_close_bad
    ldd hs_size
    bne hs_read_close_bad
    ldd hs_size+2
    subd #160
    bne hs_read_close_bad
    ldd #hs_probe
    std hs_io
    ldd #160
    std hs_io+2
    ldaa hs_handle
    ldx #hs_io
    int $4c
    tsta
    bne hs_read_close_bad
    cpx #160
    bne hs_read_close_bad
    ldaa hs_handle
    int $4e
    tsta
    bne hs_read_bad
    jmp hs_validate
hs_read_close_bad
    ldaa hs_handle
    int $4e
hs_read_bad
    ldaa #1
    rts
hs_validate
    ldd hs_probe
    subd #$5048
    bne hs_read_bad
    ldd hs_probe+2
    subd #$5331
    bne hs_read_bad
    ldaa hs_probe+6
    cmpa #hs_id
    bne hs_read_bad
    ldaa hs_probe+7
    cmpa #10
    bne hs_read_bad
    ldx #hs_probe
    jsr hs_checksum
    subd hs_probe+158
    bne hs_read_bad
    ldx #hs_probe+8
    ldd #$ffff
    std hs_previous
    ldaa #10
    staa hs_row
hs_check_row
    ldd 0,x
    subd hs_previous
    bhi hs_read_bad
    ldd 0,x
    std hs_previous
    tst 14,x
    bne hs_validate_bad
    stx hs_entry
    inx
    inx
    ldab #12
hs_check_name
    ldaa 0,x
    beq hs_name_valid
    cmpa #32
    bcs hs_validate_bad
    cmpa #126
    bhi hs_validate_bad
    inx
    decb
    bne hs_check_name
hs_name_valid
    ldx hs_entry
    ldab #15
    abx
    dec hs_row
    bne hs_check_row
    clra
    rts
hs_validate_bad
    jmp hs_read_bad
hs_checksum
    ldd #0
    std hs_sum
    ldab #158
    stab hs_count
hs_sum_byte
    ldab 0,x
    clra
    addd hs_sum
    std hs_sum
    inx
    dec hs_count
    bne hs_sum_byte
    rts
hs_accept
    ldx #hs_probe
    ldab #160
hs_accept_byte
    ldaa 0,x
    staa hs_table-hs_probe,x
    inx
    decb
    bne hs_accept_byte
    rts
; Graphical UI shares the game's live GAMEBIOS context. Page 5 leaves the
; game atlas, backgrounds and HAM8 picture intact. MODE never selects native
; video here; only the application's final CLOSE returns to UniDOS.
; hs_show: B=0 start/restart, B=1 exit. BIOS character input works while the
; framebuffer remains enabled, allowing names without a second raw decoder.
hs_show
    jsr hs_panel
    ldx #hs_attr_gold
    jsr hs_attribute
    ldx #hs_heading
    ldab #4
    jsr hs_center
    ldx #hs_attr_muted
    jsr hs_attribute
    ldx #hs_columns
    ldd #$0606
    jsr hs_text
    clr hs_row
hs_print_row
    ldaa hs_row
    ldab #15
    mul
    addd #hs_table+8
    std hs_entry
    xgdx
    ldd 0,x
    jsr hs_decimal
    ldx #hs_attr_white
    tst hs_row
    bne hs_row_colour
    ldx #hs_attr_gold
hs_row_colour
    jsr hs_attribute
    ldaa #' '
    staa hs_ui_rank
    ldaa hs_row
    adda #'1'
    cmpa #':'
    bne hs_rank_digit
    ldaa #'1'
    staa hs_ui_rank
    ldaa #'0'
hs_rank_digit
    staa hs_ui_rank+1
    ldaa #6
    ldab hs_row
    addb #7
    ldx #hs_ui_rank
    jsr hs_text
    ldx hs_entry
    inx
    inx
    tst 0,x
    bne hs_row_name
    ldx #hs_empty_name
hs_row_name
    ldaa #10
    ldab hs_row
    addb #7
    jsr hs_text
    ldx #hs_number
    ldaa #28
    ldab hs_row
    addb #7
    jsr hs_text
    inc hs_row
    ldaa hs_row
    cmpa #10
    bne hs_print_row
    ldx #hs_attr_white
    jsr hs_attribute
    ldx #hs_last_score
    ldd #$0812
    jsr hs_text
    ldd hs_score
    jsr hs_decimal
    ldx #hs_number
    ldd #$1712
    jsr hs_text
    ldx #hs_attr_muted
    jsr hs_attribute
    tst hs_ui_status
    beq hs_no_status
    ldx #hs_saved_text
    ldaa hs_ui_status
    cmpa #1
    beq hs_status_text
    ldx #hs_failed_text
hs_status_text
    ldab #19
    jsr hs_center
hs_no_status
    tst mus_loaded
    bne hs_music_present
    ldx #hs_no_music
    ldab #20
    jsr hs_center
hs_music_present
    ldx #hs_attr_cyan
    jsr hs_attribute
    ldx #hs_prompt
    ldab #21
    jsr hs_center
    ldx #hs_exit_prompt
    ldab #22
    jsr hs_center
    jsr hs_present
hs_wait
    jsr hs_key
    cmpa #27
    beq hs_exit_choice
    cmpa #32
    beq hs_start_choice
    cmpa #$c0
    beq hs_start_choice
    cmpa #13
    bne hs_wait
hs_start_choice
    clrb
    rts
hs_exit_choice
    ldab #1
    rts
; Prepare a hidden indexed framebuffer and its six UI-only colours.
hs_panel
    ldaa #1
    staa hs_ui_active
    ldaa #GB_STOP
    jsr hs_api
    ldaa #GB_MODE
    ldab #1
    jsr hs_api
    ldaa #GB_TARGET
    ldab #5
    jsr hs_api
    ldaa #GB_WINDOW
    ldx #hs_window
    jsr hs_api
    ldx #hs_palette
    stx hs_ui_palette
    ldaa #6
    staa hs_ui_count
hs_palette_loop
    ldx hs_ui_palette
    ldaa #GB_PALETTE
    jsr hs_api
    ldab #4
    abx
    stx hs_ui_palette
    dec hs_ui_count
    bne hs_palette_loop
    ldx #hs_background
    jsr hs_rectangle
    ldx #hs_card
    jsr hs_rectangle
    ldx #hs_banner
    jsr hs_rectangle
    ldx #hs_rule
    jsr hs_rectangle
    ldx #hs_attr_title
    jsr hs_attribute
    ldx #hs_title
    ldab #2
    jsr hs_center
    ; Release exclusive gameplay capture, but retain graphics and audio.
    ldaa #GB_PS2_FLUSH+GB_PS2_CLEAR+GB_PS2_RELEASE
    staa GB_PS2_CONTROL
hs_drain_keys
    int $10
    cmpa #$ff
    beq hs_panel_done
    int $11
    bra hs_drain_keys
hs_panel_done
    rts
hs_present
    ldaa #GB_FLIP
    ldab #5
    jsr hs_api
    ; The music keeps playing while waiting/editing; no blocking BIOS input.
    jmp mus_start
hs_key
    jsr mus_fill
    int $10
    cmpa #$ff
    beq hs_key
    int $11
    rts
hs_rectangle
    ldaa #GB_RECT
    jmp hs_api
hs_attribute
    ldaa #GB_ATTR
    jmp hs_api
; X=string, D=column,row. All UI text uses framebuffer glyphs.
hs_text
    stx hs_ui_pointer
    std hs_ui_cursor
    ldx #hs_ui_cursor
    ldaa #GB_CURSOR
    jsr hs_api
    ldx hs_ui_pointer
    ldaa #GB_PUTS
    jmp hs_api
; X=bounded NUL string, B=row, centre within 40 columns.
hs_center
    stx hs_ui_pointer
    stab hs_ui_cursor+1
    clrb
hs_center_count
    tst 0,x
    beq hs_center_ready
    inx
    incb
    bra hs_center_count
hs_center_ready
    negb
    addb #40
    lsrb
    tba
    ldab hs_ui_cursor+1
    ldx hs_ui_pointer
    jmp hs_text
hs_api
    staa hs_ui_operation
    int GB_INT
    tsta
    beq *+5
    jmp hs_failure
    rts
; D unsigned 0..65535 -> five decimal digits. No ROM decimal scratch used.
hs_decimal
    std hs_value
    ldx #hs_divisors
    stx hs_divisor
    ldx #hs_number
    stx hs_destination
    ldaa #5
    staa hs_digits
hs_digit
    ldaa #'0'
    staa hs_digit_char
hs_subtract
    ldx hs_divisor
    ldd hs_value
    subd 0,x
    bcs hs_digit_ready
    std hs_value
    inc hs_digit_char
    bra hs_subtract
hs_digit_ready
    ldx hs_destination
    ldaa hs_digit_char
    staa 0,x
    inx
    stx hs_destination
    ldx hs_divisor
    inx
    inx
    stx hs_divisor
    dec hs_digits
    bne hs_digit
    rts
; hs_score holds completed score. Only a qualifying, nonzero score asks name.
hs_record
    clr hs_ui_status
    ldd hs_score
    beq hs_record_done
    ldx #hs_table+8
    clr hs_row
hs_rank
    ldd hs_score
    subd 0,x
    bhi hs_qualifies
    ldab #15
    abx
    inc hs_row
    ldaa hs_row
    cmpa #10
    bne hs_rank
hs_record_done
    rts
hs_qualifies
    stx hs_entry
    jsr hs_panel
    ldaa #2
    staa hs_ui_active
    ldx #hs_attr_gold
    jsr hs_attribute
    ldx #hs_name_prompt
    ldab #7
    jsr hs_center
    ldd hs_score
    jsr hs_decimal
    ldx #hs_number
    ldab #10
    jsr hs_center
    ldx #hs_attr_muted
    jsr hs_attribute
    ldx #hs_edit_prompt
    ldab #16
    jsr hs_center
    ldx #hs_confirm_prompt
    ldab #18
    jsr hs_center
    clr hs_name_length
    ldx #hs_player
    ldab #13
hs_name_zero
    clr 0,x
    inx
    decb
    bne hs_name_zero
    jsr hs_edit_name
    jsr hs_present
hs_name_key
    jsr hs_key
    cmpa #$c0
    beq hs_name_done
    cmpa #13
    beq hs_name_done
    cmpa #27
    beq hs_name_done
    cmpa #$7f
    beq hs_name_backspace
    cmpa #8
    beq hs_name_backspace
    cmpa #'a'
    bcs hs_name_upper
    cmpa #'z'
    bhi hs_name_upper
    suba #32
hs_name_upper
    cmpa #32
    bcs hs_name_key
    cmpa #126
    bhi hs_name_key
    ldab hs_name_length
    cmpb #12
    bcc hs_name_key
    ldx #hs_player
    abx
    staa 0,x
    inc hs_name_length
    jsr hs_edit_name
    bra hs_name_key
hs_name_backspace
    tst hs_name_length
    beq hs_name_key
    dec hs_name_length
    ldx #hs_player
    ldab hs_name_length
    abx
    clr 0,x
    jsr hs_edit_name
    bra hs_name_key
hs_name_done
    tst hs_name_length
    bne hs_insert
    ldx #hs_default_player
    stx hs_source
    ldx #hs_player
    stx hs_destination
    jsr hs_copy_string
hs_insert
    ; Shift downward backwards, retaining only the first ten entries.
    ldx #hs_table+142
hs_shift
    cpx hs_entry
    bcs hs_insert_data
    ldaa 0,x
    staa 15,x
    dex
    bra hs_shift
hs_insert_data
    ldx hs_entry
    ldd hs_score
    std 0,x
    inx
    inx
    stx hs_destination
    ldx #hs_player
    stx hs_source
    ldab #13
hs_insert_name
    ldx hs_source
    ldaa 0,x
    inx
    stx hs_source
    ldx hs_destination
    staa 0,x
    inx
    stx hs_destination
    decb
    bne hs_insert_name
    jsr hs_save
    tsta
    beq hs_save_success
    ldaa #2
    staa hs_ui_status
    rts
hs_save_success
    ldaa #1
    staa hs_ui_status
    rts
hs_edit_name
    ldx #hs_player
    stx hs_ui_pointer
    ldx #hs_ui_name
    ldab #13
hs_edit_blank
    ldaa #' '
    staa 0,x
    inx
    decb
    bne hs_edit_blank
    ldx #hs_ui_name
    stx hs_destination
    ldab hs_name_length
    beq hs_edit_cursor
hs_edit_copy
    ldx hs_ui_pointer
    ldaa 0,x
    inx
    stx hs_ui_pointer
    ldx hs_destination
    staa 0,x
    inx
    stx hs_destination
    decb
    bne hs_edit_copy
hs_edit_cursor
    ldx hs_destination
    ldaa #'_'
    staa 0,x
    ldx #hs_attr_white
    jsr hs_attribute
    ldx #hs_ui_name
    ldd #$0d0d
    jmp hs_text
hs_copy_string
    ldx hs_source
    ldaa 0,x
    inx
    stx hs_source
    ldx hs_destination
    staa 0,x
    inx
    stx hs_destination
    tsta
    bne hs_copy_string
    rts
hs_save
    tst hs_unwritable
    beq *+5
    jmp hs_save_bad
    ldd hs_table+4
    addd #1
    std hs_table+4
    ldx #hs_table
    jsr hs_checksum
    std hs_table+158
    ldaa hs_active
    cmpa #0
    beq hs_save_backup
    ldx #hs_primary_name
    jsr hs_asset_path
    clr hs_next_slot
    bra hs_create
hs_save_backup
    ldx #hs_backup_name
    jsr hs_asset_path
    ldaa #1
    staa hs_next_slot
hs_create
    ldd #hs_path
    std hs_io
    clr hs_io+2
    clr hs_io+3
    ldx #hs_io
    clra
    int $4b
    tsta
    beq *+5
    jmp hs_save_bad
    stab hs_handle
    ldd #hs_table
    std hs_io
    ldd #160
    std hs_io+2
    ldaa hs_handle
    ldx #hs_io
    int $4d
    tsta
    bne hs_save_close_bad
    cpx #160
    bne hs_save_close_bad
    ldaa hs_handle
    int $4e
    tsta
    beq *+5
    jmp hs_save_bad
    jsr hs_read
    tsta
    beq *+5
    jmp hs_save_bad
    ldx #hs_probe
    ldab #160
hs_verify
    ldaa 0,x
    cmpa hs_table-hs_probe,x
    beq *+5
    jmp hs_save_bad
    inx
    decb
    bne hs_verify
    ldaa hs_next_slot
    staa hs_active
    clra
    rts
hs_save_close_bad
    ldaa hs_handle
    int $4e
hs_save_bad
    ldaa #1
    rts
hs_divisors dw 10000,1000,100,10,1
hs_number db '00000',0
hs_window db 0,0,40,25
hs_palette
    db 240,8,12,24,241,20,30,53,242,67,220,250
    db 243,239,246,255,244,255,195,62,245,124,145,183
hs_background dw 0,0,320
    db 200,240
hs_card dw 16,8,288
    db 184,241
hs_banner dw 16,8,288
    db 32,242
hs_rule dw 32,48,256
    db 1,245
hs_attr_title db 240,242
hs_attr_gold db 244,241
hs_attr_white db 243,241
hs_attr_muted db 245,241
hs_attr_cyan db 242,241
hs_heading db 'HIGH SCORES',0
hs_columns db ' #  PLAYER            SCORE',0
hs_empty_name db '---',0
hs_last_score db 'LAST SCORE:',0
hs_prompt db 'SPACE / ENTER: PLAY',0
hs_exit_prompt db 'ESC: RETURN TO UNIDOS',0
hs_name_prompt db 'NEW HIGH SCORE!',0
hs_edit_prompt db 'NAME: UP TO 12 CHARACTERS',0
hs_confirm_prompt db 'BACKSPACE: EDIT   ENTER: SAVE',0
hs_default_player db 'PLAYER',0
hs_saved_text db 'HIGH SCORE SAVED',0
hs_failed_text db 'DISK SAVE FAILED - SCORE IN MEMORY',0
hs_no_music db 'MUSIC UNAVAILABLE',0

; Native SWI handler updates the saved result A, as required by UniBIOS.
hs_io_error
    ldaa #3
    staa $06
    rts
hs_unhook
    tst hs_hooked
    beq hs_unhook_done
    stx hs_restore_x
    ldaa #7
    ldab hs_error_page
    ldx hs_error_address
    int $2f
    clr hs_hooked
    ldx hs_restore_x
hs_unhook_done
    rts
