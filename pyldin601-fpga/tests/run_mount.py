"""Read-only mounts and native listing on each supported storage configuration."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
for script in ('prepare_partitions.py', 'prepare_fat16.py'):
    subprocess.run([sys.executable, 'tests/'+script], cwd=ROOT, check=True)
for model in ('601', '601a'):
    for cpu in ('mc6800', 'hd6303'):
        for card in ('sdhc', 'sdsc'):
            for image, mode in (('sd.img', 'fat16'), ('wide12.img', 'fat12'),
                                ('header-pool.img', 'pool')):
                subprocess.run(['build/test_mount', 'build/fat16/'+image,
                                model, cpu, card, mode], cwd=ROOT, check=True)
