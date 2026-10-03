"""Make integration fixtures from a real native ROM set; no third-party tools."""
import importlib.util
from pathlib import Path
import struct
import sys
import zlib

project=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('make_sd',project/'tools/make_sd.py')
sd=importlib.util.module_from_spec(spec);spec.loader.exec_module(sd)
native=Path(sys.argv[1]);output=Path(sys.argv[2]);output.mkdir(exist_ok=True,parents=True)
disk=sd.blank_disk()
image,_=sd.build(native,[disk,disk]);output.joinpath('test-sd.img').write_bytes(image)
partition=2048*512
reserved=sd.u16(image,partition+14);spf=sd.u16(image,partition+22)
root=partition+(reserved+image[partition+16]*spf)*512
data=root+sd.u16(image,partition+17)*32
entry=next(p for p in range(root,data,32) if image[p:p+11]==b'P601    ROM')
cluster=sd.u16(image,entry+26);size=sd.u32(image,entry+28)
fat=partition+reserved*512
chain=[];payload=bytearray()
while len(payload)<size:
    chain.append(cluster);offset=data+(cluster-2)*512
    payload+=image[offset:offset+512];cluster=sd.u16(image,fat+cluster*2)
payload=bytes(payload[:size]);output.joinpath('rom.reference').write_bytes(payload)
output.joinpath('rom-payload.mem').write_text(''.join(f'{v:02x}\n' for v in payload[512:]))
fragmented=bytearray(image)
new_chain=[cluster if index%2==0 else 4096+index for index,cluster in enumerate(chain)]
for index,cluster in enumerate(new_chain):
    position=data+(cluster-2)*512
    block=payload[index*512:(index+1)*512]
    fragmented[position:position+len(block)]=block
    for copy in range(2):
        struct.pack_into('<H',fragmented,fat+copy*spf*512+cluster*2,
                         new_chain[index+1] if index+1<len(new_chain) else 0xffff)
output.joinpath('fragmented.img').write_bytes(fragmented)
corrupt=bytearray(image);corrupt[data+(chain[1]-2)*512+17]^=1
output.joinpath('corrupt-rom.img').write_bytes(corrupt)
short=bytearray(image)
for copy in range(2):struct.pack_into('<H',short,fat+copy*spf*512+chain[0]*2,0xffff)
output.joinpath('short-chain.img').write_bytes(short)
output.joinpath('boot-config.mem').write_text(''.join(f'{v:02x}\n' for v in payload[:64]+image[462:494]))
print('Prepared classic, fragmented, CRC-corrupt and truncated FAT-chain fixtures')

# Preserve classic fixtures and also exercise both BIOS choices on one SD.
a_image,_=sd.build(native,[disk,disk],bios_a=project.parent/'native-src/BIOS_A.ROM')
output.joinpath('models-sd.img').write_bytes(a_image)
a_entry=next(p for p in range(root,data,32) if a_image[p:p+11]==b'P601A   ROM')
a_cluster=sd.u16(a_image,a_entry+26);a_size=sd.u32(a_image,a_entry+28)
a_offset=data+(a_cluster-2)*512
output.joinpath('rom-a.reference').write_bytes(a_image[a_offset:a_offset+a_size])
output.joinpath('rom-a-payload.mem').write_text(''.join(f'{v:02x}\n' for v in a_image[a_offset+512:a_offset+a_size]))
wrong=bytearray(a_image);wrong[a_offset+25]=0
struct.pack_into('<I',wrong,a_offset+508,zlib.crc32(wrong[a_offset:a_offset+508]))
output.joinpath('wrong-model.img').write_bytes(wrong)
missing=bytearray(a_image);missing[a_entry]=0xe5
output.joinpath('missing-model.img').write_bytes(missing)
