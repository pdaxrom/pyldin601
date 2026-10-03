"""Short integration fixture: real CPU programs commit metadata; ROM SRAM preloaded.
CRC is deliberately empty in this fixture; full payload CRC is covered separately.
"""
from pathlib import Path
import importlib.util
import sys
root=Path(__file__).parents[1]
s=importlib.util.spec_from_file_location('asm',root/'tools/asm6800.py')
a=importlib.util.module_from_spec(s);s.loader.exec_module(a)
model_a=len(sys.argv)>1 and sys.argv[1]=='601a'
b=bytearray(root.joinpath('build/rom-a.reference' if model_a else 'build/rom.reference').read_bytes()[:64]);b[20:24]=bytes(4)
image=root.joinpath('build/test-sd.img').read_bytes();b+=image[462:494]
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
'''+ 'db '+','.join(f'${v:02x}' for v in b)+'\norg $fff8\ndw $f000,$f000,$f000,$f000\n'
if model_a: source=source.replace('lds #$1fff','lds #$1fff\nldaa #1\nstaa $e6a0')
binary,_=a.assemble(source,0xf000,4096)
root.joinpath('build/handoff-boot.mem').write_text(''.join(f'{v:02x}\n' for v in binary))
