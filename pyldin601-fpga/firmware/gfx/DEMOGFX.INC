; Shared-IRQ GFXMUSIC graphics: no song-bank accesses and no disk I/O.
; HAM runs restart at four-pixel boundaries. Sprites move four pixels in X,
; and every opaque run is grid-aligned, so transparent COPY cannot leak
; held RGB state into the original background to its right.
gfxmusic_guard
    ldaa $e65e
    cmpa #'G'
    bne gfxmusic_need_gfx
    ldaa $e65f
    cmpa #5
    bcs gfxmusic_need_gfx
    ldaa $e650
    bita #$81
    bne gfxmusic_busy_gfx
    rts
gfxmusic_need_gfx
    ldx #lg_need_gfx
    jmp message_exit
gfxmusic_busy_gfx
    ldx #lg_busy_gfx
    jmp message_exit
gfxmusic_init
    jsr lg_save_palette
    jsr lg_make_components
    jsr lg_background
    jsr gfxmusic_atlas
    rts
gfxmusic_show
    ldaa #7
    staa $e650
    rts
gfxmusic_finish
    tst lg_saved
    beq lg_finish_done
    clr $e650
    ; Drain a possibly accepted command before restoring palette/console.
    ldx #$ffff
lg_finish_wait
    ldaa $e650
    bpl lg_finish_ready
    dex
    bne lg_finish_wait
lg_finish_ready
    jsr lg_restore_palette
lg_finish_done
    rts
lg_ctrl = $e650
lg_cmd = $e651
lg_front = $e652
lg_colour = $e653
lg_srcpage = $e654
lg_dstpage = $e655
lg_srclo = $e656
lg_srchi = $e657
lg_dstlo = $e658
lg_dsthi = $e659
lg_widthlo = $e65a
lg_widthhi = $e65b
lg_height = $e65c
lg_ident = $e65e
lg_version = $e65f

gfxmusic_atlas
        clr lg_valid
        clr lg_valid+1
        ldx #lg_initial_motion
        ldd 0,x
        std lg_motion
        ldd 2,x
        std lg_motion+2
        ldd 4,x
        std lg_motion+4
        ldd 6,x
        std lg_motion+6
        ldd 8,x
        std lg_motion+8
        ldd 10,x
        std lg_motion+10
        ldd 12,x
        std lg_motion+12
        ldd 14,x
        std lg_motion+14
        ldd 16,x
        std lg_motion+16
        ldd 18,x
        std lg_motion+18
        ldd 20,x
        std lg_motion+20
        ldd 22,x
        std lg_motion+22
        ; The atlas is cleared once; index zero is the transparent key.
        ldaa #2
        staa lg_dstpage
        clr lg_dstlo
        clr lg_dsthi
        clr lg_colour
        jsr lg_full_rectangle
        ldaa #1
        jsr lg_execute
        clr lg_ball
lg_atlas_ball
        ldaa lg_ball
        asla
        asla
        asla
        asla
        asla
        staa lg_atlas_x
        ldx #lg_ball_colours
        ldab lg_ball
        abx
        ldaa 0,x
        staa lg_colour
        clr lg_line
        clr lg_row_base
        clr lg_row_base+1
        clr lg_widthhi
        ldaa #1
        staa lg_height
lg_atlas_line
        ldx #lg_circle
        ldab lg_line
        aslb
        abx
        ldab 0,x
        clra
        addd lg_row_base
        addb lg_atlas_x
        adca #0
        staa lg_dsthi
        stab lg_dstlo
        ldaa 1,x
        staa lg_widthlo
        ldaa #1
        jsr lg_execute
        ldd lg_row_base
        addd #320
        std lg_row_base
        inc lg_line
        ldaa lg_line
        cmpa #32
        bne lg_atlas_line
        ; A grid-aligned highlight makes the round sprites easy to identify.
        ldd #2568
        addb lg_atlas_x
        adca #0
        staa lg_dsthi
        stab lg_dstlo
        ldaa #4
        staa lg_widthlo
        staa lg_height
        ldaa #63
        staa lg_colour
        ldaa #1
        jsr lg_execute
        inc lg_ball
        ldaa lg_ball
        cmpa #3
        beq lg_atlas_done
        jmp lg_atlas_ball
