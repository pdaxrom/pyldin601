; Resident HD6303 boot BIOS. All SD/FAT work runs on the CPU.
; SPI ABI matches current HD6303 machine, relocated to E660-E664.
SPI_DATA equ $e661
SPI_CTL equ $e662
SPI_DIV equ $e663
DEBUG equ $e6a1
SIZE equ $100
REM equ $104
NAME equ $108
PART equ $114
PLEN equ $118
FATBASE equ $11c
ROOTBASE equ $120
DATABASE equ $124
LBA equ $128
ARG equ $12c
TEMP equ $130
CLUSTER equ $134
SPC equ $136
SECI equ $137
BUFP equ $138
BLEFT equ $13a
ROOTLEFT equ $13c
ENTRY equ $13e
MATCH equ $140
SAVEX equ $142
COMMAND equ $144
CHECK equ $145
RESPONSE equ $146
SDMODE equ $147
RETRY equ $148
COUNT equ $14a
CRC16 equ $14c
VOLUME equ $174
VEND equ $178
CLIMIT equ $17c
CRCPTR equ $180
SECTOR equ $800
PARTITIONS equ $150
PTR equ $80
LEFT equ $82
UI_X equ $184
UI_TEXT equ $186
UI_DEST equ $188
UI_STAGE equ $18a
UI_BLOCK equ $18b
UI_TOTAL equ $18c
VERIFY_BLOCKS equ $18d
MENU_TICKS equ $18e
MENU_KEY equ $190
SD_INIT_TICKS equ $192
SD_INIT_PHASE equ $193
SD_ERROR_VALUE equ $194
SD_ERROR_IO equ $195
MODEL equ $e6a0
    org $f000
    jmp cold_start
    jmp file_open
    jmp file_byte
    jmp failed
    jmp handoff
    jmp ui_status
    jmp ui_progress
cold_start:
    sei
    lds #$1fff
    jsr ui_init
    ldaa #$ff
    staa MENU_KEY
    clr SET_SAVING
    clr SET_LOADING
    ldaa #1
    jsr ui_status
    jsr sd_init
    ldaa #2
    jsr ui_status
    jsr mount
    jsr setup_configure
    ldaa #3
    jsr ui_status
    ldx #loader_name
    jsr file_open
    ldaa SIZE+2
    oraa SIZE+3
    lbne failed
    ldaa SIZE+1
    cmpa #$10
    lbcc failed
    staa LEFT
    ldaa SIZE
    staa LEFT+1
    oraa LEFT
    lbeq failed
    ldx #$2000
    stx PTR
copy_loader:
    jsr file_byte
    ldx PTR
    staa 0,x
    inx
    stx PTR
    ldx LEFT
    dex
    stx LEFT
    bne copy_loader
    jmp $2000
failed:
    staa SD_ERROR_VALUE
    ldaa SPI_CTL
    staa SD_ERROR_IO
    tst SET_SAVING
    lbne setup_save_failed
    tst SET_LOADING
    lbne settings_load_failed
    ; A stopped bootstrap must leave the card deselected for the next reset.
    ldaa #$23
    staa SPI_CTL
    jsr ui_error
    ldaa #$ee
    staa DEBUG
failed_stop:
    bra failed_stop
; A=outgoing byte, A=incoming byte. X/B preserved; bounded READY polling.
spi:
    staa SPI_DATA
    pshb
    ldab #0
spi_wait:
    ldaa SPI_CTL
    bmi spi_ready
    decb
    bne spi_wait
    jmp failed
spi_ready:
    pulb
    ldaa SPI_DATA
    rts
spi_read:
    ldaa #$ff
    jmp spi
release:
    ldaa #$23
    staa SPI_CTL
    jmp spi_read
; COMMAND, ARG little-endian, CHECK. Return first R1 in A, CS remains selected.
command:
    jsr command_try
    tsta
    lbmi failed
    rts
