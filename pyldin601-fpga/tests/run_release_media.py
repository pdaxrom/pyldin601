#!/usr/bin/env python3
"""Boot and launch NC from the packaged SD, including its original shell.

Use a built test checkout. Only private image copies have their BIOS settings
changed; the published image and all packaged program bytes remain intact.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--release', type=Path, required=True)
    args = parser.parse_args()
    root, release = args.project.resolve(), args.release.resolve()
    sys.path.insert(0, str(root / 'tools'))
    from make_sd import fat16, settings_record
    from update_boot import root_files
    from sd_partitions import scan
    from add_disk_files import install
    out = root / 'build/release-media'
    out.mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, 'tests/run_nc.py', '--prepare-only'], cwd=root, check=True)
    cc = os.environ.get('CC', 'cc')
    for source, name, flags in [('test_firmware.c', 'boot', ['-DCOMPACT_FIXTURE']),
                                ('test_nc.c', 'nc', [])]:
        subprocess.run([cc, '-O2', *flags, '-I../pyldin601/src',
                        'tests/' + source, '-o', str(out / name)], cwd=root, check=True)
    subprocess.run([cc, '-O2', '-I' + str(root.parent / 'pyldin601/src'),
                    '-DRELEASE_NC_SOURCE="' + str(root / 'tests/test_nc.c') + '"',
                    str(Path(__file__).with_name('test_release_nc.c')),
                    '-o', str(out / 'nc-cvm')], cwd=root, check=True)
    image = (release / 'sd.img').read_bytes()
    initial_sha = hashlib.sha256(image).hexdigest()
    p = next(p for p in scan(image) if p.number == 1)
    begin, end = p.start * 512, (p.start + p.sectors) * 512
    files = root_files(image[begin:end])
    helpers = {name + '.PGM': (root / 'build/nc' / (name + '.PGM')).read_bytes()
               for name in ('NCGRAF2', 'NCGRAF3')}
    results = []

    def run(command, name, description, expected=None):
        start = time.time()
        with (out / (name + '.log')).open('wb') as log:
            result = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
        text = (out / (name + '.log')).read_text(errors='replace')
        if result.returncode == 0 and expected and expected not in text:
            raise ValueError(name + ': expected settings not applied: ' + expected)
        record = dict(case=name, description=description, returncode=result.returncode,
                      seconds=round(time.time() - start, 2))
        results.append(record)
        (out / 'results.json').write_text(json.dumps(dict(sd_sha256=initial_sha, cases=results), indent=2) + '\n')
        if result.returncode:
            print(text[-5000:])
            result.check_returncode()
        print('PASS release media', name, flush=True)

    for model in ('601', '601a'):
        for cpu in ('mc6800', 'hd6303'):
            run([str(out / 'nc-cvm'), str(release / 'sd.img'), model, cpu, '0', 'ready'],
                f'nc-cvm-{model}-{cpu}', 'original disk shell, resident CPU VM, NC command execution/reload and cleanup')
            for speed in (1, 8):
                private_files = dict(files)
                private_files['P601.SET'] = settings_record(model == '601a', cpu == 'hd6303', speed)
                private = bytearray(image)
                private[begin:end] = fat16(private_files)
                media = out / 'private.img'
                media.write_bytes(private)
                name = f'boot-{model}-{cpu}-{speed}'
                run([str(out / 'boot'), str(root / 'build/boot.bin'), str(media)], name,
                    'real bootstrap/SPI CRC, both ROM selections, saved ISA/speed and warm Reset',
                    f'settings={int(model == "601a")}/{int(cpu == "hd6303")}/{speed}MHz')
                # The functional native harness has a fixed clock schedule.
                # Actual 1/2/4/8 MHz timing is covered by the HDL suites.
                if speed != 1:
                    continue
                # Graphic launchers are test instrumentation on private copies.
                # They do not replace NC or any other packaged application.
                graphic, _ = install(private, helpers, replace=True)
                media.write_bytes(graphic)
                for video in ((0, 3) if model == '601' else (0, 4, 2, 3)):
                    name = f'nc-{model}-{cpu}-video{video}'
                    run([str(out / 'nc'), str(media), model, cpu, str(video), 'ready'], name,
                        'original disk shell, packaged NC, panels/F1/F10, caret and heap/lease cleanup')
    if hashlib.sha256((release / 'sd.img').read_bytes()).hexdigest() != initial_sha:
        raise ValueError('published release image was modified')
    print('PASS packaged SD unchanged:', len(results), 'boot/NC configurations')


if __name__ == '__main__':
    main()
