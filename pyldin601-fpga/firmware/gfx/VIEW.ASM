; Native UniDOS PCX viewer, HD6303 ISA. Standard version-5 8-bit, one-plane
; PCX with RLE and the actual 256-colour RGB trailer. No private file format.
ctrl = $e650
command = $e651
front = $e652
colour = $e653
destpage = $e655
destlo = $e658
desthi = $e659
widthlo = $e65a
widthhi = $e65b
heightreg = $e65c
ident = $e65e
palette_high = $e65d
palette_control = $e65f
cpuconfig = $e6a0

start
        ; Keep this guard MC6800-compatible, before the first extended opcode.
        ldaa cpuconfig
        bita #2
        bne hd_ok
        ldx #msg_hd
        int $23
        int $38
hd_ok
        ldaa ident
        cmpa #'G'
        beq hardware_ok
        ldx #msg_gfx
        jmp print_exit
hardware_ok
        ldaa palette_control
        cmpa #2
        bcc palette_hardware_ok
        ldx #msg_palette
        jmp print_exit
palette_hardware_ok
        int $3b
        cmpa #2
        beq arguments_ok
        ldx #msg_usage
        jmp print_exit
arguments_ok
        ldaa #1
        ldx #filename
        int $3c
        ldd #filename
        std open_table
        ldx #open_table
        ldaa #1
        int $4a
        tsta
        beq opened_ok
        ldx #msg_open
        jmp print_exit
opened_ok
        stab handle
        ldaa #1
        staa opened
        ldd #pcx_header
        std read_table
        ldd #128
        std read_table+2
        jsr read_exact
        bcc header_read
        jmp bad_file
header_read
        jsr validate_header
        bcc header_ok
        jmp bad_file
header_ok
        ; UniDOS INT51 uses big-endian 32-bit sizes, also above 64 KiB.
        ldaa handle
        ldx #file_size
        int $51
        tsta
        beq size_ok
        jmp io_error
size_ok
        ldd file_size+2
        subd #897             ; header 128 + trailer 769
        std data_left+2
        ldd file_size
        sbcb #0
        sbca #0
        std data_left
        bcc size_in_range
        jmp bad_file
size_in_range
        ldaa data_left
        oraa data_left+1
        oraa data_left+2
        oraa data_left+3
        bne size_nonzero
        jmp bad_file
size_nonzero
        ; IMPORTANT: UniDOS method 2 SUBTRACTS a positive distance from EOF.
        ldd #0
        std seek_pos
        ldd #769
        std seek_pos+2
        ldab #2
        jsr seek_file
        bcc palette_seek_ok
        jmp io_error
palette_seek_ok
        ldd #raw_palette
        std read_table
        ldd #769
        std read_table+2
        jsr read_exact
        bcc palette_read
        jmp bad_file
palette_read
        ldaa raw_palette
        cmpa #12
        beq palette_ok
        jmp bad_file
palette_ok
        clr ctrl
        jsr save_palette
        jsr make_palette
        ldd #0
        std seek_pos
        ldd #128
        std seek_pos+2
        clrb
        jsr seek_file
        bcc image_seek_ok
        jmp io_error
image_seek_ok
        ldx #msg_load
        int $23
        clr ctrl
        ldaa #1
        staa video_changed
        ldaa front
        eora #1
        anda #15
        staa destpage
        clr destlo
        clr desthi
        ldaa background
        staa colour
        ldaa #64
        staa widthlo
        ldaa #1
        staa widthhi
        ldaa #200
        staa heightreg
        ldaa #1
        jsr gfx_execute
        bcc cleared
        jmp graphics_error
cleared
        clr widthhi
        ldaa #1
        staa heightreg
        ; Centre the image. D and MUL avoid software 16-bit arithmetic.
        ldd #320
        subd image_width
        lsrd
        std row_address
        ldd #200
        subd image_height
        lsrd
        ldaa #64
        mul                   ; vertical margin * 64
        std temp_word
        asld
        asld
        addd temp_word        ; vertical margin * 320
        addd row_address
        std row_address
        ldd image_height
        std rows_left
next_row
        ldd row_address
        std pixel_address
        ldd image_width
        std visible_left
        ldd line_stride
        std line_left
next_packet
        jsr get_byte
        bcc packet_read
        jmp bad_rle
packet_read
        cmpa #$c0
        bcc repeated
        staa index_byte
        ldaa #1
        staa run_count
        bra packet_ready
repeated
        anda #$3f
        bne nonzero_run
        jmp bad_rle
nonzero_run
        staa run_count
        jsr get_byte
        bcc value_read
        jmp bad_rle
