"""PGM/native DOS regression plus actual FTDI pins, CPU, IRQ and video HDL."""
import argparse
import hashlib
from pathlib import Path
import struct
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(root/'tools'),str(root/'host/hg')]
import add_disk_files
import fat12
import make_sd


def run(*command):
    subprocess.run(command,cwd=root,check=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--hdl',action='store_true')
    parser.add_argument('--nvc',default='nvc')
    parser.add_argument('--cc',default='cc')
    parser.add_argument('--models', nargs='+', choices=('601','601a'), default=('601','601a'))
    parser.add_argument('--speeds', nargs='+', type=int, choices=(0,1,2,3), default=(0,1,2,3))
    parser.add_argument('--isa', type=int, choices=(0,1), default=0, help='HDL CPU extension 0=MC6800, 1=HD6303')
    args=parser.parse_args()
    image=bytearray((root/'images/sd.img').read_bytes())
    start,count=struct.unpack_from('<II',image,486)
    programs={name:(root/'build/hg'/name).read_bytes() for name in ('HG.PGM','HGTIME.PGM')}
    image[start*512:(start+count)*512]=add_disk_files.add_files(make_sd.blank_disk(count*512),programs)
    test_image=root/'build/sd-hg.img';test_image.write_bytes(image)
    text=b'Hello from the host HG disk\r\n'*100
    host_image=root/'build/hg-host.img'
    data=bytearray(fat12.add_files(fat12.blank_disk(),{'HELLO.TXT':text}))
    info,table,start_fat,fat_size,copies,root_start,entries,payload_start=fat12.layout(data)
    last_cluster=info['clusters']+1
    fat12.fat_set(table,last_cluster,0xfff)
    entry=bytearray(32);entry[:11]=b'LAST    TXT';entry[11]=0x20
    struct.pack_into('<H',entry,24,9<<9|1<<5|1)
    tail=b'Last FAT12 data cluster\r\n'
    struct.pack_into('<HI',entry,26,last_cluster,len(tail))
    data[root_start+32:root_start+64]=entry
    at=payload_start+(last_cluster-2)*4096;data[at:at+len(tail)]=tail
    for copy in range(copies):data[start_fat+copy*fat_size:start_fat+(copy+1)*fat_size]=table
    host_image.write_bytes(data)
    run(args.cc,'-O2','-I../pyldin601/src','tests/test_hg_unidos.c','host/hg/fat12.c','-o','build/test_hg_unidos')
    for model in args.models:
        for wire in (1,2):
            run('build/test_hg_unidos',str(test_image),str(host_image),model, *(() if wire == 1 else ('v2',)))
            remote=fat12.root_files((root/'build/hg-host-after.img').read_bytes())
            local=(root/'build/hg-sd-after.img').read_bytes();a_start,a_count=struct.unpack_from('<II',local,470)
            a_files=add_disk_files.root_files(local[a_start*512:(a_start+a_count)*512])
            assert remote['HELLO.TXT']==remote['BACK.TXT']==a_files['HGTEST.TXT']==text
            assert 'TEMP.TXT' not in remote
            assert a_files['LIVE.TXT']==b'First host update\r\n'
            assert a_files['LIVEB.TXT']==remote['LIVE.TXT']==b'Second host update\r\n'*500
            assert a_files['LAST.TXT']==remote['LAST.TXT']==tail
            print(f'PASS {model}/HG v{wire} byte-identical E->A->E copy and TEMP deletion; SHA256 {hashlib.sha256(text).hexdigest()}')
        if not args.hdl:continue
        run(sys.executable,'tests/prepare_hg_hdl.py')
        work=f'work:build/hg-bios-{model}'
        rtl=[str(p.relative_to(root)) for p in sorted((root/'rtl').glob('*.v'))]
        run(args.nvc,'--std=2008',f'--work={work}','--ieee-warnings=off','-a',
            'rtl/cpu6800.vhd',*rtl,'tests/fast_clock.v','tests/tb_hg_bios.v','tests/tb_hg_bios.vhd')
        for speed in args.speeds:
            run(sys.executable,'tests/prepare_runtime.py','--prefix','hgdisk','--speed',str(speed))
            log=root/f'build/hg-bios-{model}-{speed}-isa{args.isa}.log'
            with log.open('w') as out:
                subprocess.run([args.nvc,'--std=2008',f'--work={work}','--ieee-warnings=off',
                    '-e','-j',f'-gSPEED={speed}',f'-gISA={args.isa}','tb_hg_bios','-r','tb_hg_bios'],cwd=root,
                    stdout=out,stderr=subprocess.STDOUT,check=True)
            result=log.read_text();print(result)
            assert 'PASS actual HDL CPU/native resident HG.PGM' in result


if __name__=='__main__':main()
