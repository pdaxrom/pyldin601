standalone_message db 10,'Start the editor with NC F4.',10,0
title db ' NC Editor',0
help_text db 'F2 Save; Sh+F2 As; F7 Find; Sh+F7 Next; F3/Shift Select; '
    db '^C Copy; ^X Cut; ^V Paste; ^A All; ^Z/Y Undo/Redo; F10 Exit',0
ok_button db '[ OK ]',0
yes_button db '[ Yes ]',0
no_button db '[ No ]',0
cancel_text db '[ Cancel ]',0
yes_no_buttons dw yes_button,no_button
ok_cancel_buttons dw ok_button,cancel_text
confirm_title db 'Confirm',0
work_name db 'NCE00000.IDX',0
work_extensions db 'IDX',0,'ADD',0,'UND',0
insert_label db ' INS C:',0
overwrite_label db ' OVR C:',0
block_label db ' BLK C:',0
editor_keys_short db '1Hlp 2Sav 3Blk ^C/X/V 7Fnd ^Z/Y 10Exit',0
editor_keys_long db '1Help 2Save Sh2As 3Block ^C/X/V 7Find Sh7Next ^Z/Y 10Exit',0
exit_title db 'Exit editor',0
exit_message db 'Save changes before leaving?',0
exit_save_label db 'Save',0
exit_discard_label db 'Discard',0
exit_cancel_label db 'Cancel',0
exit_button_table dw exit_save_label,exit_discard_label,exit_cancel_label
save_as_title db 'Save as',0
overwrite_text db 'Replace the existing file?',0
saving_title db 'Saving',0
cancel_save_text db '[Esc Cancel]',0
save_name db 'NCE00000.NEW',0
written_label db 'Written:',0
total_label db 'Total:',0
search_title db 'Search',0
not_found_text db 'Text not found.',0
retry_title db 'Disk error - pending edit',0
retry_text db 'Enter retries. Esc discards all unsaved changes and closes the editor.',0
const32 db 0,0,0,32
bss_start
owner ds 2
mode ds 1
original_attr ds 1
columns ds 1
ui_command ds 1
ui_keys ds 1
saved_cursor ds 1
screen_base ds 2
text_stride ds 1
ui_x ds 1
ui_y ds 1
ink ds 1
gfx_table ds 2
glyph ds 8
glyph_ptr ds 2
glyph_row ds 1
glyph_bits ds 1
glyph_byte ds 1
font_saved_page ds 1
font_saved_group ds 1
outptr ds 2
stride ds 1
output_char ds 1
remaining ds 1
fill_char ds 1
textptr ds 2
src ds 2
dst ds 2
add_pointer ds 2
input ds 81
input_end ds 2
command_caret ds 1
message_ptr ds 2
window_title ds 2
window_text ds 2
window_inner ds 1
window_left ds 1
window_top ds 1
window_bottom ds 1
window_focus ds 1
window_index ds 1
window_key ds 1
button_table ds 2
button_focus ds 1
button_width ds 1
edit_length ds 1
edit_cursor ds 1
edit_offset ds 1
edit_index ds 1
error_text ds 81
number ds 4
number_text ds 11
number_ptr ds 2
remainder ds 1
number_divisor ds 1
q ds 4
wanted_file ds 1
wanted_pos ds 4
block_offset ds 2
block_left ds 2
cache_slot ds 1
cache_count ds 1
cache_hand ds 1
cache_buf ds 2
cache_byte ds 2
saved_tag ds 2
cache_tags ds 160
cache_data ds 2048
cache_lease ds 4
cache_leased ds 1
old_page ds 1
old_group ds 1
lease_group ds 1
io_file ds 1
io_position ds 4
io_count ds 2
io_table ds 4
open_table ds 4
handles ds 4
file_positions ds 16
file_sizes ds 16
leaf_id ds 4
leaf_start ds 4
leaf_ptr ds 2
leaf_slot ds 1
entry_base ds 2
next_leaf ds 4
piece_in ds 4
piece_index ds 1
entry_ptr ds 2
shift_end ds 2
split_buffer ds 256
split_count ds 1
split_bytes ds 2
split_next ds 4
split_ptr ds 2
split_index ds 1
split_total ds 4
index_end ds 4
where ds 4
doc_size ds 4
insert_off ds 4
insert_len ds 4
prefix_ptr ds 2
insert_ptr ds 2
remove_len ds 4
remove_left ds 4
remove_take ds 4
suffix_len ds 4
stream_left ds 2
stream_file ds 1
stream_physical ds 4
stream_remaining ds 4
stream_ptr ds 2
stream_char ds 1
filename ds 80
work_path ds 80
work_tail ds 2
work_ready ds 1
work_attempt ds 1
work_kind ds 1
work_created ds 1
work_error ds 1
new_handle ds 1
opened ds 1
find_table ds 6
find_state ds 19
dir_entry ds 32
body_rows ds 1
eol_length ds 1
eol_bytes ds 2
add_tail ds 4
append_char ds 1
disk_buffer ds 512
change_at ds 4
change_delete ds 1
change_add ds 1
change_bytes ds 2
change_index ds 1
change_group ds 1
e_cursor ds 4
pending_record ds 32
history_record ds 32
history_mode ds 1
history_position ds 4
history_cursor ds 4
history_count ds 4
history_target ds 4
group_open ds 1
apply_pos ds 4
apply_left ds 4
apply_insert_off ds 4
apply_insert_len ds 4
apply_cursor ds 4
apply_phase ds 1
apply_error ds 1
saved_history ds 4
saved_valid ds 1
modified ds 1
screen_chars ds 1920
new_line ds 80
line_offsets ds 100
line_ends ds 96
line_left ds 96
line_left_column ds 96
line_valid ds 24
horizontal ds 4
screen_top ds 4
e_column ds 4
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
view_scan ds 31
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
search_prefix_table equ new_line
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
view_anchor ds 18
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
view_tail ds 10
save_bar_width ds 1
block_state ds 112
block_marks ds 48
bss_end
