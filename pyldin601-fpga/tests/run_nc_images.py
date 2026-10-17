"""Real NC -> Paint image associations through resident HG and native UniDOS."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import install
from unias import assembler_path
from paint_pcx_fixture import make_fixtures, decode
from paint_iff_fixture import make_iff_fixtures

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--quick', action='store_true')
p.add_argument('--case', nargs=4, metavar=('MODEL','CPU','VIDEO','BACKEND'))
p.add_argument('--jobs', type=int, default=1)
a = p.parse_args()
out = ROOT/'build/nc-images'
out.mkdir(parents=True, exist_ok=True)
for image, header, prefix in [('PAINT.MAP','PAINTF.h','PUI'),('PNTFIO.MAP','PAINTIO.h','PIO')]:
    subprocess.run([str(ROOT/'build/firmware-data'),'public-labels',str(ROOT/'build/paint'/image),str(ROOT/'build/paint'/header),prefix],check=True)
subprocess.run([str(ROOT/'build/firmware-data'),'labels',str(ROOT/'build/paint/PNTOVL.LST'),str(ROOT/'build/paint/PNTOVL.h'),'POV'],check=True)
pcx = make_fixtures(out)
iff = make_iff_fixtures(out)
media, _ = install((ROOT/'images/sd.img').read_bytes(), {'HG.PGM':(ROOT/'build/hg/HG.PGM').read_bytes()}, replace=True)
(out/'sd.img').write_bytes(media)
runner = out/'test_images'
shutil.copy2(ROOT/'tests/nc_image_graph.asm',out/'NIGRAPH.ASM')
with (out/'NIGRAPH.log').open('wb') as log:
    subprocess.run([assembler_path(),'-o','NIGRAPH.PGM','NIGRAPH.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run(['cc','-O2','-I../pyldin601/src','tests/test_nc_images.c','host/hg/fat12.c','host/hg/volume.c','-o',str(runner)],cwd=ROOT,check=True)
cases = [('601','hd6303','0','banked')] if a.quick else [(m,c,v,b) for m in ('601','601a') for c in ('mc6800','hd6303') for v,b in [('0','banked'),('0','missing'),('3' if m=='601' else '4','banked')]]
if not a.quick:
    cases += [('601',c,'3','missing') for c in ('mc6800','hd6303')]
    cases += [('601','hd6303','0','long'),('601a','mc6800','0','no-paint')]
    cases += [('601a','hd6303','3','low-gfx')]
if a.case:cases=[tuple(a.case)]
def run_case(case):
    model, cpu, video, backend = case
    host = out/f'{model}-{cpu}-{video}-{backend}'
    if host.exists():shutil.rmtree(host)
    host.mkdir()
    apps = host/('longdir1/longdir2/longdir3/longdir4/longdir5/longdir6' if backend=='long' else '.')
    apps.mkdir(parents=True,exist_ok=True)
    shutil.copy2(out/'NIGRAPH.PGM',host/'NIGRAPH.PGM')
    for directory,names in [('nc',('NC.PGM','NCMAIN.PGM','NCEDIT.PGM')),('paint',('PAINT.PGM','PNTNAT.PGM','PNTRGB.PGM','PNTHAM.PGM'))]:
        for name in names:
            if name=='PAINT.PGM' and backend=='no-paint':continue
            shutil.copy2(ROOT/'build'/directory/name,apps/name)
    images = host/'images/sub'
    images.mkdir(parents=True)
    for name, data in {'PCX3.PCX':pcx['PCX3.PCX'],'LONGNAME.PCX':pcx['PCX3.PCX'],'HAM.IFF':iff['IFF1.IFF'],'HAM.LBM':iff['IFF0.IFF']}.items():
        (images/name).write_bytes(data)
    log_path=out/f'{model}-{cpu}-{video}-{backend}.log'
    with log_path.open('wb') as log:
        status=subprocess.run([str(runner),str(out/'sd.img'),model,cpu,video,str(host),backend],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    if status.returncode:
        print(log_path.read_text(errors='replace')[-6000:],flush=True)
        status.check_returncode()
    if backend not in ('no-paint','low-gfx'):
        width,height,pixels,palette = decode((images/'SAVED.PCX').read_bytes())
        assert (width,height)==(320,200)
        assert pixels==(out/f'saved-{model}-{cpu}-{video}-{backend}.raw').read_bytes()
        assert palette==(out/'PCX3.pal').read_bytes()
    assert (images/'PCX3.PCX').read_bytes()==pcx['PCX3.PCX']
    assert (images/'HAM.IFF').read_bytes()==iff['IFF1.IFF']
    print('\n'.join(line for line in log_path.read_text().splitlines() if line.startswith('PASS')),flush=True)
with ThreadPoolExecutor(max_workers=a.jobs) as pool:
    list(pool.map(run_case,cases))
print('PASS NC image artifacts: original files unchanged, saved PCX independently decoded')
