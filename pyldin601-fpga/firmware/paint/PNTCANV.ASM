    extern v_paint_dma_1
    extern v_paint_dma_10
    extern v_paint_dma_2
    extern v_paint_dma_4
    extern v_paint_dma_5
    extern v_paint_dma_7
    extern v_paint_dma_8
    extern v_params_13
    extern v_paint_dma_6
    extern v_paint_dma_11
    extern v_paint_dma_0
    extern v_paint_dma_9
    extern v_paint_dma_14
    extern v_paint_dma_3
    extern v_stride_1
    extern v_serial_3
    extern v_serial_2
    extern v_serial_1
    extern v_saved_ser_3
    extern v_saved_ser_2
    extern v_saved_ser_1
    extern v_params_6
    extern v_params_8
    extern v_params_3
    extern v_params_0
    extern v_params_4
    extern v_params_14
    extern v_params_10
    extern v_params_12
    extern v_params_2
    extern v_frame_byt_1
    extern v_frame_1
    extern v_doc_size_2
    extern v_doc_size_1
    extern v_doc_seria_4
    extern v_doc_seria_3
    extern v_doc_seria_2
    extern v_doc_seria_1
    extern v_copy_src_3
    extern v_copy_src_2
    extern v_copy_src_1
    extern v_copy_dst_2
    extern v_copy_dst_1
    extern v_copy_byte_2
    extern v_copy_byte_1
; Canonical row I/O and preview transport. Document bytes are in GPU SRAM,
; never in an assumed RAMMAN page. All hardware transfers use flat DMA.
    include PNTABI.INC
    include PNTDEF.INC
    include DMA.INC
    public canvas_config
    public canvas_module
    public canvas_linear
    public canvas_read
    public canvas_store
    public canvas_show
    public canvas_blit
    public canvas_getcode
    public canvas_fill
    public canvas_blank
    public canvas_front
    public canvas_snapshot
    public canvas_undo
    public canvas_modified
    public row_document
    public row_address
    extern paint_dma
    extern dma_reset
    extern dma_run
    extern dma_wait
    extern paint_idle
    extern backend_kind
    extern backend_params
    extern backend_encode
    extern p_model
    extern p_kind
    extern p_preview_ext
    extern p_native_mode
    extern p_native_pal
    extern p_width
    extern p_stride
    extern p_doc_size
    extern p_doc_page
    extern p_undo_page
    extern p_front_page
    extern p_undo_front
    extern p_frame
    extern p_frame_bytes
    extern p_copy_src
    extern p_copy_dst
    extern p_copy_bytes
    extern p_render_y
    extern p_row
    extern p_encoded
    extern p_enc_tail
    extern p_params
    extern p_cached_y
    extern p_row_dirty
    extern p_have_undo
    extern p_have_redo
    extern p_serial
    extern p_doc_serial
    extern p_undo_serial
    extern p_saved_serial
    extern p_modified
    extern src
    extern dst
    extern copy_n
    extern pal_snapshot
    extern palette_undo
    section
row_address ds 3
multiply_value ds 3
multiply_factor ds 1
multiply_steps ds 1
row_y ds 1
ordinary_pointer ds 2
undo_direction ds 1
front_timeout ds 2
rect_pointer ds 2
    ends
; A=logical kind; validate before changing any image configuration.
canvas_config
    cmpa #5
    bcs *+5
    jmp canvas_invalid
    cmpa #PNT_MONO640
    bne canvas_supported
    tst p_model
    bne *+5
    jmp canvas_invalid
canvas_supported
    staa p_kind
    staa backend_kind
    ldx #320
    stx p_width
    stx p_stride
    ldaa #3
    staa p_native_mode
    clr p_preview_ext
    ldaa #2
    staa p_native_pal
    ldaa p_kind
    beq configure_mono
    cmpa #PNT_MONO640
    beq configure_wide
    cmpa #PNT_FOUR
    beq configure_four
    ldaa #1
    staa p_preview_ext
    ldaa p_kind
    cmpa #PNT_HAM8
    bne configure_size
    ldaa #7
    staa p_preview_ext
    ldx #960
    stx p_stride
    bra configure_size
configure_mono
    tst p_model
    beq configure_size
    inc p_preview_ext
    bra configure_size
configure_wide
    ldx #640
    stx p_width
    stx p_stride
    bra configure_size
configure_four
    tst p_model
    beq configure_four_extended
    ldaa #2
    staa p_native_mode
    bra configure_size
configure_four_extended
    inc p_preview_ext
configure_size
    clr p_doc_size
    clr v_doc_size_1
    clr v_doc_size_2
    ldab #200
