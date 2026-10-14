; One leased 8K bank contains two directly accessed 4K catalogue windows.
; Every DOS interrupt and font/IRQ mapping restores the NC bank selectors.
cache_open
    ldaa #ENTRY_COUNT
    staa entry_capacity
    ldaa #$e5
    int $2e
    cpx #0
    beq cache_unavailable
    ldaa #1
    ldab #1
    ldx #cache_lease
    int $e5
    tsta
    bne cache_unavailable
    inc cache_lease_open
    ldaa #BANK_COUNT
    staa entry_capacity
    ldaa $e6f1
    staa cache_old_group
    ldaa $e6f0
    staa cache_old_page
    clr cache_group
    ldaa cache_lease+3
cache_divide
    cmpa #6
    bcs cache_remainder
    suba #6
    inc cache_group
    bra cache_divide
cache_remainder
    inca
cache_map
    staa $e6f0
    ldaa cache_group
    staa $e6f1
cache_unavailable
    rts
cache_close
    tst cache_lease_open
    beq cache_close_done
    ldaa cache_old_group
    staa $e6f1
    ldaa cache_old_page
    staa $e6f0
    ldaa #2
    ldx #cache_lease
    int $e5
    clr cache_lease_open
cache_close_done
    rts
