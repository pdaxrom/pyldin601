"""Independent format, codec and exact hardware-preview tests for the C tool."""
import argparse
from pathlib import Path
import struct
import subprocess
from ham8_format import decode, rgb, png, read_png, chunks
def main():
    root=Path(__file__).resolve().parents[1]
    p=argparse.ArgumentParser();p.add_argument('--tool',default='build/ham8conv');p.add_argument('--cc',default='cc');args=p.parse_args()
    tool=(root/args.tool).resolve();work=root/'build/ham8conv-test';work.mkdir(parents=True,exist_ok=True)
    flags=subprocess.check_output(['pkg-config','--cflags','--libs','libjpeg'],text=True).split()
    subprocess.run([args.cc,'-O2','-Wall','-Wextra','tests/prepare_ham8_jpeg.c','-o',str(work/'jpeg'),*flags],cwd=root,check=True)

    def run(source,name,options=()):
        out=work/f'{name}.IFF';preview=work/f'{name}-preview.png'
        result=subprocess.run([str(tool),*options,'--preview',str(preview),str(source),str(out)],capture_output=True,text=True,check=True)
        codes=decode(out.read_bytes());assert read_png(preview)==(320,200,rgb(codes))
        print(result.stdout.strip().splitlines()[-1])
        return codes

    source=work/'pattern.png';pixels=bytes(v for y in range(200) for x in range(320) for v in ((x*13+y*17)&255,(x+y*3)&255,(x*7+y*5)&255))
    png(source,320,200,pixels)
    a=run(source,'pattern');assert a==run(source,'raw',['--uncompressed'])
    assert a==run(source,'repeat');assert len((work/'raw.IFF').read_bytes())==64260
    # Independent greedy search over all 256 commands bounds the beam result.
    # This uses decoded RGB states directly, not the converter's candidate set.
    weights=(.299,.587,.114)
    actual=rgb(a)
    beam_error=sum(weights[i%3]*(v-pixels[i])**2 for i,v in enumerate(actual))
    greedy_error=0
    for y in range(200):
        state=[0,0,0]
        for x in range(320):
            target=pixels[(y*320+x)*3:(y*320+x+1)*3]
            candidates=[]
            for code in range(64):candidates.append([(code>>4)*85,((code>>2)&3)*85,(code&3)*85])
            for channel in (2,0,1):
                best=min(range(64),key=lambda n:abs(((n<<2)|(n>>4))-target[channel]))
                v=state.copy();v[channel]=(best<<2)|(best>>4);candidates.append(v)
            state=min(candidates,key=lambda c:sum(w*(v-t)**2 for w,v,t in zip(weights,c,target)))
            greedy_error+=sum(w*(v-t)**2 for w,v,t in zip(weights,state,target))
    assert beam_error<=greedy_error+0.00001,(beam_error,greedy_error)
    print(f'PASS weighted error: beam {beam_error:.0f} <= independent greedy {greedy_error:.0f}')
    # A 1x1 transparent source must yield exact black; RGBA composites onto black.
    png(work/'alpha.png',1,1,b'\xff\xff\xff\0',4)
    assert rgb(run(work/'alpha.png','alpha'))==bytes(192000)
    png(work/'grey.png',320,200,bytes(x&255 for y in range(200) for x in range(320)),1)
    run(work/'grey.png','grey')
    # Default aspect keeps square pictures 200x200; --stretch explicitly fills.
    png(work/'square.png',10,10,b'\xff\0\0'*100)
    fit=rgb(run(work/'square.png','fit'));stretch=rgb(run(work/'square.png','stretch',['--stretch']))
    assert all(fit[(y*320+x)*3:(y*320+x+1)*3]==bytes(3) for y in range(200) for x in (*range(60),*range(260,320)))
    assert stretch==b'\xff\0\0'*64000
    # Repeat rows must reset HAM state at every left edge.
    row=bytes(v for x in range(320) for v in (x&255,(x*7)&255,(x*11)&255));png(work/'rows.png',320,200,row*200)
    r=run(work/'rows.png','rows');assert all(r[y*320:(y+1)*320]==r[:320] for y in range(200))
    # Baseline, progressive, grayscale and CMYK JPEG inputs.
    for mode in range(4):
        src=work/f'jpeg{mode}.jpg';ref=work/f'jpeg{mode}.rgb'
        subprocess.run([str(work/'jpeg'),str(src),str(ref),str(mode)],check=True)
        run(src,f'jpeg{mode}')
    # All eight TIFF/Exif orientations match an independently rearranged RGB image.
    base=(work/'jpeg0.jpg').read_bytes();original=(work/'jpeg0.rgb').read_bytes()
    for o in range(1,9):
        exif=b'Exif\0\0II'+struct.pack('<HIH',42,8,1)+struct.pack('<HHIHH',0x112,3,1,o,0)+bytes(4)
        src=work/f'orientation{o}.jpg';src.write_bytes(base[:2]+b'\xff\xe1'+struct.pack('>H',len(exif)+2)+exif+base[2:])
        w,h=(50,80) if o>4 else (80,50);rot=bytearray(w*h*3)
        for y in range(50):
            for x in range(80):
                a,b=[(x,y),(79-x,y),(79-x,49-y),(x,49-y),(y,x),(49-y,x),(49-y,79-x),(y,79-x)][o-1]
                rot[(b*w+a)*3:(b*w+a+1)*3]=original[(y*80+x)*3:(y*80+x+1)*3]
        ref=work/f'orientation{o}-ref.png';png(ref,w,h,rot)
        assert run(src,f'orientation{o}')==run(ref,f'orientation{o}-ref')
    # Invalid input and same-file aliases must not overwrite an existing output.
    for suffix,data in [('bad',b'not an image'),('broken',b'\xff\xd8bogus')]:
        src=work/suffix;src.write_bytes(data);out=work/'protected.IFF';out.write_bytes(b'original')
        p=subprocess.run([str(tool),str(src),str(out)],capture_output=True)
        assert p.returncode and out.read_bytes()==b'original'
    before=source.read_bytes();alias=work/'alias.png';alias.unlink(missing_ok=True);alias.symlink_to(source)
    for output in (source,alias):
        assert subprocess.run([str(tool),str(source),str(output)],capture_output=True).returncode
    assert source.read_bytes()==before
    print('PASS C HAM8 converter: independent IFF/ByteRun1/planar/HAM decode equals PNG preview; raw/compressed/determinism/aspect/alpha/row reset; four JPEG modes, eight Exif orientations; invalid input and overwrite protection')


if __name__=='__main__':
    main()