configure_sum
    ldaa p_doc_size
    adda v_stride_1
    staa p_doc_size
    ldaa v_doc_size_1
    adca p_stride
    staa v_doc_size_1
    bcc configure_next
    inc v_doc_size_2
configure_next
    decb
    bne configure_sum
    ldx #PNT_MAGIC
    stx v_params_0
    ldaa #PNT_ABI
    staa v_params_2
    clr v_params_3
    ldaa p_kind
    staa v_params_4
    ldx p_width
    stx v_params_6
    ldx #p_row
    stx v_params_8
    ldx #p_encoded
    stx v_params_10
    ldx #paint_idle
    stx v_params_14
    ldx #p_params
    stx backend_params
    ldaa #$ff
    staa p_cached_y
    clr p_row_dirty
    clra
    rts
canvas_invalid
    ldaa #65
    rts
canvas_module
    ldx #native_name
    tst p_preview_ext
    beq module_ready
    ldx #indexed_name
    ldaa p_kind
    cmpa #PNT_HAM8
    bne module_ready
    ldx #ham_name
module_ready
    rts
; Three adjacent LE24 source/destination/length records.
canvas_linear
    jsr dma_reset
    ldx #p_copy_src
    stx src
    ldx #paint_dma
    stx dst
    ldab #9
    jsr copy_n
    ldaa #DMA_COPY
    jmp dma_run
; A=row, row_address = row * BE16 stride as LE24.
row_multiply
    staa multiply_factor
    clr row_address
    clr row_address+1
    clr row_address+2
    clr multiply_value+2
    ldaa #8
    staa multiply_steps
multiply_bit
    lsr multiply_factor
    bcc multiply_shift
    ldaa row_address
    adda multiply_value
    staa row_address
    ldaa row_address+1
    adca multiply_value+1
    staa row_address+1
    ldaa row_address+2
    adca multiply_value+2
    staa row_address+2
multiply_shift
    asl multiply_value
    rol multiply_value+1
    rol multiply_value+2
    dec multiply_steps
    bne multiply_bit
    rts
row_document
    staa row_y
    ldaa v_stride_1
    staa multiply_value
    ldaa p_stride
    staa multiply_value+1
    ldaa row_y
    jsr row_multiply
    ldaa row_address+2
    adda p_doc_page
    staa row_address+2
    rts
; Prepare doc -> ordinary row. No transfer starts until canvas_linear.
row_job
    staa p_render_y
    jsr row_document
    ldaa row_address
    staa p_copy_src
    ldaa row_address+1
    staa v_copy_src_1
    ldaa row_address+2
    staa v_copy_src_2
    ldx #p_row
    stx ordinary_pointer
    ldaa ordinary_pointer+1
    staa p_copy_dst
    ldaa ordinary_pointer
    staa v_copy_dst_1
    clr v_copy_dst_2
    ldaa v_stride_1
    staa p_copy_bytes
    ldaa p_stride
    staa v_copy_byte_1
    clr v_copy_byte_2
    rts
canvas_read
    jsr row_job
    jmp canvas_linear
canvas_store
    jsr row_job
    ldx #p_copy_src
row_swap
    ldaa 0,x
    ldab 3,x
    staa 3,x
    stab 0,x
    inx
    cpx #v_copy_src_3
    bne row_swap
    jmp canvas_linear
; Existing encoded HAM row into the otherwise unused tail of p_encoded.
canvas_getcode
    staa p_render_y
    jsr dma_reset
    ldaa #64
    staa multiply_value
    ldaa #1
    staa multiply_value+1
    ldaa p_render_y
    jsr row_multiply
    ldaa row_address
    staa v_paint_dma_0
    ldaa row_address+1
    staa v_paint_dma_1
    ldaa p_front_page
    adda #$10
    staa v_paint_dma_2
    ldx #p_enc_tail
    stx ordinary_pointer
    ldaa ordinary_pointer+1
    staa v_paint_dma_3
    ldaa ordinary_pointer
    staa v_paint_dma_4
    ldaa #64
    staa v_paint_dma_6
    ldaa #1
    staa v_paint_dma_7
    ldaa #DMA_COPY
    jmp dma_run
