; NCMAIN: Panel startup, command loop and dispatch.
    include NCABI.INC
    include NCBOX.INC
    public edit_file
    public image_type
    public image_request
    public enter
    public leave
    public owner
    public redraw
    public refresh
    public shell_request
    extern mouse_wait
    extern mouse_init
    extern mouse_close
    extern mouse_height
    extern mouse_show
    extern mouse_action
    extern mouse_activate
    extern active
    extern add_b
    extern bank_valid
    extern bss_end
    extern cache_close
    extern cache_open
    extern cache_valid
    extern choose_panel
    extern columns
    extern command_length
    extern command_line
    extern copy_n
    extern copy_z
    extern cursors
    extern delta
    extern draw_panel
    extern drive_left
    extern drive_right
    extern dst
    extern editor_sta_3f23
    extern entry_capacity
    extern entry_pointer
    extern error
    extern file_action
    extern has_next
    extern has_previous
    extern help
    extern input
    extern last_key
    extern make_directory
    extern mark_index
    extern mark_pointer
    extern marks_left
    extern marks_page_text
    extern marks_ptr
    extern menu
    extern message
    extern mode
    extern next_cursor
    extern open_menu
    extern original_attr
    extern page_flag__1353
    extern page_pivot_7800
    extern page_request
    extern panel
    extern panel_width
    extern path_length
    extern pathptr
    extern pcount
    extern pcur
    extern previous_cursor
    extern previous_top
    extern ptop
    extern render
    extern render_act_cbe7
    extern render_com_7e25
    extern render_pan_c869
    extern render_prepare
    extern request
    extern restore_edited
    extern saved_cursor
    extern screen_base
    extern selected
    extern selected_path
    extern set_workin_d418
    extern source_path
    extern src
    extern standalone_cbac
    extern store_cursor
    extern switch_panel
    extern text_stride
    extern tops
    extern ui_bottom
    extern ui_command
    extern ui_end
    extern ui_info
    extern ui_keys
    extern ui_rows
    extern update_cursor
    extern v_bank_val_1
    extern v_cursors_1
    extern v_marks_r_97b9
    extern v_screen_b_1
    extern v_tops_1
    extern viewer

    section
bss_start
owner ds 2
image_tail ds 2
image_prefix ds 1
image_length ds 1
    ends
; Pyldin Commander panels. MC6800 ISA, real UniDOS filesystem and loader.
start
    ldx #bss_start
nc_zero
    clr 0,x
    inx
    cpx #bss_end
    bne nc_zero
    int $3b
    cmpa #2
    beq nc_argument
    jmp bad_parent
nc_argument
    ldaa #1
    ldx #input
    int $3c
    ldx #input
    ldab #4
; A branch to *+5 skips the three-byte JMP without spending a UniAS symbol.
nc_hex
    ldaa 0,x
    inx
    suba #'0'
    cmpa #9
    bls nc_digit
    suba #7
    cmpa #15
    bls *+5
    jmp bad_parent
nc_digit
    pshb
    ldab #4
nc_shift
    asl owner+1
    rol owner
    decb
    bne nc_shift
    oraa owner+1
    staa owner+1
    pulb
    decb
    bne nc_hex
    tst 0,x
    beq *+5
    jmp bad_parent
    ldaa owner
    bne *+5
    jmp bad_parent
    cmpa #$bd
    bcs *+5
    jmp bad_parent
    ldx owner
    ldx 0,x
    cpx #$4e43
    beq *+5
    jmp bad_parent
    ldx owner
    ldaa S_ACTIVE,x
    anda #1
    staa active
    ldaa S_CURSOR,x
    staa cursors
    ldaa S_CURSOR+1,x
    staa v_cursors_1
    ldaa S_TOP,x
    staa tops
    ldaa S_TOP+1,x
    staa v_tops_1
    int $13
    staa mode
    stab original_attr
    stx screen_base
    ldaa #BASE_UI_ROWS
    staa ui_rows
    ldaa #BASE_UI_END
    staa ui_end
    ldaa #BASE_UI_INFO
    staa ui_info
    ldaa #BASE_UI_BOTTOM
    staa ui_bottom
    ldaa #BASE_UI_COMMAND
    staa ui_command
    ldaa #BASE_UI_KEYS
    staa ui_keys
    ldaa mode
    anda #3
    beq nc_layout_ready
    dec ui_rows
    dec ui_end
    dec ui_info
    dec ui_bottom
    dec ui_command
    dec ui_keys
