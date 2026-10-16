"""Production Paint.PGM: staged Open, atomic Save and native failure paths."""
import argparse,subprocess,sys,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install
from make_sd import blank_disk
from sd_partitions import scan
from unias import assembler_path
from paint_pcx_fixture import make_fixtures,decode
from paint_iff_fixture import make_iff_fixtures,decode as decode_iff
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cc',default='cc');p.add_argument('--quick',action='store_true');a=p.parse_args()
out=ROOT/'build/paint'
subprocess.run([str(ROOT/'build/firmware-data'),'public-labels',str(out/'PAINT.MAP'),str(out/'PAINTF.h'),'PUI'],cwd=ROOT,check=True)
source=(ROOT/'tests/paint_graph.asm').read_text().replace('PAINTUI.PGM','PAINT.PGM');(out/'PFGRAPH.ASM').write_text(source)
with (out/'PFGRAPH.log').open('wb') as log:subprocess.run([assembler_path(),'-o','PFGRAPH.PGM','PFGRAPH.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
with (out/'PFGRAF2.log').open('wb') as log:subprocess.run([assembler_path(),'-D','COLOUR','-o','PFGRAF2.PGM','PFGRAPH.ASM'],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
files={n:(out/n).read_bytes() for n in ('PAINT.PGM','PFGRAPH.PGM','PFGRAF2.PGM','PNTNAT.PGM','PNTRGB.PGM','PNTHAM.PGM')}
files.update(make_fixtures(out));files.update(make_iff_fixtures(out))
media=bytearray((ROOT/'images/sd.img').read_bytes());part=list(scan(media))[2];media[part.start*512:(part.start+part.sectors)*512]=blank_disk(size=part.sectors*512)
image,_=install(media,files,replace=True);(out/'files-sd.img').write_bytes(image)
bad=bytearray(files['PNTHAM.PGM']);bad[0]=0
bad_image,_=install(image,{'PNTHAM.PGM':bytes(bad)},replace=True);(out/'files-bad-module.img').write_bytes(bad_image)
runner=out/'test_files';subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_paint_files.c','-o',str(runner)],cwd=ROOT,check=True)
cases=[('601','hd6303','0','banked')] if a.quick else [(m,c,v,'banked') for m in ('601','601a') for c in ('mc6800','hd6303') for v in ('0','3')]
if not a.quick:
 cases += [(m,c,'3',b) for m in ('601','601a') for c in ('mc6800','hd6303') for b in ('missing','busy')]
 cases += [('601a',c,'2','banked') for c in ('mc6800','hd6303')]
 cases += [('601','hd6303','0','arg'),('601','mc6800','0','bad'),('601a','hd6303','3','bad')]
 cases += [('601','hd6303','0','full'),('601a','mc6800','3','full')]
for model,cpu,video,backend in cases:
 subprocess.run([str(runner),str(out/('files-bad-module.img' if backend=='bad' else 'files-sd.img')),model,cpu,video,backend],cwd=ROOT,check=True)
 if backend=='bad':continue
 stem=f'files-{model}-{cpu}-{video}-{backend}'
 width,height,pixels,palette=decode((out/(stem+'.pcx')).read_bytes())
 assert (width,height)==(320,200) and pixels==(out/'PCX3.raw').read_bytes() and palette==(out/'PCX3.pal').read_bytes()
 assert decode_iff((out/(stem+'.iff')).read_bytes())==(out/(stem+'-ham-loaded.raw')).read_bytes()
print('PASS Paint file artifacts: independent PCX/ILBM validation matches native documents')
