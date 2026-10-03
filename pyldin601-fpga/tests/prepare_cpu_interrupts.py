"""Exercise interrupt entry around a BIOS-style SWI with an inline service byte."""
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('asm', root / 'tools/asm6800.py')
asm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(asm)
source = '''org $1000
sei
lds #$9000
ldab #$34
ldx #$5678
ldaa #$21
tap
service:
swi
db $22
after_service:
staa $e030
stab $e031
stx $e032
sts $e034
ldaa #$aa
staa $e0ff
done:
bra done
org $2000
swi_handler:
tpa
staa $e010
tsx
ldaa 0,x
staa $e011
ldaa 5,x
staa $e012
ldaa 6,x
staa $e013
inc 6,x
ldaa #$53
staa $e000
rti
org $2100
irq_handler:
tpa
staa $e020
tsx
ldaa 0,x
staa $e021
ldaa 5,x
staa $e022
ldaa 6,x
staa $e023
ldaa #$49
staa $e001
rti
org $fff8
dw irq_handler,swi_handler,irq_handler,$1000
'''
binary, labels = asm.assemble(source, 0, 65536)
(root / 'build/cpu-interrupts.mem').write_text(''.join(f'{b:02x}\n' for b in binary))
(root / 'build/cpu-interrupts-labels.vhd').write_text(f'''library ieee;
use ieee.std_logic_1164.all;
package cpu_interrupt_labels is
 constant service_pc:std_logic_vector(15 downto 0):=x"{labels['service']:04x}";
 constant return_pc:std_logic_vector(15 downto 0):=x"{labels['after_service']:04x}";
end package;
''')
