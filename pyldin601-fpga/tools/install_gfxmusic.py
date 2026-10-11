#!/usr/bin/env python3
"""Add the combined demo to B: in a regular SD backup; keep ROM/other volumes."""
import argparse
import hashlib
import json
import mmap
from pathlib import Path
import shutil
import stat
from add_disk_files import add_files
from sd_partitions import scan

ROOT = Path(__file__).resolve().parents[1]


def demo_files():
    files = {p.name: p.read_bytes() for p in sorted((ROOT / 'firmware/audio').iterdir()) if p.is_file()}
    for name in ('GFXMUSIC.PGM', 'YPLAY.PGM', 'DEMO.YM'):
        files[name] = (ROOT / 'build/audio' / name).read_bytes()
    for name in ('DEMOGFX.INC', 'PALCOEF.ASM', 'GFXCLIP.ASM'):
        files[name] = (ROOT / 'firmware/gfx' / name).read_bytes()
    return files


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--image', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if not stat.S_ISREG(a.image.stat().st_mode):
        raise ValueError('input must be a regular SD backup')
    files = demo_files()
    sha = lambda data: hashlib.sha256(data).hexdigest()
    # Only the B: volume needs RAM, even for a large unified SD backup.
    with a.image.open('rb') as source:
        with mmap.mmap(source.fileno(), 0, access=mmap.ACCESS_READ) as image:
            drive_b = next(p for p in scan(image, max_logical=32) if p.number == 3)
            if drive_b.kind != 1:
                raise ValueError('expected FAT12 B: partition 3')
            offset, size = drive_b.start*512, drive_b.sectors*512
            old = image[offset:offset+size]
            volume = add_files(old, files, replace=True)
            report = dict(drive='B', start_lba=drive_b.start, sectors=drive_b.sectors,
                          before_sha256=sha(old), after_sha256=sha(volume),
                          files={n: dict(bytes=len(data), sha256=sha(data)) for n,data in files.items()},
                          rom_and_settings_preserved=True, mbr_and_other_partitions_preserved=True,
                          fpga_update_required=False)
        with a.output.open('xb') as target:
            shutil.copyfileobj(source, target, 4*1024*1024)
            target.seek(offset)
            target.write(volume)
    a.output.with_suffix('.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Prepared GFXMUSIC and sources on B: {a.output}; other partitions preserved')


if __name__ == '__main__':
    main()
