"""Exercise real GAMEBIOS ROM with native UniDOS on both models and ISAs."""
import argparse
from pathlib import Path
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
(out / 'GAMEEXIT.ASM').write_text('''    include GAMEBIOS.INC
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
    ldaa #GB_CLOSE
    int GB_INT
    clra
    int $38
failed
    ldaa #GB_CLOSE
    int GB_INT
    ldaa #1
    int $38
context ds GB_CONTEXT_BYTES
    end
''')
program = assemble(a.unias, out, 'GAMEEXIT.ASM', 'GAMEEXIT.PGM')
subprocess.run(['make', '-s', '-f', 'firmware/Makefile', 'game', 'UNIAS='+a.unias], cwd=ROOT, check=True)
image, _ = install((ROOT / 'images/sd.img').read_bytes(), {'GAMEEXIT.PGM': program, 'ARKANOID.PGM': (ROOT/'build/game/ARKANOID.PGM').read_bytes(), 'SDKTEST.PGM': (ROOT/'build/game/SDKTEST.PGM').read_bytes(), **{n: (ROOT/'build/game'/n).read_bytes() for n in ('XONIX.PGM','LENA.IFF','WARHAWK.YM','LEDSTRM1.YM')}}, replace=True)
(out / 'sd-test.img').write_bytes(image)
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

# Both arcade applications execute through the real native PGM/file APIs.
arcade_dir = ROOT / 'build/games-next'
arcade_dir.mkdir(parents=True, exist_ok=True)
for name in ('WARHAWK', 'LEDSTRM1'):
    with (arcade_dir / (name+'.raw')).open('wb') as stream:
        subprocess.run(['7z', 'e', '-so', str(ROOT/'firmware/game'/(name+'.YM'))], stdout=stream, check=True)
from ham8_format import decode
(arcade_dir / 'LENA.raw').write_bytes(decode((ROOT/'firmware/game/LENA.IFF').read_bytes()))
runner = out / 'test_arcade'
subprocess.run([a.cc, '-O2', '-I../pyldin601/src', 'tests/test_arcade.c', '-o', str(runner)], cwd=ROOT, check=True)
for model in ('601', '601a'):
    subprocess.run([str(runner), str(out/'sd-test.img'), model], cwd=ROOT, check=True)
# Real resident HG driver and durable C host volume, not only SD file calls.
hg_runner = out / 'test_arcade_hg'
subprocess.run([a.cc, '-O2', '-DARCADE_HG', '-I../pyldin601/src', '-Ihost/hg',
                'tests/test_arcade.c', 'host/hg/fat12.c', 'host/hg/volume.c',
                '-o', str(hg_runner)], cwd=ROOT, check=True)
for model in ('601', '601a'):
    subprocess.run([str(hg_runner), str(out/'sd-test.img'), model], cwd=ROOT, check=True)
# Exhaust FAT12 clusters without changing any program, boot or other volume.
from add_disk_files import layout, fat_get
from sd_partitions import scan
part_b = next(p for p in scan(image, max_logical=32) if p.number == 3)
volume = image[part_b.start*512:(part_b.start+part_b.sectors)*512]
info, table, *_ = layout(volume)
unit = info['sectors_per_cluster']*512
free = sum(fat_get(table, k)==0 for k in range(2, info['clusters']+2))
full, _ = install(image, {'FULLDISK.DAT': bytes(free*unit)}, replace=True)
(out/'sd-full.img').write_bytes(full)
for model in ('601', '601a'):
    subprocess.run([str(runner), str(out/'sd-full.img'), model, 'full'], cwd=ROOT, check=True)
