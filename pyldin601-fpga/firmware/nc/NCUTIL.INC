add_b
    tstb
    beq add_done
    ; MC6800 has no ABX. Add in constant time, preserving A as before.
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
add_done
    rts
end_z
    tst 0,x
    beq end_done
    inx
    bra end_z
end_done
    rts
copy_z
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    staa 0,x
    beq copy_z_done
    inx
    stx dst
    bra copy_z
copy_z_done
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
