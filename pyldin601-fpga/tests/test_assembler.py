import importlib.util
from pathlib import Path
import unittest
s=importlib.util.spec_from_file_location('asm',Path(__file__).parents[1]/'tools/asm6800.py')
a=importlib.util.module_from_spec(s);s.loader.exec_module(a)
class AssemblerTests(unittest.TestCase):
    def test_classic_encodings(self):
        b,_=a.assemble('ldaa #$12\nldx #$abcd\njsr $1234\njsr 7,x\nrts',0x1000)
        self.assertEqual(b,bytes.fromhex('8612ceabcdbd1234ad0739'))
    def test_long_branch_expansion(self):
        b,_=a.assemble('lbne $3456\nlbra $1234\nlbsr $abcd',0x1000)
        self.assertEqual(b,bytes.fromhex('27037e34567e1234bdabcd'))
    def test_reject_6303_and_distant_short_branch(self):
        for source in ['ldd #$1234','mul','bra $2000']:
            with self.assertRaises(ValueError): a.assemble(source,0x1000)
