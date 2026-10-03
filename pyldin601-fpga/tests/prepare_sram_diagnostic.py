"""Shorten only the diagnostic's range for a real HDL CPU smoke test.

Production SRAM diagnostic tests 2038 KiB; this simulation checks its CPU/bus
path on 256 bytes with all five patterns and an optional injected failure.
"""
from pathlib import Path
import importlib.util
root = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location("asm", root / "tools/asm6800.py")
asm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(asm)
source = (root / "firmware/sram_test.asm").read_text()
source = source.replace("LIMIT_HIGH equ $20", "LIMIT_HIGH equ 0")
source = source.replace("LIMIT_MID equ 0", "LIMIT_MID equ $21")
binary, _ = asm.assemble(source, 0xf000, 4096)
(root / "build/sram-smoke.mem").write_text("".join(f"{b:02x}\n" for b in binary))