nc_layout_ready
    ldaa $ed1d
    staa saved_cursor
    anda #$1f
    staa $ed1d
    int $6d
    staa columns
    lsra
    staa panel_width
    ldaa mode
    cmpa #2
    bne nc_keep_palette
    ldaa #6
    int $22
    clra
    int $22
nc_keep_palette
    ; Use the hardware pitch and visible start, including the 601 margins.
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
    bne nc_crtc_done
    ldaa #12
    staa $e600
    ldaa $e601
    staa screen_base
    ldaa #13
    staa $e600
    ldaa $e601
    staa v_screen_b_1
nc_crtc_done
    pula
    staa $e600
    pula
    tap
    ; PCB exit restores both handlers. Never abandon live cache/file state
    ; through the shell's asynchronous BREAK or interactive disk-error abort.
    ldx #ignore_break
    clrb
    ldaa #4
    int $2f
    ldx #fail_io
    clrb
    ldaa #7
    int $2f
    jsr mouse_init
    ldaa ui_keys
    inca
    asla
    asla
    asla
    staa mouse_height
    ldaa #$80
    staa mouse_show
    jsr cache_open
    clra
    jsr choose_panel
    ldaa #1
    jsr choose_panel
    jsr restore_edited
    jmp redraw
bad_parent
    ldx #standalone_cbac
    int $23
    int $38
redraw
    jsr render
wait_key
    ; Stable test/debug boundary: no open handles or transient stack frames.
    ldaa #0
    jsr mouse_wait
    staa last_key
    cmpa #$fe
    bne mouse_not_event
    ldaa mouse_action
    cmpa #2
    bne mouse_select_file
    jmp open_menu
mouse_select_file
    jsr mouse_activate
    ldaa mouse_action
    cmpa #3
    bne *+5
    jmp enter
    jmp redraw
mouse_not_event
    cmpa #15
    bne key_not_shell
    jmp shell_request
key_not_shell
    ; Native Ctrl+O is ASCII 0F too; Tab is ED in the native keymap.
    cmpa #$ed
    bne key_not_tab2
    jsr switch_panel
    jmp wait_key
key_not_tab2
    cmpa #$e1
    bne key_not_drive_left
    jmp drive_left
key_not_drive_left
    cmpa #$e2
    bne key_not_drive_right
    jmp drive_right
key_not_drive_right
    cmpa #$c9
    bne key_not_f1
    jmp help
key_not_f1
    cmpa #$ca
    bne key_not_f2
    jmp menu
key_not_f2
    cmpa #$cb
    bne key_not_f3
    jmp viewer
key_not_f3
    cmpa #$cc
    bne key_not_f4
    jmp edit_file
key_not_f4
    cmpa #$cd
    bne key_not_f5
    ldaa #1
    jmp file_action
key_not_f5
    cmpa #$ce
    bne key_not_f6
    ldaa #2
    jmp file_action
key_not_f6
    cmpa #$cf
    bne key_not_f7
    jmp make_directory
key_not_f7
    cmpa #$d0
    bne key_not_f8
    ldaa #3
    jmp file_action
key_not_f8
    cmpa #$d1
    bne key_not_f9
    jmp open_menu
key_not_f9
    cmpa #$d2
    bne key_not_f10
    clra
    jmp leave
key_not_f10
    cmpa #$c0
    bne key_not_enter
    jmp enter
key_not_enter
    cmpa #$7f
    bne key_not_bs
    tst command_length
    beq key_parent_directory
    jmp delete_command_char
key_parent_directory
    jmp parent_directory
key_not_bs
    cmpa #$c4
    bne key_not_up
    ldaa #$ff
    jmp move_cursor
key_not_up
    cmpa #$c3
    bne key_not_down
    ldaa #1
    jmp move_cursor
