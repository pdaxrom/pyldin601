"""Bootstrap UniCC twice under native UniDOS/HG, then use the rebuilt compiler."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import install


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--toolchain', type=Path, required=True)
    parser.add_argument('--cc', default='cc')
    parser.add_argument('--jobs', type=int, default=1)
    parser.add_argument('--quick', action='store_true', help='601/HD6303 only')
    args = parser.parse_args()
    tc = args.toolchain.resolve()
    out = ROOT/'build/cvm/selfhost'
    cross = out/'cross'
    cross.mkdir(parents=True, exist_ok=True)
    sources = {'SMALLC.C': (tc/'SMALL-C/SMALLC.C').read_bytes(),
               'CVMTEST.C': (ROOT/'firmware/cvm/CVMTEST.C').read_bytes()}
    for name in ('MMAIN.C', 'MHELP.C', 'MOTHER.C'):
        sources[name] = (tc/'tests/cmodules'/name).read_bytes()
    tools = {name: (tc/'pyldin'/name).read_bytes() for name in
             ('UNICC.CMD', 'UNIAS.CMD', 'UNILD.CMD', 'SYSTEM.H',
              'CVMDEF.INC', 'CSTART.OBJ', 'CRT.LIB', 'ZVM6303.ROM', 'ZVM6800.ROM')}
    tools['RAMLOAD.PGM'] = (ROOT/'build/ramloader/RAMLOAD.PGM').read_bytes()
    for name, data in (sources | tools).items():
        (cross/name).write_bytes(data)
    commands = ['unicc -o UC1.ASM SMALLC.C', 'unias -o UC1.CMD UC1.ASM',
                'uc1.cmd -o UC2.ASM SMALLC.C\tThere were 0 errors',
                'unias -o UC2.CMD UC2.ASM',
                'uc2.cmd -o CVMTEST.ASM CVMTEST.C\tThere were 0 errors',
                'unias -o CVMTEST.CMD CVMTEST.ASM', 'cvmtest.cmd\tCVM TEST PASS']
    for stem in ('MMAIN', 'MHELP', 'MOTHER'):
        commands += [f'uc2.cmd -c -o {stem}.ASM {stem}.C\tThere were 0 errors',
                     f'unias -c -o {stem}.OBJ {stem}.ASM']
    commands += ['unild -o MODTEST.PGM CSTART.OBJ MMAIN.OBJ MHELP.OBJ MOTHER.OBJ CRT.LIB',
                 'modtest.pgm\tC MODULE PASS']
    # Only the native execution uses UC1/UC2. Host expectations use the pure-C
    # bootstrap compiler; scvm cannot execute the optimized compiler's #asm.
    expected = ['UC1.ASM', 'UC1.CMD', 'UC2.ASM', 'UC2.CMD',
                'CVMTEST.ASM', 'CVMTEST.CMD']
    for index, command in enumerate(commands):
        words = command.split('\t')[0].split()
        name = words[0].lower()
        if name not in ('unicc', 'uc1.cmd', 'uc2.cmd', 'unias', 'unild'):
            continue
        name = 'unicc' if name in ('uc1.cmd', 'uc2.cmd') else name
        with (cross/f'{index}.log').open('wb') as log:
            subprocess.run([str(tc/name), *words[1:]], cwd=cross, stdout=log,
                           stderr=subprocess.STDOUT, check=True)
    for stem in ('MMAIN', 'MHELP', 'MOTHER'):
        expected += [stem+'.ASM', stem+'.OBJ']
    expected.append('MODTEST.PGM')
    assert (cross/'UC1.ASM').read_bytes() == (tc/'pyldin/UNICC.ASM').read_bytes()
    assert (cross/'UC1.CMD').read_bytes() == tools['UNICC.CMD']
    assert (cross/'UC1.ASM').read_bytes() == (cross/'UC2.ASM').read_bytes()
    assert (cross/'UC1.CMD').read_bytes() == (cross/'UC2.CMD').read_bytes()
    commandfile = out/'commands.txt'
    commandfile.write_text('\n'.join(commands)+'\n')
    image, _ = install((ROOT/'images/sd.img').read_bytes(),
                       {'HG.PGM': (ROOT/'build/hg/HG.PGM').read_bytes()}, replace=True)
    sd = out/'SD.IMG'
    sd.write_bytes(image)
    runner = out/'test_selfhost'
    subprocess.run([args.cc, '-O2', '-DNATIVE_TOOLS_HG', '-I../pyldin601/src',
                    'tests/test_native_tools.c', 'host/hg/fat12.c', 'host/hg/volume.c',
                    '-o', str(runner)], cwd=ROOT, check=True)

    def native_case(case):
        model, cpu = case
        result = out/(model+'-'+cpu)
        host = result/'host'
        if host.exists():
            shutil.rmtree(host)
        cvm = host/'CVM'
        cvm.mkdir(parents=True)
        for name, data in (sources | tools).items():
            (cvm/name).write_bytes(data)
        print('Native UniCC selfhost:', model, cpu, 'log:', result/'run.log', flush=True)
        with (result/'run.log').open('wb') as log:
            run = subprocess.run([str(runner), str(sd), model, cpu, str(result),
                                  str(commandfile), str(host)], cwd=ROOT,
                                 stdout=log, stderr=subprocess.STDOUT)
        if run.returncode:
            print((result/'run.log').read_text(errors='replace')[-7000:], flush=True)
            run.check_returncode()
        files = []
        for name in expected:
            actual = (cvm/name).read_bytes()
            want = (cross/name).read_bytes()
            assert actual == want, (model, cpu, name, len(actual), len(want))
            files.append({'file': name, 'bytes': len(actual), 'sha256': sha(actual)})
        assert (cvm/'UC1.CMD').read_bytes() == tools['UNICC.CMD']
        assert (cvm/'UC2.CMD').read_bytes() == tools['UNICC.CMD']
        log = (result/'run.log').read_text(errors='replace')
        cycles = [int(n) for n in re.findall(r'Finished command: (\d+) reference cycles', log)]
        assert len(cycles) == len(commands)
        stacks = [int(n, 16) for n in re.findall(r'Lowest stack address: ([0-9a-f]+)', log)]
        compiler_end = 0x100 + len(tools['UNICC.CMD'])
        assert min(stacks) > compiler_end, 'tool stack overlaps the rebuilt compiler'
        print('PASS native selfhost:', model, cpu,
              'both generations match UNICC.CMD; CMD and OBJ programs execute', flush=True)
        return {'model': model, 'cpu': cpu, 'files': files,
                'command_cycles': cycles, 'lowest_stack': min(stacks)}

    cases = [('601', 'hd6303')] if args.quick else [
        (model, cpu) for model in ('601', '601a') for cpu in ('mc6800', 'hd6303')]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(native_case, cases))
    report = {'execution': 'native UniDOS, resident HG, HANDLES 16, RAMMAN ROM VM',
              'source': {'file': 'SMALL-C/SMALLC.C', 'bytes': len(sources['SMALLC.C']),
                         'sha256': sha(sources['SMALLC.C'])},
              'tools': {name: sha(data) for name, data in tools.items()},
              'commands': commands, 'cases': results}
    (out/'comparison.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
