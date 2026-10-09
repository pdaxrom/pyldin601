; Native HD6303 HAM8 demo. Standard relocatable UniDOS PGM.
; Page 0 holds a 320x200 HAM command stream. No host-generated assets.
ctrl=$e650
cmd=$e651
front=$e652
colour=$e653
dstpage=$e655
dstlo=$e658
dsthi=$e659
widthlo=$e65a
widthhi=$e65b
height=$e65c
palhi=$e65d
ident=$e65e
palctl=$e65f
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
        ldaa palctl
        cmpa #5
        bcc hardware_ok
need_fpga
        ldx #need_graphics
        jmp message_exit
hardware_ok
        clr ctrl
        clr saved
        ldx #loading
        int $23
        jsr save_palette
        jsr make_components
        clr page
page_loop
        ldaa page
        staa dstpage
        clr dstlo
        clr dsthi
        clr colour
        ldaa #64
        staa widthlo
        ldaa #1
        staa widthhi
        ldaa #200
        staa height
        ldaa #1
        jsr execute
        ; 64x64 five-pixel cells, each repeated on three physical source rows.
        ; Every cell sets R, G, B explicitly; its last three pixels are exact.
        clr widthhi
        ldaa #3
        staa height
        clr row
        clr row_base
        clr row_base+1
row_loop
        ldd row_base
        std position
        clr column
cell_loop
        ; Fine six-bit R/G ramps and a diagonal B ramp: 4096 distinct states.
        ldaa column
        oraa #$80
        staa red_code
        ldaa row
        oraa #$c0
        staa green_code
        ldaa row
        adda column
        anda #63
        oraa #$40
        staa blue_code
        ldd position
        staa dsthi
        stab dstlo
        ldaa #1
        staa widthlo
        ldaa red_code
        staa colour
        ldaa #1
        jsr execute
        ldd position
        addd #1
        staa dsthi
        stab dstlo
        ldaa green_code
        staa colour
        ldaa #1
        jsr execute
        ldd position
        addd #2
        staa dsthi
        stab dstlo
        ldaa #3
        staa widthlo
        ldaa blue_code
        staa colour
        ldaa #1
        jsr execute
        ldd position
        addd #5
        std position
        inc column
        ldaa column
        cmpa #64
        beq row_done
        jmp cell_loop
row_done
        ldd row_base
        addd #960
        std row_base
        inc row
        ldaa row
        cmpa #64
        beq page_done
        jmp row_loop
page_done

images_ready
        ldx #running
        int $23
        jsr show
keys
        int $10
        cmpa #$ff
        beq keys
        int $11
        cmpa #27
        beq escape
        bra keys

escape
        clr ctrl
        jsr restore_palette
        ldx #returned
message_exit
        int $23
        int $38
show
        clr ctrl
        ldaa page
        staa dstpage
        ldaa #3
        jsr execute
        ldaa #7
        staa ctrl
        rts

execute
        staa cmd
        ldx #$ffff
wait_job
        ldaa ctrl
        bpl job_done
        dex
        bne wait_job
        bra failed
job_done
        bita #$30
        bne failed
        rts
failed
        clr ctrl
        jsr restore_palette
        ldx #graphics_error
        jmp message_exit
save_palette
        clr front
        clr palhi
        ldaa #1
        staa palctl
        ldx #backup
save_sample
        ldaa ident
        staa 0,x
        inx
        ldaa #3
        staa palctl
        cpx #backup+8192
        bne save_sample
        clr palctl
        inc saved
        rts
restore_palette
        tst saved
        beq restore_done
        clr front
        clr palhi
        ldx #backup
restore_sample
        ldaa 0,x
        staa ident
        inx
        cpx #backup+8192
        bne restore_sample
        clr palctl
        clr saved
restore_done
        rts
; Three 64x32 six-bit component tables in the existing waveform RAM.
; Native signed Q9 gains, one hardware MUL per sample. No host converter.
make_components
        clr front
        clr palhi
        clr channel
channel_loop
        ldd #6400             ; R/B bias 12, plus one-half for rounding
        ldab channel
        cmpb #1
        bne bias12
        ldd #768              ; G bias 1, plus one-half for rounding
        bra bias_ready
bias12
        ldd #6400
bias_ready
        std bias
        clr level
level_loop
        ldaa level
        lsra
        lsra
        lsra
        lsra
        staa temp
        ldaa level
        asla
        asla
        oraa temp             ; six-bit level -> RGB888 by replication
        staa rgb_value
        ldx #coefficients
        ldab channel
        abx
        stx gain_pointer
        ldaa #32
        staa phases
phase_loop
        ldx gain_pointer
        ldaa 0,x
        inx
        inx
        inx
        stx gain_pointer
        ldab rgb_value
        tsta
        bmi subtract_gain
        mul
        addd bias
        bra rounded
subtract_gain
        nega
        mul
        std product
        ldd bias
        subd product
rounded
        lsra                  ; positive 16-bit Q9 accumulator >> 9
        staa ident
        dec phases
        bne phase_loop
        inc level
        ldaa level
        cmpa #64
        bne level_loop
        inc channel
        ldaa channel
        cmpa #3
        bne channel_loop
        rts
loading db 'HAM: preparing native HAM8 demo...',13,10,0
running db 'HAM: HAM8 colour ramps; ESC returns.',13,10,0
returned db 'HAM: returned to UniDOS.',13,10,0
need_cpu db 'HAM needs HD6303 EXTENSION Y.',13,10,0
need_graphics db 'HAM needs FPGA graphics v5 or later.',13,10,0
graphics_error db 'HAM: graphics error; palette restored.',13,10,0
saved db 0
page db 0
row db 0
column db 0
row_base dw 0
position dw 0
red_code db 0
green_code db 0
blue_code db 0
temp db 0
channel db 0
level db 0
phases db 0
rgb_value db 0
bias dw 0
product dw 0
gain_pointer dw 0
coefficients
        include PALCOEF.ASM
backup ds 8192
