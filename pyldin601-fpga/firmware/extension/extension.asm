; FPGA extension ROM, page B in the first ROM bank. MC6800 disk API.
; Original INT 17 ABI: A=0 reset,80 init,FF motor tick,1 read,2 write,
; 3 seek/read ID,4 format; bit7 double-step has no meaning on an SD card.
; X: drive,track,head,sector,buffer (big-endian word at +4).
; Native ROM/RAM-disk drivers own BF80-BF84, despite the BIOS memory map
; calling BF80-BF9F reserved. SD state uses only BF85-BF9F. Temporary state
; replaces the old FDC variables ED61-ED7B and free ED7E-ED7F; the pseudo-RS
; flag ED7C and line-input limit ED7D must also remain untouched.
SPI_DATA equ $e661
SPI_CTL equ $e662
SPI_DIV equ $e663
SD_INFO equ $e6a2
SWIA equ $06
SWIB equ $05
SYS_LINE equ $ed20
FDDPARMS equ $ed26
TABLE equ $bf85
INIT_BUF equ $bf9d
FORMAT_LEFT equ $bf9f
SAVED_SP equ $ed7e
BUF equ $ed61
COUNT equ $ed63
ARG equ $ed65
LBA equ $ed69
CMD equ $ed6d
STATUS equ $ed6e
CRC equ $ed6f
CRCPTR equ $ed71
DRIVE equ $ed73
PARAM equ $ed75
OP equ $ed77
FILL equ $ed78
TRACK equ $ed79
HEAD equ $ed7a
SECTOR equ $ed7b
    org $c000
    dw $a55a
    db "FPGABIOS"
    jmp init
    jmp version
    db $17
    dw int17
    db $e0
    dw services
    db 0
version
    rts
init
    sei
    ; Allocate a temporary sector on the caller's stack; never reserve a DOS
    ; heap buffer or overwrite the existing keyboard/display work areas.
    sts SAVED_SP
    sts INIT_BUF
    ldaa INIT_BUF
    suba #2
    staa INIT_BUF
    lds INIT_BUF
    tsx
    stx INIT_BUF
    stx BUF
    ldx #TABLE
init_clear
    clr 0,x
    inx
    cpx #TABLE+24
    beq ext_skip_1
    jmp init_clear
ext_skip_1
    clr LBA
    clr LBA+1
    clr LBA+2
    clr LBA+3
    clr OP
    jsr sector_read
    tst STATUS
    beq ext_skip_2
    jmp init_done
ext_skip_2
    ldx INIT_BUF
    ; Signature is at +510, outside the MC6800 indexed range.
    ldaa INIT_BUF
    adda #1
    staa BUF
    ldaa INIT_BUF+1
    staa BUF+1
    ldx BUF
    ldaa 254,x
    cmpa #$55
    beq ext_skip_3
    jmp init_done
ext_skip_3
    ldaa 255,x
    cmpa #$aa
    beq ext_skip_4
    jmp init_done
ext_skip_4
    ldx INIT_BUF
    stx BUF
    ; MBR partition 2 and 3, not the boot filesystem in partition 1.
    ldaa INIT_BUF+1
    adda #$ce
    staa PARAM+1
    ldaa INIT_BUF
    adca #1
    staa PARAM
    ldx #TABLE
    stx DRIVE
    jsr partition
    ldaa PARAM+1
    adda #16
    staa PARAM+1
    ldaa PARAM
    adca #0
    staa PARAM
    ldx #TABLE+12
    stx DRIVE
    jsr partition
    ; Check both before reading BPBs, which overwrite the MBR sector.
    jsr partition_bounds
    ldx #TABLE
    stx DRIVE
    jsr geometry
    ldx #TABLE+12
    stx DRIVE
    jsr geometry
init_done
    jsr release
    lds SAVED_SP
    rts
