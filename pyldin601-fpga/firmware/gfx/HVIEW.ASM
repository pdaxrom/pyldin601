; UniAS HD6303 viewer: standard 320x200 HAM8 IFF ILBM, RGB222 CMAP.
; Eight interleaved bitplanes, raw or ByteRun1, bounded 32-bit chunk sizes.
ctrl=$e650
cmd=$e651
front=$e652
colour=$e653
dstpage=$e655
dstlo=$e658
dsthi=$e659
palhi=$e65d
ident=$e65e
palctl=$e65f
start
        ldaa $e6a0
        bita #2
        bne cpu_ok
        ldx #need_cpu
        jmp print_exit
cpu_ok
        ldaa ident
        cmpa #'G'
        bne need_fpga
        ldaa palctl
        cmpa #5
        bcc hardware_ok
need_fpga
        ldx #need_graphics
        jmp print_exit
hardware_ok
        int $3b
        cmpa #2
        beq args_ok
        ldx #usage
        jmp print_exit
args_ok
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
        ldx #open_error
        jmp print_exit
opened_ok
        stab handle
        inc opened
        ldaa handle
        ldx #file_size
        int $51
        tsta
        beq size_ok
        jmp io_error
size_ok
        ; Bound both input work and all 32-bit arithmetic to 1 MiB.
        ldx file_size
        cpx #15
        bls size_fits
        jmp bad_file
size_fits
        ldd #file_header
        std read_table
        ldd #12
        std read_table+2
        jsr read_exact
        jsr validate_form
        ldd file_size+2
        subd #12
        std file_left+2
        ldd file_size
        sbcb #0
        sbca #0
        std file_left
        bcc form_ready
        jmp bad_file
form_ready
        ldx #loading
        int $23
next_chunk
        ldd file_left
        bne read_chunk_header
        ldd file_left+2
        bne read_chunk_header
        jmp file_done
read_chunk_header
        ldx #chunk_header
        stx copy_pointer
        ldaa #8
        staa copy_count
header_byte
        jsr get_byte
        ldx copy_pointer
        staa 0,x
        inx
        stx copy_pointer
        dec copy_count
        bne header_byte
        ldd chunk_header+4
        std chunk_left
        ldd chunk_header+6
        std chunk_left+2
        andb #1
        stab padding
        ldx chunk_left
        cpx file_left
        bhi chunk_bad
        blo chunk_fits
        ldx chunk_left+2
        cpx file_left+2
        bls chunk_fits
chunk_bad
        jmp bad_file
chunk_fits
        ldx chunk_header
        cpx #$424d
        bne not_bmhd
        ldx chunk_header+2
        cpx #$4844
        bne unknown_chunk
        jsr bitmap_header
        jmp chunk_done
not_bmhd
        cpx #$4341
        bne not_camg
        ldx chunk_header+2
        cpx #$4d47
        bne unknown_chunk
        jsr mode_header
        jmp chunk_done
not_camg
        cpx #$434d
        bne not_cmap
        ldx chunk_header+2
        cpx #$4150
        bne unknown_chunk
        jsr colour_map
        jmp chunk_done
not_cmap
        cpx #$424f
        bne unknown_chunk
        ldx chunk_header+2
        cpx #$4459
        bne unknown_chunk
        ldaa seen
        cmpa #7
        beq body_ready
        jmp bad_file
body_ready
        clr ctrl
        ldaa front
        eora #1
        anda #15
        staa page
        staa dstpage
        jsr save_palette
        jsr make_components
        jsr decode_body
        ldaa #15
        staa seen
        jmp chunk_done
unknown_chunk
        jsr skip_chunk
chunk_done
        tst padding
        beq next_chunk_jump
        jsr get_byte
next_chunk_jump
        jmp next_chunk
file_done
        ldaa seen
        cmpa #15
        beq display_ready
        jmp bad_file
display_ready
        jsr close_file
        ldaa page
        staa dstpage
        ldaa #3
        jsr execute
        ldaa #7
        staa ctrl
keys
        int $10
        cmpa #$ff
        beq keys
        int $11
        cmpa #27
        bne keys
        ldx #returned
        jmp finish
bad_file
        ldx #format_error
        bra finish
io_error
        ldx #read_error
        bra finish
graphics_error
        ldx #draw_error
