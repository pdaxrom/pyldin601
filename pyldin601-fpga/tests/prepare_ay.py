"""Install the UniAS AY PGM in a private native UniDOS SD fixture."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
import add_disk_files as fat12
image=(root/'images/sd.img').read_bytes()
result,_=fat12.install(image,{'AY.PGM':(root/'build/gfx/AY.PGM').read_bytes()},replace=True)
work=root/'build/ay'
work.mkdir(parents=True,exist_ok=True)
(work/'sd.img').write_bytes(result)
