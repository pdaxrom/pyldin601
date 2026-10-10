; Direct physical SD and graphics/audio services, page B, MC6800 compatible.
; INT E2 exposes capacity and 512-byte I/O with a full 32-bit physical LBA.
; INT 17 only retains the native BIOS periodic motor-tick no-op (A=FF).
; Private SD scratch replaces unused FDC variables ED61..ED7B/ED7E..ED7F.
; Preserve native keyboard/pseudo-RS bytes ED7C and ED7D.
SPI_DATA equ $e661
SPI_CTL equ $e662
SPI_DIV equ $e663
SD_INFO equ $e6a2
SWIA equ $06
SWIB equ $05
SYS_LINE equ $ed20
INIT_BUF equ $ed73
FORMAT_LEFT equ $ed79
SAVED_SP equ $ed7e
BUF equ $ed61
COUNT equ $ed63
ARG equ $ed65
LBA equ $ed69
CMD equ $ed6d
STATUS equ $ed6e
CRC equ $ed6f
CRCPTR equ $ed71
PARAM equ $ed75
OP equ $ed77
FILL equ $ed78
    org $c000
    dw $a55a
    db "FPGABIOS"
    jmp init
    jmp version
    db $17
    dw timer_noop
    db $e0
    dw services
    db $e2
    dw rawsd
    db 0
version
init
    rts
timer_noop
    cmpa #$ff
    beq timer_return
    ldaa #$80
    staa SWIA
timer_return
    rts
address_bad
    ldaa #4
    staa STATUS
    rts
    include RAWSD.ASM
indicator
    ldx SYS_LINE
    staa 81,x
    rts
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
