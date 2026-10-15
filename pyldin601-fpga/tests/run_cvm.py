"""Test the common Small-C bytecode on the host and native 601/601A CPUs."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import install

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--toolchain', type=Path, required=True)
p.add_argument('--cc', default='cc')
p.add_argument('--quick', action='store_true')
a = p.parse_args()
out = ROOT/'build/cvm'
with (out/'host-test.log').open('wb') as log:
    subprocess.run([str(a.toolchain.resolve()/'scvm'), 'CVMTEST.CMD'], cwd=out,
                   stdout=log, stderr=subprocess.STDOUT, check=True)
assert b'CVM TEST PASS' in (out/'host-test.log').read_bytes()
files = {n: (out/n).read_bytes() for n in ('ZVM6303.ROM','ZVM6800.ROM','HELLO.CMD',
         'CVMTEST.CMD','NATIVE.CMD','UNICC.CMD','UNIAS.CMD','SYSTEM.H','HELLO.C')}
files['RAMLOAD.PGM'] = (ROOT/'build/ramloader/RAMLOAD.PGM').read_bytes()
image, _ = install((ROOT/'images/sd.img').read_bytes(), files, replace=True)
image, _ = install(image, {'SYSTEM.H': files['SYSTEM.H']}, drive='A', replace=True)
(out/'sd-test.img').write_bytes(image)
runner = out/'test_cvm'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_cvm.c','-o',str(runner)],cwd=ROOT,check=True)
cases = [('601','mc6800','normal')] if a.quick else [(m,c,s) for m in ('601','601a') for c in ('mc6800','hd6303') for s in ('normal','offset')]
for model,cpu,scenario in cases:
    subprocess.run([str(runner),str(out/'sd-test.img'),model,cpu,scenario],cwd=ROOT,check=True)
