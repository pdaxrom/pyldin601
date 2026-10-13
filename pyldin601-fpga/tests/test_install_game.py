"""Release migration preserves the actual ready image and native ROM pages."""
import sys
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from install_game import prepare, prepare_apps, game_files
from sd_partitions import scan
from update_boot import root_files
from add_disk_files import root_files as fat12_files


class GameInstallTests(unittest.TestCase):
    def test_game_update_preserves_other_volumes_and_old_programs(self):
        old = (ROOT / 'images/sd.img').read_bytes()
        regions, report = prepare(old)
        new = bytearray(old)
        for offset, volume in regions:
            new[offset:offset+len(volume)] = volume
        self.assertEqual(old[:2048*512], new[:2048*512])
        parts = scan(old, max_logical=32)
        self.assertEqual(parts, scan(new, max_logical=32))
        for p in parts:
            start, end = p.start*512, (p.start+p.sectors)*512
            if p.number not in (1, 3):
                self.assertEqual(old[start:end], new[start:end])
        b = next(p for p in parts if p.number == 3)
        before = fat12_files(old[b.start*512:(b.start+b.sectors)*512])
        after = fat12_files(new[b.start*512:(b.start+b.sectors)*512])
        programs = game_files()
        for name, content in programs.items():
            self.assertEqual(after[name], content)
        for name, content in before.items():
            if name not in programs:
                self.assertEqual(after[name], content)
        boot = next(p for p in parts if p.number == 1)
        before = root_files(old[boot.start*512:(boot.start+boot.sectors)*512])
        after = root_files(new[boot.start*512:(boot.start+boot.sectors)*512])
        for name in before:
            if name not in ('P601.ROM', 'P601A.ROM'):
                self.assertEqual(before[name], after[name])
        self.assertEqual(report['gamebios_context_bytes'], 416)
        self.assertTrue(report['native_boot_sector_preserved'])
        self.assertTrue(report['fpga_update_required'])
        self.assertEqual(report['fpga_min_graphics_revision'], 6)
        self.assertEqual(report['ps2_raw_identity'], 0x52)

    def test_apps_only_preserves_boot_and_records(self):
        from add_disk_files import install
        old = (ROOT / 'images/sd.img').read_bytes()
        old, _ = install(old, {'ARKSCORE.DAT': b'previous scores',
                              'XONSCORE.BAK': b'backup scores',
                              'XONIX.CFG': b'LENA.IFF\nOTHER.IFF\n'}, replace=True)
        regions, report = prepare_apps(old)
        new = bytearray(old)
        self.assertEqual(len(regions), 1)
        for offset, data in regions:
            new[offset:offset+len(data)] = data
        b = next(p for p in scan(old, max_logical=32) if p.number == 3)
        start, end = b.start*512, (b.start+b.sectors)*512
        self.assertEqual(old[:start], new[:start])
        self.assertEqual(old[end:], new[end:])
        files = fat12_files(new[start:end])
        self.assertEqual(files['ARKSCORE.DAT'], b'previous scores')
        self.assertEqual(files['XONSCORE.BAK'], b'backup scores')
        self.assertEqual(files['XONIX.CFG'], b'LENA.IFF\nOTHER.IFF\n')
        self.assertTrue(report['existing_xonix_config_preserved'])
        self.assertFalse(report['rom_update_required'])
        self.assertTrue(report['fpga_update_required'])
        self.assertEqual(report['fpga_min_graphics_revision'], 6)


if __name__ == '__main__':
    unittest.main()
