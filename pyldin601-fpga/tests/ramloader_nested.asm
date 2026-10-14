; Invoke ramloader as a child of a real PGM, before/after its registry exists.
start
    ldx #line
    int $39
    int $38
line db 'B:RAMLOAD B:CRC16.ROM',0
    end
