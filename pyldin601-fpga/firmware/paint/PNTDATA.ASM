; Ordinary state for the shared NC window/font routines. No NC supervisor ABI.
    public mode
    public columns
    public ui_command
    public screen_base
    public text_stride
    public ui_x
    public ink
    public gfx_table
    public font_saved_page
    public outptr
    public stride
    public output_char
    public remaining
    public fill_char
    public textptr
    public src
    public dst
    public add_pointer
    extern input
    public input_end
    public command_caret
    public message_ptr
    public window_title
    public window_text
    public window_inner
    public window_left
    public window_top
    public window_bottom
    public window_focus
    public window_index
    public window_key
    public button_table
    public button_focus
    public button_width
    public edit_length
    public edit_cursor
    public edit_offset
    public edit_index
    extern error_text
    public number
    public number_text
    public number_ptr
    public remainder
    public number_divisor
    public font_saved_19b7
    public v_add_poin_1
    public v_dst_1
    public v_number_1
    public v_number_2
    public v_number_3
    public v_number_t_10
    public v_outptr_1
    public v_screen_b_1
    public v_src_1
    public copy_blocks
    section
mode ds 1
columns ds 1
ui_command ds 1
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
number ds 4
number_text ds 11
number_ptr ds 2
remainder ds 1
number_divisor ds 1
copy_blocks ds 1
    ends
font_saved_19b7 equ font_saved_group
v_add_poin_1 equ add_pointer+1
v_dst_1 equ dst+1
v_number_1 equ number+1
v_number_2 equ number+2
v_number_3 equ number+3
v_number_t_10 equ number_text+10
v_outptr_1 equ outptr+1
v_screen_b_1 equ screen_base+1
v_src_1 equ src+1
    end