; Copy the LE MBR start/count; reject a missing/non-FAT12 partition or wrap.
partition
    ldx PARAM
    ldaa 4,x
    cmpa #1
    beq ext_skip_5
    jmp partition_bad
ext_skip_5
    ldaa 8,x
    staa LBA
    ldaa 9,x
    staa LBA+1
    ldaa 10,x
    staa LBA+2
    ldaa 11,x
    staa LBA+3
    oraa LBA
    oraa LBA+1
    oraa LBA+2
    bne ext_skip_6
    jmp partition_bad
ext_skip_6
    ldx DRIVE
    ldaa LBA
    staa 0,x
    ldaa LBA+1
    staa 1,x
    ldaa LBA+2
    staa 2,x
    ldaa LBA+3
    staa 3,x
    ldx PARAM
    ldaa 12,x
    staa ARG
    ldaa 13,x
    staa ARG+1
    ldaa 14,x
    staa ARG+2
    ldaa 15,x
    staa ARG+3
    oraa ARG
    oraa ARG+1
    oraa ARG+2
    bne ext_skip_7
    jmp partition_bad
ext_skip_7
    ldaa LBA
    adda ARG
    ldaa LBA+1
    adca ARG+1
    ldaa LBA+2
    adca ARG+2
    ldaa LBA+3
    adca ARG+3
    bcc ext_skip_8
    jmp partition_bad
ext_skip_8
    ldx DRIVE
    ldaa ARG
    staa 4,x
    ldaa ARG+1
    staa 5,x
    ldaa ARG+2
    staa 6,x
    ldaa ARG+3
    staa 7,x
    inc 11,x
partition_bad
    rts
; The data partitions may not alias the boot partition or each other.
; Keep all comparisons 32-bit, including an MBR edited after boot.
partition_bounds
    ldaa INIT_BUF+1
    adda #$be
    staa PARAM+1
    ldaa INIT_BUF
    adca #1
    staa PARAM
    ldx PARAM
    ldaa 4,x
    cmpa #6
    beq bounds_boot_type
    jmp bounds_bad
bounds_boot_type
    ldaa 8,x
    oraa 9,x
    oraa 10,x
    oraa 11,x
    bne bounds_boot_start
    jmp bounds_bad
bounds_boot_start
    ldaa 12,x
    oraa 13,x
    oraa 14,x
    oraa 15,x
    bne bounds_boot_size
    jmp bounds_bad
bounds_boot_size
    ldaa 8,x
    adda 12,x
    staa ARG
    ldaa 9,x
    adca 13,x
    staa ARG+1
    ldaa 10,x
    adca 14,x
    staa ARG+2
    ldaa 11,x
    adca 15,x
    staa ARG+3
    bcc bounds_boot_end
    jmp bounds_bad
bounds_boot_end
    ldx #TABLE
    jsr after_boot
    ldx #TABLE+12
    jsr after_boot
    tst TABLE+11
    beq bounds_return
    tst TABLE+23
    beq bounds_return
    ldx #TABLE
    jsr partition_end
    ldx #TABLE+12
    jsr after_end
    bcc bounds_return
    jsr partition_end
    ldx #TABLE
    jsr after_end
    bcc bounds_return
bounds_bad
    clr TABLE+11
    clr TABLE+23
bounds_return
    rts
after_boot
    ldaa 0,x
    suba ARG
    ldaa 1,x
    sbca ARG+1
    ldaa 2,x
    sbca ARG+2
    ldaa 3,x
    sbca ARG+3
    bcc bounds_return
    clr 11,x
    rts
partition_end
    ldaa 0,x
    adda 4,x
    staa LBA
    ldaa 1,x
    adca 5,x
    staa LBA+1
    ldaa 2,x
    adca 6,x
    staa LBA+2
    ldaa 3,x
    adca 7,x
    staa LBA+3
    rts
