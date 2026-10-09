"""Frozen Python reference for HG wire framing and the former mirror format.

The production daemon is C; test_hg_host.c/test_hg_watch.py exercise that code.
"""
import datetime
import importlib.util
from pathlib import Path
import struct
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'host/hg'))
spec=importlib.util.spec_from_file_location('hg_reference',ROOT/'tests/hg_reference.py')
hg=importlib.util.module_from_spec(spec);spec.loader.exec_module(hg)


def header(op,block=0,count=512,version=1):
    data=b'HG'+bytes((version,))+struct.pack('<BBHH',op,0,block,count)
    xor=0
    for byte in data:xor^=byte
    return data+bytes((xor,))


class Link:
    def __init__(self,incoming):self.incoming=bytearray(incoming);self.out=bytearray();self.selected=False
    def select(self,value):self.selected=value
    def exchange(self,data=None,count=None):
        assert self.selected
        if data is not None:self.out.extend(data);return bytes(len(data))
        result=bytes(self.incoming[:count]);del self.incoming[:count]
        assert len(result)==count
        return result
    def wait_phase(self,value,mask):pass
    def exchange_packet(self,data=None,count=None):return self.exchange(data,count)
    def exchange_flow(self,data=None,count=None):
        self.select(True)
        result=self.exchange(data,count)
        self.select(False)
        return result


