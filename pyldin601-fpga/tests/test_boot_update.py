import hashlib
import importlib.util
from pathlib import Path
import struct
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
sys.path.insert(0, str(TOOLS))
import make_sd as sd
import update_boot as update


class BootUpdateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        project = TOOLS.parent
        disk = sd.blank_disk()
        image, _ = sd.build(project.parent/'native', [disk, disk])
        # User data written after creating the card must survive the update.
        cls.backup = bytearray(image)
        a_start = sd.u32(image, 462+8) * 512
        cls.backup[a_start+2048:a_start+2056] = b'USERDATA'
        cls.bios = (project.parent/'native-src/BIOS_A.ROM').read_bytes()
        spec = importlib.util.spec_from_file_location('assembler', TOOLS/'asm6800.py')
        assembler = importlib.util.module_from_spec(spec);spec.loader.exec_module(assembler)
        cls.loader, _ = assembler.assemble((project/'firmware/loader.asm').read_text(), 0x2000)

    def test_update_preserves_user_disks_and_classic_rom(self):
        volume, metadata = update.prepare(self.backup, self.bios, self.loader)
        offset = metadata['start_lba'] * 512
        after = self.backup[:offset]+volume+self.backup[offset+len(volume):]
        self.assertEqual(after[:offset], self.backup[:offset])
        self.assertEqual(after[offset+len(volume):], self.backup[offset+len(volume):])
        before_files = update.root_files(self.backup[offset:offset+len(volume)])
        files = update.root_files(volume)
        self.assertEqual(files['P601.ROM'], before_files['P601.ROM'])
        self.assertEqual(files['LOADER.BIN'], self.loader)
        alternate = files['P601A.ROM']
        self.assertEqual(alternate[25], 1)
        self.assertEqual(alternate[512+0x50000:512+0x51000], self.bios)
        self.assertEqual(alternate[512:512+0x50000], files['P601.ROM'][512:512+0x50000])
        self.assertEqual(alternate[512+0x51000:], files['P601.ROM'][512+0x51000:])
        self.assertEqual(metadata['preserved_classic_rom_sha256'], hashlib.sha256(files['P601.ROM']).hexdigest())

    def test_rejects_truncated_backup_and_wrong_geometry(self):
        with self.assertRaises(ValueError):
            update.prepare(self.backup[:17*1024*1024], self.bios, self.loader)
        changed = bytearray(self.backup)
        struct.pack_into('<I', changed, 462+8, sd.u32(changed,462+8)+1)
        with self.assertRaises(ValueError):
            update.prepare(changed, self.bios, self.loader)


if __name__ == '__main__':
    unittest.main()
