#!/usr/bin/env python3
"""XMODEM-CRC peer for UART.PGM, using FTDI channel B (HG remains on A).

On Pyldin: F3 Receive <-> this tool's send; F4 Send <-> receive.
128-byte blocks, CRC-16/XMODEM, padding retained on receive. No dependencies.
"""
import argparse
import binascii
import fcntl
import os
from pathlib import Path
import tempfile
import termios
import time

from uart_board_test import read_exact, speed, write_all

SOH, EOT, ACK, NAK, CAN = 1, 4, 6, 21, 24


class Link:
    def __init__(self, fd, baud):
        self.fd, self.baud = fd, baud

    def read(self, n=1, timeout=10):
        return read_exact(self.fd, n, timeout)

    def write(self, data):
        write_all(self.fd, data, 2 + len(data) * 12 / self.baud)


def control(link, timeout=10):
    """Ignore terminal XON/XOFF outside binary frames; require double CAN."""
    end, cancelled = time.monotonic() + timeout, False
    while True:
        value = link.read(1, max(0.001, end - time.monotonic()))[0]
        if value == CAN:
            if cancelled:
                raise InterruptedError('Remote cancelled transfer')
            cancelled = True
        else:
            cancelled = False
            if value not in (17, 19):
                return value
        if time.monotonic() >= end:
            raise TimeoutError('XMODEM handshake timed out')


def send(link, source, progress=lambda n: None):
    for _ in range(10):
        try:
            if control(link) == ord('C'):
                break
        except TimeoutError:
            pass
    else:
        raise TimeoutError('Receiver did not request XMODEM-CRC')
    sequence, count = 1, 0
    while True:
        data = source.read(128)
        if not data:
            break
        payload = data.ljust(128, b'\x1a')
        crc = binascii.crc_hqx(payload, 0)
        packet = bytes((SOH, sequence, sequence ^ 255)) + payload + crc.to_bytes(2, 'big')
        for _ in range(10):
            link.write(packet)
            try:
                if control(link) == ACK:
                    break
            except TimeoutError:
                pass
        else:
            raise TimeoutError('Block was not acknowledged after 10 attempts')
        count += len(data)
        progress(count)
        sequence = (sequence + 1) & 255
    for _ in range(10):
        link.write(bytes((EOT,)))
        try:
            if control(link) == ACK:
                return count
        except TimeoutError:
            pass
    raise TimeoutError('End of file was not acknowledged')


def purge(link):
    for _ in range(4096):
        try:
            link.read(1, 1)
        except TimeoutError:
            return
    raise InterruptedError('Peer did not go quiet after a bad packet')


def receive(link, target, progress=lambda n: None):
    sequence, count, attempts = 1, 0, 0
    request = ord('C')
    link.write(bytes((request,)))
    while attempts < 10:
        try:
            header = control(link)
            if header == EOT:
                target.flush()
                # The caller publishes before sending the final ACK.
                return count
            if header == 2:
                raise InterruptedError('XMODEM-1K is unsupported; select 128-byte XMODEM-CRC')
            if header != SOH:
                raise ValueError('Expected a 128-byte SOH block')
            request = NAK
            packet = link.read(132, 2 + 132 * 12 / link.baud)
            number, inverse = packet[:2]
            payload, crc = packet[2:130], int.from_bytes(packet[130:], 'big')
            if number ^ inverse != 255 or binascii.crc_hqx(payload, 0) != crc:
                raise ValueError('Invalid block number or CRC')
            if number == sequence:
                target.write(payload)
                count += 128
                progress(count)
                sequence = (sequence + 1) & 255
            elif not count or number != ((sequence - 1) & 255):
                raise InterruptedError('Unexpected block sequence')
            link.write(bytes((ACK,)))
            attempts = 0
        except (TimeoutError, ValueError):
            purge(link)
            attempts += 1
            link.write(bytes((request,)))
    raise TimeoutError('Too many receive errors')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('direction', choices=('send', 'receive'))
    parser.add_argument('file', type=Path)
    parser.add_argument('--port', default='/dev/serial/by-id/usb-FTDI_Dual_RS232-if01-port0')
    parser.add_argument('--baud', type=int, choices=(300, 600, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200), default=19200)
    args = parser.parse_args()
    if 'if00' in args.port:
        parser.error('FTDI channel A is used by HG; choose channel B (if01)')
    if args.direction == 'receive' and args.file.exists():
        parser.error('Destination already exists; choose a new filename')
    fd = os.open(args.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    saved = termios.tcgetattr(fd)
    owned, temporary = False, None
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fcntl.ioctl(fd, termios.TIOCEXCL)
        owned = True
        speed(fd, args.baud)  # raw, 8N1, software flow disabled for binary packets
        link = Link(fd, args.baud)
        def progress(count):
            print(f'\r{count} bytes', end='', flush=True)
        if args.direction == 'send':
            with args.file.open('rb') as source:
                count = send(link, source, progress)
        else:
            with tempfile.NamedTemporaryFile(prefix='.uart-', dir=args.file.resolve().parent, delete=False) as target:
                temporary = Path(target.name)
                count = receive(link, target, progress)
                os.fsync(target.fileno())
            # Exclusive publication protects even a destination created mid-transfer.
            os.link(temporary, args.file)
            temporary.unlink()
            temporary = None
            link.write(bytes((ACK,)))
            # A lost final ACK must not leave the sender retrying a complete
            # published file. Keep answering EOT during its retry interval.
            until = time.monotonic() + 12
            while time.monotonic() < until:
                try:
                    if control(link, max(0.001, until-time.monotonic())) == EOT:
                        link.write(bytes((ACK,)))
                except TimeoutError:
                    break
        print(f'\nComplete: {count} bytes' + (' (XMODEM padding retained)' if args.direction == 'receive' else ''))
    except (Exception, KeyboardInterrupt):
        if owned:
            try:
                write_all(fd, bytes((CAN, CAN)), 1)
            except (OSError, TimeoutError):
                pass
        raise
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
        try:
            if owned:
                termios.tcsetattr(fd, termios.TCSANOW, saved)
                fcntl.ioctl(fd, termios.TIOCNXCL)
        finally:
            os.close(fd)


if __name__ == '__main__':
    main()
