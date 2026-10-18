"""Release integrity: nested FAT data, aliasing, stale FPGA and corruption."""
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import package_release as release
from add_disk_files import add_files, fat_set, layout
from make_sd import blank_disk


class FATIntegrityTests(unittest.TestCase):
    def test_file_chain_readback(self):
        files = {'EMPTY.TXT': b'', 'BIG.BIN': bytes(range(256)) * 300}
        self.assertEqual(release.fat12_tree(add_files(blank_disk(), files)), files)

    def test_shared_chain_is_rejected(self):
        image = bytearray(add_files(blank_disk(), {'ONE.BIN': b'one', 'TWO.BIN': b'two'}))
        _, _, _, _, _, root, _, _ = layout(image)
        image[root + 32 + 26:root + 32 + 28] = image[root + 26:root + 28]
        with self.assertRaisesRegex(ValueError, 'shared FAT12'):
            release.fat12_tree(image)

    def test_overlong_chain_is_rejected(self):
        image = bytearray(add_files(blank_disk(), {'ONE.BIN': b'one'}))
        _, table, start, size, copies, _, _, _ = layout(image)
        fat_set(table, 2, 3)
        fat_set(table, 3, 0xfff)
        for i in range(copies):
            image[start + i * size:start + (i + 1) * size] = table
        with self.assertRaisesRegex(ValueError, 'size/chain mismatch'):
            release.fat12_tree(image)


class FPGAProvenanceTests(unittest.TestCase):
    def test_changed_and_new_rtl_require_new_routed_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'project'
            evidence = Path(temporary) / 'evidence'
            evidence.mkdir()
            names = ['rtl/example.v', 'build/boot.mem', 'build-diamond.tcl',
                     'pyldin601_classic.ldf', 'pyldin601_classic.lpf', 'pyldin601_classic.sty']
            inputs = {}
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'original')
                inputs[name] = release.sha(path.read_bytes())
            release.write_json(evidence / 'routed-inputs.json', inputs)
            jed = b'test JED'
            (evidence / 'pyldin601_classic_impl1.jed').write_bytes(jed)
            record = dict(jed_sha256=release.sha(jed), timing_passed=True,
                          lut4=1, slices=1, pfu_registers=1, ebr=1, pll=1)
            release.write_json(evidence / 'validated-build.json', record)
            (evidence / 'pyldin601_classic_impl1.twr').write_text(
                'Cumulative negative slack: 0.000\n0 unconstrained paths found\n')
            release.checked_fpga(root, evidence)
            (root / 'rtl/example.v').write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'inputs differ'):
                release.checked_fpga(root, evidence)
            (root / 'rtl/example.v').write_bytes(b'original')
            (root / 'rtl/new.v').write_bytes(b'new module')
            with self.assertRaisesRegex(ValueError, 'incomplete routed'):
                release.checked_fpga(root, evidence)


@unittest.skipUnless(os.environ.get('P601_RELEASE_DIR'), 'set P601_RELEASE_DIR for package integration checks')
class PackageIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name) / 'release'
        shutil.copytree(os.environ['P601_RELEASE_DIR'], self.path)

    def test_complete_release_readback(self):
        release.verify(self.path)

    def test_corrupted_paint_is_rejected(self):
        path = self.path / 'hg/PAINT.PGM'
        data = bytearray(path.read_bytes())
        data[-1] ^= 1
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
            release.verify(self.path)

    def test_incomplete_nc_bundle_is_rejected_even_with_updated_manifest(self):
        path = self.path / 'release.json'
        data = json.loads(path.read_text())
        data['files'].pop('hg/NCMAIN.PGM')
        path.write_text(json.dumps(data))
        (self.path / 'hg/NCMAIN.PGM').unlink()
        with self.assertRaisesRegex(ValueError, 'incomplete application'):
            release.verify(self.path)

    def test_manifest_cannot_escape_release_directory(self):
        path = self.path / 'release.json'
        data = json.loads(path.read_text())
        data['files']['../outside'] = {'bytes': 0, 'sha256': release.sha(b'')}
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'unsafe manifest path'):
            release.verify(self.path)


if __name__ == '__main__':
    unittest.main()
