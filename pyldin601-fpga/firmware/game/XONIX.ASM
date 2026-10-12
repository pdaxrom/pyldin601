; HD6303 Xonix: native HAM8 image, clipped tile blits, flood fill, AY.
; Map 40x25: 0 water, 1 land, 2 live cut, 4 enemy-reachable water.
    include GAMEBIOS.INC
hs_id equ 2
start
    ; UniDOS reserves PGM BSS without clearing reused conventional memory.
    ldx #bss_start
xo_zero_bss
    clr 0,x
    inx
    cpx #bss_end
    bne xo_zero_bss
    ldaa $e6a0
    bita #2
    bne xo_cpu
    ldx #xo_need_cpu
    jmp xo_message_exit
xo_cpu
    ldaa $e65f
    cmpa #6
    bcc xo_layer_present
    ldx #xo_need_layer
    jmp xo_message_exit
xo_layer_present
    jsr hs_init
    jsr xc_load
    tsta
    beq xo_prepare
    ldx #xo_bad_config
    jmp xo_message_exit
xo_prepare
    ldx #xo_music_name
    jsr hs_asset_path
    jsr mus_load
    ; Load-time LH5 storage is reused by GAMEBIOS after OPEN.
    ldab #GB_VIDEO+GB_AUDIO
    jsr sdk_open
    tsta
    beq xo_opened
    ldx #xo_need_cpu
    jmp xo_message_exit
xo_opened
    ; Build atlases and the HAM component palette once, before any music.
    ; Score-screen colours 240..245 lie outside the HAM table (0..191).
    ; Keep those component entries across menus/restarts, avoiding a long SWI.
    ldaa #GB_MODE
    ldab #1
    jsr xo_api
    ldaa #GB_TARGET
    ldab #4
    jsr xo_api
    clr xo_rect
    clr xo_rect+1
    clr xo_rect+2
    clr xo_rect+3
    ldd #320
    std xo_rect+4
    ldaa #200
    staa xo_rect+6
    clr xo_rect+7
    jsr xo_rectangle
    ldaa #GB_TARGET
    ldab #2
    jsr xo_api
    jsr xo_rectangle
    ldd #8
    std xo_rect+4
    ldaa #8
    staa xo_rect+6
    ldaa #21
    staa xo_rect+7
    jsr xo_rectangle
    ldd #8
    std xo_rect
    ldaa #63
    staa xo_rect+7
    jsr xo_rectangle
    ldd #16
    std xo_rect
    ldaa #48
    staa xo_rect+7
    jsr xo_rectangle
    ldd #24
    std xo_rect
    ldaa #15
    staa xo_rect+7
    jsr xo_rectangle
    ldaa #GB_ATTR
    ldx #xo_attr
    jsr xo_api
    ldaa #GB_CURSOR
    ldx #xo_hud_atlas
    jsr xo_api
    ldaa #GB_PUTS
    ldx #xo_hud_text
    jsr xo_api
    ldaa #GB_CURSOR
    ldx #xo_digit_atlas
    jsr xo_api
    ldaa #GB_PUTS
    ldx #xo_digits
    jsr xo_api
    ; Cache the empty board too: a restart need not draw 126 border cells.
    ldaa #3
    staa xo_lives
    ldaa #1
    staa xo_level
    ldaa #8
    staa xo_picture_page
    jsr xo_init_board
    ldaa #4
    staa xo_copy+3
    jsr xo_copy_job
    inc xk_template
    ldaa #GB_MODE
    ldab #7
    jsr xo_api
    jsr xl_panel
xo_preload_next
    jsr xk_name
    jsr xl_caption
    jsr xk_name
    jsr hs_asset_path
    pshx
    ldx #xk_pages
    ldab xk_index
    abx
    ldaa 0,x
    pulx
    jsr hi_load
    tsta
    beq xk_ready
    jsr sdk_close
    jsr mus_release
    tst xl_cancel
    beq *+5
    jmp xo_exit_load
    ldx #xo_bad_picture
    jmp xo_message_exit
xo_exit_load
    ldx #xo_done
    jmp xo_message_exit
xk_ready
    inc xk_index
    ldaa xk_index
    cmpa xc_n
    bcs xo_preload_next
    jsr hs_show
    tstb
    beq xo_new_game
    jmp xo_exit_native