lg_atlas_done

        ; The only full-frame copies happen before animation starts.
        ldaa #3
        staa lg_srcpage
        clr lg_srclo
        clr lg_srchi
        clr lg_dstlo
        clr lg_dsthi
        clr lg_dstpage
        jsr lg_full_rectangle
        ldaa #2
        jsr lg_execute
        inc lg_dstpage
        ldaa #2
        jsr lg_execute
        clr lg_dstpage
        ldaa #3
        jsr lg_execute
        rts

gfxmusic_frame
        ldaa lg_front
        eora #1
        staa lg_hidden
        staa lg_dstpage
        clr lg_widthhi
        ; Restore ALL old clipped rectangles before drawing ANY sprite.
        ldx #lg_valid
        ldab lg_hidden
        abx
        tst 0,x
        beq lg_draw_sprites
        ldaa #3
        staa lg_srcpage
        clr lg_ball
lg_restore_sprite
        jsr lg_previous_pointer
        ldaa 2,x
        beq lg_restore_next
        staa lg_widthlo
        ldaa 3,x
        staa lg_height
        ldd 0,x
        staa lg_srchi
        stab lg_srclo
        staa lg_dsthi
        stab lg_dstlo
        ldaa #2
        jsr lg_execute
lg_restore_next
        inc lg_ball
        ldaa lg_ball
        cmpa #3
        bne lg_restore_sprite
lg_draw_sprites
        ldaa #2
        staa lg_srcpage
        clr lg_colour
        clr lg_srchi
        clr lg_ball
lg_draw_sprite
        jsr lg_motion_pointer
        ldd 0,x
        std clip_x
        ldd 2,x
        std clip_y
        clra
        ldab lg_ball
        aslb
        aslb
        aslb
        aslb
        aslb
        std clip_src
        ldd #32
        std clip_width
        ldaa #32
        staa clip_height
        jsr gfx_clip
        ; Store the actual visible rectangle separately for each lg_hidden page.
        jsr lg_previous_pointer
        ldd clip_destination
        std 0,x
        ldaa clip_draw_width+1
        staa 2,x
        ldaa clip_draw_height
        staa 3,x
        tst 2,x
        beq lg_draw_next
        ldd clip_source
        staa lg_srchi
        stab lg_srclo
        ldd clip_destination
        staa lg_dsthi
        stab lg_dstlo
        ldaa clip_draw_width+1
        staa lg_widthlo
        ldaa clip_draw_height
        staa lg_height
        ldaa #6
        jsr lg_execute
lg_draw_next
        inc lg_ball
        ldaa lg_ball
        cmpa #3
        beq lg_draw_done
        jmp lg_draw_sprite
lg_draw_done
        ldx #lg_valid
        ldab lg_hidden
        abx
        ldaa #1
        staa 0,x
        ; FLIP waits for the 50Hz field boundary; CPU never copies pixels.
        ldaa #3
        jsr lg_execute
        clr lg_ball
lg_move_sprite
        jsr lg_motion_pointer
        ldd 0,x
        addd 4,x
        addd #32
        bmi lg_bounce_left
        subd #352
        bmi lg_x_in_range
        beq lg_x_in_range
        ldd #320
        bra lg_bounce_x
lg_x_in_range
        addd #320
        bra lg_store_x
lg_bounce_left
        ldd #$ffe0
lg_bounce_x
        std 0,x
        ldd #0
        subd 4,x
        std 4,x
        bra lg_move_y
lg_store_x
        std 0,x
lg_move_y
        ldd 2,x
        addd 6,x
        addd #32
        bmi lg_bounce_top
        subd #232
        bmi lg_y_in_range
        beq lg_y_in_range
        ldd #200
        bra lg_bounce_y
lg_y_in_range
        addd #200
        bra lg_store_y
lg_bounce_top
        ldd #$ffe0
