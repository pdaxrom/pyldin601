"""Differential instruction probes. Golden state comes from the existing classic C core."""
from pathlib import Path
import importlib.util,random,subprocess
root=Path(__file__).resolve().parents[1]
sp=importlib.util.spec_from_file_location('asm',root/'tools/asm6800.py');asm=importlib.util.module_from_spec(sp);sp.loader.exec_module(asm)
rng=random.Random(6800)
source=['org $1000','lds #$9000']
address=0xa000
ops=['nega','coma','lsra','rora','asra','asla','rola','deca','inca','tsta','clra',
     'negb','comb','lsrb','rorb','asrb','aslb','rolb','decb','incb','tstb','clrb','daa',
     'sba','cba','tab','tba','aba','inx','dex']
for i in range(4):
 for op in ops:
  a=rng.randrange(256);b=rng.randrange(256);x=rng.randrange(65536);flags=rng.randrange(64)|16
  # Seed flags after loads; otherwise LDA/LDX erase the selected N/Z/V.
  # PULA restores A without changing those flags.
  source.extend([f'ldaa #${a:02x}',f'ldab #${b:02x}',f'ldx #${x:04x}',
                 'psha',f'ldaa #${flags:02x}','tap','pula',op])
  source.extend(['psha','tpa','anda #$3f',f'staa ${address:04x}','pula',f'staa ${address+1:04x}',f'stab ${address+2:04x}',f'stx ${address+3:04x}']);address+=5
for op in ['suba','cmpa','sbca','anda','bita','eora','adca','oraa','adda','subb','cmpb','sbcb','andb','bitb','eorb','adcb','orab','addb']:
 for mode in ['imm','dir','ext','idx']:
  for operand in [0,1,0x7f,0x80,0xff]:
   a=rng.randrange(256);b=rng.randrange(256)
   flags=rng.randrange(64)|16
   if mode!='imm':source.extend([f'ldaa #${operand:02x}','staa $80' if mode=='dir' else 'staa $8000'])
   source.extend([f'ldaa #${a:02x}',f'ldab #${b:02x}','ldx #$8000',
                  'psha',f'ldaa #${flags:02x}','tap','pula'])
   source.append(f'{op} '+(f'#${operand:02x}' if mode=='imm' else '$80' if mode=='dir' else '$8000' if mode=='ext' else '0,x'))
   source.extend(['psha','tpa','anda #$3f',f'staa ${address:04x}','pula',f'staa ${address+1:04x}',f'stab ${address+2:04x}',f'stx ${address+3:04x}']);address+=5
for op in ['neg','com','lsr','ror','asr','asl','rol','dec','inc','tst','clr']:
 for mode in ['ext','idx']:
  for operand in [0,0x7f,0x80,0xff]:
   flags=rng.randrange(64)|16
   source.extend([f'ldaa #${operand:02x}','staa $8001','ldx #$8000',
                  f'ldaa #${flags:02x}','tap',f'{op} '+('$8001' if mode=='ext' else '1,x'),
                  'tpa',f'staa ${address:04x}','ldaa $8001',f'staa ${address+1:04x}'])
   address+=2
# Exercise every combination of N/Z/V/C for every conditional branch.
for branch in ['bhi','bls','bcc','bcs','bne','beq','bvc','bvs','bpl','bmi','bge','blt','bgt','ble']:
 for flags in range(16):
  label=f'branch_{branch}_{flags}'
  source.extend(['ldab #0',f'ldaa #${flags|16:02x}','tap',f'{branch} {label}',
                 f'bra {label}_record',label+':','incb',label+'_record:',f'stab ${address:04x}'])
  address+=1
# CLR must clear a previously set V in both accumulators and memory. Record
# all CCR bits here, including the fixed ones returned by TPA.
for op in ['clra','clrb','clr $8001','clr 1,x']:
 source.extend(['ldx #$8000','ldaa #$3f','tap',op,'tpa',f'staa ${address:04x}']);address+=1
source.extend(['ldaa #0','tap','tpa',f'staa ${address:04x}']);address+=1
for x,y in [(0x100,0xff),(0xff,0x100),(0xffff,1),(0x8000,1),(0x7fff,0xffff),(0,0),(0x1234,0x1234)]:
 source.extend([f'ldx #${x:04x}',f'cpx #${y:04x}','tpa','anda #$3f',f'staa ${address:04x}']);address+=1
source.extend(['ldaa #$10','jsr sub_ext','bsr sub_rel',f'staa ${address:04x}','lbra after_sub','sub_ext:','psha','ldaa #$fe','pula','adda #3','rts','sub_rel:','adda #4','rts','after_sub:','tsx',f'stx ${address+1:04x}']);address+=3
source.extend(['ldaa #$25','ldab #$63','ldx #$4567','swi',f'staa ${address:04x}',f'stab ${address+1:04x}',f'stx ${address+2:04x}',
 'cli','ldaa #1','staa $effe','irq_wait:','ldaa $ad00','beq irq_wait',f'staa ${address+4:04x}','sei','lbra probes_done',
 'swi_handler:','ldaa #$ff','ldab #$ee','ldx #$dddd','rti',
 'irq_handler:','inc $ad00','clr $effe','rti','probes_done:']);address+=5
source.extend(['ldaa #$aa','staa $efff','done:','bra done','org $8000','db $80','org $fff8','dw irq_handler,swi_handler','org $fffe','dw $1000'])
binary,labels=asm.assemble('\n'.join(source),0,65536)
assert labels['done']<0x8000 and address<=0xac00, 'probe code/result regions overlap'
(root/'build/cpu.bin').write_bytes(binary)
(root/'build/cpu.mem').write_text(''.join(f'{v:02x}\n' for v in binary))
(root/'build/cpu_probes.asm').write_text('\n'.join(source)+'\n')
print('Prepared',address-0xa000,'CPU differential bytes')
