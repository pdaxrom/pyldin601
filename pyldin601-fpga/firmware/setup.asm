; Resident HD6303 setup extension. D000-DFFF is ROM only while boot_mode=1.
; P601.SET is a single-cluster, 16-byte file in the FAT16 root directory.
SET_REQUEST equ $1a0
SET_CURRENT equ $1a1
SET_ORIGINAL equ $1a2
SET_CURSOR equ $1a3
SET_VALID equ $1a4
SET_SAVING equ $1a5
SET_SP equ $1a6
SET_TABLE equ $1a8
SET_ROW equ $1aa
SET_ROOT equ $1ac
SET_ENTRY equ $1b0
SET_CLUSTER equ $1b2
SET_FATSIZE equ $1b4
SET_FATCOPIES equ $1b6
SET_COPY equ $1b7
SET_SOURCE equ $1b8
SET_DEST equ $1ba
SET_ATTR equ $1bc
SET_DRAW_ROWS equ $1bd
SET_SECONDS equ $1be
SET_SUBTICKS equ $1bf
SET_EDIT equ $1c0
SET_LOADING equ $1c1
SET_LOAD_SP equ $1c2
CFGDATA equ $a00
SAVEBUF equ $c00
    org $d000
setup_wait:
    clr SET_REQUEST
    ldx #$590
    stx UI_DEST
    ldx #setup_notice
    jsr ui_puts
    ldaa $e62b
    ldx #500
    stx MENU_TICKS
    ldaa #10
    staa SET_SECONDS
    ldaa #50
    staa SET_SUBTICKS
    jsr setup_countdown
setup_wait_tick:
    ldaa $e628
    staa MENU_KEY
    cmpa #$f9
    lbeq setup_wait_del
    ldaa $e62b
    lbpl setup_wait_tick
    dec SET_SUBTICKS
    lbne setup_wait_decrement
    ldaa #50
    staa SET_SUBTICKS
    dec SET_SECONDS
    jsr setup_countdown
setup_wait_decrement:
    ldx MENU_TICKS
    dex
    stx MENU_TICKS
    lbne setup_wait_tick
    rts
setup_wait_del:
    inc SET_REQUEST
    rts
setup_countdown:
    ldx #$5e0
    stx UI_DEST
    ldx #setup_countdown_text
    jsr ui_puts
    ldab #'0'
    ldaa SET_SECONDS
    cmpa #10
    lbcs setup_countdown_digit
    ldab #'1'
setup_countdown_digit:
    jsr ui_putc
    ldaa SET_SECONDS
    cmpa #10
    lbcs setup_countdown_units
    suba #10
setup_countdown_units:
    adda #'0'
    tab
    jsr ui_putc
    ldx #setup_seconds_text
    jmp ui_puts
setup_configure:
    jsr settings_load
    ldaa SET_CURRENT
    staa SET_ORIGINAL
    tst SET_VALID
    lbeq setup_menu
    jsr setup_summary
    jsr setup_wait
    tst SET_REQUEST
    lbne setup_menu
setup_apply:
    ldaa SET_CURRENT
    staa MODEL
    jmp ui_init
setup_menu:
    clr SET_CURSOR
    ldaa #6
    staa SET_DRAW_ROWS
    jsr setup_draw
    tst SET_VALID
    lbne setup_read_key
    ldx #setup_missing
    jsr setup_message
setup_read_key:
    ldaa $e628
    cmpa MENU_KEY
    lbeq setup_read_key
    staa MENU_KEY
    cmpa #$ff
    lbeq setup_read_key
    cmpa #$1b
    lbeq setup_exit
    cmpa #$c4
    lbeq setup_up
    cmpa #$c3
    lbeq setup_down
    cmpa #$c1
    lbeq setup_left
    cmpa #$c2
    lbeq setup_right
    cmpa #' '
    lbeq setup_right
    cmpa #$c0
    lbne setup_read_key
    ldaa SET_CURSOR
    cmpa #3
    lbcs setup_right
    lbeq setup_save
    cmpa #4
    lbeq setup_apply
setup_exit:
    ldaa SET_ORIGINAL
    staa SET_CURRENT
    lbra setup_apply
setup_save:
    sts SET_SP
    ldaa SET_CURRENT
    staa SET_EDIT
    inc SET_SAVING
    jsr settings_save
    clr SET_SAVING
    lbra setup_apply
