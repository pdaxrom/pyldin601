"""Sweep IRQ arrival across SWI stacking/vector entry and fetched opcodes."""
import argparse
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--nvc', default='nvc')
parser.add_argument('--work', default='build/cpu-interrupts')
parser.add_argument('--hd', action='store_true', help='Run the same interrupt entry suite with HD6303 enabled')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
cases = [(0, delay, None) for delay in range(18)] + [(s, 0, None) for s in range(1, 7)]
# Operands are never executed: an IRQ/NMI accepts the opcode fetch itself.
# Cover every fetch-state ALU/register writeback family, including LDS/LDX.
prefetch = [0x01, 0x3e, 0x3f] + list(range(0x80, 0x100))
if args.hd:
    # Undefined HD6303 opcodes intentionally take TRAP before IRQ/NMI.
    prefetch = [op for op in prefetch if op not in
                (0x87, 0x8f, 0xc7, 0xcd, 0xcf)]
for scenario in (7, 8):
    cases.extend((scenario, 0, op) for op in prefetch)
logs = []
for scenario, delay, opcode in cases:
    extra = [] if opcode is None else [f'-gFETCH_OPCODE={opcode}']
    result = subprocess.run([args.nvc, '--std=2008', f'--work=work:{args.work}', '--ieee-warnings=off',
                             '-e', f'-gHD={str(args.hd).lower()}', f'-gSCENARIO={scenario}', f'-gIRQ_DELAY={delay}',
                             *extra,
                             'tb_cpu_interrupts', '-r', 'tb_cpu_interrupts'],
                            cwd=root, capture_output=True, text=True)
    log = result.stdout + result.stderr
    logs.append(log)
    if result.returncode or 'PASS interrupt boundary' not in log:
        (root / ('build/cpu-interrupts-hd.log' if args.hd else 'build/cpu-interrupts.log')).write_text(''.join(logs))
        raise SystemExit(log)
(root / ('build/cpu-interrupts-hd.log' if args.hd else 'build/cpu-interrupts.log')).write_text(''.join(logs))
print(f'PASS {len(cases)} actual VHDL interrupt entry cases: SWI masks IRQ, saves CCR/PC, '
      'pending IRQ follows RTI, accepted IRQ survives pin removal and fetched SWI/WAI; '
      'prefetched ALU/load opcodes preserve entry registers/frame; '
      'reset masks IRQ and WAI respects I with IRQ/NMI wakeup')
