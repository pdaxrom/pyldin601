; Disposable ramloader CLI. The prefix patches CONTEXT after streamed relocation.
    include RAMABI.INC
    jmp start
context dw 0
start
    ldx #bss_start
zero
    clr 0,x
    inx
    cpx #bss_end
    bne zero
    ; Return I/O errors to our rollback path; BREAK requests a deferred abort.
    ; These vectors must be restored before the disposable core is released.
    ldaa #4
    int $2e
    stx saved_break
    stab saved_break+2
    ldaa #7
    int $2e
    stx saved_io
    stab saved_io+2
    ldx #request_abort
    clrb
    ldaa #4
    int $2f
    ldx #fail_io
    clrb
    ldaa #7
    int $2f
    int $3b
    cmpa #1
    beq list
    cmpa #2
    beq one_arg
    cmpa #3
    beq two_args
    jmp usage
one_arg
    ldaa #1
    jsr argument
    ldx #list_arg
    jsr equal_arg
    beq list
    ldx #list_word
    jsr equal_arg
    beq list
    ldx #cvm_arg
    jsr equal_arg
    bne *+5
    jmp select_cvm
    jmp load_rom
two_args
    ldaa #1
    jsr argument
    ldx #unload_arg
    jsr equal_arg
    bne *+5
    jmp unload_rom
    ldx #unload_word
    jsr equal_arg
    beq *+5
    jmp usage
    jmp unload_rom
list
    ldx #list_msg
    int $23
    clr slot
list_next
    jsr record_at
    ldaa R_FLAGS,x
    cmpa #1
    bne list_skip
    jsr print_record
    inc listed
list_skip
    inc slot
    ldaa slot
    cmpa #RL_SLOTS
    bcs list_next
    tst listed
    bne done
    ldx #none_msg
    int $23
done
    clra
core_return
    psha
    ldab saved_break+2
    ldx saved_break
    ldaa #4
    int $2f
    ldab saved_io+2
    ldx saved_io
    ldaa #7
    int $2f
    pula
    rts
request_abort
    inc cancelled
    rts
fail_io
    ldaa #3
    staa $06
    rts
select_cvm
    ; The CPU choice and path handling use only classic MC6800 instructions.
    ldaa #$ef
    int $2e
    cpx #0
    beq cvm_path
    stx target
    clr slot
cvm_find_loaded
    jsr record_at
    ldaa R_FLAGS,x
    cmpa #1
    bne cvm_loaded_next
    ldx #cvm_name_text
    stx src
    jsr compare_name
    bne cvm_loaded_next
    ldx record
    ldab #R_GATES
    jsr add_b
    cpx target
    beq cvm_loaded_info
    jmp cvm_conflict
cvm_loaded_next
    inc slot
    ldaa slot
    cmpa #RL_SLOTS
    bcs cvm_find_loaded
    jmp cvm_conflict
cvm_loaded_info
    clra
    int $ef
    cmpa #1
    bne cvm_conflict
    cpx #$5a56
    bne cvm_conflict
    stab offset
    ldaa $e6a0
    anda #2
    lsra
    cmpa offset
    bne cvm_conflict
    ldx #cvm_ready
    int $23
    jmp done
cvm_conflict
    ldaa #82
    jmp fail
cvm_path
    ldx context
    ldx C_PATH,x
    stx src
    ldx #argtext
    stx dst
    stx selected
    clr offset
    clr selected_slot
cvm_copy_path
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    staa 0,x
    tsta
    beq cvm_filename
    inx
    stx dst
    cmpa #':'
    beq cvm_component
    cmpa #'\'
    bne cvm_path_next
cvm_component
    stx selected
    ldaa offset
    inca
    staa selected_slot
cvm_path_next
    inc offset
    ldaa offset
    cmpa #79
    bcs cvm_copy_path
    jmp bad_rom
cvm_filename
    ldaa selected_slot
    cmpa #69
    bcs *+5
    jmp bad_rom
    ldx #cvm_mc
    ldaa $e6a0
    bita #2
    beq cvm_name
    ldx #cvm_hd
cvm_name
    stx src
    ldx selected
    stx dst
    ldab #12
    jsr copy_n
    jmp load_rom
