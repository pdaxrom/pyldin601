"""Prove the HDL CCR assertion rejects the former TPA-in-SWI mask bug."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/dma-bios'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--nvc', default='nvc')
a = p.parse_args()
paths = [OUT / name for name in ('rom.mem', 'ram.mem', 'wait.mem')]
saved = {path: path.read_bytes() for path in paths}
try:
    # Reintroduce the old mask capture, preserving every address/branch:
    # LDAA SWIC; PSHA -> TPA; NOP; PSHA. Only the external native BIOS changes.
    words = (OUT / 'rom-0.mem').read_text().split()
    rom = bytearray.fromhex(''.join(word[2:] + word[:2] for word in words))
    needle = bytes.fromhex('960436')
    bios = rom[65536:65536 + 4096]
    assert bios.count(needle) == 2, 'expected RAM/PAL caller-mask snapshots'
    rom[65536:65536 + 4096] = bios.replace(needle, bytes.fromhex('070136'))
    paths[0].write_text(''.join(f'{rom[i+1]:02x}{rom[i]:02x}\n' for i in range(0, len(rom), 2)))
    shutil.copyfile(OUT / 'ram-0-1-3.mem', paths[1])
    shutil.copyfile(OUT / 'wait-0.mem', paths[2])
    command = [a.nvc, '--std=2008', '--work=work:build/dma-bios/rtl',
               '--ieee-warnings=off', '-e', '-j', '-gMODEL_A=0', '-gHD=1',
               '-gSPEED=3', 'tb_dma_bios', '-r', 'tb_dma_bios']
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    log = result.stdout + result.stderr
    (OUT / 'negative-mask.log').write_text(log)
    if result.returncode == 0 or 'INT E8 ignored caller SEI during DMA wait' not in log:
        raise RuntimeError('CCR regression test did not reject the old mask bug:\n' + log[-4000:])
    (OUT / 'negative-mask.json').write_text(json.dumps({
        'result': 'PASS: real HDL CPU CCR check rejects old TPA-in-SWI mask capture',
        'expected_failure': 'INT E8 ignored caller SEI during DMA wait',
        'exit_code': result.returncode,
    }, indent=2) + '\n')
    print('PASS DMA caller-mask negative control: old TPA capture rejected by actual CPU CCR')
finally:
    for path, data in saved.items():
        path.write_bytes(data)
