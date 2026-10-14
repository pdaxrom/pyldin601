; Native text and graphics share the ROM font (see NCVIDEO.INC).
; NC colours: light grey on blue, black on cyan, yellow marked names.
; Pyldin's Cyrillic font differs from PC code pages at CF and D3.
BOX_TOP_LEFT equ $da
BOX_TOP_RIGHT equ $cf
BOX_BOTTOM_LEFT equ $c0
BOX_BOTTOM_RIGHT equ $d9
BOX_HORIZONTAL equ $c4
BOX_VERTICAL equ $d3
BOX_LEFT_TEE equ $c3
BOX_RIGHT_TEE equ $d4
render
    clr menu_active
    jsr render_menu_bar
    clr draw_panel
    jsr render_one_panel
    inc draw_panel
    jsr render_one_panel
    ldaa active
    jsr choose_panel
    jsr render_command_line
    clr ui_x
    ldaa ui_keys
    staa ui_y
    jsr position
    ldaa columns
    staa remaining
    ldx #keys_short
    ldaa columns
    cmpa #80
    bcs render_keys
    ldx #keys_long
render_keys
    stx textptr
render_key_character
    ldx textptr
    ldaa 0,x
    beq render_key_padding
    inx
    stx textptr
    psha
    cmpa #'0'
    bcs render_key_label
    cmpa #'9'
    bhi render_key_label
    ldaa #$70
    bra render_key_colour
render_key_label
    ldaa #$03
render_key_colour
    jsr colour
    pula
    jsr put_field
    bra render_key_character
render_key_padding
    ldaa #$03
    jsr colour
    jsr padding

render_done
    rts
render_one_panel
    ldaa draw_panel
    jsr choose_panel
    jsr render_prepare
    jsr render_panel_header
    jsr render_column_headings
    jsr render_panel_body
    ldaa origin
    staa ui_x
    ldaa ui_end
    staa ui_y
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_LEFT_TEE
    jsr put
    ldaa panel_width
    suba #2
    staa remaining
    ldaa #BOX_HORIZONTAL
    staa fill_char
    jsr fill_field
    ldaa #BOX_RIGHT_TEE
    jsr put
    jsr render_panel_info
    ldaa origin
    staa ui_x
    ldaa ui_bottom
    staa ui_y
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_BOTTOM_LEFT
    jsr put
    ldaa panel_width
    suba #2
    staa remaining
    ldaa #BOX_HORIZONTAL
    staa fill_char
    jsr free_text_pointer
    jsr right_field
    ldaa #BOX_BOTTOM_RIGHT
    jsr put
    rts
; The active catalogue is already cached for ordinary navigation.
render_prepare
    ldaa pcur
    cmpa pcount
    bcs render_cursor_ok
    ldaa pcount
    deca
    staa pcur
    jsr store_cursor
render_cursor_ok
    ldaa pcur
    cmpa ptop
    bcs render_new_top
    suba ptop
    cmpa ui_rows
    bcs render_top_ok
    ldaa pcur
    suba ui_rows
    inca
render_new_top
    staa ptop
render_top_ok
    ; The parent is visible only at the actual start of the directory.
    tst ptop
    bne render_visible_top
    ldab panel
    ldx #has_previous
    jsr add_b
    tst 0,x
    beq render_visible_top
    inc ptop
render_visible_top
    ldab panel
    ldx #tops
    jsr add_b
    ldaa ptop
    staa 0,x
    clr origin
    tst draw_panel
    beq render_origin
    ldaa panel_width
    staa origin
render_origin
    ldaa origin
    staa ui_x
    rts
render_panel_header
    ldaa origin
    staa ui_x
    ldaa #1
    staa ui_y
    ldaa #$31
    ldab draw_panel
    cmpb active
    bne render_header
    ldaa #$03
render_header
    staa header_ink
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_TOP_LEFT
    jsr put
    ldaa header_ink
    jsr colour
    ldaa panel_width
    suba #2
    staa remaining
    ldx pathptr
    jsr text_field
    ldaa #$31
    jsr colour
    ldaa #BOX_HORIZONTAL
    staa fill_char
    jsr fill_field
    ldaa #BOX_TOP_RIGHT
    jsr put
    rts