xo_new_game
    clr hs_ui_active
    clr xo_score
    clr xo_score+1
    ldaa #3
    staa xo_lives
    ldaa #1
    staa xo_level
    clr xo_picture_index
    jsr xo_choose_picture
    jsr sdk_input_reset
    tsta
    beq xo_captured
    jmp xo_failed
xo_captured
    jsr xo_init_board
    ; Switch at VBL only after both game buffers are ready. Music continues
    ; from the table; restarting it here would unnecessarily mute the AY.
    ldaa #GB_FLIP
    clrb
    jsr xo_api
    jsr xo_layer_mode
xo_loop
    jsr sdk_input
    tsta
    beq xo_input_ok
    jmp xo_failed
xo_input_ok
    stab xo_held
    ldaa sdk_pressed
    bita #GB_KEY_ESC
    beq xo_pause_key
    jmp xo_end_game
xo_pause_key
    bita #GB_KEY_SPACE
    beq xo_keys_done
    ldaa xo_paused
    eora #1
    staa xo_paused
    tab
    eorb #1
    ldaa #GB_PLAY
    jsr xo_api
xo_keys_done
    tst xo_paused
    bne xo_loop
    jsr mus_fill
    inc xo_phase
    ldaa xo_phase
    cmpa #3
    bcs xo_draw_frame
    clr xo_phase
    jsr xo_move_player
    tst xo_over
    bne xo_end_game
    jsr xo_move_enemies
    tst xo_over
    bne xo_end_game
xo_draw_frame
    jsr xo_draw
    jmp xo_loop
xo_end_game
    ldd xo_score
    std hs_score
    jsr hs_record
    jsr hs_show
    tstb
    bne xo_exit_native
    jmp xo_new_game
xo_exit_native
    jsr sdk_close
    jsr mus_release
    ldx #xo_done
xo_message_exit
    jsr hs_unhook
    int $23
    clra
    int $38
xk_name
    ldaa #64
    ldab xk_index
    mul
    addd #xc_names
    xgdx
    rts
xo_choose_picture
    ldx #xk_pages
    ldab xo_picture_index
    abx
    ldaa 0,x
    staa xo_picture_page
    rts
xo_layer_mode
    ldaa xo_picture_page
    staa $e654
    ldaa #15
    staa $e650
    rts
; Cold loading precedes music: even a long native DOS OPEN cannot starve
; the 16-frame queue. Once the table appears, play/restarts never read disk.
; Row/refill hooks handle ESC/progress and feed any active foreground music.
xl_panel
    jsr hs_panel
    ldaa #3
    staa hs_ui_active
    ldx #xl_title
    ldab #7
    jsr hs_center
    ldx #hs_attr_white
    jsr hs_attribute
    ldaa #GB_FLIP
    ldab #5
    jmp xo_api
xl_caption
    stx xl_source
    ; Clear the entire bounded filename line before a shorter next name.
    ldd #32
    std xo_rect
    ldd #80
    std xo_rect+2
    ldd #256
    std xo_rect+4
    ldaa #8
    staa xo_rect+6
    ldaa #241
    staa xo_rect+7
    jsr xo_rectangle
    ldx #xl_name
    stx xl_dest
    ldab #32
xl_name_byte
    pshb
    ldx xl_source
    ldaa 0,x
    inx
    stx xl_source
    ldx xl_dest
    staa 0,x
    inx
    stx xl_dest
    pulb
    tsta
    beq xl_name_done
    decb
    bne xl_name_byte
    clr 0,x
xl_name_done
    ldx #xl_name
    ldab #10
    jsr hs_center
    clra
    ldab xk_index
    incb
    jsr hs_decimal
    ldd hs_number+3
    std xl_label+6
    clra
    ldab xc_n
    jsr hs_decimal
    ldd hs_number+3
    std xl_label+12
    ldx #xl_label
    ldab #15
    jsr hs_center
    ldaa #200
    staa hi_rows_left
    ldd #0
    jsr xl_bar
    rts
xl_audio
    psha
    pshb
    pshx
    ldaa hs_ui_active
    cmpa #3
    bne xl_music
    tst hi_opened
    beq xl_music
    int $10
    cmpa #$ff
    beq xl_music
    int $11
    cmpa #27
    bne xl_music
    inc xl_cancel
    jmp hi_io_error
