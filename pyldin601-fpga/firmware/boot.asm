; Resident HD6303 boot BIOS. All SD/FAT work runs on the CPU.
; SPI ABI matches current HD6303 machine, relocated to E660-E664.
B_SPI_DATA equ $e661
B_SPI_CTL equ $e662
B_SPI_DIV equ $e663
B_DEBUG equ $e6a1
B_SIZE equ $100
B_REM equ $104
B_NAME equ $108
B_PART equ $114
B_PLEN equ $118
B_FATBASE equ $11c
B_ROOTBASE equ $120
B_DATABASE equ $124
B_LBA equ $128
B_ARG equ $12c
B_TEMP equ $130
B_CLUSTER equ $134
B_SPC equ $136
B_SECI equ $137
B_BUFP equ $138
B_BLEFT equ $13a
B_ROOTLEFT equ $13c
B_ENTRY equ $13e
B_MATCH equ $140
B_SAVEX equ $142
B_COMMAND equ $144
B_CHECK equ $145
B_RESPONSE equ $146
B_SDMODE equ $147
B_RETRY equ $148
B_COUNT equ $14a
B_CRC16 equ $14c
B_VOLUME equ $174
B_VEND equ $178
B_CLIMIT equ $17c
B_CRCPTR equ $180
B_SECTOR equ $800
B_PARTITIONS equ $150
B_PTR equ $80
B_LEFT equ $82
B_UI_X equ $184
B_UI_TEXT equ $186
B_UI_DEST equ $188
B_UI_STAGE equ $18a
B_UI_BLOCK equ $18b
B_UI_TOTAL equ $18c
B_VERIFY_BLOCKS equ $18d
B_MENU_TICKS equ $18e
B_MENU_KEY equ $190
B_SD_INIT_TICKS equ $192
B_SD_INIT_PHASE equ $193
B_SD_ERROR_VALUE equ $194
B_SD_ERROR_IO equ $195
B_MODEL equ $e6a0
    org $f000
    jmp cold_start
    jmp file_open
    jmp file_byte
    jmp failed
    jmp handoff
    jmp ui_status
    jmp ui_progress
cold_start
    sei
    lds #$1fff
    jsr boot_keyboard_init
    jsr ui_init
    ldaa #$ff
    staa B_MENU_KEY
    clr B_SET_SAVING
    clr B_SET_LOADING
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
    ldaa B_SIZE+2
    oraa B_SIZE+3
    beq long_branch_1
    jmp failed
long_branch_1
    ldaa B_SIZE+1
    cmpa #$10
    bcs long_branch_2
    jmp failed
long_branch_2
    staa B_LEFT
    ldaa B_SIZE
    staa B_LEFT+1
    oraa B_LEFT
    bne long_branch_3
    jmp failed
long_branch_3
    ldx #$2000
    stx B_PTR
copy_loader
    jsr file_byte
    ldx B_PTR
    staa 0,x
    inx
    stx B_PTR
    ldx B_LEFT
    dex
    stx B_LEFT
    bne copy_loader
    jmp $2000
failed
    staa B_SD_ERROR_VALUE
    ldaa B_SPI_CTL
    staa B_SD_ERROR_IO
    tst B_SET_SAVING
    beq long_branch_4
    jmp setup_save_failed
long_branch_4
    tst B_SET_LOADING
    beq long_branch_5
    jmp settings_load_failed
long_branch_5
    ; A stopped bootstrap must leave the card deselected for the next reset.
    ldaa #$23
    staa B_SPI_CTL
    jsr ui_error
    ldaa #$ee
    staa B_DEBUG
failed_stop
    bra failed_stop
; A=outgoing byte, A=incoming byte. X/B preserved; bounded READY polling.
spi
    staa B_SPI_DATA
    pshb
    ldab #0
spi_wait
    ldaa B_SPI_CTL
    bmi spi_ready
    decb
    bne spi_wait
    jmp failed
spi_ready
    pulb
    ldaa B_SPI_DATA
    rts
