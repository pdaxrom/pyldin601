"""Independent on-disk FAT12/FAT16 consistency check for firmware mutations."""
from pathlib import Path
import struct
import sys


def check(path):
    v = Path(path).read_bytes()
    u16 = lambda o: struct.unpack_from('<H', v, o)[0]
    u32 = lambda o: struct.unpack_from('<I', v, o)[0]
    assert u16(11) == 512 and v[510:512] == b'\x55\xaa'
    spc, reserved, copies, spf = v[13], u16(14), v[16], u16(22)
    root, total = u16(17), u16(19) or u32(32)
    data = reserved + copies * spf + (root * 32 + 511) // 512
    count = (total - data) // spc
    bits = 12 if count < 4085 else 16
    assert total * 512 <= len(v) and 0 < count < 65525
    fat = v[reserved * 512:(reserved + spf) * 512]
    for copy in range(1, copies):
        begin = (reserved + copy * spf) * 512
        assert v[begin:begin + len(fat)] == fat, 'FAT mirrors differ'

    def value(c):
        if bits == 16:
            return struct.unpack_from('<H', fat, c * 2)[0]
        n = struct.unpack_from('<H', fat, c + c // 2)[0]
        return n >> 4 if c & 1 else n & 4095

    used = {}
    files = 0
    dirs = 0

    def chain(c, name):
        result = []
        while True:
            assert 2 <= c <= count + 1, (name, 'invalid cluster', c)
            assert c not in used, (name, 'cycle/cross-link', c, used.get(c))
            used[c] = name
            result.append(c)
            n = value(c)
            if n >= (0xfff8 if bits == 16 else 0xff8):
                return result
            assert n < (0xfff0 if bits == 16 else 0xff0), (name, 'reserved/bad FAT link', n)
            assert n != 0, (name, 'chain enters free space')
            c = n

    def directory(contents, parent, current, prefix):
        nonlocal files, dirs
        for off in range(0, len(contents), 32):
            e = contents[off:off + 32]
            if not e[0]:
                break
            if e[0] == 0xe5 or e[11] & 8:
                continue
            name = e[:8].rstrip().decode('ascii')
            ext = e[8:11].rstrip().decode('ascii')
            c, size = struct.unpack_from('<HI', e, 26)
            if name in ('.', '..'):
                assert c == (current if name == '.' else parent)
                continue
            full = prefix + name + ('.' + ext if ext else '')
            if not c:
                assert size == 0 and not e[11] & 16, (full, 'missing cluster')
                files += 1
                continue
            allocated = chain(c, full)
            if e[11] & 16:
                dirs += 1
                chunks = []
                for n in allocated:
                    begin = (data + (n - 2) * spc) * 512
                    chunks.append(v[begin:begin + spc * 512])
                directory(b''.join(chunks), current, c, full + '/')
            else:
                files += 1
                assert len(allocated) == (size + spc * 512 - 1) // (spc * 512), (full, 'allocation/size mismatch')

    root_begin = (reserved + copies * spf) * 512
    directory(v[root_begin:root_begin + root * 32], 0, 0, '')
    allocated = {c for c in range(2, count + 2) if value(c) != 0}
    assert allocated == set(used), ('lost clusters', sorted(allocated - set(used))[:20])
    print(f'PASS independent FAT{bits}: {files} files, {dirs} directories, {len(used)} clusters; mirrors and all chains consistent')


if __name__ == '__main__':
    check(sys.argv[1])