render_column_headings
    ldaa origin
    staa ui_x
    ldaa #2
    staa ui_y
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #$61
    jsr colour
    ldaa panel_width
    suba #2
    staa remaining
    ldaa columns
    cmpa #80
    bcs render_name_heading
    ldaa #13
    staa remaining
render_name_heading
    ldx #name_heading
    jsr field
    ldaa columns
    cmpa #80
    bcc nc_long_ncui_1_801
    jmp render_row_border
nc_long_ncui_1_801
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #10
    staa remaining
    ldx #size_heading
    ldaa #' '
    staa fill_char
    jsr right_field
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #13
    staa remaining
    ldx #date_heading
    jsr field
    jmp render_row_border
render_panel_body
    ldaa #UI_FIRST
    staa ui_y
    ldaa ptop
    staa draw_index
render_rows
    jsr render_row
    inc draw_index
    inc ui_y
    ldaa ui_y
    cmpa ui_end
    bcs render_rows
    rts
render_row
    ldaa origin
    staa ui_x
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #$71
    jsr colour
    ldaa draw_index
    cmpa pcount
    bcs render_valid_entry
    clr row_entry
    clr row_entry+1
    clr name_text
    ldaa #' '
    jsr put
    bra render_name_field
render_valid_entry
    jsr entry_pointer
    stx row_entry
    ldaa 12,x
    beq render_not_marked
    ldaa #$61
    jsr colour
render_not_marked
    ldaa draw_panel
    cmpa active
    bne render_not_cursor
    ldaa draw_index
    cmpa pcur
    bne render_not_cursor
    ldaa #$03
    jsr colour
    ldaa #'>'
    bra render_marker
render_not_cursor
    ldx row_entry
    ldaa 12,x
    beq render_unmarked
    ldaa #'*'
    bra render_marker
render_unmarked
    ldaa #' '
render_marker
    jsr put
    ldx #name_text
    stx dst
    ldx row_entry
    jsr record_name
render_name_field
    ldaa #12
    staa remaining
    ldx #name_text
    jsr field
    ldaa columns
    cmpa #80
    bcc render_wide_fields
    ldaa #5
    staa remaining
    ldx row_entry
    beq render_empty
    ldaa 11,x
    bita #16
    beq render_empty
    jsr directory_label
    jsr field
    jmp render_row_border
render_wide_fields
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #10
    staa remaining
    ldx row_entry
    beq render_empty_size
    ldaa 11,x
    bita #16
    beq render_file_size
    jsr directory_label
    bra render_size_text
render_file_size
    ldab #E_SIZE
    jsr add_b
    jsr decimal_le
    ldx #number_text
render_size_text
    ldaa #' '
    staa fill_char
    jsr right_field
    bra render_date_field
render_empty_size
    jsr padding
render_date_field
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #13
    staa remaining
    jsr render_file_date
render_empty
    jsr padding
render_row_border
    ldaa #$31
    jsr colour
    ldaa #BOX_VERTICAL
    jmp put

directory_label
    ldaa 0,x
    ldx #dir_text
    cmpa #'.'
    bne directory_label_done
    ldx #up_text
directory_label_done
    rts

; DD.MM [YYYY] HH:MM from the native little-endian FAT date/time. Parent/unknown
; timestamps stay blank; formatting uses no DOS calls or bank transfers.
render_file_date
    ldx row_entry
    bne nc_long_ncui_2_786
    jmp render_date_done
nc_long_ncui_2_786
    ldaa E_DATE,x
    oraa E_DATE+1,x
    bne nc_long_ncui_3_786
    jmp render_date_done
nc_long_ncui_3_786
    ldaa E_DATE,x
    anda #31
    jsr date_two
    ldaa #'.'
    jsr put_field
    ldx row_entry
    ldaa E_DATE+1,x
    asla
    asla
    asla
    anda #8
    staa field_padding
    ldaa E_DATE,x
    lsra
    lsra
    lsra
    lsra
    lsra
    oraa field_padding
    jsr date_two
    ldaa remaining
    cmpa #20
    bcs render_date_time
    ldaa #'.'
    jsr put_field
    clr number
    clr number+1
    ldaa #7
    staa number+2
    ldx row_entry
    ldaa E_DATE+1,x
    lsra
    adda #188
    staa number+3
    bcc render_date_year
    inc number+2
