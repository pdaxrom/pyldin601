"""Assemble native paging-dispatch fixtures with UniAS; no opcode encoder."""
import argparse
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from build_partitions import assemble,bios_symbols

root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--unias',required=True)
a=p.parse_args()
out=root/'build/ram-pages';out.mkdir(parents=True,exist_ok=True)
(out/'ABI.ASM').write_bytes((root/'tests/ram_pages_abi.asm').read_bytes())
program=assemble(a.unias,out,'ABI.ASM','ABI.BIN')
assert program[:4]==bytes.fromhex('0f8ebfff')
ram=bytearray(65536);ram[0x800:0x800+len(program)]=program;ram[0xc000]=0x27
# Real native BIOS ROM and native vectors, except the reset entry for this
# standalone fixture. The dispatch itself is exactly the shipped build.
for model in ('BIOS','BIOS_A'):
    symbols=bios_symbols((root/f'build/partitions/{model}.ROM.LST').read_text(encoding='latin1'))
    ram[0xee6e:0xee70]=symbols['INT_37'].to_bytes(2,'big')
    (out/f'RAM-{model}.mem').write_text(''.join(f'{b:02x}\n' for b in ram))
    bios=bytearray((root/f'build/partitions/{model}.ROM').read_bytes())
    bios[-2:]=bytes.fromhex('0800')
    (out/f'{model}.mem').write_text(''.join(f'{b:02x}\n' for b in bios))
source='''    org $c000
    ldaa $e6f0
    cmpa #9
    bne fail
    tst $e6f1
    bne fail
    ldaa #12
    staa $e6f1
    ldaa #1
    staa $0707
    rts
fail
    ldaa #$de
    staa $070f
halt
    bra halt
    end
'''
(out/'ROM.ASM').write_text(source)
program=assemble(a.unias,out,'ROM.ASM','ROM.BIN')
rom=bytearray(8192);rom[:len(program)]=program
(out/'ROM.mem').write_text(''.join(f'{b:02x}\n' for b in rom))
print('Prepared real UniAS/native BIOS paging ABI: nested SWI, RAM/ROM handlers, IRQ and nested NMI')
