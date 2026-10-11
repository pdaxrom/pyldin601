"""Native UniDOS demo: HAM pixels, clipping, music, pause, EOF and cleanup."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cc', default='cc')
parser.add_argument('--cases', nargs='+', default=['DEMOH5.YM', 'LOOP.YM', 'SIX.YM',
    'LOG.PSG', 'WAIT.PSG', 'LH5BIG.YM', 'BADCRC.YM', 'BADEND.YM', 'HUGE.YM'])
args = parser.parse_args()
out = ROOT / 'build/gfxmusic'
runner = out / 'test_gfxmusic'
subprocess.run([args.cc, '-O2', '-I../pyldin601/src', 'tests/test_gfxmusic.c', '-o', str(runner)], cwd=ROOT, check=True)
cases = json.loads((ROOT / 'build/audio/cases.json').read_text())

def run(model, name, looping=0, error=None, env=None):
    case = cases[name]
    variant = ('audio-'+env['AUDIO_FAULT'] if env and 'AUDIO_FAULT' in env else 'gfx-'+env['GFX_FAULT'] if env and 'GFX_FAULT' in env else error or 'normal')
    log = out / f'native-{model}-{name}-{looping}-{variant}.log'
    command = [str(runner), str(out / 'sd-test.img'), model, name.lower(),
               str(ROOT / 'build/audio' / case['oracle']), str(case['rate']),
               str(case['factor']), str(case['loop']), str(looping),
               error or case['error'] or '-', str(ROOT / 'build/audio' / (name + '.raw'))]
    with log.open('w') as output:
        subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, env=env, check=True)
    for line in log.read_text().splitlines():
        if line.startswith('PASS'):
            print(line, flush=True)

for model in ('601', '601a'):
    for name in args.cases:
        run(model, name, looping=int(name == 'DEMOH5.YM'))
    run(model, 'LH5BIG.YM', error='stopped')
    for fault, error in [('missing', 'update audio'), ('busy', 'already in use'), ('stuck', 'timed out')]:
        run(model, 'THREE.YM', error=error, env=dict(os.environ, AUDIO_FAULT=fault))
    for fault, error in [('missing', 'needs graphics v5'), ('version', 'needs graphics v5'), ('busy', 'graphics already in use')]:
        run(model, 'THREE.YM', error=error, env=dict(os.environ, GFX_FAULT=fault))
