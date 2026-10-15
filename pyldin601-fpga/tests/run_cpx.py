"""Check CPX against the two manufacturers' rules, independently of the C core.

M6800 M68PRM(D), CPX: compare the two bytes separately; N/V come from
the high-byte subtraction, Z tests both bytes, C/H/I are unchanged.
HD6303R data sheet, table 9: full-word X - operand, updating N/Z/V/C.
Both the actual VHDL CPU and the software emulator run the same probes.
"""
import argparse
import json
import random
import subprocess
from pathlib import Path

import unias_fixture as asm


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
RESULT = 0xa000
STRIDE = 9  # CCR, A, B, X, SP+1 (TSX), operand in memory


def flags_for(x, operand, flags, hd):
    """Specification oracle: do not call or import either CPU implementation."""
    if hd:
        result = (x - operand) & 0xffff
        negative = bool(result & 0x8000)
        overflow = bool((x ^ operand) & (x ^ result) & 0x8000)
        carry = x < operand
    else:
        high = ((x >> 8) - (operand >> 8)) & 255
        negative = bool(high & 0x80)
        overflow = bool(((x >> 8) ^ (operand >> 8)) &
                        ((x >> 8) ^ high) & 0x80)
        carry = bool(flags & 1)
    return (0xc0 | (flags & 0x30) | (8 if negative else 0) |
            (4 if x == operand else 0) | (2 if overflow else 0) | carry)


def prepare(mode, pairs):
    source = ['    org 0', '    ds $1000-*,$ff', '    lds #$9000']
    cases = []
    # Sweep every preserved H/I/C combination with incoming N/Z/V all clear
    # and all set. CPX must overwrite N/Z/V independently of their old values.
    seeds = [h | i | c | nzv for h in (0, 0x20) for i in (0, 0x10)
             for c in (0, 1) for nzv in (0, 0x0e)]
    for x, operand in pairs:
        for flags in seeds:
            pointer = {'direct80': 0x80, 'directff': 0xff,
                       'extended': 0x80ff, 'extwrap': 0xffff}.get(mode)
            if mode.startswith('indexed'):
                pointer = (x + (255 if mode == 'indexed255' else 0)) & 65535
            if pointer is not None:
                assert pointer < 0x1000 or 0x7fff <= pointer < 0x9000 or pointer >= 0xff00
                source += [f'    ldx #${operand:04x}', f'    stx ${pointer:04x}']
            source += ['    ldaa #$5a', '    ldab #$a5', f'    ldx #${x:04x}',
                       '    psha', f'    ldaa #${flags:02x}', '    tap', '    pula']
            argument = (f'#${operand:04x}' if mode == 'immediate' else
                        '255,x' if mode == 'indexed255' else
                        '0,x' if mode == 'indexed0' else f'${pointer:04x}')
            address = RESULT + len(cases) * STRIDE
            source += [f'    cpx {argument}', '    psha', '    tpa',
                       f'    staa ${address:04x}', '    pula',
                       f'    staa ${address+1:04x}', f'    stab ${address+2:04x}',
                       f'    stx ${address+3:04x}', '    tsx',
                       f'    stx ${address+5:04x}']
            if pointer is not None:
                source += [f'    ldx ${pointer:04x}', f'    stx ${address+7:04x}']
            cases.append({'x': x, 'operand': operand, 'flags': flags,
                          'memory': pointer is not None, 'address': address})
    source += ['    ldaa #$aa', '    staa $efff', 'done', '    bra done',
               '    ds $fffe-*,$ff', '    dw $1000']
    binary, labels = asm.assemble('\n'.join(source), 0, 65536)
    assert labels['done'] < 0x7fff, 'CPX probe code overlaps operand memory'
    prefix = 'cpx-' + mode
    (BUILD / (prefix+'.asm')).write_text('\n'.join(source)+'\n')
    (BUILD / (prefix+'.bin')).write_bytes(binary)
    memory = ''.join(f'{v:02x}\n' for v in binary)
    for cpu in ('mc6800', 'hd6303'):
        name = prefix+'-'+cpu
        expected = bytearray(binary)
        for case in cases:
            a = case['address']
            expected[a:a+7] = bytes([flags_for(case['x'], case['operand'],
                                             case['flags'], cpu == 'hd6303'),
                                     0x5a, 0xa5, case['x'] >> 8,
                                     case['x'] & 255, 0x90, 0x01])
            if case['memory']:
                expected[a+7:a+9] = case['operand'].to_bytes(2, 'big')
        (BUILD / (name+'.mem')).write_text(memory)
        (BUILD / (name+'.expected.mem')).write_text(''.join(f'{v:02x}\n' for v in expected))
    return prefix, cases