; X=[xBE16,y8,widthBE16,height8,index8], 320-wide byte-indexed canvas.
; The caller has taken Undo and selected an extended non-HAM preview.
canvas_fill
    stx rect_pointer
    ldaa 2,x
    staa row_y
    jsr dma_reset
    ldaa #64
    staa multiply_value
    ldaa #1
    staa multiply_value+1
    ldaa row_y
    jsr row_multiply
    ldx rect_pointer
    ldaa row_address
    adda 1,x
    staa v_paint_dma_3
    ldaa row_address+1
    adca 0,x
    staa v_paint_dma_4
    ldaa p_doc_page
    staa v_paint_dma_5
    ldaa 4,x
    staa v_paint_dma_6
    ldaa 3,x
    staa v_paint_dma_7
    ldaa 5,x
    staa v_paint_dma_9
    ldaa 6,x
    ldx #paint_dma
    staa DMA_VALUE,x
    ldaa #64
    staa DMA_DST_STRIDE,x
    ldaa #1
    staa DMA_DST_STRIDE+1,x
    ldaa #DMA_FILL
    jsr dma_run
    tsta
    bne rect_return
    ldaa p_front_page
    adda #$10
    staa v_paint_dma_5
    ldaa #DMA_FILL
    jsr dma_run
rect_return
    rts
canvas_show
    staa p_render_y
    jsr backend_encode
    tsta
    beq show_prepare
    rts
canvas_blit
    staa p_render_y
show_prepare
    jsr dma_reset
    ldx #p_encoded
    stx ordinary_pointer
    ldaa ordinary_pointer+1
    staa v_paint_dma_0
    ldaa ordinary_pointer
    staa v_paint_dma_1
    tst p_preview_ext
    beq show_native
    ldaa #64
    staa multiply_value
    ldaa #1
    staa multiply_value+1
    ldaa p_render_y
    jsr row_multiply
    ldaa row_address
    staa v_paint_dma_3
    ldaa row_address+1
    staa v_paint_dma_4
    ldaa p_front_page
    adda #$10
    staa v_paint_dma_5
    ldaa v_params_13
    staa v_paint_dma_6
    ldaa v_params_12
    staa v_paint_dma_7
    bra show_launch
show_native
    ldaa #64
    staa multiply_value
    ldaa #1
    tst p_model
    beq native_pitch
    ldaa #128
    staa multiply_value
    ldaa #2
native_pitch
    staa multiply_value+1
    ldaa p_render_y
    lsra
    lsra
    lsra
    jsr row_multiply
    ldaa p_render_y
    anda #7
    adda row_address
    staa row_address
    ldaa row_address+1
    adca #0
    staa row_address+1
    ldaa row_address
    adda v_frame_1
    staa v_paint_dma_3
    ldaa row_address+1
    adca p_frame
    staa v_paint_dma_4
    ldaa #1
    staa v_paint_dma_6
    staa v_paint_dma_11
    ldaa #8
    staa v_paint_dma_14
    ldaa v_params_13
    staa v_paint_dma_9
    ldaa v_params_12
    staa v_paint_dma_10
show_launch
    ldaa #DMA_COPY
    jmp dma_run
; Empty black/zero-index image, including a zero HAM command stream.
canvas_blank
    jsr dma_reset
    ldaa p_doc_page
    staa v_paint_dma_5
    jsr document_size
    ldaa #DMA_FILL
    jsr dma_run
    tsta
    bne blank_return
    jsr dma_reset
    tst p_preview_ext
    beq blank_native
    ldaa p_front_page
    adda #$10
    staa v_paint_dma_5
    ldaa #$00
    staa v_paint_dma_6
    ldaa #$fa
    staa v_paint_dma_7
    bra blank_launch
blank_native
    ldaa v_frame_1
    staa v_paint_dma_3
    ldaa p_frame
    staa v_paint_dma_4
    ldaa v_frame_byt_1
    staa v_paint_dma_6
    ldaa p_frame_bytes
    staa v_paint_dma_7
blank_launch
    ldaa #DMA_FILL
    jsr dma_run
blank_return
    rts
document_size
    ldaa p_doc_size
    staa v_paint_dma_6
    ldaa v_doc_size_1
    staa v_paint_dma_7
    ldaa v_doc_size_2
    staa v_paint_dma_8
    rts
; Request the selected extended page at VBL; native mode needs no flip.
canvas_front
    tst p_preview_ext
    beq front_native
    ldaa p_front_page
    staa $e655
    ldaa #3
    staa $e651
    ldx #$ffff
    stx front_timeout
front_wait
    ldaa $e650
    bpl front_ready
    jsr paint_idle
    ldx front_timeout
    dex
    stx front_timeout
    bne front_wait
    ldaa #3
    rts
front_ready
    bita #$30
    bne front_bad
    ldaa p_preview_ext
    staa $e650
    clra
    rts
front_native
    clr $e650
    clra
    rts
front_bad
    ldaa #2
    rts
