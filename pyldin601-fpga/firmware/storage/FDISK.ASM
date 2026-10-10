; Native MC6800 MBR/EBR editor. Addresses and sizes are decimal sectors.
; Never alters a mounted volume's bounds. Every table write is read back,
; validated by the resident scanner, and rolled back if validation fails.
start
    int $3b
    staa argc
    cmpa #2
    bcc fd_device
    jmp usage
fd_device
    ldaa #1
    jsr argument
    ldx #sd_name
    stx pat
    ldx #argtext
    jsr match
    bcc fd_device_ok
    jmp usage
fd_device_ok
    ldx #capacity
    clra
    int $e2
    tsta
    beq fd_capacity
    jmp finish_result
fd_capacity
    ldaa argc
    cmpa #2
    bne fd_operation
    jmp list
fd_operation
    ldaa #2
    jsr argument
    ldx #list_name
    stx pat
    ldx #argtext
    jsr match
    bcs fd_active
    jmp list
fd_active
    ldx #active_name
    stx pat
    ldx #argtext
    jsr match
    bcs fd_delete
    jmp active
fd_delete
    ldx #delete_name
    stx pat
    ldx #argtext
    jsr match
    bcs fd_create
    jmp delete
fd_create
    ldx #create_name
    stx pat
    ldx #argtext
    jsr match
    bcs fd_extended
    ldaa #1
    staa kind
    jmp create
fd_extended
    ldx #extended_name
    stx pat
    ldx #argtext
    jsr match
    bcs fd_logical
    ldaa #$0f
    staa kind
    jmp create
fd_logical
    ldx #logical_name
    stx pat
    ldx #argtext
    jsr match
    bcs fd_usage
    ldaa #1
    staa kind
    ldaa #1
    staa logical
    jmp create
fd_usage
    jmp usage
get_record
    ldab index
    ldx #record
    ldaa #1
    int $e1
    rts
find_part
    clr index
find_part_loop
    jsr get_record
    tsta
    bne find_part_done
    ldaa record+8
    cmpa target
    beq find_part_ok
    inc index
    bra find_part_loop
find_part_ok
    clra
find_part_done
    rts
read_table_record
    ldx #record+16
    jsr set_lba
    jmp read_table
set_lba
    ldaa 0,x
    staa descriptor+2
    ldaa 1,x
    staa descriptor+3
    ldaa 2,x
    staa descriptor+4
    ldaa 3,x
    staa descriptor+5
    rts
read_table
    ldx #sector
    stx descriptor
    ldx #descriptor
    ldaa #1
    int $e2
    tsta
    beq save_original
    rts
save_original
    ldx #sector
    stx ptr
    ldx #backup
    stx pat
    jmp copy_sector
entry_pointer
    ; slot is zero-based. The returned X points into the private table.
    ldx #sector+446
    stx ptr
    ldaa slot
    asla
    asla
    asla
    asla
    adda ptr+1
    staa ptr+1
    ldaa ptr
    adca #0
    staa ptr
    ldx ptr
    rts
write_table
    ldx #sector
    stx descriptor
    ldx #descriptor
    ldaa #2
    int $e2
    tsta
    bne rollback
    ldx #verify
    stx descriptor
    ldx #descriptor
    ldaa #1
    int $e2
    tsta
    bne rollback
    ldx #sector
    stx ptr
    ldx #verify
    stx pat
    ldx #512
    stx count
verify_loop
    ldx ptr
    ldaa 0,x
    inx
    stx ptr
    ldx pat
    cmpa 0,x
    bne verify_error
    inx
    stx pat
    ldx count
    dex
    stx count
    cpx #0
    bne verify_loop
    ldaa #5
    int $e1
    tsta
    bne rollback
    rts
verify_error
    ldaa #5
rollback
    staa error
    ldx #backup
    stx descriptor
    ldx #descriptor
    ldaa #2
    int $e2
    tsta
    bne rollback_failed
    ldaa #5
    int $e1
    ldaa error
    rts
rollback_failed
    ldx #rollback_msg
    int $23
    ldaa #6
    rts
