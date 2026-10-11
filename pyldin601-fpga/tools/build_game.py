#!/usr/bin/env python3
"""Assemble GAMEBIOS SDK applications with UniAS and package their BSS."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
from build_partitions import assemble, data_source
ROOT = Path(__file__).resolve().parents[1]

def build(unias):
    unias = shutil.which(unias) or str(Path(unias).resolve())
    out = ROOT / 'build/game'
    out.mkdir(parents=True, exist_ok=True)
    for path in (ROOT / 'firmware/game').glob('*'):
        if path.is_file():
            shutil.copyfile(path, out / path.name)
    # Small original eight-note example, already prepared register frames.
    # File decoders can enqueue frames through the same GB_FRAME interface.
    melody = (478, 379, 319, 284, 319, 379, 426, 478)
    frames = bytearray()
    for tone in melody:
        for _ in range(8):
            frames += bytes((tone & 255, tone >> 8, 188, 3, 0, 0,
                             0, 0x3c, 5, 3, 0, 0, 0, 255))
    (out / 'ARKSONG.INC').write_text(data_source(frames))
    (out / 'SDKWORLD.INC').write_text(data_source(bytes(range(64))))
    result = {}
    for name in ('ARKANOID', 'SDKTEST'):
        data = assemble(unias, out, name + '.ASM', name + '.PGM')
        fields = list(struct.unpack('>8H', data[:16]))
        symbols = dict(re.findall(r'^([A-Z_][A-Z0-9_]*) =\$([0-9A-F]+)$',
                                 (out / (name + '.PGM.LST')).read_text(), re.M))
        scratch = int(symbols['BSS_END'], 16) - int(symbols['BSS_START'], 16)
        assert fields[5] == 0 and data[-scratch:] == bytes(scratch)
        fields[3] -= scratch
        fields[5] = scratch
        data = struct.pack('>8H', *fields) + data[16:-scratch]
        assert fields[0] == 0xa55a and fields[2] == 16 + 2 * fields[1]
        assert len(data) == fields[2] + fields[3] and fields[4] < fields[3]
        assert all(n + 1 < fields[3] for n in struct.unpack(f'>{fields[1]}H', data[16:fields[2]]))
        (out / (name + '.PGM')).write_bytes(data)
        (out / (name.lower() + '_labels.h')).write_text(''.join(
            f'#define {"GAME" if name == "ARKANOID" else "SDK"}_{symbol} 0x{value}\n' for symbol, value in symbols.items()))
        result[name] = dict(bytes=len(data), code=fields[3], bss=scratch,
                            ram_bytes=fields[3]+scratch, relocations=fields[1],
                            sha256=hashlib.sha256(data).hexdigest())
    (out / 'manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    return result

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--unias', required=True)
    build(p.parse_args().unias)