def run(command):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    log = result.stdout + result.stderr
    if result.returncode:
        raise RuntimeError(log or repr(command))
    return log


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--nvc', default='nvc')
    parser.add_argument('--reference', default='build/cpu_reference')
    args = parser.parse_args()
    BUILD.mkdir(exist_ok=True)
    pairs = [(0, 0), (0, 1), (1, 0), (0xff, 0x100), (0x100, 0xff),
             (0xffff, 0), (0, 0xffff), (0xffff, 1), (0x8000, 1),
             (0x7fff, 0xffff), (0x8000, 0x7fff), (0x8000, 0x8001),
             (0x7fff, 0x8000), (0xff00, 0xff01), (0xff01, 0xff00),
             (0x7fff, 0x7f00), (0x8000, 0x80ff), (0x123, 0x123)]
    rng = random.Random(68006303)
    pairs += [(rng.randrange(0x8000, 0x8f00), rng.randrange(65536))
              for _ in range(6)]
    modes = ('immediate', 'direct80', 'directff', 'extended', 'extwrap',
             'indexed0', 'indexed255')
    work = '--work=work:build/cpx-test'
    common = [args.nvc, '--std=2008', work, '--ieee-warnings=off']
    run(common + ['-a', 'rtl/cpu6800.vhd', 'tests/tb_cpu.vhd'])
    reports = []
    logs = []
    for mode in modes:
        prefix, cases = prepare(mode, pairs)
        last = RESULT + len(cases)*STRIDE - 1
        for cpu in ('mc6800', 'hd6303'):
            name = prefix+'-'+cpu
            ref = BUILD / (name+'.reference.mem')
            run([args.reference, str(BUILD/(prefix+'.bin')), str(ref)] +
                (['hd6303'] if cpu == 'hd6303' else []))
            actual = bytes(int(v, 16) for v in ref.read_text().splitlines())
            expected = bytes(int(v, 16) for v in
                             (BUILD/(name+'.expected.mem')).read_text().splitlines())
            for case in cases:
                a = case['address']
                assert actual[a:a+STRIDE] == expected[a:a+STRIDE], (
                    f'C emulator {name}: {case}, actual={actual[a:a+STRIDE].hex()} '
                    f'expected={expected[a:a+STRIDE].hex()}')
            log = run(common + ['-e', f'-gPREFIX={name}',
                                '-gHD='+str(cpu == 'hd6303').lower(),
                                f'-gLAST_RESULT={last}', 'tb_cpu', '-r', 'tb_cpu'])
            logs.append(log)
            assert 'PASS actual VHDL CPU' in log, log
            reports.append({'cpu': cpu, 'mode': mode, 'cases': len(cases),
                            'rtl': 'pass', 'emulator': 'pass'})
            print(f'PASS CPX {cpu} {mode}: {len(cases)} cases, RTL and C emulator',
                  flush=True)
    (BUILD/'cpx.log').write_text(''.join(logs))
    (BUILD/'cpx-report.json').write_text(json.dumps(reports, indent=2)+'\n')
    print(f'PASS {sum(r["cases"] for r in reports)} CPX cases per CPU implementation: '
          'NZVC, H/I preservation, A/B/X/SP, operand memory, byte boundaries and hold')


if __name__ == '__main__':
    main()
