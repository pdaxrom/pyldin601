; NCMV3: Uninitialized application state and buffers.
    include NCABI.INC
    include NCBOX.INC
    public action_index
    public action_record
    public cancelled
    public edited_name_ptr
    public edited_retry
    public entries_left
    public error_text
    public existing_target
    public frame
    public full_table
    public group_marked
    public io_buffer
    public io_error
    public io_table
    public mkdir_pref_9e0e
    public open_table
    public operation
    public progress_bytes
    public progress_done
    public progress_items
    public progress_next
    public progress_q_e83a
    public progress_total
    public rename_call
    public rename_source
    public rename_table
    public skipped
    public source_handle
    public source_open
    public stat_entry
    public stat_find
    public stat_table
    public target_handle
    public target_open
    public temp_digits
    public temp_tail
    public temp_tries
    public v_20b2500eb9
    public v_4b58002d3a
    public v_51fd781692
    public v_534cb484b8
    public v_62eaa41089
    public v_7299279710
    public v_993c946a81
    public v_a1fcfeedc2
    public v_a45ec5704b
    public v_c4fc9c08c2
    public v_full_tab_2
    public v_io_table_2
    public v_open_tab_2
    public v_progress_1
    public v_progress_2
    public v_progress_3
    public v_rename_c_2
    public v_rename_t_2
    public v_stat_ent_11
    public v_stat_ent_22
    public v_stat_ent_24
    public v_stat_ent_28
    public v_stat_tab_2
    public v_stat_tab_4
    public v_view_his_4
    public v_view_pos_1
    public v_view_pos_2
    public v_view_pos_3
    public v_walk_tab_2
    public v_walk_tab_4
    public view_eof
    public view_handle
    public view_history
    public view_left
    public view_page
    public view_position
    public view_ptr
    public walk_depth
    public walk_frames
    public walk_table

    section
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
rename_call ds 4
rename_table ds 4
full_table ds 4
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
    ends
mkdir_pref_9e0e equ mkdir_prefix_length
progress_q_e83a equ progress_quantum
v_20b2500eb9 equ progress_items+2
v_4b58002d3a equ progress_next+1
v_51fd781692 equ progress_next+2
v_534cb484b8 equ progress_items+1
v_62eaa41089 equ progress_next+3
v_7299279710 equ progress_done+1
v_993c946a81 equ progress_items+3
v_a1fcfeedc2 equ progress_quantum+2
v_a45ec5704b equ progress_quantum+1
v_c4fc9c08c2 equ progress_quantum+3
v_full_tab_2 equ full_table+2
v_io_table_2 equ io_table+2
v_open_tab_2 equ open_table+2
v_progress_1 equ progress_bytes+1
v_progress_2 equ progress_done+2
v_progress_3 equ progress_done+3
v_rename_c_2 equ rename_call+2
v_rename_t_2 equ rename_table+2
v_stat_ent_11 equ stat_entry+11
v_stat_ent_22 equ stat_entry+22
v_stat_ent_24 equ stat_entry+24
v_stat_ent_28 equ stat_entry+28
v_stat_tab_2 equ stat_table+2
v_stat_tab_4 equ stat_table+4
v_view_his_4 equ view_history+4
v_view_pos_1 equ view_position+1
v_view_pos_2 equ view_position+2
v_view_pos_3 equ view_position+3
v_walk_tab_2 equ walk_table+2
v_walk_tab_4 equ walk_table+4
    end
