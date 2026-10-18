; Read-only SPI initialization diagnostic, MC6800 ISA, native relocatable PGM.
; Load using the working SD/HG, replace SD at the prompt, press Enter.
; No sector commands, DOS file calls or return to stale mounted volumes.
SPI_DATA equ $e661
SPI_CTL equ $e662
SPI_DIV equ $e663
PAL_TICK equ $e62b
start
    ldx #intro
    int $23
    ldaa #$23
    staa SPI_CTL
    ldx #swap_text
    int $23
wait_enter
    int $11
    cmpa #$c0
    beq begin_probe
    cmpa #13
    bne wait_enter
begin_probe
    sei
    clr profile
next_profile
    ldaa profile
    asla
    tab
    ldx #names
name_offset
    tstb
    beq name_ready
    inx
    decb
    bra name_offset
name_ready
    ldx 0,x
    int $23
    jsr probe
    jsr report
    inc profile
    ldaa profile
    cmpa #4
    bne next_profile
    ldx #done_text
    int $23
halt
    bra halt

probe
    clr error
    clr phase
    ldaa #$ff
    staa r0
    staa r8
    staa r55
    staa r41
    staa r58
    ldx #r7
    ldab #8
clear_reply
    staa 0,x
    inx
    decb
    bne clear_reply
    clr version2
    ldx #parameters
    ldab profile
parameter_offset
    tstb
    beq parameters_ready
    inx
    inx
    inx
    decb
    bra parameter_offset
parameters_ready
    ldaa 0,x
    staa SPI_DIV
    ldaa 1,x
    staa clocks
    ldab 2,x
    ldaa #$23
    staa SPI_CTL
    jsr spi_read
    ldaa PAL_TICK
power_delay
    jsr wait_tick
    tst error
    bne probe_done
    decb
    bne power_delay
    ldaa #1
    staa phase
    jsr deadline
try_reset
    ldab clocks
initial_clocks
    jsr spi_read
    decb
    bne initial_clocks
    jsr clear_arg
    ldaa #$40
    staa command
    ldaa #$95
    staa crc
    jsr send_command
    staa r0
    cmpa #1
    beq reset_ok
    jsr retry
    tst error
    bne probe_done
    tst ticks
    bne try_reset
probe_done
    jmp release
reset_ok
    ldaa #2
    staa phase
    jsr deadline
try_interface
    jsr clear_arg
    ldaa #$48
    staa command
    ldaa #1
    staa arg+2
    ldaa #$aa
    staa arg+3
    ldaa #$87
    staa crc
    jsr send_command
    staa r8
    cmpa #$ff
    bne interface_reply
    jsr retry
    tst error
    bne probe_done
    tst ticks
    bne try_interface
    bra probe_done
interface_reply
    cmpa #5
    beq app_start
    cmpa #1
    bne protocol_error
    ldx #r7
    jsr read_four
    ldaa r7
    oraa r7+1
    bne bad_pattern
    ldaa r7+2
    cmpa #1
    bne bad_pattern
    ldaa r7+3
    cmpa #$aa
    bne bad_pattern
    inc version2
app_start
    ldaa #3
    staa phase
    jsr deadline
try_app
    jsr clear_arg
    ldaa #$77
    staa command
    jsr send_command
    staa r55
    cmpa #$ff
    beq app_retry
    cmpa #1
    bhi protocol_error
    jsr clear_arg
    tst version2
    beq app_argument
    ldaa #$40
    staa arg
app_argument
    ldaa #$69
    staa command
    jsr send_command
    staa r41
    tsta
    beq app_ready
    cmpa #1
    beq app_retry
    cmpa #$ff
    bne protocol_error
app_retry
    jsr retry
    tst error
    bne probe_done_far
    tst ticks
    bne try_app
probe_done_far
    jmp probe_done
bad_pattern
    ldaa #3
    staa error
    bra probe_done_far
protocol_error
    ldaa #4
    staa error
    bra probe_done_far
app_ready
    ldaa #4
    staa phase
    jsr clear_arg
    ldaa #$7a
    staa command
    jsr send_command
    staa r58
    tsta
    bne probe_done_far
    ldx #ocr
    jsr read_four
    ldaa ocr
    bita #$80
    beq protocol_error
    jmp probe_done
read_four
    ldab #4
