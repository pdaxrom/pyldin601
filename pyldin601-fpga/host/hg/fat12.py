"""Flat FAT12 directory volume for UniDOS HG; 512 bytes, 8 sectors/cluster.

The tested UniDOS 32400-sector layout has two 12-sector FATs and 512 root
entries. Its FAT12 ceiling is 4084 data clusters: 32736 total sectors with
57 metadata sectors and fewer than 4085 complete clusters.
"""
import math
import re
import struct

MAX_SECTORS = 32736


def u16(data, offset):return struct.unpack_from('<H',data,offset)[0]
def u32(data, offset):return struct.unpack_from('<I',data,offset)[0]


def disk_info(data):
    if len(data)<512 or len(data)%512 or data[510:512] not in (b'\x55\xaa',b'\xa5\x5a'):
        raise ValueError('invalid FAT12 boot sector/image size')
    bps,spc,reserved,fats=u16(data,11),data[13],u16(data,14),data[16]
    entries,total,spf=u16(data,17),u16(data,19),u16(data,22)
    if bps!=512 or spc not in (1,2,4,8,16,32,64,128) or not 0<reserved<256 or not fats or not entries or not 0<spf<256:
        raise ValueError('BPB is unsupported by the UniDOS block driver')
    if not total or total>len(data)//512:
        raise ValueError('requires the 16-bit BPB sector count within the image')
    overhead=reserved+fats*spf+(entries*32+511)//512
    clusters=(total-overhead)//spc
    if not 1<=clusters<4085 or spf*512<math.ceil((clusters+2)*3/2):
        raise ValueError('expected FAT12 with sufficient FAT space')
    return dict(sectors=total,sectors_per_cluster=spc,clusters=clusters,
                sectors_per_track=u16(data,24),heads=u16(data,26))


def blank_disk(sectors=MAX_SECTORS):
    if not 128<=sectors<=MAX_SECTORS:
        raise ValueError(f'8-sector cluster FAT12 requires 128..{MAX_SECTORS} sectors')
    data=bytearray(sectors*512)
    data[:11]=b'\xeb\x3c\x90UniDOS  '
    struct.pack_into('<HBHBHHBHHHII',data,11,512,8,1,2,512,sectors,0xf8,12,81,2,0,0)
    data[38]=0x29;data[43:54]=b'UniDOS     ';data[54:62]=b'FAT12   '
    data[510:512]=b'\x55\xaa'
    for n in range(2):data[(1+n*12)*512:(1+n*12)*512+3]=b'\xf8\xff\xff'
    disk_info(data)
    return bytes(data)


def fat_get(table,cluster):
    offset=cluster+cluster//2
    value=table[offset]|table[offset+1]<<8
    return value>>4 if cluster&1 else value&4095


def fat_set(table,cluster,value):
    offset=cluster+cluster//2
    old=table[offset]|table[offset+1]<<8
    word=(old&15)|value<<4 if cluster&1 else (old&0xf000)|value
    table[offset:offset+2]=struct.pack('<H',word)


def short_name(name):
    if not re.fullmatch(r'[A-Z0-9_$~!#%&()@^{}-]{1,8}(?:\.[A-Z0-9_$~!#%&()@^{}-]{1,3})?',name):
        raise ValueError(f'expected an uppercase 8.3 file name: {name}')
    base,_,ext=name.partition('.')
    return (base.ljust(8)+ext.ljust(3)).encode('ascii')


def layout(data):
    info=disk_info(data);reserved,fats,spf,entries=u16(data,14),data[16],u16(data,22),u16(data,17)
    start,size=reserved*512,spf*512;root=(reserved+fats*spf)*512
    table=bytearray(data[start:start+size]);payload=root+(entries*32+511)//512*512
    if any(data[start+n*size:start+(n+1)*size]!=table for n in range(1,fats)):
        raise ValueError('FAT copies differ')
    if fat_get(table,0)&255!=data[21] or fat_get(table,1)<0xff8:
        raise ValueError('invalid FAT reserved entries')
    return info,table,start,size,fats,root,entries,payload


def root_files(data):
    info,table,_,_,_,root,entries,payload=layout(data)
    files={};allocated=set();unit=info['sectors_per_cluster']*512
    for pos in range(root,root+entries*32,32):
        entry=data[pos:pos+32]
        if entry[0]==0:break
        if entry[0]==0xe5 or entry[11]&8 or entry[11]==0xf:continue
        if entry[11]&16:raise ValueError('directory mirror supports root files only; use --image for subdirectories')
        name=entry[:8].decode('ascii').rstrip();ext=entry[8:11].decode('ascii').rstrip()
        if ext:name+='.'+ext
        short_name(name)
        if name in files:raise ValueError('duplicate FAT12 root file')
        cluster,length=u16(entry,26),u32(entry,28);contents=bytearray();seen=set()
        while len(contents)<length:
            if cluster in seen or cluster in allocated or not 2<=cluster<info['clusters']+2:
                raise ValueError(f'{name}: invalid FAT chain')
            seen.add(cluster);allocated.add(cluster);offset=payload+(cluster-2)*unit
            contents.extend(data[offset:offset+unit]);cluster=fat_get(table,cluster)
        if length and cluster<0xff8:raise ValueError('missing FAT end marker')
        files[name]=bytes(contents[:length])
    return files


def add_files(data,files):
    info,table,start,size,fats,root,entries,payload=layout(data)
    existing=root_files(data);result=bytearray(data);unit=info['sectors_per_cluster']*512
    slots=[p for p in range(root,root+entries*32,32) if data[p] in (0,0xe5)]
    free=[c for c in range(2,info['clusters']+2) if fat_get(table,c)==0]
    if len(files)>len(slots) or sum((len(b)+unit-1)//unit for b in files.values())>len(free):
        raise ValueError('host files do not fit in FAT12 volume')
    for pos,(name,contents) in zip(slots,files.items()):
        if name in existing:raise ValueError('file already exists')
        count=(len(contents)+unit-1)//unit;chain,free=free[:count],free[count:]
        entry=bytearray(32);entry[:11]=short_name(name);entry[11]=0x20
        struct.pack_into('<H',entry,24,9<<9|1<<5|1)
        struct.pack_into('<HI',entry,26,chain[0] if chain else 0,len(contents))
        result[pos:pos+32]=entry
        for index,cluster in enumerate(chain):
            fat_set(table,cluster,chain[index+1] if index+1<len(chain) else 0xfff)
            offset=payload+(cluster-2)*unit;chunk=contents[index*unit:(index+1)*unit]
            result[offset:offset+unit]=chunk+bytes(unit-len(chunk))
    for n in range(fats):result[start+n*size:start+(n+1)*size]=table
    assert root_files(result)==dict(existing,**files)
    return bytes(result)
