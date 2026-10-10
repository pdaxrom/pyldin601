; MBR/EBR validation. Extended bounds live in state+20..23, next in +16..19.
save_link
    jsr state_pointer
    clr 16,x
    clr 17,x
    clr 18,x
    clr 19,x
    clr PJ
    ldx PP
    tst 0,x
    beq far_scan_0
    jmp scan_link_bad
far_scan_0
    ldaa 4,x
    beq far_scan_1
    jmp long_branch_0_6
far_scan_1
    jmp scan_link_empty
long_branch_0_6
    jsr is_extended
    beq far_scan_2
    jmp scan_link_bad
far_scan_2
    ldx PP
    ldaa 8,x
    oraa 9,x
    oraa 10,x
    oraa 11,x
    bne far_scan_3
    jmp scan_link_bad
far_scan_3
    ldaa 12,x
    oraa 13,x
    oraa 14,x
    oraa 15,x
    bne far_scan_4
    jmp scan_link_bad
far_scan_4
    ; next=extended base + relative link, detect addition wrap.
    ldaa 8,x
    adda PX
    staa PE+0
    ldaa 9,x
    adca PX+1
    staa PE+1
    ldaa 10,x
    adca PX+2
    staa PE+2
    ldaa 11,x
    adca PX+3
    staa PE+3
    bcc far_scan_5
    jmp scan_link_bad
far_scan_5
    jsr state_pointer
    ldaa PE
    staa 16,x
    ldaa PE+1
    staa 17,x
    ldaa PE+2
    staa 18,x
    ldaa PE+3
    staa 19,x
    stx P0
    ldx PP
    ldaa 12,x
    adda PE
    ldx P0
    staa 8,x
    ldx PP
    ldaa 13,x
    adca PE+1
    ldx P0
    staa 9,x
    ldx PP
    ldaa 14,x
    adca PE+2
    ldx P0
    staa 10,x
    ldx PP
    ldaa 15,x
    adca PE+3
    ldx P0
    staa 11,x
    bcc far_scan_6
    jmp scan_link_bad
far_scan_6
    ldaa 20,x
    suba 8,x
    ldaa 21,x
    sbca 9,x
    ldaa 22,x
    sbca 10,x
    ldaa 23,x
    sbca 11,x
    bcc far_scan_7
    jmp scan_link_bad
far_scan_7
    ; Recover current EBR address saved before reading its link.
    ldaa 36,x
    staa PE
    ldaa 37,x
    staa PE+1
    ldaa 38,x
    staa PE+2
    ldaa 39,x
    staa PE+3
    inc PJ
    clra
    rts
scan_link_empty
    ldaa 8,x
    oraa 9,x
    oraa 10,x
    oraa 11,x
    oraa 12,x
    oraa 13,x
    oraa 14,x
    oraa 15,x
    beq far_scan_8
    jmp scan_link_bad
far_scan_8
    clra
    rts
scan_link_bad
    ldaa #9
    rts
append_logical
    ldx PP
    tst 4,x
    bne logical_present
    ldaa 0,x
    oraa 8,x
    oraa 9,x
    oraa 10,x
    oraa 11,x
    oraa 12,x
    oraa 13,x
    oraa 14,x
    oraa 15,x
    beq logical_empty
    jmp new_bad
logical_empty
    clra
    rts
logical_present
    jsr new_record
    tsta
    beq far_scan_9
    jmp logical_return
far_scan_9
    ldx PR
    ldaa 9,x
    jsr is_extended
    bne far_scan_10
    jmp logical_bad
far_scan_10
    ldx PR
    ; A logical volume cannot start at its EBR sector.
    ldaa 0,x
    oraa 1,x
    oraa 2,x
    oraa 3,x
    bne far_scan_11
    jmp logical_bad
far_scan_11
    ldaa 0,x
    adda PE
    staa 0,x
    ldaa 1,x
    adca PE+1
    staa 1,x
    ldaa 2,x
    adca PE+2
    staa 2,x
    ldaa 3,x
    adca PE+3
    staa 3,x
    bcs logical_bad
    ldaa PE
    staa 16,x
    ldaa PE+1
    staa 17,x
    ldaa PE+2
    staa 18,x
    ldaa PE+3
    staa 19,x
    jsr record_bounds
    tsta
    beq far_scan_12
    jmp logical_return
