; Pyldin HD6303 GAMEBIOS example: tiles, dirty buffers, AY music + effects.
    include GAMEBIOS.INC
hs_id equ 1
start
    ; UniDOS reserves PGM BSS without clearing reused conventional memory.
    ldx #bss_start
game_zero_bss
    clr 0,x
    inx
    cpx #bss_end
    bne game_zero_bss
    ldaa $e6a0
    bita #2
    bne game_cpu_ready
    ldx #need_gamebios
    jmp message_exit
game_cpu_ready
    jsr hs_init
game_prepare
    ldx #music_name
    jsr hs_asset_path
    jsr mus_load
    ; Decode music in temporary banks before opening the video context.
    ldab #GB_VIDEO+GB_AUDIO
    jsr sdk_open
    tsta
    beq started
    ldx #need_gamebios
    jmp message_exit
started
    ldaa #GB_INFO
    int GB_INT
    clr batch_available
    bitb #GB_FEATURE_BATCH
    beq game_scores
    inc batch_available
game_scores
    jsr hs_show
    tstb
    beq game_begin
    jmp exit_native
game_begin
    ldaa #1
    staa level
    ldaa #3
    staa lives
    clr score
    clr score+1
round_begin
    clr hs_ui_active
    ; Remove launch-command characters once, before exclusive raw capture.
drain_keys
    int $10
    cmpa #$ff
    beq capture_keys
    int $11
    bra drain_keys
capture_keys
    jsr sdk_input_reset
    tsta
    beq input_present
    jsr sdk_close
    ldx #need_input
    jmp message_exit
input_present
    ldaa #GB_MODE
    ldab #1
    jsr api
    clr palette_number
    ldx #colours
    stx palette_pointer
palette_loop
    ldaa palette_number
    staa pal_desc
    ldx palette_pointer
    ldd 0,x
    std pal_desc+1
    ldaa 2,x
    staa pal_desc+3
    inx
    inx
    inx
    stx palette_pointer
    ldaa #GB_PALETTE
    ldx #pal_desc
    jsr api
    inc palette_number
    ldaa palette_number
    cmpa #8
    bne palette_loop
    ldaa #GB_TARGET
    ldab #2
    jsr api
    clr rect_desc
    clr rect_desc+1
    clr rect_desc+2
    clr rect_desc+3
    ldd #320
    std rect_desc+4
    ldaa #200
    staa rect_desc+6
    clr rect_desc+7
    jsr rectangle
    ; Tile atlas, IDs 1..5. Each brick tile has a one-pixel dark seam.
    ldaa #1
    staa palette_number
atlas_loop
    clra
    ldab palette_number
    asld
    asld
    asld
    std rect_desc
    ldd #7
    std rect_desc+4
    ldaa #7
    staa rect_desc+6
    ldaa palette_number
    staa rect_desc+7
    jsr rectangle
    inc palette_number
    ldaa palette_number
    cmpa #6
    bne atlas_loop
    ; White ball at tile 63: three bands, transparent corners.
    ldd #58
    std rect_desc
    ldd #56
    std rect_desc+2
    ldd #4
    std rect_desc+4
    ldaa #2
    staa rect_desc+6
    ldaa #7
    staa rect_desc+7
    jsr rectangle
    ldd #56
    std rect_desc
    ldd #58
    std rect_desc+2
    ldd #8
    std rect_desc+4
    ldaa #4
    staa rect_desc+6
    jsr rectangle
    ldd #58
    std rect_desc
    ldd #62
    std rect_desc+2
    ldd #4
    std rect_desc+4
    ldaa #2
    staa rect_desc+6
    jsr rectangle
    ; Cache HUD digits once, outside the 64x64 tile atlas and ball sprite.
    ; Runtime score updates use COPY instead of repainting text pixel by pixel.
    ldaa #GB_ATTR
    ldx #text_attr
    jsr api
    ldaa #GB_CURSOR
    ldx #digit_cursor
    jsr api
    ldaa #GB_PUTS
    ldx #digit_text
    jsr api
    ldaa #GB_TARGET
    ldab #3
    jsr api
    ldx #world
    ldd #1000
    std work_count
world_clear
    clr 0,x
    inx
    ldd work_count
    subd #1
    std work_count
    bne world_clear
    clr remaining
    clr brick_row
