"""Prepare real booted native BIOS vectors, ROMs and a DMA/IRQ test program."""
from pathlib import Path
import os
import shutil
import struct
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from unias import assemble
out = ROOT / 'build/dma-bios'
out.mkdir(parents=True, exist_ok=True)
(ROOT/'build/gamebios').mkdir(parents=True,exist_ok=True)
subprocess.run([os.environ.get('CC','cc'), '-O2', '-I../pyldin601/src', 'tests/prepare_gamebios.c', '-o', str(out/'prepare')], cwd=ROOT, check=True)
shutil.copyfile(ROOT/'tests/dma_bios_abi.asm',out/'ABI.ASM')
unias=os.environ.get('UNIAS',str(ROOT.parents[2]/'FPGA/hd6303-toolchain/unias'))
program=assemble(unias,out,'ABI.ASM','ABI.BIN')
for model in (0,1):
    name='601a' if model else '601'
    subprocess.run([str(out/'prepare'),'build/test-sd.img',name],cwd=ROOT,check=True)
    ram=bytearray((ROOT/f'build/gamebios/RAM-{name}.bin').read_bytes())
    ram[0x700:0x710]=bytes(16)
    ram[0x6000]=0x76
    ram[0x800:0x800+len(program)]=program
    rom=(ROOT/('build/rom-a.reference' if model else 'build/rom.reference')).read_bytes()[512:]
    signature=bytes.fromhex('b6e6e02bfb')
    bios=rom[65536:65536+4096];assert bios.count(signature)==1
    (out/f'wait-{model}.mem').write_text(f'{0xf000+bios.index(signature):04x}\n')
    (out/f'rom-{model}.mem').write_text(''.join(f'{rom[i+1]:02x}{rom[i]:02x}\n' for i in range(0,len(rom),2)))
    for hd in (0,1):
        for speed in range(4):
            header=bytearray(64);header[:8]=b'P601BOOT'
            for at,value in ((8,2),(12,0x10000),(16,0x11800)):
                struct.pack_into('<I',header,at,value)
            header[25]=model
            ram[0x300:0x340]=header
            (out/'BOOT.ASM').write_text(f'''    org $0100
    sei
    lds #$9fff
    ldaa #{model+hd*2+speed*4}
    staa $e6a0
    ldx #$0300
header
    ldaa 0,x
    staa $e6a3
    inx
    cpx #$0340
    bne header
    ldaa #$a5
    staa $e6a0
    jmp $0800
    end
''')
            boot=assemble(unias,out,'BOOT.ASM','BOOT.BIN')
            ram[0x100:0x100+len(boot)]=boot
            (out/f'ram-{model}-{hd}-{speed}.mem').write_text(''.join(f'{ram[i+1]:02x}{ram[i]:02x}\n' for i in range(0,65536,2)))
boot=bytearray([255]*8192);boot[:3]=bytes.fromhex('7e0100');boot[4094:4096]=bytes.fromhex('f000')
(out/'boot.mem').write_text(''.join(f'{b:02x}\n' for b in boot))
print('Prepared production DMA/native BIOS/IRQ fixtures',flush=True)
