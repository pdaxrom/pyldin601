; Bounded ANSI/VT100 parser. 24 terminal rows + a private status row.
vt_reset
    clr t_x
    clr t_y
    clr t_state
    clr t_wrap
    clr t_origin
    clr t_app
    clr t_newline
    clr t_g0
    clr t_g1
    clr t_charset
    clr t_designate
    clr t_reverse
    clr t_bold
    clr t_blink
    clr t_top
    ldaa #23
    staa t_bottom
    ldaa #1
    staa t_autowrap
    staa t_visible
    ldaa #7
    staa t_fg
    clr t_bg
    jsr vt_attr
    clr t_row
vt_reset_row
    jsr vt_clear_row
    inc t_row
    ldaa t_row
    cmpa #24
    bcs vt_reset_row
    jmp vt_save
vt_attr
    ; Native foreground has 3 bits; attribute bit7 is BLINK, not intensity.
    ldaa t_fg
    asla
    asla
    asla
    asla
    oraa t_bg
    tst t_reverse
    beq vt_attr_blink
    staa t_attr
    asla
    asla
    asla
    asla
    ldab t_attr
    lsrb
    lsrb
    lsrb
    lsrb
    aba
vt_attr_blink
    tst t_blink
    beq vt_attr_ready
    oraa #$80
vt_attr_ready
    staa t_attr
    rts
; t_row/t_col -> X; never changes terminal coordinates.
vt_address
    ldx screen
    ldab t_row
vt_address_row
    tstb
    beq vt_address_col
    pshb
    ldab pitch
    jsr add_b
    pulb
    decb
    bra vt_address_row
vt_address_col
    ldab t_col
    tst cell_bytes
    ldaa cell_bytes
    cmpa #2
    bne vt_address_add
    aslb
vt_address_add
    jmp add_b
vt_here
    ldaa t_x
    staa t_col
    ldaa t_y
    staa t_row
    jmp vt_address
vt_cursor
    tst ui_active
    beq *+5
    jmp vt_cursor_done
    tst t_visible
    beq vt_cursor_hide
    jsr vt_here
    tst $fff7
    bmi vt_cursor_a
    inx
    inx
    bra vt_cursor_write
vt_cursor_a
    ldaa cell_bytes
    cmpa #2
    bne vt_cursor_write
    inx
    bra vt_cursor_write
vt_cursor_hide
    ldx #$3fff
vt_cursor_write
    stx t_cursor
    tpa
    psha
    sei
    ldaa $e600
    psha
    ldaa #14
    staa $e600
    ldaa t_cursor
    staa $e601
    ldaa #15
    staa $e600
    ldaa t_cursor+1
    staa $e601
    pula
    staa $e600
    pula
    tap
vt_cursor_done
    rts
vt_clear_row
    clr t_col
    jsr vt_address
    ldaa columns
    staa t_count
vt_blank
    ldaa cell_bytes
    cmpa #2
    bne vt_blank_char
    ldaa t_attr
    staa 0,x
    inx
vt_blank_char
    ldaa #' '
    staa 0,x
    inx
    tst transfer
    bne vt_blank_no_pump
    jsr pump
vt_blank_no_pump
    dec t_count
    bne vt_blank
    rts
vt_scroll_up
    ldaa t_top
    staa t_row
    clr t_col
    jsr vt_address
    stx t_move+4
    inc t_row
    jsr vt_address
    stx t_move+2
    jsr vt_scroll_dma
    tsta
    bne vt_scroll_up_cpu
    ldaa t_bottom
    staa t_row
    jmp vt_clear_row
vt_scroll_up_cpu
    ldaa t_top
    staa t_row
vt_scroll_up_row
    clr t_col
    jsr vt_address
    stx t_dst
    inc t_row
    jsr vt_address
    stx t_src
    jsr vt_copy_row
    ldaa t_row
    cmpa t_bottom
    bcs vt_scroll_up_row
    jmp vt_clear_row
vt_scroll_down
    ldaa t_top
    staa t_row
    clr t_col
    jsr vt_address
    stx t_move+2
    inc t_row
    jsr vt_address
    stx t_move+4
    jsr vt_scroll_dma
    tsta
    bne vt_scroll_down_cpu
    ldaa t_top
    staa t_row
    jmp vt_clear_row
vt_scroll_down_cpu
    ldaa t_bottom
    staa t_row
