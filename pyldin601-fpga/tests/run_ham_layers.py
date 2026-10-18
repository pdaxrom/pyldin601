"""Verify lossless HAM8 underlay/foreground and every composed PAL colour.

The native game reads the original IFF. These memory files are independent
test input/oracles only; they are never packaged as game assets or ROM code.
"""
import argparse
from pathlib import Path
import subprocess

from ham8_format import decode, rgb
from test_ham_tables import prepare as prepare_components

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--iverilog', default='iverilog')
p.add_argument('--vvp', default='vvp')
a = p.parse_args()
out = ROOT / 'build/layer'
out.mkdir(parents=True, exist_ok=True)
# tb_pal_ham consumes this independent oracle. Generate it here so this
# target also works before test-ham-pal or any other suite has run.
prepare_components()
codes = decode((ROOT / 'firmware/game/LENA.IFF').read_bytes())
pixels = rgb(codes)
(out / 'LENA-code.mem').write_text(''.join(f'{n:02x}\n' for n in codes))
(out / 'LENA-rgb.mem').write_text(''.join(
    f'{((pixels[i] >> 2) << 12) | ((pixels[i+1] >> 2) << 6) | (pixels[i+2] >> 2):05x}\n'
    for i in range(0, len(pixels), 3)))


def check(name, top, parameters, sources, expected):
    target = out / name
    subprocess.run([a.iverilog, '-g2012', '-s', top, *parameters,
                    '-o', str(target), *map(str, sources)], cwd=ROOT, check=True)
    with (out / (name + '.log')).open('w') as log:
        result = subprocess.run([a.vvp, str(target)], cwd=ROOT, stdout=log,
                                stderr=subprocess.STDOUT, timeout=1200)
    log = (out / (name + '.log')).read_text()
    print(log, end='', flush=True)
    if result.returncode or expected not in log:
        raise RuntimeError(name + ' failed')


check('gfx', 'tb_gfx', ['-Ptb_gfx.LAYER_ONLY=1'],
      sorted((ROOT / 'rtl').glob('*.v')) + [ROOT / 'tests' / n for n in
      ('fast_clock.v', 'pal_viewport_reference.v', 'tb_gfx.v')],
      'PASS lossless HAM8 layers')
for phase in ('0', '5.208'):
    check('pal-' + phase, 'tb_pal_ham',
          ['-Ptb_pal_ham.LAYER=1', '-Ptb_pal_ham.FAST_OFFSET=' + phase],
          [ROOT / 'rtl/classic_pal_encoder.v', ROOT / 'tests/tb_pal_ham.v'],
          'PASS layered HAM8 PAL')
