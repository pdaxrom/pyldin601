"""Check the external assembler bridge; no substitute opcode encoder."""
from pathlib import Path
import tempfile
import unittest
from unias_fixture import assemble


class UniASTests(unittest.TestCase):
    def test_classic_and_hd6303_encodings(self):
        data,_=assemble('''    org $1000
    ldaa #$12
    ldx #$abcd
    jsr $1234
    jsr 7,x
    mul
    rts''',0x1000)
        self.assertEqual(data,bytes.fromhex('8612ceabcdbd1234ad073d39'))

    def test_explicit_branch_and_rom_fill(self):
        data,labels=assemble('''    org $f000
    beq after
    jmp $3456
after
    rts
    ds $fff8-*,$ff
    dw $f000,$f000,$f000,$f000''',0xf000)
        self.assertEqual(len(data),4096)
        self.assertEqual(data[:6],bytes.fromhex('27037e345639'))
        self.assertEqual(labels['after'],0xf005)
        self.assertEqual(data[-8:],bytes.fromhex('f000f000f000f000'))
