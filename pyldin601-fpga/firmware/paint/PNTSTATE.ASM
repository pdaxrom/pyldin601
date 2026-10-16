; Paint owns ordinary control state; image and Undo bytes live in GPU SRAM.
    include PNTABI.INC
    include PNTDEF.INC
    public p_model
    public p_original_mode
    public p_original_attr
    public p_original_base
    public p_original_page
    public p_old_group
    public p_original_gfx
    public p_old_front
    public p_original_read
    public p_old_cursor
    public p_break_vector
    public p_break_page
    public p_io_vector
    public p_io_page
    public p_vectors
    public p_frame
    public p_frame_owned
    public p_frame_top
    public p_frame_bytes
    public p_native_mode
    public p_native_pal
    public p_kind
    public p_preview_ext
    public p_width
    public p_stride
    public p_doc_size
    public p_doc_page
    public p_front_page
    public p_undo_front
    public p_busy
    public p_stroke_saved
    public p_copy_src
    public p_copy_dst
    public p_copy_bytes
    public p_undo_page
    public p_have_undo
    public p_have_redo
    public p_modified
    public p_serial
    public p_doc_serial
    public p_undo_serial
    public p_saved_serial
    public p_fg
    public p_bg
    public p_fg_rgb
    public p_bg_rgb
    public p_colour
    public p_colour_rgb
    public p_brush
    public p_tool
    public p_stroke
    public p_anchor
    public p_prev_buttons
    public p_x0
    public p_y0
    public p_x1
    public p_y1
    public p_cached_y
    public p_row_dirty
    public p_render_y
    public p_row
    public p_encoded
    public p_params
    public p_palette
    public p_palette_saved
    public p_old_saved
    public p_ui_active
    public p_ui_underlay
    public p_ui_gfx
    public p_ui_result
    public p_ui_menu
    public p_error
    public p_cancel
    public p_queue
    public p_queue_head
    public p_queue_count
    public p_queue_over
    public p_event_x
    public p_event_y
    public p_event_buttons
    public p_ignore
    public p_app_path
    public p_module_path
    public p_module_tail
    public p_filename
    public p_file_buffer
    public backend_buffer
    public pal_wave
    public input
    public error_text
    public spans
    public file_header
    public file_input
    public file_target
    public file_temp
    public file_backup
    section
p_model ds 1
p_original_mode ds 1
p_original_attr ds 1
p_original_base ds 2
p_original_page ds 1
p_old_group ds 1
p_original_gfx ds 1
p_old_front ds 1
p_original_read ds 1
p_old_cursor ds 2
p_break_vector ds 2
p_break_page ds 1
p_io_vector ds 2
p_io_page ds 1
p_vectors ds 1
p_frame ds 2
p_frame_owned ds 1
p_frame_top ds 2
p_frame_bytes ds 2
p_native_mode ds 1
p_native_pal ds 1
p_kind ds 1
p_preview_ext ds 1
p_width ds 2
p_stride ds 2
p_doc_size ds 3
p_doc_page ds 1
p_front_page ds 1
p_undo_front ds 1
p_busy ds 1
p_stroke_saved ds 1
p_copy_src ds 3
p_copy_dst ds 3
p_copy_bytes ds 3
p_undo_page ds 1
p_have_undo ds 1
p_have_redo ds 1
p_modified ds 1
p_serial ds 4
p_doc_serial ds 4
p_undo_serial ds 4
p_saved_serial ds 4
p_fg ds 1
p_bg ds 1
p_fg_rgb ds 3
p_bg_rgb ds 3
p_colour ds 1
p_colour_rgb ds 3
p_brush ds 1
p_tool ds 1
p_stroke ds 1
p_anchor ds 1
p_prev_buttons ds 1
p_x0 ds 2
p_y0 ds 1
p_x1 ds 2
p_y1 ds 1
p_cached_y ds 1
p_row_dirty ds 1
p_render_y ds 1
p_row ds 960
p_encoded ds 640
p_params ds PB_SIZE
p_palette ds P_PALETTE_BYTES
p_palette_saved ds 1
p_old_saved ds 1
p_ui_active ds 1
p_ui_underlay ds 1
p_ui_gfx ds 1
p_ui_result ds 1
p_ui_menu ds 1
p_error ds 1
p_cancel ds 1
p_queue ds P_NUM_EVENTS*4
p_queue_head ds 1
p_queue_count ds 1
p_queue_over ds 1
p_event_x ds 2
p_event_y ds 1
p_event_buttons ds 1
p_ignore ds 1
p_module_path ds 146
p_module_tail ds 2
p_filename ds 81
p_file_buffer ds 2
; Drawing spans and file names/header have disjoint lifetimes: every modal
; file operation first finishes the stroke, and each stroke resets all spans.
p_work ds 800
    ends
; Module loading never retains a canonical row. Its bounce buffer may use
; p_row, including during Open before any rows are decoded.
backend_buffer equ p_row
pal_wave equ p_row
; Modal input/errors precede codec headers and never coexist with spans.
input equ p_work
error_text equ p_work
spans equ p_work
file_header equ p_work
file_input equ p_work+128
p_app_path equ p_work+128
file_target equ p_work+209
file_temp equ p_work+355
file_backup equ p_work+501
    public v_copy_byte_1
v_copy_byte_1 equ p_copy_bytes+1
    public v_copy_byte_2
v_copy_byte_2 equ p_copy_bytes+2
    public v_copy_dst_1
v_copy_dst_1 equ p_copy_dst+1
    public v_copy_dst_2
v_copy_dst_2 equ p_copy_dst+2
    public v_copy_src_1
v_copy_src_1 equ p_copy_src+1
    public v_copy_src_2
v_copy_src_2 equ p_copy_src+2
    public v_copy_src_3
v_copy_src_3 equ p_copy_src+3
    public v_doc_seria_1
v_doc_seria_1 equ p_doc_serial+1
    public v_doc_seria_2
v_doc_seria_2 equ p_doc_serial+2
    public v_doc_seria_3
v_doc_seria_3 equ p_doc_serial+3
    public v_doc_seria_4
v_doc_seria_4 equ p_doc_serial+4
    public v_doc_size_1
v_doc_size_1 equ p_doc_size+1
    public v_doc_size_2
v_doc_size_2 equ p_doc_size+2
    public v_frame_1
v_frame_1 equ p_frame+1
    public v_frame_byt_1
v_frame_byt_1 equ p_frame_bytes+1
    public v_params_0
v_params_0 equ p_params+0
    public v_params_10
v_params_10 equ p_params+10
    public v_params_12
v_params_12 equ p_params+12
    public v_params_14
v_params_14 equ p_params+14
    public v_params_2
v_params_2 equ p_params+2
    public v_params_3
v_params_3 equ p_params+3
    public v_params_4
v_params_4 equ p_params+4
    public v_params_6
v_params_6 equ p_params+6
    public v_params_8
v_params_8 equ p_params+8
    public v_saved_ser_1
v_saved_ser_1 equ p_saved_serial+1
    public v_saved_ser_2
v_saved_ser_2 equ p_saved_serial+2
    public v_saved_ser_3
v_saved_ser_3 equ p_saved_serial+3
    public v_serial_1
v_serial_1 equ p_serial+1
    public v_serial_2
v_serial_2 equ p_serial+2
    public v_serial_3
v_serial_3 equ p_serial+3
    public v_stride_1
v_stride_1 equ p_stride+1
    public v_params_13
v_params_13 equ p_params+13
    public p_palette_end
p_palette_end equ p_palette+P_PALETTE_BYTES
    public p_enc_tail
p_enc_tail equ p_encoded+320
    end
