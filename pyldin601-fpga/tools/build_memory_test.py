#!/usr/bin/env python3
"""Assemble the on-machine paged RAM diagnostic with the real UniAS."""
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
    out = ROOT / 'build/memory-test'
    out.mkdir(parents=True, exist_ok=True)
    for name in ('RAMPAGE.ASM', 'RAMHOW.TXT'):
        shutil.copyfile(ROOT / 'firmware/memory' / name, out / name)
    data = assemble(unias, out, 'RAMPAGE.ASM', 'RAMPAGE.PGM')
    allocated = assemble(unias, out, 'RAMPAGE.ASM', 'RAMALLOC.PGM', ('-D', 'ALLOCATED_TEST'))
    (out / 'ramalloc.json').write_text(json.dumps(dict(bytes=len(allocated), sha256=hashlib.sha256(allocated).hexdigest(), pages=8, kib=64), indent=2)+'\n')
    magic, count, offset, length, entry, bss, _, _ = struct.unpack('>8H', data[:16])
    if magic != 0xa55a or offset != 16 + 2 * count or len(data) != offset + length or entry >= length:
        raise ValueError('invalid relocatable RAMPAGE PGM')
    if any(p + 1 >= length for p in struct.unpack(f'>{count}H', data[16:offset])):
        raise ValueError('RAMPAGE relocation outside program')
    metadata = dict(bytes=len(data), code=length, relocations=count,
                    sha256=hashlib.sha256(data).hexdigest(), pages=111, kib=888)
    (out / 'manifest.json').write_text(json.dumps(metadata, indent=2) + '\n')
    symbols = dict(re.findall(r'^([A-Z_][A-Z0-9_]*) =\$([0-9A-F]+)$',
                             (out / 'RAMPAGE.PGM.LST').read_text(), re.M))
    (out / 'rampage_labels.h').write_text(''.join(
        f'#define RP_{name} 0x{symbols[name]}\n'
        for name in ('IRQ_PROBE', 'PHASE', 'BANK', 'SAVED_GROUP', 'SAVED_PAGE', 'RETURN_TO_DOS')))
    print(metadata)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unias', required=True)
    build(parser.parse_args().unias)
