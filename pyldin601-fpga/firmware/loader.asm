; Stage two runs in ordinary RAM. It fills physical ROM through a boot-only port,
; verifies CRC32, clears cold RAM/electronic disk, hands off through the resident BIOS RAM trampoline.
OPEN equ $f003
GET equ $f006
FAIL equ $f009
STATUS equ $f00f
PROGRESS equ $f012
SIZE equ $100
ADDR equ $e6a4
STORE equ $e6a7
MEMSTATUS equ $e6a8
CRCFEED equ $e6a9
CRCRESET equ $e6aa
CRC equ $e6ac
COMMIT equ $e6a0
CONFIG equ $e6a3
PTR equ $80
LEFT equ $82
BLOCKS equ $84
TMP equ $85
    org $2000
    sei
    ldaa #4
    jsr STATUS
    ldx #rom_name
    jsr OPEN
    ldaa SIZE
    bne bad_size
    ldaa SIZE+1
    cmpa #$1a
    bne bad_size
    ldaa SIZE+2
    cmpa #5
    bne bad_size
    ldaa SIZE+3
    bne bad_size
    bra size_ok
bad_size:
    jmp FAIL
size_ok:
    ldaa #5
    jsr STATUS
    ldaa #1
    staa CRCRESET
    ldx #$1000
    stx PTR
    ldx #512
    stx LEFT
read_header:
    jsr GET
    ldx PTR
    staa 0,x
    ldaa LEFT
    bne header_crc_byte
    ldaa LEFT+1
    cmpa #5
    bcs no_header_crc
header_crc_byte:
    ldaa 0,x
    staa CRCFEED
no_header_crc:
    inx
    stx PTR
    ldx LEFT
    dex
    stx LEFT
    bne read_header
    ldx #$1000
    ldaa 0,x
    cmpa #'P'
    bne bad
    ldaa 1,x
    cmpa #'6'
    bne bad
    ldaa 2,x
    cmpa #'0'
    bne bad
    ldaa 3,x
    cmpa #'1'
    bne bad
    ldaa CRC
    cmpa $11fc
    bne bad
    ldaa CRC+1
    cmpa $11fd
    bne bad
    ldaa CRC+2
    cmpa $11fe
    bne bad
    ldaa CRC+3
    cmpa $11ff
    bne bad
    jmp header_ok
bad:
    jmp FAIL
header_ok:
    ; Provide ROM header and the MBR entries mounted by resident CPU firmware.
    ldx #$1000
    clrb
config_copy:
    ldaa 0,x
    staa CONFIG
    inx
    incb
    cmpb #64
    bne config_copy
    ldx #$150
    ldab #32
partition_copy:
    ldaa 0,x
    staa CONFIG
    inx
    decb
    bne partition_copy
    clr ADDR
    clr ADDR+1
    ldaa #1
    staa ADDR+2
    staa CRCRESET
    ldaa #5
    staa BLOCKS
    ldaa #6
    jsr STATUS
payload_block:
    ldaa #6
    suba BLOCKS
    ldab #5
    jsr PROGRESS
    clr LEFT
    clr LEFT+1
payload_byte:
    jsr GET
    staa STORE
    jsr mem_wait
    staa CRCFEED
    ldx LEFT
    dex
    stx LEFT
    bne payload_byte
    dec BLOCKS
    bne payload_block
    ldaa #7
    jsr STATUS
    ldx #$1800
    stx LEFT
payload_tail:
    jsr GET
    staa STORE
    jsr mem_wait
    staa CRCFEED
    ldx LEFT
    dex
    stx LEFT
    bne payload_tail
    ldaa #8
    jsr STATUS
    ldaa CRC
    cmpa $1014
    bne bad_payload
    ldaa CRC+1
    cmpa $1015
    bne bad_payload
    ldaa CRC+2
    cmpa $1016
    bne bad_payload
    ldaa CRC+3
    cmpa $1017
    bne bad_payload
    ; Resident handoff clears $0000-$2FFF after leaving this loader.
    ; Do not erase the executing loader, stack, header or zero-page variables.
    ldaa #9
    jsr STATUS
    clr ADDR
    ldaa #$30
    staa ADDR+1
    clr ADDR+2
    ldx #$d000
    stx LEFT
    jsr clear_region
    ldaa #10
    jsr STATUS
    clr ADDR
    clr ADDR+1
    ldaa #8
    staa ADDR+2
    staa BLOCKS
clear_disk:
    ldaa #9
    suba BLOCKS
    ldab #8
    jsr PROGRESS
    clr LEFT
    clr LEFT+1
    jsr clear_region
    dec BLOCKS
    bne clear_disk
    ; Resident BIOS installs a RAM trampoline and clears the loader/stack itself.
    jmp $f00c
bad_payload:
    jmp FAIL
clear_region:
    clra
clear_byte:
    staa STORE
    jsr mem_wait
    ldx LEFT
    dex
    stx LEFT
    bne clear_byte
    rts
mem_wait:
    psha
mem_poll:
    ldaa MEMSTATUS
    bmi mem_failed
    bita #1
    bne mem_poll
    pula
    rts
mem_failed:
    jmp FAIL
rom_name:
    db "P601    ROM"
