"""Exercise real GAMEBIOS ROM with native UniDOS on both models and ISAs."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from unias import assemble
from add_disk_files import install

p = argparse.ArgumentParser()
p.add_argument('--unias', required=True)
p.add_argument('--cc', default='cc')
a = p.parse_args()
out = ROOT / 'build/gamebios'
out.mkdir(parents=True, exist_ok=True)
shutil.copyfile(ROOT / 'firmware/game/GAMEBIOS.INC', out / 'GAMEBIOS.INC')
(out / 'GAMELEAK.ASM').write_text('''    include GAMEBIOS.INC
    ldx #context
    ldd #GB_CONTEXT_BYTES
    std 0,x
    ldaa #GB_ABI
    staa 2,x
    ldaa #3
    staa 3,x
    ldaa #GB_OPEN
    int GB_INT
    tsta
    bne failed
    ldaa #GB_MODE
    ldab #1
    int GB_INT
    tsta
    bne failed
    ldaa #7
    staa GB_PS2_CONTROL
    clra
    int $38
failed
    ldaa #1
    int $38
context ds GB_CONTEXT_BYTES
    end
''')
leak = assemble(a.unias, out, 'GAMELEAK.ASM', 'GAMELEAK.PGM')
subprocess.run(['make', '-s', '-f', 'firmware/Makefile', 'game', 'UNIAS='+a.unias], cwd=ROOT, check=True)
image, _ = install((ROOT / 'images/sd.img').read_bytes(), {'GAMELEAK.PGM': leak, 'ARKANOID.PGM': (ROOT/'build/game/ARKANOID.PGM').read_bytes(), 'SDKTEST.PGM': (ROOT/'build/game/SDKTEST.PGM').read_bytes()}, replace=True)
(out / 'sd-test.img').write_bytes(image)
coef = (ROOT / 'firmware/gfx/PALCOEF.ASM').read_text()
(out / 'coeff.bin').write_bytes(bytes(int(x, 16) for x in re.findall(r'\$([0-9a-fA-F]{2})', coef)))
runner = out / 'test_gamebios'
subprocess.run([a.cc, '-O2', '-I../pyldin601/src', 'tests/test_gamebios.c', '-o', str(runner)], cwd=ROOT, check=True)
for model in ('601', '601a'):
    for cpu in ('mc6800', 'hd6303'):
        subprocess.run([str(runner), str(out / 'sd-test.img'), model, cpu], cwd=ROOT, check=True)
runner = out / 'test_game_app'
subprocess.run([a.cc, '-O2', '-I../pyldin601/src', 'tests/test_game_app.c', '-o', str(runner)], cwd=ROOT, check=True)
for model in ('601', '601a'):
    for cpu in ('mc6800', 'hd6303'):
        subprocess.run([str(runner), str(out / 'sd-test.img'), model, cpu], cwd=ROOT, check=True)
