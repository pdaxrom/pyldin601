; Small disposable PGM prefix plus resident SWI gates and records.
    include RAMABI.INC
start
    ldx #bss_start
loader_zero
    clr 0,x
    inx
    cpx #bss_end
    bne loader_zero
    ldx #registry
    stx control+C_REG
    ldx #gate_template
    stx control+C_TEMPLATE
    ldx #manager_gateway
    stx control+C_GATEWAY
    ldaa #1
    staa control+C_FIRST
    ldaa #RL_INT
    int $2e
    cpx #0
    beq loader_self
    stx load_ptr
    ldaa load_ptr
    cmpa #1
    bcc *+5
    jmp LOADER_CONFLICT
    cmpa #$bd
    bcs *+5
    jmp LOADER_CONFLICT
    ldaa 0,x
    cmpa #$7e
    beq *+5
    jmp LOADER_CONFLICT
    ldaa 3,x
    cmpa #'R'
    beq *+5
    jmp LOADER_CONFLICT
    ldaa 4,x
    cmpa #'M'
    beq *+5
    jmp LOADER_CONFLICT
    ldaa 5,x
    cmpa #'L'
    beq *+5
    jmp LOADER_CONFLICT
    ldaa 6,x
    cmpa #1
    beq *+5
    jmp LOADER_CONFLICT
    ldaa 11,x
    cmpa #RL_SLOTS
    beq *+5
    jmp LOADER_CONFLICT
    ldaa 12,x
    cmpa #RL_RECORD
    beq *+5
    jmp LOADER_CONFLICT
    stx control+C_GATEWAY
    ldaa 7,x
    staa control+C_REG
    ldaa 8,x
    staa control+C_REG+1
    ldaa 9,x
    staa control+C_TEMPLATE
    ldaa 10,x
    staa control+C_TEMPLATE+1
    clr control+C_FIRST
loader_self
    clra
    ldx #load_argument
    int $3c
    ldx #load_argument
    stx load_open
    ldx #load_path
    stx load_open+2
    ldx #load_open
    int $3f
    tsta
    beq *+5
    jmp loader_error
    ; UniDOS leaves the executable suffix out of argv[0] when it was omitted.
    ldx #load_path
    clrb
loader_path_scan
    ldaa 0,x
    beq loader_path_end
    cmpa #'\\'
    beq loader_path_component
    cmpa #':'
    bne loader_path_dot
loader_path_component
    clr load_dot
loader_path_dot
    cmpa #'.'
    bne loader_path_next
    inc load_dot
loader_path_next
    inx
    incb
    cmpb #75
    bcs loader_path_scan
    jmp loader_bad
loader_path_end
    tst load_dot
    bne loader_path_ready
    ldaa #'.'
    staa 0,x
    ldaa #'P'
    staa 1,x
    ldaa #'G'
    staa 2,x
    ldaa #'M'
    staa 3,x
    clr 4,x
loader_path_ready
    ldx #load_path
    stx control+C_PATH
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
    ldx $ee1e
    stx load_previous
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
    ldx #control
    stx load_target
    ldx load_base
    ldaa load_target
    staa 3,x
    ldaa load_target+1
    staa 4,x
    ldx load_entry
    jsr 0,x
    ldx load_previous
    int $2b
    jmp resident_finish
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
load_message db 10,'RAMLOAD: ',0
loader_conflict
    ldx #conflict_message
    int $23
    ldaa #80
    int $38
conflict_message db 'RAMLOAD: INT EC already in use.',13,10,0
; Initialized prefix workspace is released with the disposable loader.
load_previous db 0,0
load_dot db 0
load_argument db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0
load_path db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0
load_buffer db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
load_open db 0,0,0,0
load_io db 0,0,0,0
load_handle db 0
load_live db 0
load_payload db 0,0
load_position db 0,0,0,0
load_records db 0,0
load_code_offset db 0,0
load_code_size db 0,0
load_reloc_limit db 0,0
load_entry db 0,0
load_ram db 0,0
load_base db 0,0
load_ptr db 0,0
load_target db 0,0
load_block_records db 0
load_error db 0
; Everything before this label is discarded on the first successful load.
; Resident code never references the disposable prefix or the core allocation.
resident_start
resident_finish
    tst control+C_FIRST
    beq resident_exit
    tst control+C_KEEP
    beq resident_exit
    ldx #resident_start
    int $2b
    int $2c
    ldaa #RL_INT
    clrb
    ldx #manager_gateway
    int $2f
resident_exit
    ldaa control+C_ERROR
    int $38
manager_gateway
    jmp manager_dispatch
    db 'R','M','L',1
    dw registry,gate_template
    db RL_SLOTS,RL_RECORD
manager_dispatch
    tsta
    bne manager_bad
    ldaa #1
    staa $06
    ldaa #RL_SLOTS
    staa $05
    ldx #registry
    stx $07
    rts
manager_bad
    ldaa #1
    staa $06
    rts
; SWI-only entry. Inline data belongs to a compiled, relocated gate template.
; Keep all call state on the ordinary stack so nested calls are independent.
module_gate
    tsx
    ldx 0,x
    ldx 4,x
    inc 0,x
    bne module_enter
    dec 0,x
    ldaa #5
    staa $06
    ins
    ins
    rts
module_enter
    ldaa $e6f0
    psha
    ldaa $e6f1
    psha
    tsx
    ldx 2,x
    ldaa 0,x
    staa $e6f1
    ldaa 1,x
    staa $e6f0
    ; Arrange RTS -> module -> module_return, then restore SWI inputs.
    ldaa module_return_address+1
    psha
    ldaa module_return_address
    psha
    ldaa 3,x
    psha
    ldaa 2,x
    psha
    ldaa $04
    tap
    ldx $07
    ldab $05
    ldaa $06
    rts
module_return
    sei
    pula
    staa $e6f1
    pula
    staa $e6f0
    tsx
    ldx 0,x
    ldx 4,x
    dec 0,x
    ins
    ins
    rts
gate_template
    jsr module_gate
    db 0,0
    dw 0,0
    db 0
module_return_address dw module_return
    section
bss_start
control ds 11
registry ds RL_SLOTS*RL_RECORD
bss_end
    ends
    end start
