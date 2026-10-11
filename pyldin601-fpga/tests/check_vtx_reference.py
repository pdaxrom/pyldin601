"""Optional real VTX check against libayemu's C LH5 decoder.

Inputs are external reference sources and an original VTX, retained in
ignored build/. Neither decoder nor a converted song is installed for
playback: the HD6303 PGM reads the original VTX itself.
"""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from add_disk_files import install

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--file', required=True, type=Path)
p.add_argument('--decoder', required=True, type=Path)
p.add_argument('--cc', default='cc')
a = p.parse_args()
out = ROOT / 'build/vtx-reference'
out.mkdir(parents=True, exist_ok=True)
data = a.file.read_bytes()
assert data[:2].lower() == b'ay'
stereo, loop, clock, rate, year, size = struct.unpack('<BHI BHI', data[2:16])
assert 0 < size <= 909312 and size % 14 == 0
offset = 16
for _ in range(5):
    offset = data.index(0, offset) + 1
(out / 'packed.bin').write_bytes(data[offset:])
source = out / 'reference.c'
source.write_text('''#include <stdio.h>
#include <stdlib.h>
extern void lh5_decode(unsigned char*,unsigned char*,unsigned long,unsigned long);
int main(int argc,char**argv){
 if(argc!=4)return 2; FILE*f=fopen(argv[1],"rb");if(!f)return 2;
 fseek(f,0,SEEK_END);long packed=ftell(f);rewind(f);
 unsigned long size=strtoul(argv[2],0,10);
 unsigned char*in=malloc(packed),*out=malloc(size);
 if(!in||!out||fread(in,1,packed,f)!=(size_t)packed)return 2;fclose(f);
 lh5_decode(in,out,size,packed);f=fopen(argv[3],"wb");
 if(!f||fwrite(out,1,size,f)!=size||fclose(f))return 2;return 0;
}
''')
decoder = out / 'reference'
subprocess.run([a.cc, '-O2', str(source), str(a.decoder), '-o', str(decoder)], check=True)
subprocess.run([str(decoder), str(out / 'packed.bin'), str(size), str(out / 'original.raw')], check=True)
raw = (out / 'original.raw').read_bytes()
frames = size // 14
(out / 'original.frames').write_bytes(bytes(raw[reg*frames+frame] for frame in range(frames) for reg in range(14)))
image, _ = install((ROOT / 'build/audio/sd-test.img').read_bytes(), {'RITM4.VTX': data}, replace=True)
(out / 'sd-test.img').write_bytes(image)
factor = {1773400: 289, 2000000: 256, 1000000: 512, 1789773: 286}[clock]
for model in ('601', '601a'):
    subprocess.run([str(ROOT / 'build/audio/test_audio_app'), str(out / 'sd-test.img'), model,
                    'ritm4.vtx', str(out / 'original.frames'), str(rate), str(factor), str(loop), '0', '-',
                    str(out / 'original.raw')], cwd=ROOT, check=True)
(out / 'result.json').write_text(json.dumps(dict(size=size, frames=frames, clock=clock, rate=rate,
    stereo=stereo, year=year, loop=loop, models=['601','601a'], decoder=str(a.decoder)), indent=2)+'\n')
