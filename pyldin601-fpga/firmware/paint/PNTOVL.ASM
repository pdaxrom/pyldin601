; Resident supervisor; code overlays share a fixed BSS base.
; Small native PGM prefix. Its packed Paint payload follows this PGM's code.
; Stream relocation records through 64 bytes instead of reserving the entire
; table in low RAM. This matters while 16K native graphics memory is allocated.
start
    bra supervisor
    db 'PNTO'
supervisor
    ldx #bss_start
loader_zero
    clr 0,x
    inx
    cpx #bss_end
    bne loader_zero
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
    beq loader_path_begin
    jmp loader_error
loader_path_begin
    ldx #load_path
    clr load_dot
    clrb
loader_path_scan
    ldaa 0,x
    beq loader_path_end
    cmpa #'\'
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
    cmpb #141
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
    tst load_cached
    bne loader_checked_cache
    jsr cache_fill
    tsta
    beq *+5
    jmp loader_error
    inc load_cached
    ldaa #2
    staa load_current
    jsr cache_select
    ldx #0
    stx load_position+2
    jsr loader_seek
    jsr loader_header
    tsta
    beq *+5
    jmp loader_error
loader_checked_cache
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
    tst load_booted
    beq loader_first
    ldx load_base
    bra loader_allocated
loader_first
    ; INT2A's old guard wraps below 0100. Reject before that case, keeping
    ; ordinary stack space even when a resident parent owns a large frame.
    tsx
    stx load_target
    ldaa load_target+1
    suba load_ram+1
    ldaa load_target
    sbca load_ram
    bcs loader_no_memory
    cmpa #2
    bcs loader_no_memory
    ldx load_ram
    clrb
    int $2a
    cpx #0
    bne loader_allocated
loader_no_memory
    ldaa #66
    jmp loader_error
loader_allocated
    stx load_base
    tst load_booted
    bne loader_has_stack
    sts load_stack
    inc load_booted
loader_has_stack
    ldaa #0
    adda load_code_offset+1
    staa load_position+3
    ldaa #0
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
    jsr loader_read
    tsta
    beq loader_code_read
    jmp loader_error
loader_code_read
    cpx load_code_size
    beq loader_seek_records
    jmp loader_bad
loader_seek_records
    ldaa #0
    adda #16
    staa load_position+3
    ldaa #0
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
    jsr loader_read
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
    ldaa 1,x
    adda load_base+1
    staa 1,x
    ldaa 0,x
    adca load_base
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
    tst load_api+4
    bne loader_run
    tst load_current
    beq loader_run
    dec load_current
    lds load_stack
    jsr cache_select
    ldx #0
    stx load_position+2
    jsr loader_seek
    jsr loader_header
    jmp loader_validate
loader_run
    ldaa load_entry+1
    adda load_base+1
    staa load_entry+1
    ldaa load_entry
    adca load_base
    staa load_entry
    ldx #load_filebuf
    stx load_api
    ldx #loader_switch
    stx load_api+2
    ldx #$4f56
    stx load_api+6
    ldx #$4c31
    stx load_api+8
    ldx #load_api
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
    jsr loader_read
    tsta
    bne loader_header_return
    cpx #16
    beq *+5
    jmp loader_bad
    clra
loader_header_return
    rts
loader_seek
    tst load_cached
    beq *+5
    jmp cache_seek
    ldaa load_handle
    clrb
    ldx #load_position
    int $50
    rts
loader_bad
    ldaa #65
loader_error
    staa load_error
    tst load_api+4
    beq loader_fatal
    tst load_recover
    bne loader_fatal
    inc load_recover
    ; A failed replacement has not changed shared BSS. Restore the edit
    ; image from the immutable cache before displaying the error there.
    lds load_stack
    clra
    staa load_current
    ldab load_error
    jmp switch_resume
loader_fatal
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
    int $38
    include PNTOCACHE.INC
load_message db 10,'Paint: ',0
    section
bss_start
load_argument ds 81
load_path ds 146
load_padding ds 285
load_dot ds 1
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
load_cached ds 1
load_booted ds 1
load_stack ds 2
load_api ds 10
load_current ds 1
load_recover ds 1
load_bases ds 6
load_extents ds 6
load_cache_base ds 2
load_cache_size ds 2
load_cache_pos ds 2
cache_index ds 1
cache_address ds 2
cache_size ds 2
cache_left ds 2
cache_count ds 2
cache_next ds 2
cache_code ds 2
cache_ram ds 2
move_source ds 2
move_src_page ds 1
move_target ds 2
move_dst_page ds 1
move_count ds 2
move_status ds 1
move_timeout ds 2
bss_end
    ends
load_buffer equ load_argument
load_filebuf equ load_argument
    end start
