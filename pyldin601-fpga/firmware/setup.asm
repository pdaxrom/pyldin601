; Resident HD6303 setup extension. D000-DFFF is ROM only while boot_mode=1.
; P601.SET is a single-cluster, 16-byte file in the FAT16 root directory.
B_SET_REQUEST equ $1a0
B_SET_CURRENT equ $1a1
B_SET_ORIGINAL equ $1a2
B_SET_CURSOR equ $1a3
B_SET_VALID equ $1a4
B_SET_SAVING equ $1a5
B_SET_SP equ $1a6
B_SET_TABLE equ $1a8
B_SET_ROW equ $1aa
B_SET_ROOT equ $1ac
B_SET_ENTRY equ $1b0
B_SET_CLUSTER equ $1b2
B_SET_FATSIZE equ $1b4
B_SET_FATCOPIES equ $1b6
B_SET_COPY equ $1b7
B_SET_SOURCE equ $1b8
B_SET_DEST equ $1ba
B_SET_ATTR equ $1bc
B_SET_DRAW_ROWS equ $1bd
B_SET_SECONDS equ $1be
B_SET_SUBTICKS equ $1bf
B_SET_EDIT equ $1c0
B_SET_LOADING equ $1c1
B_SET_LOAD_SP equ $1c2
B_SET_PART equ $1c4
B_SET_PART_ORIGINAL equ $1c5
B_SET_PART_EDIT equ $1c6
B_CFGDATA equ $a00
B_SAVEBUF equ $c00
    org $d000
setup_wait
    clr B_SET_REQUEST
    ldx #$5e0
    stx B_UI_DEST
    ldx #setup_notice
    jsr ui_puts
    ldaa $e62b
    ldx #500
    stx B_MENU_TICKS
    ldaa #10
    staa B_SET_SECONDS
    ldaa #50
    staa B_SET_SUBTICKS
    jsr setup_countdown
setup_wait_tick
    jsr boot_keyboard_poll
    ldaa $e628
    staa B_MENU_KEY
    cmpa #$f9
    bne long_branch_52
    jmp setup_wait_del
long_branch_52
    ldaa $e62b
    bmi long_branch_53
    jmp setup_wait_tick
long_branch_53
    dec B_SET_SUBTICKS
    beq long_branch_54
    jmp setup_wait_decrement
long_branch_54
    ldaa #50
    staa B_SET_SUBTICKS
    dec B_SET_SECONDS
    jsr setup_countdown
setup_wait_decrement
    ldx B_MENU_TICKS
    dex
    stx B_MENU_TICKS
    beq long_branch_55
    jmp setup_wait_tick
long_branch_55
    rts
setup_wait_del
    inc B_SET_REQUEST
    rts
setup_countdown
    ldx #$630
    stx B_UI_DEST
    ldx #setup_countdown_text
    jsr ui_puts
    ldab #'0'
    ldaa B_SET_SECONDS
    cmpa #10
    bcc long_branch_56
    jmp setup_countdown_digit
long_branch_56
    ldab #'1'
setup_countdown_digit
    jsr ui_putc
    ldaa B_SET_SECONDS
    cmpa #10
    bcc long_branch_57
    jmp setup_countdown_units
long_branch_57
    suba #10
setup_countdown_units
    adda #'0'
    tab
    jsr ui_putc
    ldx #setup_seconds_text
    jmp ui_puts
setup_configure
    jsr settings_load
    ldaa B_SET_CURRENT
    staa B_SET_ORIGINAL
    ldaa B_SET_PART
    staa B_SET_PART_ORIGINAL
    tst B_SET_VALID
    bne long_branch_58
    jmp setup_menu
long_branch_58
    jsr setup_summary
    jsr setup_wait
    tst B_SET_REQUEST
    beq long_branch_59
    jmp setup_menu
long_branch_59
setup_apply
    ldaa B_SET_PART
    staa $e6ae
    ldaa B_SET_CURRENT
    staa B_MODEL
    jmp ui_init
setup_menu
    clr B_SET_CURSOR
    ldaa #7
    staa B_SET_DRAW_ROWS
    jsr setup_draw
    tst B_SET_VALID
    beq long_branch_60
    jmp setup_read_key
long_branch_60
    ldx #setup_missing
    jsr setup_message
setup_read_key
    jsr boot_keyboard_poll
    ldaa $e628
    cmpa B_MENU_KEY
    bne long_branch_61
    jmp setup_read_key