finish
        pshx
        tst opened
        beq file_closed
        jsr close_file
file_closed
        tst saved
        beq palette_intact
        clr ctrl
        jsr restore_palette
palette_intact
        pulx
print_exit
        int $23
        int $38
close_file
        ldaa handle
        int $4e
        clr opened
        rts
read_exact
        ldaa handle
        ldx #read_table
        int $4c
        tsta
        bne read_failed
        cpx read_table+2
        bne read_failed
        rts
read_failed
        jmp io_error
validate_form
        ldx file_header
        cpx #$464f
        bne form_bad
        ldx file_header+2
        cpx #$524d
        bne form_bad
        ldx file_header+8
        cpx #$494c
        bne form_bad
        ldx file_header+10
        cpx #$424d
        bne form_bad
        ldd file_size+2
        subd #8
        std temp_word
        ldd file_size
        sbcb #0
        sbca #0
        std temp_high
        ldx temp_high
        cpx file_header+4
        bne form_bad
        ldx temp_word
        cpx file_header+6
        bne form_bad
        rts
form_bad
        jmp bad_file
; get_byte decrements unread FILE bytes; refill never crosses EOF.
get_byte
        ldd file_left
        bne byte_exists
        ldd file_left+2
        bne byte_exists
        jmp bad_file
byte_exists
        ldd available
        bne buffered
        ldd #512
        ldx file_left
        bne refill_size
        ldx file_left+2
        cpx #512
        bcc refill_size
        ldd file_left+2
refill_size
        std read_table+2
        ldd #input_buffer
        std read_table
        jsr read_exact
        stx available
        ldx #input_buffer
        stx input_pointer
buffered
        ldd file_left+2
        subd #1
        std file_left+2
        ldd file_left
        sbcb #0
        sbca #0
        std file_left
        ldd available
        subd #1
        std available
        ldx input_pointer
        ldaa 0,x
        inx
        stx input_pointer
        rts
chunk_byte
        ldd chunk_left
        bne chunk_exists
        ldd chunk_left+2
        bne chunk_exists
        jmp bad_file
chunk_exists
        ldd chunk_left+2
        subd #1
        std chunk_left+2
        ldd chunk_left
        sbcb #0
        sbca #0
        std chunk_left
        jmp get_byte
skip_chunk
        ldd chunk_left
        bne skip_byte
        ldd chunk_left+2
        beq skip_done
skip_byte
        jsr chunk_byte
        bra skip_chunk
skip_done
        rts
; Known header payloads must fit in 16 bits and have an exact size in X.
header_length
        ldd chunk_left
        bne header_length_bad
        cpx chunk_left+2
        bne header_length_bad
        rts
header_length_bad
        jmp bad_file
bitmap_header
        ldaa seen
        bita #1
        bne bitmap_bad
        ldx #20
        jsr header_length
        ldx #bitmap
        stx copy_pointer
        ldaa #20
        staa copy_count
bitmap_byte
        jsr chunk_byte
        ldx copy_pointer
        staa 0,x
        inx
        stx copy_pointer
        dec copy_count
        bne bitmap_byte
        ldx bitmap
        cpx #320
        bne bitmap_bad
        ldx bitmap+2
        cpx #200
        bne bitmap_bad
        ldaa bitmap+8
        cmpa #8
        bne bitmap_bad
        tst bitmap+9
        bne bitmap_bad
        ldaa bitmap+10
        cmpa #1
        bhi bitmap_bad
        staa compression
        ldaa seen
        oraa #1
        staa seen
        rts
bitmap_bad
        jmp bad_file
mode_header
        ldaa seen
        bita #4
        bne mode_bad
        ldx #4
        jsr header_length
        jsr chunk_byte
        tsta
        bne mode_bad
        jsr chunk_byte
        tsta
        bne mode_bad
        jsr chunk_byte
        cmpa #8
        bne mode_bad
        jsr chunk_byte
        tsta
        bne mode_bad
        ldaa seen
        oraa #4
        staa seen
        rts
mode_bad
        jmp bad_file
colour_map
        ldaa seen
        bita #2
        bne map_bad
        ldx #192
        jsr header_length
        clr map_index
