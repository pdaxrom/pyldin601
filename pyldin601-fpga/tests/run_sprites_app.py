"""Run the real SPRITES.PGM on the actual HD6303 VHDL core and SRAM pads."""
import argparse
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--nvc', default='nvc')
parser.add_argument('--models', nargs='+', type=int, choices=(0, 1), default=[0, 1])
parser.add_argument('--speeds', nargs='+', type=int, choices=(0, 1, 2, 3), default=[0, 1, 2, 3])
args = parser.parse_args()
subprocess.run(['python3', 'tests/prepare_sprites_app.py'], cwd=root, check=True)
command = [args.nvc, '--std=2008', '--work=work:build/sprites-app', '--ieee-warnings=off']
sources = ['rtl/cpu6800.vhd', *map(str, sorted(Path('rtl').glob('*.v'))),
           'tests/fast_clock.v', 'tests/tb_sprites_app.v', 'tests/tb_sprites_app.vhd']
subprocess.run([*command, '-a', *sources], cwd=root, check=True)
for model in args.models:
    for speed in args.speeds:
        shutil.copyfile(root/f'build/sprites-app-{model}-{speed}.mem', root/'build/sprites-app-sram.mem')
        log = root/f'build/sprites-app-{model}-{speed}.log'
        with log.open('w') as output:
            subprocess.run([*command, '-e', '-j', f'-gMODEL_A={model}', f'-gSPEED={speed}',
                            'tb_sprites_app', '-r', 'tb_sprites_app'], cwd=root,
                           stdout=output, stderr=subprocess.STDOUT, check=True)
        passes = [line for line in log.read_text().splitlines() if line.startswith('PASS actual HD6303 SPRITES.PGM')]
        assert len(passes) == 1, log
        print(passes[0], flush=True)
