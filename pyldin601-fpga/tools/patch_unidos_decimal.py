"""Patch the decimal routine in a classic 10001-byte UniDOS disk shell.

Assemble the owned ROM-shell routine at the disk shell's existing address.
All other code, configuration fields and their addresses remain byte-identical.
"""
import argparse
import hashlib
import os
from pathlib import Path
import tempfile

from unias import assemble

ROOT = Path(__file__).resolve().parents[1]
POWERS = bytes.fromhex(
    '80 96 98 00 40 42 0f 00 a0 86 01 00 10 27 00 00 '
    'e8 03 00 00 64 00 00 00 0a 00 00 00 01 00 00 00')
SUBTRACT = bytes.fromhex('5f df 7b de 79 a6 00 de 7b a0 00 36')


def patch(data, unias):
    if len(data) != 10001 or data.count(POWERS) != 1 or data.count(SUBTRACT) != 1:
        raise ValueError('Unsupported UniDOS disk shell layout')
    subtract = data.index(SUBTRACT)
    candidates = [p for p in range(max(0, subtract-96), subtract)
                  if data[p] == 0x7f and data[p+3:p+6] == b'\xdf\x79\x7f']
    if len(candidates) != 1:
        raise ValueError('Ambiguous decimal entry')
    begin = candidates[0]
    table = data.index(POWERS)
    end = table + len(POWERS)
    address = 0xc000 + begin - (len(data)-8192)
    flag = int.from_bytes(data[begin+1:begin+3], 'big')
    decimal = int.from_bytes(data[begin+6:begin+8], 'big')
    expected_tail = (b'\xfa' + decimal.to_bytes(2, 'big') + b'\xf7' +
                     decimal.to_bytes(2, 'big') + b'\x26\x02\x86\x20\x7d' +
                     flag.to_bytes(2, 'big') + b'\x26\x03\x3f\x69\x39\x3f\x22\x39')
    classic = data[table-len(expected_tail):table] == expected_tail
    source = (ROOT/'firmware/bios/UNIDOS.ASM').read_text('latin1')
    start = source.index('pr_dec\t\tproc')
    finish = source.index('\n\t\tendp', start) + len('\n\t\tendp')
    routine = source[start:finish]
    header = (f'x1 = $79\nx2 = $7b\ndec_flag = ${decimal:04x}\n'
              f'pr_dec_flag = ${flag:04x}\n    org ${address:04x}\n')
    with tempfile.TemporaryDirectory(prefix='unidos-decimal-', dir=ROOT/'build') as directory:
        work = Path(directory)
        (work/'DECIMAL.ASM').write_text(header+routine+'\n    end\n', encoding='ascii')
        assemble(unias, work, 'DECIMAL.ASM', 'DECIMAL.BIN')
        replacement = (work/'DECIMAL.BIN').read_bytes()
    if len(replacement) > end-begin or replacement[:8] != data[begin:begin+8]:
        raise ValueError('Replacement does not fit or changes the entry ABI')
    if not classic and data[begin:end] != replacement:
        raise ValueError('Unsupported decimal output routine')
    result = data[:begin]+replacement+b'\x01'*(end-begin-len(replacement))+data[end:]
    assert len(result) == len(data) and result[:begin] == data[:begin] and result[end:] == data[end:]
    return result, dict(address=f'0x{address:04X}', offset=begin,
                        original_bytes=end-begin, assembled_bytes=len(replacement),
                        already_fixed=not classic,
                        original_sha256=hashlib.sha256(data).hexdigest(),
                        patched_sha256=hashlib.sha256(result).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--unias', default=os.environ.get('UNIAS', 'unias'))
    args = parser.parse_args()
    result, report = patch(args.source.read_bytes(), args.unias)
    args.output.write_bytes(result)
    import json
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
