"""Exercise the host peer against independently framed binary wire traffic."""
import binascii
import io
from pathlib import Path
import socket
import sys
import threading
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
from uart_xmodem import Link, receive, send


def crc(data):
    value = 0
    for byte in data:
        value ^= byte << 8
        for _ in range(8):
            value = ((value << 1) ^ (0x1021 if value & 0x8000 else 0)) & 65535
    return value


def frame(number, data):
    return bytes((1, number, number ^ 255)) + data + crc(data).to_bytes(2, 'big')


class PeerTest(unittest.TestCase):
    def session(self, peer, body):
        left, right = socket.socketpair()
        errors = []
        def worker():
            try:
                peer(Link(right.fileno(), 115200))
            except BaseException as error:
                errors.append(error)
        thread = threading.Thread(target=worker, daemon=True)
        thread.start()
        try:
            body(Link(left.fileno(), 115200))
            thread.join(3)
            self.assertFalse(thread.is_alive(), 'peer terminated')
            if errors:
                raise errors[0]
        finally:
            left.close()
            right.close()

    def test_crc_vector(self):
        self.assertEqual(crc(b'123456789'), 0x31c3)
        self.assertEqual(binascii.crc_hqx(b'123456789', 0), 0x31c3)

    def test_send_wrap_retry_padding(self):
        data = bytes((i*73 ^ i>>8)&255 for i in range(32771))
        def peer(link):
            link.write(b'\x11C')
            for offset in range(0, len(data), 128):
                packet = link.read(133, 2)
                number = (offset//128+1)&255
                expected = frame(number, data[offset:offset+128].ljust(128, b'\x1a'))
                self.assertEqual(packet, expected)
                if offset == 0:
                    link.write(b'\x15')
                    self.assertEqual(link.read(133, 2), expected)
                link.write(b'\x06')
            self.assertEqual(link.read(), b'\x04')
            link.write(b'\x15')
            self.assertEqual(link.read(), b'\x04')
            link.write(b'\x06')
        self.session(peer, lambda link: self.assertEqual(send(link, io.BytesIO(data)), len(data)))

    def test_receive_crc_duplicate_and_binary_padding(self):
        data = bytes(range(128))
        target = io.BytesIO()
        def peer(link):
            self.assertEqual(link.read(), b'C')
            packet = frame(1, data)
            link.write(packet[:-1]+bytes((packet[-1]^1,)))
            self.assertEqual(link.read(), b'\x15')
            link.write(packet)
            self.assertEqual(link.read(), b'\x06')
            link.write(packet)  # lost ACK: no duplicate disk data
            self.assertEqual(link.read(), b'\x06')
            link.write(frame(2, b'\x1a'*128))
            self.assertEqual(link.read(), b'\x06')
            link.write(b'\x04')
        self.session(peer, lambda link: self.assertEqual(receive(link, target), 256))
        self.assertEqual(target.getvalue(), data+b'\x1a'*128)

    def test_cancel_requires_two_can(self):
        def peer(link):
            self.assertEqual(link.read(), b'C')
            link.write(b'\x18\x18')
        def body(link):
            with self.assertRaises(InterruptedError):
                receive(link, io.BytesIO())
        self.session(peer, body)

    def test_empty_send(self):
        def peer(link):
            link.write(b'C')
            self.assertEqual(link.read(), b'\x04')
            link.write(b'\x06')
        self.session(peer, lambda link: self.assertEqual(send(link, io.BytesIO()), 0))


if __name__ == '__main__':
    unittest.main()
