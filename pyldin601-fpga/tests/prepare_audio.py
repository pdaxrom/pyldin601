"""Standard register-dump fixtures and independent complete-frame oracles."""
import json
from itertools import groupby
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from add_disk_files import install
from make_sd import blank_disk, u32


def melody(count):
    notes = (478, 426, 379, 358, 319, 284, 253, 239)
    return [bytes([notes[(i // 10) % 8] & 255, notes[(i // 10) % 8] >> 8,
                   (i * 19) & 255, (i // 29) & 15, (i * 7) & 255, (i // 37) & 15,
                   i % 32, 0x38, 12, 8, 6, i & 255, (i >> 8) & 255,
                   9 if i % 17 == 0 else 255]) for i in range(count)]


def ym3(frames, loop=None):
    body = b''.join(bytes(f[r] for f in frames) for r in range(14))
    return (b'YM3!' if loop is None else b'YM3b') + body + (b'' if loop is None else struct.pack('<I', loop))


def ym56(frames, version=6, planar=True, rate=50, clock=2000000, loop=0):
    regs = [f + bytes(2) for f in frames]
    body = b''.join(bytes(f[r] for f in regs) for r in range(16)) if planar else b''.join(regs)
    return (f'YM{version}!'.encode() + b'LeOnArD!' +
            struct.pack('>IIHIHIH', len(frames), int(planar), 0, clock, rate, loop, 0) +
            b'Lilith AY test\0Native HD6303\0No host conversion\0' + body + b'End!')


def compact_psg(data):
    output = bytearray(data[:16])
    pending = {}
    i = 16
    while i < len(data):
        op = data[i]; i += 1
        if op == 253:
            output.append(op)
            break
        if op >= 254:
            for reg, value in sorted(pending.items()):
                output.extend((reg, value))
            pending.clear()
            output.append(op)
            if op == 254:
                output.append(data[i]); i += 1
        else:
            value = data[i]; i += 1
            if op < 14:
                pending[op] = value
    return bytes(output)


def vtx(frames, rate=50, clock=1773400, loop=0):
    """Standard VTX, with independently encoded constant-symbol LH5 blocks."""
    raw = b''.join(bytes(f[r] for f in frames) for r in range(14))
    bits = []
    for value, run in groupby(raw):
        count = len(list(run))
        while count:
            n = min(count, 65535)
            bits.append(f'{n:016b}' + '00000' + '00000' + '000000000' + f'{value:09b}' + '0000' + '0000')
            count -= n
    stream = ''.join(bits)
    stream += '0' * (-len(stream) % 8)
    packed = int(stream, 2).to_bytes(len(stream)//8, 'big')
    header = b'ay' + struct.pack('<BHI BHI', 0, loop, clock, rate, 2026, len(raw))
    return header + b'Puldin test\0Native HD6303\0Fixture\0\0No conversion\0' + packed, raw


def main():
    out = ROOT / 'build/audio'
    out.mkdir(parents=True, exist_ok=True)
    frames = melody(80)
    cases = {}
    files = {'YPLAY.PGM': (out / 'YPLAY.PGM').read_bytes()}

    def add(name, data, oracle=frames, rate=50, factor=256, loop=0, error=None, large=False, unpacked=None):
        files[name] = data
        (out / name).write_bytes(data)
        oracle_name = name + '.frames'
        (out / oracle_name).write_bytes(b''.join(oracle))
        original = data if unpacked is None else unpacked
        expected = compact_psg(original) if original.startswith(b'PSG\x1a') and not error else original
        (out / (name + '.raw')).write_bytes(expected)
        cases[name] = dict(oracle=oracle_name, rate=rate, factor=factor, loop=loop,
                           error=error, large=large)

    demo = (out / 'DEMO.YM').read_bytes()
    demo_frames = [bytes(demo[4+r*375+i] for r in range(14)) for i in range(375)]
    add('DEMO.YM', demo, oracle=demo_frames)
    add('DEMOH5.YM', (ROOT / 'firmware/audio/DEMOH5.YM').read_bytes(), oracle=demo_frames, unpacked=demo)
    add('THREE.YM', ym3(frames))
    add('LOOP.YM', ym3(frames, 7), loop=7)
    add('FIVE.YM', ym56(frames, 5, False, 60, 1000000), rate=60, factor=512)
    add('SIX.YM', ym56(frames, 6, True, 100, 1773400), rate=100, factor=289)
    add('SLOW.YM', ym56(frames, 6, False, 1, 2000000), rate=1)
    add('ODD.YM', ym56(frames, 6, False, 37, 2000000), rate=37)
    add('MSX.YM', ym56(frames, 6, False, 50, 1789773), factor=286)
    large = melody(32400)
    add('LARGE.YM', ym3(large), oracle=large, large=True)
    commands = b''.join(b''.join(bytes([r, f[r]]) for r in range(14) if r != 13 or f[r] != 255) + b'\xff' for f in frames) + b'\xfd'
    add('LOG.PSG', b'PSG\x1a' + bytes([0, 60]) + bytes(10) + commands, rate=60, factor=289)
    dense = b''.join(b''.join(bytes([r, f[r]]) for _ in range(8) for r in range(14) if r != 13 or f[r] != 255) + b'\xff' for f in frames) + b'\xfd'
    add('DENSE.PSG', b'PSG\x1a' + bytes([0, 60]) + bytes(10) + dense, rate=60, factor=289)
    held = frames[:1] * 8 + frames[1:]
    held = [f if i == 0 else f[:13] + bytes([255]) if i < 8 else f for i, f in enumerate(held)]
    stream = b''.join(bytes([r, frames[0][r]]) for r in range(14)) + b'\xfe\x02'
    stream += b''.join(b''.join(bytes([r, f[r]]) for r in range(14) if r != 13 or f[r] != 255) + b'\xff' for f in frames[1:])
    add('WAIT.PSG', b'PSG\x1a' + bytes(12) + stream, oracle=held, factor=256)
    add('BADEND.YM', ym56(frames)[:-1], error='invalid/unsupported')
    effects = frames.copy(); effects[40] = effects[40][:1] + bytes([0x10]) + effects[40][2:]
    add('EFFECT.YM', ym56(effects), error='timer/digidrum')
    add('BADCLK.YM', ym56(frames, clock=1234), error='invalid/unsupported')
    add('BADREG.PSG', b'PSG\x1a' + bytes(12) + b'\x70\x00\xff', error='invalid/unsupported')
    add('TRUNC.PSG', b'PSG\x1a' + bytes(12) + b'\x01', error='invalid/unsupported')
    add('ZEROWAIT.PSG', b'PSG\x1a' + bytes(12) + b'\xfe\x00', error='invalid/unsupported')
    add('HUGE.YM', b'YM3!' + bytes(909312), error='exceeds 888 KiB')
    # Legal PT trailing-zero skip extends beyond the encoded length count.
    # Constant literal blocks also exercise both constant Huffman trees.
    bits = ''
    def put(value, width):
        nonlocal bits
        bits += f'{value:0{width}b}'
    raw = ym3([bytes(14)] * 80)
    for value, count in [(ord('Y'),1),(ord('M'),1),(ord('3'),1),(ord('!'),1),(0,1120)]:
        put(count,16); put(3,5)
        for length in (1,2,2): put(length,3)
        put(3,2); put(0,9); put(value,9); put(0,4); put(0,4)
    bits += '0' * (-len(bits) % 8)
    packed_bits = int(bits,2).to_bytes(len(bits)//8,'big')
    crc = 0
    for byte in raw:
        crc ^= byte
        for _ in range(8): crc = (crc>>1)^ (0xa001 if crc&1 else 0)
    header = bytearray(b'\0\0-lh5-' + struct.pack('<II',len(packed_bits),len(raw)) + bytes(4) + bytes([0x20,0,7]) + b'ZERO.YM' + struct.pack('<H',crc))
    header[0] = len(header)-2; header[1] = sum(header[2:]) & 255
    add('SKIPLH5.YM', bytes(header)+packed_bits+b'\0', oracle=[bytes(14)]*80, unpacked=raw)
    wrong = bits[:21] + '001001001' + bits[30:]
    add('BADTREE.YM', bytes(header)+int(wrong,2).to_bytes(len(wrong)//8,'big')+b'\0', error='invalid/unsupported')
    fixture = ROOT / 'tests/fixtures/audio'
    add('LH0.YM', (fixture / 'LH0.YM').read_bytes(), unpacked=ym3(frames))
    packed = (fixture / 'LH5.YM').read_bytes()
    add('LH5.YM', packed, rate=60, factor=512, unpacked=ym56(frames, 5, False, 60, 1000000))
    add('LH5BIG.YM', (fixture / 'LH5BIG.YM').read_bytes(), oracle=large, large=True, unpacked=ym3(large))
    mute = [bytes(14)] * 10000
    add('MUTELH5.YM', (fixture / 'MUTELH5.YM').read_bytes(), oracle=mute, large=True, unpacked=ym3(mute))
    bad = bytearray(packed)
    bad[22 + bad[21]] ^= 1
    bad[1] = sum(bad[2:bad[0]+2]) & 255
    add('BADCRC.YM', bytes(bad), error='invalid/unsupported')
    bad = bytearray(packed); bad[1] ^= 1
    add('BADLHA.YM', bytes(bad), error='invalid/unsupported')
    add('CUTLHA.YM', packed[:-8], error='invalid/unsupported')
    bad = bytearray(packed); bad[20] = 2
    bad[1] = sum(bad[2:bad[0]+2]) & 255
    add('LEVEL2.YM', bytes(bad), error='invalid/unsupported')
    vtx_data, vtx_raw = vtx(frames)
    add('AYTEST.VTX', vtx_data, factor=289, unpacked=vtx_raw)
    data, raw = vtx(frames, rate=60, clock=1000000, loop=11)
    add('AYLOOP.VTX', data, rate=60, factor=512, loop=11, unpacked=raw)
    data, raw = vtx(melody(2100), rate=100, clock=2000000)
    add('AYBIG.VTX', data, oracle=melody(2100), rate=100, factor=256, large=True, unpacked=raw)
    add('VTXCUT.VTX', vtx_data[:-32], error='invalid/unsupported', unpacked=vtx_raw)
    for name, index, value in [('VTXRATE.VTX',9,0),('VTXMODE.VTX',2,7),('VTXSIZE.VTX',12,1),('VTXLOOP.VTX',4,255)]:
        data = bytearray(vtx_data); data[index] = value
        add(name, bytes(data), error='invalid/unsupported', unpacked=vtx_raw)
    add('VTXSTR.VTX', vtx_data[:16] + b'x'*255, error='invalid/unsupported', unpacked=vtx_raw)
    source = bytearray((ROOT / 'images/sd.img').read_bytes())
    # The full positive/negative corpus outgrows the floppy-sized B:.
    # Give only this private fixture a native-profile FAT12 volume after C:.
    start, size = 73728 * 512, 32400 * 512
    capacity = ((start+size+524287)//524288)*524288
    source.extend(bytes(max(0, capacity-len(source))))
    struct.pack_into('<II', source, 446+2*16+8, start//512, size//512)
    source[start:start+size] = blank_disk(size)
    image, _ = install(bytes(source), files, replace=True)
    (out / 'sd-test.img').write_bytes(image)
    (out / 'cases.json').write_text(json.dumps(cases, indent=2) + '\n')
    print(f'{len(cases)} audio files installed in private B: fixture.')


if __name__ == '__main__':
    main()
