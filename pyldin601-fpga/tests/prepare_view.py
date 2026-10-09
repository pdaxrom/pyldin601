"""Standard PCX test vectors and independent RGB332 expectations; no converter."""
from pathlib import Path
import math
import struct
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root/'tools'))
import add_disk_files
import make_sd


def encode_line(row):
    result = bytearray()
    pos = 0
    while pos < len(row):
        count = 1
        while count < 63 and pos+count < len(row) and row[pos+count] == row[pos]:
            count += 1
        if count > 1 or row[pos] >= 192:
            result.append(192+count)
        result.append(row[pos])
        pos += count
    return bytes(result)


def pcx(width, height, pixels, palette, stride=None, origin=(0, 0)):
    stride = stride or (width+1)&~1
    header = bytearray(128)
    header[:4] = bytes((10, 5, 1, 8))
    x, y = origin
    struct.pack_into('<6H', header, 4, x, y, x+width-1, y+height-1, 320, 200)
    header[65] = 1
    struct.pack_into('<4H', header, 66, stride, 1, width, height)
    payload = b''.join(encode_line(pixels[y*width:(y+1)*width]+bytes([241])*(stride-width))
                       for y in range(height))
    return bytes(header)+payload+b'\x0c'+bytes(palette)


def frame(width, height, pixels, palette):
    result = bytearray(64000)
    x0, y0 = (320-width)//2, (200-height)//2
    for y in range(height):
        for x in range(width):
            i = pixels[y*width+x]*3
            r, g, b = palette[i:i+3]
            result[(y+y0)*320+x+x0] = ((r*7+127)//255)<<5 | ((g*7+127)//255)<<2 | (b*3+127)//255
    return bytes(result)


def prepare():
    work = root/'build/view';work.mkdir(parents=True, exist_ok=True)
    # Deliberately permuted colours: a viewer that treats indices as RGB332 fails.
    palette = bytes(v for n in range(256) for v in ((n*73+18)&255, (n*151+55)&255, (n*199+128)&255))
    cases = {}
    full = bytes((x*13+y*79)&255 for y in range(200) for x in range(320))
    odd = bytes((x//3+y*17+192)&255 for y in range(9) for x in range(17))
    runs = bytes((y*37)&255 for y in range(200) for x in range(320))
    for name, w, h, pixels, stride, origin in [
        ('FULL', 320, 200, full, 320, (0, 0)),
        ('ODD', 17, 9, odd, 32, (13, 29)),
        ('RUNS', 320, 200, runs, 512, (0, 0))]:
        data = pcx(w, h, pixels, palette, stride, origin)
        cases[name] = data
        (work/f'{name}.PCX').write_bytes(data)
        (work/f'{name}.rgb332').write_bytes(frame(w, h, pixels, palette))
    # A generated picture for hardware viewing, stored as standard PCX directly.
    # There is no image import or PNG/JPEG conversion path.
    fractal_palette = bytes(v for n in range(256) for v in (
        (0, 0, 0) if n == 0 else tuple(round(127.5+127.5*math.sin(n/19+phase)) for phase in (0, 2.1, 4.2))))
    fractal = bytearray()
    for y in range(200):
        for x in range(320):
            c = complex(-2.3+x*3.1/319, -1.05+y*2.1/199);z = 0j
            for n in range(255):
                z = z*z+c
                if abs(z)>2:
                    fractal.append(1+n);break
            else:
                fractal.append(0)
    cases['FRACTAL'] = pcx(320, 200, fractal, fractal_palette)
    (work/'FRACTAL.PCX').write_bytes(cases['FRACTAL'])
    (work/'FRACTAL.rgb332').write_bytes(frame(320, 200, fractal, fractal_palette))
    assert len(cases['FULL']) > 65535
    good = cases['ODD']
    for name, at, value in [('PLANES', 65, 3), ('BITS', 3, 4), ('HEIGHT', 10, 250),
                             ('STRIDE', 66, 17), ('SMALL', 66, 16), ('PAL', len(good)-769, 13)]:
        data = bytearray(good);data[at] = value;cases[name] = bytes(data)
    cases['ZERO'] = good[:128]+b'\xc0\x01'+good[-769:]
    cases['CROSS'] = good[:128]+b'\xff\x01'+good[-769:]
    cases['CUT'] = good[:128]+b'\xc1'+good[-769:]
    cases['SHORT'] = good[:127]
    cases['TRUNC'] = good[:128]+good[128:130]+good[-769:]
    cases['WRAP'] = good[:4]+struct.pack('<HHHH', 0, 0, 65535, 8)+good[12:]
    cases['ORDER'] = good[:4]+struct.pack('<HHHH', 20, 0, 19, 8)+good[12:]
    cases['BIGPAD'] = good[:66]+struct.pack('<H', 514)+good[68:]
    cases['WIDTH'] = good[:8]+struct.pack('<H', 333)+good[10:]
    files = {'VIEW.PGM': (root/'build/gfx/VIEW.PGM').read_bytes(),
             **{f'{name}.PCX': data for name, data in cases.items()}}
    # A private test volume retains the real DOS/application files and overlays
    # the freshly built VIEW. Editing the viewer never requires rewriting the
    # distributed SD image before its tests can run.
    base = (root/'images/sd.img').read_bytes()
    begin = int.from_bytes(base[486:490], 'little')*512
    end = begin+int.from_bytes(base[490:494], 'little')*512
    existing = add_disk_files.root_files(base[begin:end])
    info = make_sd.disk_info(base[begin:end])
    blank = make_sd.blank_disk(end-begin, info['sectors_per_track'], info['heads'])
    image = bytearray(base)
    image[begin:end] = add_disk_files.add_files(blank, {**existing, **files})
    (work/'sd.img').write_bytes(image)
    print(f'Prepared {len(cases)} standard-PCX vectors, including {len(cases["FULL"])}-byte file')


if __name__ == '__main__':
    prepare()
