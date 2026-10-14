"""Exercise free-space scans and cache transitions through assembled DOS APIs."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
for prepare in ('prepare_partitions.py', 'prepare_fat16.py'):
    subprocess.run([sys.executable, 'tests/' + prepare], cwd=ROOT, check=True)

def run(volume, model='601', cpu='mc6800', card='sdhc', mode=None):
    args = ['build/test_free_space', 'build/fat16/' + volume, model, cpu, card]
    if mode:
        args.append(mode)
    subprocess.run(args, cwd=ROOT, check=True)

for model in ('601', '601a'):
    for cpu in ('mc6800', 'hd6303'):
        for card in ('sdhc', 'sdsc'):
            for volume in ('sd.img', 'wide12.img'):
                run(volume, model, cpu, card)
for volume in ('sd.img', 'wide12.img'):
    for mode in ('empty', 'full'):
        run(volume, mode=mode)
    if os.environ.get('FAT_RAMMAN') == '1':
        for mode in ('no-ram', 'no-e5'):
            run(volume, mode=mode)
