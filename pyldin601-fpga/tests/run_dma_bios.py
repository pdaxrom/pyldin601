"""Run the assembled BIOS on the production VHDL CPU, DMA and SRAM pads."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--nvc',default='nvc')
p.add_argument('--models',nargs='+',type=int,choices=(0,1),default=[0,1])
p.add_argument('--cpus',nargs='+',type=int,choices=(0,1),default=[0,1])
p.add_argument('--speeds',nargs='+',type=int,choices=(0,1,2,3),default=[0,1,2,3])
a=p.parse_args();out=ROOT/'build/dma-bios'
subprocess.run([sys.executable,'tests/prepare_dma_bios.py'],cwd=ROOT,check=True)
cmd=[a.nvc,'--std=2008','--work=work:build/dma-bios/rtl','--ieee-warnings=off']
sources=['rtl/cpu6800.vhd',*map(str,sorted(Path('rtl').glob('*.v'))),'tests/fast_clock.v','tests/tb_dma_bios.v','tests/tb_dma_bios.vhd']
subprocess.run([*cmd,'-a',*sources],cwd=ROOT,check=True)
results=[]
for model in a.models:
    shutil.copyfile(out/f'rom-{model}.mem',out/'rom.mem')
    shutil.copyfile(out/f'wait-{model}.mem',out/'wait.mem')
    for hd in a.cpus:
        for speed in a.speeds:
            shutil.copyfile(out/f'ram-{model}-{hd}-{speed}.mem',out/'ram.mem')
            path=out/f'rtl-{model}-{hd}-{speed}.log';start=time.monotonic()
            with path.open('w') as log:
                result=subprocess.run([*cmd,'-e','-j',f'-gMODEL_A={model}',f'-gHD={hd}',f'-gSPEED={speed}','tb_dma_bios','-r','tb_dma_bios'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
            passes=[s for s in path.read_text().splitlines() if s.startswith('PASS actual HDL CPU/BIOS/shared DMA')]
            if result.returncode or len(passes)!=1:
                print(path.read_text()[-7000:]);raise RuntimeError(f'DMA/native BIOS failed: {path}')
            results.append(dict(model=model,hd=hd,speed=speed,seconds=round(time.monotonic()-start,2),result=passes[0]))
            (out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
            print(passes[0],flush=True)