render_date_year
    jsr decimal_number
    ldx #number_text
    jsr text_field
render_date_time
    ldaa #' '
    jsr put_field
    ldx row_entry
    ldaa E_TIME+1,x
    lsra
    lsra
    lsra
    jsr date_two
    ldaa #':'
    jsr put_field
    ldx row_entry
    ldaa E_TIME+1,x
    anda #7
    asla
    asla
    asla
    staa field_padding
    ldaa E_TIME,x
    lsra
    lsra
    lsra
    lsra
    lsra
    oraa field_padding
    jsr date_two
render_date_done
    rts
date_two
    clrb
date_tens
    cmpa #10
    bcs date_digits
    suba #10
    incb
    bra date_tens
date_digits
    psha
    tba
    adda #'0'
    jsr put_field
    pula
    adda #'0'
    jmp put_field

render_active_info
render_panel_info
    ldaa origin
    staa ui_x
    ldaa ui_info
    staa ui_y
    jsr info_line_start
    ldaa pcur
    jsr entry_pointer
    stx row_entry
    ldx #name_text
    stx dst
    ldx row_entry
    jsr record_name
    ldaa panel_width
    suba #6
    staa remaining
    ldx #name_text
    jsr field
    ldab #1
    ldx #attribute_names
    stx textptr
info_attribute
    pshb
    ldx row_entry
    ldaa #'-'
    bitb E_ATTR,x
    beq info_attribute_put
    ldx textptr
    ldaa 0,x
info_attribute_put
    jsr put
    ldx textptr
    inx
    stx textptr
    pulb
    aslb
    cmpb #8
    bne info_attribute_archive
    ldab #32
info_attribute_archive
    cmpb #64
    bcs info_attribute
    jsr render_row_border
    inc ui_y
    ldaa origin
    staa ui_x
    jsr info_line_start
    ldaa panel_width
    suba #2
    staa remaining
    jsr render_file_date
    ldx row_entry
    ldaa E_ATTR,x
    bita #16
    beq info_file_size
    jsr directory_label
    bra info_size_text
info_file_size
    ldab #E_SIZE
    jsr add_b
    jsr decimal_le
    ldx #number_text
    jsr path_length
    cmpb remaining
    bcs info_size_ready
    ; Compact text uses KiB/MiB when the exact byte count would touch time.
    ldx row_entry
    ldaa E_SIZE+3,x
    staa number
    ldaa E_SIZE+2,x
    staa number+1
    ldaa E_SIZE+1,x
    staa number+2
    ldaa E_SIZE,x
    staa number+3
    ldaa #'K'
    staa info_unit
info_scale
    ldab #10
info_shift
    lsr number
    ror number+1
    ror number+2
    ror number+3
    decb
    bne info_shift
    ldaa number
    oraa number+1
    bne info_scale_more
    ldaa number+2
    cmpa #39
    bcs info_scaled
    bne info_scale_more
    ldaa number+3
    cmpa #16
    bcs info_scaled
info_scale_more
    ldaa #'M'
    staa info_unit
    bra info_scale
info_scaled
    jsr decimal_number
    ldx #number_text
    jsr end_z
    ldaa info_unit
    staa 0,x
    clr 1,x
info_size_ready
    ldx #number_text
info_size_text
    ldaa #' '
    staa fill_char
    jsr right_field
    jsr padding
    jmp render_row_border
info_line_start
    ldaa #$31
    jsr colour
    jsr position
    ldaa #BOX_VERTICAL
    jsr put
    ldaa #$71
    jmp colour

; Both panels retain a formatted free-space string. Only catalogue refresh
; queries INT52; navigation and painting use these strings directly.
free_text_pointer
    ldx #free_left
    tst panel
    beq free_text_ready
    ldx #free_right
free_text_ready
    rts
