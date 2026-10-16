; NCEV1: Uninitialized application state and buffers.
    .define NC_EDITOR
    include NCABI.INC
    include NCBOX.INC
    public add_pointer
    public block_left
    public block_offset
    public button_focus
    public button_table
    public button_width
    public cache_buf
    public cache_count
    public cache_data
    public cache_hand
    public cache_lease
    public cache_leased
    public cache_tags
    public columns
    public command_caret
    public dst
    public edit_cursor
    public edit_index
    public edit_length
    public edit_offset
    public error_text
    public file_positions
    public file_sizes
    public fill_char
    public font_saved_19b7
    public font_saved_page
    public gfx_table
    public handles
    public ink
    public input
    public input_end
    public io_count
    public io_file
    public io_position
    public io_table
    public leaf_id
    public leaf_ptr
    public leaf_start
    public lease_group
    public message_ptr
    public mode
    public number
    public number_divisor
    public number_ptr
    public number_text
    public old_group
    public old_page
    public open_table
    public original_attr
    public outptr
    public output_char
    public q
    public remainder
    public remaining
    public saved_cursor
    public saved_tag
    public screen_base
    public src
    public stride
    public text_stride
    public textptr
    public ui_command
    public ui_keys
    public ui_x
    public v_add_poin_1
    public v_block_le_1
    public v_block_of_1
    public v_cache_bu_1
    public v_cache_le_3
    public v_dst_1
    public v_error_te_1
    public v_error_te_2
    public v_file_pos_1
    public v_file_pos_2
    public v_file_pos_3
    public v_file_siz_12
    public v_io_count_1
    public v_io_posit_1
    public v_io_posit_2
    public v_io_posit_3
    public v_io_table_2
    public v_leaf_id_1
    public v_leaf_id_2
    public v_leaf_id_3
    public v_leaf_sta_1
    public v_leaf_sta_2
    public v_leaf_sta_3
    public v_number_1
    public v_number_2
    public v_number_3
    public v_number_t_10
    public v_open_tab_2
    public v_outptr_1
    public v_q_1
    public v_q_2
    public v_q_3
    public v_screen_b_1
    public v_src_1
    public v_wanted_p_2
    public v_wanted_p_3
    public wanted_file
    public wanted_pos
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
mode ds 1
original_attr ds 1
columns ds 1
ui_command ds 1
ui_keys ds 1
saved_cursor ds 1
screen_base ds 2
text_stride ds 1
ui_x ds 1
ink ds 1
gfx_table ds 2
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
cache_count ds 1
cache_hand ds 1
cache_buf ds 2
saved_tag ds 2
cache_tags ds 160
cache_data ds 1536
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
    ends
font_saved_19b7 equ font_saved_group
v_add_poin_1 equ add_pointer+1
v_block_le_1 equ block_left+1
v_block_of_1 equ block_offset+1
v_cache_bu_1 equ cache_buf+1
v_cache_le_3 equ cache_lease+3
v_dst_1 equ dst+1
v_error_te_1 equ error_text+1
v_error_te_2 equ error_text+2
v_file_pos_1 equ file_positions+1
v_file_pos_2 equ file_positions+2
v_file_pos_3 equ file_positions+3
v_file_siz_12 equ file_sizes+12
v_io_count_1 equ io_count+1
v_io_posit_1 equ io_position+1
v_io_posit_2 equ io_position+2
v_io_posit_3 equ io_position+3
v_io_table_2 equ io_table+2
v_leaf_id_1 equ leaf_id+1
v_leaf_id_2 equ leaf_id+2
v_leaf_id_3 equ leaf_id+3
v_leaf_sta_1 equ leaf_start+1
v_leaf_sta_2 equ leaf_start+2
v_leaf_sta_3 equ leaf_start+3
v_number_1 equ number+1
v_number_2 equ number+2
v_number_3 equ number+3
v_number_t_10 equ number_text+10
v_open_tab_2 equ open_table+2
v_outptr_1 equ outptr+1
v_q_1 equ q+1
v_q_2 equ q+2
v_q_3 equ q+3
v_screen_b_1 equ screen_base+1
v_src_1 equ src+1
v_wanted_p_2 equ wanted_pos+2
v_wanted_p_3 equ wanted_pos+3
    end
