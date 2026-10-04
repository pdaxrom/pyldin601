#!/usr/bin/env python3
"""Build the resident HD6303 BIOS: F000 API plus boot-only D000 setup ROM."""
import argparse
import json
from pathlib import Path

from asm6800 import assemble


def build():
    root = Path(__file__).resolve().parents[1]
    source = '\n'.join((root / 'firmware' / name).read_text()
                       for name in ('boot.asm', 'setup.asm'))
    binary, labels = assemble(source, 0xd000, 0x3000, hd6303=True)
    if labels['setup_end'] > 0xe000 or binary[4096:8192] != b'\xff' * 4096:
        raise ValueError('setup ROM must fit D000-DFFF; E000-EFFF remains RAM/I/O')
    return binary[8192:] + binary[:4096], labels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('build/boot.bin'))
    parser.add_argument('--mem', type=Path, default=Path('build/boot.mem'))
    parser.add_argument('--labels', type=Path, default=Path('build/boot-labels.json'))
    args = parser.parse_args()
    binary, labels = build()
    args.output.write_bytes(binary)
    args.mem.write_text(''.join(f'{byte:02x}\n' for byte in binary))
    args.labels.write_text(json.dumps(labels, indent=2, sort_keys=True) + '\n')
    print(f'Resident BIOS: {len(binary)} bytes; setup uses {labels["setup_end"] - 0xd000} bytes')


if __name__ == '__main__':
    main()