class HostTests(unittest.TestCase):
    def test_disk_status_checksum_and_time(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'disk.img';path.write_bytes(hg.fat12.blank_disk())
            volume=hg.Volume(path)
            original=volume.read(0,512)
            link=Link(header(1));self.assertFalse(hg.serve_one(link,volume))
            self.assertEqual(link.out,b'\0'+hg.checked_payload(original));self.assertFalse(link.selected)
            data=bytes(n&255 for n in range(512))
            link=Link(header(2,100)+hg.checked_payload(data));self.assertTrue(hg.serve_one(link,volume))
            self.assertEqual(link.out,b'\0\0');self.assertEqual(volume.read(100,512),data)
            link=Link(header(2,100)+bytes(514));link.incoming[-1]=1
            hg.serve_one(link,volume);self.assertEqual(link.out,b'\0'+bytes((hg.CHECKSUM,)))
            self.assertEqual(volume.read(100,512),data)
            link=Link(header(1,65535));hg.serve_one(link,volume);self.assertEqual(link.out,bytes((hg.RANGE,)))
            now=datetime.datetime(2026,10,8,19,14,25,440000)
            link=Link(header(3,50,6));hg.serve_one(link,volume,now)
            self.assertEqual(link.out,b'\0'+hg.checked_payload(hg.host_time(50,now)))
            for op,block,count in [(1,100,512),(2,100,512),(3,50,6)]:
                incoming=header(op,block,count,2)+(hg.checked_payload(data) if op==2 else b'')
                link=Link(incoming);hg.serve_one(link,volume,now)
                expected=b'\0\0' if op==2 else b'\0'+hg.checked_payload(data if op==1 else hg.host_time(50,now))
                self.assertEqual(link.out,expected);self.assertFalse(link.selected)
            for hdr in [header(3,51,6),header(3,50,5),header(9),header(0x81),header(1)[:-1]+b'\xff']:
                link=Link(hdr);hg.serve_one(link,volume);self.assertEqual(link.out,bytes((hg.PROTOCOL,)))
            volume.close();volume=hg.Volume(path,True)
            link=Link(header(2,100));hg.serve_one(link,volume);self.assertEqual(link.out,bytes((hg.READ_ONLY,)))
            volume.close()

    def test_fat12_directory_roundtrip(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory=Path(tmp);(directory/'hello.txt').write_bytes(b'hello\r\n')
            volume=hg.DirectoryVolume(directory)
            self.assertEqual(volume.info['sectors'],32736)
            self.assertEqual(volume.info['clusters'],4084)
            self.assertEqual(hg.fat12.root_files(volume.path.read_bytes())['HELLO.TXT'],b'hello\r\n')
            changed=hg.fat12.add_files(volume.path.read_bytes(),{'BACK.TXT':b'new file\r\n'})
            for offset in range(0,len(changed),512):
                if changed[offset:offset+512]!=volume.read(offset//512,512):volume.write(offset//512,changed[offset:offset+512])
            volume.export();self.assertEqual((directory/'BACK.TXT').read_bytes(),b'new file\r\n')
            self.assertEqual((directory/'hello.txt').read_bytes(),b'hello\r\n')
            # Delete only the mirrored file through a FAT directory change.
            data=bytearray(volume.path.read_bytes());root=hg.fat12.layout(data)[5]
            entry=next(p for p in range(root,root+512*32,32) if data[p:p+11]==b'BACK    TXT')
            data[entry]=0xe5;volume.write(entry//512,data[(entry//512)*512:(entry//512+1)*512]);volume.export()
            self.assertFalse((directory/'BACK.TXT').exists());volume.close()

    def test_geometry_and_directory_recovery(self):
        self.assertEqual(hg.fat12.disk_info(hg.fat12.blank_disk(32400))['clusters'],4042)
        with self.assertRaises(ValueError):hg.fat12.blank_disk(32737)
        with tempfile.TemporaryDirectory() as tmp:
            directory=Path(tmp);(directory/'README').write_bytes(b'no extension')
            volume=hg.DirectoryVolume(directory)
            with self.assertRaises(BlockingIOError):hg.DirectoryVolume(directory)
            changed=hg.fat12.add_files(volume.path.read_bytes(),{'RECOVER.TXT':b'durable guest data'})
            for offset in range(0,len(changed),512):
                block=changed[offset:offset+512]
                if block!=volume.read(offset//512,512):volume.write(offset//512,block)
            volume.close()  # crash before export; the pending journal must be replayed
            self.assertFalse((directory/'RECOVER.TXT').exists())
            recovered=hg.DirectoryVolume(directory)
            self.assertEqual((directory/'RECOVER.TXT').read_bytes(),b'durable guest data')
            self.assertEqual((directory/'README').read_bytes(),b'no extension')
            recovered.close()

    def test_time_limits(self):
        for hz in (50,60):
            for year in (1972,2003,2004,2026,2035):
                now=datetime.datetime(year,2,28,23,59,59,980000)
                date,high,low=struct.unpack('<HHH',hg.host_time(hz,now))
                self.assertEqual(1972+(date>>14)*32+(date&31),year)
                self.assertLess(high*65536+low,86400*hz)
        with self.assertRaises(ValueError):hg.host_time(50,datetime.datetime(2036,1,1))

    def test_credit_phase_wait(self):
        link=hg.Mpsse.__new__(hg.Mpsse)
        phases=iter((0xff,0xff,0x9a))
        link.exchange_packet=lambda count:bytes((next(phases),))
        link.wait_phase(0x9a,0x9e)
        link.exchange_packet=lambda count:b'\xcb'
        with self.assertRaises(OSError):link.wait_phase(0x8b,0x9f)

    def test_mpsse_wire_and_open_drain(self):
        link=hg.Mpsse.__new__(hg.Mpsse)
        link.value=0;link.direction=0x0b;link.jtag_controlled=False
        sent=[];link.write=lambda data:sent.append(data)
        link.read=lambda n:b'\xa5'*n
        link.pins=lambda:0x80 if not link.direction&0x80 else 0
        link.jtag_enable(False);self.assertEqual(sent[-1],b'\x80\0\x8b')
        link.jtag_enable(True);self.assertEqual(sent[-1],b'\x80\0\x0b')
        self.assertEqual(link.exchange(b'\x53\x19'),b'\xa5\xa5')
        self.assertEqual(sent[-2:],[b'\x39\0\0\x53\x87',b'\x39\0\0\x19\x87'])
        self.assertEqual(link.exchange_packet(bytes(range(32))),b'\xa5'*32)
        self.assertEqual(sent[-1],b'\x39\x1f\0'+bytes(range(32))+b'\x87')
        for size in (0,33):
            with self.assertRaises(ValueError):link.exchange_packet(count=size)
        packets=[];credits=[]
        link.wait_phase=lambda value,mask:credits.append((value,mask))
        link.exchange_packet=lambda data,count:packets.append((data,count)) or bytes(count)
        wire=hg.checked_payload(bytes(range(256))*2)
        self.assertEqual(len(link.exchange_flow(wire)),514)
        self.assertEqual([n for _,n in packets],[32]*16+[2])
        self.assertEqual(b''.join(d for d,_ in packets),wire)
        self.assertEqual(credits,[(0x8b,0x9f)]*17);self.assertFalse(link.value&8)


if __name__=='__main__':unittest.main()
