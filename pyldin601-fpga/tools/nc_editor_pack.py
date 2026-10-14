"""Wrap the editor's ordinary PGM in a native PGM with streamed relocation.

UniDOS reads only the outer header's code extent. The prefix then reads the
appended standard PGM without a large low-memory relocation allocation.
"""
import hashlib, json, struct
from pathlib import Path
out=Path('build/nc')
payload=(out/'NCEDIT.PGM').read_bytes()
(out/'NCEDIT.core.PGM').write_bytes(payload)
loader=(out/'NCELOAD.PGM').read_bytes()
def check(p):
 magic,count,offset,code,entry,bss=struct.unpack_from('>6H',p)
 assert magic==0xa55a and offset==16+count*2 and offset+code==len(p)
 assert entry<code and code+bss<0xbe00
 return code,bss
check(payload);check(loader)
combined=loader+payload
(out/'NCEDIT.PGM').write_bytes(combined)
metadata=json.loads((out/'NCEDIT.json').read_text())
metadata['bytes']=len(combined)
metadata['loader_ram_bytes']=sum(check(loader))
metadata['total_ram_bytes']=metadata['ram_bytes']+metadata['loader_ram_bytes']
metadata['sha256']=hashlib.sha256(combined).hexdigest()
metadata['streamed_relocations']=True
(out/'NCEDIT.json').write_text(json.dumps(metadata,indent=2)+'\n')
