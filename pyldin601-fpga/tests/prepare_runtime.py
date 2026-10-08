"""Restore native DOS registers with an RTI trampoline; no runtime RTL patch."""
from pathlib import Path
import argparse,importlib.util,json
root=Path(__file__).parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--prefix',default='runtime',choices=['runtime','session','keyboard','hgdisk'])
parser.add_argument('--speed',type=int,choices=range(4))
args=parser.parse_args()
prefix=args.prefix
spec=importlib.util.spec_from_file_location('asm',root/'tools/asm6800.py')
asm=importlib.util.module_from_spec(spec);spec.loader.exec_module(asm)
ctx=json.loads((root/f'build/{prefix}-context.json').read_text())
config=bytearray((root/f'build/{prefix}-config.bin').read_bytes());config[20:24]=bytes(4)
source='''org $f000
sei
lds #$1fff
ldaa #$40
staa $e6a2
clr $e6aa
ldx #config
ldab #96
send:
ldaa 0,x
staa $e6a3
inx
decb
bne send
jmp $e000
config:
'''+ 'db '+','.join(f'${v:02x}' for v in config)+'\norg $fff8\ndw $f000,$f000,$f000,$f000\n'
if ctx.get('model_a',0) or args.speed is not None:
    setting=ctx.get('model_a',0)|((args.speed or 0)<<2)
    source=source.replace('ldaa #$40',f'ldaa #{setting}\nstaa $e6a0\nldaa #$40',1)
boot,_=asm.assemble(source,0xf000,4096)
(root/f'build/{prefix}-boot.mem').write_text(''.join(f'{v:02x}\n' for v in boot))
ram=bytearray((root/f'build/{prefix}-ram.bin').read_bytes())
# RTI pull order: CC, B, A, X hi/lo, PC hi/lo, above the decremented SP.
frame=bytes([ctx['cc'],ctx['b'],ctx['a'],ctx['x']>>8,ctx['x']&255,ctx['pc']>>8,ctx['pc']&255])
ram[ctx['sp']-6:ctx['sp']+1]=frame
restore=['org $e000','ldaa #$a5','staa $e6a0',f"ldaa #${ctx['page']:02x}",'staa $e6f0',f"ldaa #${ctx['mode']:02x}",'staa $e629']
for reg,value in enumerate(ctx['crtc']):restore += [f'ldaa #{reg}','staa $e600',f'ldaa #{value}','staa $e601']
restore += [f"lds #${ctx['sp']-7:04x}",'rti']
trampoline,_=asm.assemble('\n'.join(restore),0xe000)
ram[0xe000:0xe000+len(trampoline)]=trampoline
rom='rom-a.reference' if ctx.get('model_a',0) else 'rom.reference'
physical=ram+(root/f'build/{rom}').read_bytes()[512:]
(root/f'build/{prefix}-sram.mem').write_text(''.join(f'{physical[j+1]:02x}{physical[j]:02x}\n' for j in range(0,len(physical),2)))
expected=(root/f'build/{prefix}-expected-ram.bin').read_bytes()
# Check only native IRQ changes outside the stack/workspace and I/O mirrors.
# Header integrity is checked independently by the HDL test at completion.
changes=[(addr,expected[addr]) for addr in range(0x10000) if expected[addr]!=ram[addr] and not ctx['sp']-256<=addr<=ctx['sp'] and not 0xe000<=addr<0xe700]
(root/f'build/{prefix}-check.mem').write_text(''.join(f'{addr:04x}{data:02x}\n' for addr,data in changes))
(root/f'build/{prefix}-check.vh').write_text(f'`define RUNTIME_CHECKS {len(changes)}\n')
print(f'{prefix}: {len(changes)} reference RAM changes')