vt_scroll_down_row
    clr t_col
    jsr vt_address
    stx t_dst
    dec t_row
    jsr vt_address
    stx t_src
    jsr vt_copy_row
    ldaa t_row
    cmpa t_top
    bhi vt_scroll_down_row
    jmp vt_clear_row
vt_scroll_dma
    ldaa t_bottom
    suba t_top
vt_dma_rows
    staa t_dma_rows
    clr t_move+6
    clr t_move+7
vt_dma_count
    ldaa t_move+7
    adda pitch
    staa t_move+7
    bcc vt_dma_count_next
    inc t_move+6
vt_dma_count_next
    dec t_dma_rows
    bne vt_dma_count
    ldx #$ffff
    stx t_move
    ldx #t_move
    ldaa #1
    int $e8
    rts

vt_copy_row
    ldaa columns
    ldab cell_bytes
    cmpb #2
    bne vt_copy_count
    asla
vt_copy_count
    staa t_count
vt_copy_byte
    ldx t_src
    ldaa 0,x
    inx
    stx t_src
    ldx t_dst
    staa 0,x
    inx
    stx t_dst
    jsr pump
    dec t_count
    bne vt_copy_byte
    rts
vt_lf
    clr t_wrap
    ldaa t_y
    cmpa t_bottom
    bne *+5
    jmp vt_scroll_up
    cmpa #23
    bcc vt_lf_done
    inc t_y
vt_lf_done
    rts
vt_ri
    clr t_wrap
    ldaa t_y
    cmpa t_top
    bne *+5
    jmp vt_scroll_down
    tsta
    beq vt_lf_done
    dec t_y
    rts
vt_byte
    staa t_char
    cmpa #27
    bne *+5
    jmp vt_escape
    cmpa #24
    beq vt_cancel
    cmpa #26
    beq vt_cancel
    ldaa t_state
    cmpa #4
    bcs *+5
    jmp vt_string
    ldaa t_char
    cmpa #32
    bcc *+5
    jmp vt_control
    cmpa #127
    beq vt_done
    ldab t_state
    bne *+5
    jmp vt_print
    cmpb #1
    bne *+5
    jmp vt_esc_byte
    cmpb #3
    bne *+5
    jmp vt_designate
    jmp vt_csi
vt_cancel
    clr t_state
vt_done
    rts
vt_escape
    ldaa t_state
    cmpa #4
    bcs vt_escape_start
    ldaa #5
    staa t_state
    rts
vt_escape_start
    ldaa #1
    staa t_state
    rts
vt_string
    ldaa t_char
    cmpa #7
    beq vt_cancel
    ldab t_state
    cmpb #5
    bne vt_done
    cmpa #92
    beq vt_cancel
    ldaa #4
    staa t_state
    rts
vt_designate
    clr t_state
    ldab t_designate
    cmpb #2
    beq vt_done
    cmpa #'0'
    beq vt_designate_set
    clra
vt_designate_set
    tst t_designate
    bne vt_designate_g1
    staa t_g0
    rts
vt_designate_g1
    staa t_g1
    rts
vt_control
    cmpa #13
    beq vt_cr
    cmpa #10
    bne *+5
    jmp vt_linefeed
    cmpa #11
    beq vt_linefeed
    cmpa #12
    beq vt_linefeed
    cmpa #8
    bne *+5
    jmp vt_bs
    cmpa #9
    bne *+5
    jmp vt_tab
    cmpa #14
    beq vt_so
    cmpa #15
    beq vt_si
    rts
vt_so
    ldaa #1
    staa t_charset
    rts
vt_si
    clr t_charset
    rts
vt_cr
    clr t_x
    clr t_wrap
    rts
vt_linefeed
    tst t_newline
    bne *+5
    jmp vt_lf
    clr t_x
    jmp vt_lf
vt_bs
    clr t_wrap
    tst t_x
    bne *+5
    jmp vt_done
    dec t_x
    rts
vt_tab
    clr t_wrap
    ldaa t_x
    oraa #7
    inca
    cmpa columns
    bcs vt_tab_store
    ldaa columns
    deca
vt_tab_store
    staa t_x
    rts
vt_print
    tst t_wrap
    beq vt_print_here
    clr t_wrap
    tst t_autowrap
    beq vt_print_here
    clr t_x
    jsr vt_lf
