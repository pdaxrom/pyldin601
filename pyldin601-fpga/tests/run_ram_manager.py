"""Run actual MC6800 ROM allocator and native DOS process cleanup."""
import argparse
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build_partitions import assemble
from build_memory_test import build as build_memory
from add_disk_files import install
p=argparse.ArgumentParser();p.add_argument('--unias',required=True);p.add_argument('--cc',default='cc');a=p.parse_args()
out=ROOT/'build/ram-manager';out.mkdir(parents=True,exist_ok=True)
(out/'RAMLEAK.ASM').write_text('''    clra
    int $e5
    cmpa #1
    bne failed
    ldaa #1
    ldab #8
    ldx #lease
    int $e5
    tsta
    bne failed
    clra
    int $38
failed
    ldaa #1
    int $38
lease ds 114
    end
''')
leak=assemble(a.unias,out,'RAMLEAK.ASM','RAMLEAK.PGM')
build_memory(a.unias)
image,_=install((ROOT/'images/sd.img').read_bytes(),{'RAMLEAK.PGM':leak,'RAMALLOC.PGM':(ROOT/'build/memory-test/RAMALLOC.PGM').read_bytes()},replace=True)
(out/'sd-test.img').write_bytes(image)
runner=out/'test_ram_manager'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_ram_manager.c','-o',str(runner)],cwd=ROOT,check=True)
for model in ('601','601a'):
    for cpu in ('mc6800','hd6303'):
        subprocess.run([str(runner),str(out/'sd-test.img'),model,cpu],cwd=ROOT,check=True)
