; HD6303 UniDOS AY register-dump player. Real UniAS relocatable PGM.
; File lives in expansion SRAM; its own hardware timer IRQ sends queued frames.
; YM3/3b/5/6 and PSG, explicit format/size/effect checks before playback.
page equ $e6f0
group equ $e6f1
ay equ $e610
audio equ $e690
start
    ldaa $e6a0
    bita #2
    bne cpu_ok
    ldx #need_cpu
    jmp message_exit
cpu_ok
    ldaa $e6f2
    cmpa #'R'
    beq long_yplay_15
    jmp no_ram
long_yplay_15
    ldaa $e6f3
    cmpa #111
    beq long_yplay_18
    jmp no_ram
long_yplay_18
    ldaa $edf0
    anda #$f0
    cmpa #$b0
    beq long_yplay_22
    jmp no_ram
long_yplay_22
    ldaa $e691
    cmpa #$59
    beq audio_hardware
    ldx #need_audio
    jmp message_exit
audio_hardware
    clra
    int $e0
    bitb #16
    bne audio_bios
    ldx #need_audio
    jmp message_exit
audio_bios
    ldaa audio
    bita #1
    beq audio_idle
    ldx #audio_busy
    jmp message_exit
audio_idle
    ldaa page
    staa saved_page
    ldaa group
    staa saved_group
    ldd #289
    std clock_factor
    int $3b
    cmpa #2
    bcc long_yplay_31
    jmp arguments_bad
long_yplay_31
    cmpa #5
    bcs long_yplay_33
    jmp arguments_bad
long_yplay_33
    staa argc
    ldaa #1
    ldx #filename
    int $3c
    ldaa #2
    staa argument
options
    ldaa argument
    cmpa argc
    bcs long_yplay_43
    jmp open_song
long_yplay_43
    ldx #option
    int $3c
    ldaa option
    cmpa #'/'
    beq long_yplay_48
    jmp arguments_bad
long_yplay_48
    tst option+2
    beq long_yplay_50
    jmp arguments_bad
long_yplay_50
    ldaa option+1
    anda #$df
    cmpa #'L'
    bne clock_option
    inc looping
    bra next_option
clock_option
    ldd #256
    ldaa option+1
    anda #$df
    cmpa #'A'
    beq clock_atari
    ldd #512
    ldaa option+1
    anda #$df
    cmpa #'C'
    beq clock_cpc
    ldd #286
    ldaa option+1
    anda #$df
    cmpa #'M'
    beq clock_msx
    cmpa #'S'
    beq long_yplay_74
    jmp arguments_bad
long_yplay_74
    ldd #289
    bra set_clock
clock_atari
    ldd #256
    bra set_clock
clock_cpc
    ldd #512
    bra set_clock
clock_msx
    ldd #286
set_clock
    std clock_factor
next_option
    inc argument
    jmp options
no_ram
    ldx #need_ram
    jmp message_exit
arguments_bad
    ldx #usage
    jmp message_exit
open_song
    ldd #filename
    std io_table
    ldx #io_table
    ldaa #1
    int $4a
    tsta
    beq open_ok
    ldx #open_error
    jmp message_exit
open_ok
    stab handle
    inc opened
    ldaa handle
    ldx #file_size
    int $51
    tsta
    beq long_yplay_113
    jmp io_failed
long_yplay_113
    ldd file_size
    std file_left
    ldd file_size+2
    std file_left+2
    ldx #loading
    int $23
    jsr load_song
    jsr close_song
    jsr parse_song
    ; Full validation is done before owning or reconfiguring the AY/timer.
    ldx #queue_data
    stx queue_head
    stx queue_tail
prefill
    jsr queue_fill
    tst decode_status
    bne prefilled
    ldaa queued
    cmpa #16
    bcs prefill
prefilled
    ldx #playing
    int $23
    ldaa #$e4
    int $2e
    tstb
    beq timer_ok
    ldx #foreign_timer
    jmp finish
timer_ok
    stx old_timer
    jsr configure_audio
    sei
    ldx #irq_player
    stx $efc8
    inc hooked
    ldaa #5
    staa audio
    cli
foreground
    tst stopped
    bne ended
    tst paused
    bne foreground_key
    jsr queue_fill
foreground_key
    int $10
    cmpa #$ff
    beq foreground
    int $11
    cmpa #27
    beq escaped
    cmpa #32
    bne foreground
    sei
    ldaa paused
    eora #1
    staa paused
    beq resumed
    clr audio
    cli
    jsr silence
    jmp foreground
