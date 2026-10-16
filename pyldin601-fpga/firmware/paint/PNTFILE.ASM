; Transactional native image files. Decode and encode the complete new image
; in GPU staging pages before committing; Save publishes a closed temp file.
    include PNTABI.INC
    include PNTDEF.INC
    include DMA.INC
    public file_load
    public file_save
    extern file_header
    extern file_input
    extern file_target
    extern file_temp
    extern file_backup
    public file_row
    public file_config
    public file_store
    public file_fetch
    extern pcx_read
    extern pcx_write
    extern iff_read
    extern iff_write
    extern io_handle
    extern io_live
    extern io_error
    extern io_begin
    extern io_read
    extern io_count
    extern io_seek
    extern io_close
    extern io_cancel
    extern p_kind
    extern p_preview_ext
    extern p_native_mode
    extern p_model
    extern p_doc_page
    extern p_doc_size
    extern p_front_page
    extern p_palette
    extern p_filename
    extern p_row
    extern p_encoded
    extern p_params
    extern p_frame
    extern p_ui_underlay
    extern p_cached_y
    extern p_row_dirty
    extern p_have_undo
    extern p_have_redo
    extern p_serial
    extern p_doc_serial
    extern p_saved_serial
    extern p_modified
    extern p_fg
    extern p_save_title
    extern p_open_title
    extern p_new_question
    extern p_replace_ask
    extern paint_module
    extern paint_dma
    extern dma_reset
    extern dma_run
    extern backend_encode
    extern canvas_config
    extern canvas_store
    extern canvas_read
    extern canvas_blit
    extern canvas_modified
    extern palette_index
    extern palette_ham
    extern ui_enter
    extern ui_leave
    extern ui_progress
    extern input
    extern dialog
    extern window_open
    extern window_line
    extern colour
    extern confirm
    extern copy_z
    extern copy_n
    extern src
    extern dst
    extern ok_cancel__0523
    section
file_row ds 1
file_open ds 4
file_find ds 6
file_find_state ds 19
file_dir ds 32
file_rename ds 4
file_title ds 2
file_auto ds 1
file_mode ds 1
file_error ds 1
file_old_kind ds 1
file_old_ext ds 1
file_old_doc ds 1
file_pal_saved ds 1
file_pal_changed ds 1
file_mod_changed ds 1
file_temp_live ds 1
file_renamed ds 1
file_exists ds 1
file_attributes ds 1
file_dot ds 1
file_length ds 1
file_pointer ds 2
file_temp_tail ds 2
file_back_tail ds 2
file_nonce ds 2
file_hex_byte ds 1
file_hex_ptr ds 2
file_enc_offset ds 2
file_enc_bytes ds 2
file_palette_ptr ds 2
file_fg_best ds 1
file_fg_limit ds 1
file_fg_index ds 1
    ends
file_config
    jsr canvas_config
    tsta
    bne file_config_return
    ldaa #P_LOAD_PAGE
    staa p_doc_page
    clra
file_config_return
    rts
file_store
    jsr canvas_store
    tsta
    bne file_config_return
    bra file_meter
file_fetch
    jsr canvas_read
    tsta
    bne file_config_return
file_meter
    ldaa file_row
    ldx #file_target
    jsr ui_progress
    jmp io_cancel
file_load
    staa file_auto
    clr file_mode
    ldx #p_open_title
    stx file_title
    jsr file_enter
    tsta
    beq *+5
    jmp file_return
    tst p_modified
    beq load_name
    ldx #p_new_question
    jsr confirm
    cmpa #'Y'
    beq *+5
    jmp file_cancelled
load_name
    jsr file_prefill
    ldaa file_auto
    cmpa #1
    beq load_argument
    ldx #p_open_title
    jsr dialog
    bcc *+5
    jmp file_cancelled
load_argument
    jsr file_path
    tsta
    beq *+5
    jmp file_done
    ldx #file_target
    stx file_open
    ldx #0
    stx file_open+2
    ldaa #1
    ldx #file_open
    int $4a
    tsta
    beq *+5
    jmp file_done
    stab io_handle
    clra
    jsr io_begin
    tsta
    bne load_close
    ldx #p_open_title
    jsr file_window
    ldaa p_kind
    staa file_old_kind
    ldaa p_preview_ext
    staa file_old_ext
    ldaa p_doc_page
    staa file_old_doc
    jsr file_palette_save
    tsta
    bne load_close
    inc file_pal_saved
    ldx #12
    stx io_count
    ldx #file_header
    jsr io_read
    bcs load_close
    ldx #file_zero
    jsr io_seek
    bcs load_close
    ldx #file_header
    ldaa 0,x
    cmpa #10
    beq load_pcx
    jsr iff_read
    bra load_decoded
