"""Execute resident BIOS against real FAT16 images and byte-level SD transfers."""
import binascii
from pathlib import Path
import struct
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'tools'))
import make_sd as sd
from update_boot import root_files

work = root / 'build/setup-tests'
work.mkdir(exist_ok=True)
original = (root / 'build/models-sd.img').read_bytes()
start = sd.u32(original, 454) * 512
length = sd.u32(original, 458) * 512
volume = original[start:start + length]
reserved, copies, spf = sd.u16(volume, 14), volume[16], sd.u16(volume, 22)
directory = start + (reserved + copies * spf) * 512
data_start = directory + sd.u16(volume, 17) * 32
entry = next(p for p in range(directory, data_start, 32)
             if original[p:p + 11] == b'P601    SET')
cluster = sd.u16(original, entry + 26)
record = data_start + (cluster - 2) * 512


def run(name, image, mode, flags, writes=0, partition=0):
    source, output = work / f'{name}.img', work / f'{name}-result.img'
    source.write_bytes(image)
    result = subprocess.run(['build/test_firmware', 'build/boot.bin', str(source),
                             mode, str(output)], cwd=root, text=True, capture_output=True)
    (work / f'{name}.log').write_text(result.stdout + result.stderr)
    if result.returncode:
        raise AssertionError(f'{name}: {result.stdout}{result.stderr}')
    expected = f'settings={flags & 1}/{(flags >> 1) & 1}/{1 << (flags >> 2)}MHz, partition={partition}, SD writes={writes}'
    assert expected in result.stdout, (name, result.stdout)
    after = output.read_bytes()
    assert after[:start] == image[:start] and after[start + length:] == image[start + length:], name
    before_files, after_files = root_files(image[start:start + length]), root_files(after[start:start + length])
    assert {k: v for k, v in before_files.items() if k != 'P601.SET'} == {
        k: v for k, v in after_files.items() if k != 'P601.SET'}, name
    if writes:
        expected_record = sd.settings_record(flags & 1, bool(flags & 2), 1 << (flags >> 2), partition)
        assert after_files['P601.SET'] == expected_record, name
        updated_volume = after[start:start + length]
        assert updated_volume[reserved * 512:(reserved + spf) * 512] == updated_volume[
            (reserved + spf) * 512:(reserved + 2 * spf) * 512], name
    else:
        assert after == image, name
    print(f'PASS setup {name}: {expected}; ROMs/loader/A/B preserved', flush=True)
    return after


saved = run('save-existing', original, 'save', 3, writes=1)
run('menu-8mhz', original, 'save8', 15, writes=1)
run('menu-frequency-left', original, 'save-left', 15, writes=1)
run('load-saved', saved, 'auto', 3)
run('temporary', original, '601a-hd6303', 3)
run('discard', original, 'exit', 0)
run('save-sdsc', original, 'save-sdsc', 3, writes=1)
for bit in range(1, 8):
    run(f'busy-release-bit-{bit}', original, f'save-busy-{bit}', 3, writes=1)
run('busy-long-transition', original, 'save-busy-long', 3, writes=1)
run('busy-sdsc-transition', original, 'save-sdsc-busy', 3, writes=1)
run('rejected-write', original, 'save-denied', 3)
readonly = bytearray(original)
readonly[entry + 11] |= 1
run('readonly', readonly, 'save-readonly', 3)

missing = bytearray(original)
missing[entry] = 0xe5
for copy in range(copies):
    struct.pack_into('<H', missing, start + (reserved + copy * spf) * 512 + cluster * 2, 0)
run('missing-defaults', missing, 'setup-default', 2)
run('create-missing', missing, 'save-default', 3, writes=4)
run('create-busy-transition', missing, 'save-default-busy', 3, writes=4)
damaged = bytearray(original)
damaged[record + 14] ^= 1
run('bad-checksum', damaged, 'setup-default', 2)
damaged = bytearray(original)
damaged[record + 8] = 3
struct.pack_into('>H', damaged, record + 14, binascii.crc_hqx(damaged[record:record + 14], 0))
run('bad-version', damaged, 'setup-default', 2)

for flags in range(16):
    configured = bytearray(original)
    configured[record:record + 16] = sd.settings_record(flags & 1, bool(flags & 2), 1 << (flags >> 2))
    run(f'config-{flags:02x}', configured, 'auto', flags)
print('PASS all sixteen model/ISA/frequency settings and BIOS persistence/error cases')

part_saved=run('save-part4',original,'save-part4',3,writes=1,partition=4)
run('load-part4',part_saved,'auto',3,partition=4)
run('temporary-part4',original,'temporary-part4',0,partition=4)
run('discard-part4',original,'exit-part4',0)
run('partition-wrap-left',original,'save-part-left',0,writes=1,partition=36)
for number in (1,36):
    configured=bytearray(original)
    configured[record:record+16]=sd.settings_record(0,False,1,number)
    run(f'load-part-{number}',configured,'auto',0,partition=number)
configured=bytearray(original)
legacy=bytearray(sd.settings_record(1,True,4));legacy[8]=1;legacy[10]=0
struct.pack_into('>H',legacy,14,binascii.crc_hqx(legacy[:14],0))
configured[record:record+16]=legacy
run('legacy-v1-auto',configured,'auto',11)
configured[record:record+16]=sd.settings_record(0,False,1)
configured[record+10]=37
struct.pack_into('>H',configured,record+14,binascii.crc_hqx(configured[record:record+14],0))
run('partition-out-of-range',configured,'setup-default',2)
print('PASS BIOS partition persistence, temporary/EXIT, AUTO, logical bounds and version-1 compatibility')
