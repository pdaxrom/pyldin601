"""Short integration fixture: real CPU programs commit metadata; ROM SRAM preloaded.
CRC is deliberately empty in this fixture; full payload CRC is covered separately.
"""
from pathlib import Path
import unias_fixture as asm
from unias import data_source
import sys
root=Path(__file__).parents[1]
settings=int(sys.argv[1],0) if len(sys.argv)>1 and sys.argv[1]!='601a' else (1 if len(sys.argv)>1 else 0)
assert 0 <= settings <= 15
model_a=bool(settings&1)
b=bytearray(root.joinpath('build/rom-a.reference' if model_a else 'build/rom.reference').read_bytes()[:64]);b[20:24]=bytes(4)
image=root.joinpath('build/test-sd.img').read_bytes()
source=f'''    org $f000
    sei
    lds #$1fff
    ldaa #{settings}
    staa $e6a0
    ldaa #$40
    staa $e6a2
    clr $e6aa
    ldx #config
    ldab #64
send
    ldaa 0,x
    staa $e6a3
    inx
    decb
    bne send
    jmp $e000
config
'''+ data_source(b)+'\n    ds $fff8-*,$ff\n    org $fff8\n    dw $f000,$f000,$f000,$f000\n'
binary,_=asm.assemble(source,0xf000,4096)
binary+=b'\xff'*4096
root.joinpath('build/handoff-boot.mem').write_text(''.join(f'{v:02x}\n' for v in binary))