brick_map_row
    clr brick_column
brick_map_column
    ldaa #8
    ldab brick_row
    mul
    addb brick_column
    adca #0
    addd #bricks
    xgdx
    ldaa level
    anda #3
    beq level_tile
    cmpa #1
    beq level_tile
    ldaa brick_column
    adda brick_row
    anda #1
    beq level_tile
    clr 0,x
    bra level_map_next
level_tile
    ldaa brick_row
    inca
    staa 0,x
    inc remaining
    ldaa #40
    ldab brick_row
    addb #5
    mul
    addd #world+4
    std work_offset
    clra
    ldab brick_column
    asld
    asld
    addd work_offset
    xgdx
    ldaa brick_row
    inca
    staa 0,x
    staa 1,x
    staa 2,x
    staa 3,x
level_map_next
    inc brick_column
    ldaa brick_column
    cmpa #8
    bne brick_map_column
    inc brick_row
    ldaa brick_row
    cmpa #5
    bne brick_map_row
    ldx #map_desc
    ldaa #$fc
    staa last_operation
    jsr sdk_map
    tsta
    beq *+5
    jmp failed
    clr round_ended
    clr bonus_active
    clr paused
    clr launched
    clr hidden
    clr valid
    clr valid+1
    ldx #bonus_history
    ldab #8
clear_bonus_history
    clr 0,x
    inx
    decb
    bne clear_bonus_history
    clr hud_initialized
    ldd #136
    std paddle
    jsr reset_ball
    jsr hud
    ldx #launch_text
    jsr centre_message
    ; Full copies occur once. Subsequent frames restore only dirty rectangles.
    ldd #0
    std blit_desc+4
    std blit_desc+6
    ldd #320
    std blit_desc+8
    ldaa #200
    staa blit_desc+10
    clr blit_desc+3
    jsr copy_background
    inc blit_desc+3
    jsr copy_background
    ldaa #GB_FLIP
    clrb
    jsr api
    jsr mus_start
frame_loop
sample_keys
    ldaa #$fe
    staa last_operation
    jsr sdk_input
    tsta
    beq *+5
    jmp failed
    stab held_keys
    ldaa sdk_pressed
    bita #GB_KEY_ESC
    beq *+5
    jmp exit_game
    bita #GB_KEY_SPACE
    bne space_key
    bra keys_done
left_key
    ldd paddle
    subd #4
    bpl paddle_store
    ldd #0
    bra paddle_store
right_key
    ldd paddle
    addd #4
    subd #273
    bcs paddle_right_valid
    ldd #272
    bra paddle_store
paddle_right_valid
    addd #273
paddle_store
    std paddle
    rts
space_key
    tst launched
    bne pause_key
    tst lives
    bne *+5
    jmp keys_done
    tst remaining
    bne *+5
    jmp keys_done
    inc launched
    jsr erase_message
    bra keys_done
pause_key
    ldaa paused
    eora #1
    staa paused
    ldab #1
    eorb paused
    ldaa #GB_PLAY
    jsr api
keys_done
    tst paused
    beq *+5
    jmp frame_idle
    ; Actual displacement (including edge clamp) supplies paddle spin.
    ldd paddle
    std paddle_delta
    ; One four-pixel step per display frame, independent of key repetition.
    ldaa held_keys
    anda #GB_KEY_LEFT+GB_KEY_RIGHT
    cmpa #GB_KEY_LEFT
    bne check_right
    jsr left_key
    bra paddle_done
check_right
    cmpa #GB_KEY_RIGHT
    bne paddle_done
    jsr right_key
paddle_done
    ldd paddle
    subd paddle_delta
    std paddle_delta
    jsr fill_music
    jsr update_bonus
    tst launched
    beq follow_paddle
    jsr move_ball
    bra frame_draw
follow_paddle
    jsr reset_ball
