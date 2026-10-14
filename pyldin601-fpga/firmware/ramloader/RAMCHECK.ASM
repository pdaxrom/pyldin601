; Execute the actual disk-loaded CRC16 ROM through its normal SWI vector.
start
    ldaa #$ed
    int $2e
    cpx #0
    bne probe
    ldx #missing
    int $23
    int $38
probe
    clra
    int $ed
    cmpa #1
    bne failed
    cpx #8
    bne failed
    ldaa #1
    ldx #request
    int $ed
    tsta
    bne failed
    ldx request+6
    cpx #$29b1
    bne failed
    ldx #passed
    int $23
    int $38
failed
    ldx #error
    int $23
    int $38
request dw text,9,$ffff,0
text db '123456789'
missing db 'Load CRC16.ROM with RAMLOAD first.',13,10,0
passed db 'PASS: banked ROM CRC16 = 29B1',13,10,0
error db 'FAIL: banked ROM CRC16',13,10,0
bss_start
bss_end
    end
