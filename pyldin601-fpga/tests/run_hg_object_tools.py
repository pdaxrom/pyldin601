"""Run the native object tools from a durable HG host directory with HG resident."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--toolchain',type=Path,required=True)
p.add_argument('--cc',default='cc')
p.add_argument('--jobs',type=int,default=1)
p.add_argument('--quick',action='store_true',help='MC6800/601 only')
p.add_argument('--small',action='store_true',help='skip large game assemblies')
a=p.parse_args();tc=a.toolchain.resolve()
out=ROOT/'build/cvm/hg-tools';out.mkdir(parents=True,exist_ok=True)
cross=out/'cross';cross.mkdir(exist_ok=True)
sources={}
for n in ('MAIN.ASM','HELP.ASM','RADIX.ASM'):
    sources[n]=(tc/'tests/objects'/n).read_bytes()
def collect(name):
    if name in sources:return
    data=(ROOT/'firmware/game'/name).read_bytes();sources[name]=data
    for m in re.finditer(rb'^\s*include\s+([^\s;]+)',data,re.I|re.M):
        collect(m[1].decode())
if not a.small:
    for n in ('ARKANOID.ASM','XONIX.ASM','XOMAIN.ASM','XOCFG.ASM'):collect(n)
for n,d in sources.items():(cross/n).write_bytes(d)
commands=[
 'unias -c -o main.obj main.asm',
 'unias -c -o help.obj help.asm',
 'unild -o app.pgm main.obj help.obj',
 'uniar r util.lib help.obj',
 'unild -o libapp.pgm main.obj util.lib',
 'unias -c -o radix.obj radix.asm',
]
if not a.small:commands += [
 'unias -o arkanoid.pgm arkanoid.asm',
 'unias -o arkanoid.pgm arkanoid.asm',
 'unias -D GAME_MUSIC -l xonix.lst -o xonix.pgm xonix.asm',
 'unias -c -D GAME_MUSIC -o xomain.obj xomain.asm',
 'unias -c -D GAME_MUSIC -o xocfg.obj xocfg.asm',
 'unild -o xoobj.pgm xomain.obj xocfg.obj',
 'uniar r xcfg.lib xocfg.obj',
 'unild -o xolib.pgm xomain.obj xcfg.lib',
]
for i,cmd in enumerate(commands):
    args=cmd.split()
    args=[x.upper() if '.' in x and not x.startswith('-') else x for x in args]
    with (cross/f'{i}.log').open('wb')as f:
        subprocess.run([str(tc/args[0]),*args[1:]],cwd=cross,stdout=f,stderr=subprocess.STDOUT,check=True)
expected=['MAIN.OBJ','HELP.OBJ','APP.PGM','LIBAPP.PGM','RADIX.OBJ']
if not a.small:
    expected+=['ARKANOID.PGM','XONIX.PGM','XOMAIN.OBJ','XOCFG.OBJ','XOOBJ.PGM','XCFG.LIB','XOLIB.PGM']
    assert (cross/'XOOBJ.PGM').read_bytes()==(cross/'XOLIB.PGM').read_bytes()
commands+=['app.pgm\tOBJECT PASS','libapp.pgm\tOBJECT PASS',
           'uniar t util.lib\tHELP','uniar x util.lib help',
           'uniar d util.lib help','uniar t util.lib']
commandfile=out/'commands.txt';commandfile.write_text('\n'.join(commands)+'\n')
native={n:(tc/'pyldin'/n).read_bytes()for n in
        ['UNIAS.CMD','UNICC.CMD','UNILD.CMD','UNIAR.CMD','ZVM6800.ROM','ZVM6303.ROM','SYSTEM.H']}
native['RAMLOAD.PGM']=(ROOT/'build/ramloader/RAMLOAD.PGM').read_bytes()
for n,d in sources.items():
    stem,ext=n.rsplit('.',1);short=stem[:8]+'.'+ext[:3]
    assert short not in native,n
    native[short]=d
image,_=install((ROOT/'images/sd.img').read_bytes(),{'HG.PGM':(ROOT/'build/hg/HG.PGM').read_bytes()},replace=True)
sd=out/'SD.IMG';sd.write_bytes(image)
runner=out/'test_hg_tools'
subprocess.run([a.cc,'-O2','-DNATIVE_TOOLS_HG','-I../pyldin601/src',
                'tests/test_native_tools.c','host/hg/fat12.c','host/hg/volume.c',
                '-o',str(runner)],cwd=ROOT,check=True)
cases=[('601','mc6800')] if a.quick else [(m,c)for m in ('601','601a')for c in ('mc6800','hd6303')]
def run_case(case):
    model,cpu=case;result=out/(model+'-'+cpu);result.mkdir(exist_ok=True)
    host=result/'host'
    if host.exists():shutil.rmtree(host)
    cvm=host/'CVM';cvm.mkdir(parents=True)
    for n,d in native.items():(cvm/n).write_bytes(d)
    print('HG native tools:',model,cpu,'log:',result/'run.log',flush=True)
    with (result/'run.log').open('wb')as f:
        r=subprocess.run([str(runner),str(sd),model,cpu,str(result),str(commandfile),str(host)],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
    if r.returncode:
        print((result/'run.log').read_text(errors='replace')[-6500:]);r.check_returncode()
    matches=[]
    for n in expected:
        actual=(cvm/n).read_bytes();want=(cross/n).read_bytes()
        assert actual==want,(model,cpu,n,len(actual),len(want))
        matches.append({'file':n,'bytes':len(actual),'sha256':hashlib.sha256(actual).hexdigest()})
    library=(cvm/'UTIL.LIB').read_bytes()
    assert library[:6]==bytes.fromhex('0bb000000000') and len(library)==32
    log=(result/'run.log').read_text(errors='replace')
    changed=[int(n)for n in re.findall(r'VM workspace changed bytes: (\d+)',log)]
    if not a.small:assert max(changed)>2000,'large assembly must use VM-bank symbol storage'
    print('PASS HG tools:',model,cpu,'native host-folder outputs match cross builds',flush=True)
    return {'model':model,'cpu':cpu,'files':matches,'workspace_changed_bytes':max(changed)}
with ThreadPoolExecutor(max_workers=a.jobs)as pool:results=list(pool.map(run_case,cases))
(out/('small.json' if a.small else 'comparison.json')).write_text(json.dumps({
    'execution':'real resident HG.PGM, durable C host volume, HANDLES 16, RAMLOAD from HG/CVM',
    'tools':{n:hashlib.sha256(d).hexdigest()for n,d in native.items()if n.endswith(('.CMD','.ROM'))},
    'cases':results},indent=2)+'\n')
