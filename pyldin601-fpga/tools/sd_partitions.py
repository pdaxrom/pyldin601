#!/usr/bin/env python3
"""Checked MBR/EBR access and the supported UniDOS FAT12 format.

Partition numbers are 1..4 for primary entries and 5 upwards in EBR order.
This module operates on regular images; it never opens a physical device.
"""
from dataclasses import dataclass
import struct
import time

SECTOR = 512
TOTAL = 32400
EXTENDED = (0x05, 0x0f, 0x85)

@dataclass(frozen=True)
class Partition:
    number: int
    start: int
    sectors: int
    kind: int
    active: bool
    table: int
    slot: int


def entry(data, offset):
    flag, kind = data[offset], data[offset+4]
    start, length = struct.unpack_from('<II', data, offset+8)
    if flag not in (0, 0x80):
        raise ValueError('invalid partition boot flag')
    if not kind:
        if start or length or flag:
            raise ValueError('nonempty unused partition entry')
        return None
    if not start or not length or start+length > 0xffffffff:
        raise ValueError('invalid partition bounds')
    return flag, kind, start, length


def overlap(a, b):
    return max(a[0], b[0]) < min(a[1], b[1])


def scan(image, max_logical=128):
    if len(image) % SECTOR or len(image) < SECTOR:
        raise ValueError('invalid image length')
    capacity = len(image)//SECTOR
    def table(lba):
        if not 0 <= lba < capacity:
            raise ValueError('partition table outside disk')
        data = image[lba*SECTOR:(lba+1)*SECTOR]
        if data[510:512] != b'\x55\xaa':
            raise ValueError('invalid MBR/EBR signature')
        return data
    mbr = table(0)
    parts, ranges, container = [], [], None
    for slot in range(4):
        e = entry(mbr, 446+slot*16)
        if not e:
            continue
        flag, kind, start, length = e
        end = start+length
        if end > capacity or any(overlap((start,end), r) for r in ranges):
            raise ValueError('primary partitions overlap or exceed disk')
        ranges.append((start,end))
        parts.append(Partition(slot+1,start,length,kind,bool(flag),0,slot))
        if kind in EXTENDED:
            if container:
                raise ValueError('multiple extended containers')
            container = start,end
    if not container:
        return parts
    base, end = container
    current, seen, used, tables = base, set(), [], []
    while True:
        if current in seen or len(seen) >= max_logical:
            raise ValueError('cyclic or oversized EBR chain')
        if not base <= current < end:
            raise ValueError('EBR outside extended container')
        seen.add(current); tables.append(current)
        data = table(current)
        # UniDOS must not reinterpret entries owned by another partition scheme.
        if any(data[478:510]):
            raise ValueError('unsupported EBR entries 3/4')
        e = entry(data,446)
        if e:
            flag,kind,relative,length = e
            start = current+relative
            if kind in EXTENDED or start+length > end or start < base:
                raise ValueError('invalid logical partition')
            r = start,start+length
            if any(overlap(r, previous) for previous in used):
                raise ValueError('overlapping logical partitions')
            used.append(r)
            parts.append(Partition(5+len(seen)-1,start,length,kind,bool(flag),current,0))
        link = entry(data,462)
        if not link:
            break
        flag,kind,relative,length = link
        if flag or kind not in EXTENDED or base+relative+length > end:
            raise ValueError('invalid EBR link')
        current = base+relative
    if any(a <= t < b for a,b in used for t in tables):
        raise ValueError('EBR is inside a logical partition')
    return parts


def fat12(label='P601 DATA', serial=None, hidden=0):
    """32,400 sectors / 4 KiB clusters / 512 root entries / 2 x 12-sector FAT."""
    label = label.upper().encode('ascii')
    if len(label)>11 or any(c<32 or c in b'"*+,./:;<=>?[\\]|' for c in label):
        raise ValueError('invalid FAT volume label')
    volume = bytearray(TOTAL*SECTOR)
    volume[:11] = b'\xeb\x3c\x90P601FAT '
    struct.pack_into('<HBHBHHBHHHII',volume,11,512,8,1,2,512,TOTAL,0xf8,12,81,2,hidden,0)
    volume[38] = 0x29
    struct.pack_into('<I',volume,39,int(time.time())&0xffffffff if serial is None else serial)
    volume[43:54] = label.ljust(11,b' ')
    volume[54:62] = b'FAT12   '
    volume[510:512] = b'\x55\xaa'
    for off in (512,13*512):
        volume[off:off+3] = b'\xf8\xff\xff'
    return bytes(volume)


