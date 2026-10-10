"""Install the assembled diagnostic on a disposable B: and execute it."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from add_disk_files import install


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cc', default='cc')
    args = parser.parse_args()
    out = ROOT / 'build/memory-test'
    image, _ = install((ROOT / 'images/sd.img').read_bytes(),
                       {'RAMPAGE.PGM': (out / 'RAMPAGE.PGM').read_bytes()}, replace=True)
    fixture = out / 'sd-test.img'
    fixture.write_bytes(image)
    runner = out / 'test_memory_app'
    subprocess.run([args.cc, '-O2', '-I../pyldin601/src', 'tests/test_memory_app.c',
                    '-o', str(runner)], cwd=ROOT, check=True)
    for model in ('601', '601a'):
        for cpu in ('mc6800', 'hd6303'):
            subprocess.run([str(runner), str(fixture), model, cpu, '0'], cwd=ROOT, check=True)
    for scenario in ('1', '2'):
        subprocess.run([str(runner), str(fixture), '601', 'hd6303', scenario], cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
