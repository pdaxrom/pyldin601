; Small native PGM prefix. Its packed editor payload follows this PGM's code.
; Stream relocation records through 64 bytes instead of reserving the entire
; table in low RAM. This matters while 16K native graphics memory is allocated.
start
    ldx #bss_start
loader_zero
    clr 0,x
    inx
    cpx #bss_end
    bne loader_zero
    clra
    ldx #load_path
    int $3c
    ldx #load_path
    stx load_open
    ldx #0
    stx load_open+2
    ldaa #1
    ldx #load_open
    int $4a
    tsta
    beq loader_opened
    jmp loader_error
loader_opened
    stab load_handle
    inc load_live
    jsr loader_header
    tsta
    beq loader_outer_header
    jmp loader_error
loader_outer_header
    ldaa load_buffer+5
    adda load_buffer+7
    staa load_payload+1
    ldaa load_buffer+4
    adca load_buffer+6
    staa load_payload
    ldx load_payload
    stx load_position+2
    jsr loader_seek
    tsta
    beq loader_payload_header
    jmp loader_error
loader_payload_header
    jsr loader_header
    tsta
    beq loader_validate
    jmp loader_error
loader_validate
    ldx load_buffer
    cpx #$a55a
    beq loader_sizes
    jmp loader_bad
loader_sizes
    ; Validate the inner PGM before allocating or applying any relocation.
    ldaa load_buffer+3
    ldab load_buffer+2
    asla
    rolb
    bcc *+5
    jmp loader_bad
    adda #16
    adcb #0
    bcc *+5
    jmp loader_bad
    cmpb load_buffer+4
    beq *+5
    jmp loader_bad
    cmpa load_buffer+5
    beq *+5
    jmp loader_bad
    ldaa load_buffer+8
    cmpa load_buffer+6
    bne loader_entry_compare
    ldaa load_buffer+9
    cmpa load_buffer+7
loader_entry_compare
    bcs *+5
    jmp loader_bad
    ldx load_buffer+6
    dex
    stx load_reloc_limit
    ldx load_buffer+2
    stx load_records
    ldx load_buffer+4
    stx load_code_offset
    ldx load_buffer+6
    stx load_code_size
    ldx load_buffer+8
    stx load_entry
    ldaa load_buffer+7
    adda load_buffer+11
    staa load_ram+1
    ldaa load_buffer+6
    adca load_buffer+10
    staa load_ram
    bcc loader_allocate
    jmp loader_bad
loader_allocate
    ldx load_ram
    ldab #8
    int $2a
    cpx #0
    bne loader_allocated
    ldaa #66
    jmp loader_error
loader_allocated
    stx load_base
    ldaa load_payload+1
    adda load_code_offset+1
    staa load_position+3
    ldaa load_payload
    adca load_code_offset
    staa load_position+2
    jsr loader_seek
    tsta
    beq loader_read_code
    jmp loader_error
loader_read_code
    ldx load_base
    stx load_io
    ldx load_code_size
    stx load_io+2
    ldaa load_handle
    ldx #load_io
    int $4c
    tsta
    beq loader_code_read
    jmp loader_error
loader_code_read
    cpx load_code_size
    beq loader_seek_records
    jmp loader_bad
loader_seek_records
    ldaa load_payload+1
    adda #16
    staa load_position+3
    ldaa load_payload
    adca #0
    staa load_position+2
    jsr loader_seek
    tsta
    beq loader_relocation_block
    jmp loader_error
loader_relocation_block
    ldx load_records
    cpx #0
    bne *+5
    jmp loader_ready
    ldaa load_records
    bne loader_full_block
    ldaa load_records+1
    cmpa #32
    bhi loader_full_block
    staa load_block_records
    clrb
    asla
    rolb
    staa load_io+3
    stab load_io+2
    bra loader_read_records
loader_full_block
    ldaa #32
    staa load_block_records
    ldx #64
    stx load_io+2
loader_read_records
    ldx #load_buffer
    stx load_io
    ldaa load_handle
    ldx #load_io
    int $4c
    tsta
    beq loader_records_read
    jmp loader_error
loader_records_read
    cpx load_io+2
    beq *+5
    jmp loader_bad
    ldx #load_buffer
    stx load_ptr
loader_relocate
    ldx load_ptr
    ldaa 1,x
    ldab 0,x
    cmpb load_reloc_limit
    bne loader_reloc_compare
    cmpa load_reloc_limit+1
loader_reloc_compare
    bcs loader_reloc_valid
    jmp loader_bad
loader_reloc_valid
    adda load_base+1
    adcb load_base
    staa load_target+1
    stab load_target
    ldx load_target
    ldaa 0,x
    adda load_base
    staa 0,x
    ldx load_ptr
    inx
    inx
    stx load_ptr
    ldx load_records
    dex
    stx load_records
    dec load_block_records
    bne loader_relocate
    jmp loader_relocation_block
loader_ready
    ldaa load_handle
    int $4e
    clr load_live
    tsta
    bne loader_error
    ldaa load_entry+1
    adda load_base+1
    staa load_entry+1
    ldaa load_entry
    adca load_base
    staa load_entry
    ; The prefix is no longer executed after this jump. Its first 768 bytes
    ; become the viewport's first rows; the native child still owns them.
    ldx #start
    stx load_target
    ldaa load_target
    ldab load_target+1
    ldx load_entry
    jmp 0,x
loader_header
    ldx #load_buffer
    stx load_io
    ldx #16
    stx load_io+2
    ldaa load_handle
    ldx #load_io
    int $4c
    tsta
    bne loader_header_return
    cpx #16
    beq *+5
    jmp loader_bad
    clra
loader_header_return
    rts
loader_seek
    ldaa load_handle
    clrb
    ldx #load_position
    int $50
    rts
loader_bad
    ldaa #65
loader_error
    staa load_error
    tst load_live
    beq loader_report
    ldaa load_handle
    int $4e
loader_report
    ldaa load_error
    ldx #load_buffer
    int $3d
    ldx #load_message
    int $23
    ldx #load_buffer
    int $23
    int $20
    int $38
load_message db 10,'NC editor: ',0
    section
bss_start
load_path ds 81
load_buffer ds 64
load_open ds 4
load_io ds 4
load_handle ds 1
load_live ds 1
load_payload ds 2
load_position ds 4
load_records ds 2
load_code_offset ds 2
load_code_size ds 2
load_reloc_limit ds 2
load_entry ds 2
load_ram ds 2
load_base ds 2
load_ptr ds 2
load_target ds 2
load_block_records ds 1
load_error ds 1
bss_end
    ends
    end start
