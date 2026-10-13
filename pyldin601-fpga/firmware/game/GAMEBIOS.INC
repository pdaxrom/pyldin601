; Public GAMEBIOS ABI 2. All words big endian; functions selected in A.
; B and X preserved except INFO (A=2, B=features, X=context bytes),
; READPIX (B=pixel), STATUS (B=queued, X=ticks). A=0 successful operation.
GB_INT equ $e6
GB_ABI equ 2
GB_CONTEXT_BYTES equ 416
GB_VIDEO equ 1
GB_AUDIO equ 2
GB_INFO equ 0
GB_OPEN equ 1
GB_CLOSE equ 2
GB_MODE equ 3
GB_TARGET equ 4
GB_FLIP equ 5
GB_PALETTE equ 6
GB_PIXEL equ 7
GB_READPIX equ 8
GB_RECT equ 9
GB_LINE equ 10
GB_COPY equ 11
GB_SPRITE equ 12
GB_PUTC equ 13
GB_PUTS equ 14
GB_CURSOR equ 15
GB_ATTR equ 16
GB_WINDOW equ 17
GB_SCROLL equ 18
GB_CLEAR equ 19
GB_NOTE equ 20
GB_FRAME equ 21
GB_RATE equ 22
GB_PLAY equ 23
GB_STOP equ 24
GB_AYREG equ 25
GB_RESERVE equ 26
GB_STATUS equ 27
GB_CLOCK equ 28
GB_RAWPIX equ 29
GB_BATCH equ 30
GB_FEATURE_BATCH equ 32
GB_OK equ 0
GB_ARGUMENT equ 1
GB_HARDWARE equ 2
GB_NEED_HD6303 equ 3
GB_UNAVAILABLE equ 4
GB_BUSY equ 5
GB_OWNER equ 6
GB_FULL equ 7
GB_UNSUPPORTED equ 8
; Independent PS/2 raw FIFO: E6B0='R', status, read/pop DATA, count/control.
GB_PS2_IDENT equ $e6b0
GB_PS2_STATUS equ $e6b1
GB_PS2_DATA equ $e6b2
GB_PS2_CONTROL equ $e6b3
GB_PS2_AVAILABLE equ 1
GB_PS2_FULL equ $20
GB_PS2_CAPTURED equ $40
GB_PS2_OVERFLOW equ $80
GB_PS2_FLUSH equ 1
GB_PS2_CLEAR equ 2
GB_PS2_CAPTURE equ 4
GB_PS2_RELEASE equ 8
GB_PS2_CAPACITY equ 64
GB_KEY_LEFT equ 1
GB_KEY_RIGHT equ 2
GB_KEY_UP equ 4
GB_KEY_DOWN equ 8
GB_KEY_SPACE equ 16
GB_KEY_ESC equ 32
GB_KEY_CTRL equ 64
GB_KEY_SHIFT equ 128
; OPEN X: sizeBE (416), ABI (2), flags (VIDEO|AUDIO), 28 private bytes,
;         384-byte private state. Caller owns this RAM until CLOSE/INT38.
; VIDEO leases one 8192-byte palette bank through RAMMAN; AUDIO alone none.
; Header 4..7: RAMMAN descriptor; 8: valid palette backup.
; PALETTE X: index,R,G,B. PIXEL/RAWPIX X: xBE,yBE,value. READPIX: xBE,yBE.
; RECT X: xBE,yBE,widthBE,height,value; signed x/y, width 1..320,h 1..200.
; LINE X: x0BE,y0BE,x1BE,y1BE,value. Endpoints within -320..639,-200..399.
; COPY X: INT E0 blit descriptor (11 bytes). SPRITE: E0 clip descriptor (12).
; PUTC B=character; PUTS X=NUL string. CURSOR X: column,row (0-based).
; ATTR X: foreground,background. WINDOW X: left,top,width,height (chars).
; SCROLL B=lines up (1..window height); CLEAR clears text window.
; NOTE X: channel(0..2),note(0=rest,1=C1..72=B6),ticksBE(0=sustain),volume.
; NOTE note=0,ticks=0 releases effect; notes reserve channel temporarily.
; FRAME X: 14 AY bytes, R13=FF means no envelope retrigger, queue 16 frames.
; RATE X: timer ticks BE32 at 24MHz, 240000..24000000 (100..1Hz), paused only.
; PLAY B=0 pause,1 resume; STOP flushes frames/notes and silences AY.
; AYREG X: register(0..13),value; allowed only while frame stream is stopped.
; RESERVE B=channel bitmask 0..7; reserved channels emit NOTE or silence.
; CLOCK B=0 2MHz,1 1MHz,2 1773400Hz,3 1789773Hz, paused only.
; MODE B=0 native,1 indexed,7 HAM8; HAM8 initializes component tables.
; Indexed primitives/text reject HAM8; RAWPIX and COPY accept encoded bytes.
; BATCH B=count (0..32), X=list of operation,B,pointerBE (4 bytes each).
; Allowed: TARGET,PIXEL,RECT,LINE,COPY,SPRITE,PUTC,PUTS,CURSOR,ATTR,WINDOW,
; SCROLL,CLEAR,RAWPIX. Stops on first error; prior operations remain applied.
; INFO feature bit 5 announces BATCH. Old ABI1 contexts are not accepted.
