; Paint native entry, resource lifetime and event dispatch. MC6800 ISA.
    .ifdef PNT_EDIT
    .define PNT_OVL
    .endif
    .ifdef PNT_FILES
    .define PNT_OVL
    .endif
    include PNTDEF.INC
    include DMA.INC
    public bss_start
    public paint_ready
    public paint_restored
    public paint_idle
    public paint_pointer
    public mouse_event
    public mouse_refocus
    public redraw
    public frame_save
    public frame_load
    public paint_new
    public paint_module
    extern bss_end
    extern p_file_buffer
    extern p_model
    extern p_original_mode
    extern p_original_attr
    extern p_original_base
    extern p_original_page
    extern p_old_group
    extern p_original_gfx
    extern p_old_front
    extern p_old_cursor
    extern p_frame
    extern p_frame_top
    extern p_frame_owned
    extern p_frame_bytes
    extern p_old_saved
    extern p_break_vector
    extern p_break_page
    extern p_io_vector
    extern p_io_page
    extern p_vectors
    extern p_native_mode
    extern p_native_pal
    extern p_preview_ext
    extern p_kind
    extern p_app_path
    extern p_module_path
    extern p_module_tail
    extern p_filename
    extern p_doc_page
    extern p_undo_page
    extern p_front_page
    extern p_undo_front
    extern p_have_undo
    extern p_have_redo
    extern p_serial
    extern p_modified
    extern p_fg
    extern p_bg
    extern p_fg_rgb
    extern p_bg_rgb
    extern p_brush
    extern p_error
    extern p_ui_active
    extern p_ui_menu
    extern p_ignore
    extern p_queue
    extern p_queue_head
    extern p_queue_count
    extern p_queue_over
    extern p_event_x
    extern p_event_y
    extern p_event_buttons
    extern p_exit_question
    extern p_need_hardware
    extern p_memory_error
    extern p_need_loader
    extern paint_dma
    extern dma_reset
    extern dma_run
    extern dma_wait
    extern canvas_config
    extern canvas_module
    extern canvas_blank
    extern canvas_front
    extern canvas_undo
    extern backend_load
    extern backend_base
    extern module_select
    extern backend_close
    extern paint_alloc
    extern palette_save
    extern palette_restore
    extern palette_default
    extern palette_index
    extern palette_ham
    extern draw_event
    extern draw_finish
    extern mouse_init
    extern mouse_poll
    extern mouse_close
    extern mouse_wait
    extern mouse_x
    extern mouse_x_low
    extern mouse_y
    extern mouse_y_low
    extern mouse_buttons
    extern mouse_pressed
    extern mouse_show
    extern mouse_height
    extern mouse_context
    extern mouse_row
    extern mouse_column
    extern window_left
    extern window_inner
    extern columns
    extern error_text
    extern text_stride
    extern src
    extern dst
    extern copy_z
    extern add_b
    extern ui_help
    extern ui_menu
    extern ui_new
    extern ui_tool
    extern ui_colour
    extern ui_error
    extern ui_confirm
    extern file_load
    extern file_save
    .ifdef PNT_OVL
    extern v_file_buffer_1
    extern p_over_call
    extern p_over_arg
    extern pcx_bits
    extern iff_form_end
    extern draw_error
    extern part_y
    extern view_refresh
    extern view_event
    extern view_key
    extern view_reset
    extern view_touch
    extern view_action
    extern p_view_shift
    .endif
    section
bss_start
main_live ds 1
main_kind ds 1
main_old_kind ds 1
main_key_buttons ds 1
main_cursor ds 2
main_temp ds 2
main_event ds 2
main_count ds 1
main_tail ds 1
frame_page ds 1
main_result ds 1
    ends
start
    bra overlay_entry
    db 'PNT1'
overlay_entry
    .ifdef PNT_OVL
    cmpa #1
    bcc *+5
    jmp bad_loader
    cmpa #$c0
    bcs *+5
    jmp bad_loader
    staa main_temp
    stab main_temp+1
    ldx main_temp
    ldaa 6,x
    cmpa #'O'
    beq *+5
    jmp bad_loader
    ldaa 7,x
    cmpa #'V'
    beq *+5
    jmp bad_loader
    ldaa 8,x
    cmpa #'L'
    beq *+5
    jmp bad_loader
    ldaa 9,x
    cmpa #'1'
    beq *+5
    jmp bad_loader
    ldaa 4,x
    beq overlay_initial
    cmpa #1
    bne overlay_files
    ldaa 5,x
    bne overlay_edit
    ldab p_over_arg
    cmpb #2
    beq overlay_edit
    jsr view_reset
