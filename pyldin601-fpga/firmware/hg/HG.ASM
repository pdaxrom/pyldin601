; UniDOS relocatable HG.PGM / HGTIME.PGM, classic MC6800 instructions only.
; Block-driver ABI and residency follow native-src/VDISK.601 (T. Todorov).
; Wire ABI follows uJ11 HG v1: little-endian header, XOR, additive data sum.
datareg = $e670
statusreg = $e671
controlreg = $e672
idreg = $e673
swia = 6

start
        ldaa idreg
        cmpa #'H'
        beq hardware_ok
        ldx #no_hardware
        jmp message_exit
hardware_ok
        .ifdef TIME_ONLY
        jsr sync_time
        bcs time_error
        ldx #time_ok
        jmp message_exit
time_error
        ldx #time_failed
        jmp message_exit
        .else
        ; Read BPB before registration; an absent host never installs a drive.
        ldaa #1
        staa operation
        clr block
        clr block+1
        ldx #512
        stx length
        ldx #fatbuf
        stx buffer
        jsr transfer
        bcc got_boot
        jmp mount_failed
got_boot
        ; Native header is big-endian, FAT BPB is little-endian.
        ldx fatbuf+510
        cpx #$55aa
        beq signature_ok
        cpx #$a55a
        beq signature_ok
        jmp mount_failed
signature_ok
        ldx fatbuf+11
        cpx #$0002
        beq sector_ok
        jmp mount_failed
sector_ok
        ldaa fatbuf+13
        bne spc_nonzero
        jmp bad_bpb
spc_nonzero
        cmpa #128
        bls spc_in_range
        jmp bad_bpb
spc_in_range
        staa header+16
        deca
        anda fatbuf+13
        beq spc_power_of_two
        jmp bad_bpb
spc_power_of_two
        ldaa fatbuf+14
        bne reserved_nonzero
        jmp bad_bpb
reserved_nonzero
        staa header+17
        tst fatbuf+15
        beq reserved_fits_byte
        jmp bad_bpb
reserved_fits_byte
        ldaa fatbuf+16
        bne fat_count_nonzero
        jmp bad_bpb
fat_count_nonzero
        staa header+18
        ldaa fatbuf+17
        staa header+20
        ldaa fatbuf+18
        staa header+19
        ldaa fatbuf+19
        staa header+22
        ldaa fatbuf+20
        staa header+21
        ldx header+21
        cpx #0
        beq bad_bpb
        ldaa fatbuf+21
        staa header+23
        ldaa fatbuf+22
        beq bad_bpb
        staa header+24
        tst fatbuf+23
        bne bad_bpb
        ldaa fatbuf+24
        staa header+25
        ldaa fatbuf+26
        staa header+26
        ; First free drive, preserving the current drive like VDISK.601.
        int $45
        staa old_drive
        clr drive
find_drive
        ldaa drive
        int $44
        tsta
        bne free_drive
        inc drive
        ldaa drive
        cmpa #8
        bcs find_drive
        ldaa old_drive
        int $44
        jmp mount_failed
free_drive
        ldaa old_drive
        int $44
        clrb
        ldx #header
        int $5d
        tsta
        bne mount_failed
        int $2c
        ldaa drive
        adda #'A'
        staa drive_letter
        ldx #disk_ok
        int $23
        jsr sync_time
        bcs sync_failed
        ldx #time_ok
        bra message_exit
sync_failed
        ldx #time_failed
        bra message_exit
bad_bpb
mount_failed
        ldx #disk_failed
        bra message_exit
        .endif
message_exit
        int $23
        int $38

        .ifndef TIME_ONLY
read    ldaa #1
        bra disk_io
write   ldaa #2
disk_io
        staa operation
        ldaa 3,x
        staa block
        ldaa 4,x
        staa block+1
        ldx 0,x
        stx buffer
        ldx #512
        stx length
        jsr transfer
        bcc init
        ldaa io_error
        staa swia
        rts
init    clr swia
        rts
header  dw init,read,write
        db 0
        dw fatbuf,dirbuf
        db 0,0,0
        dw 512
        db 1,1,2
        dw 512,2880
        db $f8,9,18,2
disk_ok db 'HG 1.0 remote disk '
drive_letter db 'C:',13,10,0
disk_failed db 'HG: host unavailable or invalid FAT12 disk.',13,10,0
old_drive db 0
drive db 0
dirbuf ds 66
fatbuf ds 512
        .endif