after_end
    ldaa 0,x
    suba LBA
    ldaa 1,x
    sbca LBA+1
    ldaa 2,x
    sbca LBA+2
    ldaa 3,x
    sbca LBA+3
    rts
; Read a partition boot sector, validate BPB and narrow to the original ABI.
geometry
    ldx DRIVE
    tst 11,x
    bne ext_skip_9
    jmp geometry_done
ext_skip_9
    ldaa 0,x
    staa LBA
    ldaa 1,x
    staa LBA+1
    ldaa 2,x
    staa LBA+2
    ldaa 3,x
    staa LBA+3
    ldx INIT_BUF
    stx BUF
    jsr sector_read
    tst STATUS
    beq ext_skip_10
    jmp geometry_bad
ext_skip_10
    ; Check the complete sector signature, accepting the native A5/5A form.
    ldaa INIT_BUF
    adda #1
    staa BUF
    ldaa INIT_BUF+1
    staa BUF+1
    ldx BUF
    ldaa 254,x
    cmpa #$55
    beq geometry_pc_signature
    cmpa #$a5
    beq geometry_native_signature
    jmp geometry_bad
geometry_pc_signature
    ldaa 255,x
    cmpa #$aa
    beq geometry_signature_ok
    jmp geometry_bad
geometry_native_signature
    ldaa 255,x
    cmpa #$5a
    beq geometry_signature_ok
    jmp geometry_bad
geometry_signature_ok
    ldx INIT_BUF
    ldaa 13,x
    bne geometry_cluster_nonzero
    jmp geometry_bad
geometry_cluster_nonzero
    deca
    anda 13,x
    beq geometry_cluster_power
    jmp geometry_bad
geometry_cluster_power
    ldaa 14,x
    oraa 15,x
    bne geometry_reserved
    jmp geometry_bad
geometry_reserved
    ldaa 16,x
    beq geometry_bad_jump
    cmpa #2
    bhi geometry_bad_jump
    ldaa 17,x
    oraa 18,x
    beq geometry_bad_jump
    ldaa 22,x
    oraa 23,x
    bne geometry_fat_ok
geometry_bad_jump
    jmp geometry_bad
geometry_fat_ok
    tst 11,x
    beq ext_skip_11
    jmp geometry_bad
ext_skip_11
    ldaa 12,x
    cmpa #2
    beq ext_skip_12
    jmp geometry_bad
ext_skip_12
    tst 25,x
    beq ext_skip_13
    jmp geometry_bad
ext_skip_13
    ldaa 24,x
    bne ext_skip_14
    jmp geometry_bad
ext_skip_14
    staa SECTOR
    tst 27,x
    beq ext_skip_15
    jmp geometry_bad
ext_skip_15
    ldaa 26,x
    bne ext_skip_16
    jmp geometry_bad
ext_skip_16
    cmpa #2
    bls ext_skip_17
    jmp geometry_bad
ext_skip_17
    staa HEAD
    ; The classic INT17 ABI uses a 16-bit relative sector range.
    ldaa 19,x
    staa ARG
    ldaa 20,x
    staa ARG+1
    oraa ARG
    bne ext_skip_18
    jmp geometry_bad
ext_skip_18
    clr ARG+2
    clr ARG+3
    ldx DRIVE
    ldaa 4,x
    suba ARG
    ldaa 5,x
    sbca ARG+1
    ldaa 6,x
    sbca #0
    ldaa 7,x
    sbca #0
    bcc ext_skip_19
    jmp geometry_bad
ext_skip_19
    ldaa ARG
    staa 4,x
    ldaa ARG+1
    staa 5,x
    clr 6,x
    clr 7,x
    ldaa SECTOR
    staa 8,x
    ldaa HEAD
    staa 9,x
geometry_done
    rts
geometry_bad
    ldx DRIVE
    clr 11,x
    rts
int17
    ; The BIOS timer calls FF while the card is busy. It must touch no state.
    cmpa #$ff
    beq ext_skip_20
    jmp int17_active