overlay_edit
    tst main_live
    bne overlay_action
    tsta
    beq *+5
    jsr ui_error
    jmp paint_ready
overlay_action
    jmp main_action
overlay_files
    ldaa 5,x
    bne overlay_save
    ldaa p_over_arg
    jsr file_load
    bra overlay_done
overlay_save
    jsr file_save
overlay_done
    tab
    clra
    ldx p_over_call
    jmp 0,x
overlay_initial
    ldaa main_temp
    ldab main_temp+1
    .endif
initialize
    cmpa #1
    bcs bad_loader
    cmpa #$c0
    bcs loader_parameters
bad_loader
    ldx #p_need_loader
    int $23
    int $38
loader_parameters
    psha
    pshb
    ldx #bss_start
main_zero
    clr 0,x
    inx
    cpx #bss_end
    bne main_zero
    ldx #p_file_buffer
    pulb
    stab 1,x
    pula
    staa 0,x
    .ifdef PNT_OVL
    ldx p_file_buffer
    ldaa 0,x
    ldab 1,x
    staa p_file_buffer
    stab v_file_buffer_1
    ldx 2,x
    stx p_over_call
    .endif
    ldaa #0
    ldx #p_app_path
    int $3c
    ldx #p_app_path
    stx main_temp
    ldx #p_module_path
    stx main_event
    ldx #main_temp
    int $3f
    tsta
    beq main_path_begin
    int $38
main_path_begin
    ldx #p_module_path
    stx p_module_tail
main_path_scan
    ldaa 0,x
    beq main_path_ready
    inx
    cmpa #':'
    beq main_path_separator
    cmpa #'\'
    beq main_path_separator
    cmpa #'/'
    bne main_path_scan
main_path_separator
    stx p_module_tail
    bra main_path_scan
main_path_ready
    ldaa $e650
    anda #15
    staa p_original_gfx
    ldaa $e652
    staa p_old_front
    ldaa $e6f0
    staa p_original_page
    ldaa $e6f1
    staa p_old_group
    ldaa $ed1d
    ldx #p_old_cursor
    staa 0,x
    ldaa $ed1e
    staa 1,x
    ldaa #14
    staa $e600
    ldaa $e601
    staa main_cursor
    ldaa #15
    staa $e600
    ldaa $e601
    staa main_cursor+1
    int $13
    staa p_original_mode
    stab p_original_attr
    stx p_original_base
    ldaa $e65f
    cmpa #255
    bne *+5
    jmp hardware_missing
    cmpa #6
    bcc *+5
    jmp hardware_missing
    ldaa DMA_COMMAND
    cmpa #'D'
    beq *+5
    jmp hardware_missing
    ldaa DMA_STATUS
    anda #15
    cmpa #1
    beq *+5
    jmp hardware_missing
    ldaa #4
    int $2e
    stx p_break_vector
    stab p_break_page
    ldaa #7
    int $2e
    stx p_io_vector
    stab p_io_page
    ldaa #4
    clrb
    ldx #ignore_break
    int $2f
    ldaa #7
    clrb
    ldx #fail_io
    int $2f
    inc p_vectors
    jsr mouse_init
    ldaa #200
    staa mouse_height
    ldaa #$80
    staa mouse_show
    ; Also load the arrow for keyboard painting when no device answered F4.
    ldaa #64
    staa $e6be
    ldx #paint_arrow
    ldab #64
main_arrow
    ldaa 0,x
    staa $e6bf
    inx
    decb
    bne main_arrow
    jsr paint_pointer
    ldx #8000
    ldaa #40
    tst $fff7
    bpl main_model
    inc p_model
    ldx #16000
    ldaa #80
main_model
    stx p_frame_bytes
    staa columns
    staa text_stride
    ldaa p_original_mode
    anda #3
    beq main_frame_allocate
    ldx p_original_base
    stx p_frame
    ldaa #P_MEM_ORIGINAL
    jsr frame_save
    tsta
    beq *+5
    jmp main_init_error
    inc p_old_saved
    bra main_frame_ready
main_frame_allocate
    ldx #0
    clrb
    int $2a
    stx p_frame_top
    ldx p_frame_bytes
    ; Native CRTC graphics addresses count eight-byte character cells.
    ; Code/data may be unaligned, but the bitmap origin must not be.
    ldab #3
    jsr paint_alloc
    cpx #0
    bne *+5
    jmp memory_missing
    stx p_frame
    inc p_frame_owned
