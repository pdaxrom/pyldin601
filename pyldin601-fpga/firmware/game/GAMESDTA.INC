; Private SDK storage; place at the end of the application's BSS.
sdk_flags ds 1
sdk_blit ds 11
sdk_tile_id ds 1
sdk_tile_x ds 1
sdk_offset ds 2
sdk_map_ptr ds 2
sdk_map_x ds 1
sdk_map_y ds 1
sdk_tile_desc ds 5
sdk_direction ds 1
sdk_edge ds 12
sdk_prefix ds 1
sdk_pause ds 1
sdk_held ds 1
sdk_pressed ds 1
sdk_limit ds 1
sdk_key_mask ds 1
sdk_keys ds 14
    .ifdef GAME_MUSIC
; Load-time LH5 scratch overlaps the later 8608-byte GAMEBIOS context.
; Real labels (not EQU aliases) are required for UniAS PGM relocation.
sdk_context
mus_dictionary ds 8192
mus_c_lengths ds 510
mus_pt_lengths ds 19
mus_c_tree ds 1126
mus_pt_tree ds 144
mus_next_symbol ds 34
    .else
sdk_context ds GB_CONTEXT_BYTES
    .endif
