"""Exercise delayed SD power-up, transient responses and bounded init failures."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
work = root / 'build/sd-init-tests'
work.mkdir(exist_ok=True)
original = (root / 'build/models-sd.img').read_bytes()
cases = (
    'init-late-power', 'init-cmd0-retry', 'init-cmd8-retry', 'init-app-retry',
    'init-long-idle', 'init-sdsc-idle', 'init-last-r1', 'init-cmd0-timeout',
    'init-acmd-timeout', 'init-bad-r7', 'init-no-tick',
    'init-reload',
)
for case in cases:
    output = work / f'{case}.img'
    result = subprocess.run(
        ['build/test_firmware', 'build/boot.bin', 'build/models-sd.img', case, str(output)],
        cwd=root, text=True, capture_output=True,
    )
    (work / f'{case}.log').write_text(result.stdout + result.stderr)
    if result.returncode:
        raise AssertionError(f'{case}: {result.stdout}{result.stderr}')
    rejected = case in ('init-cmd0-timeout', 'init-acmd-timeout', 'init-bad-r7', 'init-no-tick')
    if rejected:
        assert 'BOOT ERROR AT STEP 01' in result.stdout, case
        assert not output.exists(), case
    else:
        assert 'PASS selectable CPU software SD/FAT boot' in result.stdout, case
        assert output.read_bytes() == original, case
        if case == 'init-reload':
            assert 'PASS full reset reinitializes powered SD' in result.stdout, case
    print(f'PASS SD initialization {case}: {result.stdout.strip()}', flush=True)
print('PASS all twelve SD initialization cases; boot files and A/B preserved')
