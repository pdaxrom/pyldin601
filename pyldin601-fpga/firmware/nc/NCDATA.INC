standalone_message db 10,'Start NC.PGM, not NCMAIN.PGM.',10,0
title db ' Pyldin Commander',0
wildcard db '*.*',0
dir_text db '<DIR>',0
up_text db '<UP>',0
attribute_names db 'RHSA'
name_heading db ' Name',0
size_heading db 'Size',0
date_heading db 'Modified',0
free_suffix db ' free',0
free_unknown db '? free',0
marks_page_text db 'Unmark files before changing page.',0
keys_short db '1Hlp2Cmd3Viw4Edt5Cpy6Mov7Mkd8Del9Mnu10Q',0
keys_long db '1Help 2Command 3View 4Edit 5Copy 6Move 7Mkdir 8Delete 9Menu 10Quit',0
help_text db 'F1-10: commands; Ctrl+F1/F2: left/right drive; Ctrl+O: shell, EXIT back',0
drive_prompt db 'Select drive',0
drive_buttons db '[Enter] [Esc]',0
no_drives_text db 'No drives available.',0
command_prompt db 'Command',0
mkdir_prompt db 'New directory',0
copy_prompt db 'Copy to',0
move_prompt db 'Move / rename to',0
delete_prompt db 'Delete selected files/directories? Y/N',0
overwrite_prompt db 'Destination exists. Overwrite? Y/N',0
viewer_keys db 'F3 View   PgUp/PgDn Space Home   Esc',0
temp_name db 'NC$000A.TMP',0
top_left db 'Left',0
top_file db 'File',0
top_command db 'Command',0
top_options db 'Options',0
top_right db 'Right',0
top_names dw top_left,top_file,top_command,top_options,top_right
item_drive db '1 Drive...',0
item_reread db '3 Reread',0
item_panel_reread db '2 Reread',0
item_option_settings db '1 Settings...',0
item_view db '1 View       F3',0
item_edit db '2 Edit       F4',0
item_copy db '3 Copy       F5',0
item_move db '4 Move       F6',0
item_mkdir db '5 Mkdir      F7',0
item_delete db '6 Delete     F8',0
item_quit db '7 Quit      F10',0
item_command db '1 Command line...',0
item_shell db '2 Shell    Ctrl+O',0
item_settings db '4 Settings...',0
panel_menu dw item_drive,item_panel_reread
file_menu dw item_view,item_edit,item_copy,item_move,item_mkdir,item_delete,item_quit
command_menu dw item_command,item_shell,item_reread,item_settings
options_menu dw item_option_settings
menu_lists dw panel_menu,file_menu,command_menu,options_menu,panel_menu
menu_counts db 2,7,4,1,2
file_actions dw viewer,menu_editor,menu_copy,menu_move,make_directory,menu_delete,menu_quit
command_actions dw menu_command,shell_request,refresh,settings
ok_button db '[ OK ]',0
yes_button db '[ Yes ]',0
no_button db '[ No ]',0
cancel_text db '[ Cancel ]',0
apply_button db '[ Apply ]',0
yes_no_buttons dw yes_button,no_button
ok_cancel_buttons dw ok_button,cancel_text
apply_cancel_buttons dw apply_button,cancel_text
cancel_button db '[ Esc Cancel ]',0
confirm_title db 'Confirm',0
settings_title db 'Settings',0
workdir_label db ' w Work files directory...',0
workdir_default db '(document directory)',0
workdir_title db 'Editor work directory',0
sort_keys db 'nesd'
sort_name db ' ( ) n Name',0
sort_ext db ' ( ) e Extension',0
sort_size db ' ( ) s Size',0
sort_date db ' ( ) d Date',0
hidden_label db ' [ ] h Hidden files',0
settings_rows dw sort_name,sort_ext,sort_size,sort_date,hidden_label
progress_copy db 'Copy - file progress',0
progress_move db 'Move - file progress',0
progress_delete db 'Delete - activity',0
progress_titles dw progress_copy,progress_move,progress_delete
progress_from db 'From: ',0
progress_to db 'To: ',0
progress_slash db ' / ',0
progress_item_label db 'Completed: ',0
bss_start
owner ds 2
active ds 1
panel ds 1
mode ds 1
original_attr ds 1
columns ds 1
ui_rows ds 1
ui_end ds 1
ui_info ds 1
ui_bottom ds 1
ui_command ds 1
ui_keys ds 1
saved_cursor ds 1
panel_width ds 1
screen_base ds 2
cacheptr ds 2
candidate ds ENTRY_SIZE
pivotptr ds 2
paging_direction ds 1
had_overflow ds 1
entry_capacity ds 1
insert_index ds 1
insert_high ds 1
insert_mid ds 1
shift_index ds 1
has_previous ds 2
has_next ds 2
page_request ds 1
cache_owner ds 1
cache_lease ds 4
cache_lease_open ds 1
bank_valid ds 2
cache_group ds 1
cache_old_group ds 1
cache_old_page ds 1
cache_valid ds 1
requested_panel ds 1
marks_ptr ds 2
mark_count ds 1
mark_index ds 1
mark_value ds 1
marks_left ds BANK_COUNT
marks_right ds BANK_COUNT
pathptr ds 2
pcount ds 1
pcur ds 1
ptop ds 1
counts ds 2
cursors ds 2
tops ds 2
directory_error ds 1
request ds 1
last_key ds 1
delta ds 1
command_length ds 1
command_line ds 81
input ds 81
; Drive selection and text-input dialogs are mutually exclusive. Media
; errors use error_text, so the available-drive list survives an error box.
drive_list equ input
drive_current equ input+8
drive_original equ input+9
drive_scan equ input+10
drive_target equ input+11
drive_choice equ input+12
input_end ds 2
command_caret ds 1
src ds 2
dst ds 2
ptr ds 2
add_pointer ds 2
next_cursor ds 1
previous_cursor ds 1
previous_top ds 1
next_top ds 1
cursor_selected ds 1
cursor_marker ds 1
cursor_cells ds 1
cursor_byte ds 1
scroll_direction ds 1
scroll_row ds 1
scroll_count ds 1
scroll_source ds 2
scroll_target ds 2
scroll_tail ds 1
copy_blocks ds 1
textptr ds 2
find_table ds 6
find_state ds 19
dir_entry ds 32
search_path ds 80
source_path ds 80
target_path ds 80
temp_path ds 80
backup_path ds 80
backup_tail ds 2
backup_tries ds 1
backup_active ds 1
file_attributes ds 1
name_record ds 2
name_index ds 1
name_text ds 14
cmp_left ds 2
cmp_right ds 2
cmp_attr ds 1
cmp_char ds 1
cmp_count ds 1
cmp_offset ds 1
cmp_step ds 1
cmp_result ds 1
ui_x ds 1
ui_y ds 1
ink ds 1
header_ink ds 1
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
text_stride ds 1
output_char ds 1
remaining ds 1
fill_char ds 1
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
menu_active ds 1
menu_group ds 1
menu_index ds 1
menu_previous ds 1
menu_count ds 1
menu_table ds 2
menu_slot ds 1
menu_draw ds 1
draft_sort ds 1
draft_hidden ds 1
draft_workdir ds 80
draw_panel ds 1
origin ds 1
draw_index ds 1
row_entry ds 2
field_ptr ds 2
field_padding ds 1
free_query ds 4
free_left ds 16
free_right ds 16
number ds 4
number_text ds 11
number_ptr ds 2
remainder ds 1
number_divisor ds 1
info_unit ds 1
progress_visible ds 1
progress_mode ds 1
progress_width ds 1
progress_cells ds 1
progress_painted ds 1
progress_index ds 1
progress_bytes ds 2
progress_total ds 4
progress_done ds 4
progress_next ds 4
progress_quantum ds 4
progress_items ds 4
error_text ds 81
mkdir_prefix_length ds 1
stat_table ds 6
stat_find ds 19
stat_entry ds 32
operation ds 1
action_index ds 1
action_record ds 2
group_marked ds 1
cancelled ds 1
walk_depth ds 1
frame ds 2
walk_table ds 6
walk_frames ds 24*56
source_open ds 1
target_open ds 1
existing_target ds 1
skipped ds 1
source_handle ds 1
target_handle ds 1
io_error ds 1
open_table ds 4
io_table ds 4
; These lifetimes are disjoint: rename has returned before an error is drawn.
rename_source equ error_text
; FindNext keeps its own search state; the wildcard scratch is reusable.
rename_target equ search_path
rename_call ds 4
rename_table ds 4
full_table ds 4
file_stamp equ free_query
temp_tail ds 2
temp_digits ds 2
temp_tries ds 1
view_handle ds 1
view_position ds 4
view_page ds 1
; Viewer and recursive file operations cannot run at the same time.
view_history equ walk_frames
view_eof ds 1
view_left ds 2
view_ptr ds 2
io_buffer ds 512
entries_left ds ENTRY_COUNT*ENTRY_SIZE
entries_right equ entries_left
edited_name_ptr ds 2
edited_retry ds 1
bss_end