setup_save_failed:
    ; Unwind the write/read/CRC call stack, retaining the edited settings.
    lds SET_SP
    clr SET_SAVING
    clr SET_LOADING
    ldaa SET_EDIT
    staa SET_CURRENT
    ldaa #$23
    staa SPI_CTL
    jsr setup_draw
    ldx #setup_save_error
    jsr setup_message
    lbra setup_read_key
setup_up:
    ldaa SET_CURSOR
    lbne setup_up_dec
    ldaa #6
setup_up_dec:
    deca
    staa SET_CURSOR
    lbra setup_redraw
setup_down:
    ldaa SET_CURSOR
    inca
    cmpa #6
    lbcs setup_cursor_store
    clra
setup_cursor_store:
    staa SET_CURSOR
    lbra setup_redraw
setup_left:
    ldab #12
    lbra setup_change
setup_right:
    ldab #4
setup_change:
    ldaa SET_CURSOR
    cmpa #3
    lbcc setup_read_key
    tsta
    lbne setup_not_model
    ldaa SET_CURRENT
    eora #1
    lbra setup_value_store
setup_not_model:
    cmpa #1
    lbne setup_frequency
    ldaa SET_CURRENT
    eora #2
    lbra setup_value_store
setup_frequency:
    ldaa SET_CURRENT
    aba
    anda #15
setup_value_store:
    staa SET_CURRENT
setup_redraw:
    jsr setup_draw
    lbra setup_read_key
setup_draw:
    ; The editor always uses 601's 40-column bootstrap screen. Hardware model
    ; and runtime ISA/frequency are applied together only on leaving setup.
    jsr ui_init
    ldx #$400
    stx UI_DEST
    ldx #setup_title
    jsr ui_puts
    ldx #setup_labels
    stx SET_TABLE
    ldd #$450
    std SET_ROW
    clr SET_COPY
setup_draw_row:
    ldx SET_ROW
    stx UI_DEST
    ldab #' '
    ldaa SET_COPY
    cmpa SET_CURSOR
    lbne setup_marker
    ldab #'>'
setup_marker:
    jsr ui_putc
    ldx SET_TABLE
    ldx 0,x
    jsr ui_puts
    ldaa SET_COPY
    lbne setup_draw_not_model
    ldx #setup_601
    ldaa SET_CURRENT
    bita #1
    lbeq setup_draw_value
    ldx #setup_601a
    lbra setup_draw_value
setup_draw_not_model:
    cmpa #1
    lbne setup_draw_not_cpu
    ldab #'N'
    ldaa SET_CURRENT
    bita #2
    lbeq setup_draw_yn
    ldab #'Y'
setup_draw_yn:
    jsr ui_putc
    lbra setup_draw_next
setup_draw_not_cpu:
    cmpa #2
    lbne setup_draw_next
    ldaa SET_CURRENT
    lsra
    lsra
    staa SET_ATTR
    ldab #'1'
setup_draw_freq:
    tst SET_ATTR
    lbeq setup_draw_freq_done
    subb #'0'
    aslb
    addb #'0'
    dec SET_ATTR
    lbra setup_draw_freq
setup_draw_freq_done:
    jsr ui_putc
    ldx #setup_mhz
setup_draw_value:
    jsr ui_puts
setup_draw_next:
    ldd SET_TABLE
    addd #2
    std SET_TABLE
    ldd SET_ROW
    addd #80
    std SET_ROW
    inc SET_COPY
    ldaa SET_COPY
    cmpa SET_DRAW_ROWS
    lbne setup_draw_row
    cmpa #3
    lbeq setup_draw_done
    ldx #$680
    stx UI_DEST
    ldx #setup_help
    jmp ui_puts
setup_draw_done:
    rts
setup_summary:
    ldaa #3
    staa SET_DRAW_ROWS
    ldaa #$ff
    staa SET_CURSOR
    jsr setup_draw
    ldx #$400
    jsr ui_clear_line
    ldx #$400
    stx UI_DEST
    ldx #setup_summary_title
    jmp ui_puts
setup_message:
    stx SET_TABLE
    ldx #$630
    jsr ui_clear_line
    ldx #$630
    stx UI_DEST
    ldx SET_TABLE
    jmp ui_puts