vt_print_here
    jsr vt_here
    ldaa cell_bytes
    cmpa #2
    bne vt_print_char
    ldaa t_attr
    staa 0,x
    inx
vt_print_char
    stx t_dst
    ldaa t_g0
    tst t_charset
    beq vt_print_set
    ldaa t_g1
vt_print_set
    tsta
    beq vt_print_raw
    ldaa t_char
    cmpa #'j'
    bcs vt_print_raw
    cmpa #'x'
    bhi vt_print_raw
    suba #'j'
    tab
    ldx #vt_graphics
    jsr add_b
    ldaa 0,x
    bra vt_print_store
vt_print_raw
    ldaa t_char
vt_print_store
    ldx t_dst
    staa 0,x
    inc t_x
    ldaa t_x
    cmpa columns
    bcc *+5
    jmp vt_done
    dec t_x
    inc t_wrap
    rts
vt_esc_byte
    clr t_state
    cmpa #'['
    bne *+5
    jmp vt_csi_start
    cmpa #']'
    beq vt_string_start
    cmpa #'P'
    beq vt_string_start
    cmpa #'#'
    bne *+5
    jmp vt_hash_start
    cmpa #'('
    beq vt_g0_start
    cmpa #')'
    beq vt_g1_start
    cmpa #'7'
    bne *+5
    jmp vt_save
    cmpa #'8'
    bne *+5
    jmp vt_restore
    cmpa #'D'
    bne *+5
    jmp vt_lf
    cmpa #'M'
    bne *+5
    jmp vt_ri
    cmpa #'E'
    beq vt_next_line
    cmpa #'c'
    bne *+5
    jmp vt_reset
    cmpa #'Z'
    bne *+5
    jmp vt_identify
    rts
vt_string_start
    ldaa #4
    staa t_state
    rts
vt_hash_start
    ldaa #2
    staa t_designate
    bra vt_g_start
vt_g0_start
    clr t_designate
    bra vt_g_start
vt_g1_start
    ldaa #1
    staa t_designate
vt_g_start
    ldaa #3
    staa t_state
    rts
vt_next_line
    clr t_x
    jmp vt_lf
vt_save
    ldaa t_x
    staa t_saved_x
    ldaa t_y
    staa t_saved_y
    ldaa t_attr
    staa t_saved_attr
    ldaa t_fg
    staa t_saved_fg
    ldaa t_bg
    staa t_saved_bg
    ldaa t_bold
    staa t_saved_bold
    ldaa t_reverse
    staa t_saved_reverse
    ldaa t_g0
    staa t_saved_g0
    ldaa t_g1
    staa t_saved_g1
    ldaa t_charset
    staa t_saved_charset
    ldaa t_blink
    staa t_saved_blink
    rts
vt_restore
    ldaa t_saved_x
    staa t_x
    ldaa t_saved_y
    staa t_y
    ldaa t_saved_attr
    staa t_attr
    ldaa t_saved_fg
    staa t_fg
    ldaa t_saved_bg
    staa t_bg
    ldaa t_saved_bold
    staa t_bold
    ldaa t_saved_reverse
    staa t_reverse
    ldaa t_saved_g0
    staa t_g0
    ldaa t_saved_g1
    staa t_g1
    ldaa t_saved_charset
    staa t_charset
    ldaa t_saved_blink
    staa t_blink
    clr t_wrap
    rts
vt_identify
    ldx #vt_id
    jmp reply
vt_csi_start
    ldaa #2
    staa t_state
    clr t_private
    clr t_bad
    clr t_param_index
    ldx #t_params
    ldab #8
vt_params_clear
    clr 0,x
    inx
    decb
    bne vt_params_clear
    rts
vt_csi
    cmpa #'?'
    bne *+5
    jmp vt_private
    cmpa #'0'
    bcc *+5
    jmp vt_csi_other
    cmpa #'9'
    bls *+5
    jmp vt_csi_other
    suba #'0'
    staa t_digit
    ldab t_param_index
    ldx #t_params
    jsr add_b
    ldaa 0,x
    cmpa #25
    bhi vt_bad
    tab
    asla
    asla
    aba
    asla
    adda t_digit
    bcs vt_bad
    staa 0,x
    rts
vt_bad
    inc t_bad
    rts
vt_private
    ldaa #1
    staa t_private
    rts
