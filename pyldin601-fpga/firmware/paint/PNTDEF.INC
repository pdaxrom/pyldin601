; Core canvas layout in the separate, application-owned graphics SRAM.
; Document and Undo bases swap; both reserve three 64K pages for RGB666 HAM8.
P_MEM_DOC equ $12
P_MEM_UNDO equ $16
P_LOAD_PAGE equ $19
P_STAGE_PAGE equ $1c
P_PICKER_PAGE equ $15
P_MEM_ORIGINAL equ $1d
P_DIALOG_PAGE equ $1e
P_PALETTE_PAGE equ $1f
P_HEIGHT equ 200
P_PALETTE_BYTES equ 768
P_NUM_EVENTS equ 16
P_TOOL_BRUSH equ 0
P_TOOL_LINE equ 1
P_TOOL_RECT equ 2
P_TOOL_FILLED equ 3
P_TOOL_PICK equ 4
P_TOOL_SELECT equ 5
P_TOOL_FLOOD equ 6
P_TOOL_ELLIPSE equ 7
P_TOOL_SOLID equ 8
