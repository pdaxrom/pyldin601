"""Install the real assembled demo in a private native UniDOS test image."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from add_disk_files import install

out = ROOT / 'build/gfxmusic'
out.mkdir(parents=True, exist_ok=True)
image, _ = install((ROOT / 'build/audio/sd-test.img').read_bytes(),
                   {'GFXMUSIC.PGM': (ROOT / 'build/audio/GFXMUSIC.PGM').read_bytes()}, replace=True)
(out / 'sd-test.img').write_bytes(image)
