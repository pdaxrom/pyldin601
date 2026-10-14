"""Exercise assembled ramloader and banked ROMs on disposable SD media."""
import argparse
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from add_disk_files import install, add_files
from sd_partitions import scan
from unias import assemble, assembler_path
import shutil
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--cc', default='cc')
p.add_argument('--unias')
p.add_argument('--quick', action='store_true')
p.add_argument('--prepare-only', action='store_true')
a = p.parse_args()
out = ROOT/'build/ramloader'
files = {s: (out/s).read_bytes() for s in ('RAMLOAD.PGM','CRC16.ROM','CRCALT.ROM','RAMCHECK.PGM')}
rom = files['CRC16.ROM']
assert len(rom) == 8192 and sum(rom)%256 == 0
files['SHORT.ROM'] = rom[:-1]
bad = bytearray(rom); bad[700] ^= 1; files['BADSUM.ROM'] = bad
for name, offset, value in [('BADVEC.ROM',16,0x23),('BADADDR.ROM',17,0xf0),('BADINIT.ROM',10,0x39)]:
    bad = bytearray(rom); bad[offset] = value; bad[-1] = (bad[-1]-sum(bad)) & 255
    files[name] = bytes(bad)
files['DUPNAME.ROM'] = rom
for filename, name, vector in [('THIRD.ROM',b'THIRD   ',0xef),('FOURTH.ROM',b'FOURTH  ',0xf0),('FIFTH.ROM',b'FIFTH   ',0xf1),('LOWER.ROM',b'crclow  ',0xef)]:
    data=bytearray(rom);data[2:10]=name;data[16]=vector;data[-1]=(data[-1]-sum(data))&255
    files[filename]=bytes(data)
data=bytearray(rom);data[16]=0xe8;data[-1]=(data[-1]-sum(data))&255;files['TAKEN.ROM']=bytes(data)
data=bytearray(rom);data[19:22]=data[16:19];data[22]=0;data[-1]=(data[-1]-sum(data))&255;files['DUPVEC.ROM']=bytes(data)
shutil.copyfile(ROOT/'tests/ramloader_nested.asm',out/'RAMNEST.ASM')
files['RAMNEST.PGM']=assemble(assembler_path(a.unias),out,'RAMNEST.ASM','RAMNEST.PGM')
files['FAILINIT.ROM']=assemble(assembler_path(a.unias),out,'CRC16.ASM','FAILINIT.ROM',('-D','INIT_FAIL'))
for name, ids in [('TOOMANY.ROM',list(range(0x80,0x89))),('NOENTRY.ROM',[]),('IRQ.ROM',[0xe4])]:
    data=bytearray(rom)
    for k,vector in enumerate(ids): data[16+k*3:19+k*3]=bytes([vector])+rom[17:19]
    data[16+3*len(ids)]=0;data[-1]=(data[-1]-sum(data))&255;files[name]=bytes(data)
ready, metadata = install((ROOT/'images/sd.img').read_bytes(), files, replace=True)
(out/'sd-test.img').write_bytes(ready)
# Also exercise the source-built ROM shell instead of the disk UniDOS 3.20.
rom_shell=bytearray(ready)
pa=next(x for x in scan(rom_shell) if x.number==2)
start,end=pa.start*512,(pa.start+pa.sectors)*512
rom_shell[start:end]=add_files(rom_shell[start:end],{'UNIDOS.CMD':(ROOT/'build/partitions/SHELL.CMD').read_bytes()},replace=True)
(out/'sd-rom-shell.img').write_bytes(rom_shell)
if a.prepare_only:
    sys.exit(0)
runner = out/'test_ramloader'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_ramloader.c','-o',str(runner)],cwd=ROOT,check=True)
cases = [('601','mc6800','normal')] if a.quick else [(m,c,s) for m in ('601','601a') for c in ('mc6800','hd6303') for s in ('normal','offset','last','full','missing')]
for model, cpu, scenario in cases:
    subprocess.run([str(runner),str(out/'sd-test.img'),model,cpu,scenario],cwd=ROOT,check=True)
if not a.quick:
    for model in ('601','601a'):
        for cpu in ('mc6800','hd6303'):
            subprocess.run([str(runner),str(out/'sd-rom-shell.img'),model,cpu,'normal'],cwd=ROOT,check=True)
