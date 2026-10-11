; MC6800-compatible expansion RAM manager, ROM page E, INT E5.
; 0 info -> A=1 ABI, B=free banks, X=111 total banks.
; 1 allocate B=1..111, X=RAM descriptor (3+B bytes): tokenBE,count,bank IDs.
; 2 release X=descriptor; token AND current UniDOS PCB must match.
; 3 release all leases owned by the current PCB (also called by close_PCB).
; Other functions return A=1. Operations: A=0 OK,1 argument,2 no memory,
; 3 stale/foreign token,4 unavailable,5 reentrant call. B/X preserved.
; Arbitrary free banks are gathered, so fragmentation does not lose capacity.
; No page writes or data erasure. BIOS preserves both page registers.
; INT E5 points to a three-byte resident JMP gateway (with ROM page E).
; That native vector is also the state pointer. All table/scratch bytes
; live in the same 240-byte BIOS allocation; no borrowed DOS variables.
RM_STATE equ $efca
RM_PCB equ $ec00
RM_A equ $06
RM_B equ $05
RM_X equ $07
RM_SIZE equ 240
RM_LEASES equ 32
RM_BANKS equ 112
; State scratch offsets; lease: cookieBE, ownerPCB BE, count (16 x 5 bytes).
    org $c000
    dw $5aa5
    db "RAMBANKS"
    jmp ram_initialize
    jmp ram_version
    db $e5
    dw ram_gateway
    .ifdef WITH_GAMEBIOS
    db $e6
    dw game_gateway
    .endif
    db 0
ram_version
    rts
ram_initialize
    ldaa $e6f2
    cmpa #'R'
    bne ram_init_done
    ldaa $e6f3
    cmpa #111
    bne ram_init_done
    ldx #RM_SIZE
    clrb
    int $2a
    cpx #0
    beq ram_init_done
    stx RM_STATE
    ldab #RM_SIZE
ram_init_clear
    clr 0,x
    inx
    decb
    bne ram_init_clear
    ldx RM_STATE
    ldaa ram_gateway
    staa 0,x
    ldaa ram_gateway+1
    staa 1,x
    ldaa ram_gateway+2
    staa 2,x
    ldaa #111
    staa 6,x
    int $2c
ram_init_done
    .ifdef WITH_GAMEBIOS
    jsr game_initialize
    .endif
    rts
ram_gateway
    jmp ram_dispatch
ram_dispatch
    sei
    psha
    ldx RM_STATE
    ldaa RM_STATE
    cmpa #1
    bcs ram_state_missing
    cmpa #$be
    bcs ram_has_state
ram_state_missing
    pula
    ldaa #4
    staa RM_A
    rts
ram_has_state
    tst 5,x
    beq ram_lock
    pula
    ldaa #5
    staa RM_A
    rts
ram_lock
    inc 5,x
    stab 10,x
    pula
    staa 21,x
    ldaa RM_X
    staa 11,x
    ldaa RM_X+1
    staa 12,x
    ldaa 21,x
    tsta
    beq ram_info
    cmpa #3
    bne ram_descriptor
    jmp ram_release_owner
ram_descriptor
    cmpa #1
    beq ram_allocate_check
    cmpa #2
    bne ram_unknown
    jmp ram_release_check
ram_unknown
    jmp ram_argument
ram_info
    ldaa 6,x
    staa RM_B
    ldx #111
    stx RM_X
    ldaa #1
    jmp ram_result
ram_allocate_check
    ldaa 10,x
    beq ram_argument
    cmpa #111
    bhi ram_argument
    cmpa 6,x
    bhi ram_no_memory
    jsr ram_check_descriptor
    bcs ram_argument
    ldx RM_PCB
    cpx #0
    beq ram_argument
    ldx RM_STATE
    ldaa #1
    staa 8,x
    ldaa 12,x
    adda #3
    staa 17,x
    ldaa 11,x
    adca #0
    staa 18,x
    ; Store the correct big-endian output pointer at offsets 17/18.
    ldaa 17,x
    ldab 18,x
    stab 17,x
    staa 18,x
    ; RAM pointer arithmetic is MC6800 compatible.
    ldx RM_STATE
    ldab #RM_LEASES