spi_read
    ldaa #$ff
    jmp spi
release
    ldaa #$23
    staa B_SPI_CTL
    jmp spi_read
; B_COMMAND, B_ARG little-endian, B_CHECK. Return first R1 in A, CS remains selected.
command
    jsr command_try
    tsta
    bpl long_branch_6
    jmp failed
long_branch_6
    rts
; Initialization may retry a silent card. Other callers require a valid R1.
command_try
    jsr release
    ldaa #$21
    staa B_SPI_CTL
    jsr spi_read
    ldaa B_COMMAND
    jsr spi
    ldaa B_ARG+3
    jsr spi
    ldaa B_ARG+2
    jsr spi
    ldaa B_ARG+1
    jsr spi
    ldaa B_ARG
    jsr spi
    ldaa B_CHECK
    jsr spi
    ldab #32
command_poll
    jsr spi_read
    bpl command_ready
    decb
    bne command_poll
    ldaa #$ff
command_ready
    staa B_RESPONSE
    rts
clear_arg
    clr B_ARG
    clr B_ARG+1
    clr B_ARG+2
    clr B_ARG+3
    ldaa #1
    staa B_CHECK
    rts
; sd_init and its timed retries reside in the boot-only D000 ROM extension.
; Read one sector at B_LBA into B_SECTOR; X/B clobbered. SDHC or SDSC addressing.
read_sector
    ldaa B_LBA+0
    staa B_ARG+0
    ldaa B_LBA+1
    staa B_ARG+1
    ldaa B_LBA+2
    staa B_ARG+2
    ldaa B_LBA+3
    staa B_ARG+3
    ldaa B_SDMODE
    bne read_addressed
    ldaa B_ARG+3
    bne read_overflow
    ldaa B_ARG+2
    bmi read_overflow
    ldab #9
read_shift
    asl B_ARG
    rol B_ARG+1
    rol B_ARG+2
    rol B_ARG+3
    decb
    bne read_shift
read_addressed
    ldaa #$51
    staa B_COMMAND
    ldaa #1
    staa B_CHECK
    jsr command
    beq long_branch_7
    jmp failed
long_branch_7
    ldx #$ffff
    stx B_COUNT
read_token
    jsr spi_read
    cmpa #$fe
    beq read_data_start
    cmpa #$ff
    beq long_branch_8
    jmp failed
long_branch_8
    ldx B_COUNT
    dex
    stx B_COUNT
    bne read_token
read_overflow
    jmp failed
read_data_start
    clr B_CRC16
    clr B_CRC16+1
    ldx #B_SECTOR
    stx B_SAVEX
    ldx #512
    stx B_COUNT
read_data
    jsr spi_read
    ldx B_SAVEX
    staa 0,x
    eora B_CRC16
    staa B_CRCPTR+1
    ldaa #crc16_hi/256
    staa B_CRCPTR
    ldx B_CRCPTR
    ldaa 0,x
    eora B_CRC16+1
    staa B_CRC16
    ldaa #crc16_lo/256
    staa B_CRCPTR
    ldx B_CRCPTR
    ldaa 0,x
    staa B_CRC16+1
    ldx B_SAVEX
    inx
    stx B_SAVEX
    ldx B_COUNT
    dex
    stx B_COUNT
    bne read_data
    jsr spi_read
    cmpa B_CRC16
    beq long_branch_9
    jmp failed
long_branch_9
    jsr spi_read
    cmpa B_CRC16+1
    beq long_branch_10
    jmp failed
long_branch_10
    jsr release
    rts
; B_LBA += little-endian dword at X, preserving X. Overflow is rejected.
add_lba
    ldaa B_LBA
    adda 0,x
    staa B_LBA
    ldaa B_LBA+1
    adca 1,x
    staa B_LBA+1
    ldaa B_LBA+2
    adca 2,x
    staa B_LBA+2
    ldaa B_LBA+3
    adca 3,x
    staa B_LBA+3
    bcc long_branch_11
    jmp failed