vt_csi_other
    cmpa #';'
    bne *+5
    jmp vt_param_next
    cmpa #$40
    bcs vt_bad
    cmpa #$7e
    bls *+5
    jmp vt_cancel
    clr t_state
    tst t_bad
    beq *+5
    jmp vt_done
    clr t_wrap
    staa t_final
    ldaa t_params
    bne vt_count_ready
    inca
vt_count_ready
    staa t_n
    tst t_private
    beq *+5
    jmp vt_modes
    ldaa t_final
    cmpa #'H'
    bne *+5
    jmp vt_cup
    cmpa #'f'
    bne *+5
    jmp vt_cup
    cmpa #'A'
    bne *+5
    jmp vt_up
    cmpa #'B'
    bne *+5
    jmp vt_down
    cmpa #'C'
    bne *+5
    jmp vt_right
    cmpa #'D'
    bne *+5
    jmp vt_left
    cmpa #'G'
    bne *+5
    jmp vt_column
    cmpa #'d'
    bne *+5
    jmp vt_row
    cmpa #'J'
    bne *+5
    jmp vt_erase_display
    cmpa #'K'
    bne *+5
    jmp vt_erase_line
    cmpa #'m'
    bne *+5
    jmp vt_sgr
    cmpa #'r'
    bne *+5
    jmp vt_margins
    cmpa #'s'
    bne *+5
    jmp vt_save
    cmpa #'u'
    bne *+5
    jmp vt_restore
    cmpa #'h'
    bne *+5
    jmp vt_modes
    cmpa #'l'
    bne *+5
    jmp vt_modes
    cmpa #'c'
    bne *+5
    jmp vt_identify
    cmpa #'n'
    bne *+5
    jmp vt_report
    rts
vt_param_next
    ldaa t_param_index
    cmpa #7
    bcs *+5
    jmp vt_bad
    inc t_param_index
    rts
vt_cup
    jsr vt_row
vt_column
    ldaa t_params+1
    ldab t_final
    cmpb #'G'
    bne vt_col_value
    ldaa t_params
vt_col_value
    tsta
    beq vt_col_zero
    deca
vt_col_zero
    cmpa columns
    bcs vt_col_store
    ldaa columns
    deca
vt_col_store
    staa t_x
    rts
vt_row
    ldaa t_n
    deca
    tst t_origin
    beq vt_row_limit
    adda t_top
vt_row_limit
    ldab #23
    tst t_origin
    beq vt_row_cap
    ldab t_bottom
vt_row_cap
    sba
    bcs vt_row_uncap
    beq vt_row_uncap
    tba
    bra vt_row_store
vt_row_uncap
    aba
vt_row_store
    staa t_y
    rts
vt_up
    ldaa t_y
    suba t_n
    bcc vt_up_cap
    clra
vt_up_cap
    tst t_origin
    beq vt_move_y
    cmpa t_top
    bcc vt_move_y
    ldaa t_top
vt_move_y
    staa t_y
    rts
vt_down
    ldaa t_y
    adda t_n
    bcs vt_down_cap
    cmpa #23
    bls vt_down_origin
vt_down_cap
    ldaa #23
vt_down_origin
    tst t_origin
    beq vt_move_y
    cmpa t_bottom
    bls vt_move_y
    ldaa t_bottom
    bra vt_move_y
vt_left
    ldaa t_x
    suba t_n
    bcs *+5
    jmp vt_col_store
    clra
    jmp vt_col_store
vt_right
    ldaa t_x
    adda t_n
    bcs *+5
    jmp vt_col_zero
    ldaa columns
    deca
    jmp vt_col_store
vt_margins
    ldaa t_n
    deca
    cmpa #23
    bcs *+5
    jmp vt_done
    staa t_newtop
    ldaa t_params+1
    bne vt_margin_last
    ldaa #24
vt_margin_last
    deca
    cmpa #24
    bcs *+5
    jmp vt_done
    cmpa t_newtop
    bhi *+5
    jmp vt_done
    staa t_bottom
    ldaa t_newtop
    staa t_top
    clr t_x
    clr t_y
    tst t_origin
    bne *+5
    jmp vt_done
    staa t_y
    rts
vt_modes
    ldaa t_final
    cmpa #'h'
    beq vt_mode_set
    cmpa #'l'
    beq *+5
    jmp vt_done
    clrb
    bra vt_mode_value
vt_mode_set
    ldab #1