resumed
    ldaa #5
    staa audio
    cli
    jmp foreground
escaped
    ldx #esc_message
    bra finish
ended
    ldx #done_message
    ldaa stopped
    cmpa #1
    beq finish
bad_file
    ldx #format_error
    bra finish
io_failed
    ldx #read_error
    bra finish
too_large
    ldx #size_error
    bra finish
unsupported_effect
    ldx #effect_error
finish
    stx finish_message
    sei
    tst hooked
    beq no_hook
    ldx old_timer
    clr audio
    stx $efc8
    clr hooked
no_hook
    tst audio_owned
    bne finish_silence
    ldaa audio
    bita #1
    bne finish_pages
finish_silence
    jsr silence
    jsr restore_audio
finish_pages
    ldaa saved_group
    staa group
    ldaa saved_page
    staa page
    cli
    jsr close_song
    ldx finish_message
message_exit
    int $23
return_to_dos
    int $38
silence
    ldaa #$3f
    staa ay+7
    clr ay+8
    clr ay+9
    clr ay+10
    rts
close_song
    tst opened
    beq closed
    ldaa handle
    int $4e
    clr opened
closed
    rts

; Buffered file reader: bounded by the actual DOS size, not FAT allocation.
file_byte
    ldd file_left
    bne file_available
    ldd file_left+2
    bne file_available
    jmp bad_file
file_available
    ldd available
    bne file_buffered
    ldd #512
    ldx file_left
    bne refill
    ldx file_left+2
    cpx #512
    bcc refill
    ldd file_left+2
refill
    std io_table+2
    ldd #input_buffer
    std io_table
    ldaa handle
    ldx #io_table
    int $4c
    tsta
    beq long_yplay_238
    jmp io_failed_jump
long_yplay_238
    cpx io_table+2
    beq long_yplay_240
    jmp io_failed_jump
long_yplay_240
    stx available
    ldx #input_buffer
    stx input_pointer
    ; Loading can also be cancelled; this never runs in the IRQ handler.
    jsr loading_key
    bra file_buffered
loading_key
    int $10
    cmpa #$ff
    beq loading_key_done
    int $11
    cmpa #27
    bne loading_key_done
    jmp escaped
loading_key_done
    rts
io_failed_jump
    jmp io_failed
file_buffered
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

; Memory pointer = group, slot, big-endian CPU address. All app code/data
; is in conventional RAM, so both page writes are safe with IRQ enabled.
mem_read
    stx access_pointer
    ldaa 0,x
    staa group
    ldaa 1,x
    staa page
    ldx 2,x
    ldaa 0,x
    psha
    ldx access_pointer
    jsr mem_advance
    pula
    rts
mem_advance
    inc 3,x
    bne mem_done
    inc 2,x
    ldaa 2,x
    cmpa #$e0
    bne mem_done
    ldaa #$c0
    staa 2,x
    inc 1,x
    ldaa 1,x
    cmpa #7
    bne mem_done
    ldaa #1
    staa 1,x
    inc 0,x
mem_done
    rts
mem_write
    psha
    ldx #write_pointer
    ldaa 0,x
    staa group
    ldaa 1,x
    staa page
    ldx 2,x
    pula
    staa 0,x
    ldx #write_pointer
    jmp mem_advance
memory_byte
    ldd read_left
    bne memory_available
    ldd read_left+2
    bne memory_available
    jmp bad_file
memory_available
    ldd read_left+2
    subd #1
    std read_left+2
    ldd read_left
    sbcb #0
    sbca #0
    std read_left
    ldx #read_pointer
    jmp mem_read
memory_reset
    ldd #1
    std read_pointer
    ldd #$c000
    std read_pointer+2
    ldd song_size
    std read_left
    ldd song_size+2
    std read_left+2
    rts
load_song
    ldd #1
    std write_pointer
    ldd #$c000
    std write_pointer+2
    ; Read the signature first. LHA detection/decoder is in a separate module.
    ldx #header
    stx header_pointer
    ldaa #4
    staa header_count
load_signature
    jsr file_byte
    ldx header_pointer
    staa 0,x
    inx
    stx header_pointer
    dec header_count
    bne load_signature
    ldaa header+2
    cmpa #'-'
    bne load_raw
    ldaa header+3
    cmpa #'l'
    bne load_raw
    jmp load_lha
