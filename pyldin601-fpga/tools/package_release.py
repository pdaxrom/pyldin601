#!/usr/bin/env python3
"""Package a built checkout as a checked, deterministic release candidate.

Only ordinary files are written. No SD device, FTDI, or running HG directory
is opened. The original system floppy and extracted software are retained.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zlib

REQUIRED_RUNTIME = {
    'NC.PGM', 'NCMAIN.PGM', 'NCEDIT.PGM',
    'PAINT.PGM', 'PNTNAT.PGM', 'PNTRGB.PGM', 'PNTHAM.PGM',
    'UART.PGM', 'HG.PGM', 'CVM/RAMLOAD.PGM', 'CVM/UNIAS.CMD',
    'CVM/UNICC.CMD', 'CVM/UNILD.CMD', 'CVM/UNIAR.CMD',
    'CVM/ZVM6303.ROM', 'CVM/ZVM6800.ROM', 'CVM/SYSTEM.H',
    'CVM/CSTART.OBJ', 'CVM/CRT.LIB',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def describe(data):
    return dict(bytes=len(data), sha256=sha(data))


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')


def fat12_tree(volume):
    """Read files recursively, independently of the C packer's round trip."""
    from add_disk_files import layout, fat_get
    info, table, _, _, _, root, entries, data_start = layout(volume)
    unit = info['sectors_per_cluster'] * 512
    claimed, result = set(), {}

    def chain(cluster):
        data = bytearray()
        while cluster < 0xff8:
            if not 2 <= cluster < info['clusters'] + 2 or cluster in claimed:
                raise ValueError('invalid/shared FAT12 chain')
            claimed.add(cluster)
            start = data_start + (cluster - 2) * unit
            data.extend(volume[start:start + unit])
            cluster = fat_get(table, cluster)
        return bytes(data)

    def directory(data, prefix=''):
        for offset in range(0, len(data), 32):
            entry = data[offset:offset + 32]
            if not entry[0]:
                break
            if entry[0] == 0xe5 or entry[0] == 46 or entry[11] & 8:
                continue
            base = entry[:8].decode('ascii').rstrip()
            ext = entry[8:11].decode('ascii').rstrip()
            name = prefix + base + ('.' + ext if ext else '')
            if name in result:
                raise ValueError('duplicate FAT12 path: ' + name)
            cluster, size = struct.unpack_from('<HI', entry, 26)
            content = chain(cluster) if cluster else b''
            if entry[11] & 16:
                if not cluster:
                    raise ValueError('directory without a FAT chain')
                directory(content, name + '/')
            else:
                if len(content) != ((size + unit - 1) // unit) * unit:
                    raise ValueError('FAT12 size/chain mismatch: ' + name)
                result[name] = content[:size]

    directory(volume[root:root + entries * 32])
    return result


def payload(root):
    """Explicit install list excludes loader pieces and test-only overlays."""
    groups = {
        'game': 'ARKANOID XONIX SDKTEST',
        'audio': 'YPLAY GFXMUSIC',
        'gfx': 'GFX VIEW HVIEW HAM SPRITES CLIPSPR AY',
        'hg': 'HG HGTIME',
        'storage': 'MOUNT UMOUNT FORMAT FDISK',
        'memory-test': 'RAMPAGE RAMALLOC DMATEST',
        'nc': 'NC NCMAIN NCEDIT',
        'paint': 'PAINT PNTNAT PNTRGB PNTHAM',
        'input': 'UART UARTTEST',
        'ramloader': 'RAMLOAD RAMCHECK',
    }
    files = {name + '.PGM': root / 'build' / group / (name + '.PGM')
             for group, names in groups.items() for name in names.split()}
    for directory in ('game', 'audio', 'gfx', 'nc', 'paint', 'input', 'hg', 'memory'):
        for path in sorted((root / 'firmware' / directory).iterdir()):
            if path.suffix in ('.TXT', '.YM', '.IFF', '.CFG'):
                if path.name in files and files[path.name].read_bytes() != path.read_bytes():
                    raise ValueError('conflicting release resource: ' + path.name)
                files[path.name] = path
    files['DEMO.YM'] = root / 'build/audio/DEMO.YM'
    cvm = json.loads((root / 'build/cvm/manifest.json').read_text())
    for name in sorted(cvm):
        files['CVM/' + name] = root / 'build/cvm' / name
    # RAMLOAD resolves VM ROMs next to its own executable.
    files['CVM/RAMLOAD.PGM'] = files['RAMLOAD.PGM']
    return {name: path.read_bytes() for name, path in sorted(files.items())}


def checked_fpga(root, evidence):
    inputs = json.loads((evidence / 'routed-inputs.json').read_text())
    for name, digest in inputs.items():
        path = Path(name)
        if path.is_absolute() or '..' in path.parts:
            raise ValueError('unsafe FPGA input name')
        if sha((root / path).read_bytes()) != digest:
            raise ValueError('FPGA inputs differ from routed JED: ' + name)
    # Do not accept a manifest which omits a newly added RTL source.
    required = {p.relative_to(root).as_posix() for p in (root / 'rtl').iterdir()
                if p.suffix in ('.v', '.vhd', '.mem', '.vh')}
    required |= {'build/boot.mem', 'build-diamond.tcl',
                 'pyldin601_classic.ldf', 'pyldin601_classic.lpf', 'pyldin601_classic.sty'}
    if not required <= inputs.keys():
        raise ValueError('incomplete routed FPGA input manifest')
    record = json.loads((evidence / 'validated-build.json').read_text())
    jed = (evidence / 'pyldin601_classic_impl1.jed').read_bytes()
    if sha(jed) != record['jed_sha256'] or not record['timing_passed']:
        raise ValueError('unvalidated FPGA binary')
    timing = (evidence / 'pyldin601_classic_impl1.twr').read_text(errors='replace')
    slacks = re.findall(r'Cumulative negative slack:\s*(-?[\d.]+)', timing)
    untimed = re.findall(r'(\d+) unconstrained paths found', timing)
    if not slacks or any(float(n) for n in slacks) or not untimed or any(map(int, untimed)):
        raise ValueError('FPGA timing report does not pass')
    return dict(jed_sha256=sha(jed), inputs=inputs, timing_passed=True,
                resource_usage={k: record[k] for k in ('lut4', 'slices', 'pfu_registers', 'ebr', 'pll')})


def pack_volume(root, scratch, volume, files):
    from add_disk_files import short_name
    source, target = scratch / 'before.img', scratch / 'after.img'
    source.write_bytes(volume)
    args = []
    directories = set()
    for name, data in sorted(files.items()):
        parts = name.split('/')
        for part in parts[:-1]:
            short_name(part + '.DIR')
        short_name(parts[-1])
        for depth in range(1, len(parts)):
            directories.add('/'.join(parts[:depth]))
        path = scratch / 'files' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        args.append(name + '=' + str(path))
    subprocess.run([str(root / 'build/migration/pack'), str(source), str(target),
                    *[d + '=' for d in sorted(directories)], *args], check=True)
    result = target.read_bytes()
    if fat12_tree(result) != files:
        raise ValueError('independent FAT12 package readback failed')
    return result


def check_roms(root, files):
    for model, name in enumerate(('P601.ROM', 'P601A.ROM')):
        data = files[name]
        if (data[:8] != b'P601BOOT' or len(data) != 512 + 0x11800
                or struct.unpack_from('<I', data, 8)[0] != 2 or data[25] != model
                or struct.unpack_from('<I', data, 20)[0] != zlib.crc32(data[512:])
                or struct.unpack_from('<I', data, 508)[0] != zlib.crc32(data[:508])):
            raise ValueError('invalid boot ROM container: ' + name)
        for page, source in ((0, 'UNIBIOS'), (2, 'PARTS'), (3, 'SD'),
                             (4, 'KERNEL'), (6, 'RAMMAN'), (7, 'SHELL')):
            if data[512 + page * 8192:512 + (page + 1) * 8192] != (root / f'build/partitions/{source}.ROM').read_bytes():
                raise ValueError('stale ROM page: ' + source)
        bios = 'BIOS_A' if model else 'BIOS'
        if data[512 + 65536:512 + 0x11000] != (root / f'build/partitions/{bios}.ROM').read_bytes():
            raise ValueError('stale native BIOS')
    if files['LOADER.BIN'] != (root / 'build/loader.bin').read_bytes():
        raise ValueError('stale SD loader')


def verify(output):
    from sd_partitions import scan
    from update_boot import root_files
    manifest = json.loads((output / 'release.json').read_text())
    if not {'hg/' + n for n in REQUIRED_RUNTIME} <= manifest['files'].keys():
        raise ValueError('incomplete application/toolchain bundle')
    for name, want in manifest['files'].items():
        path = Path(name)
        if path.is_absolute() or '..' in path.parts:
            raise ValueError('unsafe manifest path')
        if describe((output / path).read_bytes()) != want:
            raise ValueError('release checksum mismatch: ' + name)
    fpga = json.loads((output / 'fpga/inputs.json').read_text())
    if sha((output / 'fpga/pyldin601.jed').read_bytes()) != fpga['jed_sha256'] or fpga['jed_sha256'] != manifest['fpga_sha256']:
        raise ValueError('FPGA binary provenance mismatch')
    for name, digest in fpga['inputs'].items():
        path = Path(name)
        if path.is_absolute() or '..' in path.parts:
            raise ValueError('unsafe FPGA source path')
        if sha((output / 'fpga/source' / path).read_bytes()) != digest:
            raise ValueError('FPGA source provenance mismatch: ' + name)
    image = (output / 'sd.img').read_bytes()
    sdinfo = json.loads((output / 'sd.json').read_text())
    if describe(image) != dict(bytes=sdinfo['bytes'], sha256=sdinfo['sha256']):
        raise ValueError('SD image hash/size mismatch')
    if sha(image) != manifest['sd_sha256']:
        raise ValueError('release and SD hashes differ')
    installed = set()
    for part in scan(image):
        volume = image[part.start * 512:(part.start + part.sectors) * 512]
        files = root_files(volume) if part.number == 1 else fat12_tree(volume)
        actual = {name: describe(data) for name, data in files.items()}
        if actual != sdinfo['partitions'][str(part.number)]['files']:
            raise ValueError('SD content manifest mismatch')
        if part.number in (3, 4):
            for name, data in files.items():
                path = output / 'hg' / name
                if path.is_file() and path.read_bytes() != data:
                    raise ValueError('SD/HG mismatch: ' + name)
                if path.is_file():
                    installed.add(name)
    if not REQUIRED_RUNTIME <= installed:
        raise ValueError('required application missing from SD')
    return manifest


def package(root, output, evidence, sources, version):
    from update_boot import root_files
    from sd_partitions import scan
    fpga = checked_fpga(root, evidence)
    files = payload(root)
    image = bytearray((root / 'build/sd.img').read_bytes())
    parts = {p.number: p for p in scan(image)}
    boot = parts[1]
    boot_files = root_files(image[boot.start * 512:(boot.start + boot.sectors) * 512])
    check_roms(root, boot_files)
    original = {n: image[p.start * 512:(p.start + p.sectors) * 512] for n, p in parts.items()}
    # Verify original native floppy and imported data are not accidentally replaced.
    old_c = fat12_tree(original[4])
    c_files = dict(old_c)
    c_files.update({name: data for name, data in files.items() if name.startswith('CVM/')})
    b_files = {name: data for name, data in files.items() if '/' not in name}
    output.mkdir(parents=True, exist_ok=False)
    scratch = output / '.scratch'
    scratch.mkdir()
    for number, contents in ((3, b_files), (4, c_files)):
        part = parts[number]
        image[part.start * 512:(part.start + part.sectors) * 512] = pack_volume(root, scratch, original[number], contents)
    if image[parts[2].start * 512:(parts[2].start + parts[2].sectors) * 512] != original[2]:
        raise ValueError('original system floppy changed')
    (output / 'sd.img').write_bytes(image)
    sdinfo = {'bytes': len(image), 'sha256': sha(image), 'partitions': {}}
    for number, part in parts.items():
        volume = image[part.start * 512:(part.start + part.sectors) * 512]
        contents = root_files(volume) if number == 1 else fat12_tree(volume)
        sdinfo['partitions'][str(number)] = dict(start_lba=part.start, sectors=part.sectors,
            type=part.kind, sha256=sha(volume), files={n: describe(d) for n, d in sorted(contents.items())})
    write_json(output / 'sd.json', sdinfo)
    for name, data in files.items():
        dest = output / 'hg' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
    (output / 'boot').mkdir()
    for name, data in boot_files.items():
        (output / 'boot' / name).write_bytes(data)
    (output / 'fpga').mkdir()
    for suffix in ('jed', 'twr', 'mrp'):
        shutil.copyfile(evidence / ('pyldin601_classic_impl1.' + suffix), output / 'fpga' / ('pyldin601.' + suffix))
    write_json(output / 'fpga/inputs.json', fpga)
    for name, digest in fpga['inputs'].items():
        data = (root / name).read_bytes()
        if sha(data) != digest:
            raise ValueError('FPGA input changed while packaging: ' + name)
        destination = output / 'fpga/source' / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    # Preserve the original CPU authorship alongside the adapted source.
    shutil.copytree(root / 'vendor', output / 'fpga/source/vendor')
    shutil.copytree(root / 'docs', output / 'docs')
    # Portable host tools, not executables tied to the packager's OS/ISA.
    for path in sorted((root / 'host/hg').iterdir()):
        if path.is_file():
            destination = output / 'host/hg' / path.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, destination)
            destination.chmod(path.stat().st_mode & 0o777)
    (output / 'tools').mkdir()
    for name in ('uart_xmodem.py', 'uart_board_test.py', 'uart_terminal_board_test.py',
                 'ham8conv.c', 'make_sd.py', 'sd_partitions.py', 'update_boot.py',
                 'add_disk_files.py', 'unias.py'):
        shutil.copyfile(root / 'tools' / name, output / 'tools' / name)
    shutil.copyfile(Path(__file__), output / 'tools/package_release.py')
    (output / 'tools/Makefile').write_text(
        'CC ?= cc\nCFLAGS ?= -O2\n\n'
        'ham8conv: ham8conv.c\n'
        '\t$(CC) $(CFLAGS) -Wall -Wextra -Wpedantic '
        '$(shell pkg-config --cflags libjpeg libpng) $< -o $@ '
        '$(shell pkg-config --libs libjpeg libpng) -lm\n')
    (output / 'tests').mkdir()
    for name in ('test_hg_host.c', 'test_hg_watch.py', 'test_uart_xmodem_host.py'):
        shutil.copyfile(root / 'tests' / name, output / 'tests' / name)
    howto = root / 'docs/RELEASE.md'
    if howto.exists():
        text = howto.read_text()
        for name in ('BUILD.md', 'SD-CARD.md'):
            text = text.replace('](' + name + ')', '](docs/' + name + ')')
        (output / 'README.md').write_text(text)
    shutil.rmtree(scratch)
    # Host paths and timestamps are deliberately absent from the package manifest.
    revisions = {name: dict(commit=record['commit']) for name, record in sources.items()}
    manifest = dict(format=1, version=version, status='release-candidate', sources=revisions,
        packager_sha256=sha(Path(__file__).read_bytes()),
        fpga_sha256=fpga['jed_sha256'], sd_sha256=sha(image),
        hardware_matrix_status='pending complete release qualification',
        files={p.relative_to(output).as_posix(): describe(p.read_bytes())
               for p in sorted(output.rglob('*')) if p.is_file()})
    write_json(output / 'release.json', manifest)
    paths = [p for p in sorted(output.rglob('*')) if p.is_file()]
    (output / 'SHA256SUMS').write_text(''.join(sha(p.read_bytes()) + '  ' + p.relative_to(output).as_posix() + '\n' for p in paths))
    verify(output)
    return manifest


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--fpga-evidence', type=Path)
    p.add_argument('--sources', type=Path)
    p.add_argument('--version', default='2026.10.17-rc1')
    p.add_argument('--verify', action='store_true')
    args = p.parse_args()
    sys.path.insert(0, str(args.project.resolve() / 'tools'))
    if args.verify:
        result = verify(args.output)
    else:
        if not args.fpga_evidence or not args.sources:
            p.error('--fpga-evidence and --sources are required when packaging')
        result = package(args.project.resolve(), args.output.resolve(),
            args.fpga_evidence.resolve(), json.loads(args.sources.read_text()), args.version)
    print('PASS release', result['version'], len(result['files']), 'checked files', result['sd_sha256'])


if __name__ == '__main__':
    main()
