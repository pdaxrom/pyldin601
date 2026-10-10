#!/usr/bin/env python3
"""Build the resident HD6303 BIOS: F000 API plus boot-only D000 setup ROM."""
import argparse
import json
from pathlib import Path

from unias_boot import build as unias_build


def build():
    binary, labels = unias_build()
    if len(binary) != 8192 or labels['setup_end'] > 0xe000:
        raise ValueError('bootstrap ROM must fit two 4 KiB pages')
    return binary, labels


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
