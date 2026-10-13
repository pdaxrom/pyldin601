"""Execute the historical native boot sector, file shell and ROM fallback."""
from pathlib import Path
import argparse
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import add_files, root_files, layout
from sd_partitions import scan, put_entry

p = argparse.ArgumentParser()
p.add_argument('--cc', default='cc')
a = p.parse_args()
out = ROOT/'build/shell-boot'
out.mkdir(parents=True, exist_ok=True)
image = bytearray((ROOT/'images/sd.img').read_bytes())
parts = scan(image, max_logical=32)
part_a = next(p for p in parts if p.number == 2)
part_c = next(p for p in parts if p.number == 4)
command = (ROOT/'build/partitions/SHELL.CMD').read_bytes()
start, end = part_a.start*512, (part_a.start+part_a.sectors)*512
sector = bytes(image[start:start+512])
assert sector[510:512] == b'\xa5\x5a'
# Exercise the unchanged historical 3.20 disk shell, then the independent
# source-built 3.10 shell in a separate fixture. Neither replaces the image.
original_command = root_files(image[start:end])['UNIDOS.CMD']
assert original_command != command
(out/'disk.img').write_bytes(image)
source = bytearray(image)
source[start:end] = add_files(source[start:end], {'UNIDOS.CMD': command}, replace=True)
assert source[start:start+512] == sector
(out/'source.img').write_bytes(source)
rom = bytearray(image)
rom[start+510:start+512] = b'\x55\xaa'
(out/'rom.img').write_bytes(rom)
no_file = bytearray(image)
volume = bytearray(no_file[start:end])
_, _, _, _, _, root, entries, _ = layout(volume)
directory = volume[root:root+entries*32]
for offset in range(0, len(directory), 32):
    if directory[offset:offset+11] == b'UNIDOS  CMD':
        directory[offset:offset+11] = b'SAVED   CMD'
        break
else:
    raise AssertionError('disk shell directory entry')
# Preserve every cluster and the original executable boot sector; change only
# a directory filename to exercise the loader's genuine file-not-found path.
volume[root:root+len(directory)] = directory
no_file[start:end] = volume
(out/'no-file.img').write_bytes(no_file)

cs, ce = part_c.start*512, (part_c.start+part_c.sectors)*512
volume = bytearray(add_files(image[cs:ce], {'UNIDOS.CMD': original_command}, replace=True))
# Preserve its BPB/geometry; transplant the historical native boot code.
volume[0x4d:512] = sector[0x4d:512]
active = bytearray(image)
active[cs:ce] = volume
active[494] = 0x80
(out/'active.img').write_bytes(active)

base = len(image)//512
logical = bytearray(image)+bytearray((2048+part_c.sectors)*512)
put_entry(logical, 0, 3, 0x0f, base, 2048+part_c.sectors)
logical[base*512+510:base*512+512] = b'\x55\xaa'
put_entry(logical, base, 0, 1, 2048, part_c.sectors)
logical[(base+2048)*512:] = volume
logical += bytes((-len(logical)) % (1024*512))
(out/'logical.img').write_bytes(logical)

runner = out/'test_shell_boot'
subprocess.run([a.cc, '-O2', '-I../pyldin601/src', 'tests/test_shell_boot.c', '-o', str(runner)], cwd=ROOT, check=True)
cases = [('disk.img', 'disk', 0), ('disk.img', 'disk-only', 0),
         ('source.img', 'disk-only', 0),
         ('rom.img', 'rom', 0), ('rom.img', 'missing', 0),
         ('rom.img', 'no-vector', 0),
         ('no-file.img', 'no-file', 0),
         ('disk.img', 'read-error', 0), ('active.img', 'disk-only', 0),
         ('logical.img', 'disk-only', 5)]
for model in ('601', '601a'):
    for cpu in ('mc6800', 'hd6303'):
        for filename, mode, partition in cases:
            subprocess.run([str(runner), str(out/filename), model, cpu, mode, str(partition)], cwd=ROOT, check=True)
