; NCEV2: Uninitialized application state and buffers.
    .define NC_EDITOR
    include NCABI.INC
    include NCBOX.INC
    public add_tail
    public append_char
    public apply_cursor
    public apply_error
    public apply_inse_8b0f
    public apply_inse_9b8b
    public apply_left
    public apply_phase
    public apply_pos
    public body_rows
    public change_add
    public change_at
    public change_bytes
    public change_delete
    public change_group
    public change_index
    public dir_entry
    public disk_buffer
    public doc_size
    public e_column
    public e_cursor
    public entry_base
    public entry_ptr
    public eol_bytes
    public eol_length
    public filename
    public find_state
    public find_table
    public group_open
    public history_count
    public history_cursor
    public history_mode
    public history_po_08d6
    public history_target
    public horizontal
    public index_end
    public insert_len
    public insert_off
    public insert_ptr
    public leaf_slot
    public line_ends
    public line_left
    public line_left__56a0
    public line_offsets
    public line_valid
    public modified
    public new_handle
    public new_line
    public next_leaf
    public opened
    public piece_in
    public piece_index
    public prefix_ptr
    public remove_left
    public remove_len
    public remove_take
    public saved_history
    public saved_valid
    public screen_chars
    public screen_top
    public search_pre_0813
    public shift_end
    public split_bytes
    public split_count
    public split_index
    public split_next
    public split_ptr
    public split_total
    public stream_char
    public stream_file
    public stream_left
    public stream_physical
    public stream_ptr
    public stream_rem_2015
    public suffix_len
    public v_add_tail_2
    public v_add_tail_3
    public v_change_b_1
    public v_dir_entr_11
    public v_e_column_1
    public v_e_column_2
    public v_e_column_3
    public v_e_cursor_1
    public v_e_cursor_2
    public v_e_cursor_3
    public v_entry_ba_1
    public v_eol_byte_1
    public v_find_tab_2
    public v_find_tab_4
    public v_horizont_1
    public v_horizont_2
    public v_horizont_3
    public v_screen_t_1
    public v_screen_t_2
    public v_screen_t_3
    public v_split_by_1
    public v_split_to_1
    public v_split_to_2
    public v_split_to_3
    public v_stream_l_1
    public v_where_1
    public v_where_2
    public v_where_3
    public where
    public work_attempt
    public work_created
    public work_error
    public work_kind
    public work_path
    public work_ready
    public work_tail

    section
leaf_slot ds 1
entry_base ds 2
next_leaf ds 4
piece_in ds 4
piece_index ds 1
entry_ptr ds 2
shift_end ds 2
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
screen_chars ds 2
new_line ds 80
line_offsets ds 100
line_ends ds 96
line_left ds 96
line_left_column ds 96
line_valid ds 24
horizontal ds 4
screen_top ds 4
e_column ds 4
search_prefix_table equ new_line
    ends
apply_inse_8b0f equ apply_insert_len
apply_inse_9b8b equ apply_insert_off
history_po_08d6 equ history_position
line_left__56a0 equ line_left_column
search_pre_0813 equ search_prefix_table
stream_rem_2015 equ stream_remaining
v_add_tail_2 equ add_tail+2
v_add_tail_3 equ add_tail+3
v_change_b_1 equ change_bytes+1
v_dir_entr_11 equ dir_entry+11
v_e_column_1 equ e_column+1
v_e_column_2 equ e_column+2
v_e_column_3 equ e_column+3
v_e_cursor_1 equ e_cursor+1
v_e_cursor_2 equ e_cursor+2
v_e_cursor_3 equ e_cursor+3
v_entry_ba_1 equ entry_base+1
v_eol_byte_1 equ eol_bytes+1
v_find_tab_2 equ find_table+2
v_find_tab_4 equ find_table+4
v_horizont_1 equ horizontal+1
v_horizont_2 equ horizontal+2
v_horizont_3 equ horizontal+3
v_screen_t_1 equ screen_top+1
v_screen_t_2 equ screen_top+2
v_screen_t_3 equ screen_top+3
v_split_by_1 equ split_bytes+1
v_split_to_1 equ split_total+1
v_split_to_2 equ split_total+2
v_split_to_3 equ split_total+3
v_stream_l_1 equ stream_left+1
v_where_1 equ where+1
v_where_2 equ where+2
v_where_3 equ where+3
    end