load_pcx
    jsr pcx_read
load_decoded
    staa io_error
load_close
    staa file_error
    jsr io_close
    tst file_error
    bne load_failed
    staa file_error
    bne load_failed
    jsr file_preview_kind
    inc file_mod_changed
    jsr paint_module
    tsta
    bne load_failed_a
    jsr file_stage
    tsta
    bne load_failed_a
    inc file_pal_changed
    jsr file_palette
    tsta
    bne load_failed_a
    jsr file_commit
    tsta
    bne load_failed_a
    jsr file_remember
    ldx #p_serial
    ldab #16
load_reset_serial
    clr 0,x
    inx
    decb
    bne load_reset_serial
    clr p_modified
    clr p_have_undo
    clr p_have_redo
    clr p_ui_underlay
    clr file_pal_saved
    clr file_mod_changed
    clr file_pal_changed
    jsr file_foreground
    clra
    jmp file_done
load_failed_a
    staa file_error
load_failed
    tst file_pal_saved
    beq load_failed_return
    ldaa file_old_kind
    jsr canvas_config
    ldaa file_old_ext
    staa p_preview_ext
    ldaa file_old_doc
    staa p_doc_page
    jsr file_palette_back
    tst file_mod_changed
    beq load_restore_palette
    jsr paint_module
load_restore_palette
    tst file_pal_changed
    beq load_failed_return
    jsr file_palette
load_failed_return
    ldaa file_error
    jmp file_done
file_save
    ldaa #1
    staa file_mode
    ldx #p_save_title
    stx file_title
    jsr file_enter
    tsta
    beq *+5
    jmp file_return
    jsr file_prefill
    tst input
    bne save_dialog
    ldx #default_pcx
    ldaa p_kind
    cmpa #4
    bne save_default
    ldx #default_iff
save_default
    stx src
    ldx #input
    stx dst
    jsr copy_z
save_dialog
    ldx #p_save_title
    jsr dialog
    bcc *+5
    jmp file_cancelled
    jsr file_path
    tsta
    beq *+5
    jmp file_done
    ldaa #32
    staa file_attributes
    ldx #file_target
    jsr file_stat
    cmpa #11
    beq save_names
    tsta
    beq *+5
    jmp file_done
    ldx #file_dir
    ldaa 11,x
    bita #17
    beq *+5
    jmp save_denied
    oraa #32
    staa file_attributes
    inc file_exists
    ldx #p_replace_ask
    jsr confirm
    cmpa #'Y'
    beq *+5
    jmp file_cancelled
save_names
    jsr file_unique
    tsta
    beq *+5
    jmp file_done
    ldx #file_temp
    stx file_open
    ldx #0
    stx file_open+2
    clra
    ldx #file_open
    int $4b
    tsta
    beq *+5
    jmp file_done
    stab io_handle
    inc file_temp_live
    ldaa #1
    jsr io_begin
    ldx #p_save_title
    jsr file_window
    ldaa p_kind
    cmpa #4
    beq save_iff
    jsr pcx_write
    bra save_encoded
save_iff
    jsr iff_write
save_encoded
    staa io_error
    jsr io_close
    tsta
    beq *+5
    jmp save_abort
    ldaa #1
    ldab file_attributes
    ldx #file_temp
    int $54
    tsta
    beq *+5
    jmp save_abort
    tst file_exists
    beq save_publish
    ldx #file_target
    stx file_rename
    ldx #file_backup
    stx file_rename+2
    jsr file_rename_do
    tsta
    beq *+5
    jmp save_abort
    inc file_renamed
save_publish
    ldx #file_temp
    stx file_rename
    ldx #file_target
    stx file_rename+2
    jsr file_rename_do
    tsta
    bne save_rollback
    clr file_temp_live
    tst file_renamed
    beq save_committed
    ldx #file_backup
    int $4f
    clr file_renamed
