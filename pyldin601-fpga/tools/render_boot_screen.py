#!/usr/bin/env python3
"""Render a CPU-test text RAM snapshot with the exact classic font layout."""
import argparse
from pathlib import Path
import struct
import zlib

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--screen',type=Path,required=True)
    parser.add_argument('--font',type=Path,default=Path('rtl/font_boot.mem'))
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    screen=args.screen.read_bytes()
    font=bytes(int(v,16) for v in args.font.read_text().split())
    if len(screen)!=960 or len(font)!=2048:raise ValueError('Expected 40x24 screen and 2048-byte font')
    raw=bytearray()
    for y in range(192):
        row=bytearray([0])
        for x in range(320):
            code=screen[(y//8)*40+x//8]
            glyph=font[((code&127)<<4)|((code&128)>>4)|(y&7)]
            value=240 if glyph&(128>>(x&7)) else 16
            row.extend(bytes([value,value,value])*2)
        raw.extend(row*2)
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',640,384,8,2,0,0,0))
    png+=chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
    args.output.write_bytes(png)
    print(args.output)

if __name__=='__main__':main()