def bpb(volume, partition_sectors=None):
    """Only require fields representable by the native UniDOS driver header."""
    if len(volume)<512 or volume[510:512] not in (b'\x55\xaa',b'\xa5\x5a'):
        raise ValueError('invalid FAT12 signature')
    size,spc,reserved,copies,root,total,media,spf,spt,heads = struct.unpack_from('<HBHBHHBHHH',volume,11)
    if size!=512 or spc not in (1,2,4,8,16,32,64,128):
        raise ValueError('invalid sector/cluster size')
    if not 1<=reserved<=255 or copies not in (1,2) or not 1<=spf<=255 or not root or not total:
        raise ValueError('unrepresentable FAT12 BPB')
    if not 1<=spt<=255 or not 1<=heads<=255:
        raise ValueError('unrepresentable geometry metadata')
    overhead=reserved+copies*spf+(root+15)//16
    clusters=(total-overhead)//spc
    if total<=overhead or not 1<=clusters<4085 or (clusters+2)*3>spf*1024:
        raise ValueError('invalid FAT12 data/FAT bounds')
    if partition_sectors is not None and total>partition_sectors:
        raise ValueError('volume exceeds partition')
    return dict(sectors=total,sectors_per_cluster=spc,clusters=clusters,reserved=reserved,
                fat_copies=copies,sectors_per_fat=spf,root_entries=root,overhead=overhead)


def choose_boot(parts, read, explicit=0):
    """Explicit BIOS selection, then first active FAT12, then old A/B slots."""
    candidates = ([p for p in parts if p.number==explicit] if explicit else
                  [p for p in parts if p.active and p.kind==1])
    if not explicit:
        candidates += [p for n in (2,3) for p in parts if p.number==n and p.kind==1]
    for p in candidates:
        if p.kind!=1:
            continue
        try:
            bpb(read(p.start),p.sectors)
        except ValueError:
            continue
        return p.number
    raise ValueError('no usable boot partition')


def put_entry(image, table, slot, kind, start, sectors, active=False):
    off=table*SECTOR+446+slot*16
    image[off:off+16]=bytes(16)
    image[off]=0x80 if active else 0
    image[off+1:off+4]=b'\xfe\xff\xff'
    image[off+4]=kind
    image[off+5:off+8]=b'\xfe\xff\xff'
    struct.pack_into('<II',image,off+8,start,sectors)


def append_plan(image, sectors, active=False):
    """Plan sector-sized metadata writes without copying the whole card."""
    parts=scan(image,max_logical=32)
    if len(parts)>=32:
        raise ValueError('native partition service supports at most 32 records')
    if not 0<sectors<=0xffffffff:
        raise ValueError('volume sector count')
    end=max([1]+[p.start+p.sectors for p in parts])
    aligned=(end+2047)//2048*2048
    writes={}
    def update(table,slot,kind,start,count,boot=False):
        if not 0<start<=0xffffffff or not 0<count<=0xffffffff or start+count>0xffffffff:
            raise ValueError('partition LBA overflow')
        sector=writes.setdefault(table,bytearray(image[table*512:(table+1)*512]))
        put_entry(sector,0,slot,kind,start,count,boot)
    extended=next((p for p in parts if p.kind in EXTENDED),None)
    if not extended:
        slots={p.slot for p in parts if p.table==0}
        slot=next((n for n in range(4) if n not in slots),None)
        if slot is None:
            raise ValueError('all primary slots occupied; an extended container is needed')
        start=aligned
        update(0,slot,1,start,sectors,active)
        number=slot+1
    else:
        logical=[p for p in parts if p.table]
        tables=[]; current=extended.start
        while True:
            tables.append(current)
            link=entry(image,current*512+462)
            if not link:break
            current=extended.start+link[2]
        last=tables[-1]
        used_end=max([extended.start+1]+[p.start+p.sectors for p in logical]+[t+1 for t in tables])
        aligned=(used_end+2047)//2048*2048
        reuse=not logical and len(tables)==1
        if not reuse and len(tables)>=32:
            raise ValueError('oversized EBR chain')
        ebr=extended.start if reuse else aligned
        start=ebr+2048
        container_end=max(extended.start+extended.sectors,start+sectors)
        if any(p.table==0 and p.number!=extended.number and overlap((extended.start,container_end),(p.start,p.start+p.sectors)) for p in parts):
            raise ValueError('extended growth would overlap another primary partition')
        if not reuse:
            update(last,1,extended.kind,ebr-extended.start,start+sectors-ebr)
        writes[ebr]=bytearray(512)
        writes[ebr][510:512]=b'\x55\xaa'
        update(ebr,0,1,start-ebr,sectors,active)
        update(0,extended.slot,extended.kind,extended.start,container_end-extended.start,extended.active)
        number=5 if reuse else 5+len(tables)
    if start+sectors>0xffffffff:
        raise ValueError('partition LBA overflow')
    return dict(number=number,start=start,bytes=max(len(image),(start+sectors)*512),writes=writes)


def append(image, volume, active=False):
    """Append without moving data; extend only the existing EBR container."""
    if len(volume)%512:
        raise ValueError('volume length')
    plan=append_plan(image,len(volume)//512,active)
    result=bytearray(image)
    if plan['bytes']>len(result):result.extend(bytes(plan['bytes']-len(result)))
    for table,sector in plan['writes'].items():result[table*512:(table+1)*512]=sector
    start=plan['start']
    result[start*512:start*512+len(volume)]=volume
    if len(scan(result,max_logical=32))>32:
        raise ValueError('native partition service supports at most 32 records')
    return bytes(result),plan['number']
