"""Run the relocatable VIEW.PGM on the actual VHDL HD6303 and SRAM bus."""
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
subprocess.run(['python3', 'tests/prepare_view.py'], cwd=root, check=True)
subprocess.run(['python3', 'tests/prepare_view_app.py'], cwd=root, check=True)
command = [args.nvc, '--std=2008', '--work=work:build/view-app', '--ieee-warnings=off']
sources = ['rtl/cpu6800.vhd', *map(str, sorted(Path('rtl').glob('*.v'))),
           'tests/fast_clock.v', 'tests/tb_view_app.v', 'tests/tb_view_app.vhd']
subprocess.run([*command, '-a', *sources], cwd=root, check=True)
for model in args.models:
    for speed in args.speeds:
        shutil.copyfile(root/f'build/view-app-{model}-{speed}.mem', root/'build/view-app-sram.mem')
        log = root/f'build/view-app-{model}-{speed}.log'
        with log.open('w') as output:
            subprocess.run([*command, '-e', '-j', f'-gMODEL_A={model}', f'-gSPEED={speed}',
                            'tb_view_app', '-r', 'tb_view_app'], cwd=root,
                           stdout=output, stderr=subprocess.STDOUT, check=True)
        passes = [line for line in log.read_text().splitlines() if line.startswith('PASS actual HD6303 VIEW.PGM')]
        assert len(passes) == 1, log
        print(passes[0], flush=True)
