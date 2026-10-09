#!/usr/bin/env python3
"""Serve a UniDOS FAT12 image/directory over the HG FT2232A link.

HG v1 byte pacing and open-drain ADBUS7 follow pdaxrom/lsi11-fpga.
HG v2 uses FPGA FIFO credits for bursts of up to 32 bytes at the same TCK.
The filesystem here is FAT12, not the uJ11 daemon's RT-11 directory backend.
Python standard library + the system libftdi1 runtime; no pyserial/pyftdi.
"""
import argparse
import ctypes as ct
import ctypes.util
import datetime
import fcntl
import json
import os
from pathlib import Path
import signal
import struct
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fat12

OK, PROTOCOL, RANGE, IO, CHECKSUM, READ_ONLY = range(6)


def decode_header(header):
    if len(header) != 10 or header[:2] != b'HG' or header[2] not in (1, 2):
        raise ValueError('invalid HG header')
    checksum = 0
    for byte in header[:9]:
        checksum ^= byte
    operation, unit, block, count = struct.unpack('<BBHH', header[3:9])
    if checksum != header[9] or unit or not 1 <= count <= 512:
        raise ValueError('invalid HG checksum/unit/count')
    op = operation & 127
    if operation & 128 or op not in (1, 2, 3):
        raise ValueError('invalid HG operation/chaining')
    if op == 3 and (operation & 128 or count != 6 or block not in (50, 60)):
        raise ValueError('invalid HG TIME request')
    return op, block, count


def host_time(hz, now=None):
    now = now or datetime.datetime.now().astimezone()
    if hz not in (50, 60):
        raise ValueError('HG TIME requires 50 or 60 Hz')
    age = now.year - 1972
    if not 0 <= age <= 63:
        raise ValueError('HG v1 date requires 1972..2035')
    date = (age >> 5) << 14 | now.month << 10 | now.day << 5 | (age & 31)
    ticks = (now.hour * 3600 + now.minute * 60 + now.second) * hz
    ticks += now.microsecond * hz // 1_000_000
    return struct.pack('<HHH', date, ticks >> 16, ticks & 65535)


def checked_payload(data):
    return data + struct.pack('<H', sum(data) & 65535)


class Volume:
    def __init__(self, image, read_only=False):
        self.path = Path(image)
        if not self.path.is_file() or self.path.is_symlink():
            raise ValueError('HG image must be a regular file')
        self.file = self.path.open('rb' if read_only else 'r+b')
        try:
            fcntl.flock(self.file, fcntl.LOCK_EX | fcntl.LOCK_NB)
            data = self.file.read()
            self.info = fat12.disk_info(data)
            fat12.layout(data)  # validate the FAT copies before any write
        except BaseException:
            self.file.close()
            raise
        self.size = self.info['sectors'] * 512
        self.read_only = read_only
        self.dirty = False

    def close(self):
        self.file.close()

    def in_range(self, block, count):
        return 0 < count <= 512 and block * 512 + count <= self.size

    def read(self, block, count):
        if not self.in_range(block, count):
            raise IndexError('HG block outside image')
        self.file.seek(block * 512)
        data = self.file.read(count)
        if len(data) != count:
            raise OSError('short disk read')
        return data

    def write(self, block, data):
        if self.read_only:
            raise PermissionError('HG volume is read-only')
        if not self.in_range(block, len(data)):
            raise IndexError('HG block outside image')
        self.file.seek(block * 512)
        if self.file.write(data) != len(data):
            raise OSError('short disk write')
        self.file.flush()
        os.fsync(self.file.fileno())  # status OK follows durable storage
        self.dirty = True


