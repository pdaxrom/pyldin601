#!/usr/bin/env python3
"""Execute the exact UniAS commands on the original C reference and RTL CPU.

RTL uses minimal SWI console stubs and a periodic level PAL IRQ; expectations
remain in the application. Real BIOS/UniDOS integration is checked separately.
"""
import argparse
import importlib.util
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/hd6303-apps'
spec = importlib.util.spec_from_file_location('assembler', ROOT / 'tools/asm6800.py')
asm = importlib.util.module_from_spec(spec);spec.loader.exec_module(asm)
STUBS = '''org $f000
irq_handler:
ldaa #0
staa $e62b
rti
org $f040
swi_handler:
tsx
stx $eff2
ldx 5,x
ldaa 0,x
staa $eff1
ldx $eff2
inc 6,x
bne advanced
inc 5,x
advanced:
ldaa $eff1
cmpa #$23
beq print_string
cmpa #$22
beq print_char
cmpa #$38
beq terminate
ldaa #$ee
staa $efff
bra returned
print_string:
ldx $eff2
ldx 3,x
next_char:
ldaa 0,x
beq returned
staa $eff0
inx
bra next_char
print_char:
ldx $eff2
ldaa 2,x
staa $eff0
bra returned
terminate:
ldaa #$aa
staa $efff
returned:
rti
org $ff00
lds #$bfff
cli
jmp $0100
org $fff8
dw irq_handler
dw swi_handler
dw irq_handler
dw $ff00
'''


def run(command, path):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    path.write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(path.read_text())
    return result.stdout + result.stderr


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--nvc', default='nvc')
    args = parser.parse_args()
    stub, _ = asm.assemble(STUBS, 0, 65536)
    for app in ('HDTEST', 'HDMUL', 'HDSLEEP'):
        memory = bytearray(stub)
        data = (OUT / (app+'.CMD')).read_bytes()
        memory[0x100:0x100+len(data)] = data
        memory[0x80:0x82] = b'\x9a\xbc'
        (OUT / (app+'.mem')).write_text(''.join(f'{value:02x}\n' for value in memory))
        if app != 'HDSLEEP':
            run(['build/test_hd6303_apps', str(OUT/(app+'.CMD'))], OUT/(app+'-native.log'))
        run(['build/test_hd6303_apps', str(OUT/(app+'.CMD')), 'classic'], OUT/(app+'-classic-native.log'))
    run(['build/test_hd6303_apps', str(OUT/'HDMUL.CMD'), 'fault'], OUT/'HDMUL-fault-native.log')
    # Add register observation ports only; execute the production CPU logic unchanged.
    cpu = (ROOT/'rtl/cpu6800.vhd').read_text()
    cpu = cpu.replace('entity cpu6800 is','entity cpu6800_lockstep is').replace(
        'architecture CPU_ARCH of cpu6800 is','architecture CPU_ARCH of cpu6800_lockstep is')
    cpu = cpu.replace('test_cc:  out std_logic_vector(7 downto 0)',
        'debug_state: out std_logic_vector(71 downto 0);\n'
        'debug_opcode: out std_logic_vector(7 downto 0);\n'
        'debug_decode: out std_logic;\n'
        'test_cc: out std_logic_vector(7 downto 0)')
    needle='begin\n\n----------------------------------'
    assert needle in cpu
    cpu=cpu.replace(needle,'begin\n'
        "debug_decode <= '1' when state=decode_state else '0';\n"
        'debug_opcode <= op_code;\n'
        'debug_state <= (pc-1) & sp & xreg & acca & accb & cc;\n\n'
        '----------------------------------',1)
    (OUT/'cpu6800_lockstep.vhd').write_text(cpu)
    base=[args.nvc,'--std=2008','--work=work:build/hd-apps-rtl','--ieee-warnings=off']
    run(base+['-a',str(OUT/'cpu6800_lockstep.vhd'),'tests/tb_hd6303_apps.vhd'],OUT/'compile.log')
    for app in ('HDTEST','HDMUL','HDSLEEP'):
        for hd in (True,False):
            log=run(base+['-e','-gAPP='+app,'-gHD='+str(hd).lower(),'tb_hd6303_apps','-r','tb_hd6303_apps'],
                    OUT/(app+('-rtl.log' if hd else '-classic-rtl.log')))
            assert 'PASS actual VHDL executable' in log
            print(log.strip())
    listing=(OUT/'HDTEST.LST').read_text()
    address=int(re.search(r'^V0001\s*=\$([0-9A-F]{4})\s*$',listing,re.MULTILINE)[1],16)+11
    log=run(base+['-e','-gBAD_EXPECTATION=true','-gBAD_ADDRESS='+str(address),'tb_hd6303_apps','-r','tb_hd6303_apps'],OUT/'HDTEST-fault-rtl.log')
    assert 'FAIL HDTEST CASE $0001' in log and 'PASS actual VHDL executable' in log
    print('PASS actual CMD tests on native reference/RTL, classic guards and injected failures')


if __name__=='__main__':main()