; Initialization may retry a silent card. Other callers require a valid R1.
command_try:
    jsr release
    ldaa #$21
    staa SPI_CTL
    jsr spi_read
    ldaa COMMAND
    jsr spi
    ldaa ARG+3
    jsr spi
    ldaa ARG+2
    jsr spi
    ldaa ARG+1
    jsr spi
    ldaa ARG
    jsr spi
    ldaa CHECK
    jsr spi
    ldab #32
command_poll:
    jsr spi_read
    bpl command_ready
    decb
    bne command_poll
    ldaa #$ff
command_ready:
    staa RESPONSE
    rts
clear_arg:
    clr ARG
    clr ARG+1
    clr ARG+2
    clr ARG+3
    ldaa #1
    staa CHECK
    rts
; sd_init and its timed retries reside in the boot-only D000 ROM extension.
; Read one sector at LBA into SECTOR; X/B clobbered. SDHC or SDSC addressing.
read_sector:
    ldaa LBA+0
    staa ARG+0
    ldaa LBA+1
    staa ARG+1
    ldaa LBA+2
    staa ARG+2
    ldaa LBA+3
    staa ARG+3
    ldaa SDMODE
    bne read_addressed
    ldaa ARG+3
    bne read_overflow
    ldaa ARG+2
    bmi read_overflow
    ldab #9
read_shift:
    asl ARG
    rol ARG+1
    rol ARG+2
    rol ARG+3
    decb
    bne read_shift
read_addressed:
    ldaa #$51
    staa COMMAND
    ldaa #1
    staa CHECK
    jsr command
    lbne failed
    ldx #$ffff
    stx COUNT
read_token:
    jsr spi_read
    cmpa #$fe
    beq read_data_start
    cmpa #$ff
    lbne failed
    ldx COUNT
    dex
    stx COUNT
    bne read_token
read_overflow:
    jmp failed
read_data_start:
    clr CRC16
    clr CRC16+1
    ldx #SECTOR
    stx SAVEX
    ldx #512
    stx COUNT
read_data:
    jsr spi_read
    ldx SAVEX
    staa 0,x
    eora CRC16
    staa CRCPTR+1
    ldaa #crc16_hi/256
    staa CRCPTR
    ldx CRCPTR
    ldaa 0,x
    eora CRC16+1
    staa CRC16
    ldaa #crc16_lo/256
    staa CRCPTR
    ldx CRCPTR
    ldaa 0,x
    staa CRC16+1
    ldx SAVEX
    inx
    stx SAVEX
    ldx COUNT
    dex
    stx COUNT
    bne read_data
    jsr spi_read
    cmpa CRC16
    lbne failed
    jsr spi_read
    cmpa CRC16+1
    lbne failed
    jsr release
    rts
; LBA += little-endian dword at X, preserving X. Overflow is rejected.
add_lba:
    ldaa LBA
    adda 0,x
    staa LBA
    ldaa LBA+1
    adca 1,x
    staa LBA+1
    ldaa LBA+2
    adca 2,x
    staa LBA+2
    ldaa LBA+3
    adca 3,x
    staa LBA+3
    lbcs failed
    rts
increment_lba:
    inc LBA
    bne increment_done
    inc LBA+1
    bne increment_done
    inc LBA+2
    bne increment_done
    inc LBA+3
    lbeq failed
increment_done:
    rts
mount:
    clr LBA
    clr LBA+1
    clr LBA+2
    clr LBA+3
    jsr read_sector
    jsr signature
    ldaa SECTOR+450
    cmpa #6
    beq mount_type_ok
    cmpa #$0e
    lbne failed
mount_type_ok:
    ldaa SECTOR+454+0
    staa PART+0
    ldaa SECTOR+454+1
    staa PART+1
    ldaa SECTOR+454+2
    staa PART+2
    ldaa SECTOR+454+3
    staa PART+3
    ldaa SECTOR+458+0
    staa PLEN+0
    ldaa SECTOR+458+1
    staa PLEN+1
    ldaa SECTOR+458+2
    staa PLEN+2
    ldaa SECTOR+458+3
    staa PLEN+3
    ; Save complete MBR entries for physical A/B bounds used by RAM loader.
    ldx #SECTOR+462
    stx ENTRY
    ldx #PARTITIONS
    stx MATCH
    ldab #32