frame_draw
    ldaa hidden
    eora #1
    staa hidden
    tab
    ldaa #GB_TARGET
    jsr api
    ldx #valid
    ldab hidden
    abx
    tst 0,x
    beq frame_new
    ldab hidden
    aslb
    aslb
    aslb
    ldx #history
    abx
    ldd 0,x
    std rect_desc
    ldd 2,x
    std rect_desc+2
    ldd #8
    std rect_desc+4
    ldaa #8
    staa rect_desc+6
    jsr restore_rectangle
    ldab hidden
    aslb
    aslb
    aslb
    ldx #history
    abx
    ldd 4,x
    std rect_desc
    ldd #190
    std rect_desc+2
    ldd #48
    std rect_desc+4
    ldaa #5
    staa rect_desc+6
    jsr restore_rectangle
frame_new
    ldab hidden
    aslb
    aslb
    ldx #bonus_history
    abx
    ldd 2,x
    beq bonus_old_clear
    std rect_desc+2
    ldd 0,x
    std rect_desc
    ldd #8
    std rect_desc+4
    ldaa #8
    staa rect_desc+6
    jsr restore_rectangle
bonus_old_clear
    ldab hidden
    aslb
    aslb
    ldx #bonus_history
    abx
    clr 2,x
    clr 3,x
    tst bonus_active
    beq bonus_drawn
    ldd bonus_x
    std 0,x
    std rect_desc
    ldd bonus_y
    std 2,x
    std rect_desc+2
    ldd #8
    std rect_desc+4
    ldaa #8
    staa rect_desc+6
    ldaa #4
    ldab bonus_active
    cmpb #2
    bne *+4
    ldaa #2
    staa rect_desc+7
    jsr rectangle
bonus_drawn
    ldd ball_x
    std sprite_desc
    ldd ball_y
    std sprite_desc+2
    ldaa hidden
    staa sprite_desc+10
    ldx #sprite_desc
    ldaa #GB_SPRITE
    jsr api
    ldd paddle
    std rect_desc
    ldd #190
    std rect_desc+2
    ldd #48
    std rect_desc+4
    ldaa #5
    staa rect_desc+6
    ldaa #6
    staa rect_desc+7
    jsr rectangle
    ldab hidden
    aslb
    aslb
    aslb
    ldx #history
    abx
    ldd ball_x
    std 0,x
    ldd ball_y
    std 2,x
    ldd paddle
    std 4,x
    ldx #valid
    ldab hidden
    abx
    ldaa #1
    staa 0,x
    ldaa #GB_FLIP
    ldab hidden
    jsr api
    tst round_ended
    beq *+5
    jmp end_party
    tst remaining
    bne *+5
    jmp next_level
    jmp frame_loop
next_level
    inc level
    ldaa level
    cmpa #10
    bcs level_ready
    ldaa #1
    staa level
level_ready
    jmp round_begin
end_party
    ldd score
    std hs_score
    jsr hs_record
    jmp game_scores
frame_idle
    ; Keep keyboard responsive while audio is paused.
    jmp frame_loop
reset_ball
    ldd paddle
    addd #20
    std ball_x
    ldd #182
    std ball_y
    clr ball_fraction_x
    clr ball_fraction_y
    ldd #384
    std velocity_x
    ldd #-665
    std velocity_y
    rts
move_ball
    ldd ball_x
    std previous_x
    ldd ball_y
    std previous_y
    ; Signed Q8.8 velocity, with a separate fraction for each 9-bit position.
    ldd velocity_x
    addb ball_fraction_x
    stab ball_fraction_x
    adca #0
    tab
    clra
    tstb
    bpl *+3
    deca
    addd ball_x
    std ball_x
    subd #2
    blt ball_left
    ldd ball_x
    subd #310
    bgt ball_right
    bra ball_vertical
ball_left
    ldd #2
    std ball_x
    bra ball_reverse_x
ball_right
    ldd #310
    std ball_x
ball_reverse_x
    clr ball_fraction_x
    ldd #0
    subd velocity_x
    std velocity_x
ball_vertical
    ldd velocity_y
    addb ball_fraction_y
    stab ball_fraction_y
    adca #0
    tab
    clra
    tstb
    bpl *+3
    deca
    addd ball_y
    std ball_y
    subd #20
    bge ball_bricks
    ldd #20
    std ball_y
    clr ball_fraction_y
    ldd #0
    subd velocity_y
    std velocity_y
