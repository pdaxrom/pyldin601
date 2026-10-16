"""Build private SD media and exercise actual NC PGM files through UniDOS."""
from pathlib import Path
import argparse
import json
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import install, add_files
from sd_partitions import scan
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--cc',default='cc')
p.add_argument('--quick',action='store_true')
p.add_argument('--prepare-only',action='store_true')
a=p.parse_args()
out=ROOT/'build/nc'
# Assemble the probe with the same production UniAS direct PGM output.
import shutil
shutil.copyfile(ROOT/'tests/nc_probe.asm',out/'NCPROBE.ASM')
from unias import assembler_path
assembler=assembler_path()
subprocess.run(['sh',str(ROOT/'tools/run-unias.sh'),'NCPROBE.log',assembler,'-l','NCPROBE.LST','-o','NCPROBE.PGM','NCPROBE.ASM'],cwd=out,check=True)
subprocess.run([str(ROOT/'build/firmware-data'),'pgm-info',str(out/'NCPROBE.PGM'),str(out/'NCPROBE.json')],cwd=ROOT,check=True)
subprocess.run([str(ROOT/'build/firmware-data'),'labels',str(out/'NCPROBE.LST'),str(out/'NCPROBE.h'),'PROBE'],cwd=ROOT,check=True)
shutil.copyfile(ROOT/'tests/nc_graph.asm',out/'NCGRAPH.ASM')
for mode in (2,3):
 app=f'NCGRAF{mode}'
 flags=['-D','COLOUR'] if mode==2 else []
 subprocess.run(['sh',str(ROOT/'tools/run-unias.sh'),app+'.log',assembler,*flags,'-l',app+'.LST','-o',app+'.PGM','NCGRAPH.ASM'],cwd=out,check=True)
 subprocess.run([str(ROOT/'build/firmware-data'),'pgm-info',str(out/(app+'.PGM')),str(out/(app+'.json'))],cwd=ROOT,check=True)
files={name:(out/name).read_bytes() for name in ('NC.PGM','NCMAIN.PGM','NCEDIT.PGM','NCPROBE.PGM','NCGRAF2.PGM','NCGRAF3.PGM')}
files['HELLO.TXT']=(b'Pyldin Commander text viewer\r\n'+b'Line of text for paging.\r\n'*100)
files['EMPTY.TXT']=b''
files['LARGE.BIN']=bytes(range(256))*300
from make_sd import blank_disk
base=bytearray((ROOT/'images/sd.img').read_bytes())
# A launchable image retains the user's existing directories and disk shell.
package={name:(out/name).read_bytes() for name in ('NC.PGM','NCMAIN.PGM','NCEDIT.PGM','NCHOW.TXT')}
ready,metadata=install(base,package,replace=True)
(out/'sd-nc.img').write_bytes(ready)
(out/'sd-nc.json').write_text(json.dumps(metadata,indent=2)+'\n')
pb=next(x for x in scan(base) if x.number==3)
blank=blank_disk()
assert len(blank)==pb.sectors*512
base[pb.start*512:(pb.start+pb.sectors)*512]=blank
image,_=install(base,files,replace=True)
image=bytearray(image)
(out/'sd-disk-shell.img').write_bytes(image)
pa=next(x for x in scan(image) if x.number==2)
start,end=pa.start*512,(pa.start+pa.sectors)*512
image[start:end]=add_files(image[start:end],{'UNIDOS.CMD':(ROOT/'build/partitions/SHELL.CMD').read_bytes()},replace=True)
(out/'sd-test.img').write_bytes(image)
no_main=bytearray(image)
no_main[pb.start*512:(pb.start+pb.sectors)*512]=add_files(blank,{'NC.PGM':files['NC.PGM']})
(out/'sd-no-main.img').write_bytes(no_main)
many_files={f'F{k:03d}.TXT':str(k).encode() for k in range(350)}
many_files.update({k:v for k,v in files.items() if k.endswith('.PGM')})
many_files.update({'ZLAST.TXT':b'last','AONE.TXT':b'first','BTWO.TXT':b'second','CTHREE.TXT':b'third','DFOUR.TXT':b'fourth','EFIVE.TXT':b'fifth'})
# 350 numbered + six executables + six named = 362 ordinary files.
many=bytearray(image)
many[pb.start*512:(pb.start+pb.sectors)*512]=add_files(blank,many_files,replace=True)
(out/'sd-many.img').write_bytes(many)
if a.prepare_only:
 sys.exit(0)
runner=out/'test_nc'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_nc.c','-o',str(runner)],cwd=ROOT,check=True)
cases=[('601','mc6800','0')] if a.quick else [(m,c,v) for m in ('601','601a') for c in ('mc6800','hd6303') for v in (('0','3') if m=='601' else ('0','4','2','3'))]
for model,cpu,video in cases:
 subprocess.run([str(runner),str(out/'sd-test.img'),model,cpu,video],cwd=ROOT,check=True)

if not a.quick:
 for backend in ('missing','full'):
  subprocess.run([str(runner),str(out/'sd-test.img'),'601','mc6800','0',backend],cwd=ROOT,check=True)
 for model,cpu,video,backend in (('601a','mc6800','2','missing'),('601a','hd6303','3','full')):
  subprocess.run([str(runner),str(out/'sd-test.img'),model,cpu,video,backend],cwd=ROOT,check=True)
 subprocess.run([str(runner),str(out/'sd-test.img'),'601a','mc6800','2','offset'],cwd=ROOT,check=True)

if not a.quick:
 for model,cpu,video,backend in (('601','mc6800','0','many'),('601','mc6800','0','many-bank'),('601a','hd6303','2','many-bank'),('601a','mc6800','3','many-bank'),('601a','hd6303','4','many-bank'),('601a','mc6800','2','many')):
  subprocess.run([str(runner),str(out/'sd-many.img'),model,cpu,video,backend],cwd=ROOT,check=True)

if not a.quick:
 for model,cpu,video in (('601','mc6800','0'),('601a','hd6303','4'),('601','mc6800','3'),('601a','hd6303','2')):
  subprocess.run([str(runner),str(out/'sd-disk-shell.img'),model,cpu,video,'disk'],cwd=ROOT,check=True)
 subprocess.run([str(runner),str(out/'sd-no-main.img'),'601','mc6800','0','no-main'],cwd=ROOT,check=True)
 for model,cpu in (('601','mc6800'),('601a','hd6303')):
  subprocess.run([str(runner),str(out/'sd-nc.img'),model,cpu,'0','ready'],cwd=ROOT,check=True)

if not a.quick:
 for model,cpu,video in [('601','mc6800','0'),('601','hd6303','3'),('601a','mc6800','4'),('601a','hd6303','2')]:
  subprocess.run([str(runner),str(out/'sd-test.img'),model,cpu,video,'mouse'],cwd=ROOT,check=True)
