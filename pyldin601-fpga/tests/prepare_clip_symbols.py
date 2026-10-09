"""Read UniAS symbols from the actual CLIPSPR listing for the native test."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
listing = (root/'build/gfx/CLIPSPR.LST').read_text()
names = ['GFX_CLIP', 'CLIP_X', 'CLIP_Y', 'CLIP_SRC', 'CLIP_WIDTH', 'CLIP_HEIGHT',
         'CLIP_SOURCE', 'CLIP_DESTINATION', 'CLIP_DRAW_WIDTH', 'CLIP_DRAW_HEIGHT']
text = []
for name in names:
    match = re.search(rf'^{name} =\$([0-9A-F]+)$', listing, re.M)
    assert match, name
    text.append(f'#define {name} 0x{int(match[1], 16)+0x2000:04x}\n')
work = root/'build/clip-sprites'
work.mkdir(parents=True, exist_ok=True)
(work/'clip_symbols.h').write_text(''.join(text))
