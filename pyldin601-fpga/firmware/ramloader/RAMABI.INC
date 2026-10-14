; ramloader resident ABI 1. All addresses below C000 are native PGM relocations.
RL_INT equ $ec
RL_SLOTS equ 4
RL_EXPORTS equ 8
RL_RECORD equ 144
; Resident record. A bank lease is pinned only after complete validation/init.
R_FLAGS equ 0
R_BUSY equ 1
R_GROUP equ 2
R_PAGE equ 3
R_LEASE equ 4
R_NAME equ 8
R_COUNT equ 16
R_CONTEXT equ 18
R_INIT equ 26
R_GATES equ 36
R_OLD equ 116
G_BYTES equ 10
; Private communication between the small PGM prefix and disposable core.
C_REG equ 0
C_TEMPLATE equ 2
C_GATEWAY equ 4
C_KEEP equ 6
C_FIRST equ 7
C_ERROR equ 8
