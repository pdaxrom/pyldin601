"""Replay Paint's native UI snapshots on the actual FPGA video pipeline."""
import argparse, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--iverilog',default='iverilog');p.add_argument('--vvp',default='vvp');a=p.parse_args()
out=ROOT/'build/paint'
def memory(path,data):path.write_text(''.join(f'{b:02x}\n' for b in data))
for n,(model,dialog) in enumerate((('601','tools'),('601','exit'),('601a','tools'),('601a','exit'))):
 ram=(out/f'ui-{model}-{dialog}-ram.bin').read_bytes()
 cfg=(out/f'ui-{model}-{dialog}-config.bin').read_bytes()
 assert len(ram)==65536 and len(cfg)==20 and cfg[2+6]==25
 base=int.from_bytes(cfg[18:20],'big');width=640 if cfg[0] else 320
 # The intended bitmap is the oracle; the RTL fetches via the captured CRTC.
 # An unaligned origin therefore reproduces the original on-board failure.
 pixels=bytes(15 if ram[(base+(y//8)*width+(x//8)*8+y%8)&65535]&(128>>(x%8)) else 0 for y in range(200) for x in range(width))
 memory(out/f'dialog-{n}-ram.mem',ram);memory(out/f'dialog-{n}-config.mem',cfg);memory(out/f'dialog-{n}-pixels.mem',pixels)
runner=out/'tb_dialog_video'
subprocess.run([a.iverilog,'-g2012','-s','tb_paint_dialog_video','-o',str(runner),
 *map(str,sorted((ROOT/'rtl').glob('*.v'))),str(ROOT/'tests/pal_viewport_reference.v'),
 str(ROOT/'tests/tb_paint_dialog_video.v')],cwd=ROOT,check=True)
subprocess.run([a.vvp,str(runner)],cwd=ROOT,check=True)