class DirectoryVolume(Volume):
    def __init__(self, directory, sectors=fat12.MAX_SECTORS, read_only=False):
        self.directory = Path(directory).resolve(strict=True)
        if not self.directory.is_dir():
            raise ValueError('HG directory does not exist')
        self.state_path = self.directory / '.p601-hg.json'
        lock_path = self.directory / '.p601-hg.lock'
        if lock_path.is_symlink():
            raise ValueError('HG lock must not be a symlink')
        self.directory_lock = lock_path.open('a+b')
        try:
            fcntl.flock(self.directory_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.initialize(sectors, read_only)
        except BaseException:
            if hasattr(self, 'file'):
                self.file.close()
            self.directory_lock.close()
            raise

    def initialize(self, sectors, read_only):
        image = self.directory / '.p601-hg.img'
        if self.state_path.is_symlink() or image.is_symlink():
            raise ValueError('HG cache must not be a symlink')
        if self.state_path.exists():
            state = json.loads(self.state_path.read_text())
            self.names = state['names']
            for name, filename in self.names.items():
                fat12.short_name(name)
                if filename != Path(filename).name or filename.upper() != name:
                    raise ValueError('invalid HG mirror state')
            if state['dirty']:
                if read_only:
                    raise ValueError('pending HG writes: recover the directory without --read-only first')
                super().__init__(image)
                try:
                    self.dirty = True
                    self.export()  # replay durable writes before rebuilding the cache
                finally:
                    self.file.close()
        elif image.exists():
            raise ValueError('HG cache without mirror state; preserve/recover .p601-hg.img first')
        files, self.names = {}, {}
        for path in sorted(self.directory.iterdir()):
            if path.name.startswith('.'):
                continue
            if path.is_symlink():
                raise ValueError(f'host symlink is not an HG file: {path.name}')
            if not path.is_file():
                continue  # HG directory is flat, like the RT-11 HG backend
            name = path.name.upper()
            fat12.short_name(name)
            if name in files:
                raise ValueError(f'case-insensitive duplicate: {name}')
            files[name] = path.read_bytes()
            self.names[name] = path.name
        # BPB geometry is informational for this logical-sector driver.
        data = fat12.add_files(fat12.blank_disk(sectors), files)
        self.atomic_write(image, data)
        super().__init__(image, read_only)
        self.save_state(False)

    def save_state(self, dirty):
        data = json.dumps(dict(names=self.names, dirty=dirty), sort_keys=True).encode() + b'\n'
        self.atomic_write(self.state_path, data)

    def write(self, block, data):
        if not self.read_only and self.in_range(block, len(data)) and not self.dirty:
            self.save_state(True)  # durable journal precedes the first guest write
        super().write(block, data)

    def close(self):
        try:
            super().close()
        finally:
            self.directory_lock.close()

    @staticmethod
    def atomic_write(path, data):
        fd, temporary = tempfile.mkstemp(prefix='.p601-hg-', dir=path.parent)
        try:
            with os.fdopen(fd, 'wb') as out:
                out.write(data)
                out.flush()
                os.fsync(out.fileno())
            os.replace(temporary, path)
            directory_fd = os.open(path.parent, os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def export(self):
        if not self.dirty or self.read_only:
            return
        # Parse everything first; temporarily inconsistent FAT copies/chains
        # postpone the entire export while UniDOS is still updating metadata.
        files = fat12.root_files(self.path.read_bytes())
        for name in files:
            fat12.short_name(name)
        for name, data in files.items():
            target = self.directory / self.names.get(name, name)
            if target.is_symlink():
                raise ValueError('host file replaced by a symlink')
            if not target.exists() or target.read_bytes() != data:
                self.atomic_write(target, data)
        for name in self.names.keys() - files.keys():
            target = self.directory / self.names[name]
            if target.is_symlink():
                raise ValueError('host file replaced by a symlink')
            target.unlink(missing_ok=True)
        self.names = {name: self.names.get(name, name) for name in files}
        self.save_state(False)
        self.dirty = False


class Mpsse:
    def __init__(self, clock=1_000_000, serial=None, index=0, vid=0x403, pid=0x6010):
        if not 100 <= clock <= 1_000_000:
            raise ValueError('MPSSE clock requires 100..1000000 Hz')
        library = ctypes.util.find_library('ftdi1')
        if not library:
            raise OSError('libftdi1 runtime not installed')
        self.lib = ct.CDLL(library)
        signatures = {
            'ftdi_new': (ct.c_void_p, []),
            'ftdi_free': (None, [ct.c_void_p]),
            'ftdi_set_interface': (ct.c_int, [ct.c_void_p, ct.c_int]),
            'ftdi_usb_open_desc_index': (ct.c_int, [ct.c_void_p, ct.c_int, ct.c_int, ct.c_char_p, ct.c_char_p, ct.c_uint]),
            'ftdi_usb_reset': (ct.c_int, [ct.c_void_p]),
            'ftdi_usb_close': (ct.c_int, [ct.c_void_p]),
            'ftdi_set_latency_timer': (ct.c_int, [ct.c_void_p, ct.c_ubyte]),
            'ftdi_set_bitmode': (ct.c_int, [ct.c_void_p, ct.c_ubyte, ct.c_ubyte]),
            'ftdi_tcioflush': (ct.c_int, [ct.c_void_p]),
            'ftdi_write_data': (ct.c_int, [ct.c_void_p, ct.c_void_p, ct.c_int]),
            'ftdi_read_data': (ct.c_int, [ct.c_void_p, ct.c_void_p, ct.c_int]),
        }
        for name, (result, arguments) in signatures.items():
            fn = getattr(self.lib, name)
            fn.restype, fn.argtypes = result, arguments
        self.context = self.lib.ftdi_new()
        if not self.context:
            raise MemoryError('ftdi_new')
        self.value, self.direction, self.jtag_controlled = 0, 0x0b, False
        try:
            self.call('ftdi_set_interface', 1)  # channel A; UART B is untouched
            self.call('ftdi_usb_open_desc_index', vid, pid, None, serial.encode() if serial else None, index)
            self.call('ftdi_usb_reset')
            self.call('ftdi_set_latency_timer', 1)
            self.call('ftdi_set_bitmode', 0, 0)
            self.call('ftdi_set_bitmode', self.direction, 2)
            time.sleep(.05)
            self.call('ftdi_tcioflush')
            self.write(b'\xaa\x87')
            if self.read(2) != b'\xfa\xaa':
                raise OSError('MPSSE sync failed')
            divisor = min(65535, max(1, 6_000_000 // clock) - 1)
            self.clock = 6_000_000 // (divisor + 1)
            self.write(b'\x86' + struct.pack('<H', divisor) + b'\x85\x87')
            self.set_low()
        except BaseException:
            self.close()
            raise

    def call(self, name, *arguments):
        result = getattr(self.lib, name)(self.context, *arguments)
        if result is not None and result < 0:
            raise OSError(f'{name} failed ({result})')
        return result

    def write(self, data):
        offset, deadline = 0, time.monotonic() + 5
        while offset < len(data):
            chunk = ct.create_string_buffer(data[offset:])
            offset += self.call('ftdi_write_data', chunk, len(data) - offset)
            if time.monotonic() > deadline:
                raise TimeoutError('MPSSE USB write')

    def read(self, size):
        data, deadline = bytearray(), time.monotonic() + 5
        while len(data) < size:
            chunk = ct.create_string_buffer(size - len(data))
            done = self.call('ftdi_read_data', chunk, len(chunk))
            data.extend(chunk.raw[:done])
            if time.monotonic() > deadline:
                raise TimeoutError('MPSSE USB read')
            if not done:
                time.sleep(.001)
        return bytes(data)

    def set_low(self):
        self.write(bytes((0x80, self.value, self.direction)))

    def pins(self):
        self.write(b'\x81\x87')
        return self.read(1)[0]

    def jtag_enable(self, enable):
        self.jtag_controlled = True
        self.value &= ~0x80
        self.direction = self.direction & ~0x80 if enable else self.direction | 0x80
        self.set_low()
        time.sleep(.001)
        if bool(self.pins() & 0x80) != bool(enable):
            raise OSError('JTAGENB readback failed')
        print('JTAGENB high readback verified' if enable else 'JTAGENB low readback verified; HG enabled', flush=True)

    def pending(self):
        return bool(self.pins() & 4)

    def select(self, enabled):
        self.value = self.value | 8 if enabled else self.value & ~8
        self.set_low()

    def exchange(self, data=None, count=None):
        if count is None:
            count = len(data)
        result = bytearray()
        for i in range(count):
            # Read positive/write negative, LSB first; TCK rests low between
            # USB byte completions, identical to hg_mpsse_exchange in uJ11.
            self.write(bytes((0x39, 0, 0, data[i] if data else 0, 0x87)))
            result.extend(self.read(1))
        return bytes(result)

    def wait_phase(self, value, mask):
        deadline = time.monotonic() + 5
        while True:
            phase = self.exchange_packet(count=1)[0]
            # Before the CPU enables queries, its legacy request pin reads FF.
            if phase != 0xff and phase & 0x40:
                raise OSError('HG FIFO overflow/underflow')
            if phase & mask == value:
                return
            if time.monotonic() > deadline:
                raise TimeoutError('HG FIFO credit/status phase')

    def exchange_packet(self, data=None, count=None):
        count = len(data) if count is None else count
        if not 1 <= count <= 32 or data is not None and len(data) != count:
            raise ValueError('HG packet requires 1..32 bytes')
        # One USB completion per packet; the FPGA credit guarantees enough
        # RX space/TX data even if a CPU interrupt spans the complete burst.
        payload = bytes(count) if data is None else data
        self.write(bytes((0x39, count - 1, 0)) + payload + b'\x87')
        return self.read(count)

    def exchange_flow(self, data=None, count=None):
        count = len(data) if count is None else count
        result = bytearray()
        self.select(False)
        for offset in range(0, count, 32):
            self.wait_phase(0x89 | (2 if data is not None else 4), 0x9f)
            size = min(32, count - offset)
            self.select(True)
            result.extend(self.exchange_packet(None if data is None else data[offset:offset + size], size))
            self.select(False)
        return bytes(result)

    def close(self):
        if not self.context:
            return
        try:
            self.value = 0
            self.set_low()
            if self.jtag_controlled:
                self.jtag_enable(True)
            self.direction = 0
            self.set_low()
            self.call('ftdi_set_bitmode', 0, 0)
        finally:
            self.lib.ftdi_usb_close(self.context)
            self.lib.ftdi_free(self.context)
            self.context = None


def serve_one(link, volume, now=None, stats=None):
    started = time.monotonic()
    version, op, block, count = 1, 0, 0, 0
    outcome = OK
    transport_failed = False
    def status(value):
        nonlocal outcome
        outcome = value
        if version == 2:
            link.select(False)
            link.wait_phase(0x9a, 0x9e)  # request/packet/inhibit/RX
            link.select(True)
        else:
            time.sleep(.0005)
        link.exchange(bytes((value,)))
    link.select(True)
    try:
        time.sleep(.002)
        try:
            # Both P601 driver versions queue all ten bytes before REQUEST.
            header = link.exchange_packet(count=10)
            op, block, count = decode_header(header)
            version = header[2]
        except ValueError:
            status(PROTOCOL)
            return False
        if op in (1, 3):
            try:
                payload = host_time(block, now) if op == 3 else volume.read(block, count)
            except (ValueError, IndexError):
                status(RANGE)
                return False
            except OSError:
                status(IO)
                return False
            status(OK)
            if version == 2:
                link.exchange_flow(checked_payload(payload))
            else:
                time.sleep(.0005)
                link.exchange(checked_payload(payload))
            return False
        if volume.read_only:
            status(READ_ONLY)
            return False
        if not volume.in_range(block, count):
            status(RANGE)
            return False
        status(OK)
        if version == 2:
            payload = link.exchange_flow(count=count + 2)
        else:
            time.sleep(.0005)
            payload = link.exchange(count=count + 2)
        if checked_payload(payload[:-2]) != payload:
            status(CHECKSUM)
            return False
        try:
            volume.write(block, payload[:-2])
        except OSError:
            status(IO)
            return False
        status(OK)
        return True
    except BaseException:
        transport_failed, outcome = True, IO
        raise
    finally:
        try:
            if version == 2 and not transport_failed:
                link.select(False)
                link.wait_phase(0x98, 0x9e)  # terminal: RX/TX disabled
                link.select(True)
                link.wait_phase(0, 0x80)  # CPU acknowledges and releases request
            time.sleep(.0005)
        finally:
            link.select(False)
            if stats is not None:
                stats(version, op, block, count, outcome, time.monotonic() - started)


class TransferStats:
    """Log real wire/CPU/FIFO wait time, separately from file decoding/rendering."""
    def __init__(self):
        self.samples = {}

    def __call__(self, version, op, block, count, status, elapsed):
        key = version, op
        samples, size, seconds = self.samples.get(key, (0, 0, 0))
        samples, size, seconds = samples + 1, size + count, seconds + elapsed
        self.samples[key] = samples, size, seconds
        name = {1: 'READ', 2: 'WRITE', 3: 'TIME'}.get(op, 'INVALID')
        print(f'HG v{version} {name}'
              f' LBA={block} bytes={count} status={status} {elapsed * 1000:.1f}ms;'
              f' average={size / seconds / 1024:.2f}KiB/s ({samples} requests)', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--image', type=Path)
    group.add_argument('--directory', type=Path)
    group.add_argument('--jtag-only', action='store_true')
    group.add_argument('--create-image', type=Path, help='format a new FAT12 image and exit')
    parser.add_argument('--read-only', action='store_true')
    parser.add_argument('--blocks', type=int, default=fat12.MAX_SECTORS, help='FAT12 sectors, default 32736; tested UniDOS geometry: 32400')
    parser.add_argument('--clock', type=int, default=1000000)
    parser.add_argument('--stats', action='store_true', help='log measured transaction time and throughput')
    parser.add_argument('--serial')
    parser.add_argument('--index', type=int, default=0)
    parser.add_argument('--vid', type=lambda n: int(n, 0), default=0x403)
    parser.add_argument('--pid', type=lambda n: int(n, 0), default=0x6010)
    parser.add_argument('--jtag-enable-adbus7', action='store_true', help='accepted for uJ11 CLI compatibility; HC7000 always uses it')
    args = parser.parse_args()
    if args.create_image:
        with args.create_image.open('xb') as out:
            out.write(fat12.blank_disk(args.blocks))
            out.flush()
            os.fsync(out.fileno())
        print(f'Created {args.create_image}: {args.blocks} sectors, FAT12, 4096-byte clusters')
        return
    volume = None
    if args.image:
        volume = Volume(args.image, args.read_only)
    elif args.directory:
        volume = DirectoryVolume(args.directory, args.blocks, args.read_only)
    stop = False
    def stopped(signum, frame):
        nonlocal stop
        stop = True
    signal.signal(signal.SIGINT, stopped)
    signal.signal(signal.SIGTERM, stopped)
    link = None
    try:
        link = Mpsse(args.clock, args.serial, args.index, args.vid, args.pid)
        link.jtag_enable(args.jtag_only)
        if args.jtag_only:
            return
        print(f'Serving {volume.path} at {link.clock} Hz; {volume.info["sectors"]} sectors', flush=True)
        last_write = 0
        stats = TransferStats() if args.stats else None
        while not stop:
            if link.pending():
                if serve_one(link, volume, stats=stats):
                    last_write = time.monotonic()
            elif isinstance(volume, DirectoryVolume) and time.monotonic() - last_write >= .5:
                try:
                    volume.export()
                except ValueError as error:
                    print(f'Waiting for consistent FAT12 metadata: {error}', file=sys.stderr)
                    last_write = time.monotonic()
            time.sleep(.002)
    finally:
        try:
            if link:
                link.close()  # SIGINT/SIGTERM returns JTAGENB to its pull-up
        finally:
            if volume:
                try:
                    if isinstance(volume, DirectoryVolume):
                        volume.export()
                finally:
                    volume.close()


if __name__ == '__main__':
    main()
