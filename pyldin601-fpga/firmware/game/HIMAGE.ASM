; Standard 320x200 HAM8 ILBM/ByteRun1 reader, derived from HVIEW.
; Preserve every decoded HAM8 byte; the FPGA handles foreground overlays.
hi_ctrl equ $e650
hi_cmd equ $e651
hi_front equ $e652
hi_colour equ $e653
hi_dstpage equ $e655
hi_dstlo equ $e658
hi_dsthi equ $e659
hi_load
    ; A=destination SRAM page, X=resolved filename. Loading happens once
    ; before the first score screen; cooperative hooks keep AY fed.
    staa hi_page
    sts hi_return_sp
    stx hi_open_table
    clr hi_open_table+2
    clr hi_open_table+3
    clr hi_seen
    clr hi_available
    clr hi_available+1
        ldx #hi_open_table
        ldaa #1
        int $4a
        tsta
        beq hi_open_ok
        jmp hi_io_error
hi_open_ok
        stab hi_handle
        inc hi_opened
        ldaa hi_handle
        ldx #hi_file_size
        int $51
        tsta
        beq hi_size_ok
        jmp hi_io_error
hi_size_ok
        ; Bound both input work and all 32-bit arithmetic to 1 MiB.
        ldx hi_file_size
        cpx #15
        bls hi_size_fits
        jmp hi_bad_file
hi_size_fits
        ldd #hi_form
        std hi_read_table
        ldd #12
        std hi_read_table+2
        jsr hi_read_exact
        jsr hi_validate
        ldd hi_file_size+2
        subd #12
        std hi_file_left+2
        ldd hi_file_size
        sbcb #0
        sbca #0
        std hi_file_left
        bcc hi_form_ready
        jmp hi_bad_file
hi_form_ready
hi_next_chunk
        ldd hi_file_left
        bne hi_next_header
        ldd hi_file_left+2
        bne hi_next_header
        jmp hi_file_done
hi_next_header
        ldx #hi_chunk
        stx hi_ptr
        ldaa #8
        staa hi_n
hi_header_byte
        jsr hi_get_byte
        ldx hi_ptr
        staa 0,x
        inx
        stx hi_ptr
        dec hi_n
        bne hi_header_byte
        ldd hi_chunk+4
        std hi_chunk_left
        ldd hi_chunk+6
        std hi_chunk_left+2
        andb #1
        stab hi_padding
        ldx hi_chunk_left
        cpx hi_file_left
        bhi hi_chunk_bad
        blo hi_fits
        ldx hi_chunk_left+2
        cpx hi_file_left+2
        bls hi_fits
hi_chunk_bad
        jmp hi_bad_file
hi_fits
        ldx hi_chunk
        cpx #$424d
        bne hi_not_bmhd
        ldx hi_chunk+2
        cpx #$4844
        bne hi_unknown_chunk
        jsr hi_bmhd
        jmp hi_chunk_done
hi_not_bmhd
        cpx #$4341
        bne hi_not_camg
        ldx hi_chunk+2
        cpx #$4d47
        bne hi_unknown_chunk
        jsr hi_camg
        jmp hi_chunk_done
hi_not_camg
        cpx #$434d
        bne hi_not_cmap
        ldx hi_chunk+2
        cpx #$4150
        bne hi_unknown_chunk
        jsr hi_cmap
        jmp hi_chunk_done
hi_not_cmap
        cpx #$424f
        bne hi_unknown_chunk
        ldx hi_chunk+2
        cpx #$4459
        bne hi_unknown_chunk
        ldaa hi_seen
        cmpa #7
        beq hi_body_ready
        jmp hi_bad_file
hi_body_ready
        ldaa hi_page
        staa hi_dstpage
        jsr hi_decode_body
        ldaa #15
        staa hi_seen
        jmp hi_chunk_done
hi_unknown_chunk
        jsr hi_skip_chunk
hi_chunk_done
        tst hi_padding
        beq hi_next_chunk_jump
        jsr hi_get_byte
hi_next_chunk_jump
        jmp hi_next_chunk
hi_file_done
        ldaa hi_seen
        cmpa #15
        beq hi_ready
        jmp hi_bad_file
hi_ready
    jsr hi_close_file
    clra
    rts
hi_bad_file
hi_io_error
hi_graphics_error
    lds hi_return_sp
    jsr hi_close_file
    ldaa #1
    rts
