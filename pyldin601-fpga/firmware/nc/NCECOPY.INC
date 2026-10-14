; Copy at most 512 ordinary/banked bytes, with a fast eight-byte body.
copy_bytes
    ldaa split_bytes+1
    anda #7
    staa copy_tail
    ldaa split_bytes
    ldab split_bytes+1
    lsra
    rorb
    lsra
    rorb
    lsra
    rorb
    tba
    jsr copy_octets
    ldab copy_tail
    tstb
    beq copy_bytes_done
    jmp copy_n
copy_bytes_done
    rts