main_frame_ready
    jsr palette_save
    tsta
    beq *+5
    jmp main_init_error
    ldaa #P_MEM_DOC
    staa p_doc_page
    ldaa #P_MEM_UNDO
    staa p_undo_page
    ldaa #1
    staa p_undo_front
    staa p_brush
    ldaa #3
    jsr paint_new
    tsta
    beq *+5
    jmp main_init_error
    ldaa #1
    ldx #p_filename
    int $3c
    tst p_filename
    beq paint_ready
    ldaa #1
    jsr file_load
    tsta
    beq paint_ready
    jsr ui_error
paint_ready
    inc main_live
    ldaa #1
    staa p_ignore
main_loop
    ldx backend_base
    cpx #0
    bne main_backend_ready
    jmp cleanup
main_backend_ready
    tst p_queue_over
    beq main_queue
    clr p_queue_over
    jsr draw_finish
main_queue
    tst p_queue_count
    beq main_wait
    ldaa p_queue_head
    asla
    asla
    tab
    ldx #p_queue
    jsr add_b
    ldaa 0,x
    ldab 1,x
    stx main_event
    ldx #p_event_x
    staa 0,x
    stab 1,x
    ldx main_event
    ldaa 2,x
    staa p_event_y
    ldaa 3,x
    staa p_event_buttons
    inc p_queue_head
    ldaa p_queue_head
    anda #15
    staa p_queue_head
    dec p_queue_count
    jsr paint_draw
    tsta
    bne *+5
    jmp main_loop
    jsr ui_error
    bra main_loop
main_wait
    .ifdef PNT_OVL
    jsr view_refresh
    tsta
    beq *+5
    jsr ui_error
    .endif
    ldaa #0
    jsr mouse_wait
main_dispatch
    cmpa #$fe
    bne *+5
    jmp main_loop
    cmpa #$c9
    bne main_not_help
    jsr ui_help
    bra main_loop
main_not_help
    cmpa #$ca
    beq main_save
    cmpa #$cb
    beq main_open
    cmpa #$cc
    bne *+5
    jmp main_colour
    cmpa #$cd
    beq main_tool
    cmpa #$ce
    beq main_new
    cmpa #$cf
    beq main_undo
    cmpa #26
    beq main_undo
    cmpa #$d0
    beq main_redo
    cmpa #25
    beq main_redo
    cmpa #$d1
    beq main_menu
    cmpa #$c0
    beq main_menu
    cmpa #$d2
    bne *+5
    jmp main_exit
    cmpa #27
    bne *+5
    jmp main_exit
    cmpa #'+'
    beq main_brush_larger
    cmpa #'-'
    beq main_brush_smaller
    jmp main_keyboard
main_save
    jsr file_save
    bra main_action
main_open
    clra
    jsr file_load
    bra main_action
main_colour
    jsr ui_colour
    bra main_action
main_tool
    jsr ui_tool
    bra main_action
main_new
    jsr ui_new
    cmpa #$ff
    bne *+5
    jmp main_loop
    jsr paint_new
    bra main_action
main_undo
    clr main_key_buttons
    jsr draw_finish
    clra
    jsr canvas_undo
    bra main_action
main_redo
    clr main_key_buttons
    jsr draw_finish
    ldaa #1
    jsr canvas_undo
main_action
    tsta
    bne main_action_bad
    .ifdef PNT_OVL
    jsr view_action
    .endif
    clr p_error
    jmp main_loop
main_action_bad
    jsr ui_error
    jmp main_loop
main_menu
    jsr ui_menu
    cmpa #$ff
    bne *+5
    jmp main_loop
    jmp main_dispatch
main_brush_larger
    ldaa p_brush
    cmpa #16
    bcs *+5
    jmp main_loop
    inc p_brush
    jmp main_loop
main_brush_smaller
    ldaa p_brush
    cmpa #2
    bcc *+5
    jmp main_loop
    dec p_brush
    jmp main_loop
main_exit
    tst p_modified
    bne *+5
    jmp cleanup
    ldx #p_exit_question
    jsr ui_confirm
    cmpa #'Y'
    beq *+5
    jmp main_loop
    jmp cleanup
main_init_error
    staa p_error
    jmp cleanup
hardware_missing
    ldx #p_need_hardware
    int $23
    int $38
memory_missing
    ldaa #66
    staa p_error
    jmp cleanup
; A=kind. Do not overwrite document/Undo until the new module is available.
paint_new
    staa main_kind
    ldaa p_kind
    staa main_old_kind
    ldaa main_kind
    jsr canvas_config
    tsta
    bne new_return
    jsr paint_module
    tsta
    beq new_available
    staa main_result
    ldaa main_old_kind
    jsr canvas_config
    jsr paint_module
    ldaa main_result