save_committed
    jsr file_remember
    ldx #p_doc_serial
    stx src
    ldx #p_saved_serial
    stx dst
    ldab #4
    jsr copy_n
    jsr canvas_modified
    clra
    jmp file_done
save_denied
    ldaa #14
    jmp file_done
save_rollback
    staa file_error
    tst file_renamed
    beq save_abort_saved
    ldx #file_backup
    stx file_rename
    ldx #file_target
    stx file_rename+2
    jsr file_rename_do
    ; A failed restore leaves the original under its unique backup name.
    clr file_renamed
    bra save_abort_saved
save_abort
    staa file_error
save_abort_saved
    tst file_temp_live
    beq save_abort_return
    ldx #file_temp
    int $4f
    clr file_temp_live
save_abort_return
    ldaa file_error
    jmp file_done
file_enter
    clr file_error
    clr file_pal_saved
    clr file_pal_changed
    clr file_mod_changed
    clr file_exists
    clr file_renamed
    clr file_temp_live
    clr io_live
    clr io_error
    jmp ui_enter
file_prefill
    ldx #p_filename
    stx src
    ldx #input
    stx dst
    jmp copy_z
file_remember
    ldx #file_input
    stx src
    ldx #p_filename
    stx dst
    jmp copy_z
file_cancelled
    clra
file_done
    cmpa #255
    bne file_result
    clra
file_result
    staa file_error
    ldaa #$ff
    staa p_cached_y
    clr p_row_dirty
    jsr ui_leave
    tsta
    beq *+5
    jmp file_return
    ldaa file_error
file_return
    rts
; Resolve a bounded input path, adding the current format's default suffix.
file_path
    ldx #input
    clr file_dot
    clr file_length
path_scan
    ldaa 0,x
    beq path_end
    cmpa #'*'
    beq path_invalid
    cmpa #'?'
    beq path_invalid
    cmpa #'\'
    beq path_component
    cmpa #':'
    bne path_dot
path_component
    clr file_dot
path_dot
    cmpa #'.'
    bne path_next
    inc file_dot
path_next
    inx
    inc file_length
    ldaa file_length
    cmpa #80
    bcs path_scan
    bra path_invalid
path_end
    tst file_length
    beq path_invalid
    tst file_dot
    bne path_full
    ldaa file_length
    cmpa #76
    bcc path_invalid
    ldaa #'.'
    staa 0,x
    ldaa p_kind
    cmpa #4
    beq path_iff
    ldaa #'P'
    staa 1,x
    ldaa #'C'
    staa 2,x
    ldaa #'X'
    bra path_suffix
path_iff
    ldaa #'I'
    staa 1,x
    ldaa #'F'
    staa 2,x
path_suffix
    staa 3,x
    clr 4,x
path_full
    ldx #input
    stx src
    ldx #file_input
    stx dst
    jsr copy_z
    ldx #input
    stx file_open
    ldx #file_target
    stx file_open+2
    ldx #file_open
    int $3f
    rts
path_invalid
    ldaa #19
    rts
file_stat
    stx file_find+4
    ldx #file_find_state
    stx file_find
    ldx #file_dir
    stx file_find+2
    clra
    clrb
    ldx #file_find
    int $42
    rts
file_rename_do
    ; UniDOS temporarily inserts NUL in the destination directory. Both
    ; names must be disposable; publication/rollback still need their paths.
    ldx file_rename
    stx src
    ldx #p_row
    stx dst
    jsr copy_z
    ldx file_rename+2
    stx src
    ldx #p_encoded
    stx dst
    jsr copy_z
    ldx #p_row
    stx file_rename
    ldx #p_encoded
    stx file_rename+2
    ldx #file_rename
    int $56
    rts
; Both private names must be absent. Neither existing user file is truncated.
file_unique
    ldx #file_target
    stx src
    ldx #file_temp
    stx dst
    jsr copy_z
    ldx #file_target
    stx src
    ldx #file_backup
    stx dst
    jsr copy_z
    ldx #file_temp
    jsr file_tail
    stx file_temp_tail
    ldx #file_temp
    stx file_hex_ptr
    ldaa file_temp_tail+1
    suba file_hex_ptr+1
    staa file_length
    ldaa file_temp_tail
    sbca file_hex_ptr
    beq *+5
    jmp path_invalid
    ldaa file_length
    cmpa #135
    bcs *+5
    jmp path_invalid
    ldx #file_backup
    jsr file_tail
    stx file_back_tail
