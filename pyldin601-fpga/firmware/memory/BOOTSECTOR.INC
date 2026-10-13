; Original native boot order: read selected A: sector zero into 0100,
; execute 0150 only after its A55A signature. INT40 uses the mounted SD drive.
; 0300..0304 is boot-only scratch outside the 0100..02FF sector buffer.
    global native_boot_sector
native_boot_sector
    ldx #$0100
    stx $0300
    clr $0302
    ldx #0
    stx $0303
    ldx #$0300
    ldaa #1
    int $40
    tsta
    bne native_sector_return
    ldx $02fe
    cpx #$a55a
    bne native_sector_return
    jsr $0150
native_sector_return
    rts