key_not_down
    cmpa #$c5
    bne key_not_home
    ldab active
    ldx #has_previous
    jsr add_b
    ldaa 0,x
    jmp set_cursor
key_not_home
    cmpa #$c6
    bne key_not_end
    ldaa active
    jsr choose_panel
    ldaa pcount
    deca
    jmp set_cursor
key_not_end
    cmpa #$c8
    bne key_not_pgup
    clra
    suba ui_rows
    jmp move_cursor
key_not_pgup
    cmpa #$c7
    bne key_not_pgdn
    ldaa ui_rows
    jmp move_cursor
key_not_pgdn
    cmpa #$fa
    bne key_not_ins
    jmp mark_entry
key_not_ins
    cmpa #18
    bne key_not_refresh
    jmp refresh
key_not_refresh
    cmpa #3
    beq clear_command
    cmpa #27
    bne key_not_escape
clear_command
    clr command_length
    clr command_line
    jmp command_redraw
key_not_escape
    cmpa #8
    bne key_not_backspace
delete_command_char
    ldaa command_length
    bne *+5
    jmp wait_key_jump
    deca
    staa command_length
    jsr command_end
    clr 0,x
    jmp command_redraw
key_not_backspace
    cmpa #32
    bcc *+5
    jmp wait_key_jump
    cmpa #127
    bcc wait_key_jump
    ldab command_length
    cmpb #79
    bcc wait_key_jump
    psha
    jsr command_end
    pula
    staa 0,x
    clr 1,x
    inc command_length
    jmp command_redraw
command_redraw
    jsr render_com_7e25
    jmp wait_key
wait_key_jump
    jmp wait_key
command_end
    ldx #command_line
    ldab command_length
    jmp add_b
move_cursor
    staa delta
    ldaa active
    jsr choose_panel
    ldaa pcur
    adda delta
    tst delta
    bpl move_nonnegative
    cmpa pcur
    bhi move_previous_window
    tsta
    beq *+5
    jmp set_cursor
move_previous_window
    ldab panel
    ldx #has_previous
    jsr add_b
    tst 0,x
    beq move_first
    ldaa #2
    jmp change_catalog_page
move_first
    ldaa pcur
    adda delta
    cmpa pcur
    bcc *+5
    jmp set_cursor
    clra
    jmp set_cursor
move_nonnegative
    cmpa pcount
    bcc *+5
    jmp set_cursor
    ldab panel
    ldx #has_next
    jsr add_b
    tst 0,x
    beq move_last
    ldaa #1
    jmp change_catalog_page
move_last
    ldaa pcount
    deca
    jmp set_cursor
change_catalog_page
    staa page_request
    ldaa #1
    staa mark_index
page_check_marks
    ldaa mark_index
    cmpa pcount
    bcc page_no_marks
    jsr entry_pointer
    tst 12,x
    beq page_mark_next
    ldx #marks_page_text
    jsr message
    jmp redraw
page_mark_next
    inc mark_index
    bra page_check_marks
page_no_marks
    ; Refill with an overlapping viewport, rather than disjoint pages.
    ; Save the target offset before directory enumeration replaces records.
    ldaa ptop
    ldab page_request
    cmpb #2
    beq page_previous_pivot
    psha
    ldaa pcur
    adda delta
    suba ptop
    staa next_cursor
    pula
    bra page_boundary
page_previous_pivot
    adda ui_rows
    deca
    cmpa pcount
    bcs page_previous_inside
    ldaa pcount
    deca
page_previous_inside
    psha
    deca
    suba pcur
    suba delta
    staa next_cursor
    pula
page_boundary
    jsr entry_pointer
    stx src
    jsr page_pivot_7800
    stx dst
    ldab #ENTRY_SIZE
    jsr copy_n
    jsr page_flag__1353
    ldaa page_request
    staa 0,x
    ldaa panel
    jsr mark_pointer
    ldx marks_ptr
    ldab entry_capacity