load_rom
    ; The native permanent allocator is a high-water mark. Do not pin a
    ; caller such as NC with the initial registry: install from the root shell.
    ldx context
    tst C_FIRST,x
    beq load_services
    ldx $ec00
    ldx 0,x
    cpx #0
    beq load_root_ok
    ldx 0,x
    cpx #0
    beq load_root_ok
    ldaa #86
    jmp fail
load_root_ok
load_services
    ldaa #$e5
    int $2e
    cpx #0
    bne *+5
    jmp no_ramman
    clra
    int $e5
    cmpa #1
    beq *+5
    jmp no_ramman
    cpx #111
    beq *+5
    jmp no_ramman
    ldaa $e6f2
    cmpa #'R'
    beq *+5
    jmp no_ramman
    ldaa $e6f3
    cmpa #111
    beq *+5
    jmp no_ramman
    clr slot
find_slot
    jsr record_at
    tst R_FLAGS,x
    beq slot_free
    inc slot
    ldaa slot
    cmpa #RL_SLOTS
    bcs find_slot
    ldaa #84
    jmp fail
slot_free
    jsr clear_record
    ldx record
    ldaa #2
    staa R_FLAGS,x
    ldx #argtext
    stx open_table
    ldaa #1
    ldx #open_table
    int $4a
    tsta
    beq *+5
    jmp fail
    stab handle
    inc file_live
    tba
    ldx #file_size
    int $51
    tsta
    beq *+5
    jmp fail
    ldx file_size
    cpx #0
    beq *+5
    jmp bad_rom
    ldx file_size+2
    cpx #8192
    beq *+5
    jmp bad_rom
    jsr lease_pointer
    ldaa #1
    ldab #1
    int $e5
    tsta
    beq *+5
    jmp fail
    inc leased
    ldx record
    ldaa R_LEASE+3,x
    clrb
bank_divide
    cmpa #6
    bcs bank_select
    suba #6
    incb
    bra bank_divide
bank_select
    inca
    staa R_PAGE,x
    stab R_GROUP,x
    ldx #$c000
    stx bank_pointer
read_page
    ldx #buffer
    stx io_table
    ldx #512
    stx io_table+2
    ldaa handle
    ldx #io_table
    int $4c
    tsta
    beq *+5
    jmp fail
    cpx #512
    beq *+5
    jmp bad_rom
    tst blocks
    bne copy_page
    ldx #buffer
    stx src
    ldx #header
    stx dst
    ldab #64
    jsr copy_n
copy_page
    ldaa $e6f0
    psha
    ldaa $e6f1
    psha
    ldx record
    ldaa R_GROUP,x
    staa $e6f1
    ldaa R_PAGE,x
    staa $e6f0
    ldx #buffer
    stx src
    ldx #512
    stx remaining
copy_byte
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx bank_pointer
    staa 0,x
    inx
    stx bank_pointer
    adda checksum
    staa checksum
    ldx remaining
    dex
    stx remaining
    bne copy_byte
    pula
    staa $e6f1
    pula
    staa $e6f0
    tst cancelled
    beq *+5
    jmp aborted
    inc blocks
    ldaa blocks
    cmpa #16
    bcc *+5
    jmp read_page
    ldaa handle
    int $4e
    tsta
    beq *+5
    jmp fail
    clr file_live
    tst checksum
    beq *+5
    jmp bad_rom
    ldx header
    cpx #$a55a
    beq header_signature
    cpx #$5aa5
    beq *+5
    jmp bad_rom
header_signature
    ldaa header+10
    cmpa #$7e
    beq *+5
    jmp bad_rom
    ldaa header+11
    jsr address_high
    bcc *+5
    jmp bad_rom
    ldaa header+2
    cmpa #33
    bcc *+5
    jmp bad_rom
    ldx #header+2
    ldab #8
header_name
    ldaa 0,x
    cmpa #32
    bcc *+5
    jmp bad_rom
    cmpa #'a'
    bcs header_name_next
    cmpa #'z'
    bhi header_name_next
    suba #32
    staa 0,x