ram_table_start
    inx
    decb
    bne ram_table_start
ram_find_lease
    tst 4,x
    beq ram_lease_found
    inx
    inx
    inx
    inx
    inx
    stx RM_X
    ldx RM_STATE
    inc 8,x
    ldaa 8,x
    cmpa #17
    beq ram_no_memory
    ldx RM_X
    bra ram_find_lease
ram_argument
    ldaa #1
    jmp ram_result
ram_no_memory
    ldaa #2
    jmp ram_result
ram_lease_found
    ; Scratch pointer must not change the caller's returned X.
    stx RM_X
    ldx RM_STATE
    ldaa RM_X
    staa 13,x
    ldaa RM_X+1
    staa 14,x
    inc 4,x
    bne ram_cookie_ready
    inc 3,x
ram_cookie_ready
    ldaa 3,x
    oraa 4,x
    bne ram_cookie_nonzero
    inc 4,x
ram_cookie_nonzero
    ; Avoid live-cookie collisions when the 16-bit sequence wraps.
    ldaa 3,x
    ldab 4,x
    psha
    pshb
    ldab #RM_LEASES
ram_cookie_table
    inx
    decb
    bne ram_cookie_table
    stx RM_X
    ldx RM_STATE
    ldaa #16
    staa 22,x
    ldx RM_X
    pulb
    pula
ram_cookie_unique
    tst 4,x
    beq ram_cookie_unique_next
    cmpa 0,x
    bne ram_cookie_unique_next
    cmpb 1,x
    bne ram_cookie_unique_next
    ldx RM_STATE
    inc 4,x
    bne ram_cookie_retry
    inc 3,x
ram_cookie_retry
    jmp ram_cookie_ready
ram_cookie_unique_next
    inx
    inx
    inx
    inx
    inx
    stx RM_X
    ldx RM_STATE
    dec 22,x
    beq ram_cookie_chosen
    ldx RM_X
    bra ram_cookie_unique
ram_cookie_chosen
    ldaa 3,x
    ldab 4,x
    ldx 13,x
    staa 0,x
    stab 1,x
    ldaa RM_PCB
    staa 2,x
    ldaa RM_PCB+1
    staa 3,x
    ldx RM_STATE
    ldaa 10,x
    staa 9,x
    ldx 13,x
    staa 4,x
    ldx RM_STATE
    ldaa 3,x
    ldab 4,x
    ldx 11,x
    staa 0,x
    stab 1,x
    ldx RM_STATE
    ldaa 10,x
    ldx 11,x
    staa 2,x
    ldx RM_STATE
    clr 7,x
    ldab #RM_BANKS
ram_bank_start
    inx
    decb
    bne ram_bank_start
ram_gather
    tst 0,x
    bne ram_gather_next
    stx RM_X
    ldx RM_STATE
    ldaa 8,x
    ldx RM_X
    staa 0,x
    ldx RM_STATE
    dec 6,x
    ldaa 7,x
    ldx 17,x
    staa 0,x
    inx
    stx RM_X
    ldx RM_STATE
    ldaa RM_X
    staa 17,x
    ldaa RM_X+1
    staa 18,x
    dec 9,x
    bne ram_gather_remaining
    jmp ram_success
ram_gather_remaining
    ; Rebuild bank table cursor from the saved physical bank ID.
    ldaa 7,x
    ldab #RM_BANKS
    aba
ram_cursor
    inx
    deca
    bne ram_cursor
ram_gather_next
    inx
    stx RM_X
    ldx RM_STATE
    inc 7,x
    ldx RM_X
    bra ram_gather
ram_release_check
    jsr ram_check_descriptor
    bcc ram_release_valid
    jmp ram_argument
ram_release_valid
    ldx RM_STATE
    ldaa #1
    staa 8,x
    ldab #RM_LEASES
ram_release_table
    inx
    decb
    bne ram_release_table
