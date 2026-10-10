"""Generate simulation-only register taps and the existing native device model.

The production CPU is copied byte-for-byte apart from the entity name and
debug outputs; its state machine, ALU and bus logic are not patched.
"""
import argparse
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cpu-source', type=Path, default=root / 'rtl/cpu6800.vhd')
args = parser.parse_args()
cpu = args.cpu_source.read_text()
cpu = cpu.replace('entity cpu6800 is', 'entity cpu6800_lockstep is').replace(
    'architecture CPU_ARCH of cpu6800 is', 'architecture CPU_ARCH of cpu6800_lockstep is')
cpu = cpu.replace('test_cc:  out std_logic_vector(7 downto 0)',
    'debug_state: out std_logic_vector(71 downto 0);\n'
    '      debug_opcode: out std_logic_vector(7 downto 0);\n'
    '      debug_decode: out std_logic;\n'
    '      test_cc:  out std_logic_vector(7 downto 0)')
needle = 'begin\n\n----------------------------------'
assert needle in cpu
cpu = cpu.replace(needle, 'begin\n'
    "debug_decode <= '1' when state=decode_state else '0';\n"
    'debug_opcode <= op_code;\n'
    'debug_state <= (pc-1) & sp & xreg & acca & accb & cc;\n\n'
    '----------------------------------', 1)
(root / 'build/cpu6800_lockstep.vhd').write_text(cpu)
model = (root / 'tests/test_firmware.c').read_text()
model = model.replace('int SuperIoReadByte(word a,byte*out){', 'int raw_device_read(word a,byte*out){')
needle = '#include "core/mc6800.c"'
assert needle in model
model = model.replace(needle, '''static FILE *io_trace;
int SuperIoReadByte(word a,byte*out){
 int result=raw_device_read(a,out);
 if(io_trace&&a>=0xe600&&a<=0xe6ff)
  fprintf(io_trace,"%04x%02x\\n",a,result?*out:MC6800GetCpuRam()[a]);
 return result;
}
''' + needle)
(root / 'build/lockstep-devices.inc').write_text(model)
payload = (root / 'build/rom.reference').read_bytes()[512:]
assert len(payload) == 0x11800
(root / 'build/rom.reference.mem').write_text(''.join(f'{v:02x}\n' for v in payload))
