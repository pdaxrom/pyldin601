from pathlib import Path
import struct
import sys
import unittest

TOOLS=Path(__file__).resolve().parents[1]/'tools'
sys.path.insert(0,str(TOOLS))
import add_disk_files as files
import make_sd as sd


class DiskFileTests(unittest.TestCase):
    def test_fragmented_allocation_keeps_existing_files_and_fat_nibbles(self):
        original=files.add_files(sd.blank_disk(),{'KEEP.TXT':bytes(range(256))*8})
        info,table,start,size,copies,root,entries,data=files.layout(original)
        volume=bytearray(original)
        # Reserve alternating clusters to force a fragmented new file.
        for cluster in (7,9,11):files.fat_set(table,cluster,0xff7)
        for copy in range(copies):volume[start+copy*size:start+(copy+1)*size]=table
        payload=bytes(range(256))*6+b'last'
        updated=files.add_files(volume,{'CHECK.CMD':payload,'EMPTY.TXT':b''})
        self.assertEqual(files.root_files(updated),{'KEEP.TXT':bytes(range(256))*8,'CHECK.CMD':payload,'EMPTY.TXT':b''})
        self.assertEqual(updated[:512],original[:512])
        self.assertEqual(updated[root:root+32],original[root:root+32])
        self.assertEqual(updated[data:data+2048],original[data:data+2048])
        new_table=files.layout(updated)[1]
        for cluster in (7,9,11):self.assertEqual(files.fat_get(new_table,cluster),0xff7)
        self.assertEqual(files.fat_get(new_table,6),8)
        self.assertEqual(files.fat_get(new_table,8),10)

    def test_reject_conflicting_names_copies_and_full_disk(self):
        disk=files.add_files(sd.blank_disk(),{'ONE.CMD':b'first'})
        with self.assertRaisesRegex(ValueError,'already exists'):files.add_files(disk,{'ONE.CMD':b'second'})
        with self.assertRaisesRegex(ValueError,'8.3'):files.add_files(disk,{'TOO-LONG-NAME.CMD':b'x'})
        corrupted=bytearray(disk);_,table,start,size,copies,*_=files.layout(disk)
        corrupted[start+size+3]^=1
        with self.assertRaisesRegex(ValueError,'copies differ'):files.add_files(corrupted,{'TWO.CMD':b'x'})
        with self.assertRaisesRegex(ValueError,'full'):files.add_files(disk,{'HUGE.CMD':b'x'*(1440*1024)})

    def test_sd_b_preserves_mbr_boot_a_tail_and_b_contents(self):
        a=files.add_files(sd.blank_disk(size=720*1024,spt=9),{'A.TXT':b'original A'})
        b=files.add_files(sd.blank_disk(),{'B.TXT':b'original B'})
        image=bytearray(5*1024*1024)
        image[-64:]=b'TAIL'*16
        parts=((2048,32,6),(4096,len(a)//512,1),(6144,len(b)//512,1))
        image[510:512]=b'\x55\xaa'
        for n,(lba,sectors,kind) in enumerate(parts):
            struct.pack_into('<B3sB3sII',image,446+n*16,0,b'\0'*3,kind,b'\0'*3,lba,sectors)
        image[2048*512:(2048+32)*512]=b'boot'*4096
        image[4096*512:4096*512+len(a)]=a
        image[6144*512:6144*512+len(b)]=b
        result,report=files.install(image,{'TEST.CMD':b'command'})
        start,end=6144*512,6144*512+len(b)
        self.assertEqual(result[:start],image[:start]);self.assertEqual(result[end:],image[end:])
        self.assertEqual(files.root_files(result[start:end]),{'B.TXT':b'original B','TEST.CMD':b'command'})
        self.assertTrue(report['mbr_and_other_partitions_preserved'])


if __name__=='__main__':unittest.main()
