"""Execute linked canvas/Undo/DMA code with real native row modules."""
import argparse,os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install
from make_sd import blank_disk
from sd_partitions import scan
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cc',default='cc');a=p.parse_args()
out=ROOT/'build/paint';tc=Path(os.environ.get('UNIAS','/Users/sash/Work/FPGA/hd6303-toolchain/unias')).resolve()
for path in (ROOT/'firmware/paint').glob('*.INC'):shutil.copyfile(path,out/path.name)
shutil.copyfile(ROOT/'tests/paint_canvas_main.asm',out/'PCMAIN.ASM')
shutil.copyfile(ROOT/'firmware/gfx/PALCOEF.ASM',out/'PALCOEF.ASM')
objects=['PCMAIN','PNTCANV','PNTDRAW','PNTTOOLS','PNTTEXT','PNTPART','PNTPAL','PNTDMA','PNTLOAD','PNTIO','PNTPCX','PNTIFF','PNTDATA','PNTSTATE','PNTEND']
for name in objects:
 if name!='PCMAIN':shutil.copyfile(ROOT/'firmware/paint'/(name+'.ASM'),out/(name+'.ASM'))
 with (out/(name+'.log')).open('wb') as log:subprocess.run([str(tc),'-c','-l',name+'.LST','-o',name+'.OBJ',name+'.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
(out/'PCTEST.LNK').write_text(''.join(x+'.OBJ\n' for x in objects))
subprocess.run([str(tc.parent/'unild'),'-m','PCTEST.MAP','-o','PCTEST.PGM','@PCTEST.LNK'],cwd=out,check=True)
subprocess.run([str(ROOT/'build/firmware-data'),'public-labels',str(out/'PCTEST.MAP'),str(out/'PCTEST.h'),'PCT'],cwd=ROOT,check=True)
files={n:(out/n).read_bytes() for n in ('PCTEST.PGM','PNTNAT.PGM','PNTRGB.PGM','PNTHAM.PGM')}
files['STREAM.BIN']=bytes(range(256))*513
from paint_pcx_fixture import make_fixtures,verify_outputs
files.update(make_fixtures(out))
from paint_iff_fixture import make_iff_fixtures,verify_iff_outputs
files.update(make_iff_fixtures(out))
media=bytearray((ROOT/'images/sd.img').read_bytes());part=list(scan(media))[2]
media[part.start*512:(part.start+part.sectors)*512]=blank_disk(size=part.sectors*512)
image,_=install(media,files,replace=True);(out/'canvas-sd.img').write_bytes(image)
runner=out/'test_canvas'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_paint_canvas.c','-o',str(runner)],cwd=ROOT,check=True)
for model in ('601','601a'):
 for cpu in ('mc6800','hd6303'):subprocess.run([str(runner),str(out/'canvas-sd.img'),model,cpu],cwd=ROOT,check=True)
verify_outputs(out)
verify_iff_outputs(out)
