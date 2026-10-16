#!/usr/bin/env python3
"""Check UARTTEST.PGM over FTDI channel B, leaving HG/channel A untouched."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import select
import termios
import time

RATES = (150, 300, 600, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200)


def speed(fd, rate):
    attr = termios.tcgetattr(fd)
    attr[0] = attr[1] = attr[3] = 0
    attr[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attr[4] = attr[5] = getattr(termios, 'B' + str(rate))
    attr[6][termios.VMIN] = 0
    attr[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attr)


def write_all(fd, data, timeout):
    end = time.monotonic() + timeout
    while data:
        left = end - time.monotonic()
        if left <= 0 or not select.select([], [fd], [], left)[1]:
            raise TimeoutError('UART write timed out')
        try:
            data = data[os.write(fd, data):]
        except BlockingIOError:
            pass


def read_exact(fd, count, timeout):
    out = bytearray()
    end = time.monotonic() + timeout
    while len(out) < count:
        left = end - time.monotonic()
        if left <= 0 or not select.select([fd], [], [], left)[0]:
            raise TimeoutError(f'UART read: {len(out)}/{count} bytes')
        try:
            chunk = os.read(fd, count - len(out))
        except BlockingIOError:
            continue
        if not chunk:
            raise OSError('UART disconnected')
        out.extend(chunk)
    return bytes(out)


def check_rate(fd, rate, count):
    speed(fd, 19200)
    termios.tcflush(fd, termios.TCIOFLUSH)
    header = bytes((0x55, 0xaa, RATES.index(rate), count >> 8, count & 255))
    checksum = 0
    for b in header:
        checksum ^= b
    write_all(fd, header + bytes((checksum,)), 2)
    termios.tcdrain(fd)
    time.sleep(0.15)
    speed(fd, rate)
    write_all(fd, b'\xa5', 2)
    if read_exact(fd, 1, 2) != b'\x5a':
        raise ValueError('UARTTEST handshake mismatch')
    # Includes every byte value, NUL, CR/LF and all combinations of bit edges.
    payload = bytes(((i * 73) ^ (i >> 8) ^ (i >> 3)) & 255 for i in range(count))
    echoed = bytearray()
    started = time.monotonic()
    for offset in range(0, count, 128):
        block = payload[offset:offset + 128]
        timeout = 2 + len(block) * 12 / rate
        write_all(fd, block, timeout)
        echoed.extend(read_exact(fd, len(block), timeout))
    trailer = read_exact(fd, 3, 2)
    if trailer != bytes((ord('D'), 0, RATES.index(rate))):
        raise ValueError(f'UART hardware error or protocol mismatch: {trailer.hex()}')
    if echoed != payload:
        first = next(i for i, (a, b) in enumerate(zip(payload, echoed)) if a != b)
        raise ValueError(f'UART byte mismatch at {first}: {payload[first]:02x}/{echoed[first]:02x}')
    write_all(fd, b'\xcc', 2)
    termios.tcdrain(fd)
    time.sleep(0.15)
    return {'rate': rate, 'bytes_each_direction': count, 'seconds': round(time.monotonic() - started, 3),
            'sha256': hashlib.sha256(payload).hexdigest(), 'rx_errors': 0}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--port', default='/dev/serial/by-id/usb-FTDI_Dual_RS232-if01-port0')
    p.add_argument('--rates', nargs='+', type=int, choices=RATES[1:], default=list(RATES[1:]),
                   help='FT2232D supports standard rates 300..115200; 150 is below its divisor range')
    p.add_argument('--bytes', type=int, help='Bytes per speed (default: about one second; 32768 at 115200)')
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    if a.bytes is not None and not 1 <= a.bytes <= 65535:
        p.error('--bytes must be 1..65535')
    result = {'port': a.port, 'passed': False, 'cases': []}
    fd = os.open(a.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    saved = termios.tcgetattr(fd)
    owned = False
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fcntl.ioctl(fd, termios.TIOCEXCL)
        owned = True
        for rate in a.rates:
            count = a.bytes or (32768 if rate == 115200 else max(64, rate // 10))
            case = check_rate(fd, rate, count)
            result['cases'].append(case)
            print(f'PASS UART {rate} 8N1: {count} bytes each direction, SHA256 {case["sha256"]}', flush=True)
        result['passed'] = True
    except Exception as e:
        result['error'] = str(e)
        raise
    finally:
        try:
            if owned:
                termios.tcsetattr(fd, termios.TCSANOW, saved)
                fcntl.ioctl(fd, termios.TIOCNXCL)
        finally:
            os.close(fd)
        if a.output:
            a.output.write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
