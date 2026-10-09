"""Run the relocatable HVIEW.PGM on the actual VHDL HD6303 and SRAM bus."""
import argparse
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--nvc', default='nvc')
parser.add_argument('--models', nargs='+', type=int, choices=(0, 1), default=[0])
parser.add_argument('--speeds', nargs='+', type=int, choices=(0, 1, 2, 3), default=[3])
parser.add_argument('--unias',default='unias')
args = parser.parse_args()
subprocess.run(['python3', 'tests/prepare_hview.py'], cwd=root, check=True)
subprocess.run(['python3', 'tests/prepare_hview_app.py','--unias',args.unias], cwd=root, check=True)
command = [args.nvc, '--std=2008', '--work=work:build/hview-app', '--ieee-warnings=off']
sources = ['rtl/cpu6800.vhd', *map(str, sorted(Path('rtl').glob('*.v'))),
           'tests/fast_clock.v', 'tests/tb_hview_app.v', 'tests/tb_hview_app.vhd']
subprocess.run([*command, '-a', *sources], cwd=root, check=True)
for model in args.models:
    for speed in args.speeds:
        shutil.copyfile(root/f'build/hview-app-{model}-{speed}.mem', root/'build/hview-app-sram.mem')
        log = root/f'build/hview-app-{model}-{speed}.log'
        with log.open('w') as output:
            subprocess.run([*command, '-e', '-j', f'-gMODEL_A={model}', f'-gSPEED={speed}',
                            'tb_hview_app', '-r', 'tb_hview_app'], cwd=root,
                           stdout=output, stderr=subprocess.STDOUT, check=True)
        passes = [line for line in log.read_text().splitlines() if line.startswith('PASS actual HD6303 HVIEW.PGM')]
        assert len(passes) == 1, log
        print(passes[0], flush=True)