mount_save_partitions:
    ldx ENTRY
    ldaa 0,x
    inx
    stx ENTRY
    ldx MATCH
    staa 0,x
    inx
    stx MATCH
    decb
    bne mount_save_partitions
    ldaa PART+0
    staa LBA+0
    ldaa PART+1
    staa LBA+1
    ldaa PART+2
    staa LBA+2
    ldaa PART+3
    staa LBA+3
    jsr read_sector
    jsr signature
    ldaa SECTOR+11
    lbne failed
    ldaa SECTOR+12
    cmpa #2
    lbne failed
    ldaa SECTOR+23
    ldab SECTOR+22
    std SET_FATSIZE
    ldaa SECTOR+16
    staa SET_FATCOPIES
    ldaa SECTOR+13
    lbeq failed
    staa SPC
    suba #1
    anda SPC
    lbne failed
    ldaa SPC
    bmi mount_bad_spc
    bra mount_spc_ok
mount_bad_spc:
    cmpa #$80
    lbne failed
mount_spc_ok:
    ldaa SECTOR+17
    ldab SECTOR+18
    staa ROOTLEFT+1
    stab ROOTLEFT
    oraa ROOTLEFT
    lbeq failed
    ldaa SECTOR+14
    staa TEMP
    ldaa SECTOR+15
    staa TEMP+1
    clr TEMP+2
    clr TEMP+3
    oraa TEMP
    lbeq failed
    ldaa PART+0
    staa LBA+0
    ldaa PART+1
    staa LBA+1
    ldaa PART+2
    staa LBA+2
    ldaa PART+3
    staa LBA+3
    ldx #TEMP
    jsr add_lba
    ldaa LBA+0
    staa FATBASE+0
    ldaa LBA+1
    staa FATBASE+1
    ldaa LBA+2
    staa FATBASE+2
    ldaa LBA+3
    staa FATBASE+3
    ldaa SECTOR+22
    staa TEMP
    ldaa SECTOR+23
    staa TEMP+1
    oraa TEMP
    lbeq failed
    ldab SECTOR+16
    lbeq failed
mount_fats:
    ldx #TEMP
    jsr add_lba
    decb
    bne mount_fats
    ldaa LBA+0
    staa ROOTBASE+0
    ldaa LBA+1
    staa ROOTBASE+1
    ldaa LBA+2
    staa ROOTBASE+2
    ldaa LBA+3
    staa ROOTBASE+3
    ; ceil(root_entries/16) sectors, then first data sector.
    ldaa ROOTLEFT+1
    adda #15
    staa TEMP
    ldaa ROOTLEFT
    adca #0
    staa TEMP+1
    clr TEMP+2
    rol TEMP+2
    ldab #4
mount_root_shift:
    lsr TEMP+2
    ror TEMP+1
    ror TEMP
    decb
    bne mount_root_shift
    ldx #TEMP
    jsr add_lba
    ldaa LBA+0
    staa DATABASE+0
    ldaa LBA+1
    staa DATABASE+1
    ldaa LBA+2
    staa DATABASE+2
    ldaa LBA+3
    staa DATABASE+3
    ; Validate FAT16 allocation bounds before trusting directory cluster numbers.
    ldaa SECTOR+19
    staa VOLUME
    ldaa SECTOR+20
    staa VOLUME+1
    clr VOLUME+2
    clr VOLUME+3
    oraa VOLUME
    bne volume_loaded
    ldaa SECTOR+32+0
    staa VOLUME+0
    ldaa SECTOR+32+1
    staa VOLUME+1
    ldaa SECTOR+32+2
    staa VOLUME+2
    ldaa SECTOR+32+3
    staa VOLUME+3
volume_loaded:
    ldaa VOLUME+3
    cmpa PLEN+3
    lbhi failed
    bcs volume_fits
    ldaa VOLUME+2
    cmpa PLEN+2
    lbhi failed
    bcs volume_fits
    ldaa VOLUME+1
    cmpa PLEN+1
    lbhi failed
    bcs volume_fits
    ldaa VOLUME+0
    cmpa PLEN+0
    lbhi failed
    bcs volume_fits
