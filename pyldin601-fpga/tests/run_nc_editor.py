"""Exercise NCEDIT on private media, including a FAT12 volume larger than RAM."""
from pathlib import Path
import argparse, json, os, struct, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from make_sd import blank_disk
from sd_partitions import scan
from add_disk_files import add_files
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--cc',default=os.environ.get('CC','cc'))
p.add_argument('--quick',action='store_true')
p.add_argument('--prepare-only',action='store_true')
a=p.parse_args();out=ROOT/'build/nc'
subprocess.run([sys.executable,'tests/run_nc.py','--prepare-only'],cwd=ROOT,check=True)
media=bytearray((out/'sd-test.img').read_bytes())
pb=next(x for x in scan(media) if x.number==3)
# Relocate B after the original partitions in this disposable copy only.
sectors=32400;target_start=(len(media)//512+2047)//2048*2048
struct.pack_into('<II',media,446+2*16+8,target_start,sectors)
media.extend(bytes(((target_start+sectors+1023)//1024*1024)*512-len(media)))
files={n:(out/n).read_bytes() for n in ('NC.PGM','NCMAIN.PGM','NCEDIT.PGM','NCPROBE.PGM','NCGRAF2.PGM','NCGRAF3.PGM')}
files['HELLO.TXT']=b'Pyldin Commander text viewer\r\n'+b'Line of text for paging.\r\n'*100
files['EMPTY.TXT']=b''
# 2 MiB, fixed 64-byte CRLF lines. A unique final line exercises far searches.
files['HUGE.TXT']=(b'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\r\n'*32768)+b'UNIQUE LAST LINE\r\n'
files['LONG.TXT']=b'a'*65530+b'\t'+b'b'*74469+b'\r\ntail'
files['RAW.TXT']=b'A\tB\rC\nD\r\nE\x1aF\x00G'
files.update({f'ZZ{k:03d}.TXT':b'z'*3000 for k in range(180)})
files['EDGE.TXT']=b'x'*511+b'\r\n'+b'y'*510+b'\rZ'
volume=add_files(blank_disk(size=sectors*512),files,replace=True)
media[target_start*512:(target_start+sectors)*512]=volume
(out/'sd-editor.img').write_bytes(media)
# Mark free B clusters allocated in a second private fixture: actual disk-full
# behavior, while editor scratch and Save As can use the separate A volume.
full=bytearray(media);vol=memoryview(full)[target_start*512:(target_start+sectors)*512]
reserved=struct.unpack_from('<H',vol,14)[0];spf=struct.unpack_from('<H',vol,22)[0];roots=struct.unpack_from('<H',vol,17)[0]
clusters=(sectors-reserved-vol[16]*spf-(roots*32+511)//512)//vol[13]
for k in range(2,clusters+2):
 off=k+k//2;value=vol[reserved*512+off]|vol[reserved*512+off+1]<<8
 if (value>>4 if k&1 else value&4095):continue
 for copy in range(vol[16]):
  at=(reserved+copy*spf)*512+off
  if k&1:vol[at]=(vol[at]&15)|0xf0;vol[at+1]=0xff
  else:vol[at]=0xff;vol[at+1]=(vol[at+1]&0xf0)|15
(out/'sd-editor-full.img').write_bytes(full)
# Error paths use separate media; the production files and image stay untouched.
small=dict(files);small.pop('NCEDIT.PGM')
missing=bytearray(media);missing[target_start*512:(target_start+sectors)*512]=add_files(blank_disk(size=sectors*512),small,replace=True)
(out/'sd-editor-missing.img').write_bytes(missing)
broken=bytearray(files['NCEDIT.PGM']);outer=struct.unpack_from('>6H',broken);payload_at=outer[2]+outer[3];broken[payload_at]=0
bad=dict(files);bad['NCEDIT.PGM']=bytes(broken)
bad_media=bytearray(media);bad_media[target_start*512:(target_start+sectors)*512]=add_files(blank_disk(size=sectors*512),bad,replace=True)
(out/'sd-editor-bad.img').write_bytes(bad_media)
if a.prepare_only:sys.exit(0)
runner=out/'test_nc_editor'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_nc_editor.c','-o',str(runner)],cwd=ROOT,check=True)
cases=[('601','mc6800','0','ui'),('601','mc6800','0','missing')] if a.quick else [(m,c,v,'ui') for m in ('601','601a') for c in ('mc6800','hd6303') for v in (('0','3') if m=='601' else ('0','4','2','3'))]
if not a.quick:
 cases += [(m,c,v,'block') for m in ('601','601a') for c in ('mc6800','hd6303') for v in (('0','3') if m=='601' else ('0','4','2','3'))]
 cases += [('601','mc6800','0','block-missing'),('601a','hd6303','2','block-missing')]
 cases += [('601','mc6800','0','bank'),('601','mc6800','0','busy'),('601','mc6800','0','offset'),('601','mc6800','0','missing'),('601a','hd6303','2','missing'),('601a','mc6800','3','missing')]
 cases += [('601','mc6800','0',name) for name in ('large','long','long-missing','raw','edge','empty','keys','block-large','block-large-missing','block-faults','readonly','faults','full','sort-return','missing-editor','bad-editor')]
 cases += [('601a','mc6800','3','block-large'),('601a','mc6800','3','long-missing')]
for model,cpu,video,kind in cases:
 subprocess.run([str(runner),str(out/({'full':'sd-editor-full.img','missing-editor':'sd-editor-missing.img','bad-editor':'sd-editor-bad.img'}.get(kind,'sd-editor.img'))),model,cpu,video,kind],cwd=ROOT,check=True)

if not a.quick:
 for model,cpu,video in [('601','mc6800','0'),('601','hd6303','3'),('601a','mc6800','4'),('601a','hd6303','2')]:
  subprocess.run([str(runner),str(out/'sd-editor.img'),model,cpu,video,'mouse'],cwd=ROOT,check=True)