long_branch_61
    staa B_MENU_KEY
    cmpa #$ff
    bne long_branch_62
    jmp setup_read_key
long_branch_62
    cmpa #$1b
    bne long_branch_63
    jmp setup_exit
long_branch_63
    cmpa #$c4
    bne long_branch_64
    jmp setup_up
long_branch_64
    cmpa #$c3
    bne long_branch_65
    jmp setup_down
long_branch_65
    cmpa #$c1
    bne long_branch_66
    jmp setup_left
long_branch_66
    cmpa #$c2
    bne long_branch_67
    jmp setup_right
long_branch_67
    cmpa #' '
    bne long_branch_68
    jmp setup_right
long_branch_68
    cmpa #$c0
    beq long_branch_69
    jmp setup_read_key
long_branch_69
    ldaa B_SET_CURSOR
    cmpa #4
    bcc long_branch_70
    jmp setup_right
long_branch_70
    bne long_branch_71
    jmp setup_save
long_branch_71
    cmpa #5
    bne long_branch_72
    jmp setup_apply
long_branch_72
setup_exit
    ldaa B_SET_PART_ORIGINAL
    staa B_SET_PART
    ldaa B_SET_ORIGINAL
    staa B_SET_CURRENT
    jmp setup_apply
setup_save
    sts B_SET_SP
    ldaa B_SET_CURRENT
    staa B_SET_EDIT
    ldaa B_SET_PART
    staa B_SET_PART_EDIT
    inc B_SET_SAVING
    jsr settings_save
    clr B_SET_SAVING
    jmp setup_apply
setup_save_failed
    ; Unwind the write/read/CRC call stack, retaining the edited settings.
    lds B_SET_SP
    clr B_SET_SAVING
    clr B_SET_LOADING
    ldaa B_SET_PART_EDIT
    staa B_SET_PART
    ldaa B_SET_EDIT
    staa B_SET_CURRENT
    ldaa #$23
    staa B_SPI_CTL
    jsr setup_draw
    ldx #setup_save_error
    jsr setup_message
    jmp setup_read_key
setup_up
    ldaa B_SET_CURSOR
    beq long_branch_76
    jmp setup_up_dec
long_branch_76
    ldaa #7
setup_up_dec
    deca
    staa B_SET_CURSOR
    jmp setup_redraw
setup_down
    ldaa B_SET_CURSOR
    inca
    cmpa #7
    bcc long_branch_78
    jmp setup_cursor_store
long_branch_78
    clra
setup_cursor_store
    staa B_SET_CURSOR
    jmp setup_redraw
setup_left
    ldab #12
    jmp setup_change
setup_right
    ldab #4
setup_change
    ldaa B_SET_CURSOR
    cmpa #4
    bcs long_branch_81
    jmp setup_read_key
long_branch_81
    cmpa #3
    bne long_branch_82
    jmp setup_change_part
long_branch_82
    tsta
    beq long_branch_83
    jmp setup_not_model
long_branch_83
    ldaa B_SET_CURRENT
    eora #1
    jmp setup_value_store
setup_not_model
    cmpa #1
    beq long_branch_85
    jmp setup_frequency
long_branch_85
    ldaa B_SET_CURRENT
    eora #2
    jmp setup_value_store
setup_change_part
    ldaa B_SET_PART
    cmpb #12
    bne long_branch_87
    jmp setup_part_left
long_branch_87
    inca
    cmpa #37
    bcc long_branch_88
    jmp setup_part_store
long_branch_88
    clra
    jmp setup_part_store
setup_part_left
    tsta
    beq long_branch_90
    jmp setup_part_dec
long_branch_90
    ldaa #37
setup_part_dec
    deca
setup_part_store
    staa B_SET_PART
    jmp setup_redraw
setup_frequency
    ldaa B_SET_CURRENT
    aba
    anda #15
setup_value_store
    staa B_SET_CURRENT
setup_redraw
    jsr setup_draw
    jmp setup_read_key
setup_draw
    ; The editor always uses 601's 40-column bootstrap screen. Hardware model
    ; and runtime ISA/frequency are applied together only on leaving setup.
    jsr ui_init
    ldx #$400
    stx B_UI_DEST
    ldx #setup_title
    jsr ui_puts
    ldx #setup_labels
    stx B_SET_TABLE
    ldd #$450
    std B_SET_ROW
    clr B_SET_COPY
