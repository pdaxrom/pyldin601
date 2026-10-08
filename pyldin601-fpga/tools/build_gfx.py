"""Build the relocatable MC6800 graphics demo with UniAS."""
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
for name in ('GFX.ASM', 'GFXHOWTO.TXT'):
    data = (root/'firmware/gfx'/name).read_bytes()
    (output/name).write_bytes(data if name.endswith('.ASM') else data.replace(b'\n', b'\r\n'))
assembler = shutil.which(args.unias) or str(Path(args.unias).resolve())
p = subprocess.run([assembler, '-l', 'GFX.LST', '-o', 'GFX_NEW.PGM', 'GFX.ASM'],
                   cwd=output, capture_output=True, text=True)
(output/'GFX.log').write_text(p.stdout+p.stderr)
if p.returncode or 'Error:' in p.stdout:
    raise RuntimeError(p.stdout+p.stderr)
data = (output/'GFX_NEW.PGM').read_bytes()
magic, count, offset, length, entry, bss, _, _ = struct.unpack('>8H', data[:16])
assert magic == 0xa55a and offset == 16+2*count and len(data) == offset+length
assert entry < length and count > 0 and all(n+1 < length for n in struct.unpack(f'>{count}H', data[16:offset]))
(output/'GFX_NEW.PGM').replace(output/'GFX.PGM')
print(f'GFX.PGM: {length} code/data bytes, {count} relocations, {len(data)} file bytes')
