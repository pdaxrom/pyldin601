; System BIOS invokes this after every native ROM has registered its services.
; Explicit partition selection is read from the retained primary BIOS port.
; AUTO uses active FAT12, then legacy partition 2 and partition 3.
boot
    jsr install_parts
    tsta
    beq boot_installed
    rts
boot_installed
    ; Preserve native permanent header buffers, then replace A/B drivers.
    jsr state_pointer
    ldaa HEAD_TABLE
    staa 32,x
    ldaa HEAD_TABLE+1
    staa 33,x
    ldaa HEAD_TABLE+2
    staa 34,x
    ldaa HEAD_TABLE+3
    staa 35,x
    ldx #HEAD_TABLE
    ldab #16
boot_clear_drives
    clr 0,x
    inx
    decb
    bne boot_clear_drives
    ldaa $e6ae
    cmpa #$ff
    beq boot_auto
    tsta
    beq boot_auto
    staa PB
    jsr mount_number
    tsta
    beq boot_mount_rest
    rts
boot_auto
    clr PI
boot_active
    ldaa PI
    cmpa PN
    bcc boot_fallback_a
    jsr record_pointer
    ldx PR
    tst 21,x
    beq boot_active_next
    tst 10,x
    beq boot_active_next
    ldaa 8,x
    staa PB
    jsr mount_number
    tsta
    beq boot_mount_rest
boot_active_next
    inc PI
    bra boot_active
boot_fallback_a
    ldaa #2
    staa PB
    jsr mount_number
    tsta
    beq boot_mount_rest
    ldaa #3
    staa PB
    jsr mount_number
    tsta
    beq boot_mount_rest
    rts
boot_mount_rest
    clr PL
boot_mount_loop
    ldaa PL
    cmpa PN
    bcc boot_shell
    staa PI
    jsr record_pointer
    ldx PR
    tst 21,x
    beq boot_mount_next
    ldaa 11,x
    cmpa #$ff
    bne boot_mount_next
    ldaa 8,x
    staa PB
    ; mount uses PJ and never PL, so the scan index remains owned here.
    jsr mount_number
    tsta
    beq boot_mount_next
    cmpa #27
    beq boot_mount_next
    rts
boot_mount_next
    inc PL
    bra boot_mount_loop
boot_shell
    int $2c
    ; First part of the command interpreter is copied by the separate F page.
    int $e3
    ldx #shell_tail
    stx PP
    ldx #$1000+SHELL_SPLIT
    stx PT
    ldx #SHELL_LENGTH-SHELL_SPLIT
    stx P0
boot_shell_copy
    ldx PP
    ldaa 0,x
    inx
    stx PP
    ldx PT
    staa 0,x
    inx
    stx PT
    ldx P0
    dex
    stx P0
    cpx #0
    bne boot_shell_copy
    jsr $1000
    clra
    rts
    include SHELLTAIL.INC
