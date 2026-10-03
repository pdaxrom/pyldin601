"""Generate a 24 MHz PAL waveform ROM for the classic 601 IRGB palette.

The six-bit board DAC retains black=15 and white=49. The ROM replaces
runtime RGB/YUV multipliers with 32 phase samples for each colour.
Reflecting the phase address reverses PAL V. The second bank contains
the 300 mV p-p swinging burst. The 1024x6 table fits one EBR.
"""
import argparse
import math
from pathlib import Path


def samples():
    for burst in range(2):
        for colour in range(16):
            intensity = (colour >> 3) & 1
            r = (2 * ((colour >> 2) & 1) + intensity) / 3
            g = (2 * ((colour >> 1) & 1) + intensity) / 3
            b = (2 * (colour & 1) + intensity) / 3
            y = 0.299 * r + 0.587 * g + 0.114 * b
            u = 0.493 * (b - y)
            v = 0.877 * (r - y)
            if burst:
                y = 0
                u = -(0.3 / 0.7) / (2 * math.sqrt(2))
                v = -u
            for phase in range(32):
                angle = (phase + 0.5) * math.tau / 32
                sample = round(15 + 34 * (y + u * math.sin(angle) + v * math.cos(angle)))
                # No wrap or clipping of saturated colours into sync.
                assert 0 < sample < 64
                yield sample


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("rtl/pal_waveform.mem"))
    args = parser.parse_args()
    args.output.write_text("".join(f"{v:02x}\n" for v in samples()))