long_branch_11
    rts
increment_lba
    inc B_LBA
    bne increment_done
    inc B_LBA+1
    bne increment_done
    inc B_LBA+2
    bne increment_done
    inc B_LBA+3
    bne long_branch_12
    jmp failed
long_branch_12
increment_done
    rts
mount
    clr B_LBA
    clr B_LBA+1
    clr B_LBA+2
    clr B_LBA+3
    jsr read_sector
    jsr signature
    ldaa B_SECTOR+450
    cmpa #6
    beq mount_type_ok
    cmpa #$0e
    beq long_branch_13
    jmp failed
long_branch_13
mount_type_ok
    ldaa B_SECTOR+454+0
    staa B_PART+0
    ldaa B_SECTOR+454+1
    staa B_PART+1
    ldaa B_SECTOR+454+2
    staa B_PART+2
    ldaa B_SECTOR+454+3
    staa B_PART+3
    ldaa B_SECTOR+458+0
    staa B_PLEN+0
    ldaa B_SECTOR+458+1
    staa B_PLEN+1
    ldaa B_SECTOR+458+2
    staa B_PLEN+2
    ldaa B_SECTOR+458+3
    staa B_PLEN+3
    ; Save complete MBR entries for physical A/B bounds used by RAM loader.
    ldx #B_SECTOR+462
    stx B_ENTRY
    ldx #B_PARTITIONS
    stx B_MATCH
    ldab #32
mount_save_partitions
    ldx B_ENTRY
    ldaa 0,x
    inx
    stx B_ENTRY
    ldx B_MATCH
    staa 0,x
    inx
    stx B_MATCH
    decb
    bne mount_save_partitions
    ldaa B_PART+0
    staa B_LBA+0
    ldaa B_PART+1
    staa B_LBA+1
    ldaa B_PART+2
    staa B_LBA+2
    ldaa B_PART+3
    staa B_LBA+3
    jsr read_sector
    jsr signature
    ldaa B_SECTOR+11
    beq long_branch_14
    jmp failed
long_branch_14
    ldaa B_SECTOR+12
    cmpa #2
    beq long_branch_15
    jmp failed
long_branch_15
    ldaa B_SECTOR+23
    ldab B_SECTOR+22
    std B_SET_FATSIZE
    ldaa B_SECTOR+16
    staa B_SET_FATCOPIES
    ldaa B_SECTOR+13
    bne long_branch_16
    jmp failed
long_branch_16
    staa B_SPC
    suba #1
    anda B_SPC
    beq long_branch_17
    jmp failed
long_branch_17
    ldaa B_SPC
    bmi mount_bad_spc
    bra mount_spc_ok
mount_bad_spc
    cmpa #$80
    beq long_branch_18
    jmp failed
long_branch_18
mount_spc_ok
    ldaa B_SECTOR+17
    ldab B_SECTOR+18
    staa B_ROOTLEFT+1
    stab B_ROOTLEFT
    oraa B_ROOTLEFT
    bne long_branch_19
    jmp failed
long_branch_19
    ldaa B_SECTOR+14
    staa B_TEMP
    ldaa B_SECTOR+15
    staa B_TEMP+1
    clr B_TEMP+2
    clr B_TEMP+3
    oraa B_TEMP
    bne long_branch_20
    jmp failed
long_branch_20
    ldaa B_PART+0
    staa B_LBA+0
    ldaa B_PART+1
    staa B_LBA+1
    ldaa B_PART+2
    staa B_LBA+2
    ldaa B_PART+3
    staa B_LBA+3
    ldx #B_TEMP
    jsr add_lba
    ldaa B_LBA+0
    staa B_FATBASE+0
    ldaa B_LBA+1
    staa B_FATBASE+1
    ldaa B_LBA+2
    staa B_FATBASE+2
    ldaa B_LBA+3
    staa B_FATBASE+3
    ldaa B_SECTOR+22
    staa B_TEMP
    ldaa B_SECTOR+23
    staa B_TEMP+1
    oraa B_TEMP
    bne long_branch_21
    jmp failed