value_read
        staa index_byte
packet_ready
        clra
        ldab run_count
        std temp_word
        ldd line_left
        subd temp_word
        bcc packet_fits
        jmp bad_rle          ; a PCX packet must not cross a scanline
packet_fits
        std line_left
        ldd visible_left
        subd temp_word
        bcc fully_visible
        ldab visible_left+1 ; remaining visible part < run_count <= 63
        stab draw_count
        ldd #0
        std visible_left
        bra draw_packet
fully_visible
        std visible_left
        ldaa run_count
        staa draw_count
draw_packet
        tst draw_count
        beq packet_done     ; skip BytesPerLine padding, never draw it
        ldaa index_byte
        staa colour
        ldaa pixel_address
        staa desthi
        ldab pixel_address+1
        stab destlo
        ldaa draw_count
        staa widthlo
        cmpa #1
        bne fill_packet
        ldaa #4
        bra submit_packet
fill_packet
        ldaa #1
submit_packet
        jsr gfx_execute
        bcc packet_drawn
        jmp graphics_error
packet_drawn
        clra
        ldab draw_count
        addd pixel_address
        std pixel_address
packet_done
        ldd line_left
        beq row_done
        jmp next_packet
row_done
        ldd row_address
        addd #320
        std row_address
        ldd rows_left
        subd #1
        std rows_left
        beq decoded
        jmp next_row
decoded
        jsr close_file
        tsta
        beq closed_ok
        jmp io_error
closed_ok
        ldaa #3
        jsr gfx_execute
        bcc flipped
        jmp graphics_error
flipped
        ldaa #1
        staa ctrl
wait_key
        int $20
        cmpa #27
        bne wait_key
        ldx #msg_done
        bra finish
bad_file
        ldx #msg_format
        bra finish
bad_rle
        ldx #msg_data
        bra finish
io_error
        ldx #msg_io
        bra finish
graphics_error
        ldx #msg_command
finish
        pshx
        tst opened
        beq no_open_file
        jsr close_file
no_open_file
        tst video_changed
        beq no_video_change
        clr ctrl
no_video_change
        tst palette_saved
        beq no_palette_change
        clr ctrl
        jsr restore_palette
no_palette_change
        pulx
print_exit
        int $23
        int $38

; File helpers use the actual UniDOS API, not a host-specific interface.
close_file
        ldaa handle
        int $4e
        clr opened
        rts
seek_file
        ldaa handle
        ldx #seek_pos
        int $50
        tsta
        bne file_failure
        clc
        rts
read_exact
        ldaa handle
        ldx #read_table
        int $4c
        tsta
        bne file_failure
        cpx read_table+2
        bne file_failure
        clc
        rts
file_failure
        sec
        rts

; Buffered RLE input is bounded BEFORE the palette, including files >64 KiB.
get_byte
        ldd available
        bne buffered
        ldd data_left
        bne full_read
        ldd data_left+2
        beq file_failure
        xgdx
        cpx #512
        bcc full_read
        xgdx
        bra set_read_size
full_read
        ldd #512
set_read_size
        std read_table+2
        ldd #input_buffer
        std read_table
        ldaa handle
        ldx #read_table
        int $4c
        tsta
        bne file_failure
        cpx #0
        beq file_failure
        stx available
        stx temp_word
        ldd data_left+2
        subd temp_word
        std data_left+2
        ldd data_left
        sbcb #0
        sbca #0
        std data_left
        ldd #input_buffer
        std input_pointer
buffered
        ldd available
        subd #1
        std available
        ldx input_pointer
        ldaa 0,x
        inx
        stx input_pointer
        clc
        rts

gfx_execute
        staa command
        ldx #$ffff
gfx_wait
        ldaa ctrl
        bpl gfx_ready
        dex
        bne gfx_wait
        sec
        rts
gfx_ready
        bita #$30
        bne file_failure
        clc
        rts

; Read a little-endian PCX word into the HD6303 D register.
le_word
        ldab 0,x
        ldaa 1,x
        rts
validate_header
        ldaa pcx_header
        cmpa #10
        bne invalid_header
        ldaa pcx_header+1
        cmpa #5
        bne invalid_header
        ldaa pcx_header+2
        cmpa #1
        bne invalid_header
        ldaa pcx_header+3
        cmpa #8
        bne invalid_header
        ldaa pcx_header+65
        cmpa #1
        bne invalid_header
        ldx #pcx_header+4
        jsr le_word
        std temp_word
        ldx #pcx_header+8
        jsr le_word
        subd temp_word
        bcs invalid_header
        addd #1
        bcs invalid_header
        std image_width
        xgdx
        cpx #320
        bhi invalid_header
        ldx #pcx_header+6
        jsr le_word
        std temp_word
        ldx #pcx_header+10
        jsr le_word
        subd temp_word
        bcs invalid_header
        addd #1
        bcs invalid_header
        std image_height
        xgdx
        cpx #200
        bhi invalid_header
        ldx #pcx_header+66
        jsr le_word
        bitb #1
        bne invalid_header
        std line_stride
        subd image_width
        bcs invalid_header
        ldx line_stride
        cpx #512
        bhi invalid_header
        clc
        rts
