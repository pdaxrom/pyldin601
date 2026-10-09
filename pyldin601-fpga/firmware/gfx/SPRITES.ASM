; Native relocatable HD6303 UniDOS demo: three colour-key sprites, two frames.
; Pages 0/1: frames; 2: sprite atlas; 3: static background. ESC returns to DOS.
ctrl = $e650
cmd = $e651
front = $e652
colour = $e653
srcpage = $e654
dstpage = $e655
srclo = $e656
srchi = $e657
dstlo = $e658
dsthi = $e659
widthlo = $e65a
widthhi = $e65b
height = $e65c
ident = $e65e
version = $e65f

start
        ldaa $e6a0
        bita #2
        bne cpu_ok
        ldx #need_cpu
        jmp message_exit
cpu_ok
        ldaa ident
        cmpa #'G'
        bne need_fpga
        ldaa version
        cmpa #3
        bcc hardware_ok
need_fpga
        ldx #need_graphics
        jmp message_exit
hardware_ok
        clr ctrl
        ; The PGM can be invoked repeatedly: all animation state is reset.
        clr valid
        clr valid+1
        ldx #initial_motion
        ldd 0,x
        std motion
        ldd 2,x
        std motion+2
        ldd 4,x
        std motion+4
        ldd 6,x
        std motion+6
        ldd 8,x
        std motion+8
        ldd 10,x
        std motion+10
        ldd 12,x
        std motion+12
        ldd 14,x
        std motion+14
        ldd 16,x
        std motion+16
        ldd 18,x
        std motion+18
        ldd 20,x
        std motion+20
        ldd 22,x
        std motion+22
        ldx #running
        int $23
        ; The atlas is cleared once; index zero is the transparent key.
        ldaa #2
        staa dstpage
        clr dstlo
        clr dsthi
        clr colour
        jsr full_rectangle
        ldaa #1
        jsr execute
        clr ball
atlas_ball
        ldaa ball
        asla
        asla
        asla
        asla
        asla
        staa atlas_x
        ldx #ball_colours
        ldab ball
        abx
        ldaa 0,x
        staa colour
        clr line
        clr row_base
        clr row_base+1
        clr widthhi
        ldaa #1
        staa height
atlas_line
        ldx #circle
        ldab line
        aslb
        abx
        ldab 0,x
        clra
        addd row_base
        addb atlas_x
        adca #0
        staa dsthi
        stab dstlo
        ldaa 1,x
        staa widthlo
        ldaa #1
        jsr execute
        ldd row_base
        addd #320
        std row_base
        inc line
        ldaa line
        cmpa #32
        bne atlas_line
        ; A small highlight makes the round sprites easy to identify.
        ldd #2568
        addb atlas_x
        adca #0
        staa dsthi
        stab dstlo
        ldaa #4
        staa widthlo
        staa height
        ldaa #255
        staa colour
        ldaa #1
        jsr execute
        inc ball
        ldaa ball
        cmpa #3
        beq atlas_done
        jmp atlas_ball
atlas_done

        ; A 20x20 checkerboard is an independent, unchanged background.
        ldaa #3
        staa dstpage
        ldaa #20
        staa widthlo
        staa height
        clr widthhi
        clr row
        clr row_base
        clr row_base+1
background_row
        ldd row_base
        std position
        clr column
background_tile
        ldd position
        staa dsthi
        stab dstlo
        ldaa row
        eora column
        anda #1
        beq dark_tile
        ldaa #$4a
        bra tile_colour
dark_tile
        ldaa #$25
tile_colour
        staa colour
        ldaa #1
        jsr execute
        ldd position
        addd #20
        std position
        inc column
        ldaa column
        cmpa #16
        bne background_tile
        ldd row_base
        addd #6400
        std row_base
        inc row
        ldaa row
        cmpa #10
        bne background_row
        ; The only full-frame copies happen before animation starts.
        ldaa #3
        staa srcpage
        clr srclo
        clr srchi
        clr dstlo
        clr dsthi
        clr dstpage
        jsr full_rectangle
        ldaa #2
        jsr execute
        inc dstpage
        ldaa #2
        jsr execute
        clr dstpage
        ldaa #3
        jsr execute
        ldaa #1
        staa ctrl

frame_loop
        ; INT10 peeks, INT11 consumes: no blocking input or macro expansion.
        int $10
        cmpa #$ff
        beq frame_ready
        int $11
        cmpa #27
        bne frame_ready
        clr ctrl
        ldx #done
        jmp message_exit
