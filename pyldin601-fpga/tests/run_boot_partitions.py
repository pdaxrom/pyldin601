"""Partition policy on real assembled ROMs and native MC6800/HD6303."""
from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import sd_partitions as p
image=(ROOT/'build/partitions/sd-test.img').read_bytes()
work=ROOT/'build/boot-partitions';work.mkdir(exist_ok=True)
def case(name,data,explicit,expected):
 path=work/(name+'.img');path.write_bytes(data)
 for model,cpu in [('601','mc6800'),('601','hd6303'),('601a','mc6800'),('601a','hd6303')]:
  r=subprocess.run(['build/test_boot_partitions',str(path),model,cpu,str(explicit)],cwd=ROOT,text=True,capture_output=True,check=True)
  assert f'mapped={expected} ' in r.stdout,(name,r.stdout,r.stderr)
 print(f'PASS boot {name}: explicit={explicit}, partition={expected}',flush=True)
case('legacy-fallback',image,0,2)
case('explicit-primary',image,4,4)
case('explicit-nonfat',image,1,0)
active=bytearray(image);active[478]=128
case('active-primary',active,0,3)
active[478]=0;active[446]=128
case('active-fat16-fallback',active,0,2)
active[446]=0;active[34816*512+13]=0
case('bad-A-fallback-B',active,0,3)
logical=bytearray(image);p.put_entry(logical,0,3,15,40960,65536)
logical[40960*512:40960*512+512]=bytes(512);logical[40960*512+510:40960*512+512]=b'\x55\xaa'
p.put_entry(logical,40960,0,1,2048,16000)
v=bytearray(p.fat12());v[19:21]=(16000).to_bytes(2,'little');logical[43008*512:59008*512]=v[:16000*512]
case('explicit-logical',logical,5,5)
logical[40960*512+446]=128
case('active-logical',logical,0,5)
