#!/usr/bin/env python3
"""Build the HD6303 music player with real UniAS; no opcode generation."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
from build_partitions import assemble

ROOT = Path(__file__).resolve().parents[1]


def build(unias):
    unias = shutil.which(unias) or str(Path(unias).resolve())
    out = ROOT / 'build/audio'
    out.mkdir(parents=True, exist_ok=True)
    for path in (ROOT / 'firmware/audio').glob('*'):
        if path.is_file():
            shutil.copyfile(path, out / path.name)
    data = assemble(unias, out, 'YPLAY.ASM', 'YPLAY.PGM')
    demo = assemble(unias, out, 'DEMO.ASM', 'DEMO.YM')
    assert demo[:4] == b'YM3!' and len(demo) == 4 + 375 * 14
    fields = list(struct.unpack('>8H', data[:16]))
    magic, count, offset, length, entry, bss, _, _ = fields
    symbols = dict(re.findall(r'^([A-Z_][A-Z0-9_]*) =\$([0-9A-F]+)$',
                             (out / 'YPLAY.PGM.LST').read_text(), re.M))
    scratch = int(symbols['BSS_END'], 16) - int(symbols['BSS_START'], 16)
    assert bss == 0 and data[-scratch:] == bytes(scratch)
    fields[3] -= scratch
    fields[5] = scratch
    data = struct.pack('>8H', *fields) + data[16:-scratch]
    assert magic == 0xa55a and offset == 16 + 2 * count
    assert len(data) == offset + fields[3] and entry < fields[3]
    assert all(n + 1 < fields[3] for n in struct.unpack(f'>{count}H', data[16:offset]))
    (out / 'YPLAY.PGM').write_bytes(data)
    metadata = dict(bytes=len(data), code=fields[3], bss=fields[5], ram_bytes=fields[3]+fields[5], relocations=count,
                    sha256=hashlib.sha256(data).hexdigest())
    (out / 'manifest.json').write_text(json.dumps(metadata, indent=2) + '\n')
    (out / 'yplay_labels.h').write_text(''.join(
        f'#define YP_{name} 0x{symbols[name]}\n'
        for name in ('IRQ_PLAYER', 'PAUSED', 'STOPPED', 'SAVED_GROUP', 'SAVED_PAGE', 'RETURN_TO_DOS', 'OLD_TIMER', 'QUEUE_FILL', 'UNDERRUNS', 'WRITE_FRAME', 'FRAME_SENT', 'IRQ_RETURN')))
    print(metadata)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unias', required=True)
    build(parser.parse_args().unias)
