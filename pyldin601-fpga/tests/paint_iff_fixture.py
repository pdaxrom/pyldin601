"""ILBM/ByteRun1 interchange oracle, independent from the native codec."""
import struct
def chunk(name,data):return name+struct.pack('>I',len(data))+data+(b'\0' if len(data)&1 else b'')
def packbits(data):
    out=bytearray();at=0
    while at<len(data):
        end=at+1
        while end<len(data) and data[end]==data[at] and end-at<128:end+=1
        if end-at>=3:out+=bytes((257-(end-at),data[at]));at=end;continue
        end=at+1
        while end<len(data) and end-at<128 and not (end+2<len(data) and data[end]==data[end+1]==data[end+2]):end+=1
        out.append(end-at-1);out+=data[at:end];at=end
    return out
def rgb(codes,palette):
    result=bytearray()
    for row in range(200):
        held=[0,0,0]
        for code in codes[row*320:(row+1)*320]:
            if code<64:held=list(palette[code*3:code*3+3])
            else:held[(2,0,1)[(code>>6)-1]]=code&63
            result+=bytes(held)
    return bytes(result)
def make_iff_fixtures(out):
    files={}
    for number in range(2):
        palette=bytes((k*13+j*19+(k//7))&63 for k in range(64) for j in range(3))
        codes=bytes((128+((y//7)&63) if x<80 else ((x*17+y*23)^(x*y)))&255 for y in range(200) for x in range(320))
        body=bytearray()
        for y in range(200):
            for plane in range(8):
                lane=bytearray(40)
                for x in range(320):lane[x//8]|=((codes[y*320+x]>>plane)&1)<<(7-x%8)
                body+=packbits(lane)+b'\x80' if number else lane
        # Native decoder permits harmless ByteRun1 NOPs between plane rows,
        # but keep the last body byte part of the actual final packet.
        if number:body.pop()
        bmhd=struct.pack('>HHhhBBBBHBBhh',320,200,0,0,8,0,number,0,0,1,1,320,200)
        cmap=chunk(b'CMAP',bytes((v<<2)|(v>>4) for v in palette))
        camg=chunk(b'CAMG',b'\0\0\x08\0')
        chunks=chunk(b'BMHD',bmhd)+chunk(b'ANNO',b'odd')
        if number:chunks+=chunk(b'JUNK',bytes(70001))+chunk(b'BODY',body)+cmap+camg
        else:chunks+=cmap+camg+chunk(b'BODY',body)
        files[f'IFF{number}.IFF']=chunk(b'FORM',b'ILBM'+chunks)
        (out/f'IFF{number}.raw').write_bytes(rgb(codes,palette))
    bad=chunk(b'BMHD',struct.pack('>HHhhBBBBHBBhh',320,200,0,0,8,0,1,0,0,1,1,320,200))+cmap+camg+chunk(b'BODY',bytes((129,0))*3)
    files['IFFBAD.IFF']=chunk(b'FORM',b'ILBM'+bad)
    return files
def decode(data):
    assert data[:4]==b'FORM' and data[8:12]==b'ILBM' and int.from_bytes(data[4:8],'big')+8==len(data)
    pieces={};at=12
    while at<len(data):
        tag=data[at:at+4];size=int.from_bytes(data[at+4:at+8],'big');pieces[tag]=data[at+8:at+8+size];at+=8+size+(size&1)
    assert pieces[b'BMHD']==struct.pack('>HHhhBBBBHBBhh',320,200,0,0,8,0,0,0,0,1,1,320,200)
    assert int.from_bytes(pieces[b'CAMG'],'big')&0x800
    body=pieces[b'BODY'];assert len(body)==64000
    codes=bytearray(64000)
    for y in range(200):
        for x in range(320):
            codes[y*320+x]=sum(((body[y*320+plane*40+x//8]>>(7-x%8))&1)<<plane for plane in range(8))
    palette=bytes(n>>2 for n in pieces[b'CMAP'])
    return rgb(codes,palette)
def verify_iff_outputs(out):
    for model in ('601','601a'):
        for cpu in ('mc6800','hd6303'):
            for number in range(2):
                stem=f'iff-{model}-{cpu}-{number}'
                assert decode((out/(stem+'.iff')).read_bytes())==(out/(stem+'-visible.raw')).read_bytes()
    print('PASS independent ILBM decoder: native HAM8 files exactly reproduce the encoded visible image')
