"""Render native NC framebuffer snapshots with the actual ROM font.

This is a digital IRGB reference, not a simulation of composite PAL filtering.
No external image libraries or replacement font are used.
"""
from pathlib import Path
import struct
import zlib

OUT = Path(__file__).resolve().parents[1] / 'build/nc'


def chunk(kind, payload):
    return (struct.pack('>I', len(payload)) + kind + payload
            + struct.pack('>I', zlib.crc32(kind + payload)))


def render(metadata):
    state = list(map(int, metadata.read_text().split()))
    model_a, mode, base, stride = state[:4]
    # Show the visible phase of the native hardware caret in text snapshots.
    cursor, cursor_start, cursor_end = state[4:] if len(state) > 4 else (-1, 32, 0)
    if not model_a:
        cursor -= 2
    height = 216 if mode in (0, 4) else 200
    ram = metadata.with_suffix('.bin').read_bytes()
    font = (OUT / 'font.bin').read_bytes()
    width = 320 if mode == 2 or not model_a or mode == 0 else 640
    palette = [tuple((170 if colour & bit else 0) + (85 if colour & 8 else 0)
                     for bit in (4, 2, 1)) for colour in range(16)]
    pixels = bytearray()
    for y in range(height):
        row = bytearray()
        for x in range(width):
            if mode in (0, 4):
                step = 2 if model_a and mode == 0 else 1
                address = (base + (y // 8) * stride + (x // 8) * step) & 65535
                char = ram[(address + (step == 2)) & 65535]
                attr = ram[address] if step == 2 else 0xf0
                dot = font[char * 8 + y % 8] & (128 >> (x % 8))
                if (((address + (step == 2)) & 65535) == cursor
                        and ((cursor_start >> 5) & 3) != 1
                        and (cursor_start & 31) <= y % 8 <= (cursor_end & 31)):
                    dot = not dot
                colour = ((attr >> 4) & 7 if step == 2 else 15) if dot else attr & 15
            else:
                bits = 2 if mode == 2 else 1
                unit = 8 // bits
                address = (base + (y // 8) * (640 if model_a else 320)
                           + (x // unit) * 8 + y % 8) & 65535
                sample = (ram[address] >> (8 - bits * (x % unit + 1))) & ((1 << bits) - 1)
                colour = sample * 2 + 1 if bits == 2 else 15 if sample else 0
            row.extend(bytes(palette[colour]) * (640 // width))
        pixels.extend((b'\0' + row) * 2)
    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', 640, height * 2, 8, 2, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(pixels, 9)) + chunk(b'IEND', b''))
    path = metadata.with_suffix('.png')
    path.write_bytes(png)
    print(path.relative_to(OUT.parent.parent))


if __name__ == '__main__':
    for snapshot in sorted(OUT.glob('screen-*.txt')):
        render(snapshot)
