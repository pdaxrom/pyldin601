need_cpu db 'YPLAY: enable HD6303 in BIOS.',13,10,0
need_ram db 'YPLAY: update RAM manager ROM.',13,10,0
memory_error db 'YPLAY: not enough free paged RAM.',13,10,0
need_audio db 'YPLAY: update audio FPGA and both BIOS ROMs.',13,10,0
audio_busy db 'YPLAY: music timer already in use.',13,10,0
clock_timeout db 'YPLAY: AY clock update timed out.',13,10,0
usage
    .ifdef GFXMUSIC_DEMO
    db 'GFXMUSIC file.YM|PSG|VTX [/L] [/A|C|S|M]',13,10,0
    .else
    db 'YPLAY file.YM|PSG|VTX [/L] [/A|C|S|M]',13,10,0
    .endif
open_error db 'YPLAY: cannot open file.',13,10,0
read_error db 'YPLAY: file read failed.',13,10,0
format_error db 'YPLAY: invalid/unsupported file.',13,10,0
effect_error db 'YPLAY: Atari timer/digidrum effect.',13,10,0
size_error db 'YPLAY: file exceeds 888 KiB.',13,10,0
foreign_timer db 'YPLAY: INT E4 is in a ROM page.',13,10,0
loading
    .ifdef GFXMUSIC_DEMO
    db 'GFXMUSIC: preparing music and HAM8...',13,10,0
    .else
    db 'YPLAY: loading into paged RAM...',13,10,0
    .endif
playing
    .ifdef GFXMUSIC_DEMO
    db 'GFXMUSIC: SPACE pause, ESC exit.',13,10,0
    .else
    db 'YPLAY: playing; SPACE pause, ESC exit.',13,10,0
    .endif
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
    section
saved_divider ds 4
saved_period ds 4
timer_period ds 4
    ends
timer_remainder dw 0
irq_ticks dw 0
rate dw 50
clock_factor dw 289
io_table dw 0,0
    section
file_size ds 4
file_left ds 4
song_size ds 4
    ends
available dw 0
input_pointer dw 0
write_pointer db 0,0,$c0,0
read_pointer db 0,0,$c0,0
map_index db 0
vtx_mode db 0
    section
read_left ds 4
    ends
access_pointer dw 0
header_pointer dw 0
header_count db 0
    section
raw_frame ds 14
    ends
compare dw 0
    include YMSTATE.INC
    include LHASTATE.INC
    section
memory_lease ds 114
bank_groups ds 111
bank_pages ds 111
queue_data ds 224
queue_end
filename ds 81
option ds 81
input_buffer ds 512
header ds 260
    include LHABSS.INC
