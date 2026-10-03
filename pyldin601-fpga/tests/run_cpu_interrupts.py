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
cases = [(0, delay) for delay in range(18)] + [(s, 0) for s in range(1, 7)]
logs = []
for scenario, delay in cases:
    result = subprocess.run([args.nvc, '--std=2008', f'--work=work:{args.work}', '--ieee-warnings=off',
                             '-e', f'-gHD={str(args.hd).lower()}', f'-gSCENARIO={scenario}', f'-gIRQ_DELAY={delay}',
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
      'reset masks IRQ and WAI respects I with IRQ/NMI wakeup')
