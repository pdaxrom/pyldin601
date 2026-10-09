"""Bounded IFF ILBM fixtures and a private UniDOS disk for the real HVIEW PGM."""
from pathlib import Path
import struct
import sys
from ham8_format import form, chunks, decode
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
import add_disk_files
import make_pal


def prepare():
    work=root/'build/hview';work.mkdir(parents=True,exist_ok=True)
    bmhd=struct.pack('>HHhhBBBBHBBhh',320,200,0,0,8,0,1,0,0,1,1,320,200)
    cmap=bytes(v for n in range(64) for v in ((n>>4)*85,((n>>2)&3)*85,(n&3)*85))
    headers=[(b'BMHD',bmhd),(b'CAMG',b'\0\0\x08\0'),(b'CMAP',cmap)]
    # Row-constant, varying HAM commands exercise all eight bitplanes.
    codes=bytes((y*73)&255 for y in range(200) for x in range(320))
    body=b''.join(bytes((128,217,255 if codes[y*320]&(1<<b) else 0)) for y in range(200) for b in range(8))
    good=form(headers+[(b'BODY',body)])
    raw=b''.join(bytes([255 if codes[y*320]&(1<<b) else 0])*40 for y in range(200) for b in range(8))
    cases={'RUNS':good,'FULL':form([(b'ANNO',bytes(65537)),(b'BMHD',bmhd[:10]+b'\0'+bmhd[11:]),*headers[1:],(b'BODY',raw)]),
           'ORDER':form([headers[2],(b'ANNO',b'odd'),headers[1],headers[0],(b'BODY',body+b'\x80'),(b'JUNK',b'x')])}
    for name,data in cases.items():
        assert decode(data)==codes
        (work/f'{name}.codes').write_bytes(codes)
    pixels=bytes((x*29+y*73)&255 for y in range(200) for x in range(320))
    planes=b''.join(bytes([39])+bytes(sum(((pixels[y*320+x+i]>>b)&1)<<(7-i) for i in range(8)) for x in range(0,320,8)) for y in range(200) for b in range(8))
    cases['COLOUR']=form(headers+[(b'BODY',planes)])
    assert decode(cases['COLOUR'])==pixels
    (work/'COLOUR.codes').write_bytes(pixels)
    lena=root/'build/ham-view/LENA.IFF'
    if lena.exists():cases['LENA']=lena.read_bytes();(work/'LENA.codes').write_bytes(decode(cases['LENA']))
    for name,at,v in [('WIDTH',0,0),('HEIGHT',3,201),('PLANES',8,6),('MASK',9,1),('PACK',10,2)]:
        bad=bytearray(bmhd);bad[at]=v;cases[name]=form([(b'BMHD',bytes(bad)),*headers[1:],(b'BODY',body)])
    cases['CMAP']=form(headers[:2]+[(b'CMAP',bytes(192)),(b'BODY',body)])
    cases['MODE']=form([headers[0],(b'CAMG',b'\0\0\0\0'),headers[2],(b'BODY',body)])
    cases['DUP']=form(headers+[headers[0],(b'BODY',body)])
    cases['EARLY']=form([(b'BODY',body)]+headers)
    cases['CROSS']=form(headers+[(b'BODY',b'\xd8\x00'+body)]) # 41 output bytes > plane row
    cases['CUT']=form(headers+[(b'BODY',b'\xd9')])
    cases['LITERAL']=form(headers+[(b'BODY',b'\x27'+bytes(39))])
    cases['TAIL']=form(headers+[(b'BODY',body+b'\x00')])
    cases['MISSING']=form(headers)
    cases['FORM']=b'BAD!'+good[4:]
    cases['SIZE']=good[:4]+b'\xff'*4+good[8:]
    cases['SHORT']=good[:9]
    cases['TRUNC']=good[:-1]
    cases['WRAP']=form(headers)+b'JUNK\xff\xff\xff\xff';cases['WRAP']=cases['WRAP'][:4]+struct.pack('>I',len(cases['WRAP'])-8)+cases['WRAP'][8:]
    cases['ODDPAD']=form(headers)+b'JUNK\0\0\0\x01x';cases['ODDPAD']=cases['ODDPAD'][:4]+struct.pack('>I',len(cases['ODDPAD'])-8)+cases['ODDPAD'][8:]
    for name,data in cases.items():(work/f'{name}.IFF').write_bytes(data)
    (work/'components.bin').write_bytes(bytes(make_pal.ham_samples()))
    image,info=add_disk_files.install((root/'images/sd.img').read_bytes(),{'HVIEW.PGM':(root/'build/gfx/HVIEW.PGM').read_bytes(),**{k+'.IFF':v for k,v in cases.items()}},replace=True)
    (work/'sd.img').write_bytes(image)
    print(f'Prepared {len(cases)} IFF cases: raw/ByteRun1/NOP/odd unknown chunks/32-bit size and malformed headers/palette/RLE')

if __name__=='__main__':prepare()
