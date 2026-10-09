"""Independent IFF/ByteRun1/HAM8 reference, shared by host and target tests."""
import struct
import zlib


def chunk(name, data):
    return name+struct.pack('>I', len(data))+data+b'\0'*(len(data)&1)


def form(chunks):
    payload=b'ILBM'+b''.join(chunk(k,v) for k,v in chunks)
    return b'FORM'+struct.pack('>I',len(payload))+payload


def chunks(data):
    assert data[:4]==b'FORM' and data[8:12]==b'ILBM'
    assert int.from_bytes(data[4:8],'big')==len(data)-8
    pos=12;result=[]
    while pos<len(data):
        size=int.from_bytes(data[pos+4:pos+8],'big');end=pos+8+size
        assert end+(size&1)<=len(data)
        result.append((data[pos:pos+4],data[pos+8:end]));pos=end+(size&1)
    assert pos==len(data)
    return result


def decode(data):
    parts=dict(chunks(data));h=parts[b'BMHD'];assert len(h)==20
    assert struct.unpack('>HH',h[:4])==(320,200) and h[8:11] in (b'\x08\x00\x00',b'\x08\x00\x01')
    assert parts[b'CAMG']==b'\0\0\x08\0'
    assert parts[b'CMAP']==bytes(v for i in range(64) for v in ((i>>4)*85,((i>>2)&3)*85,(i&3)*85))
    body=parts[b'BODY'];pos=0;codes=bytearray(64000)
    for y in range(200):
        for bit in range(8):
            plane=bytearray()
            while len(plane)<40:
                n=body[pos];pos+=1
                if not h[10]:plane.append(n)
                elif n<128:plane+=body[pos:pos+n+1];pos+=n+1
                elif n>128:plane+=bytes([body[pos]])*(257-n);pos+=1
                assert len(plane)<=40
            for x in range(320):
                if plane[x//8]&(128>>(x&7)):codes[y*320+x]|=1<<bit
    assert not body[pos:] or h[10] and set(body[pos:])=={128}
    return bytes(codes)


def rgb(codes):
    out=bytearray()
    for y in range(200):
        c=[0,0,0]
        for v in codes[y*320:(y+1)*320]:
            if v<64:c=[(v>>4)*21,((v>>2)&3)*21,(v&3)*21]
            else:c[{1:2,2:0,3:1}[v>>6]]=v&63
            out+=bytes((x<<2)|(x>>4) for x in c)
    return bytes(out)


def png(path,w,h,pixels,channels=3):
    colour={1:0,3:2,4:6}[channels]
    def block(k,v):return struct.pack('>I',len(v))+k+v+struct.pack('>I',zlib.crc32(k+v)&0xffffffff)
    raw=b''.join(b'\0'+pixels[y*w*channels:(y+1)*w*channels] for y in range(h))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+block(b'IHDR',struct.pack('>IIBBBBB',w,h,8,colour,0,0,0))+block(b'IDAT',zlib.compress(raw))+block(b'IEND',b''))


def read_png(path):
    data=path.read_bytes();pos=8;compressed=bytearray()
    while pos<len(data):
        n=int.from_bytes(data[pos:pos+4],'big');k=data[pos+4:pos+8];v=data[pos+8:pos+8+n];pos+=12+n
        if k==b'IHDR':w,h,depth,colour,*_=struct.unpack('>IIBBBBB',v);assert (depth,colour)==(8,2)
        if k==b'IDAT':compressed+=v
    raw=zlib.decompress(compressed);stride=w*3;previous=bytes(stride);out=bytearray()
    for y in range(h):
        at=y*(stride+1);f=raw[at];row=bytearray(raw[at+1:at+1+stride])
        for i in range(stride):
            a=row[i-3] if i>=3 else 0;b=previous[i];c=previous[i-3] if i>=3 else 0
            p=a+b-c;pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
            predictor=(0,a,b,(a+b)//2,a if pa<=pb and pa<=pc else b if pb<=pc else c)[f]
            row[i]=(row[i]+predictor)&255
        out+=row;previous=row
    return w,h,bytes(out)