ram_find_cookie
    tst 4,x
    beq ram_cookie_next
    stx RM_X
    ldx RM_STATE
    ldx 11,x
    ldaa 0,x
    ldab 1,x
    ldx RM_X
    cmpa 0,x
    bne ram_cookie_next
    cmpb 1,x
    bne ram_cookie_next
    ldaa RM_PCB
    cmpa 2,x
    bne ram_bad_cookie
    ldaa RM_PCB+1
    cmpa 3,x
    bne ram_bad_cookie
    jsr ram_free_lease
    ldx RM_STATE
    ldx 11,x
    clr 0,x
    clr 1,x
    clr 2,x
    bra ram_success
ram_cookie_next
    inx
    inx
    inx
    inx
    inx
    stx RM_X
    ldx RM_STATE
    inc 8,x
    ldaa 8,x
    cmpa #17
    beq ram_bad_cookie
    ldx RM_X
    bra ram_find_cookie
ram_bad_cookie
    ldaa #3
    bra ram_result
ram_release_owner
    ldaa #1
    staa 8,x
    ldab #RM_LEASES
ram_owner_table
    inx
    decb
    bne ram_owner_table
ram_owner_next
    tst 4,x
    beq ram_owner_skip
    ldaa RM_PCB
    cmpa 2,x
    bne ram_owner_skip
    ldaa RM_PCB+1
    cmpa 3,x
    bne ram_owner_skip
    jsr ram_free_lease
ram_owner_skip
    inx
    inx
    inx
    inx
    inx
    stx RM_X
    ldx RM_STATE
    inc 8,x
    ldaa 8,x
    cmpa #17
    beq ram_success
    ldx RM_X
    bra ram_owner_next
ram_success
    clra
ram_result
    psha
    ldx RM_STATE
    ldaa 21,x
    beq ram_keep_info_x
    ldaa 11,x
    staa RM_X
    ldaa 12,x
    staa RM_X+1
ram_keep_info_x
    clr 5,x
    pula
    staa RM_A
    rts
; Reject descriptors outside conventional application RAM. Count+3 bytes
; on allocate, three bytes on release; the banked C000 window is forbidden.
ram_check_descriptor
    ldx RM_STATE
    ldaa 12,x
    adda #3
    staa 16,x
    ldaa 11,x
    adca #0
    staa 15,x
    bcs ram_descriptor_bad
    ldaa 21,x
    cmpa #1
    bne ram_check_range
    ldaa 16,x
    adda 10,x
    staa 16,x
    ldaa 15,x
    adca #0
    staa 15,x
    bcs ram_descriptor_bad
ram_check_range
    tst 11,x
    beq ram_descriptor_bad
    ldaa 15,x
    cmpa #$be
    bhi ram_descriptor_bad
    bcs ram_check_resident
    tst 16,x
    bne ram_descriptor_bad
ram_check_resident
    ; Applications live below the allocator's permanent resident table.
    cmpa RM_STATE
    bcs ram_descriptor_good
    bhi ram_descriptor_bad
    ldaa 16,x
    cmpa RM_STATE+1
    bls ram_descriptor_good
ram_descriptor_bad
    sec
    rts
ram_descriptor_good
    clc
    rts
; X=lease entry, slot in state. Keep X so owner-release can iterate entries.
ram_free_lease
    clr 0,x
    clr 1,x
    clr 4,x
    pshb
    stx RM_X
    ldx RM_STATE
    ldaa RM_X
    staa 13,x
    ldaa RM_X+1
    staa 14,x
    ldaa 8,x
    ldab #RM_BANKS
ram_free_begin
    inx
    decb
    bne ram_free_begin
    ldab #111
ram_free_bank
    cmpa 0,x
    bne ram_free_next
    clr 0,x
    stx RM_X
    ldx RM_STATE
    inc 6,x
    ldx RM_X
ram_free_next
    inx
    decb
    bne ram_free_bank
    ldx RM_STATE
    ldx 13,x
    pulb
    rts
ram_end
    .ifdef WITH_GAMEBIOS
    include GAMEBIOS.ASM
    .endif
ram_image_end
    checksum
    ds $e000-*,$ff
    end
