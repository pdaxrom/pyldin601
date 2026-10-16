"""Independent PCX interchange fixture and decoder for native codec tests."""
import struct

CASES=((0,320,1,1,2),(1,640,1,1,0),(2,320,1,2,2),(3,320,8,1,0),(4,320,1,4,0),(5,320,2,1,2))
def encode_rle(data):
    out=bytearray();at=0
    while at<len(data):
        end=at+1
        while end<len(data) and data[end]==data[at] and end-at<63:end+=1
        if end-at>1 or data[at]>=192:out.append(192+end-at)
        out.append(data[at]);at=end
    return out
def make_fixtures(out):
    files={}
    for number,width,bits,planes,pad in CASES:
        colours=1<<(bits*planes)
        pixels=bytes(((x*23+y*37+(x//7)*13) ^ (x*y))%(colours) for y in range(200) for x in range(width))
        palette=bytes((k*17+j*29+(k//3))&63 for k in range(256) for j in range(3))
        line=(width*bits+7)//8+pad;header=bytearray(128);header[:4]=bytes((10,5,1,bits))
        struct.pack_into('<HHHH',header,4,0,0,width-1,199);header[65]=planes;struct.pack_into('<HH',header,66,line,1)
        pal8=bytes((n<<2)|(n>>4) for n in palette)
        header[16:64]=pal8[:48]
        body=bytearray()
        for y in range(200):
            row=pixels[y*width:(y+1)*width]
            packed=bytearray()
            for plane in range(planes):
                lane=bytearray(line)
                for x,index in enumerate(row):
                    v=(index>>(plane*bits))&((1<<bits)-1)
                    lane[(x*bits)//8] |= v << (8-bits-(x*bits)%8)
                # Deliberately nonzero row padding must be ignored by decoder.
                for x in range((width*bits+7)//8,line):lane[x]=0xc5
                packed+=lane
            body+=encode_rle(packed)
        files[f'PCX{number}.PCX']=bytes(header+body+(b'\x0c'+pal8 if bits==8 else b''))
        (out/f'PCX{number}.raw').write_bytes(pixels)
        (out/f'PCX{number}.pal').write_bytes(palette if bits==8 else palette[:48]+bytes(720))
    bad=bytearray(files['PCX3.PCX']);bad[-769]=0;files['PCXBAD.PCX']=bytes(bad)
    return files
def decode(data):
    assert data[:3]==b'\x0a\x05\x01' and len(data)>=128
    bits,planes,line=data[3],data[65],int.from_bytes(data[66:68],'little')
    x0,y0,x1,y1=struct.unpack_from('<HHHH',data,4);width,height=x1-x0+1,y1-y0+1
    at=128;raw=bytearray();count=height*planes*line
    while len(raw)<count:
        v=data[at];at+=1;n=1
        if v&192==192:n=v&63;assert n;v=data[at];at+=1
        raw.extend(bytes((v,))*n)
    assert len(raw)==count
    pixels=bytearray()
    for y in range(height):
        for x in range(width):
            index=0
            for plane in range(planes):
                value=raw[(y*planes+plane)*line+(x*bits)//8]
                index |= ((value>>(8-bits-(x*bits)%8))&((1<<bits)-1))<<(plane*bits)
            pixels.append(index)
    palette=data[-768:] if bits==8 and data[-769]==12 else data[16:64]+bytes(720)
    return width,height,bytes(pixels),bytes(n>>2 for n in palette)
def verify_outputs(out):
    for model in ('601','601a'):
        for cpu in ('mc6800','hd6303'):
            for number,width,*_ in CASES:
                if number==1 and model=='601':continue
                data=(out/f'pcx-{model}-{cpu}-{number}.pcx').read_bytes()
                w,h,pixels,palette=decode(data)
                assert (w,h)==(width,200) and pixels==(out/f'PCX{number}.raw').read_bytes()
                assert palette==(out/f'PCX{number}.pal').read_bytes()
    print('PASS independent PCX decoder: native files preserve every pixel and RGB666 palette entry')
