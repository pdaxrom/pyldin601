"""Run the real UniPascal compiler and shipped interpreter with paged RAM."""
import argparse
from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from add_disk_files import add_files, root_files
from migrate_sd import prepare


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cc', default='cc')
    args = p.parse_args()
    out = ROOT / 'build/ram-pages-ycode'
    out.mkdir(exist_ok=True)
    image, _ = prepare((ROOT / 'images/sd.img').read_bytes(), add_data=False)
    image = bytearray(image)
    start, count = struct.unpack_from('<II', image, 502)
    source = (ROOT / 'tests/y_pages.pas').read_bytes().replace(b'\n', b'\r\n')
    files = {'YPAGES.PAS': source}
    for name in ('UPC.PGM', 'UPL.PGM', 'SYSTEM.UPL'):
        files[name] = (ROOT / 'build/romdisk-extracted/unpacked' / name).read_bytes()
    image[start * 512:(start + count) * 512] = add_files(
        image[start * 512:(start + count) * 512], files, replace=True)
    fixture = out / 'sd-test.img'
    fixture.write_bytes(image)
    runners = {}
    for baseline in (False, True):
        runner = out / ('original' if baseline else 'paged')
        subprocess.run([args.cc, '-O2', '-I../pyldin601/src',
                        *(['-DLEGACY_FIXTURE'] if baseline else []),
                        'tests/test_ram_pages_ycode.c', '-o', str(runner)],
                       cwd=ROOT, check=True)
        runners[baseline] = runner
    for model in ('601', '601a'):
        for cpu in ('mc6800', 'hd6303'):
            compiled = out / f'{model}-{cpu}.img'
            subprocess.run([str(runners[False]), str(fixture), model, cpu, str(compiled)],
                           cwd=ROOT, check=True)
            result = compiled.read_bytes()
            bstart, bcount = struct.unpack_from('<II', result, 486)
            bfiles = root_files(result[bstart * 512:(bstart + bcount) * 512])
            assert bfiles['YPAGES.PGM'].startswith(b'\xc0\xde')
            assert bfiles['YRESULT.TXT'] == b'Y PAGE SUM 220\r\n'
            baseline = out / f'baseline-{model}-{cpu}.img'
            subprocess.run([str(runners[True]), str(compiled), model, cpu, str(baseline)],
                           cwd=ROOT, check=True)
            original_files = root_files(baseline.read_bytes()[bstart * 512:(bstart + bcount) * 512])
            assert original_files['YRESULT.TXT'] == b'Y PAGE SUM 220\r\n'


if __name__ == '__main__':
    main()
