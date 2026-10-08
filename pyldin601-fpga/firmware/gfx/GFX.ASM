; Relocatable UniDOS GFX.PGM, MC6800 instructions only.
; SPACE switches the two pages; ESC restores the native video controller.
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

start
        ldaa ident
        cmpa #'G'
        beq hardware_ok
        ldx #absent
        jmp message_exit
hardware_ok
        clr ctrl
        clr dstpage
        clr dstlo
        clr dsthi
        ldaa #64
        staa widthlo
        ldaa #1
        staa widthhi
        ldaa #200
        staa height
        clr colour
        ldaa #1
        jsr execute
        bcc clear_ok
        jmp failure
clear_ok
        clr widthhi
        ldaa #20
        staa widthlo
        ldaa #12
        staa height
        clr tile
        clr row
        clr row_base
        clr row_base+1
next_row
        ldx row_base
        stx position
        clr column
next_tile
        ldaa position
        staa dsthi
        ldaa position+1
        staa dstlo
        ldaa tile
        staa colour
        ldaa #1
        jsr execute
        bcc tile_ok
        jmp failure
tile_ok
        inc tile
        ldaa position+1
        adda #20
        staa position+1
        ldaa position
        adca #0
        staa position
        inc column
        ldaa column
        cmpa #16
        bne next_tile
        ldaa row_base
        adda #15
        staa row_base
        inc row
        ldaa row
        cmpa #16
        bne next_row
        ; Copy the complete frame to the second page using the hardware engine.
        clr srcpage
        ldaa #1
        staa dstpage
        clr srclo
        clr srchi
        clr dstlo
        clr dsthi
        ldaa #64
        staa widthlo
        ldaa #1
        staa widthhi
        ldaa #200
        staa height
        ldaa #2
        jsr execute
        bcc copy_ok
        jmp failure
copy_ok
        ; A white border and a rectangular copy make page changes visible.
        ldaa #$40
        staa dstlo
        ldaa #$32
        staa dsthi
        ldaa #192
        staa widthlo
        clr widthhi
        ldaa #120
        staa height
        ldaa #255
        staa colour
        ldaa #1
        jsr execute
        bcc border_ok
        jmp failure
border_ok
        ldaa #$50
        staa dstlo
        ldaa #$41
        staa dsthi
        ldaa #160
        staa widthlo
        ldaa #96
        staa height
        ldaa #2
        jsr execute
        bcc frame_ok
        jmp failure
frame_ok
        clr dstpage
        ldaa #3
        jsr execute
        bcs failure
        ldaa #1
        staa ctrl
wait_key
        int $20
        cmpa #27
        beq finished
        cmpa #32
        bne wait_key
        ldaa front
        eora #1
        staa dstpage
        ldaa #3
        jsr execute
        bcc wait_key
failure
        clr ctrl
        ldx #failed
        bra message_exit
finished
        clr ctrl
        ldx #done
message_exit
        int $23
        int $38

execute
        staa cmd
busy
        ldaa ctrl
        bmi busy
        bita #$30
        bne error
        clc
        rts
error
        sec
        rts

absent db 'GFX: FPGA graphics extension is absent.',13,10,0
failed db 'GFX: graphics command failed.',13,10,0
done db 'GFX: returned to native video.',13,10,0
tile db 0
row db 0
column db 0
row_base dw 0
position dw 0
