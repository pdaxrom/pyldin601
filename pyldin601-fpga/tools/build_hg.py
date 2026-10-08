#!/usr/bin/env python3
"""Build relocatable MC6800 HG.PGM and HGTIME.PGM with UniAS."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def build(unias, output):
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # UniAS has short internal pathname buffers; use local names in its cwd.
    source = ROOT / 'firmware/hg/HG.ASM'
    (output / 'HG.ASM').write_bytes(source.read_bytes())
    (output / 'HGHOWTO.TXT').write_bytes((source.parent/'HGHOWTO.TXT').read_bytes().replace(b'\n', b'\r\n'))
    programs = {}
    for name, defines in [('HG', []), ('HGTIME', ['-D', 'TIME_ONLY'])]:
        p = subprocess.run([unias, *defines, '-l', name + '.LST', '-o', name + '_NEW.PGM', 'HG.ASM'],
                           cwd=output, capture_output=True, text=True)
        (output / (name + '.log')).write_text(p.stdout + p.stderr)
        if p.returncode or 'Error:' in p.stdout:
            raise RuntimeError('\n'.join(line for line in (p.stdout+p.stderr).splitlines() if 'Error' in line or 'Line ' in line or 'unias:' in line))
        data = (output / (name + '_NEW.PGM')).read_bytes()
        magic, items, offset, length, entry, bss, _, _ = struct.unpack('>8H', data[:16])
        assert magic == 0xa55a and offset == 16 + items * 2
        assert len(data) == offset + length and entry < length and items > 0
        relocs = struct.unpack(f'>{items}H', data[16:offset])
        assert all(n + 1 < length for n in relocs)
        (output / (name + '_NEW.PGM')).replace(output / (name + '.PGM'))
        programs[name + '.PGM'] = dict(bytes=len(data), code_bytes=length,
            relocation_items=items, entry=entry, bss=bss, sha256=hashlib.sha256(data).hexdigest())
        print(f'{name}.PGM: {length} code/data bytes, {items} relocations')
    (output / 'manifest.json').write_text(json.dumps(dict(cpu='MC6800',
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), programs=programs), indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unias', required=True)
    parser.add_argument('--output', type=Path, default=ROOT/'build/hg')
    args = parser.parse_args()
    build(str(Path(args.unias).resolve()), args.output)