new_return
    rts
new_available
    .ifdef PNT_OVL
    jsr view_reset
    .endif
    clr $e650
    jsr palette_default
    ldaa p_kind
    cmpa #4
    beq new_ham
    jsr palette_index
    bra new_palette_ready
new_ham
    jsr palette_ham
new_palette_ready
    tsta
    bne new_return
    ldaa p_native_mode
    oraa #$80
    ldab p_native_pal
    ldx p_frame
    int $12
    jsr canvas_blank
    tsta
    bne new_return
    jsr canvas_front
    tsta
    bne new_return
    ldx #p_serial
    ldab #16
new_serial
    clr 0,x
    inx
    decb
    bne new_serial
    clr p_modified
    clr p_have_undo
    clr p_have_redo
    clr p_filename
    clr p_bg
    ldaa #255
    ldab p_kind
    cmpb #3
    bcc new_foreground
    ldaa #3
    cmpb #2
    beq new_foreground
    ldaa #1
new_foreground
    staa p_fg
    ldx #p_fg_rgb
    ldaa #63
    staa 0,x
    staa 1,x
    staa 2,x
    ldx #p_bg_rgb
    clr 0,x
    clr 1,x
    clr 2,x
    ldaa #1
    staa p_ignore
    clr p_queue_count
    clr p_queue_head
    clra
    rts
paint_module
    jsr canvas_module
    stx src
    ldx p_module_tail
    stx dst
    jsr copy_z
    ldx #p_module_path
    jmp module_select
; A=graphics SRAM top byte, copy the native frame to/from that page.
frame_save
    staa frame_page
    jsr frame_descriptor
    ldaa frame_page
    staa DMA_DST+2,x
    ldx #p_frame
    ldaa 1,x
    ldab 0,x
    ldx #paint_dma
    staa DMA_SRC,x
    stab DMA_SRC+1,x
    ldaa #DMA_COPY
    jmp dma_run
frame_load
    staa frame_page
    jsr frame_descriptor
    ldaa frame_page
    staa DMA_SRC+2,x
    ldx #p_frame
    ldaa 1,x
    ldab 0,x
    ldx #paint_dma
    staa DMA_DST,x
    stab DMA_DST+1,x
    ldaa #DMA_COPY
    jmp dma_run
frame_descriptor
    jsr dma_reset
    ldx #p_frame_bytes
    ldaa 1,x
    ldab 0,x
    ldx #paint_dma
    staa DMA_WIDTH,x
    stab DMA_WIDTH+1,x
    rts
cleanup
    jsr draw_finish
    ; Never release an ordinary DMA source while the hardware still owns it.
cleanup_dma
    ldaa DMA_STATUS
    bpl cleanup_idle
    jsr paint_idle
    bra cleanup_dma
cleanup_idle
    jsr mouse_close
    clr $e650
    jsr palette_restore
    tst p_old_saved
    beq cleanup_video
    ldaa #P_MEM_ORIGINAL
    jsr frame_load
cleanup_video
    ldaa p_original_mode
    oraa #$80
    ldab p_original_attr
    ldx p_original_base
    int $12
    ldaa p_old_front
    staa $e655
    ldaa #3
    staa $e651
cleanup_flip
    ldaa $e650
    bmi cleanup_flip
    ldaa p_original_gfx
    staa $e650
    ldx #p_old_cursor
    ldaa 0,x
    staa $ed1d
    ldab 1,x
    stab $ed1e
    ldaa #10
    staa $e600
    ldaa $ed1d
    staa $e601
    ldaa #11
    staa $e600
    ldaa $ed1e
    staa $e601
    ldaa #14
    staa $e600
    ldaa main_cursor
    staa $e601
    ldaa #15
    staa $e600
    ldaa main_cursor+1
    staa $e601
paint_restored
    jsr backend_close
    tst p_frame_owned
    beq cleanup_vectors
    ldx p_frame_top
    int $2b
cleanup_vectors
    tst p_vectors
    beq cleanup_selectors
    ldaa #4
    ldab p_break_page
    ldx p_break_vector
    int $2f
    ldaa #7
    ldab p_io_page
    ldx p_io_vector
    int $2f
cleanup_selectors
    ldaa p_old_group
    staa $e6f1
    ldaa p_original_page
    staa $e6f0
    ldaa p_error
    beq cleanup_return
    cmpa #66
    bne cleanup_native_error
    ldx #p_memory_error
    bra cleanup_print
cleanup_native_error
    ldx #error_text
    int $3d
    ldx #error_text