hi_close_file
    tst hi_opened
    beq hi_closed
    ldaa hi_handle
    int $4e
    clr hi_opened
hi_closed
    rts
hi_read_exact
        ldaa hi_handle
        ldx #hi_read_table
        int $4c
        tsta
        bne hi_read_failed
        cpx hi_read_table+2
        bne hi_read_failed
        jsr xl_audio
        rts
hi_read_failed
        jmp hi_io_error
hi_validate
        ldx hi_form
        cpx #$464f
        bne hi_form_bad
        ldx hi_form+2
        cpx #$524d
        bne hi_form_bad
        ldx hi_form+8
        cpx #$494c
        bne hi_form_bad
        ldx hi_form+10
        cpx #$424d
        bne hi_form_bad
        ldd hi_file_size+2
        subd #8
        std hi_temp_word
        ldd hi_file_size
        sbcb #0
        sbca #0
        std hi_temp_high
        ldx hi_temp_high
        cpx hi_form+4
        bne hi_form_bad
        ldx hi_temp_word
        cpx hi_form+6
        bne hi_form_bad
        rts
hi_form_bad
        jmp hi_bad_file
; hi_get_byte decrements unread FILE bytes; refill never crosses EOF.
hi_get_byte
        ldd hi_file_left
        bne hi_has
        ldd hi_file_left+2
        bne hi_has
        jmp hi_bad_file
hi_has
        ldd hi_available
        bne hi_buffered
        ldd #512
        ldx hi_file_left
        bne hi_refill_size
        ldx hi_file_left+2
        cpx #512
        bcc hi_refill_size
        ldd hi_file_left+2
hi_refill_size
        std hi_read_table+2
        ldd #hi_buf
        std hi_read_table
        jsr hi_read_exact
        stx hi_available
        ldx #hi_buf
        stx hi_input
hi_buffered
        ldd hi_file_left+2
        subd #1
        std hi_file_left+2
        ldd hi_file_left
        sbcb #0
        sbca #0
        std hi_file_left
        ldd hi_available
        subd #1
        std hi_available
        ldx hi_input
        ldaa 0,x
        inx
        stx hi_input
        rts
hi_chunk_byte
        ldd hi_chunk_left
        bne hi_chunk_has
        ldd hi_chunk_left+2
        bne hi_chunk_has
        jmp hi_bad_file
hi_chunk_has
        ldd hi_chunk_left+2
        subd #1
        std hi_chunk_left+2
        ldd hi_chunk_left
        sbcb #0
        sbca #0
        std hi_chunk_left
        jmp hi_get_byte
hi_skip_chunk
        ldd hi_chunk_left
        bne hi_skip_byte
        ldd hi_chunk_left+2
        beq hi_skip_done
hi_skip_byte
        jsr hi_chunk_byte
        bra hi_skip_chunk
hi_skip_done
        rts
; Known header payloads must fit in 16 bits and have an exact size in X.
hi_len
        ldd hi_chunk_left
        bne hi_len_bad
        cpx hi_chunk_left+2
        bne hi_len_bad
        rts
hi_len_bad
        jmp hi_bad_file
hi_bmhd
        ldaa hi_seen
        bita #1
        bne hi_bitmap_bad
        ldx #20
        jsr hi_len
        ldx #hi_bitmap
        stx hi_ptr
        ldaa #20
        staa hi_n
hi_bitmap_byte
        jsr hi_chunk_byte
        ldx hi_ptr
        staa 0,x
        inx
        stx hi_ptr
        dec hi_n
        bne hi_bitmap_byte
        ldx hi_bitmap
        cpx #320
        bne hi_bitmap_bad
        ldx hi_bitmap+2
        cpx #200
        bne hi_bitmap_bad
        ldaa hi_bitmap+8
        cmpa #8
        bne hi_bitmap_bad
        tst hi_bitmap+9
        bne hi_bitmap_bad
        ldaa hi_bitmap+10
        cmpa #1
        bhi hi_bitmap_bad
        staa hi_comp
        ldaa hi_seen
        oraa #1
        staa hi_seen
        rts
hi_bitmap_bad
        jmp hi_bad_file
