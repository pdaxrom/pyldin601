"""Independent FAT16 fixture with fragmented/high clusters and a large directory.

Uses the prepared regular SD fixture; never touches a device or shipped image.
"""
from pathlib import Path
import struct
import os
import sys
import shutil
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from unias import assemble
from add_disk_files import root_files

ROOT = Path(__file__).resolve().parents[1]
SECTOR = 512
TOTAL = 262144  # 128 MiB, TotSec32, 2 KiB clusters, FAT sector 255 is used.
SPC, RESERVED, FATS, SPF, ROOT_ENTRIES = 4, 1, 2, 256, 512
DATA = RESERVED + FATS * SPF + ROOT_ENTRIES // 16
COUNT = (TOTAL - DATA) // SPC
START = 40960
OUT = ROOT / 'build/fat16'


def pattern(size, salt=0):
    return bytes(((n * 17) ^ (n >> 8) ^ 0xa5 ^ salt) & 255 for n in range(size))


def entry(name, attr, cluster, size=0):
    e = bytearray(32)
    e[:11] = name
    e[11] = attr
    struct.pack_into('<HI', e, 26, cluster, size)
    return e


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    original = (ROOT / 'build/partitions/sd-test.img').read_bytes()
    a_start, a_sectors = struct.unpack_from('<II', original, 470)
    (OUT / 'datetime.expected').write_bytes(root_files(original[a_start*512:(a_start+a_sectors)*512])['DATETIME.PGM'])
    image = bytearray((START + TOTAL) * SECTOR)
    image[:START * SECTOR] = original[:START * SECTOR]
    # PART4 becomes C:, bootstrap PART1 stays unmounted. Use the assembled shell.
    image[34816 * SECTOR + 510:34816 * SECTOR + 512] = b'\x55\xaa'
    image[446 + 3 * 16 + 4] = 6
    struct.pack_into('<II', image, 446 + 3 * 16 + 8, START, TOTAL)
    v = memoryview(image)[START * SECTOR:]
    v[:11] = b'\xeb\x3c\x90TESTF16 '
    struct.pack_into('<HBHBHHBHHHII', v, 11, SECTOR, SPC, RESERVED, FATS,
                     ROOT_ENTRIES, 0, 0xf8, SPF, 63, 255, START, TOTAL)
    v[38] = 0x29
    v[43:54] = b'FAT16 TEST '
    v[54:62] = b'FAT16   '
    v[510:512] = b'\x55\xaa'
    fat = bytearray(SPF * SECTOR)
    struct.pack_into('<HH', fat, 0, 0xfff8, 0xffff)

    def chain(clusters, content):
        for i, c in enumerate(clusters):
            struct.pack_into('<H', fat, c * 2,
                             clusters[i + 1] if i + 1 < len(clusters) else 0xffff)
            off = (DATA + (c - 2) * SPC) * SECTOR
            part = content[i * SPC * SECTOR:(i + 1) * SPC * SECTOR]
            v[off:off + len(part)] = part

    # A valid zero-filled file occupies low clusters, forcing real allocation
    # past 32768. This exercises the allocator instead of modifying its state.
    for c in range(2, 32767):
        struct.pack_into('<H', fat, c * 2, c + 1 if c < 32766 else 0xffff)
    high = pattern(8192)
    chain([32767, 32768, 50000, COUNT + 1], high)
    # The same low 16-bit sector as HICHAIN, but a different high word.
    alias = pattern(2048, 0x67)
    chain([49151], alias)
    inner = pattern(97777, 0x31)
    chain(list(range(45001, 45049)), inner)
    directory = bytearray(SPC * SECTOR)
    directory[:32] = entry(b'.          ', 16, 45000)
    directory[32:64] = entry(b'..         ', 16, 0)
    directory[64:96] = entry(b'INNER   BIN', 0, 45001, len(inner))
    chain([45000], directory)
    root = (RESERVED + FATS * SPF) * SECTOR
    for i, e in enumerate([
        entry(b'LOWFILL BIN', 0, 2, 32765 * SPC * SECTOR),
        entry(b'HICHAIN BIN', 0, 32767, len(high)),
        entry(b'HIDIR      ', 16, 45000),
        entry(b'ALIAS   BIN', 0, 49151, len(alias)),
    ]):
        v[root + i * 32:root + (i + 1) * 32] = e
    for copy in range(FATS):
        off = (RESERVED + copy * SPF) * SECTOR
        v[off:off + len(fat)] = fat
    (OUT / 'sd.img').write_bytes(image)
    # Five small logical FAT12 volumes fill all remaining DOS letters. A/B/C
    # and their software stay unchanged; EBRs occupy the unused MBR alignment gap.
    pooled = bytearray(image)
    pooled[446:462] = bytes(16)
    pooled[450] = 15
    struct.pack_into('<II', pooled, 454, 16, 2032)
    for index in range(5):
        base = 16 + index*128
        table = bytearray(512)
        table[450] = 1
        struct.pack_into('<II', table, 454, 1, 65)
        if index < 4:
            table[466] = 15
            struct.pack_into('<II', table, 470, (index+1)*128, 2032-(index+1)*128)
        table[510:512] = b'\x55\xaa'
        pooled[base*512:(base+1)*512] = table
        volume = bytearray(65*512)
        volume[:11] = b'\xeb\x3c\x90POOLTEST'
        struct.pack_into('<HBHBHHBHHHII', volume, 11, 512, 1, 1, 2, 16, 65, 0xf8, 1, 0, 0, base+1, 0)
        volume[510:512] = b'\x55\xaa'
        volume[512:515] = volume[1024:1027] = b'\xf8\xff\xff'
        pooled[(base+1)*512:(base+66)*512] = volume
    (OUT / 'header-pool.img').write_bytes(pooled)
    shutil.copyfile(ROOT / 'tests/file_cache_fault.asm', OUT / 'file_cache_fault.asm')
    assemble(os.environ.get('UNIAS', 'unias'), OUT, 'file_cache_fault.asm', 'file-cache-fault.bin')

    (OUT / 'high.expected').write_bytes(high)
    (OUT / 'inner.expected').write_bytes(inner)
    (OUT / 'alias.expected').write_bytes(alias)
    print(f'FAT16 fixture: {TOTAL} sectors, {COUNT} clusters, highest {COUNT + 1}')
    wide12(original)


