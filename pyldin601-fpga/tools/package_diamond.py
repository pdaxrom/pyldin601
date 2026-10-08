"""Freeze a self-contained Diamond input archive and per-file hashes."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument("--name", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
paths = [root / "Makefile", root / "build-diamond.tcl", root / "build/boot.mem"]
paths += list(root.glob("pyldin601_classic.*"))
paths += [p for sub in ("rtl", "firmware") for p in (root / sub).rglob("*") if p.is_file()]
out = root / "build/diamond"
out.mkdir(parents=True, exist_ok=True)
manifest = {}
with tarfile.open(out / f"source-{args.name}.tar.gz", "w:gz") as archive:
    for path in sorted(paths):
        name = path.relative_to(root).as_posix()
        data = path.read_bytes()
        manifest[name] = hashlib.sha256(data).hexdigest()
        entry = tarfile.TarInfo(name)
        entry.size = len(data)
        entry.mode = 0o644
        archive.addfile(entry, io.BytesIO(data))
(out / f"source-{args.name}.sha256.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
print(out / f"source-{args.name}.tar.gz")
