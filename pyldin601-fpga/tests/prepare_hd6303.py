"""HD6303 differential probes: documented 6801 and Hitachi extensions only."""
from pathlib import Path
import importlib.util, random
root=Path(__file__).resolve().parents[1]
sp=importlib.util.spec_from_file_location('asm',root/'tools/asm6800.py')
asm=importlib.util.module_from_spec(sp);sp.loader.exec_module(asm)
rng=random.Random(6303)
s=['org $1000','lds #$9000'];out=0xa000

def seed(a,b,x,flags):
 s.extend([f'ldaa #${a:02x}',f'ldab #${b:02x}',f'ldx #${x:04x}','psha',f'ldaa #${flags|16:02x}','tap','pula'])
def record():
 global out
 s.extend(['psha','tpa',f'staa ${out:04x}','pula',f'staa ${out+1:04x}',f'stab ${out+2:04x}',f'stx ${out+3:04x}']);out+=5
# Shift/exchange/unsigned ABX and multiply: all CCR combinations and boundaries.
for op in (4,5,0x18,0x3a,0x3d):
 for flags in range(64):
  for a,b,x in [[(0,0,0xffff),(0xff,0xff,0x8000),(0x80,1,0xff80),(rng.randrange(256),rng.randrange(256),rng.randrange(65536))][flags%4]]:
   seed(a,b,x,flags);s.append(f'db ${op:02x}');record()
# Every D arithmetic/load addressing mode, word carries and wrap at FFFF.
for op in (0x83,0xc3,0xcc):
 for mode in range(4):
  for left,right in [(0,0),(0,1),(0xffff,1),(0x7fff,1),(0x8000,0xffff),(0xff,0x100),(0x1234,0x1234)]:
   s.extend([f'ldaa #${right>>8:02x}','staa $80','staa $8000',f'ldaa #${right&255:02x}','staa $81','staa $8001'])
   seed(left>>8,left&255,0x8000,rng.randrange(64))
   operand=f'${right>>8:02x},${right&255:02x}' if mode==0 else '$80' if mode==1 else '$00' if mode==2 else '$80,$00'
   s.append(f'db ${op+16*mode:02x},{operand}');record()
# STD modes and flags, PSHX/PULX byte order and direct JSR.
for op,args,addr in [(0xdd,'$80',0x80),(0xed,'$ff',0x80ff),(0xfd,'$80,$01',0x8001)]:
 for d in (0,1,0x8000,0xffff):
  seed(d>>8,d&255,0x8000,0x3f);s.append(f'db ${op:02x},{args}');record()
  s.extend([f'ldaa ${addr:04x}',f'staa ${out:04x}',f'ldaa ${addr+1:04x}',f'staa ${out+1:04x}']);out+=2
seed(0x5a,0xc3,0xabcd,0x3f);s.extend(['db $3c','ldx #0','db $38']);record()
s.extend(['db $9d,$c0']);record()
s.extend(['db $21,$ff']);record() # BRN consumes displacement, never branches.
# Immediate-mask operations at low/upper direct addresses and indexed carry/wrap.
for op in (0x61,0x62,0x65,0x6b,0x71,0x72,0x75,0x7b):
 for n in range(16):
  flags=rng.randrange(64);value=rng.randrange(256);mask=rng.randrange(256)
  offset=(0,1,0x80,0xff)[n%4];x=(0x8000,0xff01)[n%2]
  addr=((x+offset)&0xffff) if op<0x70 else offset
  if addr<0x20: addr=0x80;offset=0x80 if op>=0x70 else offset;x=0 if op<0x70 else x
  # Do not overwrite reset/interrupt vectors in this differential image.
  if addr>=0xffee: x=0xff00;offset=1;addr=0xff01
  s.extend([f'ldaa #${value:02x}',f'staa ${addr:04x}'])
  seed(0x33,0xaa,x,flags);s.append(f'db ${op:02x},${mask:02x},${offset:02x}');record()
  s.extend([f'ldaa ${addr:04x}',f'staa ${out:04x}']);out+=1
# Full-word CPX differs from classic high/low byte comparison, including C.
for x,y in [(0x100,0xff),(0xff,0x100),(0,0xffff),(0x8000,1),(0x7fff,0xffff),(0,0)]:
 seed(0x12,0x34,x,0x3f);s.append(f'cpx #${y:04x}');record()
s.extend(['ldaa #$aa','staa $efff','done:','bra done','org $c0','inca','rts','org $fffe','dw $1000'])
binary,labels=asm.assemble('\n'.join(s),0,65536)
assert labels['done']<0x8000 and out<0xe000, 'probe regions overlap'
(root/'build/hd6303.bin').write_bytes(binary)
(root/'build/hd6303.mem').write_text(''.join(f'{v:02x}\n' for v in binary))
(root/'build/hd6303-probes.asm').write_text('\n'.join(s)+'\n')
print(f'Prepared {out-0xa000} HD6303 differential result bytes')
