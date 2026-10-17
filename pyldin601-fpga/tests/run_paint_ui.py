"""Native Paint event/windows/resource tests; file actions use a test stub."""
import argparse,os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cc',default='cc');a=p.parse_args()
out=ROOT/'build/paint';tc=Path(os.environ.get('UNIAS','/Users/sash/Work/FPGA/hd6303-toolchain/unias')).resolve()
for source in (ROOT/'firmware/paint').iterdir():shutil.copyfile(source,out/source.name)
for name in ('NCABI.INC','NCBOX.INC','NCCOM.ASM','NCKEY.ASM'):shutil.copyfile(ROOT/'firmware/nc'/name,out/name)
shutil.copyfile(ROOT/'firmware/input/MOUSE.ASM',out/'MOUSE.ASM')
shutil.copyfile(ROOT/'firmware/gfx/PALCOEF.ASM',out/'PALCOEF.ASM')
shutil.copyfile(ROOT/'tests/paint_ui_files.asm',out/'PUIFILE.ASM')
objects=['PNTMAIN','PNTUI','PNTCANV','PNTDRAW','PNTTOOLS','PNTPART','PNTPAL','PNTDMA','PNTLOAD','PNTMOD','PNTIO','PUIFILE','PNTCOM','NCKEY','MOUSE','PNTDATA','PNTSTATE','PNTSTR','PNTEND']
for name in objects:
 with (out/(name+'.log')).open('wb') as log:subprocess.run([str(tc),'-c',*(['-D','MOUSE_OBJECT'] if name=='MOUSE' else []),'-l',name+'.LST','-o',name+'.OBJ',name+'.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
with (out/'PNTBOOT.log').open('wb') as log:subprocess.run([str(tc),'-l','PNTBOOT.LST','-o','PNTBOOT.PGM','PNTBOOT.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
shutil.copyfile(ROOT/'tests/paint_graph.asm',out/'PGRAPH.ASM')
with (out/'PGRAPH.log').open('wb') as log:subprocess.run([str(tc),'-o','PGRAPH.PGM','PGRAPH.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
(out/'PUI.LNK').write_text(''.join(x+'.OBJ\n' for x in objects))
subprocess.run([str(tc.parent/'unild'),'-m','PUI.MAP','-o','PUI.PGM','@PUI.LNK'],cwd=out,check=True)
subprocess.run([str(tc.parent/'unild'),'-b','-o','PAINTUI.PGM','PNTBOOT.PGM','PUI.PGM'],cwd=out,check=True)
subprocess.run([str(ROOT/'build/firmware-data'),'public-labels',str(out/'PUI.MAP'),str(out/'PUI.h'),'PUI'],cwd=ROOT,check=True)
files={n:(out/n).read_bytes() for n in ('PAINTUI.PGM','PGRAPH.PGM','PNTNAT.PGM','PNTRGB.PGM','PNTHAM.PGM')}
image,_=install((ROOT/'images/sd.img').read_bytes(),files,replace=True);(out/'ui-sd.img').write_bytes(image)
runner=out/'test_ui'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_paint_ui.c','-o',str(runner)],cwd=ROOT,check=True)
for model in ('601','601a'):
 for cpu in ('mc6800','hd6303'):
  for mode in ('0','3'):subprocess.run([str(runner),str(out/'ui-sd.img'),model,cpu,mode],cwd=ROOT,check=True)