invalid_header
        sec
        rts

; Preserve the complete previous waveform table, including other custom
; palettes. Port B readback is synchronous; CPU cycles allow it to settle.
save_palette
        clr front
        clr palette_high
        ldaa #1
        staa palette_control
        ldx #palette_backup
save_sample
        ldaa ident
        staa 0,x
        inx
        ldaa #3
        staa palette_control
        cpx #palette_backup+8192
        bne save_sample
        clr palette_control
        inc palette_saved
        rts
restore_palette
        clr front
        clr palette_high
        ldx #palette_backup
restore_sample
        ldaa 0,x
        staa ident
        inx
        cpx #palette_backup+8192
        bne restore_sample
        clr palette_control
        clr palette_saved
        rts

; Three signed Q9 RGB gains per phase. MUL uses unsigned magnitudes;
; add/subtract products to the 16-bit DAC accumulator, round once at end.
; The PCX indices themselves go into the framebuffer unchanged.
make_palette
        clr front
        clr palette_high
        ldd #raw_palette+1
        std palette_pointer
        ldd #$ffff
        std darkest
        clr palette_count
palette_entry
        ldx palette_pointer
        ldaa 0,x
        staa red
        ldaa 1,x
        staa green
        ldaa 2,x
        staa blue
        inx
        inx
        inx
        stx palette_pointer
        clra
        ldab red
        std accumulator
        ldab green
        addd accumulator
        std accumulator
        clra
        ldab blue
        addd accumulator
        subd darkest
        bcc background_known
        addd darkest
        std darkest
        ldaa palette_count
        staa background
background_known
        ldx #phase_gains
        ldaa #32
        staa phase_count
palette_phase
        ldd #15*512+256
        std accumulator
        ldaa red
        ldab 0,x
        jsr add_channel
        ldaa green
        ldab 1,x
        jsr add_channel
        ldaa blue
        ldab 2,x
        jsr add_channel
        ldaa accumulator
        lsra
        staa ident
        inx
        inx
        inx
        dec phase_count
        bne palette_phase
        inc palette_count
        bne palette_entry
        rts
add_channel
        tstb
        bmi subtract_channel
        mul
        addd accumulator
        std accumulator
        rts
subtract_channel
        negb
        mul
        std product
        ldd accumulator
        subd product
        std accumulator
        rts
phase_gains
        include PALCOEF.ASM

msg_hd db 'VIEW: enable HD6303 EXTENSION in BIOS.',13,10,0
msg_gfx db 'VIEW: FPGA graphics extension is absent.',13,10,0
msg_palette db 'VIEW: update FPGA for palette support.',13,10,0
msg_usage db 'Usage: VIEW drive:picture.PCX',13,10,'8-bit PCX, max 320x200. ESC returns to UniDOS.',13,10,0
msg_open db 'VIEW: cannot open picture.',13,10,0
msg_format db 'VIEW: unsupported or truncated PCX.',13,10,0
msg_data db 'VIEW: corrupt or truncated RLE data.',13,10,0
msg_io db 'VIEW: file read/seek failed.',13,10,0
msg_command db 'VIEW: graphics command failed.',13,10,0
msg_load db 'VIEW: loading PCX; ESC returns after display.',13,10,0
msg_done db 'VIEW: returned to UniDOS.',13,10,0
open_table dw 0,0
read_table dw 0,0
handle db 0
opened db 0
video_changed db 0
image_width dw 0
image_height dw 0
line_stride dw 0
file_size ds 4
seek_pos ds 4
data_left ds 4
available dw 0
input_pointer dw 0
row_address dw 0
pixel_address dw 0
rows_left dw 0
line_left dw 0
visible_left dw 0
temp_word dw 0
run_count db 0
draw_count db 0
index_byte db 0
palette_pointer dw 0
palette_count db 0
palette_saved db 0
phase_count db 0
red db 0
green db 0
blue db 0
background db 0
darkest dw 0
accumulator dw 0
product dw 0
filename ds 81
pcx_header ds 128
raw_palette ds 769
input_buffer ds 512
palette_backup ds 8192
