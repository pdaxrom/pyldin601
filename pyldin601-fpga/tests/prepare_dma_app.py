"""Install DMATEST and the tiny native GAMEBIOS exit fixture on a disposable B:."""
from pathlib import Path
import os
import shutil
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install
from unias import assemble
out=ROOT/'build/dma-bios';out.mkdir(parents=True,exist_ok=True)
shutil.copyfile(ROOT/'firmware/game/GAMEBIOS.INC',out/'GAMEBIOS.INC')
(out/'EXIT.ASM').write_text('''    include GAMEBIOS.INC
    ldx #context
    ldd #GB_CONTEXT_BYTES
    std 0,x
    ldaa #GB_ABI
    staa 2,x
    ldaa #3
    staa 3,x
    ldaa #GB_OPEN
    int GB_INT
    tsta
    bne close
    ldaa #GB_MODE
    ldab #1
    int GB_INT
    ldaa #7
    staa GB_PS2_CONTROL
close
    ldaa #GB_CLOSE
    int GB_INT
    clra
    int $38
context ds GB_CONTEXT_BYTES
    end
''')
unias=os.environ.get('UNIAS',str(ROOT.parents[2]/'FPGA/hd6303-toolchain/unias'))
exit_program=assemble(unias,out,'EXIT.ASM','EXIT.PGM')
image,_=install((ROOT/'images/sd.img').read_bytes(),{'DMATEST.PGM':(ROOT/'build/memory-test/DMATEST.PGM').read_bytes(),'GAMEEXIT.PGM':exit_program},replace=True)
(out/'app-sd.img').write_bytes(image)