unique_next
    ldx file_temp_tail
    jsr unique_base
    ldaa #'.'
    staa 0,x
    ldaa #'T'
    staa 1,x
    ldaa #'M'
    staa 2,x
    ldaa #'P'
    staa 3,x
    clr 4,x
    ldx file_back_tail
    jsr unique_base
    ldaa #'.'
    staa 0,x
    ldaa #'B'
    staa 1,x
    ldaa #'A'
    staa 2,x
    ldaa #'K'
    staa 3,x
    clr 4,x
    ldx #file_temp
    jsr file_stat
    cmpa #11
    bne unique_conflict
    ldx #file_backup
    jsr file_stat
    cmpa #11
    beq unique_ok
unique_conflict
    tsta
    bne unique_error
    inc file_nonce+1
    bne unique_next
    inc file_nonce
    bne unique_next
    ldaa #29
unique_error
    rts
unique_ok
    clra
    rts
file_tail
    stx file_pointer
tail_scan
    ldaa 0,x
    beq tail_ready
    inx
    cmpa #'\'
    beq tail_separator
    cmpa #':'
    bne tail_scan
tail_separator
    stx file_pointer
    bra tail_scan
tail_ready
    ldx file_pointer
    rts
unique_base
    ldaa #'P'
    staa 0,x
    ldaa #'N'
    staa 1,x
    ldaa #'T'
    staa 2,x
    inx
    inx
    inx
    ldaa file_nonce
    jsr unique_hex
    ldaa file_nonce+1
unique_hex
    staa file_hex_byte
    lsra
    lsra
    lsra
    lsra
    jsr unique_digit
    staa 0,x
    inx
    ldaa file_hex_byte
    anda #15
    jsr unique_digit
    staa 0,x
    inx
    rts
unique_digit
    adda #'0'
    cmpa #'9'
    bls unique_digit_ok
    adda #7
unique_digit_ok
    rts
file_window
    jsr window_open
    ldaa #$03
    jsr colour
    ldx #ok_cancel__0523
    ldx 2,x
    ldaa #16
    jsr window_line
    rts
file_palette_save
    jsr palette_descriptor
    ldaa #DMA_COPY
    jmp dma_run
file_palette_back
    jsr palette_descriptor
    ldx #paint_dma
    ldab #3
palette_swap
    ldaa 0,x
    psha
    ldaa 3,x
    staa 0,x
    pula
    staa 3,x
    inx
    decb
    bne palette_swap
    ldaa #DMA_COPY
    jmp dma_run
palette_descriptor
    jsr dma_reset
    ldx #p_palette
    stx file_palette_ptr
    ldx #paint_dma
    ldaa file_palette_ptr+1
    staa DMA_SRC,x
    ldaa file_palette_ptr
    staa DMA_SRC+1,x
    ldaa #$fa
    staa DMA_DST+1,x
    ldaa #P_STAGE_PAGE
    staa DMA_DST+2,x
    ldaa #3
    staa DMA_WIDTH+1,x
    rts
file_palette
    ldaa p_kind
    cmpa #4
    beq file_palette_ham
    jmp palette_index
file_palette_ham
    jmp palette_ham
file_preview_kind
    ; Imported two-/four-colour palettes may require indexed preview even
    ; when the native 601/A packed mode cannot reproduce those RGB values.
    ldaa p_kind
    beq preview_mono_palette
    cmpa #2
    bne preview_kind_ready
    tst p_model
    beq preview_kind_ready
    ldx #native_four
    stx src
    ldx #p_palette
    stx dst
    ldab #12
preview_four_compare
    ldx src
    ldaa 0,x
    inx
    stx src
    ldx dst
    cmpa 0,x
    bne preview_custom
    inx
    stx dst
    decb
    bne preview_four_compare
    rts
preview_mono_palette
    ldx #p_palette
    ldaa 0,x
    oraa 1,x
    oraa 2,x
    bne preview_custom
    ldaa 3,x
    cmpa #63
    bne preview_custom
    ldaa 4,x
    cmpa #63
    bne preview_custom
    ldaa 5,x
    cmpa #63
    bne preview_custom
preview_kind_ready
    rts