map_entry
        ldaa map_index
        lsra
        lsra
        lsra
        lsra
        jsr map_component
        ldaa map_index
        lsra
        lsra
        anda #3
        jsr map_component
        ldaa map_index
        anda #3
        jsr map_component
        inc map_index
        ldaa map_index
        cmpa #64
        bne map_entry
        ldaa seen
        oraa #2
        staa seen
        rts
map_component
        ldab #85
        mul
        stab expected_component
        jsr chunk_byte
        cmpa expected_component
        bne map_bad
        rts
map_bad
        jmp bad_file
decode_body
        clr position
        clr position+1
        ldaa #200
        staa rows_left
next_row
        ldx #row_buffer
clear_row
        clr 0,x
        inx
        cpx #row_buffer+320
        bne clear_row
        ldaa #1
        staa plane_mask
next_plane
        ldx #row_buffer
        stx pixel_pointer
        ldaa #40
        staa plane_left
plane_packet
        jsr chunk_byte
        tst compression
        beq raw_byte
        cmpa #128
        beq plane_packet
        bcc repeat_packet
        inca
        jsr packet_size
literal_byte
        jsr chunk_byte
        jsr put_plane_byte
        dec run_count
        bne literal_byte
        bra plane_more
repeat_packet
        nega
        inca
        jsr packet_size
        jsr chunk_byte
        staa packed_value
repeat_byte
        ldaa packed_value
        jsr put_plane_byte
        dec run_count
        bne repeat_byte
        bra plane_more
raw_byte
        jsr put_plane_byte
plane_more
        tst plane_left
        bne plane_packet
        asl plane_mask
        bne next_plane
        ldx #row_buffer
draw_pixel
        ldaa 0,x
        staa colour
        ldd position
        staa dsthi
        stab dstlo
        ldaa #4
        jsr execute
        inx
        ldd position
        addd #1
        std position
        cpx #row_buffer+320
        bne draw_pixel
        dec rows_left
        beq body_end
        jmp next_row
body_end
        ldd chunk_left
        bne body_tail
        ldd chunk_left+2
        beq body_done
body_tail
        tst compression
        beq body_bad
        jsr chunk_byte
        cmpa #128
        beq body_end
body_bad
        jmp bad_file
body_done
        rts
packet_size
        cmpa plane_left
        bhi body_bad
        staa run_count
        rts
put_plane_byte
        tab
        ldx pixel_pointer
        ldaa #8
        staa bit_count
plane_bit
        aslb
        bcc bit_zero
        ldaa 0,x
        oraa plane_mask
        staa 0,x
bit_zero
        inx
        dec bit_count
        bne plane_bit
        stx pixel_pointer
        dec plane_left
        rts
execute
        staa cmd
        pshx
        ldx #$ffff
wait_job
        ldaa ctrl
        bpl job_done
        dex
        bne wait_job
        jmp graphics_error
job_done
        bita #$30
        beq job_ok
        jmp graphics_error
job_ok
        pulx
        rts
; Palette save/restore and native component table builder follow below.
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
need_cpu db 'HVIEW: enable HD6303 EXTENSION in BIOS.',13,10,0
need_graphics db 'HVIEW: FPGA graphics v5 is required.',13,10,0
usage db 'Usage: HVIEW drive:picture.IFF',13,10,0
open_error db 'HVIEW: cannot open picture.',13,10,0
format_error db 'HVIEW: invalid HAM8 ILBM or palette.',13,10,0
read_error db 'HVIEW: file read failed.',13,10,0
draw_error db 'HVIEW: graphics command failed.',13,10,0
loading db 'HVIEW: loading HAM8; ESC returns after display.',13,10,0
returned db 'HVIEW: returned to UniDOS.',13,10,0
open_table dw 0,0
read_table dw 0,0
handle db 0
opened db 0
seen db 0
padding db 0
compression db 0
available dw 0
input_pointer dw 0
copy_pointer dw 0
copy_count db 0
file_size ds 4
file_left ds 4
chunk_left ds 4
file_header ds 12
chunk_header ds 8
bitmap ds 20
map_index db 0
expected_component db 0
plane_mask db 0
plane_left db 0
run_count db 0
packed_value db 0
bit_count db 0
pixel_pointer dw 0
rows_left db 0
position dw 0
temp_word dw 0
temp_high dw 0
page db 0
saved db 0
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
filename ds 81
input_buffer ds 512
row_buffer ds 320
backup ds 8192