long_branch_21
    ldab B_SECTOR+16
    bne long_branch_22
    jmp failed
long_branch_22
mount_fats
    ldx #B_TEMP
    jsr add_lba
    decb
    bne mount_fats
    ldaa B_LBA+0
    staa B_ROOTBASE+0
    ldaa B_LBA+1
    staa B_ROOTBASE+1
    ldaa B_LBA+2
    staa B_ROOTBASE+2
    ldaa B_LBA+3
    staa B_ROOTBASE+3
    ; ceil(root_entries/16) sectors, then first data sector.
    ldaa B_ROOTLEFT+1
    adda #15
    staa B_TEMP
    ldaa B_ROOTLEFT
    adca #0
    staa B_TEMP+1
    clr B_TEMP+2
    rol B_TEMP+2
    ldab #4
mount_root_shift
    lsr B_TEMP+2
    ror B_TEMP+1
    ror B_TEMP
    decb
    bne mount_root_shift
    ldx #B_TEMP
    jsr add_lba
    ldaa B_LBA+0
    staa B_DATABASE+0
    ldaa B_LBA+1
    staa B_DATABASE+1
    ldaa B_LBA+2
    staa B_DATABASE+2
    ldaa B_LBA+3
    staa B_DATABASE+3
    ; Validate FAT16 allocation bounds before trusting directory cluster numbers.
    ldaa B_SECTOR+19
    staa B_VOLUME
    ldaa B_SECTOR+20
    staa B_VOLUME+1
    clr B_VOLUME+2
    clr B_VOLUME+3
    oraa B_VOLUME
    bne volume_loaded
    ldaa B_SECTOR+32+0
    staa B_VOLUME+0
    ldaa B_SECTOR+32+1
    staa B_VOLUME+1
    ldaa B_SECTOR+32+2
    staa B_VOLUME+2
    ldaa B_SECTOR+32+3
    staa B_VOLUME+3
volume_loaded
    ldaa B_VOLUME+3
    cmpa B_PLEN+3
    bls long_branch_23
    jmp failed
long_branch_23
    bcs volume_fits
    ldaa B_VOLUME+2
    cmpa B_PLEN+2
    bls long_branch_24
    jmp failed
long_branch_24
    bcs volume_fits
    ldaa B_VOLUME+1
    cmpa B_PLEN+1
    bls long_branch_25
    jmp failed
long_branch_25
    bcs volume_fits
    ldaa B_VOLUME+0
    cmpa B_PLEN+0
    bls long_branch_26
    jmp failed
long_branch_26
    bcs volume_fits
volume_fits
    ldaa B_PART+0
    staa B_LBA+0
    ldaa B_PART+1
    staa B_LBA+1
    ldaa B_PART+2
    staa B_LBA+2
    ldaa B_PART+3
    staa B_LBA+3
    ldx #B_VOLUME
    jsr add_lba
    ldaa B_LBA+0
    staa B_VEND+0
    ldaa B_LBA+1
    staa B_VEND+1
    ldaa B_LBA+2
    staa B_VEND+2
    ldaa B_LBA+3
    staa B_VEND+3
    ldaa B_VEND+0
    suba B_DATABASE+0
    staa B_TEMP+0
    ldaa B_VEND+1
    sbca B_DATABASE+1
    staa B_TEMP+1
    ldaa B_VEND+2
    sbca B_DATABASE+2
    staa B_TEMP+2
    ldaa B_VEND+3
    sbca B_DATABASE+3
    staa B_TEMP+3
    bcc long_branch_27
    jmp failed
long_branch_27
    ldab B_SPC
volume_cluster_shift
    lsrb
    beq volume_clusters
    lsr B_TEMP+3
    ror B_TEMP+2
    ror B_TEMP+1
    ror B_TEMP
    bra volume_cluster_shift
volume_clusters
    ldaa B_TEMP+3
    oraa B_TEMP+2
    beq long_branch_28
    jmp failed