settings_load:
    sts SET_LOAD_SP
    inc SET_LOADING
    clr SET_VALID
    clr SET_CURRENT
    ldx #settings_name
    jsr file_find
    lbcs settings_invalid
    ; Keep the root location for save before the shared sector buffer changes.
    stx SET_ENTRY
    jsr settings_keep_root
    ldd 28,x
    subd #$1000
    lbne settings_invalid
    ldd 30,x
    lbne settings_invalid
    ldaa 27,x
    ldab 26,x
    std SET_CLUSTER
    jsr settings_cluster_check
    lbcs settings_invalid
    jsr settings_fat_entry
    ldaa 1,x
    cmpa #$ff
    lbne settings_invalid
    ldaa 0,x
    cmpa #$f8
    lbcs settings_invalid
    jsr settings_data_lba
    jsr read_sector
    ldx #SECTOR
    stx SET_SOURCE
    ldx #CFGDATA
    stx SET_DEST
    ldd #16
    std LEFT
    jsr settings_copy
    ldd CFGDATA
    subd #$5036
    lbne settings_invalid
    ldd CFGDATA+2
    subd #$3031
    lbne settings_invalid
    ldd CFGDATA+4
    subd #$5345
    lbne settings_invalid
    ldd CFGDATA+6
    subd #$5400
    lbne settings_invalid
    ldaa CFGDATA+8
    cmpa #1
    lbne settings_invalid
    ldaa CFGDATA+9
    cmpa #15
    lbhi settings_invalid
    ldd CFGDATA+10
    lbne settings_invalid
    ldd CFGDATA+12
    lbne settings_invalid
    jsr settings_checksum
    ldd CFGDATA+14
    subd CRC16
    lbne settings_invalid
    ldaa CFGDATA+9
    staa SET_CURRENT
    inc SET_VALID
settings_invalid:
    clr SET_LOADING
    rts
settings_load_failed:
    lds SET_LOAD_SP
    clr SET_LOADING
    clr SET_VALID
    clr SET_CURRENT
    ldaa #$23
    staa SPI_CTL
    rts
settings_cluster_check:
    ldd SET_CLUSTER
    subd #2
    lbcs settings_bad_cluster
    ldaa SET_CLUSTER
    cmpa CLIMIT+1
    lbhi settings_bad_cluster
    lbcs settings_good_cluster
    ldaa SET_CLUSTER+1
    cmpa CLIMIT
    lbcc settings_bad_cluster
settings_good_cluster:
    clc
    rts
settings_bad_cluster:
    sec
    rts
settings_keep_root:
    ldd LBA
    std SET_ROOT
    ldd LBA+2
    std SET_ROOT+2
    rts
settings_restore_root:
    ldx #SET_ROOT
settings_copy_lba:
    ldd 0,x
    std LBA
    ldd 2,x
    std LBA+2
    rts
settings_data_lba:
    ldd SET_CLUSTER
    std CLUSTER
    clr SECI
    jmp cluster_lba
settings_fat_entry:
    ldx #FATBASE
    jsr settings_copy_lba
    ldaa SET_CLUSTER
    staa TEMP
    clr TEMP+1
    clr TEMP+2
    clr TEMP+3
    ldx #TEMP
    jsr add_lba
    jsr read_sector
    ldx #SECTOR
    ldab SET_CLUSTER+1
    aslb
    lbcc settings_fat_offset
    ldx #SECTOR+256
settings_fat_offset:
    abx
    stx ENTRY
    rts
settings_checksum:
    clr CRC16
    clr CRC16+1
    ldx #CFGDATA
settings_checksum_byte:
    ldaa 0,x
    jsr settings_crc_byte
    inx
    cpx #CFGDATA+14
    lbne settings_checksum_byte
    rts
settings_crc_byte:
    pshx
    psha
    eora CRC16
    staa CRCPTR+1
    ldaa #crc16_hi>>8
    staa CRCPTR
    ldx CRCPTR
    ldaa 0,x
    eora CRC16+1
    staa CRC16
    ldaa #crc16_lo>>8
    staa CRCPTR
    ldx CRCPTR
    ldaa 0,x
    staa CRC16+1
    pula
    pulx
    rts
settings_copy:
    ; LEFT is a big-endian even byte count; source and destination are RAM/ROM.
    ldx SET_SOURCE
    ldd 0,x
    inx
    inx
    stx SET_SOURCE
    ldx SET_DEST
    std 0,x
    inx
    inx
    stx SET_DEST
    ldd LEFT
    subd #2
    std LEFT
    lbne settings_copy
    rts