header_name_next
    inx
    decb
    bne header_name
    ldx #header+2
    stx src
    ldx record
    ldab #R_NAME
    jsr add_b
    stx dst
    ldab #8
    jsr copy_n
    jsr unique_name
    bcc *+5
    jmp duplicate
    jsr validate_exports
    tsta
    beq *+5
    jmp fail
    ; The initializer receives eight zeroed persistent context bytes.
    ldx record
    ldab #R_INIT
    jsr add_b
    stx gate
    ldx #$c00a
    stx target
    clr vector_id
    jsr build_gate
    tpa
    psha
    staa $04
    clr $05
    clr $06
    ldx record
    ldab #R_CONTEXT
    jsr add_b
    stx $07
    ldx gate
    jsr 0,x
    ldaa $06
    staa saved_error
    pula
    tap
    ldaa saved_error
    tsta
    beq *+5
    jmp fail
    tst cancelled
    beq *+5
    jmp aborted
    jsr lease_pointer
    ldaa #4
    int $e5
    tsta
    beq lease_pinned
    cmpa #1
    bne *+5
    jmp old_ramman
    jmp fail
lease_pinned
    inc pinned
    ; An initializer must not replace the exports it asked us to install.
    jsr check_free_exports
    tsta
    beq *+5
    jmp fail
    tpa
    psha
    sei
    jsr publish
    ldx record
    ldaa #1
    staa R_FLAGS,x
    ldx context
    staa C_KEEP,x
    pula
    tap
    clr leased
    ldx #loaded_msg
    int $23
    jsr print_record
    jmp done
; Validate the standard ROM export table and build ordinary-RAM SWI gates.
validate_exports
    clr export_index
export_next
    jsr header_export
    ldaa 0,x
    beq exports_end
    cmpa #$80
    bcs export_bad
    cmpa #RL_INT
    beq export_bad
    cmpa #$e4
    beq export_bad
    cmpa #$e7
    beq export_bad
    staa vector_id
    ldaa export_index
    cmpa #RL_EXPORTS
    bcc export_bad
    ldaa 1,x
    jsr address_high
    bcs export_bad
    ldx 1,x
    stx target
    ; An export number may appear only once in the page.
    ldx #header+16
    ldab export_index
export_duplicate
    tstb
    beq export_unique
    ldaa 0,x
    cmpa vector_id
    beq export_bad
    inx
    inx
    inx
    decb
    bra export_duplicate
export_unique
    ldaa vector_id
    int $2e
    cpx #0
    bne export_conflict
    stx old_vector
    stab old_page
    jsr old_pointer
    ldaa old_page
    staa 0,x
    ldaa old_vector
    staa 1,x
    ldaa old_vector+1
    staa 2,x
    jsr gate_pointer
    stx gate
    jsr build_gate
    inc export_index
    bra export_next
exports_end
    ldaa export_index
    beq export_bad
    ldx record
    staa R_COUNT,x
    clra
    rts
export_bad
    ldaa #81
    rts
export_conflict
    ldaa #82
    rts
check_free_exports
    clr export_index
check_free_next
    jsr gate_pointer
    ldaa 9,x
    int $2e
    cpx #0
    bne export_conflict
    inc export_index
    ldx record
    ldaa export_index
    cmpa R_COUNT,x
    bcs check_free_next
    clra
    rts
publish
    clr export_index
publish_next
    jsr gate_pointer
    ldaa 9,x
    clrb
    int $2f
    inc export_index
    ldx record
    ldaa export_index
    cmpa R_COUNT,x
    bcs publish_next
    rts
build_gate
    ldx context
    ldx C_TEMPLATE,x
    stx src
    ldx gate
    stx dst
    ldab #G_BYTES
    jsr copy_n
    ldx record
    ldaa R_GROUP,x
    ldab R_PAGE,x
    ldx gate
    staa 3,x
    stab 4,x
    ldaa target
    staa 5,x
    ldaa target+1
    staa 6,x
    ldx record
    inx
    stx busy_ptr
    ldx gate
    ldaa busy_ptr
    staa 7,x
    ldaa busy_ptr+1
    staa 8,x
    ldaa vector_id
    staa 9,x
    rts
unload_rom
    ldaa #2
    jsr argument
    ; Normalize the module's eight-character ROM header name, space padded.
    ldx #argtext
    ldab #8
unload_name
    tst 0,x
    beq unload_pad
    inx
    decb
    bne unload_name
    tst 0,x
    beq unload_find
    jmp usage
