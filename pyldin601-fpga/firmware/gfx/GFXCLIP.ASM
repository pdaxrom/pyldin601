; HD6303 software rectangle clipping for the 320x200 byte framebuffer.
; Inputs: clip_x/clip_y signed 16-bit destination, clip_src unsigned offset,
; clip_width unsigned 16-bit (1..320), clip_height byte (1..200).
; Source stride is 320. The complete source rectangle must fit in 64000 bytes.
; Outputs: clip_source, clip_destination, clip_draw_width/clip_draw_height.
; C=1: empty or invalid; C=0: visible. Clobbers D/CCR, preserves X.
; No MMIO, no pixel copies: pass outputs to FILL/COPY/TRANSPARENT COPY.
gfx_clip
        bra clip_begin
clip_empty
        clr clip_draw_width
        clr clip_draw_width+1
        clr clip_draw_height
        sec
        rts
clip_begin
        ldd clip_width
        beq clip_empty
        subd #321
        bcc clip_empty
        ldaa clip_height
        beq clip_empty
        cmpa #201
        bcc clip_empty
        ; Reject overflow and any source byte outside the physical frame.
        ldab clip_height
        decb
        ldaa #64
        mul
        std clip_temp
        asld
        asld
        addd clip_temp
        addd clip_width
        bcs clip_empty
        addd clip_src
        bcs clip_empty
        subd #64001
        bcc clip_empty
        ldd clip_width
        std clip_draw_width
        ldaa clip_height
        staa clip_draw_height
        clr clip_skip_x
        clr clip_skip_x+1
        clr clip_skip_y
        clr clip_skip_y+1
        ldd clip_x
        bmi clip_left
        std clip_tx
        ldd #320
        subd clip_x
        bls clip_empty
        subd clip_width
        bcc clip_x_done
        ldd #320
        subd clip_x
        std clip_draw_width
        bra clip_x_done
clip_left
        clr clip_tx
        clr clip_tx+1
        ldd #0
        subd clip_x
        std clip_skip_x
        ldd clip_width
        subd clip_skip_x
        bhi clip_left_visible
        jmp clip_empty
clip_left_visible
        std clip_draw_width
clip_x_done
        ldd clip_y
        bmi clip_top
        std clip_ty
        ldd #200
        subd clip_y
        bhi clip_y_visible
        jmp clip_empty
clip_y_visible
        clra
        ldab clip_height
        std clip_temp
        ldd #200
        subd clip_y
        subd clip_temp
        bcc clip_y_done
        ldd #200
        subd clip_y
        stab clip_draw_height
        bra clip_y_done
clip_top
        clr clip_ty
        clr clip_ty+1
        ldd #0
        subd clip_y
        std clip_skip_y
        clra
        ldab clip_height
        subd clip_skip_y
        bhi clip_top_visible
        jmp clip_empty
clip_top_visible
        stab clip_draw_height
clip_y_done
        ldab clip_skip_y+1
        ldaa #64
        mul
        std clip_temp
        asld
        asld
        addd clip_temp
        addd clip_skip_x
        addd clip_src
        std clip_source
        ldab clip_ty+1
        ldaa #64
        mul
        std clip_temp
        asld
        asld
        addd clip_temp
        addd clip_tx
        std clip_destination
        clc
        rts
        .ifdef GFXCLIP_ROM
        section $ed61
        .endif
clip_x dw 0
clip_y dw 0
clip_src dw 0
clip_width dw 0
clip_height db 0
clip_source dw 0
clip_destination dw 0
clip_draw_width dw 0
clip_draw_height db 0
clip_skip_x dw 0
clip_skip_y dw 0
clip_tx dw 0
clip_ty dw 0
clip_temp dw 0

        .ifdef GFXCLIP_ROM
        ends
        .endif