ext_skip_20
    rts
int17_active
    staa OP
    stx PARAM
    cmpa #$80
    bne ext_skip_21
    jmp reset_disk
ext_skip_21
    tsta
    bne ext_skip_22
    jmp reset_disk
ext_skip_22
    anda #$7f
    cmpa #4
    bls ext_skip_23
    jmp bad_address
ext_skip_23
    staa OP
    ldaa TABLE+11
    oraa TABLE+23
    bne ext_skip_24
    jmp not_ready
ext_skip_24
    ldx PARAM
    ldaa 0,x
    cmpa #1
    bls ext_skip_25
    jmp bad_address
ext_skip_25
    ldab SD_INFO
    lsrb
    andb #1
    ; Boot B swaps logical A/B exactly as the previous controller did.
    aba
    anda #1
    ldx #TABLE
    tsta
    bne ext_skip_26
    jmp drive_selected
ext_skip_26
    ldx #TABLE+12
drive_selected
    stx DRIVE
    tst 11,x
    bne ext_skip_27
    jmp not_ready
ext_skip_27
    ldx PARAM
    ldaa 1,x
    staa TRACK
    ldaa 2,x
    staa HEAD
    ldaa 3,x
    staa SECTOR
    ldx 4,x
    stx BUF
    ldaa OP
    cmpa #4
    bne ext_skip_28
    jmp format_track
ext_skip_28
    jsr address
    tst STATUS
    beq ext_skip_29
    jmp finish
ext_skip_29
    ldaa OP
    cmpa #3
    bne ext_skip_30
    jmp seek_done
ext_skip_30
    ; Honor the caller's interrupt mask. This permits 50Hz time/keyboard IRQs
    ; during slow PIO, without the old fixed artificial clock correction.
    ldaa $04
    bita #$10
    beq ext_skip_31
    jmp disk_transfer
ext_skip_31
    cli
disk_transfer
    ldaa OP
    cmpa #1
    beq ext_skip_32
    jmp write_disk
ext_skip_32
    ldaa #'R'
    jsr indicator
    jsr sector_read
    jmp finish
write_disk
    ldaa #'W'
    jsr indicator
    jsr sector_write
    jmp finish
seek_done
    ldaa TRACK
    staa SWIB
    clr STATUS
    jmp finish
reset_disk
    jsr init
    ldaa TABLE+11
    oraa TABLE+23
    bne ext_skip_33
    jmp not_ready
ext_skip_33
    clr STATUS
    jmp finish
bad_address
    ldaa #4
    staa STATUS
    jmp finish
not_ready
    ldaa #$80
    staa STATUS
finish
    sei
    jsr release
    clra
    jsr indicator
    ldaa STATUS
    staa SWIA
    rts
indicator
    ldx SYS_LINE
    staa 81,x
    rts
; CHS -> partition-relative 16-bit LBA, then bounded 32-bit physical LBA.
address
    clr STATUS
    ldx DRIVE
    ldaa HEAD
    cmpa 9,x
    bcs ext_skip_34
    jmp address_bad
ext_skip_34
    ldaa SECTOR
    bne ext_skip_35
    jmp address_bad
ext_skip_35
    cmpa 8,x
    bls ext_skip_36
    jmp address_bad
ext_skip_36
    clr LBA
    clr LBA+1
    clr LBA+2
    clr LBA+3
    ldab TRACK
    ldaa 9,x
    cmpa #2
    beq ext_skip_37
    jmp address_track
ext_skip_37
    ; Track*2+head is at most 511; do not truncate the carry.
    aslb
    rol LBA+1
address_track
    stab LBA
    ldaa LBA
    adda HEAD
    staa LBA
    ldaa LBA+1
    adca #0
    staa LBA+1
    ldaa LBA
    staa ARG
    ldaa LBA+1
    staa ARG+1
    clr LBA
    clr LBA+1
    ldab 8,x
