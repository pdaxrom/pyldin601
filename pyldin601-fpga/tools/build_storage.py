#!/usr/bin/env python3
"""Build native relocatable storage utilities using the real UniAS."""
import argparse,json,shutil,struct
from pathlib import Path
from build_partitions import assemble
ROOT=Path(__file__).resolve().parents[1]
def build(unias):
 unias=shutil.which(unias) or str(Path(unias).resolve())
 out=ROOT/'build/storage';out.mkdir(parents=True,exist_ok=True)
 for p in (ROOT/'firmware/storage').glob('*'):shutil.copyfile(p,out/p.name)
 programs={}
 for name,src,defines in [('MOUNT','MOUNT.ASM',()),('FORMAT','MOUNT.ASM',('-D','FORMAT_TOOL')),('UMOUNT','UMOUNT.ASM',()),('FDISK','FDISK.ASM',())]:
  data=assemble(unias,out,src,name+'.PGM',defines)
  magic,count,offset,length,entry,bss,_,_=struct.unpack('>8H',data[:16])
  if magic!=0xa55a or offset!=16+2*count or len(data)!=offset+length or entry>=length:raise ValueError('invalid PGM '+name)
  programs[name]=dict(bytes=len(data),code=length,relocations=count)
 (out/'manifest.json').write_text(json.dumps(programs,indent=2)+'\n')
 print(programs)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--unias',required=True);build(p.parse_args().unias)