settings_save:
    ; Keep existing allocation unchanged; create a one-cluster file if absent.
    ldaa SET_FATCOPIES
    cmpa #1
    lbcs failed
    cmpa #2
    lbhi failed
    clr SET_ATTR
    ldx #settings_name
    jsr file_find
    lbcs settings_create
    stx SET_ENTRY
    jsr settings_keep_root
    ldaa 11,x
    bita #1
    lbne failed
    ldd 28,x
    subd #$1000
    lbne failed
    ldd 30,x
    lbne failed
    ldaa 27,x
    ldab 26,x
    std SET_CLUSTER
    jsr settings_cluster_check
    lbcs failed
    jsr settings_fat_entry
    ldaa 1,x
    cmpa #$ff
    lbne failed
    ldaa 0,x
    cmpa #$f8
    lbcs failed
    lbra settings_write_data
settings_create:
    inc SET_ATTR
    jsr settings_empty_root
    ldd #2
    std SET_CLUSTER
settings_free_sector:
    jsr settings_cluster_check
    lbcs failed
    jsr settings_fat_entry
settings_free_entry:
    ldd 0,x
    lbeq settings_write_data
    ldd SET_CLUSTER
    addd #1
    std SET_CLUSTER
    jsr settings_cluster_check
    lbcs failed
    ldaa SET_CLUSTER+1
    lbeq settings_free_sector
    inx
    inx
    lbra settings_free_entry
settings_write_data:
    ldx #settings_magic
    stx SET_SOURCE
    ldx #CFGDATA
    stx SET_DEST
    ldd #14
    std LEFT
    jsr settings_copy
    ldaa SET_CURRENT
    staa CFGDATA+9
    jsr settings_checksum
    ldd CRC16
    std CFGDATA+14
    jsr settings_data_lba
    ldx #SECTOR
settings_clear_sector:
    clr 0,x
    inx
    cpx #SECTOR+512
    lbne settings_clear_sector
    ldx #CFGDATA
    stx SET_SOURCE
    ldx #SECTOR
    stx SET_DEST
    ldd #16
    std LEFT
    jsr settings_copy
    jsr settings_write_checked
    tst SET_ATTR
    lbeq settings_save_verify
    jsr settings_fat_entry
    ldaa #$ff
    staa 0,x
    staa 1,x
    clr SET_COPY
settings_allocate_fat:
    jsr settings_write_checked
    inc SET_COPY
    ldaa SET_COPY
    cmpa SET_FATCOPIES
    lbcc settings_publish
    ldaa SET_FATSIZE+1
    staa TEMP
    ldaa SET_FATSIZE
    staa TEMP+1
    clr TEMP+2
    clr TEMP+3
    ldx #TEMP
    jsr add_lba
    jsr read_sector
    ldx ENTRY
    ldaa 0,x
    oraa 1,x
    lbne failed
    ldaa #$ff
    staa 0,x
    staa 1,x
    lbra settings_allocate_fat
settings_publish:
    jsr settings_restore_root
    jsr read_sector
    ldx SET_ENTRY
    ldaa 0,x
    lbeq settings_root_free
    cmpa #$e5
    lbne failed
settings_root_free:
    ldab #32
settings_clear_entry:
    clr 0,x
    inx
    decb
    lbne settings_clear_entry
    ldx #settings_name
    stx SET_SOURCE
    ldx SET_ENTRY
    stx SET_DEST
    ldab #11
settings_publish_name:
    ldx SET_SOURCE
    ldaa 0,x
    inx
    stx SET_SOURCE
    ldx SET_DEST
    staa 0,x
    inx
    stx SET_DEST
    decb
    lbne settings_publish_name
    ldx SET_ENTRY
    ldaa #$20
    staa 11,x
    ldaa SET_CLUSTER+1
    staa 26,x
    ldaa SET_CLUSTER
    staa 27,x
    ldaa #16
    staa 28,x
    ldaa #$21
    staa 16,x
    staa 18,x
    staa 24,x
    jsr settings_write_checked
settings_save_verify:
    ldaa SET_CURRENT
    psha
    jsr settings_load
    pula
    tst SET_VALID
    lbeq failed
    cmpa SET_CURRENT
    lbne failed
    rts
