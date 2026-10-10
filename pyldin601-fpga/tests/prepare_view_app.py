"""Execute the real VIEW.PGM in HDL with minimal, explicit UniDOS SWI services.

The native-DOS companion test covers the actual filesystem and PGM loader;
this fixture isolates the decoder, CPU ISA and real SRAM/graphics hardware.
"""
from pathlib import Path
import struct
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
import asm6800

root = Path(__file__).resolve().parents[1]
pgm = (root/'build/gfx/VIEW.PGM').read_bytes()
_, count, offset, length, entry, *_ = struct.unpack('>8H', pgm[:16])
ram = bytearray(65536)
code = bytearray(pgm[offset:])
for pos in struct.unpack(f'>{count}H', pgm[16:offset]):
    code[pos] = (code[pos]+0x20) & 255
ram[0x2000:0x2000+length] = code
picture = (root/'build/view/ODD.PCX').read_bytes()
ram[0x6000:0x6000+len(picture)] = picture
service = f'''org $0100
FPOS equ $03b0
DEST equ $03b2
COUNT equ $03b4
LEFT equ $03b6
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
lbeq exit
cmpa #$20
lbeq keyboard
cmpa #$3b
lbeq argc
cmpa #$3c
lbeq argv
cmpa #$4a
lbeq open
cmpa #$4c
lbeq read
cmpa #$50
lbeq seek
cmpa #$51
lbeq size
return_ok: tsx
clr 2,x
rti
argc: ldaa #2
staa 2,x
rti
argv: ldd 3,x
std DEST
ldx #filename
copy_arg: ldab 0,x
inx
stx $03b8
ldx DEST
stab 0,x
inx
stx DEST
ldx $03b8
tstb
bne copy_arg
bra return_ok
open: clr FPOS
clr FPOS+1
ldaa #1
staa 1,x
bra return_ok
size: ldx 3,x
clra
clrb
std 0,x
ldd #{len(picture)}
std 2,x
bra return_ok
seek: ldab 1,x
ldx 3,x
ldd 2,x
std LEFT
tsx
ldab 1,x
cmpb #2
beq seek_end
ldd LEFT
bra set_position
seek_end: ldd #{len(picture)}
subd LEFT
set_position: std FPOS
bra return_ok
read: ldx 3,x
ldd 0,x
std DEST
ldd 2,x
std COUNT
ldd #{len(picture)}
subd FPOS
subd COUNT
bcc full_count
ldd #{len(picture)}
subd FPOS
std COUNT
full_count: ldd COUNT
std LEFT
beq read_done
copy_byte: ldd FPOS
addd #$6000
xgdx
ldab 0,x
ldx DEST
stab 0,x
inx
stx DEST
ldd FPOS
addd #1
std FPOS
ldd LEFT
subd #1
std LEFT
bne copy_byte
read_done: tsx
ldd COUNT
std 3,x
jmp return_ok
keyboard: ldaa #1
staa $0381
wait_escape: ldaa $0382
beq wait_escape
tsx
ldaa #27
staa 2,x
rti
exit: ldaa #$a5
staa $0380
halt: bra halt
filename: db "ODD.PCX",0
'''
binary, _ = asm6800.assemble(service, 0x100, hd6303=True)
assert 0x100+len(binary) <= 0x300
ram[0x100:0x100+len(binary)] = binary
header = bytearray(64)
header[:8] = b'P601BOOT'
for at, value in [(8,2),(12,0x10000),(16,0x11800)]:
    struct.pack_into('<I', header, at, value)
for model in (0,1):
    for speed in range(4):
        h = bytearray(header);h[25] = model;ram[0x300:0x340] = h
        source = f'''org $0800
sei
lds #$bfff
ldaa #{model+speed*4+2}
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
        (root/f'build/view-app-{model}-{speed}.mem').write_text(''.join(f'{v:04x}\n' for v in words))
boot = bytearray([255]*8192)
boot[:3] = bytes.fromhex('7e0800')
boot[4094:4096] = bytes.fromhex('f000')
(root/'build/view-app-boot.mem').write_text(''.join(f'{v:02x}\n' for v in boot))
(root/'build/view-app-expected.mem').write_text(''.join(f'{v:02x}\n' for v in (root/'build/view/ODD.indices').read_bytes()))
(root/'build/view-app-palette.mem').write_text(''.join(f'{v:02x}\n' for v in (root/'build/view/ODD.palette').read_bytes()))
print(f'Prepared real VIEW.PGM: {length} bytes, {count} relocations; PCX and UniDOS SWI ABI fixture')
