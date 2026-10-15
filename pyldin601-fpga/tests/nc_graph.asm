; Parent owns native graphics memory across NC and every external child.
start
    int $60
    cpx #0
    beq failed
    .ifdef COLOUR
    ldaa #2
    .else
    ldaa #3
    .endif
    clrb
    int $12
    ldx #command
    int $39
    int $61
    int $38
failed
    ldx #message
    int $23
    int $38
command db 'B:NC.PGM',0
message db 'NC graphics fixture: allocation failed.',0
    section
bss_start
bss_end
    ends
    end start
