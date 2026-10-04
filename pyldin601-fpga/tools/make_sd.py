#!/usr/bin/env python3
"""Build a regular SD image; never open a block device or overwrite an image.

Partition 1 is FAT16. Partitions 2/3 are unmodified FAT12 disk images.
Only Python's standard library is needed. See --help for input paths.
"""
import argparse
import importlib.util
import gzip
import json
import binascii
import math
from pathlib import Path
import struct
import zlib

SECTOR = 512
ALIGN = 2048
BOOT_SECTORS = 32768
ROM_BASE = 0x10000
ROM_SIZE = 0x51800
MAX_DISK_SIZE = 12 * 1024 * 1024


def u16(data, offset):
    return struct.unpack_from('<H', data, offset)[0]


def u32(data, offset):
    return struct.unpack_from('<I', data, offset)[0]


def unpack_file(path):
    data = Path(path).read_bytes()
    return gzip.decompress(data) if data[:2] == b'\x1f\x8b' else data


def disk_info(data):
    if len(data) < SECTOR or len(data) % SECTOR or len(data) > MAX_DISK_SIZE:
        raise ValueError('disk must contain whole 512-byte sectors, at most 12 MiB')
    # Classic Pyldin boot sectors can end in A5 5A, not PC 55 AA.
    if data[510:512] not in (b'\x55\xaa', b'\xa5\x5a'):
        raise ValueError('missing FAT boot signature (55AA or classic A55A)')
    size, spc, reserved, fats = u16(data, 11), data[13], u16(data, 14), data[16]
    root, spf = u16(data, 17), u16(data, 22)
    total = u16(data, 19) or u32(data, 32)
    spt, heads = u16(data, 24), u16(data, 26)
    if size != SECTOR or spc not in (1, 2, 4, 8, 16, 32, 64, 128):
        raise ValueError('unsupported FAT sector/cluster size')
    if not reserved or not fats or not root or not spf or not total:
        raise ValueError('invalid FAT BPB')
    overhead = reserved + fats * spf + (root * 32 + 511) // SECTOR
    if total <= overhead or total > len(data) // SECTOR:
        raise ValueError('BPB total sectors outside disk image')
    clusters = (total - overhead) // spc
    if not 1 <= clusters < 4085:
        raise ValueError(f'expected FAT12, found {clusters} data clusters')
    if spf * SECTOR < math.ceil((clusters + 2) * 3 / 2):
        raise ValueError('FAT too small for data clusters')
    if not 1 <= spt <= 255 or not 1 <= heads <= 2:
        raise ValueError('classic CHS requires 1..255 sectors/track and 1..2 heads')
    cylinders = (total + spt * heads - 1) // (spt * heads)
    if cylinders > 256:
        raise ValueError('geometry exceeds 8-bit cylinder addressing')
    return dict(sectors=total, image_sectors=len(data)//SECTOR,
                sectors_per_track=spt, heads=heads, cylinders=cylinders,
                sectors_per_cluster=spc, clusters=clusters)


