; Native BIOS owns its services and coordinates boot through registered INTs.
; RESET is still reading restbl with SP in ROM: no pushes or JSR here.
    global bank_copy_init,native_boot
bank_copy_init
    ldx #bank_copy
    stx swivec+$1d0
    ldx #swivec
    jmp native_reset_vectors
native_boot
    ldaa #$e1
    int $2e
    cpx #0
    beq native_boot_disk_bad
    ldaa #$41
    int $2e
    cpx #0
    beq native_boot_kernel_bad
    ldaa #7
    int $e1
    tsta
    bne native_boot_disk_bad
    int $2c
    ; Legacy disk shells probe the removed FDC status address. It is now
    ; ordinary underlying RAM: seed only its presence byte so they retain
    ; mounted A/B headers. INT17 remains a compatibility no-op, not an FDC.
    ldaa #$80
    staa $e6d0
    jsr native_boot_sector
    ; INT01 is the original registered ROM boot entry (Uniload/UniShell).
    ; Discover it without keeping an outer SWI active around the shell.
    ldaa #1
    int $2e
    cpx #0
    beq native_boot_kernel_bad
    cpx #reset
    beq native_boot_kernel_bad
    ldaa rompage
    psha
    ldaa $e6f1
    psha
    tstb
    beq native_boot_call
    clr $e6f1
    stab rompage
native_boot_call
    jsr 0,x
    pula
    staa $e6f1
    pula
    staa rompage
    rts
native_boot_disk_bad
    ldx #native_disk_error
    bra native_boot_error
native_boot_kernel_bad
    ldx #native_kernel_error
native_boot_error
    int $23
    ; The native reserved INT30 safely returns when no monitor is installed.
    int $30
native_boot_halt
    bra native_boot_halt
native_disk_error db 13,10,'BOOT: SDPARTS error',13,10,0
native_kernel_error db 13,10,'BOOT: no system',13,10,0
