; NCEV3: Uninitialized application state and buffers.
    .define NC_EDITOR
    include NCABI.INC
    include NCBOX.INC
    public base_closed
    public base_is_backup
    public base_path
    public build_full
    public caret_char
    public caret_x
    public caret_y
    public change_lin_2598
    public copy_blocks
    public copy_tail
    public cursor_row
    public cursor_seen
    public deleted_char
    public desired_column
    public desired_valid
    public edit_delta
    public editor_ini_76b1
    public error_key
    public exit_draw
    public exit_focus
    public full_table
    public half_columns
    public last_key
    public latest_backup
    public metadata_row
    public nav_column
    public nav_end
    public nav_line
    public nav_position
    public nav_probe
    public nav_saved
    public nav_start
    public overwrite
    public page_remaining
    public path_char
    public path_tail
    public poll_count
    public rename_call
    public rename_table
    public render_eof
    public render_row
    public restore_ptr
    public restore_row
    public save_attempt
    public save_attributes
    public save_backu_94f9
    public save_backup
    public save_bar_index
    public save_bar_width
    public save_buffer
    public save_cells
    public save_chunk
    public save_done
    public save_error
    public save_exists
    public save_handle
    public save_length
    public save_next
    public save_open
    public save_ptr
    public save_quantum
    public save_renamed
    public save_tail
    public save_take
    public save_target
    public save_temp
    public search_amount
    public search_char
    public search_i
    public search_j
    public search_length
    public search_skip
    public search_start
    public search_text
    public search_wrapped
    public split_has__2828
    public split_neig_366a
    public split_neighbor
    public v_edit_del_1
    public v_edit_del_2
    public v_edit_del_3
    public v_full_tab_2
    public v_nav_colu_1
    public v_nav_colu_2
    public v_nav_colu_3
    public v_rename_c_2
    public v_rename_t_2
    public v_save_chu_1
    public v_save_chu_2
    public v_save_don_1
    public v_save_don_2
    public v_save_don_3
    public v_save_len_1
    public v_save_tak_1
    public view_valid

    section
last_key ds 1
overwrite ds 1
render_row ds 1
cursor_row ds 1
cursor_seen ds 1
render_eof ds 1
build_full ds 1
; view_scan+0 = render_x
; view_scan+1 = anchor_set
; view_scan+2 = scan_column
; view_scan+6 = scan_start
; view_scan+10 = scan_char_pos
; view_scan+14 = scan_char_column
; view_scan+18 = scan_char
; view_scan+19 = display_char
; view_scan+20 = scan_end
; view_scan+24 = eol_detected
; view_scan+25 = paint_cache
; view_scan+27 = paint_text
; view_scan+29 = paint_char
; view_scan+30 = paint_run
caret_x ds 1
caret_y ds 1
caret_char ds 1
desired_valid ds 1
desired_column ds 4
nav_line ds 4
nav_position ds 4
nav_start ds 4
nav_end ds 4
nav_probe ds 4
nav_saved ds 4
nav_column ds 4
page_remaining ds 1
half_columns ds 4
deleted_char ds 1
edit_delta ds 4
metadata_row ds 1
poll_count ds 1
exit_focus ds 1
base_path ds 80
base_is_backup ds 1
base_closed ds 1
latest_backup ds 80
save_target ds 80
save_temp ds 80
save_backup ds 80
save_open ds 1
save_renamed ds 1
save_exists ds 1
save_attributes ds 1
save_handle ds 1
save_done ds 4
save_cells ds 1
save_quantum ds 4
save_next ds 4
save_ptr ds 2
save_length ds 2
save_error ds 1
save_tail ds 2
save_backup_tail ds 2
save_attempt ds 1
save_bar_index ds 1
path_tail ds 2
path_char ds 1
full_table ds 4
rename_table ds 4
rename_call ds 4
save_buffer ds 512
search_text ds 80
search_length ds 1
search_skip ds 1
search_j ds 1
search_i ds 1
search_char ds 1
search_start ds 4
search_wrapped ds 1
search_amount ds 4
exit_draw ds 1
error_key ds 1
split_has_neighbor ds 1
split_neighbor ds 2
split_neighbor_slot ds 1
; view_anchor+0 = anchor_offset
; view_anchor+4 = anchor_column
; view_anchor+8 = anchor_saved_cursor
; view_anchor+12 = anchor_saved_column
; view_anchor+16 = anchor_saved_row
; view_anchor+17 = anchor_error
editor_initialized ds 1
copy_blocks ds 1
copy_tail ds 1
save_take ds 2
save_chunk ds 4
view_valid ds 1
restore_row ds 1
restore_ptr ds 2
change_linebreak ds 1
; view_tail+0 = scan_take
; view_tail+2 = scan_run_start
; view_tail+4 = scan_run_end
; view_tail+6 = scan_advance
save_bar_width ds 1
    ends
change_lin_2598 equ change_linebreak
editor_ini_76b1 equ editor_initialized
save_backu_94f9 equ save_backup_tail
split_has__2828 equ split_has_neighbor
split_neig_366a equ split_neighbor_slot
v_edit_del_1 equ edit_delta+1
v_edit_del_2 equ edit_delta+2
v_edit_del_3 equ edit_delta+3
v_full_tab_2 equ full_table+2
v_nav_colu_1 equ nav_column+1
v_nav_colu_2 equ nav_column+2
v_nav_colu_3 equ nav_column+3
v_rename_c_2 equ rename_call+2
v_rename_t_2 equ rename_table+2
v_save_chu_1 equ save_chunk+1
v_save_chu_2 equ save_chunk+2
v_save_don_1 equ save_done+1
v_save_don_2 equ save_done+2
v_save_don_3 equ save_done+3
v_save_len_1 equ save_length+1
v_save_tak_1 equ save_take+1
    end