query_free_space
    ldx pathptr
    ldaa 0,x
    suba #'A'
    ldx #free_query
    int $52
    tsta
    bne free_space_unknown
    ldx free_query
    stx number
    ldx free_query+2
    stx number+2
    jsr decimal_number
    jsr free_text_pointer
    stx dst
    ldx #number_text
    stx src
    jsr copy_z
    ldx #free_suffix
    bra free_space_copy
free_space_unknown
    jsr free_text_pointer
    stx dst
    ldx #free_unknown
free_space_copy
    stx src
    jmp copy_z

; X=string, remaining=field width, fill_char=left padding glyph.
right_field
    stx field_ptr
    jsr path_length
    ldaa remaining
    sba
    bcs right_field_text
    staa field_padding
right_field_pad
    tst field_padding
    beq right_field_text
    ldaa fill_char
    jsr put_field
    dec field_padding
    bra right_field_pad
right_field_text
    ldx field_ptr
    jmp text_field

render_command_line
    clr ui_x
    ldaa ui_command
    staa ui_y
    ldaa #$70
    jsr colour
    jsr position
    ; Keep room for input even when the active directory has a long name.
    ldaa columns
    lsra
    staa remaining
    ldx pathptr
    jsr text_field
    ldaa columns
    lsra
    adda remaining
    staa remaining
    ldaa #'>'
    jsr put_field
    ldx #command_line
    jsr field
    rts
; X=32-bit little-endian integer -> zero-terminated decimal, no 64K truncation.
decimal_le
    ldaa 3,x
    staa number
    ldaa 2,x
    staa number+1
    ldaa 1,x
    staa number+2
    ldaa 0,x
    staa number+3
decimal_number
    ldaa #10
    staa number_divisor
    ldx #number_text+10
    clr 0,x
    stx number_ptr
decimal_digit
    jsr divide_number
    ldaa remainder
    adda #'0'
    ldx number_ptr
    dex
    staa 0,x
    stx number_ptr
    ldaa number
    oraa number+1
    oraa number+2
    oraa number+3
    bne decimal_digit
    ; Stop when the quotient reaches zero, rather than doing ten complete
    ; 32-bit divisions for every small file on every newly exposed row.
    ldx number_ptr
    stx src
    ldx #number_text
    stx dst
    jsr copy_z
    rts
; Unsigned BE32 / byte, quotient in number, remainder in remainder.
divide_number
    clr remainder
    ldx #number
    ldab #4
decimal_byte
    pshb
    ldab #8
decimal_bit
    asl 0,x
    rol remainder
    ldaa remainder
    cmpa number_divisor
    bcs decimal_less
    suba number_divisor
    staa remainder
    inc 0,x
decimal_less
    decb
    bne decimal_bit
    inx
    pulb
    decb
    bne decimal_byte
    rts
    include NCVIDEO.INC

line_text
    ldaa columns
    staa remaining
field
    jsr text_field
padding
    ldaa #' '
    staa fill_char
fill_field
    tst remaining
    beq field_done
    ldaa fill_char
    jsr put_field
    bra fill_field
field_done
    rts
text_field
    stx textptr
text_loop
    tst remaining
    beq text_done
    ldx textptr
    ldaa 0,x
    beq text_done
    inx
    stx textptr
    jsr put_field
    bra text_loop
text_done
    rts
put_field
    tst remaining
    beq field_done
    dec remaining
    jmp put
    include NCWINDOW.INC
    include NCMENU.INC

change_drive
    clr input
    ldx #drive_prompt
    jsr dialog
    bcs drive_done
    ldaa input
    anda #$df
    suba #'A'
    cmpa #8
    bcc drive_done
    int $5c
    tsta
    bne drive_error
    ldaa active
    jsr choose_panel
    ldaa input
    anda #$df
    ldx pathptr
    staa 0,x
    ldaa #':'
    staa 1,x
    ldaa #'\'
    staa 2,x
    clr 3,x
    jsr page_flag_pointer
    clr 0,x
    clr pcur
    jsr store_cursor
    jmp refresh
drive_error
    jsr error
drive_done
    jmp redraw
