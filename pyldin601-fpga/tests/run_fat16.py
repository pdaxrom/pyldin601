"""Run native FAT16 code on both machines, CPUs and SD addressing modes."""
from pathlib import Path
import subprocess
import sys
import os

ROOT = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, 'tests/prepare_partitions.py'], cwd=ROOT, check=True)
subprocess.run([sys.executable, 'tests/prepare_fat16.py'], cwd=ROOT, check=True)
(ROOT / 'build/fdisk-ui').mkdir(parents=True, exist_ok=True)
for model in ('601', '601a'):
    for cpu in ('mc6800', 'hd6303'):
        for card in ('sdhc', 'sdsc'):
            args = ['build/fat16/sd.img', model, cpu, card]
            subprocess.run(['build/test_fat16', *args], cwd=ROOT, check=True)
            for volume in ('after.img', 'formatted.img', 'small16.img'):
                subprocess.run([sys.executable, 'tests/check_fat_volume.py', 'build/fat16/'+volume], cwd=ROOT, check=True)
            subprocess.run(['build/test_fat16_tools', *args], cwd=ROOT, check=True)
            subprocess.run(['build/test_fdisk_ui', model, cpu, card], cwd=ROOT, check=True)
            subprocess.run([sys.executable, 'tests/check_fat_volume.py', 'build/fdisk-ui/formatted.img'], cwd=ROOT, check=True)
            subprocess.run(['build/test_fat16_tools', *args, 'resize-overlap'], cwd=ROOT, check=True)
            subprocess.run(['build/test_fat16_tools', *args, 'overwrite'], cwd=ROOT, check=True)
            subprocess.run([sys.executable, 'tests/check_fat_volume.py', 'build/fat16/overwrite.img'], cwd=ROOT, check=True)
            subprocess.run(['build/test_fat16_tools', 'build/fat16/header-pool.img', model, cpu, card, 'header-pool'], cwd=ROOT, check=True)
            subprocess.run(['build/test_fat16', 'build/fat16/wide12.img', model, cpu, card, 'wide12'], cwd=ROOT, check=True)
            subprocess.run([sys.executable, 'tests/check_fat_volume.py', 'build/fat16/wide12-after.img'], cwd=ROOT, check=True)
for mode in ('full', 'empty'):
    subprocess.run(['build/test_fdisk_ui', '601', 'mc6800', 'sdhc', mode], cwd=ROOT, check=True)
if os.environ.get('FAT_RAMMAN') == '1':
    for fault in ('no-ram', 'no-e5', 'no-e8', 'exhausted', 'no-copy', 'bad-copy', 'no-file-copy', 'bad-file-copy'):
        subprocess.run(['build/test_fat16', 'build/fat16/sd.img', '601', 'mc6800', 'sdhc', fault], cwd=ROOT, check=True)
