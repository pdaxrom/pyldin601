"""Build the canonical Small-C toolchain and copy its FPGA target outputs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--toolchain', type=Path, required=True)
a = p.parse_args()
tc = a.toolchain.resolve()
out = ROOT/'build/cvm'
out.mkdir(parents=True, exist_ok=True)
with (out/'toolchain-build.log').open('wb') as log:
    subprocess.run(['make', 'pyldin'], cwd=tc, stdout=log, stderr=subprocess.STDOUT, check=True)
names = ['ZVM6303.ROM', 'ZVM6800.ROM', 'UNIAS.CMD', 'UNICC.CMD', 'UNILD.CMD', 'UNIAR.CMD', 'SYSTEM.H',
         'CVMDEF.INC', 'CVMABI.INC', 'CSTART.OBJ', 'CRT.LIB']
for name in names:
    shutil.copyfile(tc/'pyldin'/name, out/name)
for source in (ROOT/'firmware/cvm').iterdir():
    shutil.copyfile(source, out/source.name)
    names.append(source.name)
for name in ('UNILD.C','UNIAR.C','TOOLIO.C','CVMOBJ.TXT',
             'CSTART.ASM','CEND.ASM','CVCALL.ASM'):
    shutil.copyfile(tc/name, out/name)
    names.append(name)
for name in ('HELLO', 'CVMTEST', 'NATIVE'):
    assert all(len(line) <= 79 for line in (out/(name+'.C')).read_text().splitlines()), 'Small-C source lines must fit 79 columns'
    for cmd in ([str(tc/'unicc'), '-o', name+'.ASM', name+'.C'],
                [str(tc/'unias'), '-l', name+'.LST', '-o', name+'.CMD', name+'.ASM']):
        with (out/(name+'-'+Path(cmd[0]).name+'.log')).open('wb') as log:
            subprocess.run(cmd, cwd=out, stdout=log, stderr=subprocess.STDOUT, check=True)
        if Path(cmd[0]).name == 'unicc':
            assert b'There were 0 errors' in (out/(name+'-unicc.log')).read_bytes(), 'Small-C reported compilation errors'
    names.extend([name+'.CMD', name+'.C'])
for name in ('ZVM6303.ROM', 'ZVM6800.ROM'):
    data = (out/name).read_bytes()
    assert len(data) == 8192 and sum(data)%256 == 0
    assert data[:2] == bytes.fromhex('5aa5') and data[16] == 0xef
metadata = {n: dict(bytes=(out/n).stat().st_size,
                   sha256=hashlib.sha256((out/n).read_bytes()).hexdigest()) for n in names}
(out/'manifest.json').write_text(json.dumps(metadata, indent=2)+'\n')
print('Built both CPU ROMs, native tools and common C test programs:', out)
