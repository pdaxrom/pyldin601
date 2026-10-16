"""Build a native loader probe and run it on private media with UniDOS."""
import argparse,os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cc',default='cc');a=p.parse_args()
out=ROOT/'build/paint';tc=Path(os.environ.get('UNIAS','/Users/sash/Work/FPGA/hd6303-toolchain/unias')).resolve()
for name,source in [('PLMAIN','paint_loader_main.asm'),('PLEND','paint_loader_end.asm')]:shutil.copyfile(ROOT/'tests'/source,out/(name+'.ASM'))
shutil.copyfile(ROOT/'firmware/paint/PNTLOAD.ASM',out/'PNTLOAD.ASM')
for name in ('PLMAIN','PNTLOAD','PLEND'):
 with (out/(name+'.log')).open('wb') as log:subprocess.run([str(tc),'-c','-l',name+'.LST','-o',name+'.OBJ',name+'.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run([str(tc.parent/'unild'),'-m','PNTTEST.MAP','-o','PNTTEST.PGM','PLMAIN.OBJ','PNTLOAD.OBJ','PLEND.OBJ'],cwd=out,check=True)
subprocess.run([str(ROOT/'build/firmware-data'),'public-labels',str(out/'PNTTEST.MAP'),str(out/'PNTTEST.h'),'PLT'],cwd=ROOT,check=True)
files={n:(out/n).read_bytes() for n in ('PNTTEST.PGM','PNTNAT.PGM','PNTRGB.PGM','PNTHAM.PGM')}
bad=bytearray(files['PNTHAM.PGM']);bad[0]=0;files['BADHEAD.PGM']=bytes(bad)
bad=bytearray(files['PNTHAM.PGM']);offset=int.from_bytes(bad[4:6],'big');bad[offset+2]=0;files['BADMAG.PGM']=bytes(bad)
bad=bytearray(files['PNTHAM.PGM']);code=int.from_bytes(bad[6:8],'big');bad[16:18]=(code-1).to_bytes(2,'big');files['BADREL.PGM']=bytes(bad)
image,_=install((ROOT/'images/sd.img').read_bytes(),files,replace=True);(out/'loader-sd.img').write_bytes(image)
runner=out/'test_loader'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_paint_loader.c','-o',str(runner)],cwd=ROOT,check=True)
for model in ('601','601a'):
 for cpu in ('mc6800','hd6303'):
  for kind in ('banked','missing','busy'):subprocess.run([str(runner),str(out/'loader-sd.img'),model,cpu,kind],cwd=ROOT,check=True)
