#!/usr/bin/env python3
"""Add root 8.3 files to a FAT12 A/B partition in a new regular SD image.

Existing files, geometry, MBR and all other partitions remain byte-for-byte
unchanged. Refuse duplicate names, conflicting FAT copies and full volumes.
Never open a block device or overwrite the input/output image.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import struct

import make_sd as sd


def fat_get(table, cluster):
    offset = cluster + cluster // 2
    value = table[offset] | table[offset+1] << 8
    return value >> 4 if cluster & 1 else value & 0xfff


def fat_set(table, cluster, value):
    offset = cluster + cluster // 2
    original = table[offset] | table[offset+1] << 8
    combined = (original & 0xf) | value << 4 if cluster & 1 else (original & 0xf000) | value
    table[offset], table[offset+1] = combined & 255, combined >> 8


def short_name(name):
    if not re.fullmatch(r'[A-Z0-9_]{1,8}\.[A-Z0-9_]{1,3}', name):
        raise ValueError(f'not an uppercase 8.3 name: {name}')
    base, ext = name.split('.')
    return (base.ljust(8)+ext.ljust(3)).encode('ascii')


def layout(volume):
    info = sd.disk_info(volume)
    reserved, copies, spf, entries = sd.u16(volume,14), volume[16], sd.u16(volume,22), sd.u16(volume,17)
    fat_start, fat_size = reserved*512, spf*512
    root_start = (reserved+copies*spf)*512
    data_start = root_start + ((entries*32+511)//512)*512
    table = bytearray(volume[fat_start:fat_start+fat_size])
    for copy in range(1,copies):
        if volume[fat_start+copy*fat_size:fat_start+(copy+1)*fat_size] != table:
            raise ValueError('FAT copies differ')
    if fat_get(table,0)&255 != volume[21] or fat_get(table,1)<0xff8:
        raise ValueError('invalid FAT12 reserved entries')
    return info, table, fat_start, fat_size, copies, root_start, entries, data_start


def root_files(volume):
    info, table, _, _, _, root, entries, data_start = layout(volume)
    unit = info['sectors_per_cluster']*512
    files = {}
    for pos in range(root,root+entries*32,32):
        entry=volume[pos:pos+32]
        if entry[0]==0:break
        if entry[0]==0xe5 or entry[11]&0x18 or entry[11]==0x0f:continue
        name=entry[:8].decode('ascii').rstrip()+'.'+entry[8:11].decode('ascii').rstrip()
        cluster, length = sd.u16(entry,26),sd.u32(entry,28)
        data, seen = bytearray(),set()
        while len(data)<length:
            if cluster in seen or not 2<=cluster<info['clusters']+2:
                raise ValueError(f'{name}: invalid FAT chain')
            seen.add(cluster)
            start=data_start+(cluster-2)*unit
            data+=volume[start:start+unit]
            cluster=fat_get(table,cluster)
        if length and cluster<0xff8:raise ValueError(f'{name}: missing FAT end marker')
        files[name]=bytes(data[:length])
    return files


def add_files(volume, files):
    info, table, fat_start, fat_size, copies, root, entries, data_start = layout(volume)
    result=bytearray(volume)
    unit=info['sectors_per_cluster']*512
    occupied={bytes(volume[p:p+11]) for p in range(root,root+entries*32,32) if volume[p] not in (0,0xe5)}
    slots=[p for p in range(root,root+entries*32,32) if volume[p] in (0,0xe5)]
    free=[n for n in range(2,info['clusters']+2) if fat_get(table,n)==0]
    needed=sum((len(data)+unit-1)//unit for data in files.values())
    if len(files)>len(slots) or needed>len(free):raise ValueError('disk/root directory full')
    for name in files:
        if short_name(name) in occupied:raise ValueError(f'file already exists: {name}')
    original_files=root_files(volume)
    for pos,(name,data) in zip(slots,files.items()):
        count=(len(data)+unit-1)//unit
        chain, free=free[:count],free[count:]
        entry=bytearray(32)
        entry[:11]=short_name(name);entry[11]=0x20
        struct.pack_into('<H',entry,24,(1989-1980)<<9|1<<5|1)
        struct.pack_into('<H',entry,26,chain[0] if chain else 0)
        struct.pack_into('<I',entry,28,len(data))
        result[pos:pos+32]=entry
        for index,cluster in enumerate(chain):
            fat_set(table,cluster,chain[index+1] if index+1<len(chain) else 0xfff)
            start=data_start+(cluster-2)*unit
            chunk=data[index*unit:(index+1)*unit]
            result[start:start+unit]=chunk+b'\0'*(unit-len(chunk))
    for copy in range(copies):
        start=fat_start+copy*fat_size;result[start:start+fat_size]=table
    extracted=root_files(result)
    assert all(extracted[name]==data for name,data in files.items())
    assert all(extracted[name]==data for name,data in original_files.items())
    assert result[:512]==volume[:512] and sd.disk_info(result)==info
    return bytes(result)


def install(image, files, drive='B'):
    if image[510:512]!=b'\x55\xaa':raise ValueError('missing MBR')
    parts=[]
    for index in range(3):
        entry=446+16*index
        start,length=sd.u32(image,entry+8)*512,sd.u32(image,entry+12)*512
        if not length or start<512 or start+length>len(image):raise ValueError('partition outside SD backup')
        parts.append((start,start+length))
    if any(max(a,c)<min(b,d) for n,(a,b) in enumerate(parts) for c,d in parts[n+1:]):
        raise ValueError('overlapping partitions')
    index=1 if drive=='A' else 2
    if image[446+index*16+4]!=1:raise ValueError('expected FAT12 data partition')
    start,end=parts[index]
    result=bytearray(image)
    result[start:end]=add_files(image[start:end],files)
    assert result[:start]==image[:start] and result[end:]==image[end:]
    metadata=dict(drive=drive,start_lba=start//512,sectors=(end-start)//512,
        input_sha256=hashlib.sha256(image).hexdigest(),output_sha256=hashlib.sha256(result).hexdigest(),
        mbr_and_other_partitions_preserved=True,
        files={name:dict(bytes=len(data),sha256=hashlib.sha256(data).hexdigest()) for name,data in files.items()})
    return bytes(result),metadata


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image',type=Path,required=True)
    parser.add_argument('--drive',choices=('A','B'),default='B')
    parser.add_argument('--files',type=Path,nargs='+',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if not stat.S_ISREG(args.image.stat().st_mode):raise ValueError('input must be a regular SD image')
    paths=[]
    for path in args.files:
        paths.extend(sorted(p for p in path.iterdir() if p.suffix in ('.CMD','.ASM','.TXT'))) if path.is_dir() else paths.append(path)
    files={}
    for path in paths:
        if not stat.S_ISREG(path.stat().st_mode):raise ValueError('source must be a regular file')
        if path.name in files:raise ValueError('duplicate source name')
        files[path.name]=path.read_bytes()
    if not files:raise ValueError('no files supplied')
    result,metadata=install(args.image.read_bytes(),files,args.drive)
    with args.output.open('xb') as out:out.write(result)
    args.output.with_suffix('.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(f'Added {len(files)} files to {args.drive}: {args.output}; MBR/other partitions preserved')


if __name__=='__main__':main()
