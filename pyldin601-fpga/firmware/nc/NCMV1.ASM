; NCMV1: Uninitialized application state and buffers.
    include NCABI.INC
    include NCBOX.INC
    public active
    public add_pointer
    public bank_valid
    public cache_group
    public cache_leas_2b52
    public cache_lease
    public cache_old_group
    public cache_old_page
    public cache_owner
    public cache_valid
    public cacheptr
    public candidate
    public columns
    public command_caret
    public command_length
    public command_line
    public copy_blocks
    public counts
    public cursor_byte
    public cursor_cells
    public cursor_marker
    public cursor_selected
    public cursors
    public delta
    public dir_entry
    public directory_error
    public drive_choice
    public drive_current
    public drive_list
    public drive_original
    public drive_scan
    public drive_target
    public dst
    public entry_capacity
    public find_state
    public find_table
    public had_overflow
    public has_next
    public has_previous
    public input
    public input_end
    public insert_high
    public insert_index
    public insert_mid
    public last_key
    public mark_count
    public mark_index
    public mark_value
    public marks_left
    public marks_ptr
    public marks_right
    public mode
    public next_cursor
    public next_top
    public original_attr
    public page_request
    public paging_dir_e8bd
    public panel
    public panel_width
    public pathptr
    public pcount
    public pcur
    public pivotptr
    public previous_cursor
    public previous_top
    public ptop
    public ptr
    public rename_target
    public request
    public requested_panel
    public saved_cursor
    public screen_base
    public scroll_count
    public scroll_dir_9732
    public scroll_row
    public scroll_source
    public scroll_tail
    public scroll_target
    public search_path
    public shift_index
    public source_path
    public src
    public textptr
    public tops
    public ui_bottom
    public ui_command
    public ui_end
    public ui_info
    public ui_keys
    public ui_rows
    public v_add_poin_1
    public v_bank_val_1
    public v_cache_le_3
    public v_cacheptr_1
    public v_candida_af21
    public v_candida_c0ff
    public v_candida_cb55
    public v_candidat_12
    public v_cursors_1
    public v_dir_entr_22
    public v_dir_entr_24
    public v_dir_entr_28
    public v_dst_1
    public v_find_tab_2
    public v_find_tab_4
    public v_marks_r_97b9
    public v_ptr_1
    public v_screen_b_1
    public v_src_1
    public v_tops_1

    section
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
rename_target equ search_path
    ends
cache_leas_2b52 equ cache_lease_open
paging_dir_e8bd equ paging_direction
scroll_dir_9732 equ scroll_direction
v_add_poin_1 equ add_pointer+1
v_bank_val_1 equ bank_valid+1
v_cache_le_3 equ cache_lease+3
v_cacheptr_1 equ cacheptr+1
v_candida_af21 equ candidate+E_SIZE
v_candida_c0ff equ candidate+E_DATE
v_candida_cb55 equ candidate+E_TIME
v_candidat_12 equ candidate+12
v_cursors_1 equ cursors+1
v_dir_entr_22 equ dir_entry+22
v_dir_entr_24 equ dir_entry+24
v_dir_entr_28 equ dir_entry+28
v_dst_1 equ dst+1
v_find_tab_2 equ find_table+2
v_find_tab_4 equ find_table+4
v_marks_r_97b9 equ marks_right+BANK_COUNT
v_ptr_1 equ ptr+1
v_screen_b_1 equ screen_base+1
v_src_1 equ src+1
v_tops_1 equ tops+1
    end