long_branch_28
    ldaa B_TEMP+1
    cmpa #$0f
    bcc long_branch_29
    jmp failed
long_branch_29
    bne cluster_min_ok
    ldaa B_TEMP
    cmpa #$f5
    bcc long_branch_30
    jmp failed
long_branch_30
cluster_min_ok
    ldaa B_TEMP+1
    cmpa #$ff
    bne cluster_max_ok
    ldaa B_TEMP
    cmpa #$f5
    bcs long_branch_31
    jmp failed
long_branch_31
cluster_max_ok
    ldaa B_TEMP
    adda #2
    staa B_CLIMIT
    ldaa B_TEMP+1
    adca #0
    staa B_CLIMIT+1
    ; FAT16 capacity = sectors-per-FAT * 256 entries.
    ldaa B_SECTOR+23
    bne fat_capacity_ok
    ldaa B_CLIMIT+1
    cmpa B_SECTOR+22
    bls long_branch_32
    jmp failed
long_branch_32
    bcs fat_capacity_ok
    ldaa B_CLIMIT
    beq long_branch_33
    jmp failed
long_branch_33
fat_capacity_ok
    rts
signature
    ldaa B_SECTOR+510
    cmpa #$55
    beq long_branch_34
    jmp failed
long_branch_34
    ldaa B_SECTOR+511
    cmpa #$aa
    beq long_branch_35
    jmp failed
long_branch_35
    rts
; X points to 11-byte uppercase 8.3 filename. B_SIZE returned little endian in RAM.
file_open
    jsr file_find
    bcc long_branch_36
    jmp failed
long_branch_36
    jmp open_found
; Optional root lookup: carry means absent; otherwise X/B_LBA identify the entry.
file_find
    stx B_MATCH
    ldx #B_NAME
    stx B_ENTRY
    ldab #11
open_name
    ldx B_MATCH
    ldaa 0,x
    inx
    stx B_MATCH
    ldx B_ENTRY
    staa 0,x
    inx
    stx B_ENTRY
    decb
    bne open_name
    ldaa B_ROOTBASE+0
    staa B_LBA+0
    ldaa B_ROOTBASE+1
    staa B_LBA+1
    ldaa B_ROOTBASE+2
    staa B_LBA+2
    ldaa B_ROOTBASE+3
    staa B_LBA+3
    ; Root size copied from mounted BPB is retained separately.
    jsr read_sector
    ldx #B_SECTOR
    stx B_ENTRY
open_entry
    ldx B_ENTRY
    ldaa 0,x
    bne long_branch_37
    jmp open_absent
long_branch_37
    cmpa #$e5
    beq open_next
    ldaa 11,x
    bita #$18
    bne open_next
    stx B_SAVEX
    ldx #B_NAME
    stx B_MATCH
    ldab #11
open_compare
    ldx B_MATCH
    ldaa 0,x
    inx
    stx B_MATCH
    ldx B_SAVEX
    cmpa 0,x
    bne open_next
    inx
    stx B_SAVEX
    decb
    bne open_compare
    ldx B_ENTRY
    clc
    rts
open_found
    ldaa 20,x
    oraa 21,x
    beq long_branch_38
    jmp failed
long_branch_38
    ldaa 26,x
    staa B_CLUSTER+1
    ldaa 27,x
    staa B_CLUSTER
    ldaa 28,x
    staa B_SIZE+0
    staa B_REM+0
    ldaa 29,x
    staa B_SIZE+1
    staa B_REM+1
    ldaa 30,x
    staa B_SIZE+2
    staa B_REM+2
    ldaa 31,x
    staa B_SIZE+3
    staa B_REM+3
    clr B_SECI
    jsr cluster_lba
    jsr read_sector
    jsr buffer_reset
    rts
open_next
    ldx B_ENTRY
    ; advance to next 32-byte root entry; only 16 entries in one sector.
    ldab #32
open_advance
    inx
    decb
    bne open_advance
    stx B_ENTRY
    cpx #B_SECTOR+512
    beq long_branch_39
    jmp open_entry
