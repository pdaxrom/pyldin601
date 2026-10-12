; Stage two runs in ordinary RAM. It fills physical ROM through a boot-only port,
; verifies CRC32, clears cold RAM, hands off through the resident BIOS RAM trampoline.
B_OPEN equ $f003
B_GET equ $f006
B_FAIL equ $f009
B_STATUS equ $f00f
B_PROGRESS equ $f012
B_SIZE equ $100
B_ADDR equ $e6a4
B_STORE equ $e6a7
B_MEMSTATUS equ $e6a8
B_CRCFEED equ $e6a9
B_CRCRESET equ $e6aa
B_CRC equ $e6ac
B_COMMIT equ $e6a0
B_CONFIG equ $e6a3
B_PTR equ $80
B_LEFT equ $82
B_BLOCKS equ $84
B_TMP equ $85
    org $2000
    sei
    ldaa #4
    jsr B_STATUS
    ldx #rom_name
    ldaa B_COMMIT
    bita #1
    beq selected_rom
    ldx #rom_a_name
selected_rom
    jsr B_OPEN
    ldaa B_SIZE
    bne bad_size
    ldaa B_SIZE+1
    cmpa #$1a
    bne bad_size
    ldaa B_SIZE+2
    cmpa #1
    bne bad_size
    ldaa B_SIZE+3
    bne bad_size
    bra size_ok
bad_size
    jmp B_FAIL
size_ok
    ldaa #5
    jsr B_STATUS
    ldaa #1
    staa B_CRCRESET
    ldx #$1000
    stx B_PTR
    ldx #512
    stx B_LEFT
read_header
    jsr B_GET
    ldx B_PTR
    staa 0,x
    ldaa B_LEFT
    bne header_crc_byte
    ldaa B_LEFT+1
    cmpa #5
    bcs no_header_crc
header_crc_byte
    ldaa 0,x
    staa B_CRCFEED
no_header_crc
    inx
    stx B_PTR
    ldx B_LEFT
    dex
    stx B_LEFT
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
    ldaa B_CRC
    cmpa $11fc
    bne bad
    ldaa B_CRC+1
    cmpa $11fd
    bne bad
    ldaa B_CRC+2
    cmpa $11fe
    bne bad
    ldaa B_CRC+3
    cmpa $11ff
    bne bad
    jmp header_ok
bad
    jmp B_FAIL
header_ok
    ldaa B_COMMIT
    anda #1
    cmpa $1019
    beq long_branch_1
    jmp B_FAIL
long_branch_1
    ; Provide only the compact ROM header; runtime firmware scans MBR/EBR.
    ldx #$1000
    clrb
config_copy
    ldaa 0,x
    staa B_CONFIG
    inx
    incb
    cmpb #64
    bne config_copy
    clr B_ADDR
    clr B_ADDR+1
    ldaa #1
    staa B_ADDR+2
    staa B_CRCRESET
    ldaa #1
    staa B_BLOCKS
    ldaa #6
    jsr B_STATUS
payload_block
    ldaa #2
    suba B_BLOCKS
    ldab #1
    jsr B_PROGRESS
    clr B_LEFT
    clr B_LEFT+1
payload_byte
    jsr B_GET
    staa B_STORE
    jsr mem_wait
    staa B_CRCFEED
    ldx B_LEFT
    dex
    stx B_LEFT
    bne payload_byte
    dec B_BLOCKS
    bne payload_block
    ldaa #7
    jsr B_STATUS
    ldx #$1800
    stx B_LEFT
payload_tail
    jsr B_GET
    staa B_STORE
    jsr mem_wait
    staa B_CRCFEED
    ldx B_LEFT
    dex
    stx B_LEFT
    bne payload_tail
    ldaa #8
    jsr B_STATUS
    ldaa B_CRC
    cmpa $1014
    bne bad_payload
    ldaa B_CRC+1
    cmpa $1015
    bne bad_payload
    ldaa B_CRC+2
    cmpa $1016
    bne bad_payload
    ldaa B_CRC+3
    cmpa $1017
    bne bad_payload
    ; Resident handoff clears $0000-$2FFF after leaving this loader.
    ; Do not erase the executing loader, stack, header or zero-page variables.
    ldaa #9
    jsr B_STATUS
    clr B_ADDR
    ldaa #$30
    staa B_ADDR+1
    clr B_ADDR+2
    ldx #$d000
    stx B_LEFT
    jsr clear_region
    ; Resident BIOS installs a RAM trampoline and clears the loader/stack itself.
    jmp $f00c
bad_payload
    jmp B_FAIL
clear_region
    clra
clear_byte
    staa B_STORE
    jsr mem_wait
    ldx B_LEFT
    dex
    stx B_LEFT
    bne clear_byte
    rts
mem_wait
    psha
mem_poll
    ldaa B_MEMSTATUS
    bmi mem_failed
    bita #1
    bne mem_poll
    pula
    rts
mem_failed
    jmp B_FAIL
rom_name
    db "P601    ROM"
rom_a_name
    db "P601A   ROM"
    end
