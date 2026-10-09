#!/usr/bin/env python3
"""Prepare a FAT16 boot-partition update from a regular SD backup.

Retain existing ROM banks/font/BIOS and all other boot files. Install the
UniAS FPGA extension in free page B of both models, plus the current loader.
Never open a block device.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import struct
import zlib

import make_sd as sd


def root_files(volume):
    reserved, copies, root_entries, spf = sd.u16(volume, 14), volume[16], sd.u16(volume, 17), sd.u16(volume, 22)
    if sd.u16(volume, 11) != 512 or volume[13] != 1 or not reserved or not copies or not spf:
        raise ValueError('expected the existing 512-byte, single-sector-cluster FAT16 boot partition')
    root = (reserved + copies * spf) * 512
    data_start = root + ((root_entries * 32 + 511) // 512) * 512
    cluster_limit = (len(volume) - data_start) // 512 + 2
    files = {}
    for off in range(root, root + root_entries * 32, 32):
        if volume[off] == 0:
            break
        if volume[off + 11] == 0x0f and volume[off] != 0xe5:
            raise ValueError('boot partition contains long filenames; retain its original filesystem')
        if volume[off] == 0xe5 or volume[off + 11] & 8:
            continue
        if volume[off + 11] & 16:
            raise ValueError('boot partition contains a subdirectory; update requires preserving it separately')
        name = volume[off:off + 8].decode('ascii').rstrip() + '.' + volume[off + 8:off + 11].decode('ascii').rstrip()
        cluster, size = sd.u16(volume, off + 26), sd.u32(volume, off + 28)
        result, seen = bytearray(), set()
        while len(result) < size:
            if cluster in seen or not 2 <= cluster < cluster_limit:
                raise ValueError(f'{name}: broken FAT chain')
            seen.add(cluster)
            start = data_start + (cluster - 2) * 512
            result += volume[start:start + 512]
            cluster = sd.u16(volume, reserved * 512 + cluster * 2)
        if cluster < 0xfff8:
            raise ValueError(f'{name}: missing FAT end marker')
        files[name] = bytes(result[:size])
    return files


def prepare(backup, bios_a, loader):
    if backup[510:512] != b'\x55\xaa':
        raise ValueError('missing MBR')
    entries = [struct.unpack_from('<B3sB3sII', backup, 446 + i * 16) for i in range(3)]
    start, sectors = entries[0][4:]
    if entries[0][2] != 6 or start != sd.ALIGN or sectors != sd.BOOT_SECTORS:
        raise ValueError('unexpected boot partition layout')
    off, length = start * 512, sectors * 512
    files = root_files(backup[off:off + length])
    rom = files['P601.ROM']
    if (len(rom) != 0x51a00 or rom[:8] != b'P601BOOT' or sd.u32(rom, 8) != 1
            or sd.u32(rom, 12) != sd.ROM_BASE or sd.u32(rom, 16) != sd.ROM_SIZE
            or rom[25] != 0 or rom[512+0x50ff7] != 0 or sd.u32(rom, 508) != zlib.crc32(rom[:508])
            or sd.u32(rom, 20) != zlib.crc32(rom[512:])):
        raise ValueError('existing classic ROM is invalid')
    drives = []
    for i, entry in enumerate(entries[1:]):
        disk_start, disk_sectors = entry[4:]
        begin, end = disk_start * 512, (disk_start + disk_sectors) * 512
        if entry[2] != 1 or begin < off + length or end > len(backup):
            raise ValueError('data partition outside backup')
        info = sd.disk_info(backup[begin:end])
        info['start_lba'] = disk_start
        values = struct.unpack_from('<IIHHH', rom, 32 + i * 16)
        expected = tuple(info[k] for k in ('start_lba', 'sectors', 'sectors_per_track', 'heads', 'cylinders'))
        if values != expected:
            raise ValueError('ROM disk geometry differs from existing data partitions')
        drives.append(info)
    rom_files = {f'ROM{i}.BIN': rom[512 + i * 65536:512 + (i + 1) * 65536] for i in range(5)}
    rom_files['FONT.BIN'] = rom[512 + 0x51000:]
    rom_files['BIOS.BIN'] = rom[512 + 0x50000:512 + 0x51000]
    files['P601.ROM'] = sd.bundle(rom_files, drives, rom[24], 0)
    rom_files['BIOS.BIN'] = bios_a
    files['P601A.ROM'] = sd.bundle(rom_files, drives, rom[24], 1)
    files['LOADER.BIN'] = loader
    configuration = json.loads(files.get('P601.CFG', b'{}'))
    configuration.update(models=['601', '601A'], rom_crc32=f'{sd.u32(files["P601.ROM"], 20):08x}',
                         rom_a_crc32=f'{sd.u32(files["P601A.ROM"], 20):08x}')
    files['P601.CFG'] = (json.dumps(configuration, indent=2) + '\n').encode('ascii')
    files.setdefault('P601.SET', sd.settings_record())
    return sd.fat16(files), {'start_lba': start, 'sectors': sectors, 'drives': drives,
        'files_sha256': {name: hashlib.sha256(data).hexdigest() for name, data in files.items()},
        'original_classic_rom_sha256': hashlib.sha256(rom).hexdigest(),
        'classic_rom_sha256': hashlib.sha256(files['P601.ROM']).hexdigest(),
        'mbr_sha256': hashlib.sha256(backup[:512]).hexdigest(),
        'data_sha256': [hashlib.sha256(backup[e[4]*512:(e[4]+e[5])*512]).hexdigest() for e in entries[1:]]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backup', type=Path, required=True)
    parser.add_argument('--bios-a', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not stat.S_ISREG(args.backup.stat().st_mode):
        raise ValueError('backup must be a regular image file')
    bios = args.bios_a.read_bytes()
    if len(bios) != 4096 or bios[0xff7] != 0x80:
        raise ValueError('expected original 4096-byte 601A BIOS, hardware version 80')
    script = Path(__file__).resolve().with_name('asm6800.py')
    spec = importlib.util.spec_from_file_location('asm6800', script)
    assembler = importlib.util.module_from_spec(spec);spec.loader.exec_module(assembler)
    loader, _ = assembler.assemble((script.parent.parent/'firmware/loader.asm').read_text(), 0x2000)
    backup = args.backup.read_bytes()
    volume, metadata = prepare(backup, bios, loader)
    metadata.update(backup_sha256=hashlib.sha256(backup).hexdigest(), boot_sha256=hashlib.sha256(volume).hexdigest())
    with args.output.open('xb') as out:
        out.write(volume)
    args.output.with_suffix('.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()