copy_sector
    ldx #512
    stx count
copy_sector_loop
    ldx ptr
    ldaa 0,x
    inx
    stx ptr
    ldx pat
    staa 0,x
    inx
    stx pat
    ldx count
    dex
    stx count
    cpx #0
    bne copy_sector_loop
    clra
    rts
list
    ldaa argc
    cmpa #3
    bls list_begin
    jmp usage
list_begin
    ldx #heading
    int $23
    clr index
list_loop
    jsr get_record
    tsta
    beq list_record
    int $38
list_record
    ldaa record+8
    jsr print_number
    ldaa #' '
    int $22
    ldaa record+9
    jsr print_hex
    ldaa #' '
    int $22
    ldaa #'0'
    tst record+10
    beq list_boot
    ldaa #'1'
list_boot
    int $22
    ldaa #' '
    int $22
    ldaa record+11
    cmpa #$ff
    bne list_drive
    ldaa #'-'-'A'
list_drive
    adda #'A'
    int $22
    ldaa #' '
    int $22
    ldx #record
    jsr print_lba
    ldaa #' '
    int $22
    ldx #record+4
    jsr print_lba
    ldx #newline
    int $23
    inc index
    jmp list_loop
print_lba
    ldaa 3,x
    jsr print_hex
    ldaa 2,x
    jsr print_hex
    ldaa 1,x
    jsr print_hex
    ldaa 0,x
    jmp print_hex
part_argument
    ldaa argc
    cmpa #4
    bne part_arg_bad
    ldaa #3
    jsr argument
    ldx #argtext
    jsr parse_decimal
    bcs part_arg_bad
    ldaa number+1
    oraa number+2
    oraa number+3
    bne part_arg_bad
    ldaa number
    cmpa #36
    bhi part_arg_bad
    staa target
    clc
    rts
part_arg_bad
    sec
    rts
active
    jsr part_argument
    bcc active_argument
    jmp usage
active_argument
    tst target
    beq active_begin
    jsr find_part
    tsta
    bne active_error
    ldaa record+9
    cmpa #1
    bne active_invalid
    tst record+21
    beq active_invalid
active_begin
    clr index
active_loop
    jsr get_record
    tsta
    bne active_complete
    ldaa record+9
    cmpa #1
    bne active_next
    jsr read_table_record
    tsta
    bne active_error
    ldaa record+20
    staa slot
    jsr entry_pointer
    clra
    ldab record+8
    cmpb target
    bne active_store
    ldaa #$80
active_store
    staa 0,x
    jsr write_table
    tsta
    bne active_error
active_next
    inc index
    bra active_loop
active_complete
    clra
active_error
    jmp finish_result
active_invalid
    ldaa #9
    jmp finish_result
delete
    jsr part_argument
    bcc delete_argument
    jmp usage
delete_argument
    jsr find_part
    tsta
    bne delete_error
    ldaa record+11
    cmpa #$ff
    bne busy
    ldaa record+9
    jsr extended_type
    bne delete_one
    ; Deleting a container also removes every logical partition.
    clr index
delete_children
    jsr get_record
    tsta
    bne delete_refind
    ldaa record+8
    cmpa #5
    bcs delete_child_next
    ldaa record+11
    cmpa #$ff
    bne busy
delete_child_next
    inc index
    bra delete_children
delete_refind
    jsr find_part
delete_one
    jsr read_table_record
    tsta
    bne delete_error
    ldaa record+20
    staa slot
    jsr entry_pointer
    ldab #16
delete_entry
    clr 0,x
    inx
    decb
    bne delete_entry
    jsr write_table
delete_error
    jmp finish_result
busy
    ldaa #15
    jmp finish_result
extended_type
    cmpa #5
    beq extended_return
    cmpa #$0f
    beq extended_return
    cmpa #$85
extended_return
    rts
create
    ldaa argc
    cmpa #6
    beq create_arguments
    jmp usage
create_arguments
    ldaa #3
    jsr argument
    ldx #argtext
    jsr parse_decimal
    bcc create_first
    jmp usage
