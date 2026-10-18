"""Run the real diagnostic with native DOS and independent scripted SPI cards."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from add_disk_files import install

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--fixtures', type=Path, default=ROOT)
p.add_argument('--cc', default='cc')
a = p.parse_args()
fixtures = a.fixtures.resolve()
out = ROOT / 'build/sdprobe'
out.mkdir(parents=True, exist_ok=True)
unias = os.environ.get('UNIAS', str(ROOT.parents[2] / 'FPGA/hd6303-toolchain/unias'))
shutil.copyfile(ROOT / 'firmware/storage/SDPROBE.ASM', out / 'SDPROBE.ASM')
with (out / 'assemble.log').open('w') as log:
    subprocess.run([unias, '-l', 'SDPROBE.LST', '-o', 'SDPROBE.PGM', 'SDPROBE.ASM'],
                   cwd=out, stdout=log, stderr=subprocess.STDOUT, check=True)
image, _ = install((ROOT / 'images/sd.img').read_bytes(),
                   {'SDPROBE.PGM': (out / 'SDPROBE.PGM').read_bytes()}, replace=True)
(out / 'test-sd.img').write_bytes(image)
runner = out / 'test_sdprobe'
subprocess.run([a.cc, '-O2', '-I' + str(ROOT.parent / 'pyldin601/src'),
                str(ROOT / 'tests/test_sdprobe.c'), '-o', str(runner)], check=True)
for model in ('601', '601a'):
    for cpu in ('mc6800', 'hd6303'):
        for scenario in range(4):
            subprocess.run([str(runner), str(out / 'test-sd.img'), model, cpu, str(scenario)],
                           cwd=fixtures, check=True)
