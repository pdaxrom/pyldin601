"""Actual VHDL CPU, production graphics/AY/PAL/shared SRAM and real PS/2.

Start from a native UniDOS checkpoint after file decoding and graphics
preparation, before starting playback. UniAS builds an RTI trampoline that resumes the unchanged
PGM. No runtime RTL forces, replacement interrupts or generated opcodes.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from unias import assemble

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--unias', required=True)
p.add_argument('--nvc', default='nvc')
p.add_argument('--models', nargs='+', choices=['601', '601a'], default=['601', '601a'])
p.add_argument('--speeds', nargs='+', type=int, choices=range(4), default=[0, 1, 2, 3])
a = p.parse_args()
out = ROOT / 'build/gfxmusic'
labels = {k: int(v, 16) for k, v in re.findall(r'#define YP_(\w+) 0x([0-9A-F]+)', (ROOT / 'build/audio/gfxmusic_labels.h').read_text())}
command = [a.nvc, '-H', '512m', '--std=2008', '--work=work:build/gfxmusic-rtl', '--ieee-warnings=off']
sources = ['rtl/cpu6800.vhd', *map(str, sorted(Path('rtl').glob('*.v'))),
           'tests/fast_clock.v', 'tests/tb_gfxmusic_app.v', 'tests/tb_gfxmusic_app.vhd']
subprocess.run([*command, '-a', *sources], cwd=ROOT, check=True)
frames = (ROOT / 'build/audio/SIX.YM.frames').read_bytes()
(out / 'rtl-frames.mem').write_text(''.join(f'{b:02x}\n' for b in frames))
for model in a.models:
    env = dict(os.environ, GFXMUSIC_SNAPSHOT=str(out / 'rtl-snapshot.bin'))
    subprocess.run([str(out / 'test_gfxmusic'), str(out / 'sd-test.img'), model, 'six.ym',
                    str(ROOT / 'build/audio/SIX.YM.frames'), '100', '289', '0', '0', '-',
                    str(ROOT / 'build/audio/SIX.YM.raw')], cwd=ROOT, env=env, check=True)
    ctx = json.loads((out / 'rtl-snapshot.bin.json').read_text())
    for speed in a.speeds:
        physical = bytearray((out / 'rtl-snapshot.bin').read_bytes())
        config = bytearray(ctx['config']); config[20:24] = bytes(4)
        boot_lines = ['org $f000', 'sei', 'lds #$1fff', f'ldaa #{2+ctx["model_a"]+speed*4}',
                      'staa $e6a0', 'ldaa #$40', 'staa $e6a2', 'clr $e6aa',
                      'ldx #config', 'ldab #64', 'send', 'ldaa 0,x', 'staa $e6a3',
                      'inx', 'decb', 'bne send', 'jmp $e000', 'config']
        boot_lines += ['db '+','.join(f'${b:02x}' for b in config[i:i+16]) for i in range(0,len(config),16)]
        boot_lines += ['ds $fff8-*,0', 'dw $f000,$f000,$f000,$f000', 'end']
        (out / 'BOOT.ASM').write_text('\n'.join(line if line in ('send', 'config') else '    '+line for line in boot_lines)+'\n')
        boot = assemble(a.unias, out, 'BOOT.ASM', 'BOOT.BIN'); assert len(boot) == 4096
        (out / 'rtl-boot.mem').write_text(''.join(f'{b:02x}\n' for b in boot))
        # Native RTI pull order above the decremented SP: CC B A X PC.
        frame = bytes([ctx['cc'],ctx['b'],ctx['a'],ctx['x']>>8,ctx['x']&255,ctx['pc']>>8,ctx['pc']&255])
        physical[ctx['sp']-6:ctx['sp']+1] = frame
        restore = ['org $e000', 'ldaa #$a5', 'staa $e6a0', f'ldaa #{ctx["group"]}', 'staa $e6f1',
                   f'ldaa #{ctx["page"]}', 'staa $e6f0', f'ldaa #{ctx["mode"]}', 'staa $e629']
        for reg, value in enumerate(ctx['crtc']):
            restore += [f'ldaa #{reg}', 'staa $e600', f'ldaa #{value}', 'staa $e601']
        # The checkpoint is after configure_audio. Restore its peripheral
        # state through the production MMIO, as well as RAM/CPU registers.
        for base, value, commit in [(0xe692, ctx['period'], 0xe696), (0xe69b, ctx['divider'], 0xe69f)]:
            for index, byte in enumerate(value.to_bytes(4, 'big')):
                restore += [f'ldaa #{byte}', f'staa ${base+index:04x}']
            restore += ['ldaa #1', f'staa ${commit:04x}']
        restore += ['wait_clock', 'ldaa $e690', 'bita #$20', 'bne wait_clock']
        restore += [f'lds #${ctx["sp"]-7:04x}', f'jsr ${ctx["app"]+labels["LG_MAKE_COMPONENTS"]:04x}', 'rti', 'end']
        (out / 'RESTORE.ASM').write_text('\n'.join(line if line == 'wait_clock' else '    '+line for line in restore)+'\n')
        trampoline = assemble(a.unias, out, 'RESTORE.ASM', 'RESTORE.BIN'); assert len(trampoline) < 256
        physical[0xe000:0xe000+len(trampoline)] = trampoline
        (out / 'rtl-sram.mem').write_text(''.join(f'{physical[j+1]:02x}{physical[j]:02x}\n' for j in range(0,len(physical),2)))
        generics = dict(SPEED=speed, MODEL_A=ctx['model_a'], APP=ctx['app'],
                        RETURN_PC=ctx['app']+labels['RETURN_TO_DOS'], UNDERRUNS=labels['UNDERRUNS'],
                        SAVED_PAGE=ctx['saved_page'], SAVED_GROUP=ctx['saved_group'], ORIGINAL_IRQ=ctx['original_irq'])
        log = out / f'rtl-{model}-{speed}.log'
        with log.open('w') as output:
            subprocess.run([*command, '-e', '-j', *(f'-g{k}={v}' for k,v in generics.items()),
                            'tb_gfxmusic_app', '-r', 'tb_gfxmusic_app'], cwd=ROOT, stdout=output,
                           stderr=subprocess.STDOUT, check=True)
        passes = [line for line in log.read_text().splitlines() if line.startswith('PASS actual HD6303 GFXMUSIC.PGM')]
        assert len(passes) == 1, log
        print(passes[0], flush=True)
