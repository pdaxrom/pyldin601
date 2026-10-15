"""Build C modules natively over HG and execute mixed CPU/bytecode calls."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import struct
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--toolchain',type=Path,required=True)
p.add_argument('--jobs',type=int,default=1)
p.add_argument('--quick',action='store_true')
p.add_argument('--cc',default='cc')
a=p.parse_args();tc=a.toolchain.resolve()
out=ROOT/'build/cvm/cmodules';cross=out/'cross';cross.mkdir(parents=True,exist_ok=True)
sources={p.name:p.read_bytes()for p in (tc/'tests/cmodules').iterdir()}
for n in ('CSTART.ASM','CEND.ASM','CVCALL.ASM','CVMDEF.INC','CVMABI.INC'):
    sources[n]=(tc/n).read_bytes()
lists={'CAPP.LNK':['CSTART.OBJ','MMAIN.OBJ','MHELP.OBJ','MOTHER.OBJ','CRT.LIB'],
       'LIBAPP.LNK':['CSTART.OBJ','MMAIN.OBJ','UTIL.LIB','CRT.LIB'],
       'MIXAPP.LNK':['CSTART.OBJ','MIX.OBJ','MINLINE.OBJ','MNATIVE.OBJ','CRT.LIB'],
       'NENTRY.LNK':['NENTRY.OBJ','MIX.OBJ','MINLINE.OBJ','MNATIVE.OBJ','CRT.LIB'],
       'SLIB.LNK':['CSTART.OBJ','SMAIN.OBJ','SIMPLIB.LIB','CRT.LIB']}
sources['BADMOD.C']=b'int value;\nint value;\nmain(){return 0;}\n'
sources['BADEND.C']=b'main()\n{ return missing+; }\n'
sources['BADMOD.ASM']=b'keep previous module'
sources['BADEND.ASM']=b'keep previous module'
for n,items in lists.items():sources[n]=('\n'.join(items)+'\n').encode()
for n,data in sources.items():(cross/n).write_bytes(data)
commands=[];expected=[]
for n in ('MMAIN','MHELP','MOTHER','MUNUSED','MIX','MINLINE','SMAIN','SIMPLE'):
    commands += [f'unicc -c -o {n}.ASM {n}.C',f'unias -c -o {n}.OBJ {n}.ASM']
    expected += [n+'.ASM',n+'.OBJ']
for n in ('CSTART','CEND','CVCALL','MNATIVE','NENTRY'):
    commands.append(f'unias -D PYLDIN601 -c -o {n}.OBJ {n}.ASM')
    expected.append(n+'.OBJ')
commands += ['uniar r CRT.LIB CEND.OBJ CVCALL.OBJ',
             'uniar r UTIL.LIB MHELP.OBJ MOTHER.OBJ MUNUSED.OBJ',
             'uniar r SIMPLIB.LIB SIMPLE.OBJ']
expected += ['CRT.LIB','UTIL.LIB','SIMPLIB.LIB']
for n in lists:
    stem=n[:-4]
    commands.append(f'unild -m {stem}.MAP -o {stem}.PGM @{n}')
    expected += [stem+'.PGM',stem+'.MAP']
for i,command in enumerate(commands):
    args=command.split()
    with (cross/f'{i}.log').open('wb')as log:
        subprocess.run([str(tc/args[0]),*args[1:]],cwd=cross,stdout=log,
                       stderr=subprocess.STDOUT,check=True)
assert (cross/'CAPP.PGM').read_bytes()==(cross/'LIBAPP.PGM').read_bytes()
for base in ('0x100','0x4300','0x8000'):
    run=subprocess.run([str(tc/'scvm'),'-b',base,'CAPP.PGM'],cwd=cross,
                       capture_output=True,check=True)
    assert b'C MODULE PASS' in run.stdout
commands += ['CAPP.PGM\tC MODULE PASS','LIBAPP.PGM\tC MODULE PASS',
             'MIXAPP.PGM\tC MIXED PASS','NENTRY.PGM\tC ABI PASS',
             'SLIB.PGM\tC LIB PASS','ulink cstart mmain mhelp mother cend',
             'CSTART.PGM\tC MODULE PASS','copy cstart.pgm plain.pgm',
             'ulink cstart smain simplib crt','CSTART.PGM\tC LIB PASS',
             '!unicc -c -o BADMOD.ASM BADMOD.C\terrors in compilation.',
             '!unicc -c -o BADEND.ASM BADEND.C\terrors in compilation.']
commandfile=out/'commands.txt';commandfile.write_text('\n'.join(commands)+'\n')
native={n:(tc/'pyldin'/n).read_bytes()for n in
        ('UNICC.CMD','UNIAS.CMD','UNILD.CMD','UNIAR.CMD',
         'ZVM6303.ROM','ZVM6800.ROM')}
native['ULINK.CMD']=(ROOT/'build/romdisk-extracted/unpacked/ULINK.CMD').read_bytes()
native['RAMLOAD.PGM']=(ROOT/'build/ramloader/RAMLOAD.PGM').read_bytes()
sd,_=install((ROOT/'images/sd.img').read_bytes(),
              {'HG.PGM':(ROOT/'build/hg/HG.PGM').read_bytes()},replace=True)
image=out/'SD.IMG';image.write_bytes(sd)
runner=out/'test_c_modules'
subprocess.run([a.cc,'-O2','-DNATIVE_TOOLS_HG','-I../pyldin601/src',
               'tests/test_native_tools.c','host/hg/fat12.c','host/hg/volume.c',
               '-o',str(runner)],cwd=ROOT,check=True)
def native_case(case):
    model,cpu=case;result=out/(model+'-'+cpu);host=result/'host'
    if host.exists():shutil.rmtree(host)
    cvm=host/'CVM';cvm.mkdir(parents=True)
    for n,data in (sources|native).items():(cvm/n).write_bytes(data)
    print('C modules:',model,cpu,'log:',result/'run.log',flush=True)
    with (result/'run.log').open('wb')as log:
        r=subprocess.run([str(runner),str(image),model,cpu,str(result),
                          str(commandfile),str(host)],cwd=ROOT,stdout=log,
                         stderr=subprocess.STDOUT)
    if r.returncode:
        print((result/'run.log').read_text(errors='replace')[-6500:]);r.check_returncode()
    files=[]
    for n in expected:
        actual,want=(cvm/n).read_bytes(),(cross/n).read_bytes()
        assert actual==want,(model,cpu,n,len(actual),len(want))
        files.append({'name':n,'bytes':len(actual),
                      'sha256':hashlib.sha256(actual).hexdigest()})
    for name in ('BADMOD','BADEND'):
        assert (cvm/(name+'.ASM')).read_bytes()==b'keep previous module'
        assert not (cvm/(name+'.UCT')).exists()
    def parts(data):
        n,off,code,entry,bss=struct.unpack_from('>5H',data,2)
        assert off>=16+2*n and len(data)==off+code
        return data[off:],entry,bss,data[16:16+2*n]
    assert parts((cvm/'PLAIN.PGM').read_bytes())==parts((cross/'CAPP.PGM').read_bytes())
    assert parts((cvm/'CSTART.PGM').read_bytes())==parts((cross/'SLIB.PGM').read_bytes())
    print('PASS C modules:',model,cpu,'native outputs identical; mixed calls and original ULINK execute',flush=True)
    return {'model':model,'cpu':cpu,'files':files}
cases=[('601','mc6800')]if a.quick else[(m,c)for m in ('601','601a')for c in ('mc6800','hd6303')]
with ThreadPoolExecutor(max_workers=a.jobs)as pool:results=list(pool.map(native_case,cases))
(out/'comparison.json').write_text(json.dumps({'cases':results,'commands':commands,
    'execution':'native HG resident, real BIOS/UniDOS, bytecode/native callbacks'},indent=2)+'\n')