preview_custom
    ldaa #1
    staa p_preview_ext
    rts
file_stage
    ldx #p_open_title
    jsr file_window
    ldx #0
    stx file_enc_offset
    clr file_row
stage_row
    ldaa file_row
    jsr canvas_read
    tsta
    bne stage_return
    jsr backend_encode
    tsta
    bne stage_return
    jsr encoded_descriptor
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    bne stage_return
    jsr encoded_advance
    jsr file_meter
    tsta
    bne stage_return
    inc file_row
    ldaa file_row
    cmpa #200
    bne stage_row
    clra
stage_return
    rts
encoded_descriptor
    ldx #p_params
    ldx PB_BYTES,x
    stx file_enc_bytes
    jsr dma_reset
    ldx #p_encoded
    stx file_palette_ptr
    ldx #paint_dma
    ldaa file_palette_ptr+1
    staa DMA_SRC,x
    ldaa file_palette_ptr
    staa DMA_SRC+1,x
    ldaa file_enc_offset+1
    staa DMA_DST,x
    ldaa file_enc_offset
    staa DMA_DST+1,x
    ldaa #P_STAGE_PAGE
    staa DMA_DST+2,x
    ldaa file_enc_bytes+1
    staa DMA_WIDTH,x
    ldaa file_enc_bytes
    staa DMA_WIDTH+1,x
    rts
encoded_advance
    ldaa file_enc_offset+1
    adda file_enc_bytes+1
    staa file_enc_offset+1
    ldaa file_enc_offset
    adca file_enc_bytes
    staa file_enc_offset
    rts
file_commit
    jsr dma_reset
    ldx #paint_dma
    ldaa #P_LOAD_PAGE
    staa DMA_SRC+2,x
    ldaa file_old_doc
    staa DMA_DST+2,x
    ldx #p_doc_size
    ldaa 0,x
    ldab 1,x
    ldx #paint_dma
    staa DMA_WIDTH,x
    stab DMA_WIDTH+1,x
    ldx #p_doc_size
    ldaa 2,x
    ldx #paint_dma
    staa DMA_WIDTH+2,x
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    bne commit_return
    ldaa file_old_doc
    staa p_doc_page
    tst p_preview_ext
    beq commit_native
    jsr dma_reset
    ldx #paint_dma
    ldaa #P_STAGE_PAGE
    staa DMA_SRC+2,x
    ldaa p_front_page
    adda #$10
    staa DMA_DST+2,x
    ldaa #$fa
    staa DMA_WIDTH+1,x
    ldaa #DMA_COPY
    jmp dma_run
commit_native
    ldx #0
    stx file_enc_offset
    clr file_row
commit_row
    jsr encoded_descriptor
    ldx #paint_dma
    ldab #3
commit_swap
    ldaa 0,x
    psha
    ldaa 3,x
    staa 0,x
    pula
    staa 3,x
    inx
    decb
    bne commit_swap
    ldaa #DMA_COPY
    jsr dma_run
    tsta
    bne commit_return
    ldaa file_row
    jsr canvas_blit
    tsta
    bne commit_return
    jsr encoded_advance
    inc file_row
    ldaa file_row
    cmpa #200
    bne commit_row
    clra
commit_return
    rts
file_foreground
    ldaa p_kind
    cmpa #4
    beq foreground_done
    ldaa #2
    ldab p_kind
    cmpb #2
    bcs foreground_limit
    ldaa #4
    cmpb #2
    beq foreground_limit
    clra
foreground_limit
    staa file_fg_limit
    clr file_fg_index
    clr file_fg_best
    clr p_fg
    ldx #p_palette
    stx file_palette_ptr
foreground_next
    ldx file_palette_ptr
    ldaa 0,x
    adda 1,x
    adda 2,x
    cmpa file_fg_best
    bls foreground_skip
    staa file_fg_best
    ldaa file_fg_index
    staa p_fg
foreground_skip
    inx
    inx
    inx
    stx file_palette_ptr
    inc file_fg_index
    ldaa file_fg_index
    cmpa file_fg_limit
    bne foreground_next
foreground_done
    rts
default_pcx db 'UNTITLED.PCX',0
default_iff db 'UNTITLED.IFF',0
native_four db 21,21,63,21,63,63,63,21,63,63,63,63
file_zero db 0,0,0,0
    end
