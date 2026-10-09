"""Build the relocatable graphics demo and native HD6303 PCX viewer with UniAS."""
import argparse
from pathlib import Path
import struct
import subprocess
import shutil

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--unias', required=True)
args = parser.parse_args()
output = root/'build/gfx'
output.mkdir(parents=True, exist_ok=True)
for name in ('GFX.ASM', 'GFXHOWTO.TXT', 'VIEW.ASM', 'VIEWHOW.TXT', 'PALCOEF.ASM',
             'SPRITES.ASM', 'SPRHOWTO.TXT', 'HAM.ASM', 'HAMHOWTO.TXT', 'HVIEW.ASM', 'HVIEWHOW.TXT',
             'GFXCLIP.ASM', 'CLIPSPR.ASM', 'CLIPHOW.TXT'):
    data = (root/'firmware/gfx'/name).read_bytes()
    (output/name).write_bytes(data if name.endswith('.ASM') else data.replace(b'\n', b'\r\n'))
assembler = shutil.which(args.unias) or str(Path(args.unias).resolve())
for name in ('AY.ASM', 'AYHOWTO.TXT'):
    data = (root/'firmware/audio'/name).read_bytes()
    (output/name).write_bytes(data if name.endswith('.ASM') else data.replace(b'\n', b'\r\n'))
for app in ('GFX', 'VIEW', 'SPRITES', 'HAM', 'CLIPSPR', 'AY', 'HVIEW'):
    p = subprocess.run([assembler, '-l', f'{app}.LST', '-o', f'{app}_NEW.PGM', f'{app}.ASM'],
                       cwd=output, capture_output=True, text=True)
    (output/f'{app}.log').write_text(p.stdout+p.stderr)
    if p.returncode or 'Error:' in p.stdout:
        raise RuntimeError(p.stdout+p.stderr)
    data = (output/f'{app}_NEW.PGM').read_bytes()
    magic, count, offset, length, entry, bss, _, _ = struct.unpack('>8H', data[:16])
    if app in ('VIEW', 'HAM', 'HVIEW'):
        # UniAS emits DS as initialized zeros. The final palette backup is
        # scratch RAM: expose it as PGM BSS so DOS reserves it without disk I/O.
        assert bss == 0 and data[-8192:] == bytes(8192)
        length -= 8192
        bss = 8192
        data = struct.pack('>8H', magic, count, offset, length, entry, bss, 0, 0) + data[16:-8192]
        (output/f'{app}_NEW.PGM').write_bytes(data)
    assert magic == 0xa55a and offset == 16+2*count and len(data) == offset+length
    assert entry < length and count > 0 and all(n+1 < length for n in struct.unpack(f'>{count}H', data[16:offset]))
    (output/f'{app}_NEW.PGM').replace(output/f'{app}.PGM')
    print(f'{app}.PGM: {length} code/data bytes, {bss} BSS bytes, {count} relocations, {len(data)} file bytes')
