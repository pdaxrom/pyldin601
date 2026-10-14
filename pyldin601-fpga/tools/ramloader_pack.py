"""Append a standard, relocatable CLI PGM to ramloader's resident prefix."""
import hashlib
import json
import re
from pathlib import Path
import struct

out = Path('build/ramloader')
prefix = (out/'RAMLOAD.prefix.PGM').read_bytes()
core = (out/'RAMCORE.PGM').read_bytes()
for pgm in (prefix, core):
    magic, count, offset, code, entry, bss = struct.unpack_from('>6H', pgm)
    assert magic == 0xa55a and offset == 16+count*2
    assert offset+code == len(pgm) and entry < code and code+bss < 0xbe00
assert struct.unpack_from('>H', core, 8)[0] == 0
combined = prefix+core
(out/'RAMLOAD.PGM').write_bytes(combined)
meta = json.loads((out/'RAMLOAD.json').read_text())
symbols={name:int(value,16) for name,value in re.findall(r'^([A-Z_][A-Z0-9_]*) =\$([0-9A-F]+)$',(out/'RAMLOAD.LST').read_text(),re.M)}
core_meta=json.loads((out/'RAMCORE.json').read_text())
roms={}
for name in ('CRC16.ROM','CRCALT.ROM'):
    data=(out/name).read_bytes()
    assert len(data)==8192 and sum(data)%256==0
    roms[name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
(out/'roms.json').write_text(json.dumps(roms,indent=2)+'\n')
meta.update(resident_payload_bytes=symbols['BSS_END']-symbols['RESIDENT_START'],
            working_ram_bytes=meta['ram_bytes']+core_meta['ram_bytes'],
            module_slots=4, exports_per_module=8, bytes=len(combined), sha256=hashlib.sha256(combined).hexdigest(),
            streamed_relocations=True)
(out/'RAMLOAD.json').write_text(json.dumps(meta, indent=2)+'\n')
