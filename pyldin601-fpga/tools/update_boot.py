#!/usr/bin/env python3
"""Prepare a FAT16 boot-partition update from a regular SD backup.

Keep other boot files and install current compact partition ROMs and loader.
This updates only the boot volume; migrate_sd.py also adds the software volume.
Never open a block device.
"""
import argparse
import hashlib
import importlib.util
import json
import mmap
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
    from migrate_sd import prepare as migrate
    if len(bios_a)!=4096 or bios_a[0xff7]!=0x80:raise ValueError('invalid 601A BIOS')
    result,metadata=migrate(backup,add_data=False)
    start,length=sd.ALIGN*512,sd.BOOT_SECTORS*512
    volume=result[start:start+length]
    files=root_files(volume);files['LOADER.BIN']=loader
    volume=sd.fat16(files)
    metadata.update(start_lba=sd.ALIGN,sectors=sd.BOOT_SECTORS,
                    classic_rom_sha256=hashlib.sha256(files['P601.ROM']).hexdigest())
    return volume,metadata


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
    from unias_boot import build
    loader,_ = build('loader')
    from migrate_sd import boot_files,file_sha
    from sd_partitions import scan
    with args.backup.open('rb') as source:
        with mmap.mmap(source.fileno(),0,access=mmap.ACCESS_READ) as backup:
            boot,files,_,_=boot_files(backup,scan(backup,max_logical=32))
            files['LOADER.BIN']=loader
            volume=sd.fat16(files)
        metadata=dict(start_lba=boot.start,sectors=boot.sectors,
                      classic_rom_sha256=hashlib.sha256(files['P601.ROM']).hexdigest(),
                      backup_sha256=file_sha(source),boot_sha256=hashlib.sha256(volume).hexdigest(),
                      settings_sha256=hashlib.sha256(files['P601.SET']).hexdigest())
    with args.output.open('xb') as out:
        out.write(volume)
    args.output.with_suffix('.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()
