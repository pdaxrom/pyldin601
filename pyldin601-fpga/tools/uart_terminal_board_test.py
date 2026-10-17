#!/usr/bin/env python3
"""Exercise UART.PGM on the physical board through FTDI B, leaving HG/A alone.

screen: query the running terminal, draw colours/native boxes and test margins.
keys: collect arrows, UARTOK+Enter, and Esc from the physical keyboard.
xsend/xreceive: binary roundtrip, optional injected CRC error, compare files.
"""
import argparse
import fcntl
import json
import hashlib
import tempfile
import os
from pathlib import Path
import re
import select
import termios
import time

from uart_board_test import speed, write_all
from uart_xmodem import Link, send as xsend, receive as xreceive, control


def read_until(fd, pattern, timeout=5):
    data = bytearray()
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if not select.select([fd], [], [], max(0, end-time.monotonic()))[0]:
            break
        chunk = os.read(fd, 256)
        if not chunk:
            raise OSError('UART disconnected')
        data.extend(chunk)
        match = re.search(pattern, data)
        if match:
            return bytes(data), match
    raise TimeoutError(f'No terminal response matching {pattern!r}; received {bytes(data)!r}')


def send(fd, text):
    write_all(fd, text, 5)
    termios.tcdrain(fd)


def screen(fd, baud):
    # Force ANSI cursor keys and default attributes; no effect on native video.
    send(fd, b'\x1b[?1l\x1b[0m\x1b[r\x1b[2J\x1b[H\x1b[c')
    identity, _ = read_until(fd, rb'\x1b\[\?1;0c')
    send(fd, b'\x1b[1;1H\x1b[255C\x1b[6n')
    geometry, match = read_until(fd, rb'\x1b\[(\d+);(\d+)R')
    columns = int(match[2])
    if int(match[1]) != 1 or columns not in (40, 80):
        raise ValueError(f'Unexpected terminal geometry: {geometry!r}')
    send(fd, b'\x1b[14;7H\x1b[6n')
    cursor, match = read_until(fd, rb'\x1b\[(\d+);(\d+)R')
    if (int(match[1]), int(match[2])) != (14, 7):
        raise ValueError(f'Wrong cursor reply: {cursor!r}')
    fixture = (
        b'\x1b[2J\x1b[H'
        b'PYLDIN UART - BOARD TEST\r\n'
        + f'{baud} 8N1 / FTDI B\r\n'.encode()
        + b'\x1b[4;1H\x1b[31mRED \x1b[32mGREEN \x1b[34mBLUE\x1b[0m'
        b'\x1b[6;1H\x1b(0lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk\x1b(B'
        b'\x1b[7;1H\x1b(0x\x1b(B Native font box: straight lines \x1b(0x\x1b(B'
        b'\x1b[8;1H\x1b(0mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj\x1b(B'
        b'\x1b[10;1HScroll area (only rows 11-13):'
        b'\x1b[11;13r\x1b[11;1HOLD\r\nONE\r\nTWO\r\nTHREE'
        b'\x1b[r\x1b[11;1H'
    )
    send(fd, fixture)
    send(fd, b'\x1b[15;1HExpected rows: ONE / TWO / THREE'
             b'\x1b[17;1HHost verified cursor and device ID.'
             b'\x1b[19;1HCheck F1 help, then return with Esc.'
             b'\x1b[21;1HEsc goes to host; F10 exits UART.'
             b'\x1b[23;1H')
    return {'phase': 'screen', 'passed': True, 'columns': columns, 'rows': 24,
            'identity_hex': identity.hex(), 'geometry_hex': geometry.hex(),
            'cursor_hex': cursor.hex(), 'visual_confirmation_required': True}


def keys(fd):
    send(fd, b'\x1b[?1l\x1b[19;1HPress all 4 arrows, type UARTOK+Enter'
             b'\x1b[20;1HThen press Esc (do not press F10).'
             b'\x1b[22;1HKeyboard: ')
    print('Waiting for arrows, UARTOK+Enter, Esc...', flush=True)
    data = bytearray()
    end = time.monotonic() + 120
    while time.monotonic() < end:
        if not select.select([fd], [], [], 1)[0]:
            continue
        chunk = os.read(fd, 256)
        if not chunk:
            raise OSError('UART disconnected')
        data.extend(chunk)
        printable = bytes(value for value in chunk if 32 <= value < 127)
        if printable:
            send(fd, printable)
        arrows = all(b'\x1b['+bytes((value,)) in data for value in b'ABCD')
        stripped = re.sub(rb'\x1b\[[ABCD]', b'', bytes(data))
        if arrows and b'uartok\r' in stripped.lower() and b'\x1b' in stripped:
            send(fd, b'\x1b[23;1HKEYBOARD PASS: all bytes received.')
            return {'phase': 'keys', 'passed': True, 'received_hex': data.hex(),
                    'arrows': True, 'text_enter': True, 'escape': True}
    raise TimeoutError(f'Keyboard test incomplete: {bytes(data)!r}')