setup_draw_row
    ldx B_SET_ROW
    stx B_UI_DEST
    ldab #' '
    ldaa B_SET_COPY
    cmpa B_SET_CURSOR
    beq long_branch_93
    jmp setup_marker
long_branch_93
    ldab #'>'
setup_marker
    jsr ui_putc
    ldx B_SET_TABLE
    ldx 0,x
    jsr ui_puts
    ldaa B_SET_COPY
    beq long_branch_94
    jmp setup_draw_not_model
long_branch_94
    ldx #setup_601
    ldaa B_SET_CURRENT
    bita #1
    bne long_branch_95
    jmp setup_draw_value
long_branch_95
    ldx #setup_601a
    jmp setup_draw_value
setup_draw_not_model
    cmpa #1
    beq long_branch_97
    jmp setup_draw_not_cpu
long_branch_97
    ldab #'N'
    ldaa B_SET_CURRENT
    bita #2
    bne long_branch_98
    jmp setup_draw_yn
long_branch_98
    ldab #'Y'
setup_draw_yn
    jsr ui_putc
    jmp setup_draw_next
setup_draw_not_cpu
    cmpa #2
    beq long_branch_100
    jmp setup_draw_partition
long_branch_100
    ldaa B_SET_CURRENT
    lsra
    lsra
    staa B_SET_ATTR
    ldab #'1'
setup_draw_freq
    tst B_SET_ATTR
    bne long_branch_101
    jmp setup_draw_freq_done
long_branch_101
    subb #'0'
    aslb
    addb #'0'
    dec B_SET_ATTR
    jmp setup_draw_freq
setup_draw_freq_done
    jsr ui_putc
    ldx #setup_mhz
    jmp setup_draw_value
setup_draw_partition
    cmpa #3
    beq long_branch_104
    jmp setup_draw_next
long_branch_104
    ldx #setup_auto
    tst B_SET_PART
    bne long_branch_105
    jmp setup_draw_value
long_branch_105
    ldx #setup_sdpart
    jsr ui_puts
    ldaa B_SET_PART
    ldab #'0'
setup_part_tens
    cmpa #10
    bcc long_branch_106
    jmp setup_part_digits
long_branch_106
    suba #10
    incb
    jmp setup_part_tens
setup_part_digits
    psha
    jsr ui_putc
    pula
    adda #'0'
    tab
    jsr ui_putc
    jmp setup_draw_next
setup_draw_value
    jsr ui_puts
setup_draw_next
    ldd B_SET_TABLE
    addd #2
    std B_SET_TABLE
    ldd B_SET_ROW
    addd #80
    std B_SET_ROW
    inc B_SET_COPY
    ldaa B_SET_COPY
    cmpa B_SET_DRAW_ROWS
    beq long_branch_109
    jmp setup_draw_row
long_branch_109
    cmpa #4
    bne long_branch_110
    jmp setup_draw_done
long_branch_110
    ldx #$6d0
    stx B_UI_DEST
    ldx #setup_help
    jmp ui_puts
setup_draw_done
    rts
setup_summary
    ldaa #4
    staa B_SET_DRAW_ROWS
    ldaa #$ff
    staa B_SET_CURSOR
    jsr setup_draw
    ldx #$400
    jsr ui_clear_line
    ldx #$400
    stx B_UI_DEST
    ldx #setup_summary_title
    jmp ui_puts
setup_message
    stx B_SET_TABLE
    ldx #$680
    jsr ui_clear_line
    ldx #$680
    stx B_UI_DEST
    ldx B_SET_TABLE
    jmp ui_puts
settings_load
    sts B_SET_LOAD_SP
    inc B_SET_LOADING
    clr B_SET_VALID
    clr B_SET_PART
    ldaa #2                 ; New systems: 601, HD6303 ISA, 1 MHz.
    staa B_SET_CURRENT
    ldx #settings_name
    jsr file_find
    bcc long_branch_111
    jmp settings_invalid
long_branch_111
    ; Keep the root location for save before the shared sector buffer changes.
    stx B_SET_ENTRY
    jsr settings_keep_root
    ldd 28,x
    subd #$1000
    beq long_branch_112
    jmp settings_invalid
long_branch_112
    ldd 30,x
    beq long_branch_113
    jmp settings_invalid
