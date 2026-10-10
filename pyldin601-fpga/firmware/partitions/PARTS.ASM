; Partition service ROM, page A, MC6800 compatible.
; Uses DOS heap ownership, not borrowed DOS/video/keyboard zero-page registers.
; One physical SD0. Primary numbers 1..4, EBR numbers 5..36. Limit 32 records.
; Record (24 bytes): baseLE32,countLE32,number,type,active,drive(FF=unmounted),
; headerBE16,totalBE16,tableLBA LE32,slot,valid,0,0.
SWIA equ 6
SWIB equ 5
HEAD_TABLE equ $eb03
CURRENT_DRIVE equ $eb00
PW equ $bf80
PN equ $bf82
PI equ $bf83
PP equ $bf84
PR equ $bf86
PS equ $bf88
PA equ $bf8a
PT equ $bf8c
PB equ $bf8e
PF equ $bf8f
PE equ $bf90
PX equ $bf94
PL equ $bf98
PJ equ $bf99
P0 equ $bf9a
WORK_SIZE equ 1536
VISITED_OFFSET equ 1408
REC_OFFSET equ 512
MBR_OFFSET equ 1280
STATE_OFFSET equ 1344
    org $c000
    dw $a55a
    db "SDPARTS "
    jmp initialize
    jmp version
    db $e1
    dw dispatch
    db 0
version
    rts
initialize
    clr PW
    clr PW+1
    clr PF
    rts
dispatch
    stx PA
    stab PB
    tsta
    bne parts_branch_1
    jmp install
parts_branch_1
    cmpa #1
    beq get_record
    cmpa #2
    bne dispatch_unmount
    jsr mount_number
    jmp result
dispatch_unmount
    cmpa #3
    bne dispatch_drive
    jsr find_number
    bcs result
    jsr unmount
    jmp result
dispatch_drive
    cmpa #4
    bne dispatch_boot
    jsr find_drive
    bcs result
    jsr unmount
    jmp result
dispatch_boot
    cmpa #5
    bne dispatch_system_boot
    jsr refresh
    jmp result
dispatch_system_boot
    cmpa #6
    bne dispatch_final_boot
    jsr format_number
    jmp result
dispatch_final_boot
    cmpa #7
    bne dispatch_bad
    jsr boot
    jmp result
dispatch_bad
    ldaa #1
result
    staa SWIA
    rts
get_record
    ldaa PB
    cmpa PN
    bcs record_index_ok
    ldaa #2
    jmp result
record_index_ok
    staa PI
    jsr record_pointer
    ldx PA
    stx PP
    ldab #24
record_copy
    ldx PR
    ldaa 0,x
    inx
    stx PR
    ldx PP
    staa 0,x
    inx
    stx PP
    decb
    bne record_copy
    clra
    jmp result
install
    jsr install_parts
    jmp result
; Allocate one sector, 32 records, MBR snapshot and operation descriptors.
; The 768-byte rollback copy is allocated only during a rescan. Keeping it
; permanently would leave too little RAM for the original GD on model 601A.
install_parts
    tst PF
    beq install_allocate
    clra
    rts
install_allocate
    ldx PW
    cpx #0
    bne install_work
    ldx #WORK_SIZE
    clrb
    int $2a
    cpx #0
    bne install_work
    ldaa #6
    rts
install_work
    stx PW
    stx PS
    stx PP
    ldx #WORK_SIZE
    stx PT
    jsr zero_memory
    ldx PW
    clra
    int $e2
    tsta
    beq install_capacity
    rts
install_capacity
    jsr scan
    tsta
    beq install_scanned
    rts
install_scanned
    inc PF
    clra
    rts
; PP destination, PT byte count. Preserves PW, PS.
zero_memory
    ldx PP
zero_loop
    clr 0,x
    inx
    stx PP
    ldx PT
    dex
    stx PT
    cpx #0
    beq zero_done
    ldx PP
    bra zero_loop
zero_done
    rts
; Compute record pointer from zero-based PI. No 6801 MUL/ABX dependency.
record_pointer
    ldaa PW+1
    staa PR+1
    ldaa PW
    adda #2
    staa PR
    ldab PI
    beq record_pointer_done
record_pointer_loop
    ldaa PR+1
    adda #24
    staa PR+1
    ldaa PR
    adca #0
    staa PR
    decb
    bne record_pointer_loop
record_pointer_done
    rts
state_pointer
    ldaa PW+1
    adda #$40
    staa PT+1
    ldaa PW
    adca #5
    staa PT
    ldx PT
    rts
