"""Black-box tests of the C daemon and its real directory event loop."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'host/hg'))
import fat12


def tree_files(data):
    # Independent oracle follows on-disk directory chains, never the C parser.
    info, table, _, _, _, root, entries, payload = fat12.layout(data)
    unit = info['sectors_per_cluster'] * 512
    owned = set()
    result = {}
    def chain(first):
        out = bytearray()
        while first < 0xff8:
            assert 2 <= first <= info['clusters'] + 1 and first not in owned
            owned.add(first)
            at = payload + (first - 2) * unit
            out += data[at:at + unit]
            first = fat12.fat_get(table, first)
        return bytes(out)
    def walk(raw, prefix=''):
        for at in range(0, len(raw), 32):
            e = raw[at:at + 32]
            if not e[0]: break
            if e[0] == 0xe5 or e[11] & 8: continue
            name = e[:8].decode('ascii').rstrip()
            ext = e[8:11].decode('ascii').rstrip()
            if ext: name += '.' + ext
            if name in ('.', '..'): continue
            name = prefix + name
            first = fat12.u16(e, 26)
            if e[11] & 16:
                result[name] = None
                walk(chain(first), name + '/')
            else:
                result[name] = chain(first)[:fat12.u32(e, 28)] if first else b''
    walk(data[root:root + entries * 32])
    return result


def wait_image(directory, wanted, timeout=8):
    until = time.monotonic() + timeout
    last = None
    while time.monotonic() < until:
        try:
            last = tree_files((directory / '.p601-hg.img').read_bytes())
            if last == wanted:
                return
        except (OSError, ValueError):
            pass
        time.sleep(.05)
    raise AssertionError(f'image did not update: {last!r} != {wanted!r}')


def journal(directory, snapshot):
    state = bytearray(16); state[:8] = b'P601HG\2\0'; state[8] = 1
    state[10:12] = (32736).to_bytes(2, 'little')
    state[12:14] = len(snapshot).to_bytes(2, 'little')
    export = bytearray(16); export[:8] = b'P601HGX1'
    export[8:10] = len(snapshot).to_bytes(2, 'little')
    for name, (host, data) in snapshot.items():
        a, b = name.encode(), host.encode()
        lengths = len(a).to_bytes(2, 'little') + len(b).to_bytes(2, 'little')
        state += lengths + a + b
        record = bytearray(12); record[:4] = lengths
        record[4:8] = len(data or b'').to_bytes(4, 'little')
        record[8] = 16 if data is None else 32
        export += record + a + b + (data or b'')
    (directory / '.p601-hg.state').write_bytes(state)
    (directory / '.p601-hg.export').write_bytes(export)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--daemon', type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        (directory / 'hello.txt').write_bytes(b'original')
        log = (directory / '.test.log').open('w+b')
        command = [str(args.daemon), '--directory', str(directory), '--watch-only']
        daemon = subprocess.Popen(command, stdout=log, stderr=log)
        try:
            wait_image(directory, {'HELLO.TXT': b'original'})
            original = (directory / '.p601-hg.img').read_bytes()
            (directory / 'LENA.PCX').write_bytes(bytes(range(256)) * 200)
            wait_image(directory, {'HELLO.TXT': b'original', 'LENA.PCX': bytes(range(256)) * 200})
            # Atomic editor replacement, rename and deletion are distinct events.
            (directory / '.editor.tmp').write_bytes(b'replacement')
            os.replace(directory / '.editor.tmp', directory / 'hello.txt')
            wait_image(directory, {'HELLO.TXT': b'replacement', 'LENA.PCX': bytes(range(256)) * 200})
            os.rename(directory / 'hello.txt', directory / 'RENAMED.TXT')
            wait_image(directory, {'RENAMED.TXT': b'replacement', 'LENA.PCX': bytes(range(256)) * 200})
            (directory / 'LENA.PCX').unlink()
            wait_image(directory, {'RENAMED.TXT': b'replacement'})
            # A slow copy must not become a partly imported guest file.
            before = (directory / '.p601-hg.img').read_bytes()
            with (directory / 'SLOW.TXT').open('wb') as f:
                f.write(b'first half'); f.flush()
                time.sleep(2.5)
                if sys.platform.startswith('linux'):
                    assert (directory / '.p601-hg.img').read_bytes() == before
                f.write(b' and second half')
            wait_image(directory, {'RENAMED.TXT': b'replacement', 'SLOW.TXT': b'first half and second half'})
            (directory / 'SLOW.TXT').unlink()
            wait_image(directory, {'RENAMED.TXT': b'replacement'})
            # Nested watches, empty directories, slow writes, and moving an
            # already watched subtree must work without restarting the daemon.
            (directory / 'images' / 'pcx').mkdir(parents=True)
            wanted = {'RENAMED.TXT': b'replacement', 'IMAGES': None, 'IMAGES/PCX': None}
            wait_image(directory, wanted)
            before = (directory / '.p601-hg.img').read_bytes()
            with (directory / 'images' / 'pcx' / 'lena.pcx').open('wb') as f:
                f.write(b'nested first half'); f.flush()
                time.sleep(2.5)
                if sys.platform.startswith('linux'):
                    assert (directory / '.p601-hg.img').read_bytes() == before
                f.write(b' and second half')
            wanted['IMAGES/PCX/LENA.PCX'] = b'nested first half and second half'
            wait_image(directory, wanted)
            os.rename(directory / 'images', directory / 'photos')
            wanted = {name.replace('IMAGES', 'PHOTOS'): value for name, value in wanted.items()}
            wait_image(directory, wanted)
            (directory / 'photos' / 'pcx' / 'lena.pcx').write_bytes(b'edited after directory move')
            wanted['PHOTOS/PCX/LENA.PCX'] = b'edited after directory move'
            wait_image(directory, wanted)
            (directory / 'photos' / 'pcx' / 'lena.pcx').unlink()
            (directory / 'photos' / 'pcx').rmdir()
            (directory / 'photos').rmdir()
            wait_image(directory, {'RENAMED.TXT': b'replacement'})
            duplicate = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
            assert duplicate.returncode != 0
            # Publishing a file larger than the available disk must retain the volume.
            before = (directory / '.p601-hg.img').read_bytes()
            with (directory / 'HUGE.BIN').open('wb') as f:
                f.truncate(17 * 1024 * 1024)
            time.sleep(1.3)
            assert (directory / '.p601-hg.img').read_bytes() == before
            (directory / 'HUGE.BIN').unlink()
            (directory / 'RESUME.TXT').write_bytes(b'recovered')
            wait_image(directory, {'RENAMED.TXT': b'replacement', 'RESUME.TXT': b'recovered'})
            assert daemon.poll() is None
        finally:
            daemon.send_signal(signal.SIGTERM)
            daemon.wait(timeout=10)
            log.close()
        assert daemon.returncode == 0
        # Clean shutdown and the native on-disk journal are restartable.
        result = subprocess.run(command[:-1] + ['--sync-only'], capture_output=True, timeout=10)
        assert result.returncode == 0, result.stderr
        assert fat12.disk_info(original)['clusters'] == 4084
    # Migrate the cache format of the former Python daemon with pending guest writes.
    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        (directory / 'hello.txt').write_bytes(b'original')
        (directory / '.p601-hg.img').write_bytes(fat12.add_files(fat12.blank_disk(), {'HELLO.TXT': b'original', 'BACK.TXT': b'pending guest'}))
        (directory / 'NEW.TXT').write_bytes(b'new host file during legacy crash')
        (directory / '.p601-hg.json').write_text(json.dumps({'dirty': True, 'names': {'HELLO.TXT': 'hello.txt'}}))
        result = subprocess.run([str(args.daemon), '--directory', str(directory), '--sync-only'], capture_output=True, timeout=10)
        assert result.returncode == 0, result.stderr
        assert (directory / 'BACK.TXT').read_bytes() == b'pending guest'
        assert (directory / 'hello.txt').read_bytes() == b'original'
        assert (directory / 'NEW.TXT').read_bytes() == b'new host file during legacy crash'
        assert (directory / '.p601-hg.base').exists()
    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        (directory / 'hello.txt').write_bytes(b'original')
        base = fat12.add_files(fat12.blank_disk(), {'HELLO.TXT': b'original'})
        (directory / '.p601-hg.base').write_bytes(base)
        # Hand-built pending directory/data in an old native journal. This
        # fixture is independent of the C updater and needs no prior build.
        image = bytearray(base)
        _, table, fat_start, fat_size, copies, root, _, payload = fat12.layout(image)
        fat12.fat_set(table, 3, 0xfff); fat12.fat_set(table, 4, 0xfff)
        for copy in range(copies):
            image[fat_start + copy * fat_size:fat_start + (copy + 1) * fat_size] = table
        entry = bytearray(32); entry[:11] = b'DISK_C     '; entry[11] = 16
        entry[26:28] = (3).to_bytes(2, 'little')
        image[root + 32:root + 64] = entry
        at = payload + 4096
        entry[:11] = b'.          '; image[at:at + 32] = entry
        entry[:11] = b'..         '; entry[26:28] = bytes(2)
        image[at + 32:at + 64] = entry
        content = b'pending nested guest'
        entry[:11] = b'UE      CMD'; entry[11] = 32
        entry[26:28] = (4).to_bytes(2, 'little')
        entry[28:32] = len(content).to_bytes(4, 'little')
        image[at + 64:at + 96] = entry
        image[payload + 8192:payload + 8192 + len(content)] = content
        (directory / '.p601-hg.img').write_bytes(image)
        state = bytearray(42)
        state[:8] = b'P601HG\1\0'; state[8] = 1
        state[10:12] = (32736).to_bytes(2, 'little')
        state[12:14] = (1).to_bytes(2, 'little')
        state[16:29] = b'HELLO.TXT\0'.ljust(13, b'\0')
        state[29:42] = b'hello.txt\0'.ljust(13, b'\0')
        (directory / '.p601-hg.state').write_bytes(state)
        result = subprocess.run([str(args.daemon), '--directory', str(directory), '--sync-only'], capture_output=True, timeout=10)
        assert result.returncode == 0, result.stderr
        assert (directory / '.p601-hg.state').read_bytes()[6] == 2
        assert (directory / 'DISK_C' / 'UE.CMD').read_bytes() == content
        assert (directory / 'hello.txt').read_bytes() == b'original'
    # Replay a crash after deleting a directory child, before replacing the
    # directory with a file; an independent host addition must survive.
    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        (directory / 'swap').mkdir()
        (directory / 'swap' / 'A.TXT').write_bytes(b'original child')
        once = [str(args.daemon), '--directory', str(directory), '--sync-only']
        result = subprocess.run(once, capture_output=True, timeout=10)
        assert result.returncode == 0, result.stderr
        (directory / '.p601-hg.img').write_bytes(fat12.add_files(fat12.blank_disk(), {'SWAP': b'desired replacement'}))
        journal(directory, {'SWAP': ('swap', None), 'SWAP/A.TXT': ('swap/A.TXT', b'original child')})
        (directory / 'swap' / 'A.TXT').unlink()
        (directory / 'EXTRA.TXT').write_bytes(b'external addition')
        result = subprocess.run(once, capture_output=True, timeout=10)
        assert result.returncode == 0, result.stderr
        assert (directory / 'swap').read_bytes() == b'desired replacement'
        assert (directory / 'EXTRA.TXT').read_bytes() == b'external addition'
        assert not (directory / '.p601-hg.export').exists()
    # Reverse type change with a partly exported directory, including a host
    # edit inside it. Recovery must complete the tree and retain the host edit.
    for external_edit in (False, True):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / 'hello.txt').write_bytes(b'original')
            (directory / 'disk_c').write_bytes(b'original file')
            once = [str(args.daemon), '--directory', str(directory), '--sync-only']
            result = subprocess.run(once, capture_output=True, timeout=10)
            assert result.returncode == 0, result.stderr
            (directory / '.p601-hg.img').write_bytes(image)
            journal(directory, {'HELLO.TXT': ('hello.txt', b'original'), 'DISK_C': ('disk_c', b'original file')})
            (directory / 'disk_c').unlink(); (directory / 'disk_c').mkdir()
            if external_edit:
                (directory / 'disk_c' / 'UE.CMD').write_bytes(b'external edit while stopped')
            result = subprocess.run(once, capture_output=True, timeout=10)
            assert result.returncode == 0, result.stderr
            expected = b'external edit while stopped' if external_edit else b'pending nested guest'
            assert (directory / 'disk_c' / 'UE.CMD').read_bytes() == expected
            assert (directory / 'hello.txt').read_bytes() == b'original'
            assert not (directory / '.p601-hg.export').exists()
    print('PASS native daemon recursive/empty directory add/replace/rename/delete and slow nested writes, volume lock, oversized import rejection, TERM/restart, old journal migration and partial export recovery with external edits')


if __name__ == '__main__':
    main()
