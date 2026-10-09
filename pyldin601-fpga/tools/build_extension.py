"""Assemble the banked FPGA BIOS with the project's UniAS cross assembler."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def build(unias='unias'):
    out = ROOT/'build/extension'
    out.mkdir(parents=True, exist_ok=True)
    assembler = shutil.which(unias) or str(Path(unias).resolve())
    for name in ('extension.asm', 'SERVICES.ASM'):
        shutil.copyfile(ROOT/'firmware/extension'/name, out/name)
    shutil.copyfile(ROOT/'firmware/gfx/GFXCLIP.ASM', out/'GFXCLIP.ASM')
    result = subprocess.run([assembler, '-D', 'GFXCLIP_ROM', '-l', 'FPGA.LST', '-o', 'FPGA.ROM',
                             'extension.asm'],
                            cwd=out, capture_output=True, text=True)
    (out/'unias.log').write_text(result.stdout+result.stderr)
    if result.returncode or 'Error:' in result.stdout:
        errors = '\n'.join(line for line in (result.stdout+result.stderr).splitlines()
                           if 'Error:' in line or 'Line ' in line or 'Line' in line)
        raise RuntimeError(f'{errors}\nFull assembler log: {out/"unias.log"}')
    data = (out/'FPGA.ROM').read_bytes()
    if len(data) != 8192 or data[:2] != b'\xa5\x5a' or sum(data)%256:
        raise ValueError('UniAS did not produce a valid 8 KiB checksummed ROM')
    listing = (out/'FPGA.LST').read_text()
    labels = {k.lower(): int(v,16) for k,v in re.findall(r'(?m)^(\w+) =\$([A-F0-9]+)$',listing)}
    (out/'labels.json').write_text(json.dumps(labels, indent=2, sort_keys=True)+'\n')
    print(f'FPGA.ROM: {labels["extension_end"]-0xc000} code/data bytes, 512 CRC table bytes, 8192 bytes with UniAS CHECKSUM')
    return data

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unias', default='unias')
    args = parser.parse_args()
    build(args.unias)
