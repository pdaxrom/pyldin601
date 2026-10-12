"""Convert actual CPU bootstrap screen dumps to the SRAM fixture's word format."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for model in ('601', 'a'):
    source = ROOT / 'build' / f'boot-console-{model}.bin'
    data = source.read_bytes()
    assert len(data) == 40 * 24
    source.with_suffix('.mem').write_text(''.join(
        f'{data[n+1]:02x}{data[n]:02x}\n' for n in range(0, len(data), 2)))
