#!/usr/bin/env python3
"""Preserve original ROM files and unpack every ARC with the original UNARC."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import add_disk_files as fat

ROOT=Path(__file__).resolve().parents[1]

def extract(native,output,cc='cc',emulator=None):
    output.mkdir(parents=True,exist_ok=True)
    banks=[]
    for n in range(1,5):
        data=(native/'RAMROMDiskPipnet'/f'rom{n}.roz').read_bytes()
        banks.append(gzip.decompress(data) if data[:2]==b'\x1f\x8b' else data)
    volume=b''.join(banks)
    if len(volume)!=320*512:raise ValueError('unexpected original ROM disk size')
    normalized=bytearray(volume);normalized[510:512]=b"\x55\xaa"
    original=fat.root_files(normalized)
    originals=output/'original';originals.mkdir(exist_ok=True)
    unpacked=output/'unpacked';unpacked.mkdir(exist_ok=True)
    for name,data in original.items():(originals/name).write_bytes(data)
    runner=output/'extract'
    subprocess.run([cc,'-O2','-I'+str(emulator or ROOT.parent/'pyldin601/src'),
                    str(ROOT/'tools/romdisk/extract.c'),'-o',str(runner)],check=True)
    manifest={}
    for name,data in original.items():
        if not name.endswith('.ARC'):continue
        disk=output/(name+'.img')
        with (output/(name+'.log')).open('wb') as log:
            subprocess.run([str(runner.resolve()),name,str(disk.resolve())],cwd=ROOT,stdout=log,stderr=log,check=True)
        p=bytearray(disk.read_bytes())
        # The original electronic disk has no boot signature and FE FAT marker.
        # Normalize the extracted temporary image solely for the host FAT reader.
        p[510:512]=b'\x55\xaa';p[21]=p[512]
        files=fat.root_files(p)
        if not files:raise ValueError(f'{name}: native extractor produced no files')
        manifest[name]={}
        for filename,contents in files.items():
            dest=unpacked/filename
            if dest.exists() and dest.read_bytes()!=contents:raise ValueError('archive filename collision: '+filename)
            dest.write_bytes(contents)
            manifest[name][filename]=dict(bytes=len(contents),sha256=hashlib.sha256(contents).hexdigest())
    metadata=dict(original_rom_sha256=hashlib.sha256(volume).hexdigest(),
                  originals={n:dict(bytes=len(d),sha256=hashlib.sha256(d).hexdigest()) for n,d in original.items()},
                  extracted=manifest,extractor='original UniDOS UNARC.CMD in MC6800 emulator')
    (output/'manifest.json').write_text(json.dumps(metadata,indent=2)+'\n')
    return metadata

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native',type=Path,default=ROOT.parent/'native')
    parser.add_argument('--output',type=Path,default=ROOT/'build/romdisk-extracted')
    args=parser.parse_args();m=extract(args.native,args.output)
    print(f"Preserved {len(m['originals'])} original files; unpacked {sum(len(a) for a in m['extracted'].values())} files")