address_multiply
    ldaa LBA
    adda ARG
    staa LBA
    ldaa LBA+1
    adca ARG+1
    staa LBA+1
    bcc ext_skip_38
    jmp address_bad
ext_skip_38
    decb
    beq ext_skip_39
    jmp address_multiply
ext_skip_39
    ldaa SECTOR
    deca
    adda LBA
    staa LBA
    ldaa LBA+1
    adca #0
    staa LBA+1
    bcc ext_skip_40
    jmp address_bad
ext_skip_40
    ; Relative LBA must be strictly below BPB total sectors.
    ldaa LBA
    suba 4,x
    ldaa LBA+1
    sbca 5,x
    bcs ext_skip_41
    jmp address_bad
ext_skip_41
    ldaa LBA
    adda 0,x
    staa LBA
    ldaa LBA+1
    adca 1,x
    staa LBA+1
    ldaa #0
    adca 2,x
    staa LBA+2
    ldaa #0
    adca 3,x
    staa LBA+3
    bcc ext_skip_42
    jmp address_bad
ext_skip_42
    rts
address_bad
    ldaa #4
    staa STATUS
    rts
format_track
    ; X+4 buffer contains C,H,R,N IDs, count at X+3. Do not write until the
    ; whole descriptor array has been checked, including all sector bounds.
    ldaa SECTOR
    bne ext_skip_43
    jmp bad_address
ext_skip_43
    staa FORMAT_LEFT
    ldx BUF
    stx CRCPTR
format_validate
    jsr format_id
    tst STATUS
    beq ext_skip_44
    jmp finish
ext_skip_44
    ldx CRCPTR
    inx
    inx
    inx
    inx
    stx CRCPTR
    dec FORMAT_LEFT
    beq ext_skip_45
    jmp format_validate
ext_skip_45
    ldx PARAM
    ldaa 3,x
    staa FORMAT_LEFT
    ldx 4,x
    stx BUF
    ldx FDDPARMS
    ldaa 7,x
    staa FILL
    ldaa #'F'
    jsr indicator
format_next
    ldx BUF
    stx CRCPTR
    jsr format_id
    tst STATUS
    beq ext_skip_46
    jmp finish
ext_skip_46
    jsr sector_write
    tst STATUS
    beq ext_skip_47
    jmp finish
ext_skip_47
    ldx BUF
    inx
    inx
    inx
    inx
    stx BUF
    dec FORMAT_LEFT
    beq ext_skip_48
    jmp format_next
ext_skip_48
    jmp finish
format_id
    ldx CRCPTR
    ldaa 3,x
    cmpa #2
    beq ext_skip_49
    jmp address_bad
ext_skip_49
    ldaa 0,x
    staa TRACK
    ldaa 1,x
    staa HEAD
    ldaa 2,x
    staa SECTOR
    jmp address
; Ready polling is bounded even with a missing card or stalled byte shifter.
spi
    staa SPI_DATA
    pshb
    ldab #0
spi_wait
    ldaa SPI_CTL
    bpl ext_skip_50
    jmp spi_ready
ext_skip_50
    decb
    beq ext_skip_51
    jmp spi_wait
ext_skip_51
    pulb
    sec
    rts
spi_ready
    pulb
    ldaa SPI_DATA
    clc
    rts
spi_read
    ldaa #$ff
    jmp spi
release
    ldaa #$23
    staa SPI_CTL
    jmp spi_read
command
    jsr release
    ldaa #0
    staa SPI_DIV
    ldaa #$21
    staa SPI_CTL
    jsr spi_read
    bcc ext_skip_52
    jmp timeout
ext_skip_52
    ; A warm reset may leave the card programming a previously accepted block.
    ; Wait for the complete ready byte before issuing the next command.
    ldx #$ffff
    stx COUNT