; Read physical PE into PS. Raw descriptor lives in the allocated state.
read_sector
    jsr state_pointer
    ldaa PS
    staa 0,x
    ldaa PS+1
    staa 1,x
    ldaa PE
    staa 2,x
    ldaa PE+1
    staa 3,x
    ldaa PE+2
    staa 4,x
    ldaa PE+3
    staa 5,x
    ldaa #1
    int $e2
    tsta
    beq read_done
    sec
    rts
read_done
    clc
    rts
sector_signature
    ldaa PS+1
    adda #$fe
    staa PP+1
    ldaa PS
    adca #1
    staa PP
    ldx PP
    ldaa 0,x
    cmpa #$55
    bne signature_bad
    ldaa 1,x
    cmpa #$aa
    bne signature_bad
    clc
    rts
signature_bad
    sec
    rts
scan
    jsr state_pointer
    clr 40,x
    clr PN
    clr PE
    clr PE+1
    clr PE+2
    clr PE+3
    clr PX
    clr PX+1
    clr PX+2
    clr PX+3
    jsr read_sector
    bcc scan_signature
    rts
scan_signature
    jsr sector_signature
    bcc scan_copy_mbr
    jmp scan_bad
scan_copy_mbr
    ; Snapshot all 4 MBR entries before BPB/EBR reads overwrite the sector.
    ldaa PS+1
    adda #$be
    staa PR+1
    ldaa PS
    adca #1
    staa PR
    ldaa PW+1
    staa PP+1
    ldaa PW
    adda #5
    staa PP
    ldab #64
scan_copy_loop
    ldx PR
    ldaa 0,x
    inx
    stx PR
    ldx PP
    staa 0,x
    inx
    stx PP
    decb
    bne scan_copy_loop
    ldaa #1
    staa PL
    clr PJ
scan_primary
    ldaa PW+1
    staa PP+1
    ldaa PW
    adda #5
    staa PP
    ldaa PJ
    asla
    asla
    asla
    asla
    adda PP+1
    staa PP+1
    ldaa PP
    adca #0
    staa PP
    jsr append_primary
    tsta
    beq far_parts_0
    jmp scan_return
far_parts_0
    inc PL
    inc PJ
    ldaa PJ
    cmpa #4
    bne scan_primary
    ; Validate pairwise disjoint primary partitions before following EBRs.
    jsr validate_primaries
    tsta
    beq far_parts_1
    jmp scan_return
far_parts_1
    ldaa PX
    oraa PX+1
    oraa PX+2
    oraa PX+3
    bne far_parts_2
    jmp scan_validate
far_parts_2
    ldaa PX
    staa PE
    ldaa PX+1
    staa PE+1
    ldaa PX+2
    staa PE+2
    ldaa PX+3
    staa PE+3
    ldaa #5
    staa PL
scan_ebr
    jsr remember_ebr
    tsta
    beq scan_ebr_read
    rts
scan_ebr_read
    jsr read_sector
    bcc far_parts_3
    jmp scan_return
far_parts_3
    jsr sector_signature
    bcc far_parts_4
    jmp scan_bad
far_parts_4
    ; Reject nonzero entries 3/4; do not reinterpret another computer's table.
    ldaa PS+1
    adda #$de
    staa PP+1
    ldaa PS
    adca #1
    staa PP
    ldx PP
    ldab #32
scan_ebr_extra
    tst 0,x
    bne scan_bad
    inx
    decb
    bne scan_ebr_extra
    ; Store the next link before any validation reads a BPB.
    ldaa PS+1
    adda #$ce
    staa PP+1
    ldaa PS
    adca #1
    staa PP
    jsr state_pointer
    ldaa PE
    staa 36,x
    ldaa PE+1
    staa 37,x
    ldaa PE+2
    staa 38,x
    ldaa PE+3
    staa 39,x
    jsr save_link
    tsta
    beq far_parts_5
    jmp scan_return
far_parts_5
    ldaa PS+1
    adda #$be
    staa PP+1
    ldaa PS
    adca #1
    staa PP
    jsr append_logical
    tsta
    beq far_parts_6
    jmp scan_return
far_parts_6
    jsr next_ebr
    tsta
    beq far_parts_7
    jmp scan_return
far_parts_7
    tst PJ
    bne far_parts_8
    jmp scan_validate
far_parts_8
    inc PL
    ldaa PL
    cmpa #37
    bcc scan_bad
    jmp scan_ebr
scan_validate
    jsr validate_logicals
    tsta
    beq far_parts_9
    jmp scan_return
far_parts_9
    jsr validate_table_sectors
    tsta
    bne scan_return
    jsr validate_volumes
scan_return
    rts
scan_bad
    ldaa #9
    rts
; Copy an entry into a new record, validate start+count/capacity and boot flag.
new_record
    ldx PP
    ldaa 0,x
    beq new_flag_ok
    cmpa #$80
    bne new_bad