ball_bricks
    ldd ball_y
    addd #4
    subd #40
    bcc *+5
    jmp ball_paddle
    subd #40
    bcs *+5
    jmp ball_paddle
    addd #40
    lsrd
    lsrd
    lsrd
    stab brick_row
    ldd ball_x
    addd #4
    subd #32
    bcc *+5
    jmp ball_paddle
    subd #256
    bcs *+5
    jmp ball_paddle
    addd #256
    lsrd
    lsrd
    lsrd
    lsrd
    lsrd
    stab brick_column
    ldaa #8
    ldab brick_row
    mul
    addb brick_column
    adca #0
    addd #bricks
    xgdx
    tst 0,x
    bne *+5
    jmp ball_paddle
    clr 0,x
    ; A side entry reflects X; a top/bottom entry reflects Y. Restore that
    ; coordinate to the last position outside the brick to prevent re-entry.
    clra
    ldab brick_row
    asld
    asld
    asld
    addd #40
    std work_offset
    ldd previous_y
    addd #4
    subd work_offset
    bcs brick_vertical
    subd #8
    bcc brick_vertical
    clra
    ldab brick_column
    asld
    asld
    asld
    asld
    asld
    addd #32
    std work_offset
    ldd previous_x
    addd #4
    subd work_offset
    bcs brick_horizontal
    subd #32
    bcs brick_vertical
brick_horizontal
    ldd previous_x
    std ball_x
    clr ball_fraction_x
    ldd #0
    subd velocity_x
    std velocity_x
    bra brick_scored
brick_vertical
    ldd previous_y
    std ball_y
    clr ball_fraction_y
    ldd #0
    subd velocity_y
    std velocity_y
brick_scored
    dec remaining
    ldd score
    addd #10
    bcc *+5
    ldd #$ffff
    std score
    jsr drop_bonus
    jsr remove_brick
    ldaa #61
    ldab #5
    jsr effect
    jsr hud
    tst remaining
    bne ball_paddle
    clr launched
    ldx #win_text
    jsr centre_message
ball_paddle
    ldd ball_y
    subd #182
    bmi ball_done
    ldd velocity_y
    bmi ball_done
    ldd previous_y
    subd #182
    bgt ball_miss_check
    ldd ball_x
    addd #8
    subd paddle
    ble ball_miss_check
    ldd paddle
    addd #48
    subd ball_x
    ble ball_miss_check
    ldd #182
    std ball_y
    clr ball_fraction_y
    jsr paddle_bounce
    ldaa #49
    ldab #3
    jsr effect
    bra ball_done
ball_miss_check
    ldd ball_y
    subd #192
    bmi ball_done
    dec lives
    clr launched
    jsr hud
    ldaa #25
    ldab #15
    jsr effect
    ldx #launch_text
    tst lives
    bne ball_message
    inc round_ended
    ldx #lose_text
ball_message
    jsr centre_message
    ; A missed ball may have reached y=193/194 in this step. Do not draw or
    ; record that position: restoring its 8x8 dirty rectangle would exceed
    ; the framebuffer on the next visit to this display buffer.
    jsr reset_ball
ball_done
    rts
; Hit position sets the angle; incoming motion is a small bias, paddle motion
; adds spin. Q8.8 avoids rounding all impacts into seven integer trajectories.
; Limit VX to 2.75 px/frame and derive VY for a speed near 3 px/frame.
paddle_bounce
    ldd velocity_x
    std velocity_before
    ldd ball_x
    subd paddle
    subd #20
    subd #24
    ble bounce_hit_left
    ldd #24
    bra bounce_hit_scale
bounce_hit_left
    addd #24
    subd #-24
    bge bounce_hit_in_range
    ldd #-24
    bra bounce_hit_scale
bounce_hit_in_range
    subd #24
bounce_hit_scale
    asld
    asld
    asld
    std work_offset
    asld
    addd work_offset
    std work_offset
    ldd velocity_x
    tsta
    bpl bounce_incoming
    addd #7
bounce_incoming
    asra
    rorb
    asra
    rorb
    asra
    rorb
    addd work_offset
    std work_offset
    ldd paddle_delta
    asld
    asld
    asld
    asld
    std bounce_spin
    asld
    addd bounce_spin
    addd work_offset
    std work_offset
    subd #704
    bgt bounce_right
    ldd work_offset
    subd #-704
    blt bounce_left
    ldd work_offset
    bra bounce_store