volume_fits:
    ldaa PART+0
    staa LBA+0
    ldaa PART+1
    staa LBA+1
    ldaa PART+2
    staa LBA+2
    ldaa PART+3
    staa LBA+3
    ldx #VOLUME
    jsr add_lba
    ldaa LBA+0
    staa VEND+0
    ldaa LBA+1
    staa VEND+1
    ldaa LBA+2
    staa VEND+2
    ldaa LBA+3
    staa VEND+3
    ldaa VEND+0
    suba DATABASE+0
    staa TEMP+0
    ldaa VEND+1
    sbca DATABASE+1
    staa TEMP+1
    ldaa VEND+2
    sbca DATABASE+2
    staa TEMP+2
    ldaa VEND+3
    sbca DATABASE+3
    staa TEMP+3
    lbcs failed
    ldab SPC
volume_cluster_shift:
    lsrb
    beq volume_clusters
    lsr TEMP+3
    ror TEMP+2
    ror TEMP+1
    ror TEMP
    bra volume_cluster_shift
volume_clusters:
    ldaa TEMP+3
    oraa TEMP+2
    lbne failed
    ldaa TEMP+1
    cmpa #$0f
    lbcs failed
    bne cluster_min_ok
    ldaa TEMP
    cmpa #$f5
    lbcs failed
cluster_min_ok:
    ldaa TEMP+1
    cmpa #$ff
    bne cluster_max_ok
    ldaa TEMP
    cmpa #$f5
    lbcc failed
cluster_max_ok:
    ldaa TEMP
    adda #2
    staa CLIMIT
    ldaa TEMP+1
    adca #0
    staa CLIMIT+1
    ; FAT16 capacity = sectors-per-FAT * 256 entries.
    ldaa SECTOR+23
    bne fat_capacity_ok
    ldaa CLIMIT+1
    cmpa SECTOR+22
    lbhi failed
    bcs fat_capacity_ok
    ldaa CLIMIT
    lbne failed
fat_capacity_ok:
    rts
signature:
    ldaa SECTOR+510
    cmpa #$55
    lbne failed
    ldaa SECTOR+511
    cmpa #$aa
    lbne failed
    rts
; X points to 11-byte uppercase 8.3 filename. SIZE returned little endian in RAM.
file_open:
    jsr file_find
    lbcs failed
    jmp open_found
; Optional root lookup: carry means absent; otherwise X/LBA identify the entry.
file_find:
    stx MATCH
    ldx #NAME
    stx ENTRY
    ldab #11
open_name:
    ldx MATCH
    ldaa 0,x
    inx
    stx MATCH
    ldx ENTRY
    staa 0,x
    inx
    stx ENTRY
    decb
    bne open_name
    ldaa ROOTBASE+0
    staa LBA+0
    ldaa ROOTBASE+1
    staa LBA+1
    ldaa ROOTBASE+2
    staa LBA+2
    ldaa ROOTBASE+3
    staa LBA+3
    ; Root size copied from mounted BPB is retained separately.
    jsr read_sector
    ldx #SECTOR
    stx ENTRY
open_entry:
    ldx ENTRY
    ldaa 0,x
    lbeq open_absent
    cmpa #$e5
    beq open_next
    ldaa 11,x
    bita #$18
    bne open_next
    stx SAVEX
    ldx #NAME
    stx MATCH
    ldab #11
open_compare:
    ldx MATCH
    ldaa 0,x
    inx
    stx MATCH
    ldx SAVEX
    cmpa 0,x
    bne open_next
    inx
    stx SAVEX
    decb
    bne open_compare
    ldx ENTRY
    clc
    rts