far_scan_12
    ; end <= extended end. Relative start is positive, EBR is in container.
    jsr state_pointer
    ldaa 8,x
    suba 20,x
    ldaa 9,x
    sbca 21,x
    ldaa 10,x
    sbca 22,x
    ldaa 11,x
    sbca 23,x
    bcs logical_append
    ldaa 8,x
    eora 20,x
    staa 14,x
    ldaa 9,x
    eora 21,x
    oraa 14,x
    staa 14,x
    ldaa 10,x
    eora 22,x
    oraa 14,x
    staa 14,x
    ldaa 11,x
    eora 23,x
    oraa 14,x
    bne logical_bad
logical_append
    inc PN
    clra
logical_return
    rts
logical_bad
    jmp new_bad
next_ebr
    tst PJ
    beq next_done
    jsr state_pointer
    ldaa 16,x
    suba PX
    ldaa 17,x
    sbca PX+1
    ldaa 18,x
    sbca PX+2
    ldaa 19,x
    sbca PX+3
    bcs next_bad
    ldaa 16,x
    suba 20,x
    ldaa 17,x
    sbca 21,x
    ldaa 18,x
    sbca 22,x
    ldaa 19,x
    sbca 23,x
    bcc next_bad
    ldaa 16,x
    staa PE
    ldaa 17,x
    staa PE+1
    ldaa 18,x
    staa PE+2
    ldaa 19,x
    staa PE+3
next_done
    clra
    rts
next_bad
    ldaa #9
    rts
; Pairwise range validation. start A in state+24..27, end A in +28..31.
validate_primaries
    clr PL
primary_outer
    ldaa PL
    cmpa PN
    bcs far_scan_13
    jmp ranges_valid
far_scan_13
    staa PI
    jsr save_outer
    ldaa PL
    inca
    staa PJ
primary_inner
    ldaa PJ
    cmpa PN
    bcc primary_next
    staa PI
    jsr record_pointer
    jsr ranges_overlap
    bcc far_scan_14
    jmp ranges_bad
far_scan_14
    inc PJ
    bra primary_inner
primary_next
    inc PL
    bra primary_outer
ranges_valid
    clra
    rts
ranges_bad
    ldaa #9
    rts
save_outer
    jsr record_pointer
    jsr record_bounds
    jsr state_pointer
    ldaa 8,x
    staa 28,x
    ldaa 9,x
    staa 29,x
    ldaa 10,x
    staa 30,x
    ldaa 11,x
    staa 31,x
    stx P0
    ldx PR
    ldaa 0,x
    ldx P0
    staa 24,x
    ldx PR
    ldaa 1,x
    ldx P0
    staa 25,x
    ldx PR
    ldaa 2,x
    ldx P0
    staa 26,x
    ldx PR
    ldaa 3,x
    ldx P0
    staa 27,x
    rts
ranges_overlap
    jsr record_bounds
    jsr state_pointer
    ldaa 24,x
    suba 8,x
    ldaa 25,x
    sbca 9,x
    ldaa 26,x
    sbca 10,x
    ldaa 27,x
    sbca 11,x
    bcc ranges_disjoint
    stx P0
    ldx PR
    ldaa 0,x
    ldx P0
    suba 28,x
    ldx PR
    ldaa 1,x
    ldx P0
    sbca 29,x
    ldx PR
    ldaa 2,x
    ldx P0
    sbca 30,x
    ldx PR
    ldaa 3,x
    ldx P0
    sbca 31,x
    rts
ranges_disjoint
    clc
    rts
validate_logicals
    clr PL
logical_outer
    ldaa PL
    cmpa PN
    bcs far_scan_15
    jmp ranges_valid
far_scan_15
    staa PI
    jsr record_pointer
    ldx PR
    ldaa 9,x
    jsr is_extended
    beq logical_outer_next
    jsr save_outer
    ldaa PL
    inca
    staa PJ
logical_inner
    ldaa PJ
    cmpa PN
    bcc logical_outer_next
    staa PI
    jsr record_pointer
    ldx PR
    ldaa 9,x
    jsr is_extended
    beq logical_inner_next
    jsr ranges_overlap
    bcc far_scan_16
    jmp ranges_bad