; One full-duplex byte stream. Discard RX during TX and vice versa.
; SELECT and all FIFO waits are bounded even if the daemon disappears.
transfer
        ldaa #$40
        staa io_error
        clr controlreg
        jsr wait_idle
        bcc transfer_idle
        rts
transfer_idle
        ldaa #$80
        staa controlreg
        clr sum
        clr sum+1
        ldaa operation
        staa wire_header+3
        ldaa block+1
        staa wire_header+5
        ldaa block
        staa wire_header+6
        ldaa length+1
        staa wire_header+7
        ldaa length
        staa wire_header+8
        clra
        ldx #wire_header
        ldab #9
header_xor
        eora 0,x
        inx
        decb
        bne header_xor
        staa wire_header+9
        ldx #wire_header
        ldab #10
header_send
        ldaa 0,x
        staa datareg
        inx
        decb
        bne header_send
        ldaa #5
        staa controlreg
        jsr wait_select
        bcc header_selected
        jmp transfer_error
header_selected
        ; Host collects 10 header bytes; no RX dummy bytes enter the FIFO.
        ; TX room reaches 64 after the final falling edge.
        jsr wait_tx_empty
        bcc header_drained
        jmp transfer_error
header_drained
        ldaa #3
        staa controlreg
        jsr receive_byte
        bcc status_received
        jmp transfer_error
status_received
        tsta
        beq status_ok
        jmp status_error
status_ok
        ldx buffer
        stx pointer
        ldx length
        stx remaining
        ldaa operation
        cmpa #2
        beq write_payload
read_payload
        jsr receive_byte
        bcc payload_received
        jmp transfer_error
payload_received
        ldx pointer
        staa 0,x
        inx
        stx pointer
        jsr add_sum
        jsr decrement
        bne read_payload
        jsr receive_byte
        bcc checksum_received
        jmp transfer_error
checksum_received
        cmpa sum+1
        bne checksum_error
        jsr receive_byte
        bcs transfer_error
        cmpa sum
        bne checksum_error
        bra transfer_ok
write_payload
        ldaa #5
        staa controlreg
write_next
        ldx pointer
        ldaa 0,x
        jsr send_byte
        bcs transfer_error
        jsr add_sum
        ldx pointer
        inx
        stx pointer
        jsr decrement
        bne write_next
        ldaa sum+1
        jsr send_byte
        bcs transfer_error
        ldaa sum
        jsr send_byte
        bcs transfer_error
        jsr wait_tx_empty
        bcs transfer_error
        ldaa #3
        staa controlreg
        jsr receive_byte
        bcs transfer_error
        tsta
        bne status_error
transfer_ok
        clr controlreg
        clc
        rts
checksum_error
        ldaa #4
        bra set_error
status_error
        ; Translate HG statuses to native BIOS disk-error bit masks.
        cmpa #5
        bne not_protected
        ldaa #1
        bra set_error
not_protected
        cmpa #2
        beq set_error
        cmpa #4
        beq set_error
        ldaa #8
set_error
        staa io_error
transfer_error
        clr controlreg
        sec
        rts

add_sum
        adda sum+1
        staa sum+1
        ldaa sum
        adca #0
        staa sum
        rts
decrement
        ldx remaining
        dex
        stx remaining
        rts

; STATUS bit3 is TX empty. TX-room is insufficient for
; changing direction, because the last byte can still be on the wire.
wait_tx_empty
        ldaa #8
        staa timeout
empty_outer
        ldx #0
empty_poll
        ldaa statusreg
        bita #8
        bne wait_ok
        ldaa statusreg
        bmi wait_bad
        dex
        bne empty_poll
        dec timeout
        bne empty_outer
        bra wait_bad
wait_idle
        ldaa #8
        staa timeout
idle_outer
        ldx #0
idle_poll
        ldaa statusreg
        bita #4
        beq wait_ok
        dex
        bne idle_poll
        dec timeout
        bne idle_outer
        bra wait_bad
wait_select
        ldaa #8
        staa timeout
select_outer
        ldx #0
select_poll
        ldaa statusreg
        bita #4
        bne wait_ok
        dex
        bne select_poll
        dec timeout
        bne select_outer
wait_bad
        sec
        rts
wait_ok clc
        rts
receive_byte
        ldaa #8
        staa timeout
receive_outer
        ldx #0
receive_poll
        ldaa statusreg
        bita #$c0
        bne fifo_bad
        bita #1
        bne receive_ready
        bita #4
        beq wait_bad
        dex
        bne receive_poll
        dec timeout
        bne receive_outer
        bra wait_bad
