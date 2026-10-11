"""Restore native DOS registers with an RTI trampoline; no runtime RTL patch."""
from pathlib import Path
import argparse,json,os,sys
root=Path(__file__).parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--prefix',default='runtime',choices=['runtime','session','keyboard','hgdisk'])
parser.add_argument('--speed',type=int,choices=range(4))
parser.add_argument('--unias',default=os.environ.get('UNIAS','unias'))
parser.add_argument('--music-irq',action='store_true')
args=parser.parse_args()
prefix=args.prefix
sys.path.insert(0,str(root/'tools'))
from build_partitions import assemble
ctx=json.loads((root/f'build/{prefix}-context.json').read_text())
config=bytearray((root/f'build/{prefix}-config.bin').read_bytes());config[20:24]=bytes(4)
source='''org $f000
sei
lds #$1fff
ldaa #$40
staa $e6a2
clr $e6aa
ldx #config
ldab #64
send:
ldaa 0,x
staa $e6a3
inx
decb
bne send
jmp $e000
config:
'''+ ''.join('db '+','.join(f'${v:02x}' for v in config[i:i+16])+'\n'
             for i in range(0,len(config),16))+'ds $fff8-*,0\ndw $f000,$f000,$f000,$f000\n'
if ctx.get('model_a',0) or args.speed is not None:
    setting=ctx.get('model_a',0)|((args.speed or 0)<<2)
    source=source.replace('ldaa #$40',f'ldaa #{setting}\nstaa $e6a0\nldaa #$40',1)
out=root/'build/runtime-assembly';out.mkdir(exist_ok=True)
(out/'BOOT.ASM').write_text('\n'.join(line[:-1] if line.endswith(':') else '    '+line
                                    for line in source.splitlines())+'\n    end\n')
boot=assemble(args.unias,out,'BOOT.ASM','BOOT.BIN')
assert len(boot)==4096
(root/f'build/{prefix}-boot.mem').write_text(''.join(f'{v:02x}\n' for v in boot))
ram=bytearray((root/f'build/{prefix}-ram.bin').read_bytes())
# RTI pull order: CC, B, A, X hi/lo, PC hi/lo, above the decremented SP.
frame=bytes([ctx['cc'],ctx['b'],ctx['a'],ctx['x']>>8,ctx['x']&255,ctx['pc']>>8,ctx['pc']&255])
ram[ctx['sp']-6:ctx['sp']+1]=frame
restore=['org $e000','ldaa #$a5','staa $e6a0',f"ldaa #${ctx['page']:02x}",'staa $e6f0',f"ldaa #${ctx['mode']:02x}",'staa $e629']
for reg,value in enumerate(ctx['crtc']):restore += [f'ldaa #{reg}','staa $e600',f'ldaa #{value}','staa $e601']
if args.music_irq:
    # Exercise production audio/PAL/keyboard dispatch together. This tiny
    # MC6800 handler only counts callbacks; YPLAY is tested separately.
    restore += ['ldx #$e100','stx $efc8','ldaa $edf2','anda #$0f','staa $edf2',
                'ldx #0','stx $e180','ldx #$0003','stx $e692',
                'ldx #$a980','stx $e694','ldaa #1','staa $e696','staa $e690']
if prefix in ('keyboard', 'session'):
    from build_partitions import bios_symbols
    kbd=bios_symbols((root/'build/partitions/SD.ROM.LST').read_text())
    # Explicitly reserve fixture-only idle-DOS scratch, away from its saved
    # stack. Heap allocation is exercised by test_keyboard_rom's real boot.
    ram[0x7000:0x7040]=bytes(64)
    ram[0x7000:0x7003]=bytes([0x7e,kbd['KEYBOARD_PUMP']>>8,kbd['KEYBOARD_PUMP']&255])
    ram[0x7009]=255
    ram[0xefce:0xefd0]=bytes([0x70,0])
    restore += ['ldaa #$ff','staa $e628','ldaa #$33','staa $e6b3']
restore += [f"lds #${ctx['sp']-7:04x}",'rti']
restore += ['end']
(out/'RESTORE.ASM').write_text('\n'.join('    '+line for line in restore)+'\n')
trampoline=assemble(args.unias,out,'RESTORE.ASM','RESTORE.BIN')
assert len(trampoline)<256
ram[0xe000:0xe000+len(trampoline)]=trampoline
if args.music_irq:
    (out/'MUSIC.ASM').write_text('    org $e100\n    ldx $e180\n    inx\n    stx $e180\n    rts\n    end\n')
    handler=assemble(args.unias,out,'MUSIC.ASM','MUSIC.BIN')
    ram[0xe100:0xe100+len(handler)]=handler
    ram[0xe180:0xe182]=bytes(2)
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