long_branch_39
    jsr increment_lba
    ; Root cannot cross into data region.
    ldaa B_LBA+3
    cmpa B_DATABASE+3
    bne open_more
    ldaa B_LBA+2
    cmpa B_DATABASE+2
    bne open_more
    ldaa B_LBA+1
    cmpa B_DATABASE+1
    bne open_more
    ldaa B_LBA
    cmpa B_DATABASE
    bne long_branch_40
    jmp open_absent
long_branch_40
open_more
    jsr read_sector
    ldx #B_SECTOR
    stx B_ENTRY
    jmp open_entry
open_absent
    sec
    rts
buffer_reset
    ldx #B_SECTOR
    stx B_BUFP
    ldx #512
    stx B_BLEFT
    rts
; Compute B_DATABASE+(cluster-2)*B_SPC+B_SECI into B_LBA.
cluster_lba
    ldaa B_CLUSTER
    cmpa B_CLIMIT+1
    bls long_branch_42
    jmp failed
long_branch_42
    bcs cluster_in_bounds
    ldaa B_CLUSTER+1
    cmpa B_CLIMIT
    bcs long_branch_43
    jmp failed
long_branch_43
cluster_in_bounds
    ldaa B_CLUSTER
    cmpa #$ff
    bcs long_branch_44
    jmp failed
long_branch_44
    ldaa B_CLUSTER+1
    suba #2
    staa B_TEMP
    ldaa B_CLUSTER
    sbca #0
    bcc long_branch_45
    jmp failed
long_branch_45
    staa B_TEMP+1
    clr B_TEMP+2
    clr B_TEMP+3
    ldab B_SPC
cluster_multiply
    lsrb
    beq cluster_multiplied
    asl B_TEMP
    rol B_TEMP+1
    rol B_TEMP+2
    rol B_TEMP+3
    bra cluster_multiply
cluster_multiplied
    ldaa B_DATABASE+0
    staa B_LBA+0
    ldaa B_DATABASE+1
    staa B_LBA+1
    ldaa B_DATABASE+2
    staa B_LBA+2
    ldaa B_DATABASE+3
    staa B_LBA+3
    ldx #B_TEMP
    jsr add_lba
    ldaa B_SECI
    staa B_TEMP
    clr B_TEMP+1
    clr B_TEMP+2
    clr B_TEMP+3
    ldx #B_TEMP
    jsr add_lba
    rts
file_byte
    ldaa B_REM
    oraa B_REM+1
    oraa B_REM+2
    oraa B_REM+3
    bne long_branch_46
    jmp failed
long_branch_46
    ldx B_BLEFT
    bne get_buffered
    inc B_SECI
    ldaa B_SECI
    cmpa B_SPC
    bcs get_sector
    ; Read FAT16 next-cluster entry; FAT sector = B_FATBASE+cluster high byte.
    ldaa B_FATBASE+0
    staa B_LBA+0
    ldaa B_FATBASE+1
    staa B_LBA+1
    ldaa B_FATBASE+2
    staa B_LBA+2
    ldaa B_FATBASE+3
    staa B_LBA+3
    ldaa B_CLUSTER
    staa B_TEMP
    clr B_TEMP+1
    clr B_TEMP+2
    clr B_TEMP+3
    ldx #B_TEMP
    jsr add_lba
    jsr read_sector
    ldx #B_SECTOR
    ldab B_CLUSTER+1
get_fat_offset
    tstb
    beq get_fat_entry
    inx
    inx
    decb
    bra get_fat_offset
get_fat_entry
    ldaa 0,x
    staa B_CLUSTER+1
    ldaa 1,x
    staa B_CLUSTER
    clr B_SECI
get_sector
    jsr cluster_lba
    jsr read_sector
    jsr buffer_reset
