#!/usr/bin/env python3
"""Build self-checking UniDOS CMD tests using the external UniAS assembler."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tests/hd6303'


def nz(value, width):
    return (8 if value & (1 << (width - 1)) else 0) | (4 if value == 0 else 0)


def arithmetic(left, right, flags, subtract=False):
    result = (left - right if subtract else left + right) & 0xffff
    overflow = ((left ^ right) & (left ^ result) if subtract else
                ~(left ^ right) & (left ^ result)) & 0x8000
    carry = left < right if subtract else left + right > 0xffff
    return result, (flags & 0x30) | nz(result, 16) | (2 if overflow else 0) | int(carry)


def make_cases():
    cases = []
    def add(name, instructions, a=0x12, b=0x34, x=0x5678, flags=0x31,
            memory=0xa55a, expected_d=None, expected_x=None, expected_flags=None,
            expected_memory=None, pointer='scratch', stack=False):
        cases.append(dict(name=name, instructions=instructions, a=a, b=b, x=x,
            flags=flags | 0xd0, memory=memory,
            expected_d=(a << 8 | b) if expected_d is None else expected_d,
            expected_x=x if expected_x is None else expected_x,
            expected_flags=(flags if expected_flags is None else expected_flags) | 0xc0,
            expected_memory=memory if expected_memory is None else expected_memory,
            pointer=pointer, stack=stack))
    flags_list = (0x10, 0x1f, 0x30, 0x3f)
    words = (0, 1, 0x7fff, 0x8000, 0x8001, 0xffff)
    for op in ('lsrd', 'asld'):
        for value in words:
            for flags in flags_list:
                if op == 'lsrd':
                    result, carry = value >> 1, value & 1
                    overflow = carry
                else:
                    result, carry = value << 1 & 0xffff, value >> 15
                    overflow = (result >> 15) ^ carry
                f = flags & 0x30 | nz(result, 16) | overflow << 1 | carry
                add(op, [op], value >> 8, value & 255, flags=flags,
                    expected_d=result, expected_flags=f)
    for d, x in ((0, 0xffff), (0xffff, 0), (0x1234, 0xabcd), (0x8001, 0x7fff)):
        for flags in flags_list:
            add('xgdx', ['xgdx'], d >> 8, d & 255, x, flags,
                expected_d=x, expected_x=d)
    for x, b in ((0, 0), (0xffff, 1), (0xff80, 0xff), (0x1234, 0x80)):
        for flags in flags_list:
            add('abx', ['abx'], b=b, x=x, flags=flags, expected_x=(x + b) & 0xffff)
    for a, b in ((0, 0), (0, 255), (1, 127), (1, 128), (2, 128),
                 (15, 17), (16, 16), (127, 255), (128, 128), (255, 255)):
        for flags in flags_list:
            product = a * b
            add('mul', ['mul'], a, b, flags=flags, expected_d=product,
                expected_flags=(flags & 0x3e) | ((product >> 7) & 1))
    for op in ('aim', 'oim', 'eim', 'tim'):
        for address in ('direct', 'indexed0', 'indexed128', 'indexed255'):
            for value, mask in ((0, 0xff), (0xff, 0), (0x55, 0xaa),
                                (0x80, 0x80), (0xff, 0x7f), (0xf0, 0x0f)):
                for flags in (0x1f, 0x30):
                    offset = 0 if address in ('direct', 'indexed0') else int(address[7:])
                    pointer = '$80' if address == 'direct' else 'scratch'
                    x = 0x5678 if address == 'direct' else f'scratch-{offset}'
                    operand = '$80' if address == 'direct' else f'{offset},x'
                    result = value & mask if op in ('aim', 'tim') else value | mask if op == 'oim' else value ^ mask
                    f = flags & 0x31 | nz(result, 8)
                    add(f'{op}-{address}', [f'{op} #${mask:02x},{operand}'],
                        x=x, flags=flags, memory=value << 8 | 0x69,
                        expected_flags=f,
                        expected_memory=(value if op == 'tim' else result) << 8 | 0x69,
                        pointer=pointer)
    pairs = ((0, 0), (0, 1), (0xffff, 1), (0x7fff, 1),
             (0x8000, 1), (0x8000, 0xffff), (0x7fff, 0xffff), (0x55aa, 0xaa55))
    for op in ('addd', 'subd', 'ldd', 'std'):
        for mode in ('immediate', 'direct', 'indexed0', 'indexed255', 'extended'):
            if op == 'std' and mode == 'immediate':
                continue
            for left, right in pairs:
                for flags in (0x1f, 0x30):
                    offset = 255 if mode == 'indexed255' else 0
                    x = f'scratch-{offset}' if mode.startswith('indexed') else 0x5678
                    pointer = '$80' if mode == 'direct' else 'scratch'
                    operand = f'#${right:04x}' if mode == 'immediate' else '$80' if mode == 'direct' else f'{offset},x' if mode.startswith('indexed') else 'scratch'
                    result, f = arithmetic(left, right, flags, op == 'subd') if op in ('addd', 'subd') else (right if op == 'ldd' else left, flags & 0x31 | nz(right if op == 'ldd' else left, 16))
                    add(f'{op}-{mode}', [f'{op} {operand}'], left >> 8, left & 255,
                        x, flags, right, expected_d=left if op == 'std' else result,
                        expected_flags=f, expected_memory=result if op == 'std' else right,
                        pointer=pointer)
    for mode in ('immediate', 'direct', 'extended', 'indexed0', 'indexed255'):
        for left, right in pairs:
            for flags in (0x1f, 0x30):
                offset = 255 if mode == 'indexed255' else 0
                indexed = mode.startswith('indexed')
                x = f'scratch-{offset}' if indexed else left
                operand = f'#${right:04x}' if mode == 'immediate' else '$80' if mode == 'direct' else f'{offset},x' if indexed else 'scratch'
                # Resolve symbolic X after UniAS assigns the scratch address.
                add(f'cpx-{mode}', [f'cpx {operand}'], x=x, flags=flags,
                    memory=right, expected_flags=arithmetic(left, right, flags, True)[1],
                    pointer='$80' if mode == 'direct' else 'scratch')
                if indexed:
                    cases[-1]['cpx_symbolic'] = (offset, right, flags)
    for a in (0, 0x7f, 0x80, 0xff):
        for flags in flags_list:
            result = (a + 1) & 255
            add('jsr-direct', ['jsr $80'], a=a, flags=flags, memory=0x4c39,
                expected_d=result << 8 | 0x34,
                expected_flags=(flags & 0x31) | nz(result, 8) | (2 if a == 0x7f else 0),
                pointer='$80')
    for x in words:
        for flags in flags_list:
            add('pshx-pulx', ['pshx', 'psha', 'tpa', 'staa stack_cc', 'pula',
                'tsx', 'ldaa 0,x', 'staa stack_hi', 'ldaa 1,x', 'staa stack_lo',
                'ldx #0', 'pulx'], x=x, flags=flags, expected_d=(x & 255) << 8 | 0x34,
                expected_flags=(flags & 0x31) | 4, stack=True)
    for flags in flags_list:
        add('brn', ['@@BRN@@'], flags=flags)
    return cases


def word(value):
    return f'${value:04x}' if isinstance(value, int) else value


def render(cases):
    blocks, vectors = [], []
    for number, case in enumerate(cases, 1):
        name = f'v{number:04x}'
        instructions = case['instructions']
        if instructions == ['@@BRN@@']:
            instructions = [f'brn bn{number:04x}', f'bra bo{number:04x}',
                            f'bn{number:04x}', 'jmp failed', f'bo{number:04x}']
        blocks += [f'; {number:04X}: {case["name"]}', f'        ldx #{name}',
                   '        stx vector', '        jsr seed']
        blocks += [(line if line.startswith(('bn', 'bo')) else '        ' + line) for line in instructions]
        blocks += ['        jsr verify']
        d = case['expected_d']
        vectors += [name, f'        db ${case["a"]:02x},${case["b"]:02x}',
            f'        dw {word(case["x"])}',
            f'        db ${case["flags"]:02x},${case["memory"] >> 8:02x},${case["memory"] & 255:02x},${d >> 8:02x},${d & 255:02x}',
            f'        dw {word(case["expected_x"])}',
            f'        db ${case["expected_flags"]:02x},${case["expected_memory"] >> 8:02x},${case["expected_memory"] & 255:02x}',
            f'        dw ${number:04x},{case["pointer"]}',
            f'        db {int(case["stack"])}']
    template = (SOURCE / 'HDTEST.ASM.in').read_text()
    return template.replace('@@CASES@@', '\n'.join(blocks)).replace(
        '@@VECTORS@@', '\n'.join(vectors)).replace('@@COUNT@@', str(len(cases))).replace(
        '@@PRINT@@', (SOURCE / 'print.inc').read_text())


def assemble(unias, source, output):
    result = subprocess.run([unias, '-l', str(output.with_suffix('.LST')),
                             '-o', str(output), str(source)], capture_output=True, text=True)
    output.with_suffix('.log').write_text(result.stdout + result.stderr)
    if result.returncode or 'Error' in result.stdout or not output.is_file():
        raise RuntimeError(result.stdout + result.stderr)
    data = output.read_bytes()
    if not 0 < len(data) < 0x9f00:
        raise ValueError(f'{output}: command exceeds conventional program memory')
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unias', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    cases = make_cases()
    source = args.output / 'HDTEST.ASM'
    source.write_text(render(cases))
    binary = assemble(args.unias, source, args.output / 'HDTEST.CMD')
    # Locate scratch via the listing symbol table, then regenerate indexed CPX expectations.
    listing = (args.output / 'HDTEST.LST').read_text()
    import re
    match = re.search(r'^SCRATCH\s*=\$([0-9A-F]{4})\s*$', listing, re.MULTILINE)
    if not match:
        raise ValueError('UniAS listing did not expose SCRATCH address')
    scratch = int(match[1], 16)
    for case in cases:
        if 'cpx_symbolic' in case:
            offset, right, flags = case['cpx_symbolic']
            case['expected_flags'] = arithmetic(scratch-offset, right, flags, True)[1] | 0xc0
    source.write_text(render(cases))
    binary = assemble(args.unias, source, args.output / 'HDTEST.CMD')
    programs = {'HDTEST.CMD': binary}
    for name in ('HDMUL', 'HDSLEEP'):
        asm = (SOURCE / f'{name}.ASM').read_text().replace('@@PRINT@@', (SOURCE / 'print.inc').read_text())
        path = args.output / f'{name}.ASM'
        path.write_text(asm)
        programs[name+'.CMD'] = assemble(args.unias, path, args.output / (name+'.CMD'))
    (args.output / 'README.TXT').write_bytes((SOURCE / 'README.TXT').read_text().replace('\n', '\r\n').encode('ascii'))
    metadata = dict(cases=len(cases), scratch=scratch, origin=0x100,
        programs={name:dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest()) for name,data in programs.items()},
        vectors=[dict(id=f'{n:04X}', **case) for n,case in enumerate(cases,1)])
    (args.output / 'tests.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(f'Built HDTEST ({len(cases)} cases), exhaustive HDMUL and HDSLEEP with UniAS')


if __name__ == '__main__':
    main()
