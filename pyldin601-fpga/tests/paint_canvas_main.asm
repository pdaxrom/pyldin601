    public bss_start
    public probe_ready
    public probe_exit
    public paint_idle
    public copy_n
    public add_b
    extern tools_run
    extern file_header
    public file_row
    public file_config
    public file_store
    public file_fetch
    public file_buffer
    extern bss_end
    extern src
    extern dst
    extern canvas_config
    extern canvas_undo
    extern canvas_show
    extern backend_load
    extern paint_alloc
    extern p_frame
    extern p_frame_bytes
    extern p_frame_top
    extern palette_default
    extern palette_index
    extern palette_ham
    extern palette_save
    extern palette_restore
    extern draw_event
    extern draw_finish
    extern io_begin
    extern io_get
    extern io_read
    extern io_write
    extern io_close
    extern io_seek
    extern pcx_read
    extern pcx_write
    extern iff_read
    extern iff_write
    extern canvas_store
    extern canvas_read
    extern p_doc_page
    section
bss_start
copy_count ds 1
add_pointer ds 2
file_row ds 1
file_buffer ds 512
    ends
start
    bra initialize
    db 'PCT1'
initialize
    ldx #bss_start
zero
    clr 0,x
    inx
    cpx #bss_end
    bne zero
    ldx #0
    clrb
    int $2a
    stx p_frame_top
    ldx #8000
    tst $fff7
    bpl frame_size
    ldx #16000
frame_size
    stx p_frame_bytes
    ldab #3
    jsr paint_alloc
    stx p_frame
probe_ready
    bra probe_ready
probe_exit
    ldx p_frame_top
    int $2b
    int $38
paint_idle
    rts
    dw canvas_config,canvas_undo,canvas_show,backend_load
    dw palette_default,palette_index,palette_ham,palette_save,palette_restore
    dw draw_event,draw_finish
    dw tools_run
    dw io_begin,io_get,io_read,io_write,io_close,io_seek
    dw pcx_read,pcx_write
    dw iff_read,iff_write
file_config
    jsr canvas_config
    tsta
    bne file_config_done
    ldaa #$19
    staa p_doc_page
    clra
file_config_done
    rts
file_store
    jmp canvas_store
file_fetch
    jmp canvas_read
; Keyboard/mouse cancellation is exercised by the complete UI runner.
    public mouse_cancel
mouse_cancel
    ldaa #$ff
    rts
copy_n
    stab copy_count
copy_loop
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    staa 0,x
    inx
    stx dst
    dec copy_count
    bne copy_loop
    rts
add_b
    tstb
    beq add_done
    psha
    stx add_pointer
    ldaa add_pointer+1
    aba
    staa add_pointer+1
    bcc add_ready
    inc add_pointer
add_ready
    ldx add_pointer
    pula
    clrb
add_done
    rts
    end start