far_scan_16
logical_inner_next
    inc PJ
    bra logical_inner
logical_outer_next
    inc PL
    bra logical_outer
validate_volumes
    clr PI
volumes_loop
    ldaa PI
    cmpa PN
    bcc volumes_done
    jsr record_pointer
    ldx PR
    ldaa 9,x
    cmpa #1
    bne volumes_next
    jsr volume_read
    bcs volumes_next
    jsr bpb_validate
    bcs volumes_next
    ldx PR
    ldaa #1
    staa 21,x
    ldx PS
    ldaa 20,x
    ldx PR
    staa 14,x
    ldx PS
    ldaa 19,x
    ldx PR
    staa 15,x
volumes_next
    inc PI
    bra volumes_loop
volumes_done
    clra
    rts
volume_read
    ldx PR
    ldaa 0,x
    staa PE
    ldaa 1,x
    staa PE+1
    ldaa 2,x
    staa PE+2
    ldaa 3,x
    staa PE+3
    jmp read_sector
; BPB fields must fit the actual UniDOS 27-byte header, not just FAT12 naming.
bpb_validate
    ldaa PS+1
    adda #$fe
    staa PP+1
    ldaa PS
    adca #1
    staa PP
    ldx PP
    ldaa 0,x
    ldab 1,x
    cmpa #$55
    bne bpb_native_signature
    cmpb #$aa
    beq bpb_size
bpb_native_signature
    cmpa #$a5
    beq far_scan_17
    jmp bpb_bad
far_scan_17
    cmpb #$5a
    beq far_scan_18
    jmp bpb_bad
far_scan_18
bpb_size
    ldx PS
    tst 11,x
    beq far_scan_19
    jmp bpb_bad
far_scan_19
    ldaa 12,x
    cmpa #2
    beq far_scan_20
    jmp bpb_bad
far_scan_20
    ldaa 13,x
    bne far_scan_21
    jmp bpb_bad
far_scan_21
    staa P0
    deca
    anda P0
    beq far_scan_22
    jmp bpb_bad
far_scan_22
    tst 14,x
    bne far_scan_23
    jmp bpb_bad
far_scan_23
    tst 15,x
    beq far_scan_24
    jmp bpb_bad
far_scan_24
    ldaa 16,x
    bne far_scan_25
    jmp bpb_bad
far_scan_25
    cmpa #2
    bls far_scan_26
    jmp bpb_bad
far_scan_26
    ldaa 17,x
    oraa 18,x
    bne far_scan_27
    jmp bpb_bad
far_scan_27
    ldaa 19,x
    oraa 20,x
    bne far_scan_28
    jmp bpb_bad
far_scan_28
    tst 22,x
    bne far_scan_29
    jmp bpb_bad
far_scan_29
    tst 23,x
    beq far_scan_30
    jmp bpb_bad
far_scan_30
    tst 24,x
    bne far_scan_31
    jmp bpb_bad
far_scan_31
    tst 25,x
    beq far_scan_32
    jmp bpb_bad
far_scan_32
    tst 26,x
    bne far_scan_33
    jmp bpb_bad
far_scan_33
    tst 27,x
    beq far_scan_34
    jmp bpb_bad
far_scan_34
    ; BPB total may not exceed its partition.
    ldaa 19,x
    staa P0+1
    ldaa 20,x
    staa P0
    ldx PR
    tst 7,x
    bne bpb_total_ok
    tst 6,x
    bne bpb_total_ok
    ldaa 5,x
    cmpa P0
    bcs bpb_bad
    bhi bpb_total_ok
    ldaa 4,x
    cmpa P0+1
    bcs bpb_bad
bpb_total_ok
    jmp bpb_arithmetic
bpb_bad
    sec
    rts
bpb_arithmetic
    ; ceil(root entries/16), then reserved + FAT copies*SPF.
    ldx PS
    ldaa 18,x
    ldab 17,x
    staa PT
    stab PT+1
    ldx PT
    ldaa #16
    clrb
    int $29
    stx PT
    tstb
    beq bpb_root_done
    inx
    stx PT
