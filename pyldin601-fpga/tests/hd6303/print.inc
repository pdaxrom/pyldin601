; A byte / X word to uppercase hexadecimal via UniDOS print-character.
print_word
        stx print_value
        ldaa print_value
        jsr print_byte
        ldaa print_value+1
        jmp print_byte
print_byte
        psha
        lsra
        lsra
        lsra
        lsra
        jsr print_nibble
        pula
        anda #$0f
print_nibble
        cmpa #10
        bcs print_digit
        adda #7
print_digit
        adda #$30
        int $22
        rts
print_value dw 0