long_branch_113
    ldaa 27,x
    ldab 26,x
    std B_SET_CLUSTER
    jsr settings_cluster_check
    bcc long_branch_114
    jmp settings_invalid
long_branch_114
    jsr settings_fat_entry
    ldaa 1,x
    cmpa #$ff
    beq long_branch_115
    jmp settings_invalid
long_branch_115
    ldaa 0,x
    cmpa #$f8
    bcc long_branch_116
    jmp settings_invalid
long_branch_116
    jsr settings_data_lba
    jsr read_sector
    ldx #B_SECTOR
    stx B_SET_SOURCE
    ldx #B_CFGDATA
    stx B_SET_DEST
    ldd #16
    std B_LEFT
    jsr settings_copy
    ldd B_CFGDATA
    subd #$5036
    beq long_branch_117
    jmp settings_invalid
long_branch_117
    ldd B_CFGDATA+2
    subd #$3031
    beq long_branch_118
    jmp settings_invalid
long_branch_118
    ldd B_CFGDATA+4
    subd #$5345
    beq long_branch_119
    jmp settings_invalid
long_branch_119
    ldd B_CFGDATA+6
    subd #$5400
    beq long_branch_120
    jmp settings_invalid
long_branch_120
    ldaa B_CFGDATA+8
    cmpa #1
    bne long_branch_121
    jmp settings_legacy
long_branch_121
    cmpa #2
    beq long_branch_122
    jmp settings_invalid
long_branch_122
    ldaa B_CFGDATA+10
    cmpa #36
    bls long_branch_123
    jmp settings_invalid
long_branch_123
    jmp settings_version_ok
settings_legacy
    tst B_CFGDATA+10
    beq long_branch_125
    jmp settings_invalid
long_branch_125
settings_version_ok
    ldaa B_CFGDATA+9
    cmpa #15
    bls long_branch_126
    jmp settings_invalid
long_branch_126
    tst B_CFGDATA+11
    beq long_branch_127
    jmp settings_invalid
long_branch_127
    ldd B_CFGDATA+12
    beq long_branch_128
    jmp settings_invalid
long_branch_128
    jsr settings_checksum
    ldd B_CFGDATA+14
    subd B_CRC16
    beq long_branch_129
    jmp settings_invalid
long_branch_129
    ldaa B_CFGDATA+9
    staa B_SET_CURRENT
    ldaa B_CFGDATA+10
    staa B_SET_PART
    inc B_SET_VALID
settings_invalid
    clr B_SET_LOADING
    rts
settings_load_failed
    lds B_SET_LOAD_SP
    clr B_SET_LOADING
    clr B_SET_VALID
    clr B_SET_PART
    ldaa #2                 ; Existing valid P601.SET always takes priority.
    staa B_SET_CURRENT
    ldaa #$23
    staa B_SPI_CTL
    rts
settings_cluster_check
    ldd B_SET_CLUSTER
    subd #2
    bcc long_branch_130
    jmp settings_bad_cluster
long_branch_130
    ldaa B_SET_CLUSTER
    cmpa B_CLIMIT+1
    bls long_branch_131
    jmp settings_bad_cluster
long_branch_131
    bcc long_branch_132
    jmp settings_good_cluster
long_branch_132
    ldaa B_SET_CLUSTER+1
    cmpa B_CLIMIT
    bcs long_branch_133
    jmp settings_bad_cluster
long_branch_133
settings_good_cluster
    clc
    rts
settings_bad_cluster
    sec
    rts
settings_keep_root
    ldd B_LBA
    std B_SET_ROOT
    ldd B_LBA+2
    std B_SET_ROOT+2
    rts
settings_restore_root
    ldx #B_SET_ROOT
settings_copy_lba
    ldd 0,x
    std B_LBA
    ldd 2,x
    std B_LBA+2
    rts
settings_data_lba
    ldd B_SET_CLUSTER
    std B_CLUSTER
    clr B_SECI
    jmp cluster_lba
settings_fat_entry
    ldx #B_FATBASE
    jsr settings_copy_lba
    ldaa B_SET_CLUSTER
    staa B_TEMP
    clr B_TEMP+1
    clr B_TEMP+2
    clr B_TEMP+3
    ldx #B_TEMP
    jsr add_lba
    jsr read_sector
    ldx #B_SECTOR
    ldab B_SET_CLUSTER+1
    aslb
    bcs long_branch_134
    jmp settings_fat_offset
