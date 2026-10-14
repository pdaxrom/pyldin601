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
    bcc boot_done
    staa PI
    jsr record_pointer
    ldx PR
    tst 21,x
    beq boot_mount_next
    ldaa 11,x
    cmpa #$ff
    bne boot_mount_next
    ; Preserve the shipped A/B/C mapping. Bootstrap FAT16 PART1 is available
    ; through an explicit MOUNT, but never consumes B: during AUTO startup.
    ldaa 8,x
    cmpa #1
    bne boot_mount_user
    ldaa 22,x
    cmpa #16
    beq boot_mount_next
boot_mount_user
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
boot_done
    clra
    rts