unload_pad
    ldaa #' '
unload_padding
    staa 0,x
    inx
    decb
    bne unload_padding
unload_find
    clr slot
unload_next
    jsr record_at
    ldaa R_FLAGS,x
    cmpa #1
    bne unload_skip
    ldx #argtext
    stx src
    jsr compare_name
    beq unload_found
unload_skip
    inc slot
    ldaa slot
    cmpa #RL_SLOTS
    bcs unload_next
    ldaa #88
    jmp fail
unload_found
    ldx record
    tst R_BUSY,x
    beq *+5
    jmp busy
    clr export_index
unload_check
    jsr gate_pointer
    stx gate
    ldaa 9,x
    int $2e
    tstb
    beq *+5
    jmp busy
    cpx gate
    beq *+5
    jmp busy
    inc export_index
    ldx record
    ldaa export_index
    cmpa R_COUNT,x
    bcs unload_check
    tpa
    psha
    sei
    clr export_index
unload_restore
    jsr old_pointer
    ldab 0,x
    ldx 1,x
    stx old_vector
    stab old_page
    jsr gate_pointer
    ldaa 9,x
    ldab old_page
    ldx old_vector
    int $2f
    inc export_index
    ldx record
    ldaa export_index
    cmpa R_COUNT,x
    bcs unload_restore
    jsr lease_pointer
    ldaa #5
    int $e5
    tsta
    beq unload_released
    staa saved_error
    jsr publish
    pula
    tap
    ldaa saved_error
    jmp fail
unload_released
    ldx record
    clr R_FLAGS,x
    pula
    tap
    ldx #unloaded_msg
    int $23
    jsr print_record
    jsr clear_record
    jmp done
; Helpers never execute from the banked window.
record_at
    ldx context
    ldx C_REG,x
    ldab slot
record_step
    tstb
    beq record_ready
    pshb
    ldab #RL_RECORD
    jsr add_b
    pulb
    decb
    bra record_step
record_ready
    stx record
    rts
lease_pointer
    ldx record
    ldab #R_LEASE
    jmp add_b
clear_record
    ldx record
    ldab #RL_RECORD
clear_record_byte
    clr 0,x
    inx
    decb
    bne clear_record_byte
    rts
header_export
    ldx #header+16
    ldab export_index
header_step
    tstb
    beq pointer_ready
    inx
    inx
    inx
    decb
    bra header_step
pointer_ready
    rts
gate_pointer
    ldx record
    ldab #R_GATES
    jsr add_b
    ldaa export_index
    ldab #G_BYTES
    ; A*10 fits in a byte (at most seven exports).
    asla
    staa offset
    asla
    asla
    adda offset
    tab
    jmp add_b
old_pointer
    ldx record
    ldab #R_OLD
    jsr add_b
    ldaa export_index
    staa offset
    asla
    adda offset
    tab
    jmp add_b
address_high
    cmpa #$c0
    bcs address_bad
    cmpa #$e0
    bcc address_bad
    clc
    rts
address_bad
    sec
    rts
unique_name
    ldx record
    stx selected
    ldaa slot
    staa selected_slot
    clr slot
unique_next
    jsr record_at
    ldaa R_FLAGS,x
    cmpa #1
    bne unique_skip
    ldx selected
    ldab #R_NAME
    jsr add_b
    stx src
    jsr compare_name
    beq unique_bad
unique_skip
    inc slot
    ldaa slot
    cmpa #RL_SLOTS
    bcs unique_next
    clc
    bra unique_return
unique_bad
    sec
unique_return
    ldx selected
    stx record
    ldaa selected_slot
    staa slot
    rts
compare_name
    ldx record
    ldab #R_NAME
    jsr add_b
    stx dst
    ldab #8
compare_byte
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    cmpa 0,x
    bne compare_done
    inx
    stx dst
    decb
    bne compare_byte
compare_done
    rts
print_record
    ldx record
    ldab #R_NAME
    jsr add_b
    stx src
    ldab #8
print_name
    ldx src
    ldaa 0,x
    inx
    stx src
    int $22
    decb
    bne print_name
    ldx #bank_msg
    int $23
    ldx record
    ldaa R_LEASE+3,x
    jsr print_hex
    ldx #group_msg
    int $23
    ldx record
    ldaa R_GROUP,x
    jsr print_hex
    ldx #page_msg
    int $23
    ldx record
    ldaa R_PAGE,x
    jsr print_hex
    ldx #newline
    int $23
    rts