load_raw
    ldd file_size
    std song_size
    ldd file_size+2
    std song_size+2
    jsr check_size
    ldx #header
    stx header_pointer
    ldaa #4
    staa header_count
write_signature
    ldx header_pointer
    ldaa 0,x
    inx
    stx header_pointer
    jsr mem_write
    dec header_count
    bne write_signature
load_raw_next
    ldd file_left
    bne load_raw_byte
    ldd file_left+2
    beq load_complete
load_raw_byte
    jsr file_byte
    jsr mem_write
    bra load_raw_next
load_complete
    rts
check_size
    ldd song_size
    std compare
    ldx compare
    cpx #13
    bhi oversized
    bne size_valid
    ldd song_size+2
    std compare
    ldx compare
    cpx #$e000
    bhi oversized
size_valid
    ldd song_size
    bne size_valid_return
    ldd song_size+2
    std compare
    ldx compare
    cpx #4
    bcs file_invalid
size_valid_return
    rts
oversized
    jmp too_large
file_invalid
    jmp bad_file

    include YMREAD.INC
    include LHA5.INC

; Produce at most one complete, frame in the foreground.
; Only the count publication is masked; IRQ may consume older frames while
; parsing and banking run. Head belongs to IRQ; tail to foreground.
queue_fill
    ldaa queued
    cmpa #16
    bcc queue_return
    tst decode_status
    bne queue_return
    tst kind
    beq queue_psg
    jsr ym_frame
    bra queue_decoded
queue_psg
    jsr psg_frame
queue_decoded
    tst decode_status
    bne queue_return
    ldx #raw_frame
    stx queue_source
    ldx queue_tail
    stx queue_destination
    ldaa #14
    staa queue_left
queue_copy
    ldx queue_source
    ldaa 0,x
    inx
    stx queue_source
    ldx queue_destination
    staa 0,x
    inx
    stx queue_destination
    dec queue_left
    bne queue_copy
    cpx #queue_end
    bne queue_publish
    ldx #queue_data
queue_publish
    stx queue_tail
    sei
    inc queued
    cli
queue_return
    rts

 ; INT E4: BIOS has acknowledged this timer separately from PAL/keyboard.
; Only conventional-RAM queue reads and AY writes; no banking or arithmetic.
irq_player
    inc irq_ticks+1
    bne irq_no_carry
    inc irq_ticks
irq_no_carry
    tst stopped
    beq irq_running
    rts
irq_running
    tst paused
    beq irq_active
    rts
irq_active
    tst queued
    bne irq_send
    ldaa decode_status
    beq irq_underrun
    staa stopped
    rts
irq_underrun
    inc underruns
    rts
irq_send
    ldx queue_head
write_frame
    ldaa 0,x
    staa ay
    ldaa 1,x
    staa ay+1
    ldaa 2,x
    staa ay+2
    ldaa 3,x
    staa ay+3
    ldaa 4,x
    staa ay+4
    ldaa 5,x
    staa ay+5
    ldaa 6,x
    staa ay+6
    ldaa 7,x
    staa ay+7
    ldaa 8,x
    staa ay+8
    ldaa 9,x
    staa ay+9
    ldaa 10,x
    staa ay+10
    ldaa 11,x
    staa ay+11
    ldaa 12,x
    staa ay+12
    ldaa 13,x
    cmpa #$ff
    beq frame_sent
    staa ay+13
frame_sent
    ldab #14
    abx
    cpx #queue_end
    bne irq_head_ready
    ldx #queue_data
irq_head_ready
    stx queue_head
    dec queued
irq_return
    rts

; Configure only an idle timer. Preserve its period and the previous chip
; divisor; all four-byte MMIO values are committed with a separate command.
configure_audio
    ldaa audio
    bita #1
    beq audio_available
    ldx #audio_busy
    jmp finish
audio_available
    jsr divider_wait
    bcc audio_clock_ready
    ldx #clock_timeout
    jmp finish
audio_clock_ready
    ldd audio+2
    std saved_period
    ldd audio+4
    std saved_period+2
    ldd audio+11
    std saved_divider
    ldd audio+13
    std saved_divider+2
    inc audio_owned
    ldx #div_atari
    ldd clock_factor
    subd #256
    beq divider_selected
    ldx #div_cpc
    ldd clock_factor
    subd #512
    beq divider_selected
    ldx #div_spectrum
    ldd clock_factor
    subd #289
    beq divider_selected
    ldx #div_msx