create_first
    tst logical
    bne create_ebr_number
    ldaa number+1
    oraa number+2
    oraa number+3
    beq fdisk_skip_000
    jmp create_bad
fdisk_skip_000
    ldaa number
    bne fdisk_skip_001
    jmp create_bad
fdisk_skip_001
    cmpa #4
    bls fdisk_skip_002
    jmp create_bad
fdisk_skip_002
    deca
    staa slot
    bra create_start
create_ebr_number
    ldx #number
    ldaa 0,x
    staa ebr
    ldaa 1,x
    staa ebr+1
    ldaa 2,x
    staa ebr+2
    ldaa 3,x
    staa ebr+3
create_start
    ldaa #4
    jsr argument
    ldx #argtext
    jsr parse_decimal
    bcc fdisk_skip_003
    jmp create_bad
fdisk_skip_003
    ldaa number
    staa first
    ldaa number+1
    staa first+1
    ldaa number+2
    staa first+2
    ldaa number+3
    staa first+3
    ldaa #5
    jsr argument
    ldx #argtext
    jsr parse_decimal
    bcc fdisk_skip_004
    jmp create_bad
fdisk_skip_004
    ldaa number
    oraa number+1
    oraa number+2
    oraa number+3
    bne fdisk_skip_005
    jmp create_bad
fdisk_skip_005
    ldaa first
    oraa first+1
    oraa first+2
    oraa first+3
    bne fdisk_skip_006
    jmp create_bad
fdisk_skip_006
    ldaa first
    adda number
    staa last
    ldaa first+1
    adca number+1
    staa last+1
    ldaa first+2
    adca number+2
    staa last+2
    ldaa first+3
    adca number+3
    staa last+3
    bcc fdisk_skip_007
    jmp create_bad
fdisk_skip_007
    ldaa capacity
    suba last
    ldaa capacity+1
    sbca last+1
    ldaa capacity+2
    sbca last+2
    ldaa capacity+3
    sbca last+3
    bcc fdisk_skip_008
    jmp create_bad
fdisk_skip_008
    clr index
    clr found_extended
create_check_loop
    jsr get_record
    tsta
    beq fdisk_skip_009
    jmp create_checked
fdisk_skip_009
    ldaa record+9
    jsr extended_type
    bne create_check_range
    tst logical
    beq create_primary_extended
    ldaa #1
    staa found_extended
    ldaa record
    staa extbase
    ldaa record+1
    staa extbase+1
    ldaa record+2
    staa extbase+2
    ldaa record+3
    staa extbase+3
    jsr record_end
    ldaa temp
    staa extend
    ldaa temp+1
    staa extend+1
    ldaa temp+2
    staa extend+2
    ldaa temp+3
    staa extend+3
    jmp create_check_next
create_primary_extended
    ldaa kind
    cmpa #$0f
    bne fdisk_skip_010
    jmp create_bad
fdisk_skip_010
create_check_range
    ; Primary creation checks all primary ranges; logical creation ignores
    ; the container but checks every actual data volume and table sector.
    tst logical
    bne create_data_range
    ldaa record+8
    cmpa #5
    bcc create_check_next
create_data_range
    jsr record_end
    ldaa first
    suba temp
    ldaa first+1
    sbca temp+1
    ldaa first+2
    sbca temp+2
    ldaa first+3
    sbca temp+3
    bcc create_check_ebr
    ldaa record
    suba last
    ldaa record+1
    sbca last+1
    ldaa record+2
    sbca last+2
    ldaa record+3
    sbca last+3
    bcc fdisk_skip_011
    jmp create_bad
fdisk_skip_011
create_check_ebr
    tst logical
    beq create_check_next
    ldaa ebr
    suba record
    ldaa ebr+1
    sbca record+1
    ldaa ebr+2
    sbca record+2
    ldaa ebr+3
    sbca record+3
    bcs create_check_next
    ldaa ebr
    suba temp
    ldaa ebr+1
    sbca temp+1
    ldaa ebr+2
    sbca temp+2
    ldaa ebr+3
    sbca temp+3
    bcc fdisk_skip_012
    jmp create_bad
