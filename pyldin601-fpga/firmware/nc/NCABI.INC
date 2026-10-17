; Private NC/NCMAIN/NCEDIT ABI 3. Offsets, never absolute application addresses.
S_COMMAND equ 226
    .ifndef NC_EDITOR
S_MAGIC equ 0
S_REQUEST equ 2
S_ACTIVE equ 3
S_SORT equ 4
S_HIDDEN equ 5
S_MODE equ 6
S_ATTR equ 7
S_BASE equ 8
S_CURSOR equ 10
S_TOP equ 12
S_ERROR equ 14
S_AUX equ 14
S_PIVOTS equ 16
S_PAGEFLAGS equ 64
S_PATHS equ 66
S_WORKDIR equ 307
S_EDITED equ 387
S_CLIP_PATH equ 401
S_SIZE equ 481
PATH_SIZE equ 80
; Requests: 0 exit, 1 command, 2 shell, 3 reload, 4 text editor,
; 5 execute the prepared command at S_AUX (parent-owned 81-byte buffer).
; Each panel owns a bounded, sorted window, with continuation at its end.
ENTRY_SIZE equ 24
ENTRY_COUNT equ 46
BANK_COUNT equ 160
E_ATTR equ 11
E_MARK equ 12
E_SIZE equ 14
E_DATE equ 18
E_TIME equ 20
; Text uses the extra row above the BIOS clock. Graphics retains 25 rows.
UI_FIRST equ 3
BASE_UI_ROWS equ 17
BASE_UI_END equ 20
BASE_UI_INFO equ 21
BASE_UI_BOTTOM equ 23
BASE_UI_COMMAND equ 24
BASE_UI_KEYS equ 25
    .endif
