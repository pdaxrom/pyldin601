"""Run paired native BIOS repeat tests with the real CPU and PS/2 RTL.

The core fixture models PAL/audio MMIO; tb_keyboard_bios.v separately
checks the complete production system and physical SRAM/clock timing.
Each case has private readmemh inputs and an NVC library.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--unias', required=True)
p.add_argument('--nvc', default='nvc')
p.add_argument('--cc', default='cc')
p.add_argument('--jobs', type=int, default=2)
p.add_argument('--output', default='build/keyboard-repeat-suite')
a = p.parse_args()
out = ROOT / a.output
out.mkdir(parents=True, exist_ok=True)
subprocess.run([a.cc, '-O2', '-I../pyldin601/src', 'tests/prepare_keyboard_bios.c',
                '-o', 'build/prepare_keyboard_bios'], cwd=ROOT, check=True)
cases = []
for model in ('601', '601a'):
    subprocess.run(['build/prepare_keyboard_bios', 'images/sd.img', model], cwd=ROOT, check=True)
    for speed in range(4):
        subprocess.run(['python3', 'tests/prepare_runtime.py', '--prefix', 'keyboard',
                        '--speed', str(speed), '--music-irq', '--unias', a.unias], cwd=ROOT, check=True)
        case = out / f'{model}-{speed}'
        (case / 'build').mkdir(parents=True, exist_ok=True)
        if not (case / 'rtl').exists():
            (case / 'rtl').symlink_to(ROOT / 'rtl', target_is_directory=True)
        shutil.copyfile(ROOT / 'build/keyboard-sram.mem', case / 'build/keyboard-sram.mem')
        cases.append((model, speed, case))

def run(item):
    model, speed, case = item
    command = [a.nvc, '--std=2008', '--work=work:' + str(case / 'work'), '--ieee-warnings=off']
    log = case / 'result.log'
    with log.open('w') as output:
        subprocess.run([*command, '-a', str(ROOT / 'rtl/cpu6800.vhd'),
                        str(ROOT / 'rtl/classic_keyboard.v'), str(ROOT / 'rtl/classic_memory_map.v'),
                        str(ROOT / 'tests/tb_keyboard_bios_core.v'), str(ROOT / 'tests/tb_keyboard_bios.vhd'),
                        '-e', '-j', f'-gSPEED={speed}', 'tb_keyboard_bios', '-r', 'tb_keyboard_bios'],
                       cwd=case, stdout=output, stderr=subprocess.STDOUT, check=True)
    passed = [line for line in log.read_text().splitlines() if 'PASS actual HDL CPU/native BIOS' in line]
    assert len(passed) == 1, log
    print(model, passed[0], flush=True)
    return dict(model=model, cpu_mhz=1 << speed, passed=True, log=str(log.relative_to(ROOT)))

with ThreadPoolExecutor(max_workers=a.jobs) as pool:
    results = list(pool.map(run, cases))
(out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
print('PASS eight BIOS/CPU-speed cases: fast taps, held repeat, pause delay, break, shared audio IRQ', flush=True)