page_clear_marks
    clr 0,x
    inx
    decb
    bne page_clear_marks
    ldab panel
    ldx #bank_valid
    jsr add_b
    clr 0,x
    clr cache_valid
    ldaa active
    jsr choose_panel
    ldaa #1
    staa ptop
    ldaa next_cursor
    ldab page_request
    cmpb #2
    bne page_new_cursor
    ldaa pcount
    deca
    suba next_cursor
    bcc page_previous_target
    clra
page_previous_target
    staa ptop
page_new_cursor
    staa pcur
    jsr store_cursor
    ; Only the active viewport changed; preserve the other panel and bars.
    ldaa active
    staa draw_panel
    jsr render_prepare
    jsr render_pan_c869
    jsr render_act_cbe7
    jmp wait_key

set_cursor
    staa next_cursor
    ldaa pcur
    staa previous_cursor
    ldaa ptop
    staa previous_top
    ldaa next_cursor
    staa pcur
    jsr store_cursor
    jsr update_cursor
    jmp wait_key
mark_entry
    ldaa active
    jsr choose_panel
    jsr selected
    bcc *+5
    jmp wait_key_jump
    ldaa 0,x
    cmpa #'.'
    bne *+5
    jmp wait_key_jump
    ldaa 12,x
    eora #1
    staa 12,x
    ldaa #1
    jmp move_cursor
refresh
    ldx #marks_left
refresh_marks
    clr 0,x
    inx
    cpx #v_marks_r_97b9
    bne refresh_marks
    clr cache_valid
    clr bank_valid
    clr v_bank_val_1
    clra
    jsr choose_panel
    ldaa #1
    jsr choose_panel
    jmp redraw
edit_file
    ldaa active
    jsr choose_panel
    jsr selected
    bcc *+5
    jmp redraw
    ldaa 11,x
    bita #16
    beq *+5
    jmp redraw
    jsr image_type
    tsta
    beq edit_text
    ldaa #6
    bra image_request
edit_text
    ldaa #4
    staa request
    bra file_directory_ready
image_request
    staa request
    jsr set_workin_d418
    tsta
    beq file_directory_ready
    jsr error
    jmp redraw
file_directory_ready
    jsr selected
    stx src
    jsr editor_sta_3f23
    stx dst
    ldab #11
    jsr copy_n
    jsr selected_path
    ldx owner
    ldab #S_COMMAND
    jsr add_b
    stx dst
    ldx #source_path
    stx src
    jsr copy_z
    ldaa request
    cmpa #4
    beq image_leave
    jmp image_command
image_leave
    jmp leave
; All pathname/command preparation belongs to the unloadable panels.
; Keep the full document path in S_COMMAND for sorted selection restore.
image_command
    ldx #source_path
    stx image_tail
image_basename
    ldaa 0,x
    beq image_count_begin
    inx
    cmpa #'\'
    beq image_component
    cmpa #':'
    bne image_basename
image_component
    stx image_tail
    bra image_basename
image_count_begin
    ldx image_tail
    clrb
image_count
    tst 0,x
    beq image_counted
    inx
    incb
    bra image_count
image_counted
    stab image_length
    ; The supervisor passes an absolute NCMAIN pathname as argv[0].
    clra
    ldx #input
    int $3c
    ldx #input
    stx dst
    clr image_prefix
    clrb
image_program_path
    ldaa 0,x
    beq image_bound
    inx
    incb
    cmpa #'\'
    beq image_program_tail
    cmpa #':'
    bne image_program_path
image_program_tail
    stx dst
    stab image_prefix
    bra image_program_path
image_bound
    ldab image_prefix
    addb image_length
    addb #10
    ldaa request
    cmpa #5
    bne image_bound_check
    addb #3
image_bound_check
    cmpb #80
    bls image_build
    jsr editor_sta_3f23
    clr 0,x
    ldaa #19
    jsr error
    jmp redraw
image_build
    ldx #paint_name
    stx src
    jsr copy_z
    ldaa request
    cmpa #5
    bne image_filename
    ldx #view_option
    stx src
    jsr copy_z
image_filename
    ldx image_tail
    stx src
    jsr copy_z
    ldx owner
    ldx S_AUX,x
    stx dst
    ldx #input
    stx src
    jsr copy_z
    ldaa #5
    jmp leave
