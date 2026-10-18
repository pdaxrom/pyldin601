"""Test assembled Xonix/config/level caching through native UniDOS on 601/A."""
import argparse
from pathlib import Path
import subprocess
import sys
import re
import struct

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install,layout
from sd_partitions import scan
from ham8_format import chunks,decode,form

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--cc',default='cc')
p.add_argument('--pgm',type=Path,help='test an alternate linked XONIX PGM')
p.add_argument('--object',type=Path,help='main OBJ, with adjacent LST, for alternate label addresses')
p.add_argument('--models',nargs='+',default=['601','601a'])
p.add_argument('--cases',nargs='+',default=['missing','empty','two','ten','long','many','large','badpic','cancel'])
a=p.parse_args()
out=ROOT/'build/xonix-start';out.mkdir(parents=True,exist_ok=True)
original=(ROOT/'firmware/game/LENA.IFF').read_bytes()
# Inherited arcade checks use independently decoded image/music oracles.
# Prepare them here too: test-xonix must not require test-gamebios first.
oracles=ROOT/'build/games-next';oracles.mkdir(parents=True,exist_ok=True)
(oracles/'LENA.raw').write_bytes(decode(original))
with (oracles/'LEDSTRM1.raw').open('wb') as stream:
    subprocess.run(['7z','e','-so',str(ROOT/'firmware/game/LEDSTRM1.YM')],
                   stdout=stream,check=True)
parts=dict(chunks(original));bmhd=bytearray(parts[b'BMHD']);bmhd[10]=0
# Distinct uncompressed image with exact RGB222/blue modifier commands.
codes=bytes(48 if x==0 else 64+(x%64) for y in range(200) for x in range(320))
body=bytearray()
for y in range(200):
    for bit in range(8):
        for byte in range(40):
            body.append(sum(((codes[y*320+byte*8+k]>>bit)&1)<<(7-k) for k in range(8)))
alt=form([(b'BMHD',bytes(bmhd)),(b'CAMG',parts[b'CAMG']),(b'CMAP',parts[b'CMAP']),(b'BODY',body)])
assert decode(alt)==codes
(out/'ALT.raw').write_bytes(codes)
base=bytearray((ROOT/'images/sd.img').read_bytes());b=next(p for p in scan(base,max_logical=32) if p.number==3)
# The missing-config case stays reproducible after the release image includes it.
volume=base[b.start*512:(b.start+b.sectors)*512];_,_,_,_,_,root,entries,_=layout(volume)
for offset in range(root,root+entries*32,32):
    if volume[offset:offset+11]==b'XONIX   CFG':volume[offset]=0xe5
base[b.start*512:(b.start+b.sectors)*512]=volume
files={n:(ROOT/'build/game'/n).read_bytes() for n in ('XONIX.PGM','LEDSTRM1.YM','LENA.IFF')}
if a.pgm:files['XONIX.PGM']=a.pgm.read_bytes()
files['ALT.IFF']=alt
base,_=install(base,files,replace=True)
configs={'empty':b'# comment only\r\n\n; comment\n',
         'two':b'  # level list\r\n\tLENA.IFF   ; first\r\n\nALT.IFF\n\x1aignored',
         'ten':b'LENA.IFF\n'+b'ALT.IFF\n'*9,
         'long':b'A'*64+b'\n','many':b'LENA.IFF\n'*11,'large':b' '*4097,
         'badpic':b'BAD.IFF\n','cancel':b'LENA.IFF\n'}
flags=[]
if a.object:
    assert a.pgm
    code=struct.unpack_from('>H',a.object.read_bytes(),8)[0]
    final=struct.unpack_from('>H',a.pgm.read_bytes(),6)[0]
    symbols={n:int(v,16) for n,v in re.findall(r'^([A-Z_][A-Z_0-9]*) =\$([0-9a-fA-F]{4})$',a.object.with_suffix('.LST').read_text(),re.M)}
    header=out/'linked_labels.h'
    header.write_text(''.join(f'#define XO_{n} {v+(final-code if v>=code else 0)}\n' for n,v in symbols.items()))
    flags=['-DXONIX_LABELS="'+str(header.resolve())+'"']
subprocess.run([a.cc,'-O2',*flags,'-I../pyldin601/src','tests/test_xonix.c' ,'-o',str(out/'test')],cwd=ROOT,check=True)
for case in a.cases:
    update={} if case=='missing' else {'XONIX.CFG':configs[case]}
    if case=='badpic':update['BAD.IFF']=original[:80]
    image,_=install(base,update,replace=True);path=out/(case+'.img');path.write_bytes(image)
    for model in a.models:
        result=subprocess.run([str(out/'test'),str(path),model,case],cwd=ROOT,capture_output=True,text=True,timeout=180)
        log=result.stdout+result.stderr;(out/(case+'-'+model+('-linked' if a.pgm else '')+'.log')).write_text(log)
        print(log,end='',flush=True)
        if result.returncode or 'PASS XONIX' not in log:raise RuntimeError('Xonix '+case+'/'+model+' failed')