get_buffered
    ldx B_BLEFT
    dex
    stx B_BLEFT
    ldaa B_REM
    suba #1
    staa B_REM
    ldaa B_REM+1
    sbca #0
    staa B_REM+1
    ldaa B_REM+2
    sbca #0
    staa B_REM+2
    ldaa B_REM+3
    sbca #0
    staa B_REM+3
    ldx B_BUFP
    ldaa 0,x
    inx
    stx B_BUFP
    rts
; Never return: executing from resident ROM permits clearing all loader RAM.
; Leave an E000 trampoline; commit removes the boot ROM overlay safely there.
handoff
    sei
    ; The loader's CRC covers bytes received from SD. Check what SRAM actually
    ; retained as well, after RAM clearing and before locking/executing ROM.
    ldaa #12
    jsr ui_status
    jsr verify_sram
    ldaa #11
    jsr ui_status
    ldx #handoff_code
    stx B_UI_TEXT
    ldx #$e000
    stx B_UI_DEST
    ldab #17
handoff_copy
    ldx B_UI_TEXT
    ldaa 0,x
    inx
    stx B_UI_TEXT
    ldx B_UI_DEST
    staa 0,x
    inx
    stx B_UI_DEST
    decb
    bne handoff_copy
    ldaa B_SDMODE
    staa $e6a2
    ldx #0
    clra
handoff_clear
    staa 0,x
    inx
    cpx #$3000
    bne handoff_clear
    jmp $e000
handoff_code
    db $86,$a5,$b7,$e6,$a0,$b6,$e6,$a0,$2b,$02,$20,$fe,$fe,$ff,$fe,$6e,$00
loader_name
    db "LOADER  BIN"
    ds $fa00-*,$ff
    org $fa00
crc16_hi
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
crc16_lo
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
ui_init
    ; Bootstrap always renders the 601 console, independently of selected ROM.
    ldaa #1
    staa $e629
    clr B_UI_STAGE
    ldx #$400
    ldaa #' '
ui_clear_screen
    staa 0,x
    inx
    cpx #$7c0
    bne ui_clear_screen
    ldx #ui_crtc
    clrb
ui_crtc_write
    stab $e600
    ldaa 0,x
    staa $e601
    inx
    incb
    cmpb #16
    bne ui_crtc_write
    ldx #$400
    stx B_UI_DEST
    ldx #ui_title
    ldaa B_MODEL
    bita #1
    beq ui_title_selected
    ldx #ui_title_a
ui_title_selected
    jmp ui_puts
; A=stage. Preserve A/B/X; display stage name and retain it for failures.
ui_status
    psha
    pshb
    stx B_UI_X
    staa B_UI_STAGE
    staa B_DEBUG
    ldx #$450
    jsr ui_clear_line
    ldx #$4a0
    jsr ui_clear_line
    ldx #$450
    stx B_UI_DEST
    ldx #ui_step
    jsr ui_puts
    ldaa B_UI_STAGE
    jsr ui_hex
    ldab #$3a
    jsr ui_putc
    ldab #' '
    jsr ui_putc
    ldx #ui_messages
    ldab B_UI_STAGE
    beq ui_message_found
ui_message_find
    inx
    inx
    decb
    bne ui_message_find
ui_message_found
    ldx 0,x
    jsr ui_puts
    ldx B_UI_X
    pulb
    pula
    rts
; A=current block, B=total blocks. Preserve A/B/X.
ui_progress
    psha
    pshb
    stx B_UI_X
    staa B_UI_BLOCK
    stab B_UI_TOTAL
    ldx #$4a0
    stx B_UI_DEST
    ldx #ui_block_message
    jsr ui_puts
    ldaa B_UI_BLOCK
    jsr ui_hex
    ldab #'/'
    jsr ui_putc
    ldaa B_UI_TOTAL
    jsr ui_hex
    ldx B_UI_X
    pulb
    pula
    rts
