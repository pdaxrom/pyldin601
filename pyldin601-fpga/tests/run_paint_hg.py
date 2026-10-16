"""Launch Paint through real resident HG, including constrained 601A graphics."""
import argparse, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install
from unias import assembler_path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cc',default='cc');p.add_argument('--quick',action='store_true');p.add_argument('--nc-only',action='store_true');a=p.parse_args()
out=ROOT/'build/paint'
subprocess.run([str(ROOT/'build/firmware-data'),'public-labels',str(out/'PAINT.MAP'),str(out/'PAINTF.h'),'PUI'],check=True)
source=(ROOT/'tests/paint_graph.asm').read_text().replace('B:PAINTUI.PGM','PAINT.PGM');(out/'PGHG.ASM').write_text(source)
with (out/'PGHG.log').open('wb') as log:subprocess.run([assembler_path(),'-o','PGHG.PGM','PGHG.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
(out/'PGLOW.ASM').write_text("start\n    ldx #22000\n    clrb\n    int $2a\n    ldx #command\n    int $39\n    int $38\ncommand db 'PAINT.PGM',0\n    end start\n")
with (out/'PGLOW.log').open('wb') as log:subprocess.run([assembler_path(),'-o','PGLOW.PGM','PGLOW.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
image,_=install((ROOT/'images/sd.img').read_bytes(),{'HG.PGM':(ROOT/'build/hg/HG.PGM').read_bytes()},replace=True);(out/'hg-sd.img').write_bytes(image)
runner=out/'test_hg';subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_paint_hg.c','host/hg/fat12.c','host/hg/volume.c','-o',str(runner)],cwd=ROOT,check=True)
cases=[('601','hd6303','0','banked')] if a.quick else [(m,c,v,b) for m in ('601','601a') for c in ('mc6800','hd6303') for v in ('0','3') for b in ('banked','missing')]
nc_cases=[('601','hd6303','0','nc'),('601a','mc6800','0','nc'),('601a','hd6303','0','nc')]
if a.nc_only:cases=nc_cases
elif not a.quick:cases += nc_cases
for model,cpu,video,backend in cases:
 host=out/f'hg-{model}-{cpu}-{video}-{backend}'
 if host.exists():shutil.rmtree(host)
 host.mkdir()
 for name in ('PAINT.PGM','PNTCORE.PGM','PNTNAT.PGM','PNTRGB.PGM','PNTHAM.PGM','PGHG.PGM','PGLOW.PGM'):shutil.copy2(out/name,host/name)
 for name in ('NC.PGM','NCMAIN.PGM'):shutil.copy2(ROOT/'build/nc'/name,host/name)
 subprocess.run([str(runner),str(out/'hg-sd.img'),model,cpu,video,str(host),backend],cwd=ROOT,check=True)
