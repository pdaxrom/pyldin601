; NCMV2: Uninitialized application state and buffers.
    include NCABI.INC
    include NCBOX.INC
    public backup_active
    public backup_path
    public backup_tail
    public backup_tries
    public button_focus
    public button_table
    public button_width
    public cmp_attr
    public cmp_char
    public cmp_count
    public cmp_left
    public cmp_offset
    public cmp_result
    public cmp_right
    public cmp_step
    public draft_hidden
    public draft_sort
    public draft_workdir
    public draw_index
    public draw_panel
    public edit_cursor
    public edit_index
    public edit_length
    public edit_offset
    public field_padding
    public field_ptr
    public file_attributes
    public file_stamp
    public fill_char
    public font_saved_19b7
    public font_saved_page
    public free_left
    public free_query
    public free_right
    public gfx_table
    public header_ink
    public info_unit
    public ink
    public menu_active
    public menu_count
    public menu_draw
    public menu_group
    public menu_index
    public menu_previous
    public menu_slot
    public menu_table
    public message_ptr
    public name_index
    public name_record
    public name_text
    public number
    public number_divisor
    public number_ptr
    public number_text
    public origin
    public outptr
    public output_char
    public progress_cells
    public progress_index
    public progress_mode
    public progress_p_70c2
    public progress_v_0160
    public progress_width
    public remainder
    public remaining
    public row_entry
    public stride
    public target_path
    public temp_path
    public text_stride
    public ui_x
    public v_free_que_2
    public v_number_1
    public v_number_2
    public v_number_3
    public v_number_t_10
    public v_outptr_1
    public v_row_entr_1
    public window_bottom
    public window_focus
    public window_index
    public window_inner
    public window_key
    public window_left
    public window_text
    public window_title
    public window_top

    section
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
ink ds 1
header_ink ds 1
gfx_table ds 2
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
file_stamp equ free_query
    ends
font_saved_19b7 equ font_saved_group
progress_p_70c2 equ progress_painted
progress_v_0160 equ progress_visible
v_free_que_2 equ free_query+2
v_number_1 equ number+1
v_number_2 equ number+2
v_number_3 equ number+3
v_number_t_10 equ number_text+10
v_outptr_1 equ outptr+1
v_row_entr_1 equ row_entry+1
    end