new_flag_ok
    ldaa PN
    cmpa #32
    bcc new_bad
    staa PI
    jsr record_pointer
    ldx PR
    ldab #24
new_zero
    clr 0,x
    inx
    decb
    bne new_zero
    ldx PP
    ldaa 0,x
    ldx PR
    staa 10,x
    ldx PP
    ldaa 4,x
    ldx PR
    staa 9,x
    ldaa PL
    staa 8,x
    ldaa #$ff
    staa 11,x
    ; PP points to source entry; PR to destination.
    ldab #4
new_fields
    ldx PP
    ldaa 8,x
    ldx PR
    staa 0,x
    ldx PP
    ldaa 12,x
    inx
    stx PP
    ldx PR
    staa 4,x
    inx
    stx PR
    decb
    bne new_fields
    ; Restore both pointers after field copy.
    jsr record_pointer
    ldaa PP+1
    suba #4
    staa PP+1
    ldaa PP
    sbca #0
    staa PP
    clra
    rts
new_bad
    ldaa #9
    rts
append_primary
    ldx PP
    tst 4,x
    bne primary_nonempty
    ; Empty entry must have empty start/count and boot flag.
    ldaa 0,x
    oraa 8,x
    oraa 9,x
    oraa 10,x
    oraa 11,x
    oraa 12,x
    oraa 13,x
    oraa 14,x
    oraa 15,x
    beq primary_empty
    jmp new_bad
primary_empty
    clra
    rts
primary_nonempty
    jsr new_record
    tsta
    bne primary_return
    ldx PR
    ldaa PJ
    staa 20,x
    jsr record_bounds
    tsta
    bne primary_return
    ldx PR
    ldaa 9,x
    jsr is_extended
    bne primary_append
    ldaa PX
    oraa PX+1
    oraa PX+2
    oraa PX+3
    bne primary_bad
    ldx PR
    ldaa 0,x
    staa PX
    ldaa 1,x
    staa PX+1
    ldaa 2,x
    staa PX+2
    ldaa 3,x
    staa PX+3
    jsr state_pointer
    ldaa 8,x
    staa 20,x
    ldaa 9,x
    staa 21,x
    ldaa 10,x
    staa 22,x
    ldaa 11,x
    staa 23,x
primary_append
    inc PN
    clra
primary_return
    rts
primary_bad
    jmp new_bad
is_extended
    cmpa #5
    beq extended_yes
    cmpa #$0f
    beq extended_yes
    cmpa #$85
extended_yes
    rts
; Compute end in state+8. Return error on zero or overflow or > card capacity.
record_bounds
    jsr state_pointer
    stx P0
    ldx PR
    ldaa 0,x
    oraa 1,x
    oraa 2,x
    oraa 3,x
    beq record_bad
    ldaa 4,x
    oraa 5,x
    oraa 6,x
    oraa 7,x
    beq record_bad
    ldab #4
    clc
record_add
    ldx PR
    ldaa 0,x
    adca 4,x
    inx
    stx PR
    ldx P0
    staa 8,x
    inx
    stx P0
    decb
    bne record_add
    bcs record_bad
    jsr record_pointer
    jsr state_pointer
    ; End <= physical card capacity (LE subtraction).
    ldaa 8,x
    suba $bf9c
    ldaa 9,x
    sbca $bf9d
    ldaa 10,x
    sbca $bf9e
    ldaa 11,x
    sbca $bf9f
    bcs record_valid
    ; Equal end is allowed; greater end is not.
    ldaa 8,x
    eora $bf9c
    staa 12,x
    ldaa 9,x
    eora $bf9d
    oraa 12,x
    staa 12,x
    ldaa 10,x
    eora $bf9e
    oraa 12,x
    staa 12,x
    ldaa 11,x
    eora $bf9f
    oraa 12,x
    bne record_bad
record_valid
    clra
    rts
record_bad
    jsr record_pointer
    ldaa #9
    rts
; A=partition number / drive lookup, PB is the saved key.
find_number
    clr PI
find_number_loop
    ldaa PI
    cmpa PN
    bcc find_missing
    jsr record_pointer
    ldx PR
    ldaa 8,x
    cmpa PB
    beq find_ok
    inc PI
    bra find_number_loop
find_drive
    clr PI
find_drive_loop
    ldaa PI
    cmpa PN
    bcc find_missing
    jsr record_pointer
    ldx PR
    ldaa 11,x
    cmpa PB
    beq find_ok
    inc PI
    bra find_drive_loop
find_missing
    ldaa #2
    sec
    rts
find_ok
    clra
    clc
    rts
    include SCAN.INC
    include MOUNT.INC
    include FORMAT.INC
    include REFRESH.INC
    include BOOT.INC
parts_end
    checksum
    ds $e000-*,$ff
    end
