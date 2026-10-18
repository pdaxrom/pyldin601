#!/usr/bin/env python3
"""Check the physical-test JOBs in native DOS and compare native tool outputs."""
import argparse
import json
import os
from pathlib import Path
import tempfile
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from prepare_board_check import payload
from package_release import fat12_tree

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--fixtures', type=Path, default=ROOT)
p.add_argument('--release', type=Path, required=True)
p.add_argument('--toolchain', type=Path, required=True)
p.add_argument('--quick', action='store_true')
a = p.parse_args()
fixtures, release, tc = a.fixtures.resolve(), a.release.resolve(), a.toolchain.resolve()
out = ROOT / 'build/board-check'
out.mkdir(parents=True, exist_ok=True)
files = payload(release / 'hg/CVM', tc)
media = release / 'sd.img'
original = {'REL1017/' + p.relative_to(release / 'hg').as_posix(): p.read_bytes()
            for p in (release / 'hg').rglob('*') if p.is_file()}
runner = out / 'test_board_job'
subprocess.run([os.environ.get('CC', 'cc'), '-O2', '-I' + str(ROOT.parent / 'pyldin601/src'),
                str(ROOT / 'tests/test_board_job.c'), str(ROOT / 'host/hg/fat12.c'),
                str(ROOT / 'host/hg/volume.c'), '-o', str(runner)], check=True)

# Build the same sources on the host; native results must match exactly.
cross = out / 'cross'
cross.mkdir(exist_ok=True)
for n, d in files.items():
    if '/' not in n:
        (cross / n).write_bytes(d)
commands = []
for raw in files['AUTO.JOB'].decode('ascii').splitlines():
    if not raw.startswith('%2\\'):
        continue
    command = raw.split(' > ')[0][3:].split()
    tool = command.pop(0).lower()
    if tool not in ('unicc', 'unias', 'unild', 'uniar'):
        continue
    commands.append([str(tc / tool), *command])
(cross / 'TEST.LIB').unlink(missing_ok=True)
for i, command in enumerate(commands):
    with (cross / f'{i}.log').open('wb') as log:
        subprocess.run(command, cwd=cross, stdout=log, stderr=subprocess.STDOUT, check=True)
expected = ['OUT.ASM', 'OUT.CMD', 'OMAIN.OBJ', 'OHELP.OBJ', 'PLAIN.PGM',
            'TEST.LIB', 'OBJLIB.PGM', 'MIX.ASM', 'MIX.OBJ', 'MINLINE.ASM',
            'MINLINE.OBJ', 'MNATIVE.OBJ', 'NENTRY.OBJ', 'MIXAPP.PGM', 'NENTRY.PGM']
cases = [('601', 'hd6303')] if a.quick else [(m, c) for m in ('601', '601a') for c in ('mc6800', 'hd6303')]
report = {'execution': 'original UniDOS executes CHECK.JOB/AUTO.JOB through the resident HG using packaged programs', 'cases': []}
for model, cpu in cases:
    started = time.time()
    case = out / (model + '-' + cpu)
    case.mkdir(exist_ok=True)
    host = Path(tempfile.mkdtemp(prefix='host-', dir=case))
    for name, data in (original | {'BOARDCHK/' + n: d for n, d in files.items()}).items():
        path = host / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    state = case / 'state.img'
    with (case / 'run.log').open('wb') as log:
        result = subprocess.run([str(runner), str(media), model, cpu, str(state), str(host)],
                                cwd=fixtures, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print((case / 'run.log').read_text(errors='replace')[-6000:])
        result.check_returncode()
    actual = fat12_tree(state.read_bytes())
    for name, data in original.items():
        assert actual[name] == data, ('installed release file changed', name)
    for name, data in files.items():
        assert actual['BOARDCHK/' + name] == data, ('test input changed', name)
    assert 'BOARDCHK/CVMIO.DAT' not in actual
    for name in expected:
        data = actual['BOARDCHK/' + name]
        assert data == (cross / name).read_bytes(), (model, cpu, name)
        (case / name).write_bytes(data)
    report['cases'].append(dict(model=model, cpu=cpu, identical_outputs=len(expected),
                               seconds=round(time.time() - started, 2)))
    (out / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS JOB {model}/{cpu}: {len(expected)} native outputs identical, stage results checked, release untouched', flush=True)
