; Native HD6303 music demo using the banked FPGA BIOS INT E0 API.
; Standard relocatable UniDOS PGM, built with UniAS.
start
        ldaa $e6a0
        bita #2
        bne cpu_ok
        ldx #need_cpu
        jmp message_exit
cpu_ok
        ldaa $edf0
        anda #$f0
        cmpa #$b0
        beq extension_ok
        ldx #need_rom
        jmp message_exit
extension_ok
        clra
        int $e0
        cmpa #1
        bne wrong_version
        bitb #8
        bne api_ok
wrong_version
        ldx #need_rom
        jmp message_exit
api_ok
        ldx #playing
        int $23
        ldx #melody
        stx note_pointer
        jsr next_note
        int $1c
        stx previous_time
        clr duration
wait_key
        int $10
        cmpa #$ff
        beq check_time
        int $11
        cmpa #27
        beq finished
check_time
        int $1c
        cpx previous_time
        beq wait_key
        stx previous_time
        inc duration
        ldaa duration
        cmpa #25
        bcs wait_key
        clr duration
        jsr next_note
        bra wait_key
finished
        ldaa #6
        int $e0
        ldx #done
message_exit
        int $23
        int $38
next_note
        ldx note_pointer
        ldd 0,x
        bne note_ready
        ldx #melody
        ldd 0,x
note_ready
        inx
        inx
        stx note_pointer
        ; AY periods are little endian. A melody, B octave, C bass.
        stab frame
        staa frame+1
        lsrd
        stab frame+2
        staa frame+3
        asld
        asld
        stab frame+4
        staa frame+5
        ldx #frame
        ldaa #5
        int $e0
        rts
frame db 0,0,0,0,0,0,7,$38,12,8,6,0,0,$ff
melody dw 478,426,379,358,319,284,253,239,253,284,319,358,379,426,478,0
note_pointer dw 0
previous_time dw 0
duration db 0
playing db 'AY: three-channel melody; ESC returns to UniDOS.',13,10,0
done db 'AY: stopped.',13,10,0
need_cpu db 'AY: enable HD6303 in BIOS.',13,10,0
need_rom db 'AY: update FPGA BIOS extension on SD.',13,10,0
        end start