long_branch_134
    ldx #B_SECTOR+256
settings_fat_offset
    abx
    stx B_ENTRY
    rts
settings_checksum
    clr B_CRC16
    clr B_CRC16+1
    ldx #B_CFGDATA
settings_checksum_byte
    ldaa 0,x
    jsr settings_crc_byte
    inx
    cpx #B_CFGDATA+14
    beq long_branch_135
    jmp settings_checksum_byte
long_branch_135
    rts
settings_crc_byte
    pshx
    psha
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
    pula
    pulx
    rts
settings_copy
    ; B_LEFT is a big-endian even byte count; source and destination are RAM/ROM.
    ldx B_SET_SOURCE
    ldd 0,x
    inx
    inx
    stx B_SET_SOURCE
    ldx B_SET_DEST
    std 0,x
    inx
    inx
    stx B_SET_DEST
    ldd B_LEFT
    subd #2
    std B_LEFT
    beq long_branch_136
    jmp settings_copy
long_branch_136
    rts
settings_save
    ; Keep existing allocation unchanged; create a one-cluster file if absent.
    ldaa B_SET_FATCOPIES
    cmpa #1
    bcc long_branch_137
    jmp failed
long_branch_137
    cmpa #2
    bls long_branch_138
    jmp failed
long_branch_138
    clr B_SET_ATTR
    ldx #settings_name
    jsr file_find
    bcc long_branch_139
    jmp settings_create
long_branch_139
    stx B_SET_ENTRY
    jsr settings_keep_root
    ldaa 11,x
    bita #1
    beq long_branch_140
    jmp failed
long_branch_140
    ldd 28,x
    subd #$1000
    beq long_branch_141
    jmp failed
long_branch_141
    ldd 30,x
    beq long_branch_142
    jmp failed
long_branch_142
    ldaa 27,x
    ldab 26,x
    std B_SET_CLUSTER
    jsr settings_cluster_check
    bcc long_branch_143
    jmp failed
long_branch_143
    jsr settings_fat_entry
    ldaa 1,x
    cmpa #$ff
    beq long_branch_144
    jmp failed
long_branch_144
    ldaa 0,x
    cmpa #$f8
    bcc long_branch_145
    jmp failed
long_branch_145
    jmp settings_write_data
settings_create
    inc B_SET_ATTR
    jsr settings_empty_root
    ldd #2
    std B_SET_CLUSTER
settings_free_sector
    jsr settings_cluster_check
    bcc long_branch_147
    jmp failed
long_branch_147
    jsr settings_fat_entry
settings_free_entry
    ldd 0,x
    bne long_branch_148
    jmp settings_write_data
long_branch_148
    ldd B_SET_CLUSTER
    addd #1
    std B_SET_CLUSTER
    jsr settings_cluster_check
    bcc long_branch_149
    jmp failed
long_branch_149
    ldaa B_SET_CLUSTER+1
    bne long_branch_150
    jmp settings_free_sector
long_branch_150
    inx
    inx
    jmp settings_free_entry
settings_write_data
    ldx #settings_magic
    stx B_SET_SOURCE
    ldx #B_CFGDATA
    stx B_SET_DEST
    ldd #14
    std B_LEFT
    jsr settings_copy
    ldaa B_SET_CURRENT
    staa B_CFGDATA+9
    ldaa B_SET_PART
    staa B_CFGDATA+10
    jsr settings_checksum
    ldd B_CRC16
    std B_CFGDATA+14
    jsr settings_data_lba
    ldx #B_SECTOR
settings_clear_sector
    clr 0,x
    inx
    cpx #B_SECTOR+512
    beq long_branch_152
    jmp settings_clear_sector
long_branch_152
    ldx #B_CFGDATA
    stx B_SET_SOURCE
    ldx #B_SECTOR
    stx B_SET_DEST
    ldd #16
    std B_LEFT
    jsr settings_copy
    jsr settings_write_checked
    tst B_SET_ATTR
    bne long_branch_153
    jmp settings_save_verify
long_branch_153
    jsr settings_fat_entry
    ldaa #$ff
    staa 0,x
    staa 1,x
    clr B_SET_COPY
settings_allocate_fat
    jsr settings_write_checked
    inc B_SET_COPY
    ldaa B_SET_COPY
    cmpa B_SET_FATCOPIES
    bcs long_branch_154
    jmp settings_publish
