; NCMSTR: Initialized panel strings and tables.
    include NCABI.INC
    include NCBOX.INC
    public apply_canc_22f2
    public attribute_names
    public cancel_button
    public command_actions
    public command_prompt
    public confirm_title
    public copy_prompt
    public date_heading
    public delete_prompt
    public dir_text
    public drive_buttons
    public drive_prompt
    public file_actions
    public free_suffix
    public free_unknown
    public help_text
    public keys_long
    public keys_short
    public marks_page_text
    public menu_counts
    public menu_lists
    public mkdir_prompt
    public move_prompt
    public name_heading
    public no_drives_text
    public ok_button
    public ok_cancel__0523
    public overwrite__e43c
    public progress_from
    public progress_i_c232
    public progress_slash
    public progress_titles
    public progress_to
    public settings_rows
    public settings_title
    public size_heading
    public sort_keys
    public standalone_cbac
    public temp_name
    public title
    public top_names
    public up_text
    public viewer_keys
    public wildcard
    public workdir_default
    public workdir_label
    public workdir_title
    public yes_no_buttons
    extern make_directory
    extern menu_command
    extern menu_copy
    extern menu_delete
    extern menu_editor
    extern menu_move
    extern menu_quit
    extern refresh
    extern settings
    extern shell_request
    extern viewer

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
apply_canc_22f2 equ apply_cancel_buttons
ok_cancel__0523 equ ok_cancel_buttons
overwrite__e43c equ overwrite_prompt
progress_i_c232 equ progress_item_label
standalone_cbac equ standalone_message
    end