open_found:
    ldaa 20,x
    oraa 21,x
    lbne failed
    ldaa 26,x
    staa CLUSTER+1
    ldaa 27,x
    staa CLUSTER
    ldaa 28,x
    staa SIZE+0
    staa REM+0
    ldaa 29,x
    staa SIZE+1
    staa REM+1
    ldaa 30,x
    staa SIZE+2
    staa REM+2
    ldaa 31,x
    staa SIZE+3
    staa REM+3
    clr SECI
    jsr cluster_lba
    jsr read_sector
    jsr buffer_reset
    rts
open_next:
    ldx ENTRY
    ; advance to next 32-byte root entry; only 16 entries in one sector.
    ldab #32
open_advance:
    inx
    decb
    bne open_advance
    stx ENTRY
    cpx #SECTOR+512
    lbne open_entry
    jsr increment_lba
    ; Root cannot cross into data region.
    ldaa LBA+3
    cmpa DATABASE+3
    bne open_more
    ldaa LBA+2
    cmpa DATABASE+2
    bne open_more
    ldaa LBA+1
    cmpa DATABASE+1
    bne open_more
    ldaa LBA
    cmpa DATABASE
    lbeq open_absent
open_more:
    jsr read_sector
    ldx #SECTOR
    stx ENTRY
    lbra open_entry
open_absent:
    sec
    rts
buffer_reset:
    ldx #SECTOR
    stx BUFP
    ldx #512
    stx BLEFT
    rts
; Compute DATABASE+(cluster-2)*SPC+SECI into LBA.
cluster_lba:
    ldaa CLUSTER
    cmpa CLIMIT+1
    lbhi failed
    bcs cluster_in_bounds
    ldaa CLUSTER+1
    cmpa CLIMIT
    lbcc failed
cluster_in_bounds:
    ldaa CLUSTER
    cmpa #$ff
    lbcc failed
    ldaa CLUSTER+1
    suba #2
    staa TEMP
    ldaa CLUSTER
    sbca #0
    lbcs failed
    staa TEMP+1
    clr TEMP+2
    clr TEMP+3
    ldab SPC
cluster_multiply:
    lsrb
    beq cluster_multiplied
    asl TEMP
    rol TEMP+1
    rol TEMP+2
    rol TEMP+3
    bra cluster_multiply
cluster_multiplied:
    ldaa DATABASE+0
    staa LBA+0
    ldaa DATABASE+1
    staa LBA+1
    ldaa DATABASE+2
    staa LBA+2
    ldaa DATABASE+3
    staa LBA+3
    ldx #TEMP
    jsr add_lba
    ldaa SECI
    staa TEMP
    clr TEMP+1
    clr TEMP+2
    clr TEMP+3
    ldx #TEMP
    jsr add_lba
    rts
file_byte:
    ldaa REM
    oraa REM+1
    oraa REM+2
    oraa REM+3
    lbeq failed
    ldx BLEFT
    bne get_buffered
    inc SECI
    ldaa SECI
    cmpa SPC
    bcs get_sector
    ; Read FAT16 next-cluster entry; FAT sector = FATBASE+cluster high byte.
    ldaa FATBASE+0
    staa LBA+0
    ldaa FATBASE+1
    staa LBA+1
    ldaa FATBASE+2
    staa LBA+2
    ldaa FATBASE+3
    staa LBA+3
    ldaa CLUSTER
    staa TEMP
    clr TEMP+1
    clr TEMP+2
    clr TEMP+3
    ldx #TEMP
    jsr add_lba
    jsr read_sector
    ldx #SECTOR
    ldab CLUSTER+1
get_fat_offset:
    tstb
    beq get_fat_entry
    inx
    inx
    decb
    bra get_fat_offset
get_fat_entry:
    ldaa 0,x
    staa CLUSTER+1
    ldaa 1,x
    staa CLUSTER
    clr SECI
get_sector:
    jsr cluster_lba
    jsr read_sector
    jsr buffer_reset
get_buffered:
    ldx BLEFT
    dex
    stx BLEFT
    ldaa REM
    suba #1
    staa REM
    ldaa REM+1
    sbca #0
    staa REM+1
    ldaa REM+2
    sbca #0
    staa REM+2
    ldaa REM+3
    sbca #0
    staa REM+3
    ldx BUFP
    ldaa 0,x
    inx
    stx BUFP
    rts