bounce_right
    ldd #704
    bra bounce_store
bounce_left
    ldd #-704
bounce_store
    std velocity_x
    tsta
    bpl bounce_magnitude
    ldd #0
    subd velocity_x
bounce_magnitude
    subd #64
    bcc bounce_speed
    ; Avoid a permanently vertical orbit, retaining the rebound's sign.
    ldd velocity_x
    bne bounce_min_sign
    ldd velocity_before
bounce_min_sign
    tsta
    bmi bounce_min_left
    ldd #64
    bra bounce_min_store
bounce_min_left
    ldd #-64
bounce_min_store
    std velocity_x
    ldd #64
    bra bounce_speed_index
bounce_speed
    addd #64
bounce_speed_index
    addd #8
    lsrd
    lsrd
    lsrd
    lsrd
    asld
    ldx #bounce_y
    abx
    ldd 0,x
    std velocity_y
    rts
drop_bonus
    tst bonus_active
    bne bonus_done
    ldaa remaining
    anda #7
    bne bonus_done
    clra
    ldab brick_column
    asld
    asld
    asld
    asld
    asld
    addd #44
    std bonus_x
    clra
    ldab brick_row
    asld
    asld
    asld
    addd #40
    std bonus_y
    ldaa remaining
    lsra
    lsra
    lsra
    anda #1
    inca
    staa bonus_active
bonus_done
    rts
update_bonus
    tst bonus_active
    beq bonus_done
    ldd bonus_y
    addd #2
    std bonus_y
    subd #184
    bcs bonus_done
    ldd bonus_x
    addd #8
    subd paddle
    ble bonus_lost
    ldd paddle
    addd #48
    subd bonus_x
    ble bonus_lost
    ldaa bonus_active
    cmpa #2
    beq bonus_points
    ldaa lives
    cmpa #9
    bcc bonus_lost
    inc lives
    bra bonus_awarded
bonus_points
    ldd score
    addd #50
    bcc *+5
    ldd #$ffff
    std score
bonus_awarded
    jsr hud
    ldaa #72
    ldab #8
    jsr effect
bonus_lost
    clr bonus_active
    rts
remove_brick
    clra
    ldab brick_column
    asld
    asld
    asld
    asld
    asld
    addd #32
    std rect_desc
    clra
    ldab brick_row
    asld
    asld
    asld
    addd #40
    std rect_desc+2
    ldd #32
    std rect_desc+4
    ldaa #8
    staa rect_desc+6
    clr rect_desc+7
    ldaa #GB_TARGET
    ldab #3
    jsr api
    jsr rectangle
    jsr refresh_rectangle
    rts
rectangle
    ldx #rect_desc
    ldaa #GB_RECT
    jmp api
; Copy same rectangle from static background to the current hidden page.
restore_rectangle
    bsr prepare_restore
    bra copy_background
prepare_restore
    ldaa #64
    ldab rect_desc+3
    mul
    std work_offset
    asld
    asld
    addd work_offset
    addd rect_desc
    std blit_desc+4
    std blit_desc+6
    ldd rect_desc+4
    std blit_desc+8
    ldaa rect_desc+6
    staa blit_desc+10
    ldaa hidden
    staa blit_desc+3
    rts
copy_background
    ldaa #2
    staa blit_desc
    clr blit_desc+1
    ldaa #3
    staa blit_desc+2
    ldx #blit_desc
    ldaa #GB_COPY
    jmp api
refresh_rectangle
    ; Both display buffers receive the same background change in one SWI.
    jsr prepare_restore
    ldaa #2
    staa blit_desc
    clr blit_desc+1
    ldaa #3
    staa blit_desc+2
    ldx #blit_desc
    ldab #11
refresh_clone
    ldaa 0,x
    staa copy_zero-blit_desc,x
    staa copy_one-blit_desc,x
    inx
    decb
    bne refresh_clone
    clr copy_zero+3
    ldaa #1
    staa copy_one+3
    tst batch_available
    bne refresh_packed
    ; Without the BATCH feature use individual COPY operations.
    ldaa #GB_COPY
    ldx #copy_zero
    jsr api
    ldaa #GB_COPY
    ldx #copy_one
    jmp api