cleanup_print
    int $23
cleanup_return
    int $38
ignore_break
    rts
fail_io
    ldaa #3
    staa $06
    rts
; Poll only; never re-enter a DMA job, a backend, or a modal from here.
paint_idle
    jsr mouse_poll
    tsta
    beq idle_return
    jmp queue_mouse
idle_return
    rts
queue_mouse
    tst p_ui_active
    bne idle_return
    tst p_ignore
    beq queue_enabled
    tst mouse_buttons
    bne idle_return
    clr p_ignore
    rts
queue_enabled
    ldaa p_queue_head
    adda p_queue_count
    anda #15
    staa main_tail
    ldaa p_queue_count
    cmpa #16
    bcs queue_new
    dec main_tail
    ldaa main_tail
    anda #15
    asla
    asla
    tab
    ldx #p_queue
    jsr add_b
    ldaa 3,x
    cmpa mouse_buttons
    beq queue_write
    inc p_queue_over
    clr p_queue_count
    clr p_queue_head
    inc p_ignore
    rts
queue_new
    ldaa main_tail
    asla
    asla
    tab
    ldx #p_queue
    jsr add_b
    inc p_queue_count
queue_write
    ldaa mouse_x
    staa 0,x
    ldaa mouse_x_low
    staa 1,x
    ldaa mouse_y_low
    staa 2,x
    ldaa mouse_buttons
    staa 3,x
    rts
mouse_event
    tst mouse_context
    bne event_modal
    jsr queue_mouse
    ldaa #$fe
    rts
event_modal
    ldaa mouse_context
    cmpa #10
    beq event_wake
    ldaa mouse_pressed
    bita #2
    bne event_escape
    bita #1
    beq event_ignore
    ldaa mouse_column
    cmpa window_left
    bcs event_ignore
    suba window_left
    cmpa window_inner
    bhi event_ignore
    ldaa mouse_row
    suba #8
    .ifdef PNT_OVL
    cmpa p_ui_menu
    .else
    cmpa #5
    .endif
    bcc event_ignore
    adda #'1'
    rts
event_wake
    ldaa #$fe
    rts
event_escape
    ldaa #27
    rts
event_ignore
    ldaa #$ff
mouse_refocus
redraw
    rts
paint_pointer
    ldaa mouse_show
    staa $e6be
    ldaa mouse_x_low
    staa $e6bf
    ldaa mouse_x
    staa $e6bf
    ldaa mouse_y_low
    staa $e6bf
    ldaa mouse_y
    staa $e6bf
    rts
main_keyboard
    .ifdef PNT_OVL
    jsr view_key
    bcc key_normal
    jmp main_action
key_normal
    .endif
    cmpa #' '
    bne key_left
    ldaa main_key_buttons
    eora #1
    staa main_key_buttons
    bra key_draw
key_left
    cmpa #$c1
    bne key_right
    ldx mouse_x
    cpx #0
    beq key_draw
    dex
    stx mouse_x
    bra key_draw
key_right
    cmpa #$c2
    bne key_up
    ldx mouse_x
    cpx #639
    beq key_draw
    inx
    stx mouse_x
    bra key_draw
key_up
    cmpa #$c4
    bne key_down
    tst mouse_y_low
    beq key_draw
    dec mouse_y_low
    bra key_draw
key_down
    cmpa #$c3
    bne key_other
    ldaa mouse_y_low
    cmpa #199
    bcc key_draw
    inc mouse_y_low
key_draw
    jsr paint_pointer
    ldx mouse_x
    stx p_event_x
    ldaa mouse_y_low
    staa p_event_y
    ldaa main_key_buttons
    staa p_event_buttons
    jsr paint_draw
    jmp main_action
key_other
    jmp main_loop
paint_draw
    .ifdef PNT_OVL
    jsr view_event
    tsta
    beq paint_draw_normal
    clra
    rts
paint_draw_normal
    .endif
    jsr draw_event
    rts
paint_arrow
    db $40,0,0,0,$50,0,0,0,$64,0,0,0,$69,0,0,0
    db $6a,$40,0,0,$6a,$90,0,0,$6a,$a4,0,0,$6a,$a9,0,0
    db $6a,$aa,$40,0,$6a,$aa,$90,0,$6a,$95,$50,0,$69,$64,0,0
    db $64,$69,0,0,$50,$1a,$40,0,$40,$06,$90,0,0,$01,$50,0
    .ifdef PNT_OVL
    ; Force identical BSS modules/order even when their code is absent.
    dw pcx_bits,iff_form_end,draw_error,part_y,p_view_shift
    .endif
    end start