argument
    ldx #argtext
    int $3c
    ldx #argtext
argument_upper
    ldaa 0,x
    beq argument_done
    cmpa #'a'
    bcs argument_next
    cmpa #'z'
    bhi argument_next
    suba #32
    staa 0,x
argument_next
    inx
    bra argument_upper
argument_done
    rts
equal_arg
    stx src
    ldx #argtext
    stx dst
equal_byte
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    cmpa 0,x
    bne equal_done
    inx
    stx dst
    tsta
    bne equal_byte
equal_done
    rts
copy_n
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    staa 0,x
    inx
    stx dst
    decb
    bne copy_n
    rts
add_b
    stx add_pointer
    psha
    ldaa add_pointer+1
    aba
    staa add_pointer+1
    bcc add_no_carry
    inc add_pointer
add_no_carry
    ldx add_pointer
    pula
    clrb
    rts
print_hex
    psha
    lsra
    lsra
    lsra
    lsra
    jsr print_nibble
    pula
    anda #15
print_nibble
    adda #'0'
    cmpa #'9'
    bls nibble_out
    adda #7
nibble_out
    int $22
    rts
bad_rom
    ldaa #81
    bra fail
duplicate
    ldaa #83
    bra fail
busy
    ldaa #85
    bra fail
old_ramman
    ldaa #87
    bra fail
no_ramman
    ldaa #4
    bra fail
aborted
    ldaa #255
fail
    staa saved_error
    tst file_live
    beq fail_lease
    ldaa handle
    int $4e
    clr file_live
fail_lease
    tst leased
    bne fail_has_lease
    ldx record
    cpx #0
    beq fail_print
    ldaa R_FLAGS,x
    cmpa #2
    bne fail_print
    jsr clear_record
    bra fail_print
fail_has_lease
    jsr lease_pointer
    ldaa #2
    tst pinned
    beq fail_release
    ldaa #5
fail_release
    int $e5
    tsta
    beq fail_clear
    ; Keep the descriptor visible if a transient manager lock prevents cleanup.
    ldx context
    ldaa #1
    staa C_KEEP,x
    bra fail_print
fail_clear
    jsr clear_record
fail_print
    ldx #error_msg
    int $23
    ldaa saved_error
    jsr print_hex
    ldx #newline
    int $23
    ldx context
    ldaa saved_error
    staa C_ERROR,x
    jmp core_return
usage
    ldx #usage_msg
    int $23
    jmp done
list_arg db '/L',0
list_word db 'LIST',0
cvm_arg db '/CVM',0
cvm_mc db 'ZVM6800.ROM',0
cvm_hd db 'ZVM6303.ROM',0
cvm_ready db 'ZCodeVM already loaded.',13,10,0
cvm_name_text db 'ZCODEVM '
unload_arg db '/U',0
unload_word db 'UNLOAD',0
list_msg db 'RAMLOAD: loaded ROMs',13,10,0
none_msg db 'None.',13,10,0
loaded_msg db 'Loaded ',0
unloaded_msg db 'Unloaded ',0
bank_msg db ' bank=',0
group_msg db ' g=',0
page_msg db ' p=',0
newline db 13,10,0
error_msg db 'RAMLOAD: error $',0
usage_msg db 'RAMLOAD file.ROM | /CVM | /L | /U NAME',13,10,0
bss_start
saved_break ds 3
saved_io ds 3
cancelled ds 1
record ds 2
selected ds 2
selected_slot ds 1
slot ds 1
listed ds 1
export_index ds 1
vector_id ds 1
old_vector ds 2
old_page ds 1
target ds 2
gate ds 2
busy_ptr ds 2
src ds 2
dst ds 2
add_pointer ds 2
offset ds 1
argtext ds 81
open_table ds 4
io_table ds 4
file_size ds 4
handle ds 1
file_live ds 1
leased ds 1
pinned ds 1
blocks ds 1
checksum ds 1
saved_error ds 1
bank_pointer ds 2
remaining ds 2
header ds 64
buffer ds 512
bss_end
    end