refresh_packed
    ldab #2
    ldx #refresh_batch
    ldaa #GB_BATCH
    jmp api
hud
    ldd score
    jsr hs_decimal
    ldd hs_number
    std score_text
    ldd hs_number+2
    std score_text+2
    ldaa hs_number+4
    staa score_text+4
    ldaa lives
    adda #'0'
    staa score_text+12
    tst hud_initialized
    bne hud_update
    inc hud_initialized
    ldaa #GB_TARGET
    ldab #3
    jsr api
    ldaa #GB_ATTR
    ldx #text_attr
    jsr api
    ldaa #GB_CURSOR
    ldx #hud_cursor
    jsr api
    ldx #hud_text
    ldaa #GB_PUTS
    jsr api
    ldaa #GB_PUTS
    ldx #score_text
    jsr api
    ldd score_text
    std hud_previous
    ldd score_text+2
    std hud_previous+2
    ldaa score_text+4
    staa hud_previous+4
    ldaa score_text+12
    staa hud_previous+5
    clr rect_desc
    clr rect_desc+1
    clr rect_desc+2
    ldaa #8
    staa rect_desc+3
    ldd #320
    std rect_desc+4
    ldaa #8
    staa rect_desc+6
    jsr refresh_rectangle
    jmp hud_done
hud_update
    clr hud_index
hud_digit_loop
    ldab hud_index
    ldx #hud_offsets
    abx
    ldab 0,x
    ldx #score_text
    abx
    ldaa 0,x
    ldab hud_index
    ldx #hud_previous
    abx
    cmpa 0,x
    beq hud_digit_next
    staa 0,x
    ; Atlas glyph -> background, then background -> both display buffers.
    suba #'0'
    tab
    clra
    asld
    asld
    asld
    addd #80
    std blit_desc+4
    ldab hud_index
    aslb
    ldx #hud_columns
    abx
    ldd 0,x
    std rect_desc
    addd #2560
    std blit_desc+6
    ldd #8
    std blit_desc+8
    std rect_desc+4
    std rect_desc+2
    ldaa #8
    staa blit_desc+10
    staa rect_desc+6
    ldaa #2
    staa blit_desc
    staa blit_desc+2
    clr blit_desc+1
    ldaa #3
    staa blit_desc+3
    ldx #blit_desc
    ldaa #GB_COPY
    jsr api
    jsr refresh_rectangle
hud_digit_next
    inc hud_index
    ldaa hud_index
    cmpa #6
    beq hud_done
    jmp hud_digit_loop
hud_done
    ldaa #'0'
    staa score_text
    staa score_text+1
    rts
hud_offsets db 0,1,2,3,4,12
hud_columns dw 200,208,216,224,232,296
centre_message
    stx message_pointer
    ldaa #GB_TARGET
    ldab #3
    jsr api
    ldaa #GB_CURSOR
    ldx #message_cursor
    jsr api
    ldaa #GB_PUTS
    ldx message_pointer
    jsr api
    jsr message_rectangle
    jmp refresh_rectangle
erase_message
    ldaa #GB_TARGET
    ldab #3
    jsr api
    jsr message_rectangle
    clr rect_desc+7
    jsr rectangle
    jmp refresh_rectangle
message_rectangle
    ldd #0
    std rect_desc
    ldd #104
    std rect_desc+2
    ldd #320
    std rect_desc+4
    ldaa #8
    staa rect_desc+6
    rts
effect
    staa note_desc+1
    clra
    std note_desc+2
    ldaa #2
    staa note_desc
    ldaa #12
    staa note_desc+4
    ldx #note_desc
    ldaa #GB_NOTE
    jmp api
fill_music
    jmp mus_fill

api
    staa last_operation
    int GB_INT
    tsta
    beq *+5
    jmp failed
    rts
failed
    staa failure_status
    ldaa GB_PS2_STATUS
    staa failure_raw
    ldaa $e650
    staa failure_gfx
    ldaa $e690
    staa failure_audio
    jsr sdk_close
    ldaa last_operation
    ldx #error_op
    jsr error_hex
    ldaa failure_status
    ldx #error_status
    jsr error_hex
    ldaa failure_raw
    ldx #error_raw
    jsr error_hex
    ldaa failure_gfx
    ldx #error_gfx
    jsr error_hex
    ldaa failure_audio
    ldx #error_audio
    jsr error_hex
    ldx #error_text
    jmp message_exit