divider_selected
    jsr divider_write
    bcc audio_clock_set
    ldx #clock_timeout
    jmp finish
audio_clock_set
    jsr timer_calculate
    ldd timer_period
    std audio+2
    ldd timer_period+2
    std audio+4
    ldaa #1
    staa audio+6
    rts
restore_audio
    tst audio_owned
    beq restore_audio_done
    clr audio
    ldd saved_period
    std audio+2
    ldd saved_period+2
    std audio+4
    ldaa #1
    staa audio+6
    ldx #saved_divider
    jsr divider_write
    clr audio_owned
restore_audio_done
    rts
divider_write
    ldd 0,x
    std audio+11
    ldd 2,x
    std audio+13
    ldaa #1
    staa audio+15
divider_wait
    ldx #$ffff
divider_wait_loop
    ldaa audio
    bita #$20
    beq divider_wait_ok
    dex
    bne divider_wait_loop
    sec
    rts
divider_wait_ok
    clc
    rts
; Rounded unsigned 24000000/rate. Division occurs once before playback,
; including rates below 50 Hz; IRQ spacing never depends on CPU speed.
timer_calculate
    ldd #$016e
    std timer_period
    ldd #$3600
    std timer_period+2
    ldd #0
    std timer_remainder
    ldaa #32
    staa shift_count
timer_divide
    asl timer_period+3
    rol timer_period+2
    rol timer_period+1
    rol timer_period
    rol timer_remainder+1
    rol timer_remainder
    ldd timer_remainder
    subd rate
    bcs timer_bit
    std timer_remainder
    inc timer_period+3
timer_bit
    dec shift_count
    bne timer_divide
    ldd timer_remainder
    asld
    subd rate
    bcs timer_ready
    inc timer_period+3
    bne timer_ready
    inc timer_period+2
    bne timer_ready
    inc timer_period+1
    bne timer_ready
    inc timer_period
timer_ready
    rts
div_atari dw $0180,$0000
div_cpc dw $0300,$0000
div_spectrum dw $01b1,$1101
div_msx dw $01ad,$1acd

need_cpu db 'YPLAY: enable HD6303 in BIOS.',13,10,0
need_ram db 'YPLAY: update paged FPGA and BIOS.',13,10,0
need_audio db 'YPLAY: update audio FPGA and both BIOS ROMs.',13,10,0
audio_busy db 'YPLAY: music timer already in use.',13,10,0
clock_timeout db 'YPLAY: AY clock update timed out.',13,10,0
usage db 'YPLAY file.YM|PSG [/L] [/A|C|S|M]',13,10,0
open_error db 'YPLAY: cannot open file.',13,10,0
read_error db 'YPLAY: file read failed.',13,10,0
format_error db 'YPLAY: invalid/unsupported file.',13,10,0
effect_error db 'YPLAY: Atari timer/digidrum effect.',13,10,0
size_error db 'YPLAY: file exceeds 888 KiB.',13,10,0
foreign_timer db 'YPLAY: INT E4 is in a ROM page.',13,10,0
loading db 'YPLAY: loading into paged RAM...',13,10,0
playing db 'YPLAY: playing; SPACE pause, ESC exit.',13,10,0
done_message db 'YPLAY: finished.',13,10,0
esc_message db 'YPLAY: stopped.',13,10,0
finish_message dw 0
argc db 0
argument db 0
looping db 0
paused db 0
stopped db 0
decode_status db 0
queued db 0
underruns db 0
queue_head dw 0
queue_tail dw 0
queue_source dw 0
queue_destination dw 0
queue_left db 0
kind db 0
hooked db 0
opened db 0
handle db 0
saved_page db 0
saved_group db 0
old_timer dw 0
audio_owned db 0
saved_divider ds 4
saved_period ds 4
timer_period ds 4
timer_remainder dw 0
irq_ticks dw 0
rate dw 50
clock_factor dw 289
io_table dw 0,0
file_size ds 4
file_left ds 4
song_size ds 4
available dw 0
input_pointer dw 0
write_pointer db 0,1,$c0,0
read_pointer db 0,1,$c0,0
read_left ds 4
access_pointer dw 0
header_pointer dw 0
header_count db 0
raw_frame ds 14
compare dw 0
    include YMSTATE.INC
    include LHASTATE.INC
bss_start
queue_data ds 224
queue_end
filename ds 81
option ds 81
input_buffer ds 512
header ds 260
    include LHABSS.INC
bss_end
    end start