; Never return: executing from resident ROM permits clearing all loader RAM.
; Leave an E000 trampoline; commit removes the boot ROM overlay safely there.
handoff:
    sei
    ; The loader's CRC covers bytes received from SD. Check what SRAM actually
    ; retained as well, after RAM clearing and before locking/executing ROM.
    ldaa #12
    jsr ui_status
    jsr verify_sram
    ldaa #11
    jsr ui_status
    ldx #handoff_code
    stx UI_TEXT
    ldx #$e000
    stx UI_DEST
    ldab #17
handoff_copy:
    ldx UI_TEXT
    ldaa 0,x
    inx
    stx UI_TEXT
    ldx UI_DEST
    staa 0,x
    inx
    stx UI_DEST
    decb
    bne handoff_copy
    ldaa SDMODE
    staa $e6a2
    ldx #0
    clra
handoff_clear:
    staa 0,x
    inx
    cpx #$3000
    bne handoff_clear
    jmp $e000
handoff_code:
    db $86,$a5,$b7,$e6,$a0,$b6,$e6,$a0,$2b,$02,$20,$fe,$fe,$ff,$fe,$6e,$00
loader_name:
    db "LOADER  BIN"
    org $fa00
crc16_hi:
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
crc16_lo:
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
    ; Text console uses ordinary screen RAM $0400-$07BF (40 x 24).
    ; It survives SD sector/header buffers and the loader's main RAM clear.
    ; The last handoff clear erases it just before the classic BIOS starts.
    org $fc00
ui_init:
    ldaa MODEL
    anda #1
    asla
    oraa #1
    staa $e629
    clr UI_STAGE
    ldx #$400
    ldaa #' '
ui_clear_screen:
    staa 0,x
    inx
    cpx #$7c0
    bne ui_clear_screen
    ldx #ui_crtc
    clrb
ui_crtc_write:
    stab $e600
    ldaa 0,x
    staa $e601
    inx
    incb
    cmpb #16
    bne ui_crtc_write
    ldaa MODEL
    bita #1
    beq ui_geometry_done
    ldaa #1
    staa $e600
    ldaa #80
    staa $e601
    ldaa #6
    staa $e600
    ldaa #12
    staa $e601
ui_geometry_done:
    ldx #$400
    stx UI_DEST
    ldx #ui_title
    ldaa MODEL
    bita #1
    beq ui_title_selected
    ldx #ui_title_a
ui_title_selected:
    jmp ui_puts
; A=stage. Preserve A/B/X; display stage name and retain it for failures.
ui_status:
    psha
    pshb
    stx UI_X
    staa UI_STAGE
    staa DEBUG
    ldx #$450
    jsr ui_clear_line
    ldx #$4a0
    jsr ui_clear_line
    ldx #$450
    stx UI_DEST
    ldx #ui_step
    jsr ui_puts
    ldaa UI_STAGE
    jsr ui_hex
    ldab #$3a
    jsr ui_putc
    ldab #' '
    jsr ui_putc
    ldx #ui_messages
    ldab UI_STAGE
    beq ui_message_found
ui_message_find:
    inx
    inx
    decb
    bne ui_message_find
ui_message_found:
    ldx 0,x
    jsr ui_puts
    ldx UI_X
    pulb
    pula
    rts
; A=current block, B=total blocks. Preserve A/B/X.
ui_progress:
    psha
    pshb
    stx UI_X
    staa UI_BLOCK
    stab UI_TOTAL
    ldx #$4a0
    stx UI_DEST
    ldx #ui_block_message
    jsr ui_puts
    ldaa UI_BLOCK
    jsr ui_hex
    ldab #'/'
    jsr ui_putc
    ldaa UI_TOTAL
    jsr ui_hex
    ldx UI_X
    pulb
    pula
    rts
