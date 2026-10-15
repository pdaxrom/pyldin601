"""Native UniCC/UniAS/UniLD/UniAR and original ULINK, real BIOS/UniDOS."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install,root_files
from make_sd import blank_disk

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--toolchain',type=Path,required=True)
p.add_argument('--cc',default='cc')
p.add_argument('--jobs',type=int,default=1)
p.add_argument('--quick',action='store_true')
p.add_argument('--resume',action='store_true',help='retest modular assemblies from saved disks; verify every output against fresh cross builds')
p.add_argument('--smoke',action='store_true',help='skip large firmware assemblies')
a=p.parse_args();tc=a.toolchain.resolve()
out=ROOT/'build/cvm/object-native';out.mkdir(parents=True,exist_ok=True)
cross=out/'cross';cross.mkdir(exist_ok=True)
sources={}
def collect(name,dirs):
    paths=[d/name for d in dirs if (d/name).is_file()]
    assert len(paths)==1,name
    data=paths[0].read_bytes()
    if name in sources:
        assert sources[name]==data;return
    sources[name]=data
    for match in re.finditer(rb'^\s*include\s+([^\s;]+)',data,re.I|re.M):
        collect(match[1].decode(),dirs)
for n in ('BIOS.ASM','BIOS_A.ASM'):
    collect(n,[ROOT/'firmware/bios',ROOT/'firmware/memory'])
for n in ('XONIX.ASM','XOMAIN.ASM','XOCFG.ASM'):
    collect(n,[ROOT/'firmware/game'])
for name,data in sources.items():(cross/name).write_bytes(data)
fixtures=tc/'tests/objects'
for name in ('MAIN.ASM','HELP.ASM','RADIX.ASM','WROOT.ASM','WHELP.ASM','OMAIN.OBJ','OHELP.OBJ','ONOENT.OBJ','ORIG.LIB','RROOT.ASM','RHELP.ASM','ARREF.LIB'):
    shutil.copyfile(fixtures/name,cross/name)
for name in ('UNILD.C','UNIAR.C','TOOLIO.C'):
    shutil.copyfile(tc/name,cross/name)
shutil.copyfile(tc/'pyldin/SYSTEM.H',cross/'SYSTEM.H')
commands=[
 'unias -l bios.lst -o bios.rom bios.asm',
 'unias -l bios_a.lst -o bios_a.rom bios_a.asm',
 'unias -D GAME_MUSIC -l xonix.lst -o xonix.pgm xonix.asm',
 'unias -c -D GAME_MUSIC -o xosolo.obj xonix.asm',
 'unild -o xosolo.pgm xosolo.obj',
 'unias -c -D GAME_MUSIC -o xomain.obj xomain.asm',
 'unias -c -D GAME_MUSIC -o xocfg.obj xocfg.asm',
 'unild -o xoobj.pgm xomain.obj xocfg.obj',
 'uniar r xcfg.lib xocfg.obj',
 'unild -o xolib.pgm xomain.obj xcfg.lib',
 'unias -c -o nmain.obj main.asm',
 'unias -c -o nhelp.obj help.asm',
 'unild -o nmain.pgm nmain.obj nhelp.obj',
 'uniar r ntest.lib nhelp.obj',
 'unild -o nlib.pgm nmain.obj ntest.lib',
 'unias -c -o wroot.obj wroot.asm',
 'unias -c -o whelp.obj whelp.asm',
 'unild -o wnew.pgm wroot.obj whelp.obj',
 'unild /c -o wcmd.cmd wroot.obj whelp.obj',
 'unild /p -o walign.pgm wroot.obj whelp.obj',
 'unias -c -o rroot.obj rroot.asm',
 'unias -c -o rhelp.obj rhelp.asm',
 'unild -o rnew.pgm rroot.obj arref.lib',
 'unias -c -o radix.obj radix.asm',
 'unicc -o ldnat.asm unild.c',
 'unias -o ldnat.cmd ldnat.asm',
 'unicc -o arnat.asm uniar.c',
 'unias -o arnat.cmd arnat.asm',
]
if a.smoke:commands=commands[10:]
def run_cross(command):
    args=command.split();args=[s.upper() if not s.startswith('-') and '.' in s else s for s in args]
    with (cross/(args[0]+'-'+str(run_cross.index)+'.log')).open('wb') as log:
        subprocess.run([str(tc/args[0]),*args[1:]],cwd=cross,stdout=log,stderr=subprocess.STDOUT,check=True)
    run_cross.index+=1
run_cross.index=0
for cmd in commands:run_cross(cmd)
for x,y in ([] if a.smoke else [('XONIX.PGM','XOSOLO.PGM'),('XOOBJ.PGM','XOLIB.PGM')]):
    assert (cross/x).read_bytes()==(cross/y).read_bytes()
run_cross('unild -o old.pgm omain.obj ohelp.obj')
files={}
for name,data in sources.items():
    base,ext=name.rsplit('.',1);short=base[:8]+'.'+ext[:3]
    assert short not in files;files[short]=data
for n in ('ZVM6303.ROM','ZVM6800.ROM','UNIAS.CMD','UNICC.CMD','UNILD.CMD','UNIAR.CMD','SYSTEM.H'):
    files[n]=(tc/'pyldin'/n).read_bytes()
for n in ('UNILD.C','UNIAR.C','TOOLIO.C'):files[n]=(tc/n).read_bytes()
for n in ('MAIN.ASM','HELP.ASM','RADIX.ASM','WROOT.ASM','WHELP.ASM','OMAIN.OBJ','OHELP.OBJ','ONOENT.OBJ','ORIG.LIB','RROOT.ASM','RHELP.ASM','ARREF.LIB'):
    files[n]=(fixtures/n).read_bytes()
files['CROOT.OBJ']=(cross/'WROOT.OBJ').read_bytes()
files['PROOT.OBJ']=(cross/'WROOT.OBJ').read_bytes()
files['LROOT.OBJ']=(cross/'NMAIN.OBJ').read_bytes()
files['MAIN.OBJ']=(cross/'NMAIN.OBJ').read_bytes()
files['HELP.OBJ']=(cross/'NHELP.OBJ').read_bytes()
files['RAMLOAD.PGM']=(ROOT/'build/ramloader/RAMLOAD.PGM').read_bytes()
files['ULINK.CMD']=(ROOT/'build/romdisk-extracted/unpacked/ULINK.CMD').read_bytes()
base=bytearray((ROOT/'images/sd.img').read_bytes())
start,length=struct.unpack_from('<II',base,486)
base[start*512:(start+length)*512]=blank_disk(length*512)
image,_=install(base,files,replace=True)
image,_=install(image,{'SYSTEM.H':files['SYSTEM.H']},drive='A',replace=True)
imagepath=out/'INPUT.IMG';imagepath.write_bytes(image)
commands+=['nmain.pgm\tOBJECT PASS','nlib.pgm\tOBJECT PASS',
           'ldnat -o rebuilt.pgm nmain.obj nhelp.obj',
           'arnat r rebuilt.lib nhelp.obj',
           'ulink main help','ulink lroot orig','ulink omain onoent',
           'ulink rroot arref','rroot.pgm',
           'ulink wroot whelp','ulink /c croot whelp','ulink /p proot whelp']
if a.resume:
    assert not a.smoke
    commands=commands[5:10]+[c for c in commands if c.startswith('unias -c -o radix.obj')]
commandpath=out/('resume-commands.txt' if a.resume else 'commands.txt');commandpath.write_text('\n'.join(commands)+'\n')
runner=out/'test_native_tools'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_native_tools.c','-o',str(runner)],cwd=ROOT,check=True)
cases=[('601','hd6303')] if a.quick else [(m,c) for m in ('601','601a') for c in ('mc6800','hd6303')]
report={'execution':'native tools, real BIOS/UniDOS, reference CPU','tools':{n:hashlib.sha256(d).hexdigest() for n,d in files.items() if n.endswith(('.CMD','.ROM'))},'retest_commands':commands if a.resume else None,'cases':[]}
expected=['BIOS.ROM','BIOS_A.ROM','XONIX.PGM','XOSOLO.OBJ','XOSOLO.PGM',
          'XOMAIN.OBJ','XOCFG.OBJ','XOOBJ.PGM','XCFG.LIB','XOLIB.PGM',
          'NMAIN.OBJ','NHELP.OBJ','NMAIN.PGM','NTEST.LIB','NLIB.PGM',
          'RADIX.OBJ','RNEW.PGM','WNEW.PGM','WCMD.CMD','WALIGN.PGM','LDNAT.ASM','LDNAT.CMD','ARNAT.ASM','ARNAT.CMD']
if a.smoke:expected=expected[10:]
def native_case(case):
    model,cpu=case
    native=out/(model+'-'+cpu);native.mkdir(exist_ok=True)
    caseimage=imagepath
    if a.resume:
        previous=(native/'STATE.IMG').read_bytes()
        resumed,_=install(previous,files,replace=True)
        caseimage=native/'RESUME.IMG';caseimage.write_bytes(resumed)
    print('Native toolchain:',model,cpu,'log:',native/'run.log',flush=True)
    if a.resume and (native/'run.log').exists():
        shutil.copyfile(native/'run.log',native/'previous-run.log')
    with (native/'run.log').open('wb') as log:
        r=subprocess.run([str(runner),str(caseimage),model,cpu,str(native),str(commandpath)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    if r.returncode:
        print((native/'run.log').read_text(errors='replace')[-9000:]);r.check_returncode()
    state=(native/'STATE.IMG').read_bytes()
    outputs=root_files(state[start*512:(start+length)*512])
    results=[]
    for name in expected:
        actual=outputs[name];want=(cross/name).read_bytes()
        assert actual==want,(model,cpu,name,len(actual),len(want))
        (native/name).write_bytes(actual)
        results.append({'file':name,'bytes':len(actual),'sha256':hashlib.sha256(actual).hexdigest(),'identical':True})
    for result,want in [('MAIN.PGM','NMAIN.PGM'),('OMAIN.PGM','OLD.PGM'),('REBUILT.PGM','NMAIN.PGM'),('REBUILT.LIB','NTEST.LIB'),('CROOT.CMD','WCMD.CMD')]:
        assert outputs[result]==(cross/want).read_bytes(),(model,cpu,result)
    def pgm_parts(data):
        n,off,code,entry,bss=struct.unpack_from('>5H',data,2)
        assert off>=16+2*n and len(data)==off+code
        return data[off:],entry,bss,data[16:16+2*n]
    for old,new in [('WROOT.PGM','WNEW.PGM'),('PROOT.PGM','WALIGN.PGM'),('RROOT.PGM','RNEW.PGM')]:
        assert pgm_parts(outputs[old])==pgm_parts((cross/new).read_bytes()),(model,cpu,old)
    legacy_lib=outputs['LROOT.PGM']
    n,off=struct.unpack_from('>2H',legacy_lib,2)
    limitation=None
    if off<16+2*n:
        limitation='Original ULINK underallocates PGM relocation space for a library member with internal relocations; same original UniLIB container. UniLD output is correct.'
    else:assert pgm_parts(legacy_lib)==pgm_parts((cross/'NMAIN.PGM').read_bytes())
    print('PASS',model,cpu,'native compiler/assembler/linker/librarian, BIOS/XONIX and legacy ULINK',flush=True)
    return {'model':model,'cpu':cpu,'files':results,'modular_retest':a.resume,'legacy_ulink':'plain OBJ, original UniLIB, original UniCROSS OBJ, byte widths, CMD and page alignment verified','reference_limitation':limitation}
with ThreadPoolExecutor(max_workers=a.jobs) as pool:
    report['cases']=list(pool.map(native_case,cases))
(out/('smoke.json' if a.smoke else 'comparison.json')).write_text(json.dumps(report,indent=2)+'\n')