error_hex
    tab
    lsra
    lsra
    lsra
    lsra
    bsr error_nibble
    staa 0,x
    tba
    anda #15
    bsr error_nibble
    staa 1,x
    rts
error_nibble
    adda #'0'
    cmpa #'9'
    bls *+4
    adda #7
    rts
exit_game
    ldd score
    std hs_score
    jsr hs_record
    jmp game_scores
exit_native
    jsr sdk_close
    jsr mus_release
    ldx #done_text
message_exit
    ; Every HD6303 exit owns music release, including OPEN/input failures.
    ldaa $e6a0
    bita #2
    beq message_print
    pshx
    jsr mus_release
    pulx
message_print
    jsr hs_unhook
    int $23
    clra
    int $38
hs_failure
    psha
    ldaa hs_ui_operation
    staa last_operation
    pula
    jmp failed
    include GAMESDK.ASM
    include HIGHSCR.ASM
    include MUSAPI.ASM
    include GAMEMUS.ASM
colours
    db 0,0,0,224,50,45,255,150,35,250,220,60,70,200,90
    db 70,120,240,80,220,230,255,255,255
map_desc
    dw world
    db 40,25,0,0,40,25,0,0,2,3
sprite_desc
    dw 0,0,17976,8
    db 8,2,0,0
text_attr db 7,0
hud_cursor db 1,1
digit_cursor db 10,0
digit_text db '0123456789',0
message_cursor db 9,13
hud_text db 'PYLDIN  ARKANOID  SCORE ',0
score_text db '00000 LIFE: 3',0
hs_title db 'PYLDIN ARKANOID',0
hs_primary_name db 'ARKSCORE.DAT',0
hs_backup_name db 'ARKSCORE.BAK',0
music_name db 'WARHAWK.YM',0
launch_text db 'SPACE: LAUNCH   ESC: EXIT',0
win_text db 'ALL BRICKS!    ESC: EXIT ',0
lose_text db 'GAME OVER      ESC: EXIT ',0
need_gamebios db 'ARKANOID needs HD6303 and GAMEBIOS ABI 2.',13,10,0
need_input db 'ARKANOID needs raw PS/2 capture FPGA.',13,10,0
refresh_batch
    db GB_COPY,0
    dw copy_zero
    db GB_COPY,0
    dw copy_one
error_text db 'ARKANOID: GAMEBIOS operation failed.',13,10,'OP='
error_op db '00 STATUS='
error_status db '00 RAW='
error_raw db '00',13,10,'GFX='
error_gfx db '00 AY='
error_audio db '00',13,10,0
done_text db 'ARKANOID: returned to UniDOS.',13,10,0
bounce_y
    ; Upward component for |VX|=0..704, step 16 in signed Q8.8.
    include BOUNCEY.INC
    section
bss_start
last_operation ds 1
failure_status ds 1
failure_raw ds 1
failure_gfx ds 1
failure_audio ds 1
palette_number ds 1
palette_pointer ds 2
pal_desc ds 4
note_desc ds 5
rect_desc ds 8
blit_desc ds 11
copy_zero ds 11
copy_one ds 11
work_count ds 2
work_offset ds 2
message_pointer ds 2
brick_row ds 1
brick_column ds 1
remaining ds 1
lives ds 1
score ds 2
paused ds 1
launched ds 1
hidden ds 1
batch_available ds 1
valid ds 2
hud_initialized ds 1
hud_index ds 1
hud_previous ds 6
held_keys ds 1
paddle ds 2
paddle_delta ds 2
ball_x ds 2
ball_y ds 2
velocity_x ds 2
velocity_y ds 2
ball_fraction_x ds 1
ball_fraction_y ds 1
previous_x ds 2
previous_y ds 2
velocity_before ds 2
bounce_spin ds 2
history ds 16
level ds 1
round_ended ds 1
bonus_active ds 1
bonus_x ds 2
bonus_y ds 2
bonus_history ds 8
bricks ds 40
world ds 1000
    include HISDATA.INC
    include GAMESDTA.INC
bss_end
    ends
    end start
