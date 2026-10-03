"""Spec-based ISA switch, undefined opcode TRAP and SLP/interrupt fixtures."""
from pathlib import Path
import importlib.util
root=Path(__file__).resolve().parents[1]
sp=importlib.util.spec_from_file_location('asm',root/'tools/asm6800.py');asm=importlib.util.module_from_spec(sp);sp.loader.exec_module(asm)
# Hitachi HD6303R tables 8-11 (printed pages 65-68), independent opcode list.
valid={1,4,5,6,7,8,9,10,11,12,13,14,15,16,17,22,23,24,25,26,27}
valid.update(range(0x20,0x40)) # All branches and 30..3F are defined in HD6303.
for high in (4,5,6,7):
 valid.update(high*16+n for n in (0,3,4,6,7,8,9,10,12,13,15))
 if high>=6:valid.update(high*16+n for n in (1,2,5,11,14))
for high in range(8,16):
 valid.update(high*16+n for n in (0,1,2,3,4,5,6,8,9,10,11,12,14))
 if high not in (8,12):valid.update((high*16+7,high*16+13,high*16+15))
valid.add(0x8d)
# CD immediate STD has no defined destination.
illegal=sorted(set(range(256))-valid)
header=['org $1000','clr $effc','lds #$9000','ldx #$5678','ldab #$34','ldaa #$21','tap']
source=header.copy()
for op in illegal:source.extend([f'bad_{op:02x}:',f'db ${op:02x}'])
source+=['ldaa #$aa','staa $efff','done:','bra done',
 'org $2000','trap_handler:','tsx','inc 6,x','bne no_carry','inc 5,x','no_carry:','inc $effc','rti',
 'org $2100','external_handler:','inc $effb','rti',
 'org $ffee','dw trap_handler','org $fff8','dw external_handler','org $fffc','dw external_handler','org $fffe','dw $1000']
def save(name,source):
 binary,labels=asm.assemble('\n'.join(source),0,65536)
 (root/f'build/{name}.mem').write_text(''.join(f'{v:02x}\n' for v in binary))
 return labels
labels=save('hd-trap',source)
(root/'build/hd-trap-addresses.mem').write_text(''.join(f'{labels[f"bad_{op:02x}"]:04x}\n' for op in illegal))
for case in range(3):
 # masked IRQ, unmasked IRQ, NMI (I set).
 flags=0x31 if case!=1 else 0x21
 src=['org $1000','clr $effc','lds #$9000','ldx #$5678','ldab #$34',f'ldaa #${flags:02x}','tap','sleep:','db $1a','after_sleep:',
 'staa $e030','stab $e031','stx $e032','sts $e034','ldaa #$aa','staa $efff','done:','bra done',
 'org $2100','handler:','inc $effc','rti','org $fff8','dw handler','org $fffc','dw handler','org $fffe','dw $1000']
 sl=save(f'hd-sleep-{case}',src)
# Exercise every extended opcode while disabled as a one-byte NOP. Padding
# bytes are NOPs too, making accidental operand fetch visible in PC/registers.
# Explicit documented additions rather than attempting to infer classic list.
extended=[4,5,0x18,0x1a,0x21,0x38,0x3a,0x3c,0x3d,0x61,0x62,0x65,0x6b,0x71,0x72,0x75,0x7b,0x83,0x93,0xa3,0xb3,0x9d,0xc3,0xd3,0xe3,0xf3,0xcc,0xdc,0xec,0xfc,0xdd,0xed,0xfd]
source=header.copy()
for op in extended:source+=['db '+','.join(f'${n:02x}' for n in (op,1,1))]
source+=['check_disabled:','nop',
 'ldaa #1','staa $effd','ldaa #$12','ldab #$34','ldx #$5678','switch_swap:','db $18',
 'check_enabled:','nop','ldaa #$5a','staa $80','latch_mask:','db $71,$f0,$80','check_latched:','nop','ldaa #0','staa $effd','ldaa #$12','ldab #$34','disabled_swap:','db $18',
 'check_back:','nop','ldaa #$aa','staa $efff','done:','bra done','org $fffe','dw $1000']
sw=save('hd-switch',source)
(root/'build/hd-edge-labels.vhd').write_text('''library ieee;use ieee.std_logic_1164.all;
package hd_edge_labels is
'''+''.join(f'constant {key}:std_logic_vector(15 downto 0):=x"{value:04x}";\n' for key,value in sw.items() if key.startswith(('check_','switch_','disabled_','latch_')))+
 f'constant sleep_pc:std_logic_vector(15 downto 0):=x"{sl["sleep"]:04x}";\nconstant sleep_next:std_logic_vector(15 downto 0):=x"{sl["after_sleep"]:04x}";\nconstant trap_count:natural:={len(illegal)};\nend package;\n')
print(f'Prepared {len(illegal)} undefined HD6303 opcodes, {len(extended)} disabled opcodes, 3 SLP wake paths and live ISA switches')