xl_music
    ldaa $e690
    bita #1
    beq xl_audio_done
    jsr mus_fill
xl_audio_done
    pulx
    pulb
    pula
    rts
xl_progress
    psha
    pshb
    pshx
    jsr mus_fill
    ldaa hi_rows_left
    deca
    anda #7
    bne xl_row_done
    ldaa #201
    suba hi_rows_left
    tab
    clra
    jsr xl_bar
xl_row_done
    ; Progress drawing changes E655; restore the decoder's page before the
    ; next row. The current source stream and game buffers remain untouched.
    ldaa hi_page
    staa $e655
    pulx
    pulb
    pula
    rts
xl_bar
    std xl_width
    ldaa #GB_TARGET
    ldab #5
    jsr xo_api
    ldd #60
    std xo_rect
    ldd #128
    std xo_rect+2
    ldd #200
    std xo_rect+4
    ldaa #8
    staa xo_rect+6
    ldaa #241
    staa xo_rect+7
    jsr xo_rectangle
    ldd xl_width
    beq xl_bar_done
    std xo_rect+4
    ldaa #242
    staa xo_rect+7
    jsr xo_rectangle
xl_bar_done
    rts
xo_init_board
    clr xo_paused
    clr xo_over
    clr xo_cut
    clr xo_phase
    clr xo_hidden
    clr xo_claimed
    clr xo_claimed+1
    ldx #xo_history
    ldab #12
xo_history_clear
    clr 0,x
    inx
    decb
    bne xo_history_clear
    ldx #xo_map
    ldd #1000
    std xo_count
xo_map_clear
    clr 0,x
    inx
    ldd xo_count
    subd #1
    std xo_count
    bne xo_map_clear
    clr xo_copy+1
    ldaa #2
    staa xo_copy
    ldaa #4
    staa xo_copy+2
    ldaa #3
    staa xo_copy+3
    clr xo_copy+4
    clr xo_copy+5
    clr xo_copy+6
    clr xo_copy+7
    ldd #320
    std xo_copy+8
    ldaa #200
    staa xo_copy+10
    jsr xo_copy_job
    clr xo_row
xo_border_row
    clr xo_column
xo_border_column
    ldaa xo_row
    beq xo_border_set
    cmpa #24
    beq xo_border_set
    ldaa xo_column
    beq xo_border_set
    cmpa #39
    bne xo_border_next
xo_border_set
    jsr xo_cell_index
    addd #xo_map
    xgdx
    ldaa #1
    staa 0,x
    tst xk_template
    bne xo_border_next
    jsr xo_draw_cell
xo_border_next
    inc xo_column
    ldaa xo_column
    cmpa #40
    bne xo_border_column
    inc xo_row
    ldaa xo_row
    cmpa #25
    bne xo_border_row
    ldaa #20
    staa xo_player_x
    clr xo_player_y
    ldd #$0c0c
    std xo_enemy
    ldd #$1b11
    std xo_enemy+2
    ldd #$0101
    std xo_direction
    ldd #$ff01
    std xo_direction+2
    jsr xo_hud
    ; Static background -> both displays once per level.
    ldaa #3
    staa xo_copy+2
    clr xo_copy+4
    clr xo_copy+5
    clr xo_copy+6
    clr xo_copy+7
    ldd #320
    std xo_copy+8
    ldaa #200
    staa xo_copy+10
    clr xo_copy+3
    jsr xo_copy_job
    inc xo_copy+3
    jsr xo_copy_job
    rts
; xo_row/column -> D=index and 8x8 screen byte offset in xo_position.
xo_cell_index
    ldaa #40
    ldab xo_row
    mul
    addb xo_column
    adca #0
    std xo_index
    asld
    asld
    asld
    std xo_position
    ; index*8 includes row*320, but y is row*8 -> add row*2240.
    ldaa #35
    ldab xo_row
    mul
    asld
    asld
    asld
    asld
    asld
    asld
    addd xo_position
    std xo_position
    ldd xo_index
    rts
xo_cell_at
    ldaa #40
    ldab xo_row
    mul
    addb xo_column
    adca #0
    addd #xo_map
    xgdx
    rts
