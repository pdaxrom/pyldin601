"""Measure the real Arkanoid PGM on production HDL, including PAL/SRAM/AY.

Results are simulated 24-MHz clock counts, not a claim of physical-board
measurement. Native execution only prepares the same loaded game state.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from unias import assemble, bios_symbols, data_source
from add_disk_files import install


def restore(model, scenario, speed, music, unias, out):
    base = out / (model + '-' + scenario)
    ctx = json.loads(base.with_name(base.name + '-context.json').read_text())
    config = bytearray(base.with_name(base.name + '-config.bin').read_bytes())
    config[20:24] = bytes(4)
    setting = (model == '601a') | 2 | (speed << 2)
    boot = f'''    org $f000
    sei
    lds #$1fff
    ldaa #{setting}
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
''' + data_source(config) + '    ds $fff8-*,0\n    dw $f000,$f000,$f000,$f000\n    end\n'
    (out / 'BOOT.ASM').write_text(boot)
    boot_bytes = assemble(unias, out, 'BOOT.ASM', 'BOOT.BIN')
    assert len(boot_bytes) == 4096
    (out / 'boot.mem').write_text(''.join(f'{b:02x}\n' for b in boot_bytes))
    ram = bytearray(base.with_name(base.name + '-ram.bin').read_bytes())
    frame = bytes((ctx['cc'], ctx['b'], ctx['a'], ctx['x'] >> 8, ctx['x'] & 255,
                   ctx['pc'] >> 8, ctx['pc'] & 255))
    ram[ctx['sp']-6:ctx['sp']+1] = frame
    source = ['org $e000', 'ldaa #$a5', 'staa $e6a0',
              f"ldaa #{ctx['page']}", 'staa $e6f0',
              f"ldaa #{ctx['mode']}", 'staa $e629']
    for reg, value in enumerate(ctx['crtc']):
        source += [f'ldaa #{reg}', 'staa $e600', f'ldaa #{value}', 'staa $e601']
    source += [f"ldaa #{ctx['front']}", 'staa $e655', 'ldaa #3', 'staa $e651',
               'ldaa $e650', 'bmi *-3', 'ldaa #1', 'staa $e650',
               f"ldd #${ctx['divider'] >> 16:04x}", 'std $e69b',
               f"ldd #${ctx['divider'] & 65535:04x}", 'std $e69d',
               'ldaa #1', 'staa $e69f',
               f"ldd #${ctx['period'] >> 16:04x}", 'std $e692',
               f"ldd #${ctx['period'] & 65535:04x}", 'std $e694',
               'ldaa #1', 'staa $e696', 'ldaa #7', 'staa $e6b3']
    if music:
        source += ['staa $e690']
    else:
        state = ram[0xefcc] * 256 + ram[0xefcd]
        ram[state+19] = 0
    source += [f"lds #${ctx['sp']-7:04x}", 'rti', 'end']
    (out / 'RESTORE.ASM').write_text(''.join('    ' + line + '\n' for line in source))
    trampoline = assemble(unias, out, 'RESTORE.ASM', 'RESTORE.BIN')
    assert len(trampoline) < 512
    ram[0xe000:0xe000+len(trampoline)] = trampoline
    rom = (ROOT / ('build/rom-a.reference' if model == '601a' else 'build/rom.reference')).read_bytes()[512:]
    physical = bytearray(2*1024*1024)
    physical[:65536] = ram
    physical[0x10000:0x10000+len(rom)] = rom
    physical[0x22000:0x100000] = base.with_name(base.name + '-pages.bin').read_bytes()
    physical[0x100000:0x140000] = base.with_name(base.name + '-fb.bin').read_bytes()
    (out / 'sram.mem').write_text(''.join(f'{physical[k+1]:02x}{physical[k]:02x}\n' for k in range(0, len(physical), 2)))
    game = bios_symbols((ROOT / 'build/game/ARKANOID.PGM.LST').read_text())
    rom_labels = bios_symbols((ROOT / 'build/partitions/RAMMAN.ROM.LST').read_text())
    labels = {name: ctx['app'] + game[key] for name, key in {
        'LOOP': 'FRAME_LOOP', 'APP_END': 'BSS_START',
        'INPUT': 'SDK_INPUT', 'INPUT_END': 'SDK_TILE',
        'REFILL': 'FILL_MUSIC', 'REFILL_END': 'API',
        'FAILED': 'FAILED', 'OP': 'LAST_OPERATION'}.items()}
    labels['GAME_IRQ'] = rom_labels['GAME_IRQ']
    labels['APP'] = ctx['app']
    (out / 'labels.vh').write_text(''.join(f"`define PERF_{name} 16'h{value:04x}\n" for name, value in labels.items()))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--unias', required=True)
    p.add_argument('--nvc', default='nvc')
    p.add_argument('--cc', default='cc')
    p.add_argument('--models', nargs='+', choices=('601', '601a'), default=['601', '601a'])
    p.add_argument('--speeds', nargs='+', type=int, choices=range(4), default=list(range(4)))
    p.add_argument('--scenarios', nargs='+', choices=('steady', 'brick', 'miss'), default=['steady', 'brick'])
    p.add_argument('--stress-input', action='store_true', help='send physical PS/2 held/repeated keys throughout the run')
    p.add_argument('--music', nargs='+', type=int, choices=(0, 1), default=[1])
    p.add_argument('--frames', type=int, default=12)
    p.add_argument('--report', type=Path, default=ROOT / 'build/game-perf/results.json')
    a = p.parse_args()
    if a.frames < 3:
        p.error('at least three frames required to exercise music IRQ')
    out = ROOT / 'build/game-perf'
    out.mkdir(parents=True, exist_ok=True)
    subprocess.run([a.cc, '-O2', '-I../pyldin601/src', 'tests/prepare_game_perf.c', '-o', str(out/'prepare')], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'tests/prepare_boot_lockstep.py'], cwd=ROOT, check=True)
    image, _ = install((ROOT/'images/sd.img').read_bytes(),
                       {n: (ROOT/'build/game'/n).read_bytes() for n in ('ARKANOID.PGM','WARHAWK.YM')}, replace=True)
    (out/'sd-test.img').write_bytes(image)
    results = []
    for model in a.models:
        for scenario in a.scenarios:
            subprocess.run([str(out/'prepare'), str(out/'sd-test.img'), model, scenario], cwd=ROOT, check=True)
            restore(model, scenario, a.speeds[0], a.music[0], a.unias, out)
            work = 'work:' + str(out / 'rtl')
            sources = ['build/cpu6800_lockstep.vhd', *map(str, sorted(Path('rtl').glob('*.v'))),
                       'tests/fast_clock.v', 'tests/tb_game_perf.v', 'tests/tb_game_perf.vhd']
            subprocess.run([a.nvc, '--std=2008', '--work='+work, '--ieee-warnings=off', '-a', *sources], cwd=ROOT, check=True)
            for speed in a.speeds:
                for music in a.music:
                    restore(model, scenario, speed, music, a.unias, out)
                    name = f'{model}-{scenario}-{1<<speed}MHz-music{music}'
                    with (out / (name+'.log')).open('w') as stream:
                        result = subprocess.run([a.nvc, '--std=2008', '--work='+work, '--ieee-warnings=off', '-e', '-j',
                            f'-gSPEED={speed}', f'-gFRAMES={a.frames}', f'-gMUSIC={music}', f'-gSTRESS={int(a.stress_input)}', 'tb_game_perf', '-r', 'tb_game_perf'], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
                    log = (out / (name+'.log')).read_text()
                    rows = [dict((k, int(v)) for k, v in re.findall(r'(\w+)=(\d+)', line))
                            for line in log.splitlines() if line.startswith('PERF frame=')]
                    if result.returncode or 'PASS production ARKANOID performance' not in log or len(rows) != a.frames:
                        print(log)
                        raise RuntimeError('performance run failed: ' + name)
                    for row in rows:
                        assert row['requests'] == 1
                        assert sum(row[k] for k in ('app','bios','input','refill','blit_wait','flip_wait','irq','other')) == row['ticks']
                    frames = [row['ticks']/24000 for row in rows]
                    item = dict(model=model, scenario=scenario, cpu_mhz=1<<speed, music=bool(music), stress_input=a.stress_input,
                                mean_frame_ms=sum(frames)/len(frames), max_frame_ms=max(frames), rows=rows)
                    results.append(item)
                    print(f"{name}: mean {item['mean_frame_ms']:.3f} ms, worst {item['max_frame_ms']:.3f} ms", flush=True)
                    a.report.parent.mkdir(parents=True, exist_ok=True)
                    a.report.write_text(json.dumps(dict(measurement='production HDL; counts normalized to 24 MHz',
                        pgm_sha256=hashlib.sha256((ROOT/'build/game/ARKANOID.PGM').read_bytes()).hexdigest(), results=results), indent=2)+'\n')


if __name__ == '__main__':
    main()