ui_error:
    ldx #$4f0
    stx UI_DEST
    ldx #ui_error_message
    jsr ui_puts
    ldaa UI_STAGE
    jsr ui_hex
    ldx #$540
    stx UI_DEST
    ldx #ui_check_message
    jsr ui_puts
    ldx #$590
    stx UI_DEST
    ldx #ui_retry_message
    jsr ui_puts
    ldaa UI_STAGE
    cmpa #1
    bne ui_string_done
    jmp sd_error_details
ui_clear_line:
    ldaa #' '
    ldab #40
ui_clear_char:
    staa 0,x
    inx
    psha
    ldaa MODEL
    bita #1
    beq ui_clear_601
    ldaa #' '
    staa 0,x
    inx
ui_clear_601:
    pula
    decb
    bne ui_clear_char
    rts
ui_puts:
    ldab 0,x
    beq ui_string_done
    stx UI_TEXT
    jsr ui_putc
    ldx UI_TEXT
    inx
    bra ui_puts
ui_string_done:
    rts
ui_putc:
    ldx UI_DEST
    psha
    ldaa MODEL
    bita #1
    beq ui_putc_601
    clr 0,x
    inx
ui_putc_601:
    pula
    stab 0,x
    inx
    stx UI_DEST
    rts
ui_hex:
    psha
    lsra
    lsra
    lsra
    lsra
    jsr ui_nibble
    pula
ui_nibble:
    anda #$0f
    cmpa #10
    bcs ui_digit
    adda #7
ui_digit:
    adda #'0'
    tab
    jmp ui_putc
ui_crtc:
    db 63,40,46,8,38,0,24,36,0,7,$20,7,4,0,0,0
ui_title:
    db "PYLDIN-601 SYSTEM INITIALIZATION",0
ui_title_a:
    db "PYLDIN-601A SYSTEM INITIALIZATION",0
ui_step:
    db "STEP ",0
ui_block_message:
    db "BLOCK ",0
ui_error_message:
    db "BOOT ERROR AT STEP ",0
ui_check_message:
    db "CHECK SD / LOADER.BIN / P601.ROM",0
ui_retry_message:
    db "PRESS RESET TO RETRY",0
ui_messages:
    dw ui_starting,ui_sd,ui_fat,ui_loader,ui_rom,ui_header,ui_banks,ui_tail,ui_crc,ui_ram,ui_disk,ui_start,ui_sram
ui_starting:
    db "STARTING",0
ui_sd:
    db "INITIALIZING SD",0
ui_fat:
    db "READING MBR / FAT16",0
ui_loader:
    db "LOADING LOADER.BIN",0
ui_rom:
    db "OPENING SELECTED ROM",0
ui_header:
    db "CHECKING ROM HEADER",0
ui_banks:
    db "LOADING ROM BANKS",0
ui_tail:
    db "LOADING BIOS / FONT",0
ui_crc:
    db "CHECKING ROM CRC32",0
ui_ram:
    db "INITIALIZING RAM",0
ui_disk:
    db "INITIALIZING ROM DISK",0
ui_start:
    db "STARTING SELECTED BIOS",0
ui_sram:
    db "VERIFYING SRAM CRC32",0
verify_sram:
    clr $e6a4
    clr $e6a5
    ldaa #1
    staa $e6a6
    staa $e6aa
    ldaa #1
    staa VERIFY_BLOCKS
verify_bank:
    ldx #0
    jsr verify_block
    dec VERIFY_BLOCKS
    bne verify_bank
    ldx #$1800
    jsr verify_block
    ldaa $e6ac
    cmpa $1014
    lbne failed
    ldaa $e6ad
    cmpa $1015
    lbne failed
    ldaa $e6ae
    cmpa $1016
    lbne failed
    ldaa $e6af
    cmpa $1017
    lbne failed
    rts
verify_block:
    stx LEFT
verify_byte:
    clr $e6ab
verify_wait:
    ldaa $e6a8
    lbmi failed
    bita #1
    bne verify_wait
    ldaa $e6ab
    staa $e6a9
    ldx LEFT
    dex
    stx LEFT
    bne verify_byte
    rts
    org $fff8
    dw failed,failed,failed,$f000
