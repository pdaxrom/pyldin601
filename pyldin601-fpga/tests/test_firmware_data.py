"""UniAS PGM packaging must preserve code/relocations and reject invalid tails."""
import hashlib
import json
import random
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
TOOL=ROOT/'build/firmware-data'


class FirmwareDataTests(unittest.TestCase):
    def test_shell_roundtrip_and_malformed_streams(self):
        raw=(ROOT/'build/partitions/SHELL.CMD').read_bytes()
        packed=(ROOT/'build/partitions/SHELL.PACKED').read_bytes()
        info=json.loads((ROOT/'build/partitions/shell-pack.json').read_text())
        self.assertEqual(info['source_sha256'],hashlib.sha256(raw).hexdigest())
        self.assertEqual(info['packed_sha256'],hashlib.sha256(packed).hexdigest())
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder);source=folder/'packed';output=folder/'raw'
            source.write_bytes(packed)
            subprocess.run([str(TOOL),'shell-unpack',str(source),str(output)],check=True)
            self.assertEqual(output.read_bytes(),raw)
            output.unlink()
            invalid=[packed[:n] for n in (0,1,2,5,len(packed)//2,len(packed)-1)]
            invalid += [packed+b'\x00',b'\x02\x00\xff\xff',b'\x00\x00\xff']
            for data in invalid:
                source.write_bytes(data)
                result=subprocess.run([str(TOOL),'shell-unpack',str(source),str(output)],capture_output=True)
                self.assertNotEqual(result.returncode,0,result.stdout)
                self.assertFalse(output.exists())

    def test_shell_pack_rejects_page_overflow_before_writing(self):
        rng=random.Random(6303)
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder);source=folder/'input'
            outputs=[folder/name for name in ('packed','include','info')]
            for data in (b'',bytes(16001),bytes(rng.randrange(256) for _ in range(10000))):
                source.write_bytes(data)
                result=subprocess.run([str(TOOL),'shell',str(source),*(str(p) for p in outputs)],capture_output=True)
                self.assertNotEqual(result.returncode,0,result.stdout)
                self.assertEqual(source.read_bytes(),data)
                self.assertTrue(all(not p.exists() for p in outputs))

    def run_pgm(self, data, trim, succeeds):
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder)
            source=folder/'input.pgm';output=folder/'output.pgm';metadata=folder/'info.json'
            source.write_bytes(data)
            result=subprocess.run([str(TOOL),'pgm',str(source),str(output),
                str(ROOT/'build/game/ARKANOID.PGM.LST'),str(metadata),trim],capture_output=True)
            self.assertEqual(result.returncode==0,succeeds,result.stderr)
            self.assertEqual(source.read_bytes(),data)
            if not succeeds:
                self.assertFalse(output.exists())
                return None
            info=json.loads(metadata.read_text())
            self.assertEqual(info['sha256'],hashlib.sha256(output.read_bytes()).hexdigest())
            return output.read_bytes()

    def test_real_unias_bss_pack_is_exact(self):
        expected=(ROOT/'build/game/ARKANOID.PGM').read_bytes()
        fields=list(struct.unpack('>8H',expected[:16]));scratch=fields[5]
        fields[3]+=scratch;fields[5]=0
        raw=struct.pack('>8H',*fields)+expected[16:]+bytes(scratch)
        self.assertEqual(self.run_pgm(raw,'auto',True),expected)
        damaged=raw[:-1]+b'\x01'
        self.run_pgm(damaged,'auto',False)

    def test_relocation_past_code_is_rejected(self):
        data=bytearray((ROOT/'build/game/ARKANOID.PGM').read_bytes())
        data[16:18]=data[6:8]
        self.run_pgm(data,'0',False)

    def test_ps2_missing_and_duplicate_codes(self):
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder);source=folder/'keys.csv';output=folder/'keys.mem'
            source.write_text('set2,set1,key\n1c,1e,A\n5a,1c,Enter\n')
            subprocess.run([str(TOOL),'ps2',str(source),str(output)],check=True)
            values=[int(n,16) for n in output.read_text().split()]
            self.assertEqual(len(values),256)
            self.assertEqual(values[0x1c],0x1e)
            self.assertEqual(values[0x5a],0x1c)
            self.assertTrue(all(v==255 for i,v in enumerate(values) if i not in (0x1c,0x5a)))
            source.write_text('set2,set1,key\n1c,1e,A\n1c,30,B\n')
            result=subprocess.run([str(TOOL),'ps2',str(source),str(output)],capture_output=True)
            self.assertNotEqual(result.returncode,0)
