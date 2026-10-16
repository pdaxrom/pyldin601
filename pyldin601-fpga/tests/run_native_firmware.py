"""Compare direct firmware/object builds on the host and native HG/UniDOS."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import install

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--toolchain', type=Path, required=True)
p.add_argument('--cc', default='cc')
p.add_argument('--jobs', type=int, default=1)
p.add_argument('--quick', action='store_true', help='601/HD6303 only')
p.add_argument('--resume', action='store_true', help='reuse already verified native outputs')
a = p.parse_args()
tc = a.toolchain.resolve()
out = ROOT/'build/bss-native/native-firmware'
cross = out/'cross'
cross.mkdir(parents=True, exist_ok=True)
sources = {}
commands = []
expected = []

def collect(path):
    data = path.read_bytes()
    if path.name in sources:
        assert sources[path.name] == data, f'conflicting source: {path}'
        return
    sources[path.name] = data
    for match in re.finditer(rb'^\s*include\s+([^\s;]+)', data, re.I|re.M):
        name = match[1].decode()
        matches = [d/name for d in (path.parent, ROOT/'firmware/game',
                   ROOT/'firmware/gfx', ROOT/'firmware/audio',
                   ROOT/'firmware/memory', ROOT/'firmware/nc') if (d/name).is_file()]
        assert matches, (path, name)
        collect(matches[0])

def assemble(path, output=None, flags=''):
    collect(path)
    output = output or path.stem+'.PGM'
    commands.append(f'unias {flags} -o {output} {path.name}')
    expected.append(output)

for name in ('NC', 'NCELOAD'):
    assemble(ROOT/f'firmware/nc/{name}.ASM')
for path in sorted((ROOT/'firmware/nc').glob('*.ASM')):
    if path.stem not in ('NC', 'NCELOAD'):
        assemble(path, path.stem+'.OBJ', '-c')
for name in ('NCMAIN.LNK', 'NCEDIT.LNK'):
    sources[name] = (ROOT/'firmware/nc'/name).read_bytes()
assemble(ROOT/'firmware/input/MOUSE.ASM', 'MOUSE.OBJ', '-D MOUSE_OBJECT -c')
commands += ['uniar r NCUI.LIB NCCOM.OBJ NCKEY.OBJ MOUSE.OBJ',
             'unild -m NCMAIN.MAP -o NCMAIN.PGM @NCMAIN.LNK',
             'unild -m NCEDIT.MAP -o NCECORE.PGM @NCEDIT.LNK',
             'unild -b -o NCEDIT.PGM NCELOAD.PGM NCECORE.PGM']
expected += ['NCUI.LIB', 'NCMAIN.PGM', 'NCMAIN.MAP', 'NCECORE.PGM',
             'NCEDIT.MAP', 'NCEDIT.PGM']
for path in sorted((ROOT/'firmware/paint').glob('*.ASM')):
    if path.stem not in ('PNTNAT', 'PNTRGB', 'PNTHAM', 'PNTBOOT'):
        assemble(path, path.stem+'.OBJ', '-c')
assemble(ROOT/'firmware/paint/PNTBOOT.ASM')
sources['PAINT.LNK'] = (ROOT/'firmware/paint/PAINT.LNK').read_bytes()
commands += ['uniar r PNTCOM.LIB PNTCOM.OBJ NCKEY.OBJ MOUSE.OBJ',
             'unild -m PAINT.MAP -o PNTCORE.PGM @PAINT.LNK',
             'unild -b -o PAINT.PGM PNTBOOT.PGM PNTCORE.PGM']
expected += ['PNTCOM.LIB', 'PAINT.MAP', 'PNTCORE.PGM', 'PAINT.PGM']
for directory, names in (
    ('game', ('ARKANOID', 'XONIX', 'SDKTEST')),
    ('gfx', ('VIEW', 'HVIEW', 'HAM', 'SPRITES', 'CLIPSPR')),
    ('audio', ('YPLAY', 'GFXMUSIC')),
    ('hg', ('HG',)),
    ('storage', ('MOUNT', 'UMOUNT', 'FDISK')),
    ('memory', ('RAMPAGE',)),
    ('input', ('UART',)),
    ('paint', ('PNTNAT', 'PNTRGB', 'PNTHAM')),
    ('ramloader', ('RAMLOAD', 'RAMCORE', 'RAMCHECK')),
):
    for name in names:
        flags = '-D GAME_MUSIC' if name in ('ARKANOID', 'XONIX') else ''
        if name == 'GFXMUSIC': flags = '-D GFXMUSIC_DEMO'
        assemble(ROOT/f'firmware/{directory}/{name}.ASM',
                 'RAMPREF.PGM' if name == 'RAMLOAD' else None, flags)
assemble(ROOT/'firmware/hg/HG.ASM', 'HGTIME.PGM', '-D TIME_ONLY')
assemble(ROOT/'firmware/storage/MOUNT.ASM', 'FORMAT.PGM', '-D FORMAT_TOOL')
assemble(ROOT/'firmware/memory/RAMPAGE.ASM', 'RAMALLOC.PGM', '-D ALLOCATED_TEST')
assemble(ROOT/'docs/examples/GFXAY.ASM')
commands += ['unild -b -o RAMLOAD.PGM RAMPREF.PGM RAMCORE.PGM']
expected += ['RAMLOAD.PGM']
for name, data in sources.items():
    (cross/name).write_bytes(data)
# A changed archive member list must not retain obsolete members from a run.
(cross/'PNTCOM.LIB').unlink(missing_ok=True)
for i, command in enumerate(commands):
    args = command.split()
    with (cross/f'{i}.log').open('wb') as log:
        subprocess.run([str(tc/args[0]), *args[1:]], cwd=cross, stdout=log,
                       stderr=subprocess.STDOUT, check=True)

native = {n:(tc/'pyldin'/n).read_bytes() for n in
          ('UNIAS.CMD', 'UNILD.CMD', 'UNIAR.CMD', 'ZVM6800.ROM', 'ZVM6303.ROM')}
native['RAMLOAD.PGM'] = (ROOT/'build/ramloader/RAMLOAD.PGM').read_bytes()
image, _ = install((ROOT/'images/sd.img').read_bytes(),
                   {'HG.PGM':(ROOT/'build/hg/HG.PGM').read_bytes()}, replace=True)
sd = out/'SD.IMG'
sd.write_bytes(image)
commandfile = out/'commands.txt'
commandfile.write_text('\n'.join('cvm\\'+c for c in commands)+'\n')
runner = out/'test_native_firmware'
subprocess.run([a.cc, '-O2', '-DNATIVE_TOOLS_HG', '-I../pyldin601/src',
                'tests/test_native_tools.c', 'host/hg/fat12.c', 'host/hg/volume.c',
                '-o', str(runner)], cwd=ROOT, check=True)

def run_case(case):
    model, cpu = case
    result = out/(model+'-'+cpu)
    host = result/'host'
    if host.exists() and not a.resume: shutil.rmtree(host)
    cvm = host/'CVM'
    cvm.mkdir(parents=True, exist_ok=True)
    for name, data in native.items(): (cvm/name).write_bytes(data)
    aliases = set()
    for name, data in sources.items():
        stem, ext = name.rsplit('.', 1)
        short = stem[:8]+'.'+ext[:3]
        assert short not in aliases, f'8.3 collision: {name}'
        aliases.add(short)
        (host/short).write_bytes(data)
    print('Native firmware:', model, cpu, 'log:', result/'run.log', flush=True)
    (host/'PNTCOM.LIB').unlink(missing_ok=True)
    pending = []
    for command in commands:
        args = command.split()
        outputs = [args[args.index('-o')+1]] if '-o' in args else [args[2]]
        if '-m' in args: outputs.append(args[args.index('-m')+1])
        if not a.resume or any(not (host/n).is_file() or
             (host/n).read_bytes() != (cross/n).read_bytes() for n in outputs):
            pending.append('cvm\\'+command)
    local_commands = result/'commands.txt'
    local_commands.write_text('\n'.join(pending)+'\n')
    with (result/'run.log').open('wb') as log:
        status = subprocess.run([str(runner), str(sd), model, cpu, str(result),
            str(local_commands), str(host), '/'], cwd=ROOT, stdout=log,
            stderr=subprocess.STDOUT)
    if status.returncode:
        print((result/'run.log').read_text(errors='replace')[-6500:])
        status.check_returncode()
    files = []
    for name in expected:
        actual, want = (host/name).read_bytes(), (cross/name).read_bytes()
        assert actual == want, (model, cpu, name, len(actual), len(want))
        files.append({'name':name, 'bytes':len(actual),
                      'sha256':hashlib.sha256(actual).hexdigest()})
    print('PASS native firmware:', model, cpu, len(files), 'identical files', flush=True)
    return {'model':model, 'cpu':cpu, 'files':files}

cases = [('601', 'hd6303')] if a.quick else [
    (m, c) for m in ('601', '601a') for c in ('mc6800', 'hd6303')]
with ThreadPoolExecutor(max_workers=a.jobs) as pool:
    results = list(pool.map(run_case, cases))
(out/'comparison.json').write_text(json.dumps({'commands':commands,
    'execution':'native HG resident, HANDLES 16, CPU-selected RAMMAN VM',
    'cases':results}, indent=2)+'\n')