lg_bounce_y
        std 2,x
        ldd #0
        subd 6,x
        std 6,x
        bra lg_move_next
lg_store_y
        std 2,x
lg_move_next
        inc lg_ball
        ldaa lg_ball
        cmpa #3
        bne lg_move_sprite
        rts

; X points to x,y,dx,dy, each a big-endian signed 16-bit word.
lg_motion_pointer
        ldx #lg_motion
        ldab lg_ball
        aslb
        aslb
        aslb
        abx
        rts
lg_previous_pointer
        ldx #lg_previous
        ldab lg_hidden
        ldaa #12
        mul
        abx
        ldab lg_ball
        aslb
        aslb
        abx
        rts
lg_full_rectangle
        ldaa #64
        staa lg_widthlo
        ldaa #1
        staa lg_widthhi
        ldaa #200
        staa lg_height
        rts
lg_ball_colours db 48,12,3
; Every opaque run and transparent gap spans complete four-pixel HAM cells.
lg_circle db 12,8,12,8,8,16,8,16,4,24,4,24,4,24,4,24
       db 0,32,0,32,0,32,0,32,0,32,0,32,0,32,0,32
       db 0,32,0,32,0,32,0,32,0,32,0,32,0,32,0,32
       db 4,24,4,24,4,24,4,24,8,16,8,16,12,8,12,8
lg_initial_motion dw -16,-16,4,1,304,184,-4,-2,140,85,-4,3
    section
lg_motion ds 24
lg_previous ds 24
lg_valid ds 2
    ends
lg_hidden db 0
lg_ball db 0
lg_atlas_x db 0
lg_line db 0
lg_row_base dw 0

lg_save_palette
        clr $e652
        clr $e65d
        ldaa #1
        staa $e65f
        ldx #lg_backup
lg_save_sample
        ldaa $e65e
        staa 0,x
        inx
        ldaa #3
        staa $e65f
        cpx #lg_backup+8192
        bne lg_save_sample
        clr $e65f
        inc lg_saved
        rts
lg_restore_palette
        tst lg_saved
        beq lg_restore_done
        clr $e652
        clr $e65d
        ldx #lg_backup
lg_restore_sample
        ldaa 0,x
        staa $e65e
        inx
        cpx #lg_backup+8192
        bne lg_restore_sample
        clr $e65f
        clr lg_saved
lg_restore_done
        rts
; Three 64x32 six-bit component tables in the existing waveform RAM.
; Native signed Q9 gains, one hardware MUL per sample. No host converter.
lg_make_components
        clr $e652
        clr $e65d
        clr lg_channel
lg_channel_loop
        ldd #6400             ; R/B lg_bias 12, plus one-half for rounding
        ldab lg_channel
        cmpb #1
        bne lg_bias12
        ldd #768              ; G lg_bias 1, plus one-half for rounding
        bra lg_bias_ready
lg_bias12
        ldd #6400
lg_bias_ready
        std lg_bias
        clr lg_level
lg_level_loop
        ldaa lg_level
        lsra
        lsra
        lsra
        lsra
        staa lg_temp
        ldaa lg_level
        asla
        asla
        oraa lg_temp             ; six-bit lg_level -> RGB888 by replication
        staa lg_rgb_value
        ldx #lg_coefficients
        ldab lg_channel
        abx
        stx lg_gain_pointer
        ldaa #32
        staa lg_phases
lg_phase_loop
        ldx lg_gain_pointer
        ldaa 0,x
        inx
        inx
        inx
        stx lg_gain_pointer
        ldab lg_rgb_value
        tsta
        bmi lg_subtract_gain
        mul
        addd lg_bias
        bra lg_rounded
lg_subtract_gain
        nega
        mul
        std lg_product
        ldd lg_bias
        subd lg_product
lg_rounded
        lsra                  ; positive 16-bit Q9 accumulator >> 9
        staa $e65e
        dec lg_phases
        bne lg_phase_loop
        inc lg_level
        ldaa lg_level
        cmpa #64
        bne lg_level_loop
        inc lg_channel
        ldaa lg_channel
        cmpa #3
        bne lg_channel_loop
        rts

