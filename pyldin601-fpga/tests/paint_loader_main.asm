    include PNTABI.INC
    public probe_started
    public probe_loaded
    public probe_encoded
    public probe_closed
    public probe_error
    public params
    public pixels
    public output
    public bss_start
    extern bss_end
    extern backend_load
    extern backend_close
    extern backend_encode
    extern backend_kind
    extern backend_params
    section
bss_start
probe_error ds 1
path ds 81
kind_text ds 81
params ds PB_SIZE
pixels ds 960
output ds 640
    ends
start
    bra initialize
    db 'PLT1'
initialize
    ldx #bss_start
zero
    clr 0,x
    inx
    cpx #bss_end
    bne zero
    ldaa #1
    ldx #path
    int $3c
    ldaa #2
    ldx #kind_text
    int $3c
    ldaa kind_text
    suba #'0'
    staa backend_kind
probe_started
    ldx #path
    jsr backend_load
    staa probe_error
    beq probe_loaded
    jmp probe_cleanup
probe_loaded
    ldx #pixels
    clra
fill
    staa 0,x
    inx
    adda #17
    cpx #pixels+960
    bne fill
    ldx #PNT_MAGIC
    stx params+PB_MAGIC
    ldaa #PNT_ABI
    staa params+PB_ABI
    ldaa backend_kind
    staa params+PB_KIND
    ldx #320
    cmpa #PNT_MONO640
    bne width_ready
    ldx #640
width_ready
    stx params+PB_WIDTH
    ldx #pixels
    stx params+PB_SOURCE
    ldx #output
    stx params+PB_DEST
    ldx #params
    stx backend_params
    jsr backend_encode
    staa probe_error
probe_encoded
    nop
probe_cleanup
    jsr backend_close
probe_closed
    int $38
    end start
