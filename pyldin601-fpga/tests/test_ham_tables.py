"""Independent bounds for the HAM8 six-bit PAL component RAM."""
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
import make_pal


def prepare():
    work = ROOT/'build/ham'
    work.mkdir(parents=True, exist_ok=True)
    samples = bytes(make_pal.ham_samples())
    (work/'components.bin').write_bytes(samples)
    (work/'components.mem').write_text(''.join(f'{n:02x}\n' for n in samples))
    return samples


class HAMTables(unittest.TestCase):
    def test_complete_component_cube_and_pal_bound(self):
        table = bytes(make_pal.ham_samples())
        self.assertEqual(len(table), 6144)
        self.assertLessEqual(max(table), 63)
        worst = 0
        # Per-channel error extrema add independently: this bounds all
        # 64^3 RGB states at each of the 32 phases, without sampling the cube.
        for phase in range(32):
            theta = (phase+.5)*math.tau/32
            weights = [34/255*(y+u*math.sin(theta)+v*math.cos(theta))
                       for y, u, v in ((.299, -.147407, .614777),
                                      (.587, -.289391, -.514799),
                                      (.114, .436798, -.099978))]
            limits = []
            for channel in range(3):
                bias = (12, 1, 12)[channel]
                errors = [table[channel*2048+level*32+phase]-bias
                          -weights[channel]*(4*level+level//16)
                          for level in range(64)]
                limits.append((min(errors), max(errors)))
                self.assertEqual(table[channel*2048+phase], bias)
            bound = max(abs(sum(n[0] for n in limits)), abs(sum(n[1] for n in limits)))
            self.assertLess(bound, 2.1)
            worst = max(worst, bound)
            lows = [min(table[ch*2048+level*32+phase] for level in range(64)) for ch in range(3)]
            highs = [max(table[ch*2048+level*32+phase] for level in range(64)) for ch in range(3)]
            self.assertGreaterEqual(sum(lows)-10, 0)
            self.assertLessEqual(sum(highs)-10, 63)
        print(f'PASS HAM component tables: all 262144 RGB states bounded at 32 PAL phases; maximum continuous-matrix error {worst:.6f} DAC codes; no wrap/clipping')



if __name__ == '__main__':
    prepare()
    unittest.main()
