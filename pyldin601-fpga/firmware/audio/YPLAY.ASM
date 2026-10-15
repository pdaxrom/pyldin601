    section
bss_start
    ends
; Native HD6303 AY player. Common code/data are also used by GFXMUSIC.
    include YMPLAYER.INC
    include YMDATA.INC
bss_end
    ends
    end start
