"""Execute the assembled native player, including invalid file paths."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cc', default='cc')
    p.add_argument('--case')
    args = p.parse_args()
    out = ROOT / 'build/audio'
    runner = out / 'test_audio_app'
    subprocess.run([args.cc, '-O2', '-I../pyldin601/src', 'tests/test_audio_app.c', '-o', str(runner)], cwd=ROOT, check=True)
    cases = json.loads((out / 'cases.json').read_text())
    for model in ('601', '601a'):
        for name, case in cases.items():
            if args.case and name != args.case:
                continue
            modes = (0, 1) if name in ('LOOP.YM', 'AYLOOP.VTX') else (0,)
            for looping in modes:
                subprocess.run([str(runner), str(out / 'sd-test.img'), model, name.lower(),
                                str(out / case['oracle']), str(case['rate']), str(case['factor']),
                                str(case['loop']), str(looping), case['error'] or '-',
                                str(out / (name + '.raw'))], cwd=ROOT, check=True)
        if not args.case:
            for name, mode, error in [('LH5BIG.YM', 'fragmented', '-'), ('AYBIG.VTX', 'fragmented', '-'), ('THREE.YM', 'full', 'not enough free')]:
                case = cases[name]
                subprocess.run([str(runner), str(out / 'sd-test.img'), model, name.lower(),
                                str(out / case['oracle']), str(case['rate']), str(case['factor']),
                                str(case['loop']), '0', error, str(out / (name + '.raw'))],
                               cwd=ROOT, check=True, env=dict(os.environ, AUDIO_RAM=mode))
            case = cases['LH5BIG.YM']
            subprocess.run([str(runner), str(out / 'sd-test.img'), model, 'lh5big.ym',
                            str(out / case['oracle']), '50', '256', '0', '0', 'stopped',
                            str(out / 'LH5BIG.YM.raw')], cwd=ROOT, check=True)
            case = cases['THREE.YM']
            for fault, error in [('missing', 'update audio'), ('busy', 'already in use'), ('stuck', 'timed out')]:
                subprocess.run([str(runner), str(out / 'sd-test.img'), model, 'three.ym',
                                str(out / case['oracle']), '50', '256', '0', '0', error,
                                str(out / 'THREE.YM.raw')], cwd=ROOT, check=True,
                               env=dict(os.environ, AUDIO_FAULT=fault))


if __name__ == '__main__':
    main()