hi_camg
        ldaa hi_seen
        bita #4
        bne hi_mode_bad
        ldx #4
        jsr hi_len
        jsr hi_chunk_byte
        tsta
        bne hi_mode_bad
        jsr hi_chunk_byte
        tsta
        bne hi_mode_bad
        jsr hi_chunk_byte
        cmpa #8
        bne hi_mode_bad
        jsr hi_chunk_byte
        tsta
        bne hi_mode_bad
        ldaa hi_seen
        oraa #4
        staa hi_seen
        rts
hi_mode_bad
        jmp hi_bad_file
hi_cmap
        ldaa hi_seen
        bita #2
        bne hi_map_bad
        ldx #192
        jsr hi_len
        clr hi_map_index
hi_map_entry
        ldaa hi_map_index
        lsra
        lsra
        lsra
        lsra
        jsr hi_map_component
        ldaa hi_map_index
        lsra
        lsra
        anda #3
        jsr hi_map_component
        ldaa hi_map_index
        anda #3
        jsr hi_map_component
        inc hi_map_index
        ldaa hi_map_index
        cmpa #64
        bne hi_map_entry
        ldaa hi_seen
        oraa #2
        staa hi_seen
        rts
hi_map_component
        ldab #85
        mul
        stab hi_expect
        jsr hi_chunk_byte
        cmpa hi_expect
        bne hi_map_bad
        rts
hi_map_bad
        jmp hi_bad_file
hi_decode_body
        clr hi_pos
        clr hi_pos+1
        ldaa #200
        staa hi_rows_left
hi_next_row
        ldx #hi_row
hi_clear_row
        clr 0,x
        inx
        cpx #hi_row+320
        bne hi_clear_row
        ldaa #1
        staa hi_mask
hi_next_plane
        ldx #hi_row
        stx hi_pixel
        ldaa #40
        staa hi_plane_left
hi_plane_packet
        jsr hi_chunk_byte
        tst hi_comp
        beq hi_raw_byte
        cmpa #128
        beq hi_plane_packet
        bcc hi_repeat_packet
        inca
        jsr hi_packet_size
hi_literal_byte
        jsr hi_chunk_byte
        jsr hi_put_plane_byte
        dec hi_run_count
        bne hi_literal_byte
        bra hi_plane_more
hi_repeat_packet
        nega
        inca
        jsr hi_packet_size
        jsr hi_chunk_byte
        staa hi_pack
hi_repeat_byte
        ldaa hi_pack
        jsr hi_put_plane_byte
        dec hi_run_count
        bne hi_repeat_byte
        bra hi_plane_more
hi_raw_byte
        jsr hi_put_plane_byte
hi_plane_more
        tst hi_plane_left
        bne hi_plane_packet
        asl hi_mask
        bne hi_next_plane
        ldx #hi_row
hi_draw_pixel
        ldaa 0,x
        staa hi_colour
        ldd hi_pos
        staa hi_dsthi
        stab hi_dstlo
        ldaa #4
        jsr hi_execute
        inx
        ldd hi_pos
        addd #1
        std hi_pos
        cpx #hi_row+320
        bne hi_draw_pixel
        jsr xl_progress
        dec hi_rows_left
        beq hi_body_end
        jmp hi_next_row
hi_body_end
        ldd hi_chunk_left
        bne hi_body_tail
        ldd hi_chunk_left+2
        beq hi_body_done
hi_body_tail
        tst hi_comp
        beq hi_body_bad
        jsr hi_chunk_byte
        cmpa #128
        beq hi_body_end
hi_body_bad
        jmp hi_bad_file
hi_body_done
        rts
hi_packet_size
        cmpa hi_plane_left
        bhi hi_body_bad
        staa hi_run_count
        rts
hi_put_plane_byte
        tab
        ldx hi_pixel
        ldaa #8
        staa hi_bit_count
hi_plane_bit
        aslb
        bcc hi_bit_zero
        ldaa 0,x
        oraa hi_mask
        staa 0,x
hi_bit_zero
        inx
        dec hi_bit_count
        bne hi_plane_bit
        stx hi_pixel
        dec hi_plane_left
        rts
hi_execute
        staa hi_cmd
        pshx
        ldx #$ffff
hi_wait_job
        ldaa hi_ctrl
        bpl hi_job_done
        dex
        bne hi_wait_job
        jmp hi_graphics_error
hi_job_done
        bita #$30
        beq hi_job_ok
        jmp hi_graphics_error
hi_job_ok
        pulx
        rts