frame_ready
        ldaa front
        eora #1
        staa hidden
        staa dstpage
        ldaa #32
        staa widthlo
        staa height
        clr widthhi
        ; Restore ALL old rectangles before drawing ANY current sprite.
        ldx #valid
        ldab hidden
        abx
        tst 0,x
        beq draw_sprites
        ldaa #3
        staa srcpage
        clr ball
restore_sprite
        jsr previous_pointer
        ldd 0,x
        staa srchi
        stab srclo
        staa dsthi
        stab dstlo
        ldaa #2
        jsr execute
        inc ball
        ldaa ball
        cmpa #3
        bne restore_sprite
draw_sprites
        ldaa #2
        staa srcpage
        clr colour
        clr srchi
        clr ball
draw_sprite
        jsr motion_pointer
        jsr screen_offset
        staa dsthi
        stab dstlo
        std position
        jsr previous_pointer
        ldd position
        std 0,x
        ldaa ball
        asla
        asla
        asla
        asla
        asla
        staa srclo
        ldaa #6
        jsr execute
        inc ball
        ldaa ball
        cmpa #3
        bne draw_sprite
        ldx #valid
        ldab hidden
        abx
        ldaa #1
        staa 0,x
        ; FLIP waits for the 50Hz field boundary; CPU never copies pixels.
        ldaa #3
        jsr execute
        clr ball
move_sprite
        jsr motion_pointer
        ldd 0,x
        addd 4,x
        bmi bounce_left
        subd #288
        bmi x_in_range
        beq x_in_range
        ldd #288
        bra bounce_x
x_in_range
        addd #288
        bra store_x
bounce_left
        ldd #0
bounce_x
        std 0,x
        ldd #0
        subd 4,x
        std 4,x
        bra move_y
store_x
        std 0,x
move_y
        ldd 2,x
        addd 6,x
        bmi bounce_top
        subd #168
        bmi y_in_range
        beq y_in_range
        ldd #168
        bra bounce_y
y_in_range
        addd #168
        bra store_y
bounce_top
        ldd #0
bounce_y
        std 2,x
        ldd #0
        subd 6,x
        std 6,x
        bra move_next
store_y
        std 2,x
move_next
        inc ball
        ldaa ball
        cmpa #3
        bne move_sprite
        jmp frame_loop

; X points to x,y,dx,dy, each a big-endian signed 16-bit word.
motion_pointer
        ldx #motion
        ldab ball
        aslb
        aslb
        aslb
        abx
        rts
previous_pointer
        ldx #previous
        ldab hidden
        ldaa #6
        mul
        abx
        ldab ball
        aslb
        abx
        rts
screen_offset
        ldab 3,x
        ldaa #64
        mul
        std scratch
        asld
        asld
        addd scratch
        addd 0,x
        rts
full_rectangle
        ldaa #64
        staa widthlo
        ldaa #1
        staa widthhi
        ldaa #200
        staa height
        rts
execute
        staa cmd
busy
        ldaa ctrl
        bmi busy
        bita #$30
        bne failure
        rts
failure
        clr ctrl
        ldx #failed
message_exit
        int $23
        int $38

need_cpu db 'SPRITES: enable HD6303 in BIOS setup.',13,10,0
need_graphics db 'SPRITES: update FPGA for transparent COPY (v3).',13,10,0
running db 'SPRITES: colour-key animation; ESC returns to UniDOS.',13,10,0
failed db 'SPRITES: graphics command failed.',13,10,0
done db 'SPRITES: returned to UniDOS.',13,10,0
ball_colours db $e0,$1c,$03
; Left inset and width for each row of a 32x32 round sprite.
circle db 12,8,10,12,8,16,6,20,5,22,4,24,3,26,2,28
       db 2,28,1,30,1,30,1,30,0,32,0,32,0,32,0,32
       db 0,32,0,32,0,32,0,32,1,30,1,30,1,30,2,28
       db 2,28,3,26,4,24,5,22,6,20,8,16,10,12,12,8
initial_motion dw 0,0,2,1,288,168,-3,-2,12,10,3,2
motion ds 24
previous ds 12
valid ds 2
hidden db 0
ball db 0
atlas_x db 0
line db 0
row db 0
column db 0
row_base dw 0
position dw 0
scratch dw 0
