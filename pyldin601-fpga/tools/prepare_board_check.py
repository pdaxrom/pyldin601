#!/usr/bin/env python3
"""Prepare a separate 8.3/CRLF directory for physical UniDOS board checks."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def payload(cvm, toolchain):
    files = {}

    def text(name, data):
        if isinstance(data, str):
            data = data.encode('ascii')
        data.decode('ascii')
        files[name] = data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')

    for path in sorted((ROOT / 'tests/board').iterdir()):
        if path.suffix in ('.JOB', '.TXT'):
            text(path.name, path.read_bytes())
    for name in ('HELLO.C', 'MAIN.ASM', 'HELP.ASM', 'SYSTEM.H',
                 'CVMDEF.INC', 'CVMABI.INC'):
        text(name, (cvm / name).read_bytes())
    for name in ('CSTART.OBJ', 'CRT.LIB'):
        files[name] = (cvm / name).read_bytes()
    for name in ('MIX.C', 'MINLINE.C', 'MNATIVE.ASM', 'NENTRY.ASM'):
        text(name, (toolchain / 'tests/cmodules' / name).read_bytes())
    text('MIXAPP.LNK', 'CSTART.OBJ\nMIX.OBJ\nMINLINE.OBJ\nMNATIVE.OBJ\nCRT.LIB\n')
    text('NENTRY.LNK', 'NENTRY.OBJ\nMIX.OBJ\nMINLINE.OBJ\nMNATIVE.OBJ\nCRT.LIB\n')
    text('LONG.TXT', ''.join(f'Line {n:04d}: Pyldin long text, selection and Undo/Redo.\n'
                             for n in range(1, 4097)))
    for n in range(128):
        text(f'MANY/F{n:03d}.TXT', f'File {n:03d}: scroll across the 63-entry cache boundary.\n')
    # This catches accidental long names and overlong shell lines in future edits.
    from add_disk_files import short_name
    for name, data in files.items():
        parts = name.split('/')
        for part in parts[:-1]:
            short_name(part + '.DIR')
        short_name(parts[-1])
        if name.endswith('.JOB'):
            for line in data.splitlines():
                expanded = line.replace(b'%1', b'E:\\REL1017').replace(b'%2', b'E:\\REL1017\\CVM').replace(b'%3', b'E:')
                if len(expanded) > 79:
                    raise ValueError(f'{name}: shell line exceeds 79 bytes: {line!r}')
    return files


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cvm', type=Path, default=ROOT / 'build/cvm')
    p.add_argument('--toolchain', type=Path,
                   default=ROOT.parents[2] / 'FPGA/hd6303-toolchain')
    p.add_argument('--output', type=Path, default=ROOT / 'build/board-check/BOARDCHK')
    a = p.parse_args()
    files = payload(a.cvm, a.toolchain)
    # Publishing is separate: never replace an existing directory or user data.
    a.output.mkdir(parents=True, exist_ok=False)
    for name, data in files.items():
        path = a.output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    manifest = {n: dict(bytes=len(d), sha256=hashlib.sha256(d).hexdigest())
                for n, d in sorted(files.items())}
    (a.output / 'FILES.JSN').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'{a.output}: {len(files)} files, {sum(map(len, files.values()))} bytes')


if __name__ == '__main__':
    main()