receive_ready
        ldaa datareg
        clc
        rts
send_byte
        staa output_byte
        ldaa #8
        staa timeout
send_outer
        ldx #0
send_poll
        ldaa statusreg
        bita #$c0
        bne fifo_bad
        bita #2
        bne send_ready
        bita #4
        beq wait_bad
        dex
        bne send_poll
        dec timeout
        bne send_outer
        bra wait_bad
fifo_bad
        ldaa #$10
        staa io_error
        bra wait_bad
send_ready
        ldaa output_byte
        staa datareg
        clc
        rts

; HG TIME is the identical 6-byte RT-11 date/ticks layout used by uJ11.
sync_time
        ldaa #3
        staa operation
        clr block
        ldaa #50
        staa block+1
        ldx #6
        stx length
        ldx #time_data
        stx buffer
        jsr transfer
        bcc time_received
        rts
time_received
        ; year=1972+((date>>14)*32)+(date&31)
        ldaa time_data+1
        anda #$c0
        lsra
        staa year+1
        ldaa time_data
        anda #31
        adda year+1
        adda #$b4
        staa year+1
        ldaa #7
        adca #0
        staa year
        ; day=(date>>5)&31, month=(date>>10)&15
        ldaa time_data+1
        anda #3
        staa day
        ldaa time_data
        lsra
        lsra
        lsra
        lsra
        lsra
        ldab day
        aslb
        aslb
        aslb
        aba
        staa day
        ldaa time_data+1
        lsra
        lsra
        anda #15
        staa month
        ; Convert the 32-bit PAL tick count by bounded repeated subtraction.
        ldaa time_data+2
        staa ticks+1
        ldaa time_data+3
        staa ticks
        ldaa time_data+4
        staa ticks+3
        ldaa time_data+5
        staa ticks+2
        ; Reject >=24 hours; prevents malicious TIME values looping forever.
        ldaa ticks
        bne bad_ticks
        ldaa ticks+1
        cmpa #$41
        bhi bad_ticks
        bcs ticks_valid
        ldaa ticks+2
        cmpa #$eb
        bhi bad_ticks
        bcs ticks_valid
bad_ticks
        jmp invalid_time
ticks_valid
        clr hours
        clr minutes
        clr seconds
        ldx #$bf20
        stx divisor+2
        ldx #2
        stx divisor
hour_loop
        jsr subtract_ticks
        bcs hours_done
        inc hours
        bra hour_loop
hours_done
        ldx #3000
        stx divisor+2
        clr divisor
        clr divisor+1
minute_loop
        jsr subtract_ticks
        bcs minutes_done
        inc minutes
        bra minute_loop
minutes_done
        ldx #50
        stx divisor+2
second_loop
        jsr subtract_ticks
        bcs seconds_done
        inc seconds
        bra second_loop
seconds_done
        ldaa ticks+3
        asla
        staa clock_value+1
        ldaa seconds
        staa clock_value
        ; Validate the complete response before changing the native date.
        ldx year
        ldab day
        ldaa month
        int $1f
        cmpa #$ff
        beq invalid_time
        ldx clock_value
        ldaa minutes
        ldab hours
        int $1d
        cmpa #$ff
        beq invalid_time
        clc
        rts
invalid_time
        sec
        rts
subtract_ticks
        ldaa ticks+3
        suba divisor+3
        staa temporary+3
        ldaa ticks+2
        sbca divisor+2
        staa temporary+2
        ldaa ticks+1
        sbca divisor+1
        staa temporary+1
        ldaa ticks
        sbca divisor
        bcs subtract_return
        staa ticks
        ldx temporary+1
        stx ticks+1
        ldaa temporary+3
        staa ticks+3
subtract_return
        rts

no_hardware db 'HG: FPGA has no HG interface.',13,10,0
time_ok db 'HG: host date/time synchronized.',13,10,0
time_failed db 'HG: host time unavailable.',13,10,0
wire_header db 'HG',1,1,0,0,0,0,2,0
operation db 0
block dw 0
length dw 0
buffer dw 0
pointer dw 0
remaining dw 0
sum dw 0
timeout db 0
output_byte db 0
io_error db 0
time_data ds 6
year dw 0
month db 0
day db 0
ticks ds 4
divisor ds 4
temporary ds 4
hours db 0
minutes db 0
seconds db 0
clock_value dw 0