xo_draw_cell
    jsr xo_cell_index
    ldd xo_position
    std xo_copy+6
    ldd #8
    std xo_copy+8
    stab xo_copy+10
    ldaa #3
    staa xo_copy+3
    jsr xo_cell_at
    ldaa 0,x
    cmpa #1
    beq xo_land_cell
    cmpa #2
    beq xo_trail_cell
    ; The blank atlas tile stays black; page 4 holds the empty-board template.
    ldaa #2
    staa xo_copy+2
    ldd #32
    std xo_copy+4
    jmp xo_copy_job
xo_trail_cell
    ldaa #2
    staa xo_copy+2
    ldd #24
    std xo_copy+4
    jmp xo_copy_job
xo_land_cell
    ldaa xo_row
    beq xo_edge_cell
    cmpa #24
    beq xo_edge_cell
    ldaa xo_column
    beq xo_edge_cell
    cmpa #39
    beq xo_edge_cell
    ldaa xo_picture_page
    staa xo_copy+2
    ldd xo_position
    std xo_copy+4
    jmp xo_copy_job
xo_edge_cell
    ldaa #2
    staa xo_copy+2
    clr xo_copy+4
    clr xo_copy+5
    jmp xo_copy_job
; Refresh current cell in both display buffers, preserving all descriptor data.
xo_refresh_cell
    jsr xo_draw_cell
    ldaa #3
    staa xo_copy+2
    ldd xo_position
    std xo_copy+4
    clr xo_copy+3
    jsr xo_copy_job
    inc xo_copy+3
    jmp xo_copy_job
xo_move_player
    ldaa xo_player_x
    staa xo_column
    ldaa xo_player_y
    staa xo_row
    ldaa xo_held
    anda #GB_KEY_LEFT+GB_KEY_RIGHT
    cmpa #GB_KEY_LEFT
    beq xo_left
    cmpa #GB_KEY_RIGHT
    beq xo_right
    ldaa xo_held
    anda #GB_KEY_UP+GB_KEY_DOWN
    cmpa #GB_KEY_UP
    beq xo_up
    cmpa #GB_KEY_DOWN
    beq xo_down
    rts
xo_left
    tst xo_column
    beq xo_player_done
    dec xo_column
    bra xo_player_next
xo_right
    ldaa xo_column
    cmpa #39
    beq xo_player_done
    inc xo_column
    bra xo_player_next
xo_up
    tst xo_row
    beq xo_player_done
    dec xo_row
    bra xo_player_next
xo_down
    ldaa xo_row
    cmpa #24
    beq xo_player_done
    inc xo_row
xo_player_next
    jsr xo_cell_at
    ldaa 0,x
    cmpa #2
    beq xo_player_died
    cmpa #1
    beq xo_reached_land
    ldaa #2
    staa 0,x
    ldaa #1
    staa xo_cut
    jsr xo_refresh_cell
    bra xo_player_store
xo_reached_land
    tst xo_cut
    beq xo_player_store
    jsr xo_capture
xo_player_store
    ldaa xo_column
    staa xo_player_x
    ldaa xo_row
    staa xo_player_y
xo_player_done
    rts
xo_player_died
    jmp xo_lose_life
xo_move_enemies
    clr xo_actor
xo_enemy_step
    ldab xo_actor
    aslb
    ldx #xo_enemy
    abx
    ldaa 0,x
    staa xo_column
    ldaa 1,x
    staa xo_row
    stx xo_actor_pointer
    ldx #xo_direction
    abx
    stx xo_direction_pointer
    ldaa xo_column
    adda 0,x
    staa xo_column
    jsr xo_cell_at
    ldaa 0,x
    cmpa #1
    bne xo_enemy_x_free
    ldx xo_direction_pointer
    neg 0,x
    ldx xo_actor_pointer
    ldaa 0,x
    staa xo_column
xo_enemy_x_free
    ldx xo_direction_pointer
    ldaa xo_row
    adda 1,x
    staa xo_row
    jsr xo_cell_at
    ldaa 0,x
    cmpa #1
    bne xo_enemy_y_free
    ldx xo_direction_pointer
    neg 1,x
    ldx xo_actor_pointer
    ldaa 1,x
    staa xo_row
