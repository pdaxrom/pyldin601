; NCESTR: Initialized editor strings and tables.
    .define NC_EDITOR
    include NCABI.INC
    include NCBOX.INC
    public block_label
    public cancel_sav_fb1e
    public confirm_title
    public const32
    public editor_key_002a
    public editor_key_4267
    public exit_butto_56b1
    public exit_message
    public exit_title
    public help_text
    public insert_label
    public not_found_text
    public ok_button
    public ok_cancel__0523
    public overwrite_label
    public overwrite_text
    public retry_text
    public retry_title
    public save_as_title
    public save_name
    public saving_title
    public search_title
    public standalone_cbac
    public title
    public total_label
    public work_extensions
    public work_name
    public written_label
    public yes_no_buttons

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
cancel_sav_fb1e equ cancel_save_text
editor_key_002a equ editor_keys_short
editor_key_4267 equ editor_keys_long
exit_butto_56b1 equ exit_button_table
ok_cancel__0523 equ ok_cancel_buttons
standalone_cbac equ standalone_message
    end
