"""Test/image tooling bridge to the real UniAS and the firmware Makefile.

No instruction encoding, source rewriting or ROM patching lives here.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def assembler_path(unias=None):
    name = unias or os.environ.get('UNIAS', 'unias')
    found = shutil.which(name)
    if found:
        return found
    path = Path(name)
    if not path.is_file():
        raise FileNotFoundError('Set UNIAS to the installed UniAS cross-assembler')
    return str(path.resolve())


def assemble(unias, out, source, output, defines=()):
    """Pass an existing source directly to UniAS, retaining its listing/log."""
    result = subprocess.run([assembler_path(unias), *defines, '-l', output+'.LST',
                             '-o', output, source], cwd=out, capture_output=True, text=True)
    log = result.stdout+result.stderr
    (out/(output+'.log')).write_text(log)
    if result.returncode or 'Error:' in log or 'symbol table full' in log:
        raise RuntimeError('\n'.join(line for line in log.splitlines()
                                    if any(s in line for s in ('Error:', 'Line ', 'unias:', 'symbol table full'))))
    return (out/output).read_bytes()


def bios_symbols(listing):
    return {name: int(value, 16) for name, value in
            re.findall(r'^([A-Z_][A-Z0-9_]*) =\$([0-9A-F]+)$', listing, re.M)}


def data_source(data):
    """Data literals for isolated test fixtures, never production firmware."""
    return ''.join('    db '+','.join(f'${n:02x}' for n in data[k:k+16])+'\n'
                   for k in range(0, len(data), 16))


def build(name='boot', unias=None):
    """Build checked-in sources with Make; image tools read the resulting files."""
    if name not in ('boot', 'loader'):
        raise ValueError('unknown bootstrap image')
    subprocess.run(['make', '-s', '-f', 'firmware/Makefile', 'bootstrap',
                    'UNIAS='+assembler_path(unias)], cwd=ROOT, check=True)
    labels = ROOT/('build/boot-labels.json' if name == 'boot' else 'build/bootstrap/loader-labels.json')
    return (ROOT/'build'/(name+'.bin')).read_bytes(), json.loads(labels.read_text())