vt_mode_value
    tst t_private
    bne *+5
    jmp vt_mode_ansi
    ldaa t_params
    cmpa #1
    beq vt_mode_app
    cmpa #6
    beq vt_mode_origin
    cmpa #7
    beq vt_mode_wrap
    cmpa #25
    beq *+5
    jmp vt_done
    stab t_visible
    rts
vt_mode_app
    stab t_app
    rts
vt_mode_origin
    stab t_origin
    clr t_x
    clr t_y
    tstb
    bne *+5
    jmp vt_done
    ldaa t_top
    staa t_y
    rts
vt_mode_wrap
    stab t_autowrap
    rts
vt_mode_ansi
    ldaa t_params
    cmpa #20
    beq *+5
    jmp vt_done
    stab t_newline
    rts
vt_erase_line
    ldaa t_y
    staa t_row
    ldaa t_params
    beq vt_erase_right
    cmpa #1
    beq vt_erase_left
    cmpa #2
    bne *+5
    jmp vt_clear_row
    rts
vt_erase_right
    ldaa t_x
    staa t_col
    jsr vt_address
    ldaa columns
    suba t_x
    staa t_count
    jmp vt_blank
vt_erase_left
    clr t_col
    jsr vt_address
    ldaa t_x
    inca
    staa t_count
    jmp vt_blank
vt_erase_display
    ldaa t_params
    cmpa #2
    beq vt_erase_all
    tsta
    beq vt_erase_after
    cmpa #1
    beq *+5
    jmp vt_done
    jsr vt_erase_left
    clr t_row
vt_erase_before
    ldaa t_row
    cmpa t_y
    bcs *+5
    jmp vt_done
    jsr vt_clear_row
    inc t_row
    bra vt_erase_before
vt_erase_after
    jsr vt_erase_line
    ldaa t_y
    inca
    staa t_row
    bra vt_erase_rows
vt_erase_all
    clr t_row
vt_erase_rows
    ldaa t_row
    cmpa #24
    bcs *+5
    jmp vt_done
    jsr vt_clear_row
    inc t_row
    bra vt_erase_rows
vt_sgr
    clr t_sgr_index
vt_sgr_next
    ldx #t_params
    ldab t_sgr_index
    jsr add_b
    ldaa 0,x
    tsta
    bne vt_sgr_bold
    clr t_bold
    clr t_blink
    clr t_reverse
    clr t_bg
    ldaa #7
    staa t_fg
    jmp vt_sgr_advance
vt_sgr_bold
    cmpa #1
    bne vt_sgr_normal
    inc t_bold
    jmp vt_sgr_advance
vt_sgr_normal
    cmpa #22
    bne vt_sgr_reverse
    clr t_bold
    jmp vt_sgr_advance
vt_sgr_reverse
    cmpa #5
    bne vt_sgr_no_blink
    ldaa #1
    staa t_blink
    bra vt_sgr_advance
vt_sgr_no_blink
    cmpa #25
    bne vt_sgr_test_reverse
    clr t_blink
    bra vt_sgr_advance
vt_sgr_test_reverse
    cmpa #7
    bne vt_sgr_unreverse
    inc t_reverse
    jmp vt_sgr_advance
vt_sgr_unreverse
    cmpa #27
    bne vt_sgr_fg
    clr t_reverse
    bra vt_sgr_advance
vt_sgr_fg
    cmpa #39
    bne vt_sgr_bg_default
    ldaa #7
    staa t_fg
    bra vt_sgr_advance
vt_sgr_bg_default
    cmpa #49
    bne vt_sgr_colour
    clr t_bg
    bra vt_sgr_advance
vt_sgr_colour
    suba #30
    cmpa #8
    bcs vt_sgr_fg_store
    suba #10
    cmpa #8
    bcc vt_sgr_advance
    tab
    ldx #vt_colours
    jsr add_b
    ldaa 0,x
    staa t_bg
    bra vt_sgr_advance
vt_sgr_fg_store
    tab
    ldx #vt_colours
    jsr add_b
    ldaa 0,x
    staa t_fg
vt_sgr_advance
    ldaa t_sgr_index
    cmpa t_param_index
    bne *+5
    jmp vt_attr
    inc t_sgr_index
    jmp vt_sgr_next
vt_report
    ldaa t_params
    cmpa #5
    bne vt_report_cursor
    ldx #vt_ok
    jmp reply