; Native procedural 80x50 colour cells: coarse RGB222 followed by B/R/G.
; All four pixels describe the same target colour with finer precision.
lg_background
    ldaa #3
    staa lg_dstpage
    clr lg_widthhi
    ldaa #1
    staa lg_widthlo
    ldaa #4
    staa lg_height
    clr lg_row
    clr lg_row_base
    clr lg_row_base+1
lg_background_row
    ldd lg_row_base
    std lg_position
    clr lg_column
lg_background_cell
    ldaa lg_column
    cmpa #64
    bcs lg_red_ok
    nega
    adda #127
lg_red_ok
    staa lg_red
    jsr lg_quantize
    asla
    asla
    asla
    asla
    staa lg_base
    ldaa lg_row
    adda #14
    staa lg_green
    jsr lg_quantize
    asla
    asla
    oraa lg_base
    staa lg_base
    ldaa lg_row
    asla
    adda lg_column
    anda #63
    staa lg_blue
    jsr lg_quantize
    oraa lg_base
    staa lg_colour
    ldd lg_position
    staa lg_dsthi
    stab lg_dstlo
    ldaa #1
    jsr lg_execute
    ldd lg_position
    addd #1
    staa lg_dsthi
    stab lg_dstlo
    ldaa lg_blue
    oraa #$40
    staa lg_colour
    ldaa #1
    jsr lg_execute
    ldd lg_position
    addd #2
    staa lg_dsthi
    stab lg_dstlo
    ldaa lg_red
    oraa #$80
    staa lg_colour
    ldaa #1
    jsr lg_execute
    ldd lg_position
    addd #3
    staa lg_dsthi
    stab lg_dstlo
    ldaa lg_green
    oraa #$c0
    staa lg_colour
    ldaa #1
    jsr lg_execute
    ldd lg_position
    addd #4
    std lg_position
    inc lg_column
    ldaa lg_column
    cmpa #80
    beq lg_background_row_done
    jmp lg_background_cell
lg_background_row_done
    ldd lg_row_base
    addd #1280
    std lg_row_base
    inc lg_row
    ldaa lg_row
    cmpa #50
    beq lg_background_done
    jmp lg_background_row
lg_background_done
    rts
lg_quantize
    cmpa #11
    bcs lg_q0
    cmpa #32
    bcs lg_q1
    cmpa #53
    bcs lg_q2
    ldaa #3
    rts
lg_q0
    clra
    rts
lg_q1
    ldaa #1
    rts
lg_q2
    ldaa #2
    rts
lg_execute
    staa lg_cmd
    ldx #$ffff
    stx lg_timeout
lg_wait_job
    ; A 100-Hz tune may consume two frames during one 50-Hz FLIP.
    ; Refill during EVERY DMA wait; no decoding happens in the IRQ.
    jsr queue_fill
    ldaa lg_ctrl
    bpl lg_job_done
    ldx lg_timeout
    dex
    stx lg_timeout
    bne lg_wait_job
    bra lg_graphics_failed
lg_job_done
    bita #$30
    bne lg_graphics_failed
    tst hooked
    bne lg_job_return
    jsr loading_key
lg_job_return
    rts
lg_graphics_failed
    ldx #lg_graphics_error
    jmp finish
lg_need_gfx db 'GFXMUSIC: needs graphics v5.',13,10,0
lg_busy_gfx db 'GFXMUSIC: graphics already in use.',13,10,0
lg_graphics_error db 'GFXMUSIC: graphics command failed.',13,10,0
lg_timeout dw 0
lg_saved db 0
lg_row db 0
lg_column db 0
lg_position dw 0
lg_red db 0
lg_green db 0
lg_blue db 0
lg_base db 0
lg_temp db 0
lg_channel db 0
lg_level db 0
lg_phases db 0
lg_rgb_value db 0
lg_bias dw 0
lg_product dw 0
lg_gain_pointer dw 0
lg_coefficients
    include PALCOEF.ASM
    include GFXCLIP.ASM