command_idle
    jsr spi_read
    bcs command_idle_failed
    cmpa #$ff
    beq command_idle_ready
    ldx COUNT
    dex
    stx COUNT
    bne command_idle
command_idle_failed
    jmp timeout
command_idle_ready
    ldaa CMD
    jsr spi
    bcc ext_skip_53
    jmp timeout
ext_skip_53
    ldaa ARG+3
    jsr spi
    bcc ext_skip_54
    jmp timeout
ext_skip_54
    ldaa ARG+2
    jsr spi
    bcc ext_skip_55
    jmp timeout
ext_skip_55
    ldaa ARG+1
    jsr spi
    bcc ext_skip_56
    jmp timeout
ext_skip_56
    ldaa ARG
    jsr spi
    bcc ext_skip_57
    jmp timeout
ext_skip_57
    ldaa #1
    jsr spi
    bcc ext_skip_58
    jmp timeout
ext_skip_58
    ldab #32
command_poll
    jsr spi_read
    bcc ext_skip_59
    jmp timeout
ext_skip_59
    bmi ext_skip_60
    jmp command_ready
ext_skip_60
    decb
    beq ext_skip_61
    jmp command_poll
ext_skip_61
    jmp timeout
command_ready
    rts
prepare
    clr STATUS
    ldaa LBA
    staa ARG
    ldaa LBA+1
    staa ARG+1
    ldaa LBA+2
    staa ARG+2
    ldaa LBA+3
    staa ARG+3
    ldaa SD_INFO
    bita #1
    beq ext_skip_62
    jmp prepared
ext_skip_62
    ; SDSC CMD argument is a byte address: reject the 32-bit shift overflow.
    ldaa ARG+3
    beq ext_skip_63
    jmp prepare_bad
ext_skip_63
    ldaa ARG+2
    bpl ext_skip_64
    jmp prepare_bad
ext_skip_64
    ldab #9
prepare_shift
    asl ARG
    rol ARG+1
    rol ARG+2
    rol ARG+3
    decb
    beq ext_skip_65
    jmp prepare_shift
ext_skip_65
prepared
    ldx #512
    stx COUNT
    clr CRC
    clr CRC+1
    rts
prepare_bad
    jmp address_bad
sector_read
    jsr prepare
    tst STATUS
    beq ext_skip_66
    jmp sector_return
ext_skip_66
    ldaa #$51
    staa CMD
    jsr command
    tst STATUS
    beq ext_skip_67
    jmp sector_return
ext_skip_67
    tsta
    beq ext_skip_68
    jmp io_error
ext_skip_68
    ldx #$ffff
    stx COUNT
read_token
    jsr spi_read
    bcc ext_skip_69
    jmp timeout
ext_skip_69
    cmpa #$fe
    bne ext_skip_70
    jmp read_start
ext_skip_70
    cmpa #$ff
    beq ext_skip_71
    jmp io_error
ext_skip_71
    ldx COUNT
    dex
    stx COUNT
    beq ext_skip_72
    jmp read_token
ext_skip_72
    jmp timeout
read_start
    ldx #512
    stx COUNT
read_byte
    jsr spi_read
    bcc ext_skip_73
    jmp timeout
ext_skip_73
    ldx BUF
    staa 0,x
    inx
    stx BUF
    jsr crc_byte
    ldx COUNT
    dex
    stx COUNT
    beq ext_skip_74
    jmp read_byte
ext_skip_74
    ; Restore the beginning so callers can use the sector after return.
    ldaa BUF
    suba #2
    staa BUF
    jsr spi_read
    bcc ext_skip_75
    jmp timeout
ext_skip_75
    cmpa CRC
    beq ext_skip_76
    jmp crc_error
ext_skip_76
    jsr spi_read
    bcc ext_skip_77
    jmp timeout
ext_skip_77
    cmpa CRC+1
    beq ext_skip_78
    jmp crc_error
ext_skip_78
sector_return
    rts
