"""Compare 500000 native BIOS instructions per added model/ISA combination."""
import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def run(args):
 p=subprocess.run(args,cwd=root,text=True,capture_output=True)
 if p.returncode:raise SystemExit(p.stdout+p.stderr)
 return p.stdout+p.stderr
run(['python3','tests/prepare_boot_lockstep.py'])
run(['cc','-O2','-I../pyldin601/src','tests/prepare_boot_lockstep.c','-o','build/prepare_boot_modes'])
run(['nvc','--std=2008','--work=work:build/boot-modes','--ieee-warnings=off','-a','build/cpu6800_lockstep.vhd','tests/tb_boot_lockstep.vhd'])
for mode in ('hd','601a','601a-hd'):
 run(['build/prepare_boot_modes','build/models-sd.img',mode])
 hd='true' if mode in ('hd','601a-hd') else 'false'
 rom='build/rom-a-payload.mem' if mode.startswith('601a') else 'build/rom.reference.mem'
 log=run(['nvc','--std=2008','--work=work:build/boot-modes','--ieee-warnings=off','-e',f'-gPREFIX=boot-mode-{mode}-lockstep',f'-gROM_FILE={rom}',f'-gHD={hd}','tb_boot_lockstep','-r','tb_boot_lockstep'])
 (root/f'build/boot-mode-{mode}-lockstep.log').write_text(log)
 if 'PASS 500000 consecutive' not in log:raise SystemExit(log)
 print(f'PASS {mode}: 500000 native BIOS/ROM instructions, all registers/CCR and final RAM',flush=True)