vt_report_cursor
    cmpa #6
    beq *+5
    jmp vt_done
    ldx #t_response
    ldaa #27
    staa 0,x
    ldaa #'['
    staa 1,x
    inx
    inx
    ldaa t_y
    inca
    jsr vt_decimal
    ldaa #';'
    staa 0,x
    inx
    ldaa t_x
    inca
    jsr vt_decimal
    ldaa #'R'
    staa 0,x
    clr 1,x
    ldx #t_response
    jmp reply
vt_decimal
    clrb
vt_decimal_tens
    cmpa #10
    bcs vt_decimal_units
    suba #10
    incb
    bra vt_decimal_tens
vt_decimal_units
    tstb
    beq vt_decimal_one
    addb #'0'
    stab 0,x
    inx
vt_decimal_one
    adda #'0'
    staa 0,x
    inx
    rts
vt_key
    cmpa #$c0
    bne vt_key_tab
    ldaa #13
    jmp term_send
vt_key_tab
    cmpa #$ed
    bne vt_key_bs
    ldaa #9
    jmp term_send
vt_key_bs
    cmpa #127
    bne vt_key_left
    ldaa #8
    jmp term_send
vt_key_left
    cmpa #$c1
    bne vt_key_right
    ldaa #'D'
    jmp vt_key_arrow
vt_key_right
    cmpa #$c2
    bne vt_key_down
    ldaa #'C'
    bra vt_key_arrow
vt_key_down
    cmpa #$c3
    bne vt_key_up
    ldaa #'B'
    bra vt_key_arrow
vt_key_up
    cmpa #$c4
    bne vt_key_home
    ldaa #'A'
    bra vt_key_arrow
vt_key_home
    cmpa #$c5
    bne vt_key_end
    ldaa #'H'
    bra vt_key_arrow
vt_key_end
    cmpa #$c6
    bne vt_key_delete
    ldaa #'F'
vt_key_arrow
    staa t_response+2
    ldaa #27
    staa t_response
    ldaa #'['
    tst t_app
    beq vt_key_arrow_normal
    ldaa #'O'
vt_key_arrow_normal
    staa t_response+1
    clr t_response+3
    ldx #t_response
    jmp reply
vt_key_delete
    cmpa #$f9
    bne vt_key_pgup
    ldx #vt_delete
    jmp reply
vt_key_pgup
    cmpa #$c7
    bne vt_key_pgdown
    ldx #vt_page_up
    jmp reply
vt_key_pgdown
    cmpa #$c8
    bne vt_key_plain
    ldx #vt_page_down
    jmp reply
vt_key_plain
    cmpa #$c0
    bcs *+5
    jmp vt_done
    jmp term_send
vt_colours db 0,4,2,6,1,5,3,7
vt_graphics db $d9,$cf,$da,$c0,$c5,'-','-',$c4,'-','-',$c3,$d4,$c1,$c2,$d3
vt_id db 27,'[?1;0c',0
vt_ok db 27,'[0n',0
vt_delete db 27,'[3~',0
vt_page_up db 27,'[5~',0
vt_page_down db 27,'[6~',0
    section
t_x ds 1
t_y ds 1
t_state ds 1
t_wrap ds 1
t_origin ds 1
t_app ds 1
t_newline ds 1
t_g0 ds 1
t_g1 ds 1
t_charset ds 1
t_designate ds 1
t_reverse ds 1
t_bold ds 1
t_blink ds 1
t_top ds 1
t_bottom ds 1
t_autowrap ds 1
t_visible ds 1
t_fg ds 1
t_bg ds 1
t_attr ds 1
t_row ds 1
t_col ds 1
t_count ds 1
t_cursor ds 2
t_char ds 1
t_dst ds 2
t_src ds 2
t_saved_x ds 1
t_saved_y ds 1
t_saved_attr ds 1
t_saved_fg ds 1
t_saved_bg ds 1
t_saved_bold ds 1
t_saved_blink ds 1
t_saved_reverse ds 1
t_saved_g0 ds 1
t_saved_g1 ds 1
t_saved_charset ds 1
t_private ds 1
t_bad ds 1
t_param_index ds 1
t_params ds 8
t_digit ds 1
t_final ds 1
t_n ds 1
t_newtop ds 1
t_sgr_index ds 1
t_response ds 16
t_move ds 8
t_dma_rows ds 1
    ends