long_branch_154
    ldaa B_SET_FATSIZE+1
    staa B_TEMP
    ldaa B_SET_FATSIZE
    staa B_TEMP+1
    clr B_TEMP+2
    clr B_TEMP+3
    ldx #B_TEMP
    jsr add_lba
    jsr read_sector
    ldx B_ENTRY
    ldaa 0,x
    oraa 1,x
    beq long_branch_155
    jmp failed
long_branch_155
    ldaa #$ff
    staa 0,x
    staa 1,x
    jmp settings_allocate_fat
settings_publish
    jsr settings_restore_root
    jsr read_sector
    ldx B_SET_ENTRY
    ldaa 0,x
    bne long_branch_157
    jmp settings_root_free
long_branch_157
    cmpa #$e5
    beq long_branch_158
    jmp failed
long_branch_158
settings_root_free
    ldab #32
settings_clear_entry
    clr 0,x
    inx
    decb
    beq long_branch_159
    jmp settings_clear_entry
long_branch_159
    ldx #settings_name
    stx B_SET_SOURCE
    ldx B_SET_ENTRY
    stx B_SET_DEST
    ldab #11
settings_publish_name
    ldx B_SET_SOURCE
    ldaa 0,x
    inx
    stx B_SET_SOURCE
    ldx B_SET_DEST
    staa 0,x
    inx
    stx B_SET_DEST
    decb
    beq long_branch_160
    jmp settings_publish_name
long_branch_160
    ldx B_SET_ENTRY
    ldaa #$20
    staa 11,x
    ldaa B_SET_CLUSTER+1
    staa 26,x
    ldaa B_SET_CLUSTER
    staa 27,x
    ldaa #16
    staa 28,x
    ldaa #$21
    staa 16,x
    staa 18,x
    staa 24,x
    jsr settings_write_checked
settings_save_verify
    ldaa B_SET_CURRENT
    psha
    ldaa B_SET_PART
    psha
    jsr settings_load
    pula
    cmpa B_SET_PART
    beq long_branch_161
    jmp failed
long_branch_161
    pula
    tst B_SET_VALID
    bne long_branch_162
    jmp failed
long_branch_162
    cmpa B_SET_CURRENT
    beq long_branch_163
    jmp failed
long_branch_163
    rts
settings_empty_root
    ldx #B_ROOTBASE
    jsr settings_copy_lba
settings_empty_sector
    jsr read_sector
    ldx #B_SECTOR
settings_empty_entry
    ldaa 0,x
    bne long_branch_164
    jmp settings_empty_found
long_branch_164
    cmpa #$e5
    bne long_branch_165
    jmp settings_empty_found
long_branch_165
    ldab #32
    abx
    cpx #B_SECTOR+512
    beq long_branch_166
    jmp settings_empty_entry
long_branch_166
    jsr increment_lba
    ldd B_LBA
    subd B_DATABASE
    beq long_branch_167
    jmp settings_empty_sector
long_branch_167
    ldd B_LBA+2
    subd B_DATABASE+2
    beq long_branch_168
    jmp settings_empty_sector
long_branch_168
    jmp failed
settings_empty_found
    stx B_SET_ENTRY
    jmp settings_keep_root
settings_write_checked
    ; Snapshot all 512 bytes before SPI changes shared buffers. Verify the
    ; complete sector after CMD24, including accepted token and busy release.
    ldx #B_SECTOR
    stx B_SET_SOURCE
    ldx #B_SAVEBUF
    stx B_SET_DEST
    ldd #512
    std B_LEFT
    jsr settings_copy
    jsr settings_write_sector
    jsr read_sector
    ldx #B_SECTOR
    stx B_SET_SOURCE
    ldx #B_SAVEBUF
    stx B_SET_DEST
settings_compare_sector
    ldx B_SET_SOURCE
    ldd 0,x
    inx
    inx
    stx B_SET_SOURCE
    ldx B_SET_DEST
    subd 0,x
    beq long_branch_169
    jmp failed
long_branch_169
    inx
    inx
    stx B_SET_DEST
    cpx #B_SAVEBUF+512
    beq long_branch_170
    jmp settings_compare_sector
long_branch_170
    rts
settings_write_sector
    ldd B_LBA
    std B_ARG
    ldd B_LBA+2
    std B_ARG+2
    ldaa B_SDMODE
    beq long_branch_171
    jmp settings_write_addressed
