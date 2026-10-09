"""Private native UniDOS fixture; never edits the distributed SD image."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root/'tools'))
import add_disk_files
import make_sd

work = root/'build/clip-sprites'
work.mkdir(parents=True, exist_ok=True)
image = bytearray((root/'images/sd.img').read_bytes())
begin = int.from_bytes(image[486:490], 'little')*512
end = begin+int.from_bytes(image[490:494], 'little')*512
files = add_disk_files.root_files(image[begin:end])
files['CLIPSPR.PGM'] = (root/'build/gfx/CLIPSPR.PGM').read_bytes()
info = make_sd.disk_info(image[begin:end])
image[begin:end] = add_disk_files.add_files(
    make_sd.blank_disk(end-begin, info['sectors_per_track'], info['heads']), files)
(work/'sd.img').write_bytes(image)
