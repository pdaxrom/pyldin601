; NC supervisor. Ordinary parent PGM, no TSR hooks or MARK_RESIDENT.
; The child PGM has returned and its heap has been released before EXEC/SHELL.
    include NCABI.INC
start
    ldx #bss_start
clear_state
    clr 0,x
    inx
    cpx #bss_end
    bne clear_state
    int $13
    staa state+S_MODE
    stab state+S_ATTR
    stx state+S_BASE
    int $6d
    cmpa #40
    bcc supported
    ldx #msg_mode
    int $23
    int $38
supported
    ldx #$4e43
    stx state+S_MAGIC
    int $45
    staa drive
    adda #'A'
    staa state+S_PATHS
    staa state+S_PATHS+PATH_SIZE
    ldaa #':'
    staa state+S_PATHS+1
    staa state+S_PATHS+PATH_SIZE+1
    ldaa drive
    ldx #state+S_PATHS+2
    int $47
    tsta
    beq nc_continue_1
    jmp fatal
nc_continue_1
    ; Current directory includes its leading slash. Add a trailing slash.
    ldx #state+S_PATHS+2
path_end
    tst 0,x
    beq path_tail
    inx
    bra path_end
path_tail
    dex
    ldaa 0,x
    cmpa #'\'
    beq path_copy
    inx
    ldaa #'\'
    staa 0,x
    inx
    clr 0,x
path_copy
    ldx #state+S_PATHS
    stx src
    ldx #state+S_PATHS+PATH_SIZE
    stx dst
    jsr copy
    clra
    ldx #argument
    int $3c
    ldx #argument
    stx table
    ldx #mainline
    stx table+2
    ldx #table
    int $3f
    tsta
    beq nc_long_nc_1_217
    jmp fatal
nc_long_nc_1_217
    ldx #mainline
    stx dst
find_tail
    ldaa 0,x
    beq replace_tail
    inx
    inc scan_index
    cmpa #'\'
    bne find_tail
    stx dst
    ldaa scan_index
    staa name_offset
    bra find_tail
replace_tail
    ldx dst
    ldaa name_offset
    cmpa #65
    bls name_fits
    ldaa #19
    jmp fatal
name_fits
    ldx #main_name
    stx src
    jsr copy
    ; Append the address of the stable parent-owned state as four hex digits.
    ldx dst
    ldaa #' '
    staa 0,x
    inx
    stx dst
    ldx #state
    stx address
    ldaa address
    jsr hex
    ldaa address+1
    jsr hex
    ldx dst
    clr 0,x
reload
    jsr restore_video
    clr state+S_REQUEST
    ldx #mainline
    int $39
    tsta
    beq nc_long_nc_2_217
    jmp fatal
nc_long_nc_2_217
    ldaa state+S_REQUEST
    beq finished
    cmpa #2
    beq shell
    cmpa #3
    beq reload
    cmpa #4
    beq editor
    ldx #state+S_COMMAND
    int $39
    bra result
shell
    int $3a
    bra result
editor
    jsr restore_video
    jsr module_tail
    ldaa #'E'
    staa 2,x
    ldaa #'D'
    staa 3,x
    ldaa #'I'
    staa 4,x
    ldaa #'T'
    staa 5,x
    ldx #mainline
    int $39
    psha
    jsr module_tail
    ldaa #'M'
    staa 2,x
    ldaa #'A'
    staa 3,x
    ldaa #'I'
    staa 4,x
    ldaa #'N'
    staa 5,x
    pula
result
    tsta
    beq reload
    jsr print_error
    ldx #msg_key
    int $23
    int $20
    bra reload
fatal
    jsr print_error
    ldx #msg_key
    int $23
    int $20
finished
    jsr restore_video
    ldaa #12
    int $22
exit_to_dos
    int $38
module_tail
    ldx #mainline
    ldab name_offset
module_tail_loop
    tstb
    beq module_tail_done
    inx
    decb
    bra module_tail_loop
module_tail_done
    rts
restore_video
    int $13
    cmpa state+S_MODE
    bne reset_video
    cpx state+S_BASE
    bne reset_video
    ldab state+S_ATTR
    int $16
    rts
reset_video
    ldaa state+S_MODE
    ldab state+S_ATTR
    ldx state+S_BASE
    int $12
    rts
print_error
    ldx #argument
    int $3d
    ldx #msg_error
    int $23
    ldx #argument
    int $23
    rts
copy
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    staa 0,x
    beq copied
    inx
    stx dst
    bra copy
copied
    rts
hex
    psha
    lsra
    lsra
    lsra
    lsra
    jsr nibble
    pula
nibble
    anda #15
    adda #'0'
    cmpa #'9'
    bls digit
    adda #7
digit
    ldx dst
    staa 0,x
    inx
    stx dst
    rts
main_name db 'NCMAIN.PGM',0
msg_error db 10,'NC: ',0
msg_key db 10,'Press a key to return to NC.',0
msg_mode db 10,'NC requires at least 40 columns.',10,0
bss_start
state ds S_SIZE
argument ds 81
mainline ds 81
table ds 4
src ds 2
dst ds 2
address ds 2
drive ds 1
scan_index ds 1
name_offset ds 1
bss_end
    end start