xo_enemy_y_free
    jsr xo_cell_at
    ldaa 0,x
    cmpa #2
    beq xo_enemy_hit
    ldx xo_actor_pointer
    ldaa xo_column
    staa 0,x
    ldaa xo_row
    staa 1,x
    tst xo_cut
    beq xo_enemy_next
    ldaa xo_column
    cmpa xo_player_x
    bne xo_enemy_next
    ldaa xo_row
    cmpa xo_player_y
    beq xo_enemy_hit
xo_enemy_next
    inc xo_actor
    ldaa xo_actor
    cmpa #2
    beq *+5
    jmp xo_enemy_step
    rts
xo_enemy_hit
    jmp xo_lose_life
xo_lose_life
    dec xo_lives
    bne xo_life_left
    inc xo_over
xo_life_left
    ldaa #25
    staa xo_note+1
    ldd #15
    std xo_note+2
    jsr xo_sound
    clr xo_cut
    clr xo_row
xo_erase_trail_row
    clr xo_column
xo_erase_trail_column
    jsr xo_cell_at
    ldaa 0,x
    cmpa #2
    bne xo_erase_next
    clr 0,x
    jsr xo_refresh_cell
xo_erase_next
    inc xo_column
    ldaa xo_column
    cmpa #40
    bne xo_erase_trail_column
    jsr mus_fill
    inc xo_row
    ldaa xo_row
    cmpa #25
    bne xo_erase_trail_row
    ldaa #20
    staa xo_player_x
    clr xo_player_y
    jmp xo_hud
; Multi-source flood fill. Both enemies' regions stay water. Bounded 1000-word
; queue; marking at enqueue prevents duplicates and any quadratic work.
xo_capture
    ldaa xo_column
    staa xo_finish_x
    ldaa xo_row
    staa xo_finish_y
    ldx #xo_queue
    stx xo_head
    stx xo_tail
    clr xo_actor
xo_flood_seed
    ldab xo_actor
    aslb
    ldx #xo_enemy
    abx
    ldaa 0,x
    staa xo_column
    ldaa 1,x
    staa xo_row
    jsr xo_cell_index
    jsr xo_enqueue
    inc xo_actor
    ldaa xo_actor
    cmpa #2
    bne xo_flood_seed
xo_flood_loop
    ldx xo_head
    cpx xo_tail
    beq xo_flood_done
    ldd 0,x
    std xo_flood_index
    inx
    inx
    stx xo_head
    addd #1
    jsr xo_enqueue
    ldd xo_flood_index
    subd #1
    jsr xo_enqueue
    ldd xo_flood_index
    addd #40
    jsr xo_enqueue
    ldd xo_flood_index
    subd #40
    jsr xo_enqueue
    ldaa xo_head+1
    anda #63
    bne xo_flood_loop
    jsr mus_fill
    bra xo_flood_loop
xo_enqueue
    std xo_work
    subd #1000
    bcc xo_enqueue_done
    ldd xo_work
    addd #xo_map
    xgdx
    tst 0,x
    bne xo_enqueue_done
    ldaa #4
    staa 0,x
    ldx xo_tail
    cpx #xo_queue+2000
    bcc xo_enqueue_bad
    ldd xo_work
    std 0,x
    inx
    inx
    stx xo_tail
xo_enqueue_done
    rts
xo_enqueue_bad
    jmp xo_failed
xo_flood_done
    clr xo_cut
    clr xo_row
xo_claim_row
    clr xo_column
xo_claim_column
    jsr xo_cell_at
    ldaa 0,x
    cmpa #4
    beq xo_unmark
    cmpa #1
    beq xo_claim_next
    ldaa #1
    staa 0,x
    ldd xo_claimed
    addd #1
    std xo_claimed
    ldd xo_score
    addd #10
    bcc *+5
    ldd #$ffff
    std xo_score
    jsr xo_refresh_cell
    bra xo_claim_next
xo_unmark
    clr 0,x
