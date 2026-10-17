"""Reboot real NCEDIT on private disks; independently verify commit CRCs."""
import argparse
import binascii
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/nc'


def copies(image):
    """Read FAT12 directly, independently of the native editor and its cache."""
    disk = bytearray(image)
    base = struct.unpack_from('<I', disk, 446 + 2*16 + 8)[0] * 512
    reserved = struct.unpack_from('<H', disk, base+14)[0]
    spf = struct.unpack_from('<H', disk, base+22)[0]
    roots = struct.unpack_from('<H', disk, base+17)[0]
    cluster_bytes = disk[base+13] * 512
    fat = base + reserved*512
    root = base + (reserved + disk[base+16]*spf)*512
    data = root + (roots*32+511)//512*512
    records = []
    for index in range(roots):
        entry = root + index*32
        name = bytes(disk[entry:entry+11])
        if not name.startswith(b'NCR') or name[8:10] != b'RC' or name[10:11] not in (b'0', b'1', b'2', b'3'):
            continue
        size = struct.unpack_from('<I', disk, entry+28)[0]
        cluster = struct.unpack_from('<H', disk, entry+26)[0]
        content, addresses, seen = bytearray(), [], set()
        while len(content) < size:
            assert 2 <= cluster < 4085 and cluster not in seen
            seen.add(cluster)
            at = data + (cluster-2)*cluster_bytes
            count = min(cluster_bytes, size-len(content))
            content.extend(disk[at:at+count])
            addresses.extend(range(at, at+count))
            pos = fat + cluster + cluster//2
            value = struct.unpack_from('<H', disk, pos)[0]
            cluster = value >> 4 if cluster & 1 else value & 4095
        payload, trailer = content[:-128], content[-128:]
        committed = (
            len(content) >= 128 and trailer[:4] == b'NCR1'
            and binascii.crc_hqx(trailer[:126], 0) == int.from_bytes(trailer[126:], 'big')
            and int.from_bytes(trailer[88:92], 'big') == len(payload)
            and binascii.crc_hqx(payload, 0) == int.from_bytes(trailer[96:98], 'big')
        )
        records.append(dict(name=name.decode(), content=bytes(content), addresses=addresses,
                            committed=committed,
                            generation=int.from_bytes(trailer[84:88], 'big') if committed else None))
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cc', default='cc')
    parser.add_argument('--prepared', action='store_true')
    parser.add_argument('--quick', action='store_true')
    args = parser.parse_args()
    if not args.prepared:
        subprocess.run(['python3', 'tests/run_nc_editor.py', '--prepare-only'], cwd=ROOT, check=True)
    subprocess.run([args.cc, '-O2', '-I../pyldin601/src', 'tests/test_nc_editor.c',
                    '-o', str(OUT/'test_nc_editor')], cwd=ROOT, check=True)
    results = []

    def run(media, model, cpu, video, case, output=None):
        command = [str(OUT/'test_nc_editor'), str(media), model, cpu, str(video), case]
        if output:
            command.append(str(output))
        subprocess.run(command, cwd=ROOT, check=True)
        results.append(dict(model=model, cpu=cpu, video=video, case=case, passed=True))

    def check(path, generations):
        records = copies(path.read_bytes())
        assert sorted(r['generation'] for r in records if r['committed']) == generations
        return records

    matrix = [('601', 'mc6800', 0)] if args.quick else [
        ('601', 'mc6800', 0), ('601', 'hd6303', 3),
        ('601a', 'mc6800', 4), ('601a', 'hd6303', 2)]
    for model, cpu, video in matrix:
        stem = f'recovery-{model}-{cpu}-{video}'
        media = OUT / (stem+'.img')
        run(OUT/'sd-editor.img', model, cpu, video, 'recovery-write', media)
        records = check(media, [1, 2])
        first = min(records, key=lambda r: r['generation'])
        latest = max(records, key=lambda r: r['generation'])
        assert first['content'].startswith(b'aPyldin')
        assert latest['content'].startswith(b'abPyldin')
        run(media, model, cpu, video, 'recovery-read', OUT/(stem+'-closed.img'))
        assert not any(r['committed'] for r in copies((OUT/(stem+'-closed.img')).read_bytes()))
        run(media, model, cpu, video, 'recovery-read-mouse')

    if not args.quick:
        run(OUT/'sd-editor.img', '601a', 'hd6303', 3, 'gpu-fault')
        run(OUT/'sd-editor.img', '601', 'mc6800', 0, 'recovery-auto')
        run(OUT/'sd-editor-full.img', '601', 'mc6800', 0, 'recovery-full')
        # No shared RAM or emulator checkpoint crosses a process boundary.
        for suffix in ('cancel', 'fault', 'cut'):
            media = OUT / f'recovery-{suffix}.img'
            run(OUT/'sd-editor.img', '601', 'mc6800', 0, 'recovery-write-'+suffix, media)
            check(media, [2])
            run(media, '601', 'mc6800', 0, 'recovery-read')

        source = OUT/'recovery-601-mc6800-0.img'
        records = copies(source.read_bytes())
        latest = max(records, key=lambda r: r['generation'])
        for suffix, at in [('payload', 5), ('trailer', len(latest['content'])-2)]:
            corrupt = bytearray(source.read_bytes())
            corrupt[latest['addresses'][at]] ^= 1
            path = OUT / f'recovery-corrupt-{suffix}.img'
            path.write_bytes(corrupt)
            check(path, [1])
            run(path, '601', 'mc6800', 0, 'recovery-read-old')

        declined = OUT/'recovery-declined.img'
        run(source, '601', 'mc6800', 0, 'recovery-decline', declined)
        check(declined, [1, 2])
        run(source, '601', 'mc6800', 0, 'recovery-read-missing')
        large = OUT/'recovery-large.img'
        run(OUT/'sd-editor.img', '601', 'mc6800', 0, 'recovery-write-large', large)
        record = check(large, [1])[0]
        expected = b'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\r\n'*32768+b'UNIQUE LAST LINE\r\nz'
        assert record['content'][:-128] == expected
        run(large, '601', 'mc6800', 0, 'recovery-read-large')
    (OUT/'recovery-results.json').write_text(json.dumps(results, indent=2)+'\n')
    print(f'PASS NC recovery: {len(results)} native runs, independent CRCs and fresh boots')


if __name__ == '__main__':
    main()
