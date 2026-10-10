import sys,struct,unittest,mmap,tempfile,zlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import sd_partitions as p
import add_disk_files as a
import make_sd as sd
import migrate_sd as migration
class Partitions(unittest.TestCase):
 def image(self):
  im=bytearray(100352*512);im[510:512]=b'\x55\xaa'
  p.put_entry(im,0,0,1,2048,p.TOTAL,True)
  im[2048*512:(2048+p.TOTAL)*512]=p.fat12('ANOTHER',0x12345678)
  p.put_entry(im,0,3,15,40000,60000)
  for ebr,next_,start in [(40000,78000,42048),(78000,74000,80048),(74000,0,76048)]:
   im[ebr*512+510:ebr*512+512]=b'\x55\xaa'
   p.put_entry(im,ebr,0,1,start-ebr,1024)
   v=bytearray(p.fat12());struct.pack_into('<H',v,19,1024);im[start*512:(start+1024)*512]=v[:1024*512]
   if next_:p.put_entry(im,ebr,1,15,next_-40000,100000-next_)
  return bytes(im)
 def test_profile(self):
  v=p.fat12('UNRELATED',123);d=p.bpb(v,p.TOTAL)
  self.assertEqual((len(v),d['sectors_per_cluster'],d['root_entries'],d['sectors_per_fat']), (32400*512,8,512,12))
  self.assertEqual(a.root_files(a.add_files(v,{'GD.CMD':b'test'})),{'GD.CMD':b'test'})
 def test_ebr_backwards_and_boot(self):
  im=self.image();parts=p.scan(im)
  self.assertEqual([q.number for q in parts],[1,4,5,6,7])
  self.assertEqual(p.choose_boot(parts,lambda l:im[l*512:(l+1)*512]),1)
  self.assertEqual(p.choose_boot(parts,lambda l:im[l*512:(l+1)*512],7),7)
 def test_active_precedes_fallback(self):
  im=bytearray(self.image());p.put_entry(im,0,1,1,35000,1024)
  v=bytearray(p.fat12());struct.pack_into('<H',v,19,1024);im[35000*512:36024*512]=v[:1024*512]
  self.assertEqual(p.choose_boot(p.scan(im),lambda l:im[l*512:(l+1)*512]),1)
  im[2048*512+13]=0
  self.assertEqual(p.choose_boot(p.scan(im),lambda l:im[l*512:(l+1)*512]),2)

 def test_corruption(self):
  for label,edit in [('signature',lambda i:i.__setitem__(510,0)),('flag',lambda i:i.__setitem__(446,1)),('loop',lambda i:p.put_entry(i,74000,1,15,38000,22000)),('linkend',lambda i:p.put_entry(i,40000,1,15,38000,40000)),('overlap',lambda i:p.put_entry(i,74000,0,1,6000,1024)),('involume',lambda i:p.put_entry(i,74000,0,1,2048,4000))]:
   with self.subTest(label=label):
    i=bytearray(self.image());edit(i)
    with self.assertRaises(ValueError):p.scan(i)
 def test_append_uses_existing_extended_free_space(self):
  old=self.image();new,n=p.append(old,p.fat12())
  # Larger container with ample free space must not grow or truncate it.
  im=bytearray(180224*512);im[:len(new)]=new
  p.put_entry(im,0,3,15,40000,140000)
  after,n=p.append(bytes(im),p.fat12())
  self.assertEqual(len(after),len(im))
  self.assertEqual(p.scan(after)[1].sectors,140000)
  self.assertLess(p.scan(after)[-1].start+p.TOTAL,180000)

 def test_append_preserves_other_data(self):
  old=self.image();new,number=p.append(old,p.fat12())
  self.assertEqual(number,8);self.assertEqual(p.scan(new)[-1].number,8)
  for q in p.scan(old):
   if q.kind not in p.EXTENDED:self.assertEqual(new[q.start*512:(q.start+q.sectors)*512],old[q.start*512:(q.start+q.sectors)*512])
 def test_append_rejects_native_record_overflow(self):
  im=bytearray(16384*512);im[510:512]=b'\x55\xaa'
  p.put_entry(im,0,0,6,1,1024);p.put_entry(im,0,3,15,2048,14336)
  for n in range(30):
   table=2048+128*n;im[table*512+510:table*512+512]=b'\x55\xaa'
   p.put_entry(im,table,0,1,1,64)
   if n<29:p.put_entry(im,table,1,15,128*(n+1),14336-128*(n+1))
  self.assertEqual(len(p.scan(im)),32)
  original=bytes(im)
  with self.assertRaisesRegex(ValueError,'32 records'):p.append(im,p.fat12())
  self.assertEqual(bytes(im),original)
 def test_append_plan_sparse_large_card(self):
  # A sparse 1 TiB backup exposes accidental whole-card bytearray copies.
  # Only MBR/EBR sectors should be accessed while choosing the new volume.
  with tempfile.TemporaryFile() as stream:
   stream.truncate(1<<40)
   mbr=bytearray(512);mbr[510:512]=b'\x55\xaa'
   p.put_entry(mbr,0,0,6,2048,32768)
   p.put_entry(mbr,0,3,15,40000,(1<<31)-40000)
   stream.seek(0);stream.write(mbr)
   stream.seek(40000*512);stream.write(bytes(510)+b'\x55\xaa');stream.flush()
   with mmap.mmap(stream.fileno(),0,access=mmap.ACCESS_READ) as image:
    plan=p.append_plan(image,p.TOTAL)
    self.assertEqual((plan['number'],plan['start'],plan['bytes']),(5,42048,1<<40))
    self.assertEqual(set(plan['writes']),{0,40000})
 def test_stream_migration_matches_memory_and_preserves_backup(self):
  root=Path(__file__).resolve().parents[1]
  current=(root/'images/sd.img').read_bytes()
  old=bytearray(current[:20*1024*1024]);old[494:510]=bytes(16)
  files=migration.root_files(old[2048*512:(2048+32768)*512])
  # Reconstruct the former five-bank payload layout with its original font
  # offset, exercising actual version-1 parsing and version-2 replacement.
  for name in ('P601.ROM','P601A.ROM'):
   compact=files[name];payload=compact[512:]
   payload=payload[:65536]+bytes(4*65536)+payload[65536:]
   header=bytearray(compact[:512]);struct.pack_into('<I',header,8,1)
   struct.pack_into('<II',header,16,len(payload),zlib.crc32(payload))
   struct.pack_into('<I',header,508,zlib.crc32(header[:508]))
   files[name]=bytes(header)+payload
  old[2048*512:(2048+32768)*512]=sd.fat16(files)
  expected,expected_report=migration.prepare(old)
  with tempfile.TemporaryDirectory() as directory:
   backup=Path(directory)/'backup.img';output=Path(directory)/'new.img'
   backup.write_bytes(old)
   report=migration.prepare_file(backup,output)
   self.assertEqual(output.read_bytes(),expected)
   self.assertEqual(report,expected_report)
   self.assertEqual(backup.read_bytes(),old)
   with self.assertRaises(FileExistsError):migration.prepare_file(backup,output)
   self.assertEqual(output.read_bytes(),expected)
if __name__=='__main__':unittest.main()
