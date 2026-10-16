"""Exercise the resident Paint overlay supervisor with actual native UniDOS."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import install
from unias import assembler_path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--quick', action='store_true')
a = p.parse_args()
out = ROOT/'build/paint-overlays'
subprocess.run([str(ROOT/'build/firmware-data'),'labels',str(out/'PNTOVL.LST'),str(out/'OVL.h'),'OVL'],check=True)
subprocess.run([str(ROOT/'build/firmware-data'), 'public-labels', str(out/'PAINT.MAP'), str(out/'PUI.h'), 'PUI'], check=True)
subprocess.run([str(ROOT/'build/firmware-data'), 'public-labels', str(out/'PNTFIO.MAP'), str(out/'PIO.h'), 'PIO'], check=True)
files = {'PAINTUI.PGM': (out/'PAINT.PGM').read_bytes()}
shutil.copyfile(ROOT/'tests/paint_graph.asm', out/'PGRAPH.ASM')
subprocess.run([assembler_path(), '-o', 'PGRAPH.PGM', 'PGRAPH.ASM'], cwd=out, stdout=subprocess.DEVNULL, check=True)
files['PGRAPH.PGM'] = (out/'PGRAPH.PGM').read_bytes()
files.update({n+'.PGM': (out/(n+'.PGM')).read_bytes() for n in ('PNTNAT','PNTRGB','PNTHAM')})
media, _ = install((ROOT/'images/sd.img').read_bytes(), files, replace=True)
(out/'test-sd.img').write_bytes(media)
runner = out/'test_overlay'
subprocess.run(['cc', '-O2', '-I../pyldin601/src', 'tests/test_paint_overlay.c', '-o', str(runner)], cwd=ROOT, check=True)
cases = [('601', 'hd6303', '0', 'banked')] if a.quick else [(m,c,v,b) for m in ('601','601a') for c in ('mc6800','hd6303') for v in ('0','3') for b in ('banked','missing')]+[('601a','mc6800','0','busy')]
for model, cpu, video, backend in cases:
    subprocess.run([str(runner), str(out/'test-sd.img'), model, cpu, video, backend], cwd=ROOT, check=True)
