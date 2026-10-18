"""Run music, shared IRQ dispatch and foreground refill on production HD6303."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from unias import assemble

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--unias', required=True)
p.add_argument('--nvc', default='nvc')
p.add_argument('--cases', nargs='+', default=['SIX.YM', 'DENSE.PSG', 'LH5BIG.YM'])
p.add_argument('--models', nargs='+', default=['601', '601a'])
p.add_argument('--speeds', nargs='+', type=int, default=[0, 1, 2, 3])
a = p.parse_args()
out = ROOT / 'build/audio'
cases = json.loads((out / 'cases.json').read_text())
command = [a.nvc, '-H', '128m', '--std=2008', '--work=work:build/audio-irq', '--ieee-warnings=off']
subprocess.run([*command, '-a', 'rtl/cpu6800.vhd', 'tests/tb_audio_irq.vhd'], cwd=ROOT, check=True)
for model in a.models:
    for name in a.cases:
        case = cases[name]
        env = dict(os.environ, AUDIO_SNAPSHOT=str(out / 'irq-snapshot.bin'))
        subprocess.run([str(out / 'test_audio_app'), str(out / 'sd-test.img'), model, name.lower(),
                        str(out / case['oracle']), str(case['rate']), str(case['factor']), '0', '0', '-',
                        str(out / (name + '.raw'))], cwd=ROOT, env=env, check=True)
        data = (out / 'irq-snapshot.bin').read_bytes()
        irq, refill, transfer, sent, underruns, rate = [int.from_bytes(data[i:i+2], 'big') for i in range(0, 12, 2)]
        period = int.from_bytes(data[12:16], 'big')
        stack = int.from_bytes(data[16:18], 'big')
        ram = bytearray(data[20:65556])
        native_irq = int.from_bytes(ram[0xfff8:0xfffa], 'big')
        pal_handler = int.from_bytes(ram[0xee0a:0xee0c], 'big')
        source = f'''    org $0200
    sei
    lds #${stack:04x}
    ldaa #12
    staa $e6f1
    ldaa #7
    staa $e6f0
    ldaa #5
    staa $e690
    cli
idle
    jsr ${refill:04x}
    bra idle
    end
'''
        (out / 'IRQ.ASM').write_text(source)
        code = assemble(a.unias, out, 'IRQ.ASM', 'IRQ.BIN')
        ram[0x200:0x200+len(code)] = code
        # This CPU bench replaces the foreground with a refill loop, so it
        # has no UniDOS task context for INT06's scheduler to switch into.
        # Keep the native PAL clock routine and nested SWI dispatch; full
        # native application tests retain the original scheduler callback.
        ram[0xee0c:0xee0e] = bytes(2)
        ram[0xfffe:] = bytes.fromhex('0200')
        (out / 'irq-ram.mem').write_text(''.join(f'{b:02x}\n' for b in ram))
        (out / 'irq-rom.mem').write_text(''.join(f'{b:02x}\n' for b in data[65556:131092]))
        (out / 'irq-banks.mem').write_text(''.join(f'{b:02x}\n' for b in data[131092:]))
        frames = (out / case['oracle']).read_bytes()[:100*14]
        (out / 'irq-frames.mem').write_text(''.join(f'{b:02x}\n' for b in frames))
        for speed in a.speeds:
            log = out / f'irq-{model}-{name}-{speed}.log'
            generics = dict(SPEED=speed, FRAMES=len(frames)//14, PERIOD=period, IRQ_ENTRY=native_irq,
                            TRANSFER=transfer, SENT=sent,
                            PAL_HANDLER=pal_handler, UNDERRUNS=underruns)
            with log.open('w') as output:
                subprocess.run([*command, '-e', *(f'-g{k}={v}' for k,v in generics.items()),
                                'tb_audio_irq', '-r', 'tb_audio_irq'], cwd=ROOT,
                               stdout=output, stderr=subprocess.STDOUT, check=True)
            passes = [line for line in log.read_text().splitlines() if 'PASS HD6303 music IRQ' in line]
            assert len(passes) == 1, log
            print(model, name, passes[0], flush=True)
