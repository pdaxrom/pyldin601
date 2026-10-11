; Puldin HD6303 GAMEBIOS example: tiles, dirty buffers, AY music + effects.
    include GAMEBIOS.INC
start
    ldab #GB_VIDEO+GB_AUDIO
    jsr sdk_open
    tsta
    beq started
    ldx #need_gamebios
    jmp message_exit
started
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
    ldaa brick_row
    inca
    staa 0,x
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
    inc brick_column
    ldaa brick_column
    cmpa #8
    bne brick_map_column
    inc brick_row
    ldaa brick_row
    cmpa #5
    bne brick_map_row
    ldx #map_desc
    jsr sdk_map
    tsta
    beq *+5
    jmp failed
    ldaa #40
    staa remaining
    ldaa #3
    staa lives
    clr score
    clr score+1
    clr paused
    clr launched
    clr hidden
    clr valid
    clr valid+1
    clr song_index
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
    jsr fill_music
    ldaa #GB_PLAY
    ldab #1
    jsr api
frame_loop
    ; Drain native characters so typematic events do not spill into DOS.
    ; Movement comes exclusively from physical make/break state below.
drain_keys
    int $10
    cmpa #$ff
    beq sample_keys
    int $11
    bra drain_keys
sample_keys
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
    beq keys_done
    tst remaining
    beq keys_done
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
    jmp frame_loop
frame_idle
    ; Keep keyboard responsive while audio is paused.
    jmp frame_loop
reset_ball
    ldd paddle
    addd #20
    std ball_x
    ldd #182
    std ball_y
    ldd #2
    std velocity_x
    ldd #-2
    std velocity_y
    rts
move_ball
    ldd ball_x
    addd velocity_x
    std ball_x
    subd #2
    ble ball_left
    ldd ball_x
    subd #310
    bge ball_right
    bra ball_vertical
ball_left
    ldd #2
    std ball_x
    bra ball_reverse_x
ball_right
    ldd #310
    std ball_x
ball_reverse_x
    ldd #0
    subd velocity_x
    std velocity_x
ball_vertical
    ldd ball_y
    addd velocity_y
    std ball_y
    subd #20
    bgt ball_bricks
    ldd #20
    std ball_y
    ldd #0
    subd velocity_y
    std velocity_y
ball_bricks
    ldd ball_y
    addd #4
    subd #40
    bcs ball_paddle
    subd #40
    bcc ball_paddle
    addd #40
    lsrd
    lsrd
    lsrd
    stab brick_row
    ldd ball_x
    addd #4
    subd #32
    bcs ball_paddle
    subd #256
    bcc ball_paddle
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
    beq ball_paddle
    clr 0,x
    ldd #0
    subd velocity_y
    std velocity_y
    dec remaining
    ldd score
    addd #10
    std score
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
    ldx #lose_text
ball_message
    jsr centre_message
ball_done
    rts
; Incoming direction, hit position and actual paddle motion shape the rebound.
; Ball centre relative to paddle centre is -27..27 on overlapping sprites.
; Seven 8-pixel zones add -3..3 to VX; half the paddle displacement adds spin.
; Bound VX to -3..3 and choose VY for nearly constant speed, always upwards.
paddle_bounce
    ldd ball_x
    subd paddle
    addd #8
    lsrd
    lsrd
    lsrd
    subd #3
    addd velocity_x
    std work_offset
    ldd paddle_delta
    asra
    rorb
    addd work_offset
    std work_offset
    subd #3
    bgt bounce_right
    ldd work_offset
    subd #-3
    blt bounce_left
    ldd work_offset
    bra bounce_store
bounce_right
    ldd #3
    bra bounce_store
bounce_left
    ldd #-3
bounce_store
    std velocity_x
    tsta
    bpl bounce_magnitude
    ldd #0
    subd velocity_x
bounce_magnitude
    ldx #bounce_y
    abx
    ldab 0,x
    ldaa #$ff
    std velocity_y
    rts
bounce_y
    db -3,-3,-2,-1
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
    ; Preserve current hidden selector; update both histories after a change.
    ldaa hidden
    psha
    clr hidden
    jsr restore_rectangle
    inc hidden
    jsr restore_rectangle
    pula
    staa hidden
    rts
hud
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
    ; Three decimal digits, maximum score 400.
    ldd score
    std work_count
    ldab #'0'
hundreds_loop
    ldd work_count
    subd #100
    bcs hundreds_done
    std work_count
    inc score_text
    bra hundreds_loop
hundreds_done
    ldd work_count
    subd #10
    bcs tens_done
    std work_count
    inc score_text+1
    bra hundreds_done
tens_done
    ldab work_count+1
    addb #'0'
    stab score_text+2
    ldaa lives
    adda #'0'
    staa score_text+10
    ldaa #GB_PUTS
    ldx #score_text
    jsr api
    ldaa #'0'
    staa score_text
    staa score_text+1
    clr rect_desc
    clr rect_desc+1
    clr rect_desc+2
    ldaa #8
    staa rect_desc+3
    ldd #320
    std rect_desc+4
    ldaa #8
    staa rect_desc+6
    jmp refresh_rectangle
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
    ldaa #GB_STATUS
    jsr api
    cmpb #16
    beq music_done
    ldaa #14
    ldab song_index
    mul
    addd #song
    xgdx
    ldaa #GB_FRAME
    jsr api
    inc song_index
    ldaa song_index
    anda #63
    staa song_index
    bra fill_music
music_done
    rts
api
    int GB_INT
    tsta
    beq *+5
    jmp failed
    rts
failed
    jsr sdk_close
    ldx #error_text
    jmp message_exit
exit_game
    jsr sdk_close
    ldx #done_text
message_exit
    int $23
    clra
    int $38
    include GAMESDK.ASM
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
message_cursor db 9,13
hud_text db 'PULDIN  ARKANOID  SCORE ',0
score_text db '000 LIFE: 3',0
launch_text db 'SPACE: LAUNCH   ESC: EXIT',0
win_text db 'ALL BRICKS!    ESC: EXIT ',0
lose_text db 'GAME OVER      ESC: EXIT ',0
need_gamebios db 'ARKANOID needs HD6303 and GAMEBIOS ABI 1.',13,10,0
need_input db 'ARKANOID needs PS/2 raw FPGA.',13,10,0
error_text db 'ARKANOID: GAMEBIOS operation failed.',13,10,0
done_text db 'ARKANOID: returned to UniDOS.',13,10,0
song
    include ARKSONG.INC
bss_start
palette_number ds 1
palette_pointer ds 2
pal_desc ds 4
note_desc ds 5
rect_desc ds 8
blit_desc ds 11
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
valid ds 2
song_index ds 1
held_keys ds 1
paddle ds 2
paddle_delta ds 2
ball_x ds 2
ball_y ds 2
velocity_x ds 2
velocity_y ds 2
history ds 16
bricks ds 40
world ds 1000
    include GAMESDTA.INC
bss_end
    end start
