"""Protect legacy GD graphics/heap compatibility after replacing ROM/RAM disks."""
import argparse
from pathlib import Path
import struct
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'host/hg')]
import add_disk_files,make_sd
import fat12
from migrate_sd import prepare

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cc',default='cc');args=p.parse_args()
    image,_=prepare((ROOT/'images/sd.img').read_bytes(),add_data=False)
    image=bytearray(image);start,count=struct.unpack_from('<II',image,486)
    programs={'HG.PGM':(ROOT/'build/hg/HG.PGM').read_bytes(),'GD.CMD':(ROOT/'build/romdisk-extracted/unpacked/GD.CMD').read_bytes()}
    image[start*512:(start+count)*512]=add_disk_files.add_files(make_sd.blank_disk(count*512),programs)
    path=ROOT/'build/storage-gd.img';path.write_bytes(image)
    (ROOT/'build/storage-gd-host.img').write_bytes(fat12.blank_disk())
    for legacy in (True,False):
        runner=ROOT/('build/test_storage_gd'+('-legacy' if legacy else ''))
        subprocess.run([args.cc,'-O2','-I../pyldin601/src',*(['-DLEGACY_FIXTURE'] if legacy else []),'tests/test_storage_gd.c','host/hg/fat12.c','-o',str(runner)],cwd=ROOT,check=True)
        for model in ('601','601a'):
            for cpu in ('mc6800','hd6303'):
                golden=ROOT/f'build/storage-gd-{model}-{cpu}.bin'
                subprocess.run([str(runner),str(path),model,cpu,str(golden)],cwd=ROOT,check=True)
if __name__=='__main__':main()
