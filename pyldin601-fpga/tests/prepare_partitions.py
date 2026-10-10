"""Native storage scenarios use a copy, with free space for FDISK writes."""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from migrate_sd import prepare
from add_disk_files import install
image,_=prepare((ROOT/'images/sd.img').read_bytes(),add_data=False)
image,_=install(image,{p.name:p.read_bytes() for p in (ROOT/'build/storage').glob('*.PGM')},replace=True)
image+=bytes(106496*512-len(image))
(ROOT/'build/partitions/sd-test.img').write_bytes(image)