paint_name db 'PAINT.PGM ',0
view_option db '/V ',0
; X=8.3 directory entry, unchanged. Recognize supported image extensions.
image_type
    ldaa 8,x
    anda #$df
    cmpa #'P'
    beq image_pcx
    cmpa #'I'
    beq image_iff
    cmpa #'L'
    bne image_other
    ldaa 9,x
    anda #$df
    cmpa #'B'
    bne image_other
    ldaa 10,x
    anda #$df
    cmpa #'M'
    bra image_test
image_iff
    ldaa 9,x
    anda #$df
    cmpa #'F'
    bne image_other
    ldaa 10,x
    anda #$df
    cmpa #'F'
    bra image_test
image_pcx
    ldaa 9,x
    anda #$df
    cmpa #'C'
    bne image_other
    ldaa 10,x
    anda #$df
    cmpa #'X'
image_test
    bne image_other
    ldaa #1
    rts
image_other
    clra
    rts
shell_request
    ldaa active
    jsr choose_panel
    jsr set_workin_d418
    tsta
    beq shell_ready
    jsr error
    jmp redraw
shell_ready
    ldaa #2
    jmp leave
enter
    tst command_length
    beq enter_file
    ldaa active
    jsr choose_panel
    jsr set_workin_d418
    tsta
    beq command_ready
    jsr error
    jmp redraw
command_ready
    ldx owner
    ldab #S_COMMAND
    jsr add_b
    stx dst
    ldx #command_line
    stx src
    jsr copy_z
    ldaa #1
    jmp leave
enter_file
    ldaa active
    jsr choose_panel
    jsr selected
    bcs enter_empty
    ldaa 11,x
    bita #16
    beq launch_file
    ldaa 0,x
    cmpa #'.'
    beq parent_directory
    jsr selected_path
    ldx #source_path
    jsr path_to_panel
    jmp refresh
enter_empty
    jmp redraw
launch_file
    jsr image_type
    tsta
    beq launch_program
    ldaa #5
    jmp image_request
launch_program
    jsr set_workin_d418
    tsta
    beq launch_directory_ready
    jsr error
    jmp redraw
launch_directory_ready
    jsr selected_path
    ldx owner
    ldab #S_COMMAND
    jsr add_b
    stx dst
    ldx #source_path
    stx src
    jsr copy_z
    ldaa #1
    jmp leave
parent_directory
    ldaa active
    jsr choose_panel
    ldx pathptr
    jsr path_length
    cmpb #3
    bls parent_done
    dex
    clr 0,x
parent_back
    dex
    ldaa 0,x
    cmpa #'\'
    bne parent_back
    clr 1,x
parent_done
    jsr page_flag__1353
    clr 0,x
    clr pcur
    ldaa active
    jsr store_cursor
    jmp refresh
path_to_panel
    stx src
    jsr path_length
    bcs panel_path_invalid
    cmpb #62
    bhi panel_path_invalid
    jsr page_flag__1353
    clr 0,x
    ldx src
    stx src
    ldx pathptr
    stx dst
    jsr copy_z
    ldx dst
    ldaa #'\'
    staa 0,x
    clr 1,x
    clr pcur
    ldaa active
    jsr store_cursor
    rts
panel_path_invalid
    ldaa #19
    jsr error
    rts
leave
    staa request
    jsr mouse_close
    ldx owner
    ldaa active
    staa S_ACTIVE,x
    ldaa cursors
    staa S_CURSOR,x
    ldaa v_cursors_1
    staa S_CURSOR+1,x
    ldaa tops
    staa S_TOP,x
    ldaa v_tops_1
    staa S_TOP+1,x
    ldaa request
    staa S_REQUEST,x
    ldaa mode
    cmpa #2
    bne leave_native_colour
    ldaa #6
    int $22
    ldaa original_attr
    int $22
leave_native_colour
    ldaa saved_cursor
    staa $ed1d
    ldab original_attr
    int $16
    ldaa #12
    int $22
    jsr cache_close
return_to_parent
    int $38
ignore_break
    rts
fail_io
    ldaa #3
    staa $06
    rts
    end start