settings_empty_root:
    ldx #ROOTBASE
    jsr settings_copy_lba
settings_empty_sector:
    jsr read_sector
    ldx #SECTOR
settings_empty_entry:
    ldaa 0,x
    lbeq settings_empty_found
    cmpa #$e5
    lbeq settings_empty_found
    ldab #32
    abx
    cpx #SECTOR+512
    lbne settings_empty_entry
    jsr increment_lba
    ldd LBA
    subd DATABASE
    lbne settings_empty_sector
    ldd LBA+2
    subd DATABASE+2
    lbne settings_empty_sector
    jmp failed
settings_empty_found:
    stx SET_ENTRY
    jmp settings_keep_root
settings_write_checked:
    ; Snapshot all 512 bytes before SPI changes shared buffers. Verify the
    ; complete sector after CMD24, including accepted token and busy release.
    ldx #SECTOR
    stx SET_SOURCE
    ldx #SAVEBUF
    stx SET_DEST
    ldd #512
    std LEFT
    jsr settings_copy
    jsr settings_write_sector
    jsr read_sector
    ldx #SECTOR
    stx SET_SOURCE
    ldx #SAVEBUF
    stx SET_DEST
settings_compare_sector:
    ldx SET_SOURCE
    ldd 0,x
    inx
    inx
    stx SET_SOURCE
    ldx SET_DEST
    subd 0,x
    lbne failed
    inx
    inx
    stx SET_DEST
    cpx #SAVEBUF+512
    lbne settings_compare_sector
    rts
settings_write_sector:
    ldd LBA
    std ARG
    ldd LBA+2
    std ARG+2
    ldaa SDMODE
    lbne settings_write_addressed
    ldaa ARG+3
    lbne failed
    ldaa ARG+2
    lbmi failed
    ldab #9
settings_write_shift:
    asl ARG
    rol ARG+1
    rol ARG+2
    rol ARG+3
    decb
    lbne settings_write_shift
settings_write_addressed:
    ldaa #$58
    staa COMMAND
    ldaa #1
    staa CHECK
    jsr command
    lbne failed
    jsr spi_read
    ldaa #$fe
    jsr spi
    clr CRC16
    clr CRC16+1
    ldx #SECTOR
settings_write_byte:
    ldaa 0,x
    jsr settings_crc_byte
    jsr spi
    inx
    cpx #SECTOR+512
    lbne settings_write_byte
    ldaa CRC16
    jsr spi
    ldaa CRC16+1
    jsr spi
    ldab #32
settings_write_token:
    jsr spi_read
    cmpa #$ff
    lbne settings_write_response
    decb
    lbne settings_write_token
    jmp failed
settings_write_response:
    anda #$1f
    cmpa #5
    lbne failed
    ldx #$ffff
settings_write_busy:
    jsr spi_read
    cmpa #$ff
    lbeq settings_write_done
    ; Busy release can occur inside this byte (01/03/.../7F). Keep clocking
    ; until an entire idle FF byte; these transitions are not write errors.
    dex
    lbne settings_write_busy
    jmp failed
settings_write_done:
    jmp release
setup_notice:
    db "PRESS DEL FOR BIOS SETUP",0
setup_countdown_text:
    db "BOOT IN ",0
setup_seconds_text:
    db " SECONDS",0
setup_title:
    db "PYLDIN BIOS SETUP",0
setup_summary_title:
    db "PYLDIN SYSTEM BIOS",0
setup_labels:
    dw setup_model,setup_cpu,setup_freq,setup_save_text,setup_nosave,setup_exit_text
setup_model:
    db "MODEL                  ",0
setup_cpu:
    db "CPU HD6303 EXTENSION    ",0
setup_freq:
    db "CPU FREQ               ",0
setup_save_text:
    db "SAVE AND BOOT",0
setup_nosave:
    db "BOOT WITHOUT SAVE",0
setup_exit_text:
    db "EXIT AND BOOT",0
setup_601:
    db "601",0
setup_601a:
    db "601A",0
setup_mhz:
    db " MHz",0
setup_help:
    db "ARROWS SELECT/CHANGE  ENTER CONFIRM",0
setup_missing:
    db "NO VALID CONFIGURATION",0
setup_save_error:
    db "SAVE FAILED - CHECK SD",0
settings_name:
    db "P601    SET"
settings_magic:
    db "P601SET",0,1,0,0,0,0,0
setup_end:
