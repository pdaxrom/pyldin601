"""Compare host UniAS with UNIAS.CMD under real BIOS/UniDOS and both VM ROMs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import struct

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import install,root_files

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--toolchain', type=Path, required=True)
p.add_argument('--cc', default='cc')
p.add_argument('--quick', action='store_true', help='only HD6303 with 601 firmware')
a = p.parse_args()
toolchain = a.toolchain.resolve()
out = ROOT/'build/cvm/native-assembly'
out.mkdir(parents=True, exist_ok=True)
cross = out/'cross'
cross.mkdir(exist_ok=True)
sources = {}

def collect(name, directories):
    matches = [d/name for d in directories if (d/name).is_file()]
    assert len(matches) == 1, f'missing or ambiguous source: {name}'
    path = matches[0]
    data = path.read_bytes()
    if name in sources:
        assert sources[name] == data, f'conflicting include: {name}'
        return
    sources[name] = data
    for match in re.finditer(rb'^\s*include\s+([^\s;]+)', data, re.I|re.M):
        collect(match[1].decode('ascii'), directories)

collect('BIOS.ASM', [ROOT/'firmware/bios',ROOT/'firmware/memory'])
collect('BIOS_A.ASM', [ROOT/'firmware/bios',ROOT/'firmware/memory'])
collect('XONIX.ASM', [ROOT/'firmware/game'])
for name, data in sources.items():
    (cross/name).write_bytes(data)

def run_cross(name):
    flags = ['-D','GAME_MUSIC'] if name == 'XONIX' else []
    binary = f'{name}.PGM' if name == 'XONIX' else f'{name}.ROM'
    with (cross/f'{name}.log').open('wb') as log:
        subprocess.run([str(toolchain/'unias'),*flags,'-l',f'{name}.LST',
                        '-o',binary,f'{name}.ASM'],cwd=cross,stdout=log,
                       stderr=subprocess.STDOUT,check=True)
    assert b'Error:' not in (cross/f'{name}.log').read_bytes()

for name in ('BIOS','BIOS_A','XONIX'):
    run_cross(name)

# UniDOS get_name() truncates each component to 8.3. Store exactly those
# aliases, rejecting collisions. File contents and include directives stay
# byte-for-byte identical on host and target (e.g. ROMRETURNS -> ROMRETUR).
short_sources = {}
aliases = {}
for name, data in sources.items():
    base, ext = name.rsplit('.',1)
    short = base[:8]+'.'+ext[:3]
    assert short not in short_sources, f'8.3 collision: {name}'
    short_sources[short] = data
    aliases[name] = short
image = (ROOT/'images/sd.img').read_bytes()
cvm = ROOT/'build/cvm'
tools = {n:(cvm/n).read_bytes() for n in ('ZVM6800.ROM','ZVM6303.ROM','UNIAS.CMD')}
tools['RAMLOAD.PGM'] = (ROOT/'build/ramloader/RAMLOAD.PGM').read_bytes()
assert tools['UNIAS.CMD'][64:] == (toolchain/'AS03.CMD').read_bytes()[64:], 'native and cross UniAS must use the same bytecode after the platform stub'
mains = {n:short_sources.pop(n) for n in ('BIOS.ASM','BIOS_A.ASM','XONIX.ASM')}
image, _ = install(image, tools|mains|short_sources, replace=True)
image_path = out/'sd-test.img'
image_path.write_bytes(image)
runner = out/'test_native_assembly'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_native_assembly.c',
                '-o',str(runner)],cwd=ROOT,check=True)

report = {'execution':'native UNIAS.CMD on reference CPU with real BIOS/UniDOS and RAMMAN',
          'define':['GAME_MUSIC'],
          'cross_unias_sha256':hashlib.sha256((toolchain/'unias').read_bytes()).hexdigest(),
          'shared_unias_bytecode_sha256':hashlib.sha256(tools['UNIAS.CMD'][64:]).hexdigest(),
          'tools':{n:hashlib.sha256(d).hexdigest() for n,d in tools.items()},
          'sources':{n:{'bytes':len(d),'sha256':hashlib.sha256(d).hexdigest(),
                       'native_name':aliases[n]} for n,d in sources.items()},
          'cases':[]}
cases = [('601','hd6303')] if a.quick else [(m,c) for m in ('601','601a') for c in ('mc6800','hd6303')]
for model, cpu in cases:
    native = out/f'{model}-{cpu}'
    native.mkdir(exist_ok=True)
    print(f'Assembling BIOS, BIOS_A and XONIX on {model}/{cpu}; log: {native/"run.log"}',flush=True)
    with (native/'run.log').open('wb') as log:
        result = subprocess.run([str(runner),str(image_path),model,cpu,str(native)],
                                cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:
        print((native/'run.log').read_text(errors='replace'),file=sys.stderr)
        result.check_returncode()
    results = []
    state=(native/'STATE.IMG').read_bytes()
    start,length=struct.unpack_from('<II',state,486)
    files=root_files(state[start*512:(start+length)*512])
    for name in ('BIOS.ROM','BIOS_A.ROM','XONIX.PGM'):
        expected, actual = (cross/name).read_bytes(),files[name]
        (native/name).write_bytes(actual)
        equal = expected == actual
        results.append({'file':name,'bytes':len(actual),'identical':equal,
                        'cross_sha256':hashlib.sha256(expected).hexdigest(),
                        'native_sha256':hashlib.sha256(actual).hexdigest()})
        if not equal:
            differences = [(i,x,y) for i,(x,y) in enumerate(zip(expected,actual)) if x != y]
            raise AssertionError(f'{model}/{cpu}/{name}: cross {len(expected)} bytes, native {len(actual)}; first differences: {differences[:16]}')
    cycles = {name:int(count) for name,count in re.findall(r'Finished (\w+): (\d+) reference cycles', (native/'run.log').read_text(errors='replace'))}
    report['cases'].append({'model':model,'cpu':cpu,'reference_cycles':cycles,'files':results})
    (out/'comparison.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'PASS {model}/{cpu}: BIOS, BIOS_A, ready-to-load XONIX byte-identical',flush=True)
