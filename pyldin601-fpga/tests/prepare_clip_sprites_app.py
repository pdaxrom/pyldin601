"""Relocate CLIPSPR.PGM for the production VHDL CPU and real SRAM fixture."""
from pathlib import Path
import struct
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
import asm6800

root = Path(__file__).resolve().parents[1]
pgm = (root/'build/gfx/CLIPSPR.PGM').read_bytes()
_, count, offset, length, entry, *_ = struct.unpack('>8H', pgm[:16])
ram = bytearray(65536)
code = bytearray(pgm[offset:])
for pos in struct.unpack(f'>{count}H', pgm[16:offset]):
    code[pos] = (code[pos]+0x20) & 255
ram[0x2000:0x2000+length] = code
service = '''org $0100
tsx
ldx 5,x
ldaa 0,x
inx
stx $03a0
tsx
ldab $03a0
stab 5,x
ldab $03a1
stab 6,x
cmpa #$38
beq exit
cmpa #$10
beq peek
cmpa #$11
beq consume
rti
peek: ldaa $0382
bne key
ldaa #$ff
bra key
consume: ldaa $0382
clr $0382
key: staa 2,x
rti
exit: ldaa #$a5
staa $0380
halt: bra halt
'''
binary, _ = asm6800.assemble(service, 0x100)
ram[0x100:0x100+len(binary)] = binary
header = bytearray(64)
header[:8] = b'P601BOOT'
for at, value in [(8,2),(12,0x10000),(16,0x11800)]:
    struct.pack_into('<I', header, at, value)
for model in (0,1):
    for speed in range(4):
        header[25] = model
        ram[0x300:0x340] = header
        source = f'''org $0800
sei
lds #$bfff
ldaa #{2+model+speed*4}
staa $e6a0
ldx #$0300
loop: ldaa 0,x
staa $e6a3
inx
cpx #$0340
bne loop
ldaa #$a5
staa $e6a0
jmp ${0x2000+entry:04x}
'''
        binary, _ = asm6800.assemble(source, 0x800)
        ram[0x800:0x800+len(binary)] = binary
        words = [ram[i] | ram[i+1]<<8 for i in range(0,65536,2)]
        (root/f'build/clip-sprites-app-{model}-{speed}.mem').write_text(''.join(f'{v:04x}\n' for v in words))
boot = bytearray([255]*8192)
boot[:3] = bytes.fromhex('7e0800')
boot[4094:4096] = bytes.fromhex('f000')
(root/'build/clip-sprites-app-boot.mem').write_text(''.join(f'{v:02x}\n' for v in boot))
