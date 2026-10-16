"""Run the real software mouse driver against the HDL PS/2 pins and CPU."""
import argparse,json,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--nvc',default='nvc');p.add_argument('--speeds',nargs='+',type=int,default=[0,1,2,3])
p.add_argument('--models',nargs='+',type=int,default=[0,1]);p.add_argument('--cpus',nargs='+',type=int,default=[0,1])
a=p.parse_args();out=ROOT/'build/mouse-driver'
subprocess.run([sys.executable,'tests/prepare_mouse_driver.py'],cwd=ROOT,check=True)
cmd=[a.nvc,'--std=2008','--work=work:build/mouse-driver/rtl','--ieee-warnings=off']
with (out/'compile.log').open('w') as log:
 subprocess.run([*cmd,'-a','rtl/cpu6800.vhd',*map(str,sorted((ROOT/'rtl').glob('*.v'))),'tests/fast_clock.v','tests/tb_mouse_driver.v','tests/tb_mouse_driver.vhd'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
results=[]
for model in a.models:
 for hd in a.cpus:
  for speed in a.speeds:
   shutil.copyfile(out/f'ram-{model}-{hd}-{speed}.mem',out/'ram.mem')
   start=time.monotonic();path=out/f'rtl-{model}-{hd}-{speed}.log'
   with path.open('w') as log:
    result=subprocess.run([*cmd,'-e','-j',f'-gMODEL_A={model}',f'-gHD={hd}',f'-gSPEED={speed}','tb_mouse_driver','-r','tb_mouse_driver'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
   passes=[s for s in path.read_text().splitlines() if s.startswith('PASS actual HDL CPU software PS/2 mouse')]
   if result.returncode or len(passes)!=1:
    print(path.read_text()[-6000:]);raise RuntimeError(f'Mouse software driver failed: {path}')
   results.append(dict(model=model,hd=hd,speed=speed,seconds=round(time.monotonic()-start,2),result=passes[0]))
   (out/'results.json').write_text(json.dumps(results,indent=2)+'\n');print(passes[0],flush=True)

for hd in a.cpus:
 for speed in a.speeds:
  for failure in (1,2):
   shutil.copyfile(out/f'ram-0-{hd}-{speed}.mem',out/'ram.mem')
   path=out/f'failure-{hd}-{speed}-{failure}.log'
   with path.open('w') as log:
    result=subprocess.run([*cmd,'-e','-j',f'-gMODEL_A=0',f'-gHD={hd}',f'-gSPEED={speed}',f'-gFAILURE={failure}','tb_mouse_driver','-r','tb_mouse_driver'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
   passes=[s for s in path.read_text().splitlines() if s.startswith('PASS actual HDL CPU software PS/2 mouse failure=')]
   if result.returncode or len(passes)!=1:
    print(path.read_text()[-6000:]);raise RuntimeError(f'Mouse failure handling failed: {path}')
   results.append(dict(model=0,hd=hd,speed=speed,failure=failure,result=passes[0]))
   (out/'results.json').write_text(json.dumps(results,indent=2)+'\n');print(passes[0],flush=True)