class CountingLink(Link):
    def __init__(self, fd, baud, corrupt=False):
        super().__init__(fd, baud)
        self.corrupt = corrupt
        self.counts = {'ack': 0, 'nak': 0, 'crc_requests': 0, 'packets_sent': 0,
                       'injected_crc_errors': 0}

    def write(self, data):
        if len(data) == 133 and data[0] == 1:
            self.counts['packets_sent'] += 1
            if self.corrupt:
                data = data[:-1] + bytes((data[-1] ^ 1,))
                self.corrupt = False
                self.counts['injected_crc_errors'] += 1
        super().write(data)

    def read(self, n=1, timeout=10):
        data = super().read(n, timeout)
        if n == 1:
            for value, name in ((6, 'ack'), (21, 'nak'), (67, 'crc_requests')):
                self.counts[name] += data == bytes((value,))
        return data


def transfer(fd, args):
    link = CountingLink(fd, args.baud, args.inject_crc_error)
    args._link = link
    if args.file is None:
        raise ValueError('--file is required')
    print('Waiting for XMODEM peer on the board...', flush=True)
    def progress(count):
        if count % 4096 == 0:
            print(f'{count} bytes', flush=True)
    if args.phase == 'xsend':
        data = args.file.read_bytes()
        with args.file.open('rb') as source:
            count = xsend(link, source, progress)
        padded = data + b'\x1a' * (-len(data) % 128)
        if args.inject_crc_error and not link.counts['nak']:
            raise ValueError('Board did not NAK the injected CRC error')
        if args.guest_file:
            # HG exports a consistent FAT snapshot to the host directory on
            # its idle sync. The serial ACK can precede that export.
            until = time.monotonic() + 15
            actual = None
            while time.monotonic() < until:
                try:
                    actual = args.guest_file.read_bytes()
                except FileNotFoundError:
                    pass
                if actual == padded:
                    break
                time.sleep(0.1)
            if actual != padded:
                raise ValueError('HG file differs from the expected padded binary data after sync')
        return {'phase': args.phase, 'passed': True, 'source_bytes': count,
                'guest_bytes': len(padded), 'source_sha256': hashlib.sha256(data).hexdigest(),
                'guest_sha256': hashlib.sha256(padded).hexdigest(), **link.counts}
    if args.file.exists():
        raise FileExistsError(args.file)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(prefix='.uart-board-', dir=args.file.parent, delete=False) as target:
            temporary = Path(target.name)
            count = xreceive(link, target, progress)
            os.fsync(target.fileno())
        actual = temporary.read_bytes()
        if args.expected:
            source = args.expected.read_bytes()
            expected = source + b'\x1a' * (-len(source) % 128)
            if actual != expected:
                raise ValueError('Returned binary file does not match the independent source')
        os.link(temporary, args.file)
        temporary.unlink()
        temporary = None
        link.write(b'\x06')
        until = time.monotonic() + 12
        while time.monotonic() < until:
            try:
                if control(link, max(0.001, until-time.monotonic())) == 4:
                    link.write(b'\x06')
            except TimeoutError:
                break
        return {'phase': args.phase, 'passed': True, 'bytes': count,
                'sha256': hashlib.sha256(actual).hexdigest(), **link.counts}
    finally:
        if temporary:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('screen', 'keys', 'xsend', 'xreceive'))
    parser.add_argument('--file', type=Path)
    parser.add_argument('--expected', type=Path)
    parser.add_argument('--guest-file', type=Path)
    parser.add_argument('--inject-crc-error', action='store_true')
    parser.add_argument('--baud', type=int, default=9600)
    parser.add_argument('--port', default='/dev/serial/by-id/usb-FTDI_Dual_RS232-if01-port0')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if 'if00' in args.port:
        parser.error('Choose FTDI B (if01); HG uses channel A')
    fd = os.open(args.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    saved = termios.tcgetattr(fd)
    owned = False
    result = {'phase': args.phase, 'baud': args.baud, 'passed': False}
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fcntl.ioctl(fd, termios.TIOCEXCL)
        owned = True
        speed(fd, args.baud)
        attributes = termios.tcgetattr(fd)
        if args.phase in ('screen', 'keys'):
            attributes[0] |= termios.IXON  # honour terminal XOFF, never binary packet bytes
        termios.tcsetattr(fd, termios.TCSANOW, attributes)
        result.update(screen(fd, args.baud) if args.phase == 'screen' else keys(fd) if args.phase == 'keys' else transfer(fd, args))
        print(json.dumps(result), flush=True)
    except BaseException as error:
        result['error'] = str(error)
        if owned and args.phase.startswith('x'):
            try:
                write_all(fd, b'\x18\x18', 1)
            except (OSError, TimeoutError):
                pass
        raise
    finally:
        if hasattr(args, '_link'):
            result.update(args._link.counts)
        args.output.write_text(json.dumps(result, indent=2)+'\n')
        try:
            if owned:
                termios.tcsetattr(fd, termios.TCSANOW, saved)
                fcntl.ioctl(fd, termios.TIOCNXCL)
        finally:
            os.close(fd)


if __name__ == '__main__':
    main()
