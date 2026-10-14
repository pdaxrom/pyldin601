; Explicit resident volume descriptor shared by the native kernel and FATCORE.
; Words/dwords are big endian. FH_IO is the public 7-byte INT EA descriptor:
; buffer BE16, drive U8, volume-relative sector BE32. No hidden high-word ABI.
FH_HEADER equ 0
FH_BITS equ 2
FH_FLAGS equ 3
FH_READONLY equ 4
; Private kernel RAM pointers, fixed by the resident memory layout.
FS_STATE_PTR equ $e5e6
FS_DESCRIPTOR_PTR equ $e5f0
FH_SPC equ 4
FH_NOF equ 5
FH_RESERVED equ 6
FH_SPF equ 8
FH_TOTAL equ 10
FH_ROOT equ 14
FH_COUNT equ 16
FH_DATA equ 18
FH_CACHE equ 22
FH_VALID equ 24
FH_DIRTY equ 25
FH_CLUSTER equ 26
FH_VALUE equ 28
FH_SECTOR equ 30
FH_IO equ 34
FH_TMP equ 41
FH_HINT equ 48
FH_SIZE equ 50
; The FPGA kernel owns the former second built-in FAT buffer at E900.
; A/B share the first FAT buffer; OWNER tracks its descriptor and flushes
; before changing volumes. Extra handle metadata follows each linked cell.
FS_AREA equ $e900
FS_FILES equ $eb13
FS_OWNER equ 8*FH_SIZE
FS_BUFFERS equ FS_OWNER+2
FS_PROBE equ FS_BUFFERS+4
FS_BANK equ FS_PROBE+FH_SIZE
FS_LEASE equ FS_BANK+2
FS_COPY equ 464
FS_FILE_FLAG equ FS_COPY+6
FS_FILE_OWNER equ FS_FILE_FLAG+1
FS_FILE_TARGET equ FS_FILE_FLAG+2
FS_FILE_IO equ FS_FILE_FLAG+3
FS_FILE_END equ FS_FILE_IO+7
FS_BYTES equ FS_FILE_END
; Reclaimed second file-data buffer: five permanent 93-byte SD headers.
FS_HEADER_POOL equ $e205
FS_HEADER_SIZE equ 93
FS_HEADER_SLOTS equ 5
