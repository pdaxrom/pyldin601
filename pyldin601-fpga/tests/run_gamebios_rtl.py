"""Run assembled GAMEBIOS code on the production HD6303 VHDL CPU."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from unias import assemble
p=argparse.ArgumentParser()
p.add_argument('--unias',required=True)
p.add_argument('--cc',default='cc')
p.add_argument('--nvc',default='nvc')
a=p.parse_args()
out=ROOT/'build/gamebios'
out.mkdir(parents=True,exist_ok=True)
shutil.copyfile(ROOT/'tests/gamebios_abi.asm',out/'ABI.ASM')
shutil.copyfile(ROOT/'firmware/game/GAMEBIOS.INC',out/'GAMEBIOS.INC')
program=assemble(a.unias,out,'ABI.ASM','ABI.BIN')
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/prepare_gamebios.c','-o',str(out/'prepare')],cwd=ROOT,check=True)
for model in ('601','601a'):
    subprocess.run([str(out/'prepare'),'images/sd.img',model],cwd=ROOT,check=True)
    ram=bytearray((out/f'RAM-{model}.bin').read_bytes())
    ram[0x800:0x800+len(program)]=program
    (out/f'RAM-{model}.mem').write_text(''.join(f'{n:02x}\n' for n in ram))
    rom=bytearray((ROOT/('build/rom-a.reference' if model=='601a' else 'build/rom.reference')).read_bytes()[512:])
    rom[65536+4094:65536+4096]=bytes.fromhex('0800')
    (out/f'ROM-{model}.mem').write_text(''.join(f'{n:02x}\n' for n in rom))
work='work:'+str(out/'rtl')
subprocess.run([a.nvc,'--std=2008','--work='+work,'--ieee-warnings=off','-a','rtl/cpu6800.vhd','tests/tb_gamebios.vhd'],cwd=ROOT,check=True)
for model in ('601','601a'):
    for hd,speeds in ((False,(0,)),(True,range(4))):
        for speed in speeds:
            result=subprocess.run([a.nvc,'--std=2008','--work='+work,'--ieee-warnings=off','-e',f'-gMODEL={model}',f'-gHD={str(hd).lower()}',f'-gSPEED={speed}','tb_gamebios','-r','tb_gamebios'],cwd=ROOT,capture_output=True,text=True)
            log=result.stdout+result.stderr
            (out/f'rtl-{model}-{hd}-{speed}.log').write_text(log)
            print(log,end='',flush=True)
            if result.returncode or 'PASS actual VHDL CPU/native GAMEBIOS' not in log:
                raise RuntimeError('GAMEBIOS RTL check failed')
