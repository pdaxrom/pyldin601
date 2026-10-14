#!/usr/bin/env python3
"""Install GAMEBIOS and games, or only games, in a regular SD backup.

Update boot ROM files and named B: files. Preserve settings, disk shells,
boot-sector code, other files, MBR/EBR and all other partitions.
--apps-only also preserves every boot-partition byte. Never open a block device.
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


def game_files():
    names = ('GAMEBIOS.INC', 'GAMESDK.ASM', 'GAMESDTA.INC', 'GAMEHOW.TXT',
             'ARKANOID.ASM', 'SDKTEST.ASM', 'XONIX.ASM', 'HIGHSCR.ASM',
             'HISDATA.INC', 'GAMEMUS.ASM', 'MUSAPI.ASM', 'MUSDATA.INC',
             'HIMAGE.ASM', 'HIMDATA.INC', 'XCFG.ASM', 'XONIX.CFG', 'MUSIC.TXT',
             'WARHAWK.YM', 'LEDSTRM1.YM', 'LENA.IFF')
    files = {n: (ROOT / 'firmware/game' / n).read_bytes() for n in names}
    for n in ('ARKANOID.PGM', 'SDKTEST.PGM', 'XONIX.PGM', 'SDKWORLD.INC', 'BOUNCEY.INC'):
        files[n] = (ROOT / 'build/game' / n).read_bytes()
    return files


def prepare_apps(image):
    """Update only named B: files; retain settings, ROM and existing scores."""
    from add_disk_files import install
    files = game_files()
    p = next(p for p in scan(image, max_logical=32) if p.number == 3)
    previous = fat12_files(image[p.start*512:(p.start+p.sectors)*512])
    if 'XONIX.CFG' in previous:
        files['XONIX.CFG'] = previous['XONIX.CFG']
    updated, report = install(image, files, replace=True)
    volume = updated[p.start*512:(p.start+p.sectors)*512]
    report.update(fpga_update_required=True, fpga_min_graphics_revision=6, rom_update_required=False,
                  existing_xonix_config_preserved='XONIX.CFG' in previous,
                  files={n: dict(bytes=len(d), sha256=sha(d)) for n, d in files.items()})
    return [(p.start*512, volume)], report


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
        # UniBIOS page 8 is now built from its owned 3.02 source. The
        # XBIOS/Y interpreter pages retain their original bytes.
        for page in (1, 5):
            start = 512 + page*8192
            if new[start:start+8192] != old[start:start+8192]:
                raise ValueError(f'{name}: native XBIOS/Y ROM changed')
        if b'UniBIOS  Version 3.02' not in new[512:512+8192]:
            raise ValueError(f'{name}: expected source-built UniBIOS 3.02')
        assert new[512+0x11000:] == old[512+0x11000:], 'font changed'
        files[name] = new
    new_boot = sd.fat16(files)
    assert root_files(new_boot) == files
    assert all(files[n] == d for n, d in originals.items()
               if n not in ('P601.ROM', 'P601A.ROM'))
    old_b = image[drive_b.start*512:(drive_b.start+drive_b.sectors)*512]
    programs = game_files()
    previous = fat12_files(old_b)
    if 'XONIX.CFG' in previous:
        programs['XONIX.CFG'] = previous['XONIX.CFG']
    new_b = add_files(old_b, programs, replace=True)
    updated = fat12_files(new_b)
    assert all(updated[n] == d for n, d in programs.items())
    assert all(updated[n] == d for n, d in previous.items() if n not in programs)
    volumes = [(boot, old_boot, new_boot), (drive_b, old_b, new_b)]
    changes = [dict(partition=p.number, start_lba=p.start, sectors=p.sectors,
                    before_sha256=sha(old), after_sha256=sha(new))
               for p, old, new in volumes]
    report = dict(changes=changes, settings_sha256=sha(files['P601.SET']),
                  rom_files={n: sha(files[n]) for n in ('P601.ROM', 'P601A.ROM')},
                  files={n: dict(bytes=len(d), sha256=sha(d)) for n, d in programs.items()},
                  other_boot_and_b_files_preserved=True, mbr_ebr_preserved=True,
                  native_boot_sector_preserved=True,
                  native_xbios_y_pages_preserved=True, unibios_version='3.02', gamebios_abi=2,
                  gamebios_context_bytes=416, gamebios_features=63,
                  fpga_update_required=True, fpga_min_graphics_revision=6, requires_ps2_capture=True,
                  existing_xonix_config_preserved='XONIX.CFG' in previous,
                  ps2_raw_identity=0x52)
    return [(p.start*512, new) for p, _, new in volumes], report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--apps-only', action='store_true', help='keep all boot ROM/settings bytes unchanged')
    args = parser.parse_args()
    if not stat.S_ISREG(args.image.stat().st_mode):
        raise ValueError('input must be a regular SD backup')
    with args.image.open('rb') as source:
        with mmap.mmap(source.fileno(), 0, access=mmap.ACCESS_READ) as image:
            regions, report = (prepare_apps if args.apps_only else prepare)(image)
        with args.output.open('x+b') as target:
            shutil.copyfileobj(source, target, 4*1024*1024)
            for offset, volume in regions:
                target.seek(offset)
                target.write(volume)
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Prepared {len(report["files"])} game/SDK files: {args.output}')


if __name__ == '__main__':
    main()
