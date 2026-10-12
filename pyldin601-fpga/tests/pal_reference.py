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


def rgb332_samples():
    """256 fixed colours; preserve the existing matrix, DAC and DDS phases."""
    for colour in range(256):
        r, g, b = (colour >> 5) / 7, ((colour >> 2) & 7) / 7, (colour & 3) / 3
        y = 0.299 * r + 0.587 * g + 0.114 * b
        u, v = 0.493 * (b - y), 0.877 * (r - y)
        for phase in range(32):
            angle = (phase + 0.5) * math.tau / 32
            sample = round(15 + 34 * (y + u * math.sin(angle) + v * math.cos(angle)))
            assert 0 < sample < 64
            yield sample


def palette_coefficients():
    """Signed Q9 gains, RGB888 -> DAC, for the native HD6303 viewer.

    All gains fit signed bytes, permitting three hardware MUL instructions
    per sample and a 16-bit accumulator. No FPGA matrix or host conversion.
    """
    for phase in range(32):
        angle = (phase + 0.5) * math.tau / 32
        s, c = math.sin(angle), math.cos(angle)
        for y, u, v in ((.299, -.493*.299, .877*(1-.299)),
                         (.587, -.493*.587, -.877*.587),
                         (.114, .493*(1-.114), -.877*.114)):
            gain = round(34*512/255*(y+u*s+v*c))
            assert -128 <= gain <= 127
            yield gain


def ham_samples():
    """HAM8 component contributions, fitting the existing RAM.

    3 channels x 64 levels x 32 phases. Six-bit samples are biased by
    R=12, G=1, B=12; the encoder sums them and subtracts ten, including
    the DAC black pedestal of fifteen. Native HD6303 computes these with
    the same signed Q9 coefficients, one MUL per sample.
    """
    gains = list(palette_coefficients())
    for channel, bias in enumerate((12, 1, 12)):
        for level in range(64):
            value = (level << 2) | (level >> 4)
            for phase in range(32):
                sample = bias + (gains[phase*3+channel]*value+256)//512
                assert 0 <= sample < 64
                yield sample
