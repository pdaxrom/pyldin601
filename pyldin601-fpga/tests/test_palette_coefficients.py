"""Bound native fixed-point PAL errors over the entire RGB888 colour cube."""
from itertools import product
import math
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
import make_pal

generated = list(make_pal.palette_coefficients())
encoded = [int(n, 16) for n in re.findall(r'\$([0-9a-f]{2})', (ROOT/'firmware/gfx/PALCOEF.ASM').read_text())]
actual = [n if n < 128 else n-256 for n in encoded]
assert actual == generated and len(actual) == 96
largest_error = 0
for phase in range(32):
    theta = (phase+.5)*math.tau/32
    s, c = math.sin(theta), math.cos(theta)
    # Independent expansion of the PAL RGB/YUV matrix; affine extrema occur
    # at cube corners. This bound covers all 16,777,216 RGB inputs per phase.
    weights = [34/255*(y+u*s+v*c) for y, u, v in (
        (.299, -.147407, .614777), (.587, -.289391, -.514799),
        (.114, .436798, -.099978))]
    gains = actual[phase*3:phase*3+3]
    errors = [255*(q/512-f) for q, f in zip(gains, weights)]
    bound = max(-sum(e for e in errors if e < 0), sum(e for e in errors if e > 0))
    assert bound < 1, (phase, bound)
    largest_error = max(largest_error, bound)
    for rgb in product((0, 255), repeat=3):
        acc = 15*512+256+sum(v*q for v, q in zip(rgb, gains))
        assert 512 <= acc < 32768, (phase, rgb, acc)
    for rgb in product(range(0, 256, 17), repeat=3):
        sample = (15*512+256+sum(v*q for v, q in zip(rgb, gains)))//512
        reference = round(15+sum(v*f for v, f in zip(rgb, weights)))
        assert abs(sample-reference) <= 1 and 0 < sample < 64
print(f'PASS native Q9 PAL: all RGB888 inputs bounded, signed MUL/16-bit accumulator safe, gain error <= {largest_error:.9f} DAC codes, rounded error <= 1')
