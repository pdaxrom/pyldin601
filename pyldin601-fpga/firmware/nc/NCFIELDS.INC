line_text
    ldaa columns
    staa remaining
field
    jsr text_field
padding
    ldaa #' '
    staa fill_char
fill_field
    tst remaining
    beq field_done
    ldaa fill_char
    jsr put_field
    bra fill_field
field_done
    rts
text_field
    stx textptr
text_loop
    tst remaining
    beq text_done
    ldx textptr
    ldaa 0,x
    beq text_done
    inx
    stx textptr
    jsr put_field
    bra text_loop
text_done
    rts
put_field
    tst remaining
    beq field_done
    dec remaining
    jmp put