long_branch_171
    ldaa B_ARG+3
    beq long_branch_172
    jmp failed
long_branch_172
    ldaa B_ARG+2
    bpl long_branch_173
    jmp failed
long_branch_173
    ldab #9
settings_write_shift
    asl B_ARG
    rol B_ARG+1
    rol B_ARG+2
    rol B_ARG+3
    decb
    beq long_branch_174
    jmp settings_write_shift
long_branch_174
settings_write_addressed
    ldaa #$58
    staa B_COMMAND
    ldaa #1
    staa B_CHECK
    jsr command
    beq long_branch_175
    jmp failed
long_branch_175
    jsr spi_read
    ldaa #$fe
    jsr spi
    clr B_CRC16
    clr B_CRC16+1
    ldx #B_SECTOR
settings_write_byte
    ldaa 0,x
    jsr settings_crc_byte
    jsr spi
    inx
    cpx #B_SECTOR+512
    beq long_branch_176
    jmp settings_write_byte
long_branch_176
    ldaa B_CRC16
    jsr spi
    ldaa B_CRC16+1
    jsr spi
    ldab #32
settings_write_token
    jsr spi_read
    cmpa #$ff
    beq long_branch_177
    jmp settings_write_response
long_branch_177
    decb
    beq long_branch_178
    jmp settings_write_token
long_branch_178
    jmp failed
settings_write_response
    anda #$1f
    cmpa #5
    beq long_branch_179
    jmp failed
long_branch_179
    ldx #$ffff
settings_write_busy
    jsr spi_read
    cmpa #$ff
    bne long_branch_180
    jmp settings_write_done
long_branch_180
    ; Busy release can occur inside this byte (01/03/.../7F). Keep clocking
    ; until an entire idle FF byte; these transitions are not write errors.
    dex
    beq long_branch_181
    jmp settings_write_busy
long_branch_181
    jmp failed
settings_write_done
    jmp release
; Initial SD power-up uses PAL's 50 Hz latch, independently of CPU loops.
; Sixteen ticks provide >=300 ms from clearing a pending tick. Keep CS high
; and MOSI idle before CMD0; repeat >=74 clocks before every CMD0 attempt.
sd_init
    clr B_SD_INIT_PHASE
    ldaa #$ff
    staa B_COMMAND
    staa B_RESPONSE
    ldaa #$23
    staa B_SPI_CTL
    ldaa #29
    staa B_SPI_DIV
    jsr spi_read
    ldaa $e62b
    ldaa #16
    staa B_SD_INIT_TICKS
sd_power
    jsr sd_wait_tick
    dec B_SD_INIT_TICKS
    bne sd_power
    jsr sd_start_deadline
sd_cmd0
    ldaa #1
    staa B_SD_INIT_PHASE
    ldab #10
sd_clocks
    jsr spi_read
    decb
    bne sd_clocks
    jsr clear_arg
    ldaa #$40
    staa B_COMMAND
    ldaa #$95
    staa B_CHECK
    jsr command_try
    cmpa #1
    beq sd_cmd8_start
    jsr sd_retry_pause
    bra sd_cmd0
sd_cmd8_start
    ldaa #2
    staa B_SD_INIT_PHASE
    jsr sd_start_deadline
sd_cmd8
    jsr clear_arg
    ldaa #$48
    staa B_COMMAND
    ldaa #$aa
    staa B_ARG
    ldaa #1
    staa B_ARG+1
    ldaa #$87
    staa B_CHECK
    jsr command_try
    cmpa #$ff
    bne sd_cmd8_reply
    jsr sd_retry_pause
    bra sd_cmd8
sd_cmd8_reply
    clr B_SDMODE
    cmpa #5
    beq sd_v1
    cmpa #1
    beq long_branch_182
    jmp failed
long_branch_182
    jsr spi_read
    jsr spi_read
    jsr spi_read
    cmpa #1
    beq long_branch_183
    jmp failed
long_branch_183
    jsr spi_read
    cmpa #$aa
    beq long_branch_184
    jmp failed
long_branch_184
    ldaa #$40
    staa B_SDMODE
sd_v1
    ldaa #3
    staa B_SD_INIT_PHASE
    jsr sd_start_deadline
sd_acmd
    jsr clear_arg
    ldaa #$77
    staa B_COMMAND
    jsr command_try
    cmpa #$ff
    beq sd_acmd_retry
    cmpa #1
    bls long_branch_185
    jmp failed