xo_claim_next
    inc xo_column
    ldaa xo_column
    cmpa #40
    bne xo_claim_column
    jsr mus_fill
    inc xo_row
    ldaa xo_row
    cmpa #25
    bne xo_claim_row
    jsr xo_hud
    ldaa #61
    staa xo_note+1
    ldd #5
    std xo_note+2
    jsr xo_sound
    ldd xo_claimed
    subd #656
    bcs xo_capture_done
    inc xo_level
    inc xo_picture_index
    ldaa xo_picture_index
    cmpa xc_n
    bcs xo_picture_advanced
    clr xo_picture_index
xo_picture_advanced
    jsr xo_choose_picture
    jsr xo_layer_mode
    jsr xo_init_board
    ldaa #20
    staa xo_finish_x
    clr xo_finish_y
xo_capture_done
    ldaa xo_finish_x
    staa xo_column
    ldaa xo_finish_y
    staa xo_row
    rts
xo_hud
    ldaa #2
    staa xo_copy
    clr xo_copy+1
    ldaa #2
    staa xo_copy+2
    ldaa #3
    staa xo_copy+3
    ldd #5120
    std xo_copy+4
    clr xo_copy+6
    clr xo_copy+7
    ldd #320
    std xo_copy+8
    ldaa #8
    staa xo_copy+10
    jsr xo_copy_job
    ldd xo_score
    jsr hs_decimal
    clr xo_digit
xo_hud_score
    ldab xo_digit
    ldx #hs_number
    abx
    ldaa 0,x
    suba #'0'
    staa xo_glyph
    ldaa xo_digit
    adda #12
    staa xo_hud_column
    jsr xo_hud_digit
    inc xo_digit
    ldaa xo_digit
    cmpa #5
    bne xo_hud_score
    ldaa xo_lives
    staa xo_glyph
    ldaa #23
    staa xo_hud_column
    jsr xo_hud_digit
    clra
    ldab xo_level
    jsr hs_decimal
    ldaa hs_number+3
    suba #'0'
    staa xo_glyph
    ldaa #28
    staa xo_hud_column
    jsr xo_hud_digit
    ldaa hs_number+4
    suba #'0'
    staa xo_glyph
    inc xo_hud_column
    jsr xo_hud_digit
    ldaa #3
    staa xo_copy+2
    clr xo_copy+4
    clr xo_copy+5
    clr xo_copy+6
    clr xo_copy+7
    ldd #320
    std xo_copy+8
    ldaa #8
    staa xo_copy+10
    clr xo_copy+3
    jsr xo_copy_job
    inc xo_copy+3
    jmp xo_copy_job
xo_hud_digit
    clra
    ldab xo_glyph
    asld
    asld
    asld
    addd #7680
    std xo_copy+4
    clra
    ldab xo_hud_column
    asld
    asld
    asld
    std xo_copy+6
    ldd #8
    std xo_copy+8
    stab xo_copy+10
    ldaa #2
    staa xo_copy+2
    ldaa #3
    staa xo_copy+3
    jmp xo_copy_job
xo_draw
    ldaa xo_hidden
    eora #1
    staa xo_hidden
    staa xo_copy+3
    clr xo_actor
xo_draw_actor
    ldab xo_hidden
    ldaa #6
    mul
    addb xo_actor
    addb xo_actor
    adca #0
    addd #xo_history
    std xo_history_pointer
    xgdx
    ldaa 1,x
    beq xo_actor_first
    suba #1
    staa xo_row
    ldaa 0,x
    staa xo_column
    jsr xo_cell_index
    ldd xo_position
    std xo_copy+4
    std xo_copy+6
    ldaa #3
    staa xo_copy+2
    jsr xo_actor_copy
xo_actor_first
    tst xo_actor
    bne xo_draw_enemy
    ldaa xo_player_x
    staa xo_column
    ldaa xo_player_y
    staa xo_row
    ldd #8
    std xo_copy+4
    bra xo_actor_new
xo_draw_enemy
    ldaa xo_actor
    deca
    asla
    tab
    ldx #xo_enemy
    abx
    ldaa 0,x
    staa xo_column
    ldaa 1,x
    staa xo_row
    ldd #16
    std xo_copy+4
