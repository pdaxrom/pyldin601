"""Isolated test snippets use the same external UniAS as production firmware."""
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from unias import assemble as run_unias, assembler_path, bios_symbols


def assemble(source, origin=None, size=None):
    # The caller supplies ordinary UniAS source, including its ORG/DS layout.
    # There is no mnemonic translator, instruction encoder or ROM patcher.
    parent = ROOT/'build/fixture-asm'
    parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=parent) as folder:
        out = Path(folder)
        (out/'TEST.ASM').write_text(source+'\n    end\n')
        data = run_unias(assembler_path(), out, 'TEST.ASM', 'TEST.BIN')
        labels = {k.lower(): v for k, v in bios_symbols((out/'TEST.BIN.LST').read_text()).items()}
    if size is not None:
        if len(data) > size:
            raise ValueError('fixture exceeds requested memory image')
        data += bytes([255])*(size-len(data))
    return data, labels
