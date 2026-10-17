"""Run UART terminal/XMODEM and diagnostics under real native BIOS/UniDOS."""
from pathlib import Path
import argparse
import json
import subprocess
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import install

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--cc', default='cc')
p.add_argument('--quick', action='store_true')
p.add_argument('--terminal-only', action='store_true')
p.add_argument('--hg', action='store_true', help='also run transfers through actual resident HG')
p.add_argument('--stress', action='store_true', help='also test empty/32771-byte files and 115200 at 8 MHz')
p.add_argument('--payload-size', type=int, default=257, choices=(0, 257, 32771))
a = p.parse_args()
out = ROOT/'build/input'
files = {n+'.PGM': (out/(n+'.PGM')).read_bytes() for n in ('UART', 'UARTTEST')}
files['HG.PGM'] = (ROOT/'build/hg/HG.PGM').read_bytes()
files['SEND.BIN'] = bytes(((k*73)^(k>>8)^(k>>3))&255 for k in range(a.payload_size))
sd, metadata = install((ROOT/'images/sd.img').read_bytes(), files, replace=True)
(out/'uart-sd.img').write_bytes(sd)
(out/'uart-sd.json').write_text(json.dumps(metadata, indent=2)+'\n')
names = ['terminal'] if a.terminal_only else ['app', 'binary', 'terminal']
for name in names:
    subprocess.run([a.cc, '-O2', '-I../pyldin601/src', f'tests/test_uart_{name}.c',
                    *(['host/hg/fat12.c', 'host/hg/volume.c'] if name == 'terminal' else []),
                    '-o', str(out/f'test_uart_{name}')], cwd=ROOT, check=True)
for model in ('601', '601a'):
    for cpu in ('mc6800', 'hd6303'):
        if not a.terminal_only:
            rates = ['default', '115200', 'bad', 'missing'] if a.quick else [
                'default', '150', '300', '600', '1200', '2400', '4800', '9600',
                '19200', '38400', '57600', '115200', 'bad', 'missing']
            for rate in rates:
                subprocess.run([str(out/'test_uart_app'), str(out/'uart-sd.img'),
                                model, cpu, rate], cwd=ROOT, check=True)
            subprocess.run([str(out/'test_uart_binary'), str(out/'uart-sd.img'),
                            model, cpu], cwd=ROOT, check=True)
        modes = (0,) if a.quick else ((0, 3) if model == '601' else (0, 4, 3))
        for mode in modes:
            subprocess.run([str(out/'test_uart_terminal'), str(out/'uart-sd.img'),
                            model, cpu, str(mode), str(a.payload_size)], cwd=ROOT, check=True)

        if a.hg:
            host = out/f'host-{model}-{cpu}'
            if host.exists():
                shutil.rmtree(host)
            host.mkdir()
            for name in ('UART.PGM', 'SEND.BIN'):
                (host/name).write_bytes(files[name])
            subprocess.run([str(out/'test_uart_terminal'), str(out/'uart-sd.img'),
                            model, cpu, '4' if model == '601a' else '0',
                            str(a.payload_size), '1', str(host)], cwd=ROOT, check=True)

if a.stress:
    for count, clock in ((0, 1), (32771, 1), (257, 8)):
        stress_files = dict(files)
        stress_files['SEND.BIN'] = bytes(((k*73)^(k>>8)^(k>>3))&255 for k in range(count))
        data, _ = install((ROOT/'images/sd.img').read_bytes(), stress_files, replace=True)
        media = out/f'uart-stress-{count}-{clock}.img'
        media.write_bytes(data)
        for model in ('601', '601a'):
            for cpu in ('mc6800', 'hd6303'):
                subprocess.run([str(out/'test_uart_terminal'), str(media), model, cpu,
                                '4' if model == '601a' else '0', str(count), str(clock)], cwd=ROOT, check=True)