bpb_root_done
    ldx PS
    ldaa 14,x
    adda PT+1
    staa PT+1
    ldaa PT
    adca #0
    staa PT
    ldab 16,x
bpb_fat_overhead
    ldaa PT+1
    adda 22,x
    staa PT+1
    ldaa PT
    adca #0
    staa PT
    decb
    bne bpb_fat_overhead
    ldaa P0+1
    suba PT+1
    staa PT+1
    ldaa P0
    sbca PT
    staa PT
    bcs bpb_bad
    ldaa PT
    oraa PT+1
    bne far_scan_35
    jmp bpb_bad
far_scan_35
    ldaa 13,x
    ldx PT
    clrb
    int $29
    stx PT
    ldaa PT
    cmpa #$0f
    bcs bpb_clusters_ok
    bls far_scan_36
    jmp bpb_bad
far_scan_36
    ldaa PT+1
    cmpa #$f5
    bcs far_scan_37
    jmp bpb_bad
far_scan_37
bpb_clusters_ok
    cpx #0
    bne far_scan_38
    jmp bpb_bad
far_scan_38
    inx
    inx
    stx PT
    ; ceil(3*(clusters+2)/1024) is the FAT's required sector count.
    ldaa PT+1
    adda PT+1
    staa P0+1
    ldaa PT
    adca PT
    staa P0
    ldaa P0+1
    adda PT+1
    staa P0+1
    ldaa P0
    adca PT
    staa P0
    lsra
    lsra
    tab
    ldaa P0
    anda #3
    oraa P0+1
    beq bpb_fat_required
    incb
bpb_fat_required
    ldx PS
    cmpb 22,x
    bls far_scan_39
    jmp bpb_bad
far_scan_39
    clc
    rts

; Bounded visited-table list accepts backward chains and detects cycles even
; when an EBR has no volume. No table sector may be inside any data volume.
visited_pointer
    ldaa PW+1
    adda #$80
    staa PP+1
    ldaa PW
    adca #5
    staa PP
    rts
remember_ebr
    jsr state_pointer
    ldaa 40,x
    cmpa #32
    bcc visited_bad
    staa PJ
    jsr visited_pointer
    ldx PP
    ldab PJ
    beq visited_store
visited_loop
    ldaa 0,x
    cmpa PE
    bne visited_next
    ldaa 1,x
    cmpa PE+1
    bne visited_next
    ldaa 2,x
    cmpa PE+2
    bne visited_next
    ldaa 3,x
    cmpa PE+3
    beq visited_bad
visited_next
    inx
    inx
    inx
    inx
    decb
    bne visited_loop
visited_store
    ldaa PE
    staa 0,x
    ldaa PE+1
    staa 1,x
    ldaa PE+2
    staa 2,x
    ldaa PE+3
    staa 3,x
    jsr state_pointer
    inc 40,x
    clra
    rts
visited_bad
    ldaa #9
    rts
validate_table_sectors
    clr PL
table_outer
    jsr state_pointer
    ldaa PL
    cmpa 40,x
    bcs table_next
    clra
    rts
table_next
    jsr visited_pointer
    ldaa PL
    asla
    asla
    adda PP+1
    staa PP+1
    ldaa PP
    adca #0
    staa PP
    ldx PP
    ldaa 0,x
    staa PE
    ldaa 1,x
    staa PE+1
    ldaa 2,x
    staa PE+2
    ldaa 3,x
    staa PE+3
    clr PI
table_inner
    ldaa PI
    cmpa PN
    bcc table_outer_next
    jsr record_pointer
    ldx PR
    ldaa 9,x
    jsr is_extended
    beq table_inner_next
    jsr record_bounds
    ldx PR
    ldaa PE
    suba 0,x
    ldaa PE+1
    sbca 1,x
    ldaa PE+2
    sbca 2,x
    ldaa PE+3
    sbca 3,x
    bcs table_inner_next
    jsr state_pointer
    ldaa PE
    suba 8,x
    ldaa PE+1
    sbca 9,x
    ldaa PE+2
    sbca 10,x
    ldaa PE+3
    sbca 11,x
    bcc scan_branch_1
    jmp visited_bad
scan_branch_1
table_inner_next
    inc PI
    bra table_inner
table_outer_next
    inc PL
    jmp table_outer
