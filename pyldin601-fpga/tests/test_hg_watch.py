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


def wait_image(directory, wanted, timeout=8):
    until = time.monotonic() + timeout
    last = None
    while time.monotonic() < until:
        try:
            last = fat12.root_files((directory / '.p601-hg.img').read_bytes())
            if last == wanted:
                return
        except (OSError, ValueError):
            pass
        time.sleep(.05)
    raise AssertionError(f'image did not update: {last!r} != {wanted!r}')


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
    print('PASS native daemon live add/replace/rename/delete, volume lock, oversized import rejection, TERM/restart and legacy journal migration')


if __name__ == '__main__':
    main()
