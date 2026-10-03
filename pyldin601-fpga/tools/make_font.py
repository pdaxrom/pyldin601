#!/usr/bin/env python3
"""Seed the existing font EBR with the classic font before SD boot."""
import argparse
import gzip
from pathlib import Path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    data=args.source.read_bytes()
    if data[:2]==b'\x1f\x8b':data=gzip.decompress(data)
    if len(data)!=2048:raise ValueError('Classic video font must be 2048 bytes')
    args.output.write_text(''.join(f'{byte:02x}\n' for byte in data))
    print(f'{args.output}: {len(data)} bytes from {args.source}')

if __name__=='__main__':main()
