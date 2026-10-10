"""Real HVIEW PGM, with small SWI/boot fixtures assembled by UniAS itself."""
import argparse
from pathlib import Path
import shutil
import struct
import subprocess
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--unias',default='unias');args=p.parse_args()
unias=shutil.which(args.unias) or str(Path(args.unias).resolve())
work=root/'build/hview-app';work.mkdir(parents=True,exist_ok=True)
def assemble(name,source):
    (work/f'{name}.asm').write_text(source)
    result=subprocess.run([unias,'-l',f'{name}.lst','-o',f'{name}.bin',f'{name}.asm'],cwd=work,capture_output=True,text=True)
    (work/f'{name}.log').write_text(result.stdout+result.stderr)
    assert not result.returncode and 'Error:' not in result.stdout,work/f'{name}.log'
    return (work/f'{name}.bin').read_bytes()
pgm=(root/'build/gfx/HVIEW.PGM').read_bytes()
magic,count,offset,length,entry,bss,*_=struct.unpack('>8H',pgm[:16]);assert magic==0xa55a
ram=bytearray(65536);code=bytearray(pgm[offset:])
for pos in struct.unpack(f'>{count}H',pgm[16:offset]):code[pos]=(code[pos]+0x20)&255
assert 0x2000+length+bss<0x6000
ram[0x2000:0x2000+length]=code
picture=(root/'build/hview/RUNS.IFF').read_bytes();assert len(picture)<0x2000
ram[0x6000:0x6000+len(picture)]=picture
source=''' org $0100
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
'''
for n,label in [(0x38,'exit'),(0x10,'keyboard'),(0x11,'keyboard'),(0x3b,'argc'),(0x3c,'argv'),(0x4a,'open'),(0x4c,'read'),(0x51,'size')]:
    source+=f' cmpa #${n:02x}\n bne next_{label}_{n}\n jmp {label}\nnext_{label}_{n}\n'
source+=f'''return_ok
 tsx
 clr 2,x
 rti
argc
 ldaa #2
 staa 2,x
 rti
argv
 ldd 3,x
 std DEST
 ldx #filename
copy_arg
 ldab 0,x
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
open
 clr FPOS
 clr FPOS+1
 ldaa #1
 staa 1,x
 bra return_ok
size
 ldx 3,x
 clra
 clrb
 std 0,x
 ldd #{len(picture)}
 std 2,x
 bra return_ok
read
 ldx 3,x
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
full_count
 ldd COUNT
 std LEFT
 beq read_done
copy_byte
 ldd FPOS
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
read_done
 tsx
 ldd COUNT
 std 3,x
 jmp return_ok
keyboard
 ldaa #1
 staa $0381
wait_escape
 ldaa $0382
 beq wait_escape
 tsx
 ldaa #27
 staa 2,x
 rti
exit
 ldaa #$a5
 staa $0380
halt
 bra halt
filename db 'RUNS.IFF',0
 end
'''
service=assemble('swi',source);assert len(service)<=0x200
ram[0x100:0x100+len(service)]=service
header=bytearray(64);header[:8]=b'P601BOOT'
for at,value in [(8,2),(12,0x10000),(16,0x11800)]:struct.pack_into('<I',header,at,value)
for model in (0,1):
    for speed in range(4):
        h=bytearray(header);h[25]=model;ram[0x300:0x340]=h
        boot=assemble(f'start-{model}-{speed}',f''' org $0800
 sei
 lds #$bfff
 ldaa #{model+speed*4+2}
 staa $e6a0
 ldx #$0300
copy_config
 ldaa 0,x
 staa $e6a3
 inx
 cpx #$0340
 bne copy_config
 ldaa #$a5
 staa $e6a0
 jmp ${0x2000+entry:04x}
 end
''')
        ram[0x800:0x800+len(boot)]=boot
        (root/f'build/hview-app-{model}-{speed}.mem').write_text(''.join(f'{ram[i]|ram[i+1]<<8:04x}\n' for i in range(0,65536,2)))
boot=bytearray([255]*8192);boot[:3]=bytes.fromhex('7e0800');boot[4094:4096]=bytes.fromhex('f000')
(root/'build/hview-app-boot.mem').write_text(''.join(f'{v:02x}\n' for v in boot))
(root/'build/hview-app-expected.mem').write_text(''.join(f'{v:02x}\n' for v in (root/'build/hview/RUNS.codes').read_bytes()))
(root/'build/hview-app-palette.mem').write_text(''.join(f'{v:02x}\n' for v in (root/'build/hview/components.bin').read_bytes()))
print(f'Prepared real HVIEW.PGM: {length} code/data + {bss} BSS, {count} relocations; UniAS SWI ABI fixture')