; Save one whole stroke. Canonical and visible snapshots are independent,
; allowing fast Undo without re-encoding an entire HAM image on the CPU.
canvas_snapshot
    jsr pal_snapshot
    tsta
    beq checkpoint_begin
    rts
checkpoint_begin
    jsr dma_reset
    ldaa p_doc_page
    staa v_paint_dma_2
    ldaa p_undo_page
    staa v_paint_dma_5
    jsr document_size
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    bne checkpoint_return
    jsr dma_reset
    tst p_preview_ext
    beq checkpoint_native
    ldaa p_front_page
    adda #$10
    staa v_paint_dma_2
    ldaa #$fa
    staa v_paint_dma_7
    bra checkpoint_target
checkpoint_native
    ldaa v_frame_1
    staa v_paint_dma_0
    ldaa p_frame
    staa v_paint_dma_1
    ldaa v_frame_byt_1
    staa v_paint_dma_6
    ldaa p_frame_bytes
    staa v_paint_dma_7
checkpoint_target
    ldaa p_undo_front
    adda #$10
    staa v_paint_dma_5
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    bne checkpoint_return
    ldx #p_doc_serial
    stx src
    ldx #p_undo_serial
    stx dst
    ldab #4
    jsr copy_n
    inc v_serial_3
    bne checkpoint_serial
    inc v_serial_2
    bne checkpoint_serial
    inc v_serial_1
    bne checkpoint_serial
    inc p_serial
checkpoint_serial
    ldx #p_serial
    stx src
    ldx #p_doc_serial
    stx dst
    ldab #4
    jsr copy_n
    ldaa #1
    staa p_have_undo
    clr p_have_redo
    jsr canvas_modified
    clra
checkpoint_return
    rts
canvas_modified
    ldaa p_doc_serial
    cmpa p_saved_serial
    bne image_modified
    ldaa v_doc_seria_1
    cmpa v_saved_ser_1
    bne image_modified
    ldaa v_doc_seria_2
    cmpa v_saved_ser_2
    bne image_modified
    ldaa v_doc_seria_3
    cmpa v_saved_ser_3
    bne image_modified
    clr p_modified
    rts
image_modified
    ldaa #1
    staa p_modified
    rts
; A=0 Undo,1 Redo. Only within the current image format/session.
canvas_undo
    staa undo_direction
    tsta
    bne check_redo
    tst p_have_undo
    bne undo_available
    clra
    rts
check_redo
    tst p_have_redo
    bne undo_available
    clra
    rts
undo_available
    jsr palette_undo
    tsta
    beq undo_palette_ready
    rts
undo_palette_ready
    tst p_preview_ext
    bne undo_extended
    ; Native preview exchange: live frame -> scratch, old -> live, scratch -> old.
    jsr frame_to_scratch
    tsta
    bne undo_return
    jsr dma_reset
    ldaa p_undo_front
    adda #$10
    staa v_paint_dma_2
    jsr frame_destination
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    bne undo_return
    jsr dma_reset
    ldaa #P_PICKER_PAGE
    staa v_paint_dma_2
    ldaa p_undo_front
    adda #$10
    staa v_paint_dma_5
    jsr frame_length
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    bne undo_return
    bra undo_metadata
undo_extended
    ldaa p_front_page
    ldab p_undo_front
    staa p_undo_front
    stab p_front_page
    jsr canvas_front
    tsta
    bne undo_return
undo_metadata
    ldaa p_doc_page
    ldab p_undo_page
    staa p_undo_page
    stab p_doc_page
    ldx #p_doc_serial
undo_serial
    ldaa 0,x
    ldab 4,x
    staa 4,x
    stab 0,x
    inx
    cpx #v_doc_seria_4
    bne undo_serial
    ldaa undo_direction
    staa p_have_undo
    eora #1
    staa p_have_redo
    jsr canvas_modified
    ldaa #$ff
    staa p_cached_y
    clr p_row_dirty
    clra
undo_return
    rts
frame_to_scratch
    jsr dma_reset
    ldaa v_frame_1
    staa v_paint_dma_0
    ldaa p_frame
    staa v_paint_dma_1
    ldaa #P_PICKER_PAGE
    staa v_paint_dma_5
    jsr frame_length
    ldaa #DMA_COPY
    jmp dma_run
frame_destination
    ldaa v_frame_1
    staa v_paint_dma_3
    ldaa p_frame
    staa v_paint_dma_4
frame_length
    ldaa v_frame_byt_1
    staa v_paint_dma_6
    ldaa p_frame_bytes
    staa v_paint_dma_7
    rts
native_name db 'PNTNAT.PGM',0
indexed_name db 'PNTRGB.PGM',0
ham_name db 'PNTHAM.PGM',0
    end