fdisk_skip_012
create_check_next
    inc index
    jmp create_check_loop
create_checked
    tst logical
    beq create_primary
    jmp create_logical
create_primary
    clr descriptor+2
    clr descriptor+3
    clr descriptor+4
    clr descriptor+5
    jsr read_table
    tsta
    beq fdisk_skip_013
    jmp create_error
fdisk_skip_013
    jsr entry_pointer
    tst 4,x
    beq fdisk_skip_014
    jmp create_bad
fdisk_skip_014
    jsr fill_entry
    ldaa kind
    cmpa #$0f
    bne create_primary_write
    ; The extended partition begins with an empty, valid EBR. Preserve the
    ; proposed MBR while initializing its table sector, then commit the MBR.
    ldx #sector
    stx ptr
    ldx #mbr_saved
    stx pat
    jsr copy_sector
    ldx #first
    jsr set_lba
    jsr empty_table
    tsta
    beq fdisk_skip_015
    jmp create_error
fdisk_skip_015
    ldx #mbr_saved
    stx ptr
    ldx #sector
    stx pat
    jsr copy_sector
    clr descriptor+2
    clr descriptor+3
    clr descriptor+4
    clr descriptor+5
    ; Reload the original MBR for rollback, without losing the proposal.
    ldx #backup
    stx descriptor
    ldx #descriptor
    ldaa #1
    int $e2
    tsta
    beq fdisk_skip_016
    jmp create_error
fdisk_skip_016
create_primary_write
    jsr write_table
create_error
    jmp finish_result
create_bad
    ldaa #4
    jmp finish_result
record_end
    ldaa record
    adda record+4
    staa temp
    ldaa record+1
    adca record+5
    staa temp+1
    ldaa record+2
    adca record+6
    staa temp+2
    ldaa record+3
    adca record+7
    staa temp+3
    rts
fill_entry
    stx ptr
    ldab #16
fill_zero
    clr 0,x
    inx
    decb
    bne fill_zero
    ldx ptr
    ldaa kind
    staa 4,x
    ldaa #$fe
    staa 1,x
    staa 5,x
    ldaa #$ff
    staa 2,x
    staa 3,x
    staa 6,x
    staa 7,x
    ldaa first
    staa 8,x
    ldaa first+1
    staa 9,x
    ldaa first+2
    staa 10,x
    ldaa first+3
    staa 11,x
    ldaa number
    staa 12,x
    ldaa number+1
    staa 13,x
    ldaa number+2
    staa 14,x
    ldaa number+3
    staa 15,x
    rts
empty_table
    jsr read_table
    tsta
    bne empty_done
    ldx #sector
    ldab #0
empty_half
    clr 0,x
    inx
    decb
    bne empty_half
    ldab #0
empty_second
    clr 0,x
    inx
    decb
    bne empty_second
    ldaa #$55
    staa sector+510
    ldaa #$aa
    staa sector+511
    jsr write_table
empty_done
    rts
create_logical
    tst found_extended
    bne fdisk_skip_017
    jmp create_bad
fdisk_skip_017
    ; ebr >= extbase, ebr < first, last <= extended end.
    ldaa ebr
    suba extbase
    ldaa ebr+1
    sbca extbase+1
    ldaa ebr+2
    sbca extbase+2
    ldaa ebr+3
    sbca extbase+3
    bcc fdisk_skip_018
    jmp create_bad
fdisk_skip_018
    ldaa ebr
    suba first
    ldaa ebr+1
    sbca first+1
    ldaa ebr+2
    sbca first+2
    ldaa ebr+3
    sbca first+3
    bcs fdisk_skip_019
    jmp create_bad
fdisk_skip_019
    ldaa extend
    suba last
    ldaa extend+1
    sbca last+1
    ldaa extend+2
    sbca last+2
    ldaa extend+3
    sbca last+3
    bcc fdisk_skip_020
    jmp create_bad
fdisk_skip_020
    ldx #extbase
    jsr set_lba
    clr chain_count
logical_chain
    inc chain_count
    ldaa chain_count
    cmpa #32
    bls fdisk_skip_021
    jmp create_bad
