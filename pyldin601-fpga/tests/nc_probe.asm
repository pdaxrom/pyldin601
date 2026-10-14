; This child needs more memory than is available with NCMAIN still loaded.
start
    ldx #0
    clrb
    int $2a
    stx old_top
    int $13
    anda #3
    beq text_size
    ldx #8000
    bra allocate
text_size
    ldx #18000
allocate
    clrb
    int $2a
    cpx #0
    beq failed
    ldaa #$a5
fill
    staa 0,x
    inx
    cpx old_top
    bne fill
allocated
    ldx old_top
    int $2b
    ldaa #0
    clrb
    ldx #0
    int $12
success
    int $38
failed
    ldx #message
    int $23
    int $38
message db 'NCPROBE: NCMAIN was not released!',0
bss_start
old_top ds 2
bss_end
    end start