sector_write
    jsr prepare
    tst STATUS
    beq ext_skip_79
    jmp sector_return
ext_skip_79
    ldaa #$58
    staa CMD
    jsr command
    tst STATUS
    beq ext_skip_80
    jmp sector_return
ext_skip_80
    tsta
    beq ext_skip_81
    jmp io_error
ext_skip_81
    ldx #512
    stx COUNT
    ldaa #$ff
    jsr spi
    bcc ext_skip_82
    jmp timeout
ext_skip_82
    ldaa #$fe
    jsr spi
    bcc ext_skip_83
    jmp timeout
ext_skip_83
    ldx BUF
    stx CRCPTR
write_byte
    ldaa OP
    cmpa #4
    bne ext_skip_84
    jmp write_fill
ext_skip_84
    ldx BUF
    ldaa 0,x
    inx
    stx BUF
    jmp write_value
write_fill
    ldaa FILL
write_value
    psha
    jsr crc_byte
    pula
    jsr spi
    bcc ext_skip_85
    jmp timeout
ext_skip_85
    ldx COUNT
    dex
    stx COUNT
    beq ext_skip_86
    jmp write_byte
ext_skip_86
    ldaa OP
    cmpa #4
    bne ext_skip_87
    jmp write_crc
ext_skip_87
    ldaa BUF
    suba #2
    staa BUF
write_crc
    ldaa CRC
    jsr spi
    bcc ext_skip_88
    jmp timeout
ext_skip_88
    ldaa CRC+1
    jsr spi
    bcc ext_skip_89
    jmp timeout
ext_skip_89
    jsr spi_read
    bcc ext_skip_90
    jmp timeout
ext_skip_90
    anda #$1f
    cmpa #5
    beq ext_skip_91
    jmp write_error
ext_skip_91
    ldx #$ffff
    stx COUNT
write_busy
    jsr spi_read
    bcc ext_skip_92
    jmp timeout
ext_skip_92
    ; A partial release byte is still busy: wait for a full FF byte.
    cmpa #$ff
    bne ext_skip_93
    jmp sector_return
ext_skip_93
    ldx COUNT
    dex
    stx COUNT
    beq ext_skip_94
    jmp write_busy
ext_skip_94
timeout
    ldaa #$80
    staa STATUS
    rts
io_error
crc_error
    ldaa #$10
    staa STATUS
    rts
write_error
    ldaa #$40
    staa STATUS
    rts
crc_byte
    eora CRC
    staa CRCPTR+1
    ldaa #/crc_hi
    staa CRCPTR
    ldx CRCPTR
    ldaa 0,x
    eora CRC+1
    staa CRC
    ldaa #/crc_lo
    staa CRCPTR
    ldx CRCPTR
    ldaa 0,x
    staa CRC+1
    rts
    include SERVICES.ASM
    include GFXCLIP.ASM
extension_end
    ds $da00-*,$ff
