"""Shorten only the diagnostic's range for a real HDL CPU smoke test.

Production SRAM diagnostic tests 2038 KiB; this simulation checks its CPU/bus
path on 256 bytes with all five patterns and an optional injected failure.
"""
from pathlib import Path
import shutil
import sys
root = Path(__file__).parents[1]
sys.path.insert(0,str(root/'tools'))
from unias import assemble, assembler_path
out=root/'build/sram-diagnostic'
out.mkdir(parents=True,exist_ok=True)
shutil.copyfile(root/'firmware/sram_test.asm',out/'SRAM.ASM')
binary=assemble(assembler_path(),out,'SRAM.ASM','SMOKE.BIN',('-D','SRAM_SMOKE'))
assert len(binary)==4096
(root / "build/sram-smoke.mem").write_text("".join(f"{b:02x}\n" for b in binary))