read_four_loop
    jsr spi_read
    staa 0,x
    inx
    decb
    bne read_four_loop
    rts

clear_arg
    clr arg
    clr arg+1
    clr arg+2
    clr arg+3
    ldaa #1
    staa crc
    rts
send_command
    jsr release
    ldaa #$21
    staa SPI_CTL
    jsr spi_read
    ldaa command
    jsr spi
    ldx #arg
    ldab #4
send_arg
    ldaa 0,x
    jsr spi
    inx
    decb
    bne send_arg
    ldaa crc
    jsr spi
    ldab #32
response
    jsr spi_read
    bpl response_done
    decb
    bne response
    ldaa #$ff
response_done
    rts
release
    ldaa #$23
    staa SPI_CTL
    jmp spi_read
spi_read
    ldaa #$ff
spi
    tst error
    bne spi_failed
    staa SPI_DATA
    pshb
    clrb
spi_wait
    ldaa SPI_CTL
    staa io
    bmi spi_ready
    decb
    bne spi_wait
    inc error
spi_ready
    pulb
    tst error
    bne spi_failed
    ldaa SPI_DATA
    rts
spi_failed
    ldaa #$ff
    rts
deadline
    ldaa PAL_TICK
    ldaa #101
    staa ticks
    rts
retry
    jsr release
    jsr wait_tick
    dec ticks
    rts
wait_tick
    stx tick_x
    ldx #0
tick_poll
    ldaa PAL_TICK
    bmi tick_seen
    dex
    bne tick_poll
    ldaa #2
    staa error
tick_seen
    ldx tick_x
    rts

report
    ldx #ph_text
    int $23
    ldaa phase
    jsr hex
    ldx #c0_text
    int $23
    ldaa r0
    jsr hex
    ldx #c8_text
    int $23
    ldaa r8
    jsr hex
    ldx #c55_text
    int $23
    ldaa r55
    jsr hex
    ldx #c41_text
    int $23
    ldaa r41
    jsr hex
    ldx #c58_text
    int $23
    ldaa r58
    jsr hex
    ldx #error_text
    int $23
    ldaa error
    jsr hex
    ldx #io_text
    int $23
    ldaa io
    jsr hex
    ldaa phase
    cmpa #2
    bcs report_end
    ldx #r7_text
    int $23
    ldx #r7
    jsr hex_four
    ldx #ocr_text
    int $23
    ldx #ocr
    jsr hex_four
report_end
    ldx #newline
    int $23
    rts
hex_four
    stx print_x
    ldaa #4
    staa print_left
hex_four_loop
    ldx print_x
    ldaa 0,x
    inx
    stx print_x
    jsr hex
    dec print_left
    bne hex_four_loop
    rts
hex
    psha
    lsra
    lsra
    lsra
    lsra
    jsr nibble
    pula
    anda #15
nibble
    adda #'0'
    cmpa #'9'
    bls digit
    adda #7
digit
    int $22
    rts
intro db 13,10,'SDPROBE: read-only SPI test',13,10,0
swap_text db 'Replace SD with test card; press ENTER.',13,10
    db 'Power OFF to leave; no DOS return.',13,10,0
done_text db 'SDPROBE DONE - POWER OFF',13,10,0
ph_text db ' PH=',0
c0_text db ' C0=',0
c8_text db ' C8=',0
c55_text db 13,10,' C55=',0
c41_text db ' C41=',0
c58_text db ' C58=',0
error_text db ' E=',0
io_text db ' IO=',0
r7_text db 13,10,' R7=',0
ocr_text db ' OCR=',0
newline db 13,10,0
name400 db '400k',0
name200 db '200k',0
name100 db '100k',0
name_long db '100k+',0
names dw name400,name200,name100,name_long
; 24 MHz / (2 * (divider + 1)); startup bytes; PAL power-delay ticks.
parameters db 29,10,16,59,10,16,119,10,16,119,160,64
    section
profile ds 1
phase ds 1
error ds 1
io ds 1
version2 ds 1
clocks ds 1
ticks ds 1
command ds 1
crc ds 1
arg ds 4
r0 ds 1
r8 ds 1
r55 ds 1
r41 ds 1
r58 ds 1
r7 ds 4
ocr ds 4
tick_x ds 2
print_x ds 2
print_left ds 1
    ends
    end start
