    .ifdef PNT_TOOLS
    .define PNT_EDIT
    .endif
    public title
    public help_text
    public confirm_title
    public ok_button
    public ok_cancel__0523
    public yes_no_buttons
    public p_save_title
    public p_open_title
    public p_colour_title
    public p_format_title
    public p_tool_title
    public p_exit_question
    public p_new_question
    public p_replace_ask
    public p_need_hardware
    public p_memory_error
    public p_format_list
    public p_tool_list
    public p_bad_format
    public p_no_memory
    public p_need_loader
    public p_view_title
    public p_view_help
title db ' Paint',0
p_view_title db ' Image viewer',0
p_view_help db 'F3 Open Z zoom G grid IJKL pan F9 Menu Esc/F10 Exit. '
    db 'Read only.',0
confirm_title db 'Paint',0
ok_button db '[ OK ]',0
cancel_button db '[ Cancel ]',0
yes_button db '[ Yes ]',0
no_button db '[ No ]',0
ok_cancel__0523 dw ok_button,cancel_button
yes_no_buttons dw yes_button,no_button
help_text db 'L draw R erase M pick. F2 Save 3 Open 4 Colour 5 Tool '
    db '6 New 7 Undo 8 Redo 9 Menu 10 Exit. +/- size. '
    .ifdef PNT_EDIT
    db 'Z zoom G grid IJKL pan S select ^C/X/V. '
    .endif
    .ifdef PNT_FILES
    db 'Z zoom G grid IJKL pan S select ^C/X/V. '
    .endif
    db 'Esc cancels tools.',0
p_save_title db 'Save image',0
p_open_title db 'Open PCX / HAM8 IFF',0
p_colour_title db 'Colour',0
p_format_title db 'New image format',0
p_tool_title db 'Drawing tool',0
p_exit_question db 'Discard changes and exit?',0
p_new_question db 'Discard changes?',0
p_replace_ask db 'Replace image?',0
p_need_hardware db 10,'Paint needs FPGA graphics v6 and flat DMA.',10,0
p_memory_error db 10,'Paint: low memory.',10,0
p_bad_format db 'Invalid image or backend.',0
p_no_memory db 'Not enough ordinary memory.',0
p_need_loader db 10,'Run PAINT.PGM.',10,0
p_format_list dw format_mono320,format_mono640,format_four,format_indexed,format_ham
format_mono320 db '1  320x200 mono',0
format_mono640 db '2  640x200 mono (601A)',0
format_four db '3  320x200 four colours',0
format_indexed db '4  320x200 256 colours',0
format_ham db '5  320x200 HAM8 RGB666',0
p_tool_list dw tool_brush,tool_line,tool_rect,tool_fill,tool_pick
    dw tool_select,tool_flood,tool_ellipse,tool_solid
tool_brush db '1  Freehand brush',0
tool_line db '2  Line',0
tool_rect db '3  Rectangle',0
tool_fill db '4  Filled rectangle',0
tool_pick db '5  Pick colour',0
tool_select db '6  Select rectangle',0
tool_flood db '7  Flood fill',0
tool_ellipse db '8  Ellipse/circle',0
tool_solid db '9  Filled ellipse',0
    end