long_branch_185
    jsr clear_arg
    ldaa B_SDMODE
    staa B_ARG+3
    ldaa #$69
    staa B_COMMAND
    jsr command_try
    beq sd_ocr
    cmpa #$ff
    beq sd_acmd_retry
    cmpa #1
    beq long_branch_186
    jmp failed
long_branch_186
sd_acmd_retry
    jsr sd_retry_pause
    bra sd_acmd
sd_ocr
    ldaa #4
    staa B_SD_INIT_PHASE
    jsr clear_arg
    ldaa #$7a
    staa B_COMMAND
    jsr command
    beq long_branch_187
    jmp failed
long_branch_187
    jsr spi_read
    bita #$80
    bne long_branch_188
    jmp failed
long_branch_188
    anda B_SDMODE
    anda #$40
    staa B_SDMODE
    jsr spi_read
    jsr spi_read
    jsr spi_read
    ldaa B_SDMODE
    bne sd_initialized
    ldaa #5
    staa B_SD_INIT_PHASE
    jsr clear_arg
    ldaa #2
    staa B_ARG+1
    ldaa #$50
    staa B_COMMAND
    jsr command
    beq long_branch_189
    jmp failed
long_branch_189
sd_initialized
    jsr release
    ldaa #1
    staa B_SPI_DIV
    rts
; Each phase permits about two seconds. Wait between attempts with CS high;
; a received protocol error still fails, except CMD0 which explicitly resets.
sd_start_deadline
    ldaa $e62b
    ldaa #101
    staa B_SD_INIT_TICKS
    rts
sd_retry_pause
    jsr release
    jsr sd_wait_tick
    dec B_SD_INIT_TICKS
    bne long_branch_190
    jmp failed
long_branch_190
    rts
; Preserve X/B and also bound the wait if PAL's tick source ever stops.
sd_wait_tick
    pshx
    ldx #0
sd_wait_tick_poll
    ldaa $e62b
    bmi sd_wait_tick_done
    dex
    bne sd_wait_tick_poll
    pulx
    jmp failed
sd_wait_tick_done
    pulx
    rts
; Permanent boot error context: phase, last CMD/R1, failing A and SPI status.
; This distinguishes a tick/READY timeout from a rejected card response.
sd_error_details
    ldx #$5e0
    stx B_UI_DEST
    ldx #sd_error_text
    jsr ui_puts
    ldaa B_SD_INIT_PHASE
    jsr ui_hex
    ldab #' '
    jsr ui_putc
    ldaa B_COMMAND
    jsr ui_hex
    ldab #' '
    jsr ui_putc
    ldaa B_RESPONSE
    jsr ui_hex
    ldab #' '
    jsr ui_putc
    ldaa B_SD_ERROR_VALUE
    jsr ui_hex
    ldab #' '
    jsr ui_putc
    ldaa B_SD_ERROR_IO
    jmp ui_hex
sd_error_text
    db "SD PH/CMD/R1/A/IO ",0
setup_notice
    db "PRESS DEL FOR BIOS SETUP",0
setup_countdown_text
    db "BOOT IN ",0
setup_seconds_text
    db " SECONDS",0
setup_title
    db "PYLDIN BIOS SETUP",0
setup_summary_title
    db "PYLDIN SYSTEM BIOS",0
setup_labels
    dw setup_model,setup_cpu,setup_freq,setup_partition,setup_save_text,setup_nosave,setup_exit_text
setup_model
    db "MODEL                  ",0
setup_cpu
    db "CPU HD6303 EXTENSION    ",0
setup_freq
    db "CPU FREQ               ",0
setup_partition
    db "BOOT PARTITION         ",0
setup_auto
    db "AUTO",0
setup_sdpart
    db "SD0:PART",0
setup_save_text
    db "SAVE AND BOOT",0
setup_nosave
    db "BOOT WITHOUT SAVE",0
setup_exit_text
    db "EXIT AND BOOT",0
setup_601
    db "601",0
setup_601a
    db "601A",0
setup_mhz
    db " MHz",0
setup_help
    db "ARROWS SELECT/CHANGE  ENTER CONFIRM",0
setup_missing
    db "NO VALID CONFIGURATION",0
setup_save_error
    db "SAVE FAILED - CHECK SD",0
settings_name
    db "P601    SET"
settings_magic
    db "P601SET",0,2,0,0,0,0,0
setup_end