def blank_disk(size=1440*1024, spt=18, heads=2):
    """Empty FAT12 volume, not a bootable system disk. Geometry is explicit."""
    if size % SECTOR or not SECTOR * 64 <= size <= MAX_DISK_SIZE:
        raise ValueError('invalid blank disk size')
    total = size // SECTOR
    root, reserved, fats = 512, 1, 2
    for spc in (1, 2, 4, 8, 16, 32, 64, 128):
        spf = 1
        while True:
            clusters = (total - reserved - fats * spf - root // 16) // spc
            needed = (math.ceil((clusters + 2) * 3 / 2) + 511) // SECTOR
            if spf >= needed:
                break
            spf = needed
        if 1 <= clusters < 4085:
            break
    data = bytearray(size)
    data[0:11] = b'\xeb\x3c\x90P601DATA'
    struct.pack_into('<HBHBHHBHHHII', data, 11, SECTOR, spc, reserved,
                     fats, root, total, 0xf8, spf, spt, heads, 0, 0)
    data[38] = 0x29
    data[43:54] = b'P601 DATA  '
    data[54:62] = b'FAT12   '
    # No x86 code and no pretend MC6800 boot code: this is a data disk.
    data[510:512] = b'\x55\xaa'
    for copy in range(fats):
        off = (reserved + copy * spf) * SECTOR
        data[off:off+3] = b'\xf8\xff\xff'
    disk_info(data)
    return bytes(data)


def rom_files(native):
    native = Path(native)
    files = {}
    for name, path, length in (
        ('BIOS.BIN', native/'Bios/bios.roz', 4096),
        ('FONT.BIN', native/'Bios/video.roz', 2048),
    ):
        data = unpack_file(path)
        if len(data) != length:
            raise ValueError(f'{path}: expected {length} bytes')
        files[name] = data
    # Full banks are authoritative; smaller EPROMs mirror into the 64 KiB slot.
    for bank in range(5):
        path = native/'RAMROMDiskPipnet'/f'rom{bank}.roz'
        data = unpack_file(path)
        if len(data) not in (8192, 16384, 32768, 65536):
            raise ValueError(f'{path}: invalid EPROM size')
        files[f'ROM{bank}.BIN'] = data * (65536 // len(data))
    return files


def bundle(files, drives, boot, model=0):
    payload = b''.join(files[f'ROM{i}.BIN'] for i in range(5))
    payload += files['BIOS.BIN'] + files['FONT.BIN']
    assert len(payload) == ROM_SIZE
    header = bytearray(SECTOR)
    header[:8] = b'P601BOOT'
    struct.pack_into('<IIII', header, 8, 1, ROM_BASE, len(payload), zlib.crc32(payload))
    if model not in (0, 1):
        raise ValueError('model must be 0 (601) or 1 (601A)')
    expected_version = 0x80 if model else 0
    if files['BIOS.BIN'][0xff7] != expected_version:
        raise ValueError('BIOS hardware version does not match selected model')
    header[24] = boot
    header[25] = model
    for i, drive in enumerate(drives):
        struct.pack_into('<IIHHH', header, 32 + i * 16, drive['start_lba'],
                         drive['sectors'], drive['sectors_per_track'],
                         drive['heads'], drive['cylinders'])
    struct.pack_into('<I', header, 508, zlib.crc32(header[:508]))
    return bytes(header) + payload


def fat16(files):
    total, reserved, copies, root_entries, spc = BOOT_SECTORS, 1, 2, 512, 1
    spf = 128
    root_sectors = root_entries // 16
    data_start = reserved + copies * spf + root_sectors
    clusters = (total - data_start) // spc
    assert 4085 <= clusters < 65525 and (clusters + 2) * 2 <= spf * SECTOR
    volume = bytearray(total * SECTOR)
    volume[:11] = b'\xeb\x3c\x90P601BOOT'
    struct.pack_into('<HBHBHHBHHHII', volume, 11, SECTOR, spc, reserved,
                     copies, root_entries, total, 0xf8, spf, 32, 2, ALIGN, 0)
    volume[38] = 0x29
    struct.pack_into('<I', volume, 39, 0x601)
    volume[43:54] = b'P601 BOOT  '
    volume[54:62] = b'FAT16   '
    volume[510:512] = b'\x55\xaa'
    table = bytearray(spf * SECTOR)
    struct.pack_into('<HH', table, 0, 0xfff8, 0xffff)
    cluster = 2
    root_start = (reserved + copies * spf) * SECTOR
    for index, (name, data) in enumerate(files.items()):
        base, ext = name.split('.')
        if len(base) > 8 or len(ext) > 3 or name != name.upper():
            raise ValueError(f'not an uppercase 8.3 name: {name}')
        count = (len(data) + SECTOR - 1) // SECTOR
        if not count or cluster + count > clusters + 2 or index >= root_entries:
            raise ValueError('boot partition full')
        entry = root_start + index * 32
        volume[entry:entry+11] = (base.ljust(8)+ext.ljust(3)).encode('ascii')
        volume[entry+11] = 0x20
        struct.pack_into('<H', volume, entry+26, cluster)
        struct.pack_into('<I', volume, entry+28, len(data))
        offset = (data_start + cluster - 2) * SECTOR
        volume[offset:offset+len(data)] = data
        for c in range(cluster, cluster + count):
            struct.pack_into('<H', table, c*2, 0xffff if c == cluster+count-1 else c+1)
        cluster += count
    for i in range(copies):
        off = (reserved + i * spf) * SECTOR
        volume[off:off+len(table)] = table
    return bytes(volume)


def settings_record(model=0, extension=False, frequency=1):
    if model not in (0, 1) or frequency not in (1, 2, 4, 8):
        raise ValueError('settings require model 601/601A and frequency 1/2/4/8 MHz')
    flags = model | (bool(extension) << 1) | ((frequency.bit_length() - 1) << 2)
    data = b'P601SET\0' + bytes((1, flags)) + bytes(4)
    return data + struct.pack('>H', binascii.crc_hqx(data, 0))


def build(native, disks, boot=0, allow_large=False, bios_a=None):
    files = rom_files(native)
    start = ALIGN + BOOT_SECTORS
    drives = []
    for data in disks:
        info = disk_info(data)
        if not allow_large and (info['sectors']>2880 or info['cylinders']>80
                                or info['sectors_per_track']>18):
            raise ValueError('classic i8272 supports at most 80 cylinders, 2 heads, 18 sectors; '
                             'large disks require the future LBA driver')
        info['start_lba'] = start
        drives.append(info)
        start = ((start + len(data)//SECTOR + ALIGN-1)//ALIGN)*ALIGN
    classic_files = files
    files = {'P601.ROM': bundle(classic_files, drives, boot)}
    if bios_a is not None:
        data = unpack_file(bios_a)
        if len(data) != 4096:
            raise ValueError('601A BIOS must be exactly 4096 bytes')
        files['P601A.ROM'] = bundle({**classic_files, 'BIOS.BIN': data}, drives, boot, 1)
    script = Path(__file__).resolve().parent/'asm6800.py'
    spec = importlib.util.spec_from_file_location('asm6800',script)
    assembler = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(assembler)
    loader,_ = assembler.assemble((script.parent.parent/'firmware/loader.asm').read_text(),0x2000)
    files['LOADER.BIN'] = loader
    config = dict(version=1, controller='experimental-lba' if allow_large else 'i8272',
                  boot_drive='B' if boot else 'A', drives=drives,
                  rom_crc32=f'{zlib.crc32(files["P601.ROM"][SECTOR:]):08x}')
    config['models'] = ['601', '601A'] if bios_a is not None else ['601']
    if bios_a is not None:
        config['rom_a_crc32'] = f'{zlib.crc32(files["P601A.ROM"][SECTOR:]):08x}'
    files['P601.CFG'] = (json.dumps(config, indent=2)+'\n').encode('ascii')
    files['P601.SET'] = settings_record()
    image = bytearray(start * SECTOR)
    image[510:512] = b'\x55\xaa'
    for i, (kind, lba, count) in enumerate(
        [(0x06, ALIGN, BOOT_SECTORS)] +
        [(0x01, d['start_lba'], d['image_sectors']) for d in drives]
    ):
        entry = 446+i*16
        struct.pack_into('<B3sB3sII', image, entry, 0, b'\xfe\xff\xff', kind,
                         b'\xfe\xff\xff', lba, count)
    image[ALIGN*SECTOR:(ALIGN+BOOT_SECTORS)*SECTOR] = fat16(files)
    for info, data in zip(drives, disks):
        off = info['start_lba']*SECTOR
        image[off:off+len(data)] = data
    return bytes(image), config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=Path, required=True,
                        help='classic emulator native directory')
    default_a = Path(__file__).resolve().parents[2]/'native-src/BIOS_A.ROM'
    parser.add_argument('--bios-a', type=Path, default=default_a if default_a.is_file() else None,
                        help='original 4096-byte 601A BIOS; defaults to native-src/BIOS_A.ROM when available')
    parser.add_argument('--disk-a', type=Path, help='raw FAT12 or gzip image')
    parser.add_argument('--disk-b', type=Path, help='raw FAT12 or gzip image')
    parser.add_argument('--blank-kib', type=int, default=1440,
                        help='size of missing data disks, default 1440 KiB')
    parser.add_argument('--blank-spt', type=int, default=18)
    parser.add_argument('--blank-heads', type=int, default=2)
    parser.add_argument('--boot', choices=('A', 'B'), default='A')
    parser.add_argument('--allow-large',action='store_true',
                        help='prepare experimental LBA images; classic core refuses these')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    disks = [unpack_file(path) if path else blank_disk(
        args.blank_kib*1024, args.blank_spt, args.blank_heads)
        for path in (args.disk_a, args.disk_b)]
    image, config = build(args.native, disks, int(args.boot == 'B'),args.allow_large,args.bios_a)
    # Exclusive creation: no implicit overwrites and no raw device writes.
    with args.output.open('xb') as out:
        out.write(image)
    print(json.dumps(dict(output=str(args.output), bytes=len(image), **config), indent=2))
    if not args.disk_a or not args.disk_b:
        print('Missing disk inputs were created as empty DATA volumes, not bootable disks.')


if __name__ == '__main__':
    main()
