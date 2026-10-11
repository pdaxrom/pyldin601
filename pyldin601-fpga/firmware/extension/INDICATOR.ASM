; Native status line: classic 601 has two 42-byte rows; 601A has two
; 80-byte rows in both 40-column colour and 80-column monochrome text.
; Use the current BIOS screen pointer, including after scrolling.
; A is the character (zero clears it), B is preserved; X is scratch.
indicator
    ldx SYS_LINE
    psha
    ldaa $e6a0
    bita #1
    beq indicator_601
    pula
    staa 159,x
    rts
indicator_601
    pula
    staa 81,x
    rts
