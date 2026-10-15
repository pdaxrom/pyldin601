; SDK tile/window/one-tile scrolling diagnostic, real relocatable PGM.
    include GAMEBIOS.INC
start
    ldab #GB_VIDEO
    jsr sdk_open
    tsta
    beq begin_test
    jmp failed
begin_test
    ldaa #GB_MODE
    ldab #1
    int GB_INT
    ldaa #GB_TARGET
    ldab #2
    int GB_INT
    clr tile_id
atlas
    clra
    ldab tile_id
    andb #7
    asld
    asld
    asld
    std rectangle
    clra
    ldab tile_id
    lsrb
    lsrb
    lsrb
    asld
    asld
    asld
    std rectangle+2
    ldaa tile_id
    staa rectangle+7
    ldaa #GB_RECT
    ldx #rectangle
    int GB_INT
    tsta
    beq *+5
    jmp failed
    inc tile_id
    ldaa tile_id
    cmpa #64
    bne atlas
    ldaa #GB_TARGET
    clrb
    int GB_INT
    ldaa #GB_CLEAR
    int GB_INT
    ldx #map
    jsr sdk_map
    tsta
    beq *+5
    jmp failed
    clr phase
    jsr show
next_scroll
    ldx #directions
    ldab phase
    abx
    ldab 0,x
    ldx #map
    jsr sdk_scroll
    tsta
    beq *+5
    jmp failed
    inc phase
    jsr show
    ldaa phase
    cmpa #7
    bne next_scroll
    ; Unsupported direction and invalid map are rejected.
    ldx #map
    ldab #4
    jsr sdk_scroll
    cmpa #GB_ARGUMENT
    bne failed
    ldaa #9
    staa map+4
    ldx #map
    jsr sdk_map
    cmpa #GB_ARGUMENT
    bne failed
    jsr sdk_close
    ldx #passed_text
    int $23
    clra
    int $38
show
    ldaa #GB_FLIP
    clrb
    int GB_INT
    tsta
    bne failed
    rts
failed
    jsr sdk_close
    ldx #failed_text
    int $23
    ldaa #1
    int $38
    include GAMESDK.ASM
rectangle dw 0,0,8
    db 8,0
map dw world
    db 8,8,2,3,4,3,5,6,2,0
world
    include SDKWORLD.INC
directions db 1,0,3,2,0,0,0
passed_text db 'PASS: SDK tiles and scrolling',13,10,0
failed_text db 'FAIL: SDK tiles and scrolling',13,10,0
    section
bss_start
tile_id ds 1
phase ds 1
    include GAMESDTA.INC
bss_end
    ends
    end start
