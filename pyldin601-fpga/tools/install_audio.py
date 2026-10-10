#!/usr/bin/env python3
"""Prepare paired audio BIOS ROMs and YPLAY in a regular SD backup.

Only the FAT16 boot volume and named files on B: change. Settings, other
boot files, existing B: files, MBR/EBR and all other volumes are retained.
This tool never opens a block device; physical installation is separate.
"""
import argparse
import hashlib
import json
import mmap
from pathlib import Path
import shutil
import stat
import zlib

from add_disk_files import add_files, root_files as fat12_files
import make_sd as sd
from sd_partitions import scan
from update_boot import root_files

ROOT = Path(__file__).resolve().parents[1]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def audio_files():
    files = {p.name: p.read_bytes() for p in sorted((ROOT / 'firmware/audio').iterdir())
             if p.is_file()}
    for name in ('YPLAY.PGM', 'DEMO.YM'):
        files[name] = (ROOT / 'build/audio' / name).read_bytes()
    return files


def prepare(image):
    parts = scan(image, max_logical=32)
    boot = next(p for p in parts if p.number == 1)
    drive_b = next(p for p in parts if p.number == 3)
    if (boot.kind, boot.sectors) != (6, sd.BOOT_SECTORS) or drive_b.kind != 1:
        raise ValueError('expected FAT16 boot partition 1 and FAT12 B: partition 3')
    old_boot = image[boot.start*512:(boot.start+boot.sectors)*512]
    files = root_files(old_boot)
    originals = dict(files)
    for model, name in enumerate(('P601.ROM', 'P601A.ROM')):
        old = files[name]
        if (len(old) != 512 + 0x11800 or old[:8] != b'P601BOOT'
            or sd.u32(old, 8) != 2 or old[25] != model
            or sd.u32(old, 20) != zlib.crc32(old[512:])
            or sd.u32(old, 508) != zlib.crc32(old[:508])):
            raise ValueError(f'{name}: invalid compact ROM bundle')
        native = {'ROM0.BIN': old[512:512+65536], 'FONT.BIN': old[512+0x11000:]}
        new = sd.bundle(native, [], 0, model)
        for page in (1, 5):
            start = 512 + page*8192
            assert new[start:start+8192] == old[start:start+8192], 'native Y ROM changed'
        assert new[512+0x11000:] == old[512+0x11000:], 'font changed'
        files[name] = new
    new_boot = sd.fat16(files)
    assert root_files(new_boot) == files
    assert all(files[n] == data for n, data in originals.items()
               if n not in ('P601.ROM', 'P601A.ROM'))
    old_b = image[drive_b.start*512:(drive_b.start+drive_b.sectors)*512]
    music = audio_files()
    new_b = add_files(old_b, music, replace=True)
    assert all(fat12_files(new_b)[n] == d for n, d in music.items())
    changes = [dict(partition=p.number, start_lba=p.start, sectors=p.sectors,
                    before_sha256=sha(old), after_sha256=sha(new))
               for p, old, new in ((boot, old_boot, new_boot), (drive_b, old_b, new_b))]
    report = dict(changes=changes, settings_sha256=sha(files['P601.SET']),
                  rom_files={n: sha(files[n]) for n in ('P601.ROM', 'P601A.ROM')},
                  files={n: dict(bytes=len(d), sha256=sha(d)) for n, d in music.items()},
                  other_boot_and_b_files_preserved=True, mbr_ebr_preserved=True,
                  fpga_update_required=True)
    return [(boot.start*512, new_boot), (drive_b.start*512, new_b)], report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if not stat.S_ISREG(args.image.stat().st_mode):
        raise ValueError('input must be a regular SD backup')
    with args.image.open('rb') as source:
        with mmap.mmap(source.fileno(), 0, access=mmap.ACCESS_READ) as image:
            regions, report = prepare(image)
        with args.output.open('x+b') as target:
            shutil.copyfileobj(source, target, 4*1024*1024)
            for offset, volume in regions:
                target.seek(offset)
                target.write(volume)
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Prepared both audio BIOS ROMs and {len(report["files"])} B: files: {args.output}')


if __name__ == '__main__':
    main()
