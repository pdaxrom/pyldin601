"""Run UART.PGM under the actual native BIOS and UniDOS on private media."""
from pathlib import Path
import argparse,subprocess,sys,json
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from add_disk_files import install
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cc',default='cc');p.add_argument('--quick',action='store_true');a=p.parse_args()
out=ROOT/'build/input';sd,metadata=install((ROOT/'images/sd.img').read_bytes(),{'UART.PGM':(out/'UART.PGM').read_bytes()},replace=True)
(out/'uart-sd.img').write_bytes(sd);(out/'uart-sd.json').write_text(json.dumps(metadata,indent=2)+'\n')
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_uart_app.c','-o',str(out/'test_uart_app')],cwd=ROOT,check=True)
for model in ('601','601a'):
 for cpu in ('mc6800','hd6303'):
  for rate in (['default','115200','bad','missing'] if a.quick else ['default','150','300','600','1200','2400','4800','9600','19200','38400','57600','115200','bad','missing']):
   subprocess.run([str(out/'test_uart_app'),str(out/'uart-sd.img'),model,cpu,rate],cwd=ROOT,check=True)
