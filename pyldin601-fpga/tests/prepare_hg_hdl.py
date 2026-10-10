"""Restore real UniDOS with its resident HG.PGM; run native INT40 and HG TIME."""
from pathlib import Path
import importlib.util
import re
import struct
import json

root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('asm',root/'tools/asm6800.py')
asm=importlib.util.module_from_spec(spec);spec.loader.exec_module(asm)
ram=bytearray((root/'build/hgdisk-ram.bin').read_bytes())
pgm=(root/'build/hg/HG.PGM').read_bytes()
_,count,offset,length,*_=struct.unpack('>8H',pgm[:16])
relocs=struct.unpack(f'>{count}H',pgm[16:offset]);code=pgm[offset:]
base=None
for candidate in range(0x100,0xc000,256):
    prefix=bytearray(code[:32])
    for pos in relocs:
        if pos<len(prefix):prefix[pos]=(prefix[pos]+(candidate>>8))&255
    if ram[candidate:candidate+32]==prefix:
        assert base is None
        base=candidate
assert base is not None,'resident HG.PGM not found in real native RAM'
symbols=dict((name,int(value,16)) for name,value in re.findall(r'^([A-Z_0-9]+) =\$([0-9A-F]+)$',(root/'build/hg/HG.LST').read_text(),re.M))
source=f'''org $0100
cli
ldaa #1
staa $0381
ldx #$0300
ldaa #1
swi
db $40
tsta
bne failed
ldaa #2
staa $0381
ldx #$0300
ldaa #2
swi
db $40
tsta
bne failed
ldaa #3
staa $0381
jsr ${base+symbols['SYNC_TIME']:04x}
bcs failed
ldaa #$a5
staa $0380
halt: bra halt
failed:
ldaa #$ee
staa $0380
bra halt
'''
program,_=asm.assemble(source,0x100)
ram[0x100:0x100+len(program)]=program
ram[0x300:0x305]=bytes((0x40,0,json.loads((root/'build/hgdisk-context.json').read_text())['hg_drive'],0x7f,0xdf))  # E:, last FAT12 sector 32735
ram[0x380]=0
(root/'build/hgdisk-ram.bin').write_bytes(ram)
(root/'build/hgdisk-expected-ram.bin').write_bytes(ram)
print(f'Resident HG.PGM at {base:04x}; native INT40 read/write + TIME with original BIOS IRQs')