xo_actor_new
    jsr xo_cell_index
    ldd xo_position
    std xo_copy+6
    ldaa #2
    staa xo_copy+2
    jsr xo_actor_copy
    ldx xo_history_pointer
    ldaa xo_column
    staa 0,x
    ldaa xo_row
    inca
    staa 1,x
    inc xo_actor
    ldaa xo_actor
    cmpa #3
    beq *+5
    jmp xo_draw_actor
    ldaa #GB_FLIP
    ldab xo_hidden
    jmp xo_api
xo_actor_copy
    ldd #8
    std xo_copy+8
    stab xo_copy+10
    jmp xo_copy_job
xo_sound
    ldaa #GB_NOTE
    ldx #xo_note
    jmp xo_api
xo_rectangle
    jsr xl_audio
    ldaa #GB_RECT
    ldx #xo_rect
    jmp xo_api
xo_copy_job
    jsr xl_audio
    ldaa #GB_COPY
    ldx #xo_copy
    jmp xo_api
xo_api
    int GB_INT
    tsta
    beq *+5
    jmp xo_failed
    rts
xo_failed
    jsr sdk_close
    jsr mus_release
    ldx #xo_error
    jmp xo_message_exit
hs_failure
    jmp xo_failed
    include GAMESDK.ASM
    include HIGHSCR.ASM
    include MUSAPI.ASM
    include GAMEMUS.ASM
    include HIMAGE.ASM
    include XCFG.ASM
hs_title db 'PYLDIN XONIX',0
hs_primary_name db 'XONSCORE.DAT',0
hs_backup_name db 'XONSCORE.BAK',0
xo_music_name db 'LEDSTRM1.YM',0
xo_picture_name db 'LENA.IFF',0
xo_config_name db 'XONIX.CFG',0
xk_pages db 8,6,7,9,10,11,12,13,14,15
xl_title db 'LOADING BACKGROUNDS',0
xl_label db 'IMAGE 00 OF 00',0
xo_done db 'XONIX: returned to UniDOS.',13,10,0
xo_need_cpu db 'XONIX needs HD6303 and GAMEBIOS ABI 1.',13,10,0
xo_need_layer db 'XONIX needs layered HAM8 FPGA (revision 6).',13,10,0
xo_bad_picture db 'XONIX: background must be readable 320x200 HAM8 ILBM.',13,10,0
xo_bad_config db 'XONIX: invalid XONIX.CFG (10 paths, max 63 characters).',13,10,0
xo_error db 'XONIX: GAMEBIOS or input operation failed.',13,10,0
xo_attr db 63,0
xo_hud_atlas db 0,2
xo_digit_atlas db 0,3
xo_digits db '0123456789',0
xo_hud_text db 'XONIX  SCORE00000 LIFE 3 LV 01',0
xo_note db 2,0,0,0,12
bss_start
xo_rect ds 8
xo_copy ds 11
xo_score ds 2
xo_level ds 1
xo_lives ds 1
xo_over ds 1
xo_cut ds 1
xo_paused ds 1
xo_phase ds 1
xo_held ds 1
xo_hidden ds 1
xo_claimed ds 2
xo_picture_index ds 1
xo_picture_page ds 1
xk_index ds 1
xk_template ds 1
xl_source ds 2
xl_dest ds 2
xl_width ds 2
xl_cancel ds 1
xl_name ds 33
xc_sp ds 2
xc_ot ds 4
xc_io ds 4
xc_h ds 1
xc_op ds 1
xc_sz ds 4
xc_left ds 2
xc_av ds 2
xc_ptr ds 2
xc_dst ds 2
xc_n ds 1
xc_len ds 1
xc_c ds 1
xc_names ds 640
xo_count ds 2
xo_row ds 1
xo_column ds 1
xo_index ds 2
xo_position ds 2
xo_player_x ds 1
xo_player_y ds 1
xo_enemy ds 4
xo_direction ds 4
xo_actor ds 1
xo_actor_pointer ds 2
xo_direction_pointer ds 2
xo_history ds 12
xo_history_pointer ds 2
xo_head ds 2
xo_tail ds 2
xo_flood_index ds 2
xo_work ds 2
xo_finish_x ds 1
xo_finish_y ds 1
xo_digit ds 1
xo_glyph ds 1
xo_hud_column ds 1
xo_map ds 1000
xo_queue ds 2000
    include HISDATA.INC
    include HIMDATA.INC
    include GAMESDTA.INC
bss_end
    end start
