; INT E0: common FPGA BIOS services. A selects the function. Results in A:
; 0 success, 1 bad arguments, 2 hardware error/timeout, 3 HD6303 required.
; Function 0: A=API version (1), B=feature bits (indexed/HAM8/blitter/AY).
; 1 mode B=0/native,1/indexed,7/HAM8 (caller supplies HAM component tables).
; 2 present B=frame page (0..15), waits until vblank flip completes.
; 3 blit X=11-byte RAM descriptor: cmd,key,srcpage,dstpage,srcBE,dstBE,wBE,h.
; 4 clipped keyed sprite X=12-byte RAM descriptor:
;   xBE(signed),yBE(signed),srcBE,wBE,h,srcpage,dstpage,key. HD6303 only.
; 5 music frame X=14 AY register bytes. R13=FF means keep current envelope.
; 6 silence AY channels (beeper stays under the original BIOS control).
; All descriptors must be in RAM accessible with ROM page B selected.
SERVICE_PTR equ $ed7b
GFX_CTRL equ $e650
GFX_CMD equ $e651
AY_BASE equ $e610
services
    stx SERVICE_PTR
    tsta
    beq service_info
    cmpa #1
    beq service_mode
    cmpa #2
    beq service_present
    cmpa #3
    beq service_blit
    cmpa #4
    bne service_more
    jmp service_sprite
service_more
    cmpa #5
    bne service_not_frame
    jmp service_frame
service_not_frame
    cmpa #6
    bne service_bad
    jmp service_silence
service_info
    ldaa #1
    staa SWIA
    ldab #15
    stab SWIB
    rts
service_bad
    ldaa #1
    jmp service_result
service_mode
    cmpb #0
    beq service_mode_valid
    cmpb #1
    beq service_mode_valid
    cmpb #7
    bne service_bad
service_mode_valid
    pshb
    jsr graphics_wait
    pulb
    tsta
    bne service_result
    stab GFX_CTRL
    bra service_ok
service_present
    cmpb #15
    bhi service_bad
    pshb
    jsr graphics_wait
    pulb
    tsta
    bne service_result
    stab $e655
    ldaa #3
    staa GFX_CMD
    jmp service_wait_done
service_blit
    jsr graphics_wait
    tsta
    bne service_result
    ldx SERVICE_PTR
    ldaa 0,x
    cmpa #1
    beq service_blit_valid
    cmpa #2
    beq service_blit_valid
    cmpa #6
    bne service_bad
service_blit_valid
    ldaa 1,x
    staa $e653
    ldaa 2,x
    cmpa #15
    bhi service_bad
    staa $e654
    ldaa 3,x
    cmpa #15
    bhi service_bad
    staa $e655
    ldaa 4,x
    staa $e657
    ldaa 5,x
    staa $e656
    ldaa 6,x
    staa $e659
    ldaa 7,x
    staa $e658
    ldaa 8,x
    staa $e65b
    ldaa 9,x
    staa $e65a
    ldaa 10,x
    staa $e65c
    ldaa 0,x
    staa GFX_CMD
service_wait_done
    jsr graphics_wait
    bra service_result
service_ok
    clra
service_result
    staa SWIA
    rts
; 65536 bounded polls. X is scratch, restored from SERVICE_PTR where needed.
graphics_wait
    ldx #0
graphics_poll
    ldaa GFX_CTRL
    bpl graphics_complete
    dex
    bne graphics_poll
    ldaa #2
    rts
graphics_complete
    bita #$30
    beq graphics_ok
    ldaa #2
    rts
graphics_ok
    clra
    rts
service_sprite
    ldaa $e6a0
    bita #2
    bne service_sprite_cpu
    ldaa #3
    jmp service_result
service_sprite_cpu
    jsr graphics_wait
    tsta
    beq service_sprite_ready
    jmp service_result
service_sprite_ready
    ldx SERVICE_PTR
    ldd 0,x
    std clip_x
    ldd 2,x
    std clip_y
    ldd 4,x
    std clip_src
    ldd 6,x
    std clip_width
    ldaa 8,x
    staa clip_height
    ldaa 9,x
    cmpa #15
    bhi service_sprite_bad
    staa $e654
    ldaa 10,x
    cmpa #15
    bhi service_sprite_bad
    staa $e655
    ldaa 11,x
    staa $e653
    jsr gfx_clip
    bcc service_sprite_visible
    ; Empty off-screen rectangles are a successful no-op.
    jmp service_ok
service_sprite_bad
    jmp service_bad
service_sprite_visible
    ldd clip_source
    staa $e657
    stab $e656
    ldd clip_destination
    staa $e659
    stab $e658
    ldd clip_draw_width
    staa $e65b
    stab $e65a
    ldaa clip_draw_height
    staa $e65c
    ldaa #6
    staa GFX_CMD
    jmp service_wait_done
service_frame
    ldx SERVICE_PTR
    clrb
service_frame_next
    ldaa 0,x
    pshb
    psha
    stx SERVICE_PTR
    ; R13=FF suppresses unwanted envelope retriggers in music streams.
    cmpb #13
    bne service_frame_write
    cmpa #$ff
    beq service_frame_skip
service_frame_write
    ldx #AY_BASE
service_frame_offset
    tstb
    beq service_frame_store
    inx
    decb
    bra service_frame_offset
service_frame_store
    staa 0,x
service_frame_skip
    pula
    pulb
    ldx SERVICE_PTR
    inx
    incb
    cmpb #14
    bne service_frame_next
    jmp service_ok
service_silence
    ldaa #$3f
    staa AY_BASE+7
    clr AY_BASE+8
    clr AY_BASE+9
    clr AY_BASE+10
    jmp service_ok