crc_hi
    db $00,$10,$20,$30,$40,$50,$60,$70,$81,$91,$a1,$b1,$c1,$d1,$e1,$f1
    db $12,$02,$32,$22,$52,$42,$72,$62,$93,$83,$b3,$a3,$d3,$c3,$f3,$e3
    db $24,$34,$04,$14,$64,$74,$44,$54,$a5,$b5,$85,$95,$e5,$f5,$c5,$d5
    db $36,$26,$16,$06,$76,$66,$56,$46,$b7,$a7,$97,$87,$f7,$e7,$d7,$c7
    db $48,$58,$68,$78,$08,$18,$28,$38,$c9,$d9,$e9,$f9,$89,$99,$a9,$b9
    db $5a,$4a,$7a,$6a,$1a,$0a,$3a,$2a,$db,$cb,$fb,$eb,$9b,$8b,$bb,$ab
    db $6c,$7c,$4c,$5c,$2c,$3c,$0c,$1c,$ed,$fd,$cd,$dd,$ad,$bd,$8d,$9d
    db $7e,$6e,$5e,$4e,$3e,$2e,$1e,$0e,$ff,$ef,$df,$cf,$bf,$af,$9f,$8f
    db $91,$81,$b1,$a1,$d1,$c1,$f1,$e1,$10,$00,$30,$20,$50,$40,$70,$60
    db $83,$93,$a3,$b3,$c3,$d3,$e3,$f3,$02,$12,$22,$32,$42,$52,$62,$72
    db $b5,$a5,$95,$85,$f5,$e5,$d5,$c5,$34,$24,$14,$04,$74,$64,$54,$44
    db $a7,$b7,$87,$97,$e7,$f7,$c7,$d7,$26,$36,$06,$16,$66,$76,$46,$56
    db $d9,$c9,$f9,$e9,$99,$89,$b9,$a9,$58,$48,$78,$68,$18,$08,$38,$28
    db $cb,$db,$eb,$fb,$8b,$9b,$ab,$bb,$4a,$5a,$6a,$7a,$0a,$1a,$2a,$3a
    db $fd,$ed,$dd,$cd,$bd,$ad,$9d,$8d,$7c,$6c,$5c,$4c,$3c,$2c,$1c,$0c
    db $ef,$ff,$cf,$df,$af,$bf,$8f,$9f,$6e,$7e,$4e,$5e,$2e,$3e,$0e,$1e
crc_lo
    db $00,$21,$42,$63,$84,$a5,$c6,$e7,$08,$29,$4a,$6b,$8c,$ad,$ce,$ef
    db $31,$10,$73,$52,$b5,$94,$f7,$d6,$39,$18,$7b,$5a,$bd,$9c,$ff,$de
    db $62,$43,$20,$01,$e6,$c7,$a4,$85,$6a,$4b,$28,$09,$ee,$cf,$ac,$8d
    db $53,$72,$11,$30,$d7,$f6,$95,$b4,$5b,$7a,$19,$38,$df,$fe,$9d,$bc
    db $c4,$e5,$86,$a7,$40,$61,$02,$23,$cc,$ed,$8e,$af,$48,$69,$0a,$2b
    db $f5,$d4,$b7,$96,$71,$50,$33,$12,$fd,$dc,$bf,$9e,$79,$58,$3b,$1a
    db $a6,$87,$e4,$c5,$22,$03,$60,$41,$ae,$8f,$ec,$cd,$2a,$0b,$68,$49
    db $97,$b6,$d5,$f4,$13,$32,$51,$70,$9f,$be,$dd,$fc,$1b,$3a,$59,$78
    db $88,$a9,$ca,$eb,$0c,$2d,$4e,$6f,$80,$a1,$c2,$e3,$04,$25,$46,$67
    db $b9,$98,$fb,$da,$3d,$1c,$7f,$5e,$b1,$90,$f3,$d2,$35,$14,$77,$56
    db $ea,$cb,$a8,$89,$6e,$4f,$2c,$0d,$e2,$c3,$a0,$81,$66,$47,$24,$05
    db $db,$fa,$99,$b8,$5f,$7e,$1d,$3c,$d3,$f2,$91,$b0,$57,$76,$15,$34
    db $4c,$6d,$0e,$2f,$c8,$e9,$8a,$ab,$44,$65,$06,$27,$c0,$e1,$82,$a3
    db $7d,$5c,$3f,$1e,$f9,$d8,$bb,$9a,$75,$54,$37,$16,$f1,$d0,$b3,$92
    db $2e,$0f,$6c,$4d,$aa,$8b,$e8,$c9,$26,$07,$64,$45,$a2,$83,$e0,$c1
    db $1f,$3e,$5d,$7c,$9b,$ba,$d9,$f8,$17,$36,$55,$74,$93,$b2,$d1,$f0
    checksum
    ds $e000-*,$ff
    end