fdisk_skip_021
    jsr read_table
    tsta
    beq fdisk_skip_022
    jmp create_error
fdisk_skip_022
    ; A specified empty EBR can be reused without changing numbering.
    ldaa descriptor+2
    cmpa ebr
    bne logical_chain_link
    ldaa descriptor+3
    cmpa ebr+1
    bne logical_chain_link
    ldaa descriptor+4
    cmpa ebr+2
    bne logical_chain_link
    ldaa descriptor+5
    cmpa ebr+3
    bne logical_chain_link
    tst sector+450
    beq fdisk_skip_023
    jmp create_bad
fdisk_skip_023
    ldaa #1
    staa reuse_ebr
    jmp logical_fill
logical_chain_link
    tst sector+466
    beq logical_last
    ldaa sector+470
    adda extbase
    staa descriptor+2
    ldaa sector+471
    adca extbase+1
    staa descriptor+3
    ldaa sector+472
    adca extbase+2
    staa descriptor+4
    ldaa sector+473
    adca extbase+3
    staa descriptor+5
    jmp logical_chain
logical_last
    ldaa descriptor+2
    staa last_table
    ldaa descriptor+3
    staa last_table+1
    ldaa descriptor+4
    staa last_table+2
    ldaa descriptor+5
    staa last_table+3
    ldx #ebr
    jsr set_lba
    jsr empty_table
    tsta
    beq fdisk_skip_024
    jmp create_error
fdisk_skip_024
logical_fill
    ; The logical entry's start is relative to its own EBR, not the container.
    ldaa first
    suba ebr
    staa first
    ldaa first+1
    sbca ebr+1
    staa first+1
    ldaa first+2
    sbca ebr+2
    staa first+2
    ldaa first+3
    sbca ebr+3
    staa first+3
    clr slot
    jsr entry_pointer
    jsr fill_entry
    jsr write_table
    tsta
    bne logical_error
    tst reuse_ebr
    bne logical_error
    ldx #last_table
    jsr set_lba
    jsr read_table
    tsta
    bne logical_error
    ldaa ebr
    suba extbase
    staa first
    ldaa ebr+1
    sbca extbase+1
    staa first+1
    ldaa ebr+2
    sbca extbase+2
    staa first+2
    ldaa ebr+3
    sbca extbase+3
    staa first+3
    ldaa extend
    suba ebr
    staa number
    ldaa extend+1
    sbca ebr+1
    staa number+1
    ldaa extend+2
    sbca ebr+2
    staa number+2
    ldaa extend+3
    sbca ebr+3
    staa number+3
    ldaa #$0f
    staa kind
    ldaa #1
    staa slot
    jsr entry_pointer
    jsr fill_entry
    jsr write_table
logical_error
    jmp finish_result
    include COMMON.INC
sd_name db "SD0:",0
list_name db "LIST",0
active_name db "ACTIVE",0
delete_name db "DELETE",0
create_name db "CREATE",0
extended_name db "EXTENDED",0
logical_name db "LOGICAL",0
usage_msg db "FDISK SD0: [LIST]",13,10
    db "FDISK SD0: ACTIVE <partition|0>",13,10
    db "FDISK SD0: DELETE <partition>",13,10
    db "FDISK SD0: CREATE|EXTENDED <slot> <start> <sectors>",13,10
    db "FDISK SD0: LOGICAL <ebr> <start> <sectors>",13,10,0
heading db "PART TYPE BOOT DRIVE START/SECTORS (hex)",13,10,0
ok_msg db "Partition table updated.",13,10,0
rollback_msg db "Rollback failed: restore SD backup before reboot.",13,10,0
index db 0
target db 0
slot db 0
kind db 0
logical db 0
found_extended db 0
reuse_ebr db 0
chain_count db 0
capacity ds 4
first ds 4
last ds 4
extbase ds 4
extend ds 4
ebr ds 4
last_table ds 4
count dw 0
descriptor ds 6
sector ds 512
backup ds 512
verify ds 512
mbr_saved ds 512
