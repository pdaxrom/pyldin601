    section
bss_start
    ends
; Combined HAM8, transparent clipped sprites and native AY music.
; Assemble with real UniAS and -D GFXMUSIC_DEMO.
    include YMPLAYER.INC
    include DEMOGFX.INC
    include YMDATA.INC
lg_backup ds 8192
bss_end
    ends
    end start