def wide12(original):
    """FAT12 entries at bytes 511/1023, 16-bit reserved/SPF, TotSec32/SPC128."""
    image = bytearray((START + TOTAL) * SECTOR)
    image[:START * SECTOR] = original[:START * SECTOR]
    image[34816 * SECTOR + 510:34816 * SECTOR + 512] = b'\x55\xaa'
    image[498] = 1
    struct.pack_into('<II', image, 502, START, TOTAL)
    v = memoryview(image)[START * SECTOR:]
    spc, reserved, spf = 128, 65535, 512
    data = reserved + 2 * spf + 32
    v[:11] = b'\xeb\x3c\x90WIDEF12 '
    struct.pack_into('<HBHBHHBHHHII', v, 11, 512, spc, reserved, 2, 512, 0,
                     0xf8, spf, 0, 0, START, TOTAL)
    v[38], v[54:62], v[510:512] = 0x29, b'FAT12   ', b'\x55\xaa'
    fat = bytearray(spf * 512)

    def put(c, n):
        off = c + c // 2
        old = struct.unpack_from('<H', fat, off)[0]
        new = (old & 15) | (n << 4) if c & 1 else (old & 0xf000) | n
        struct.pack_into('<H', fat, off, new)

    put(0, 0xff8); put(1, 0xfff)
    for c in range(2, 341):
        put(c, c + 1 if c < 340 else 0xfff)
    content = pattern(131949, 0x4e)
    for i, c in enumerate((341, 342, 682)):
        put(c, (342, 682, 0xfff)[i])
        off = (data + (c - 2) * spc) * 512
        chunk = content[i * 65536:(i + 1) * 65536]
        v[off:off + len(chunk)] = chunk
    root = (reserved + 2 * spf) * 512
    v[root:root + 32] = entry(b'LOWFILL BIN', 0, 2, 339 * 65536)
    v[root + 32:root + 64] = entry(b'WIDE    BIN', 0, 341, len(content))
    for copy in range(2):
        off = (reserved + copy * spf) * 512
        v[off:off + len(fat)] = fat
    (OUT / 'wide12.img').write_bytes(image)
    (OUT / 'wide12.expected').write_bytes(content)


if __name__ == '__main__':
    main()
