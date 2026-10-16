"""Assemble the actual MC6800 software PS/2 driver for an HDL CPU test."""
from pathlib import Path
import os,sys,struct,shutil
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from unias import assemble
out=ROOT/'build/mouse-driver';out.mkdir(parents=True,exist_ok=True)
shutil.copyfile(ROOT/'firmware/input/MOUSE.ASM',out/'MOUSE.ASM')
(out/'ABI.ASM').write_text('''    .define MOUSE_FIXED
    org $0800
    jmp start
    include MOUSE.ASM
start
    sei
    lds #$9fff
    jsr mouse_init
    tsta
    beq *+5
    jmp failed
    ldaa #$80
    staa mouse_show
    ldaa #1
    staa $0700
loop
    jsr mouse_poll
    tsta
    beq loop
    ldx mouse_x
    stx $0704
    ldx mouse_y
    stx $0706
    ldaa mouse_buttons
    staa $0708
    ldaa mouse_pressed
    staa $0709
    ldaa mouse_released
    staa $070a
    inc $0701
    ldaa $0701
    cmpa #5
    bne loop
    jsr mouse_close
    ldaa #$a5
    staa $070f
stop
    bra stop
failed
    ldaa #1
    staa $070f
    bra stop
    end
''')
program=assemble(None,out,'ABI.ASM','ABI.BIN')
assert len(program)<8192 and program[:2]!=b'\xa5\x5a'
for model in (0,1):
 for hd in (0,1):
  for speed in range(4):
   ram=bytearray(65536);ram[0x800:0x800+len(program)]=program
   header=bytearray(64);header[:8]=b'P601BOOT'
   for at,val in ((8,2),(12,0x10000),(16,0x11800)):struct.pack_into('<I',header,at,val)
   header[25]=model;ram[0x300:0x340]=header
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
   boot=assemble(None,out,'BOOT.ASM','BOOT.BIN');ram[0x100:0x100+len(boot)]=boot
   (out/f'ram-{model}-{hd}-{speed}.mem').write_text(''.join(f'{ram[i+1]:02x}{ram[i]:02x}\n' for i in range(0,65536,2)))
boot=bytearray([255]*8192);boot[:3]=bytes.fromhex('7e0100');boot[4094:4096]=bytes.fromhex('f000')
(out/'boot.mem').write_text(''.join(f'{b:02x}\n' for b in boot))
print(f'Prepared actual software mouse driver: {len(program)} native bytes')
