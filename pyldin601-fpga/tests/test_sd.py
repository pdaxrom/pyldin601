import importlib.util
from pathlib import Path
import struct
import unittest
import zlib

spec = importlib.util.spec_from_file_location('make_sd', Path(__file__).parents[1]/'tools/make_sd.py')
sd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sd)


def root_files(volume):
    reserved, spf = sd.u16(volume,14), sd.u16(volume,22)
    root = (reserved+volume[16]*spf)*512
    data_start = root+sd.u16(volume,17)*32
    files = {}
    for off in range(root, data_start, 32):
        if volume[off] == 0:
            break
        name = volume[off:off+11].decode('ascii')
        cluster, size = sd.u16(volume,off+26), sd.u32(volume,off+28)
        result, seen = bytearray(), set()
        while cluster < 0xfff8:
            if cluster in seen or cluster < 2:
                raise ValueError('bad FAT chain')
            seen.add(cluster)
            pos = data_start+(cluster-2)*512
            result += volume[pos:pos+512]
            cluster = sd.u16(volume,reserved*512+cluster*2)
        files[name] = bytes(result[:size])
    return files


class SDTests(unittest.TestCase):
    def test_large_fat12_last_cluster(self):
        disk = sd.blank_disk(sd.MAX_DISK_SIZE,96,2)
        info = sd.disk_info(disk)
        self.assertEqual(info['sectors'],24576)
        self.assertEqual(info['cylinders'],128)
        self.assertEqual(info['sectors_per_track'],96)
        self.assertLess(info['clusters'],4085)
        self.assertEqual(((127*2+1)*96+96-1),24575)

    def test_reject_invalid_geometry_and_fat(self):
        disk = bytearray(sd.blank_disk(sd.MAX_DISK_SIZE,96,2))
        struct.pack_into('<H',disk,24,0)
        with self.assertRaises(ValueError): sd.disk_info(disk)
        disk = bytearray(sd.blank_disk(sd.MAX_DISK_SIZE,96,2))
        disk[13] = 1
        with self.assertRaises(ValueError): sd.disk_info(disk)
        disk = bytearray(sd.blank_disk(sd.MAX_DISK_SIZE,96,2))
        struct.pack_into('<H',disk,19,30000)
        with self.assertRaises(ValueError): sd.disk_info(disk)

    def test_fat16_roundtrip(self):
        files = {'SMALL.BIN':b'abc', 'LARGE.BIN':bytes(range(256))*100}
        volume = sd.fat16(files)
        clusters = (sd.u16(volume,19)-1-2*sd.u16(volume,22)-32)//volume[13]
        self.assertTrue(4085 <= clusters < 65525)
        self.assertEqual(root_files(volume),{'SMALL   BIN':files['SMALL.BIN'],
                                             'LARGE   BIN':files['LARGE.BIN']})

    def test_manifest_and_mirrors(self):
        native = Path(__file__).parents[1]/'tests/native_fixture'
        native.joinpath('Bios').mkdir(parents=True,exist_ok=True)
        native.joinpath('RAMROMDiskPipnet').mkdir(exist_ok=True)
        bios = bytearray([0xaa])*4096
        bios[0xff7] = 0
        native.joinpath('Bios/bios.roz').write_bytes(bios)
        native.joinpath('Bios/video.roz').write_bytes(bytes([0xbb])*2048)
        for i in range(5):
            native.joinpath(f'RAMROMDiskPipnet/rom{i}.roz').write_bytes(bytes([i])*32768)
        files = sd.rom_files(native)
        self.assertEqual(len(files['ROM4.BIN']),65536)
        self.assertEqual(files['ROM4.BIN'][:32768],files['ROM4.BIN'][32768:])
        disk = sd.blank_disk()
        bios[0xff7] = 0x80
        a_path = native/'BIOS_A.ROM'
        a_path.write_bytes(bios)
        image, config = sd.build(native,[disk,disk],1,bios_a=a_path)
        first = image[2048*512:(2048+sd.BOOT_SECTORS)*512]
        contents = root_files(first)
        bundle = contents['P601    ROM']
        self.assertEqual(bundle[:8],b'P601BOOT')
        self.assertEqual(bundle[24],1)
        self.assertEqual(bundle[25],0)
        alternate = contents['P601A   ROM']
        self.assertEqual(alternate[25],1)
        self.assertEqual(alternate[512+5*65536:512+5*65536+4096],bios)
        self.assertEqual(sd.u32(alternate,508),zlib.crc32(alternate[:508]))
        self.assertEqual(sd.u32(alternate,20),zlib.crc32(alternate[512:]))
        with self.assertRaises(ValueError):
            sd.bundle({**files, 'BIOS.BIN':bytes(bios)}, config['drives'],1,0)
        self.assertEqual(config['models'],['601','601A'])
        self.assertEqual(sd.u32(bundle,508),zlib.crc32(bundle[:508]))
        self.assertEqual(sd.u32(bundle,20),zlib.crc32(bundle[512:]))
        for i, drive in enumerate(config['drives']):
            start = sd.u32(image,446+(i+1)*16+8)
            self.assertEqual(start,drive['start_lba'])
            self.assertEqual(image[start*512:(start+len(disk)//512)*512],disk)
        # Remove only test-owned fixtures; source files are never touched.
        for p in native.rglob('*'):
            if p.is_file(): p.unlink()
        native.joinpath('Bios').rmdir();native.joinpath('RAMROMDiskPipnet').rmdir();native.rmdir()


if __name__ == '__main__': unittest.main()