ui_error
    ldx #$4f0
    stx B_UI_DEST
    ldx #ui_error_message
    jsr ui_puts
    ldaa B_UI_STAGE
    jsr ui_hex
    ldx #$540
    stx B_UI_DEST
    ldx #ui_check_message
    jsr ui_puts
    ldx #$590
    stx B_UI_DEST
    ldx #ui_retry_message
    jsr ui_puts
    ldaa B_UI_STAGE
    cmpa #1
    bne ui_string_done
    jmp sd_error_details
ui_clear_line
    ldaa #' '
    ldab #40
ui_clear_char
    staa 0,x
    inx
    decb
    bne ui_clear_char
    rts
ui_puts
    ldab 0,x
    beq ui_string_done
    stx B_UI_TEXT
    jsr ui_putc
    ldx B_UI_TEXT
    inx
    bra ui_puts
ui_string_done
    rts
ui_putc
    ldx B_UI_DEST
    stab 0,x
    inx
    stx B_UI_DEST
    rts
ui_hex
    psha
    lsra
    lsra
    lsra
    lsra
    jsr ui_nibble
    pula
ui_nibble
    anda #$0f
    cmpa #10
    bcs ui_digit
    adda #7
ui_digit
    adda #'0'
    tab
    jmp ui_putc
ui_crtc
    db 63,40,46,8,38,0,24,36,0,7,$20,7,4,0,0,0
ui_title
    db "PYLDIN-601 SYSTEM INITIALIZATION",0
ui_title_a
    db "PYLDIN-601A SYSTEM INITIALIZATION",0
ui_step
    db "STEP ",0
ui_block_message
    db "BLOCK ",0
ui_error_message
    db "BOOT ERROR AT STEP ",0
ui_check_message
    db "CHECK SD / LOADER.BIN / P601.ROM",0
ui_retry_message
    db "PRESS RESET TO RETRY",0
ui_messages
    dw ui_starting,ui_sd,ui_fat,ui_loader,ui_rom,ui_header,ui_banks,ui_tail,ui_crc,ui_ram,ui_disk,ui_start,ui_sram
ui_starting
    db "STARTING",0
ui_sd
    db "INITIALIZING SD",0
ui_fat
    db "READING MBR / FAT16",0
ui_loader
    db "LOADING LOADER.BIN",0
ui_rom
    db "OPENING SELECTED ROM",0
ui_header
    db "CHECKING ROM HEADER",0
ui_banks
    db "LOADING ROM BANKS",0
ui_tail
    db "LOADING BIOS / FONT",0
ui_crc
    db "CHECKING ROM CRC32",0
ui_ram
    db "INITIALIZING RAM",0
ui_disk
    db "INITIALIZING ROM DISK",0
ui_start
    db "STARTING SELECTED BIOS",0
ui_sram
    db "VERIFYING SRAM CRC32",0
verify_sram
    clr $e6a4
    clr $e6a5
    ldaa #1
    staa $e6a6
    staa $e6aa
    ldaa #1
    staa B_VERIFY_BLOCKS
verify_bank
    ldx #0
    jsr verify_block
    dec B_VERIFY_BLOCKS
    bne verify_bank
    ldx #$1800
    jsr verify_block
    ldaa $e6ac
    cmpa $1014
    beq long_branch_47
    jmp failed
long_branch_47
    ldaa $e6ad
    cmpa $1015
    beq long_branch_48
    jmp failed
long_branch_48
    ldaa $e6ae
    cmpa $1016
    beq long_branch_49
    jmp failed
long_branch_49
    ldaa $e6af
    cmpa $1017
    beq long_branch_50
    jmp failed
long_branch_50
    rts
verify_block
    stx B_LEFT
verify_byte
    clr $e6ab
verify_wait
    ldaa $e6a8
    bpl long_branch_51
    jmp failed
long_branch_51
    bita #1
    bne verify_wait
    ldaa $e6ab
    staa $e6a9
    ldx B_LEFT
    dex
    stx B_LEFT
    bne verify_byte
    rts
    ds $fff8-*,$ff
    org $fff8
    dw failed,failed,failed,$f000

    include SETUP.ASM
    include BOOTKEY.ASM
    ds $e000-*,$ff
    end
