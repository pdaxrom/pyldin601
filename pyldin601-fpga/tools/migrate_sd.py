#!/usr/bin/env python3
"""Prepare the native-partition SD update on a regular backup; never write a device."""
import argparse,hashlib,json,mmap,os,shutil,stat,struct,subprocess,zlib
from pathlib import Path
import make_sd as sd
import sd_partitions as partitions
from update_boot import root_files
from unias_boot import build as build_boot
ROOT=Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()
def data_volume(extracted,utilities):
    work=ROOT/'build/migration';work.mkdir(parents=True,exist_ok=True)
    subprocess.run(['cc','-O2','-std=c11',str(ROOT/'tools/pack_fat12.c'),str(ROOT/'host/hg/fat12.c'),'-o',str(work/'pack')],check=True)
    blank=work/'empty.img';blank.write_bytes(partitions.fat12('P601 DATA',0x06012026))
    args=['ARCHIVES=']+[f'ARCHIVES/{p.name}={p}' for p in sorted((extracted/'original').iterdir()) if p.is_file()]
    files={p.name:p for p in (extracted/'unpacked').iterdir() if p.is_file()}
    files.update({p.name:p for p in (extracted/'original').iterdir() if p.suffix in ('.CMD','.PGM')})
    files.update({p.name:p for p in utilities.glob('*.PGM')})
    # These replace old jobs which first unpacked from C: onto the removed D:.
    for name,text in {'E90.JOB':'e90.pgm','GD.JOB':'gd.cmd','TLO.JOB':'tlo.cmd','UASM.JOB':'uasm.cmd','PASCAL.JOB':'dir *.pgm'}.items():
        p=work/name;p.write_bytes((text+'\r\n').encode('ascii'));files[name]=p
    args += [f'{n}={p}' for n,p in sorted(files.items())]
    output=work/'data.img'
    subprocess.run([str(work/'pack'),str(blank),str(output),*args],check=True)
    return output.read_bytes(),dict(root_files={n:sha(p.read_bytes()) for n,p in files.items()},original_archives='ARCHIVES',extraction=json.loads((extracted/'manifest.json').read_text()))
def boot_files(backup,parts):
    """Read only the boot volume; callers may provide a large read-only mmap."""
    boot=next((p for p in parts if p.number==1),None)
    if not boot or boot.kind not in (6,14) or boot.start!=sd.ALIGN or boot.sectors!=sd.BOOT_SECTORS:
        raise ValueError('expected the existing FAT16 boot partition at primary 1')
    for part in parts:
        if part.number in (2,3) and part.kind==1:partitions.bpb(backup[part.start*512:(part.start+1)*512],part.sectors)
    begin,end=boot.start*512,(boot.start+boot.sectors)*512
    files=root_files(backup[begin:end]);rom=files['P601.ROM']
    if (rom[:8]!=b'P601BOOT' or sd.u32(rom,8) not in (1,2) or sd.u32(rom,12)!=sd.ROM_BASE
        or sd.u32(rom,16)!=len(rom)-512 or sd.u32(rom,20)!=zlib.crc32(rom[512:])
        or sd.u32(rom,508)!=zlib.crc32(rom[:508])):raise ValueError('invalid source ROM bundle')
    font_offset=0x51000 if sd.u32(rom,8)==1 else 0x11000
    native={'ROM0.BIN':rom[512:512+65536],'FONT.BIN':rom[512+font_offset:]}
    if len(native['FONT.BIN'])!=2048:raise ValueError('source font size')
    for model,name in [(0,'P601.ROM'),(1,'P601A.ROM')]:files[name]=sd.bundle(native,[],0,model)
    files['LOADER.BIN']=build_boot('loader')[0]
    files.setdefault('P601.SET',sd.settings_record())
    config=json.loads(files.get('P601.CFG',b'{}'));config.update(version=2,controller='native-sd-lba',boot_partition='AUTO',rom_bytes=sd.ROM_SIZE,models=['601','601A'])
    for key in ['drives','boot_drive']:config.pop(key,None)
    files['P601.CFG']=(json.dumps(config,indent=2)+'\n').encode('ascii')
    return boot,files,config,sd.u32(rom,8)
def prepare(backup,extracted=None,add_data=True,force_data=False):
    parts=partitions.scan(backup,max_logical=32)
    boot,files,config,version=boot_files(backup,parts)
    begin,end=boot.start*512,(boot.start+boot.sectors)*512
    result=bytearray(backup);result[begin:end]=sd.fat16(files)
    report=dict(input_sha256=sha(backup),boot_files_sha256={n:sha(d) for n,d in files.items()},data_partition=None,preserved_partitions=[])
    if add_data and (version==1 or force_data):
        volume,details=data_volume(extracted or ROOT/'build/romdisk-extracted',ROOT/'build/storage')
        result,number=partitions.append(result,volume)
        report.update(data_partition=number,software=details)
        config['data_partition']=number
        files['P601.CFG']=(json.dumps(config,indent=2)+'\n').encode('ascii')
        result=bytearray(result);result[begin:end]=sd.fat16(files)
    aligned=(len(result)+512*1024-1)//(512*1024)*512*1024
    result=bytes(result)+bytes(aligned-len(result))
    for part in parts:
        if part.number==1 or part.kind in partitions.EXTENDED:continue
        old=backup[part.start*512:(part.start+part.sectors)*512]
        if result[part.start*512:(part.start+part.sectors)*512]!=old:raise ValueError('existing data changed')
        report['preserved_partitions'].append(dict(number=part.number,start=part.start,sectors=part.sectors,sha256=sha(old)))
    partitions.scan(result,max_logical=32)
    report.update(output_sha256=sha(result),bytes=len(result),settings_sha256=sha(files['P601.SET']),boot_files_sha256={n:sha(d) for n,d in files.items()})
    return result,report

def file_sha(stream,start=0,length=None):
    """Hash with a bounded buffer, including multi-gigabyte foreign volumes."""
    stream.seek(start);digest=hashlib.sha256()
    remaining=length
    while remaining is None or remaining:
        data=stream.read(4*1024*1024 if remaining is None else min(remaining,4*1024*1024))
        if not data:
            if remaining:raise ValueError('short backup or output file')
            break
        digest.update(data)
        if remaining is not None:remaining-=len(data)
    return digest.hexdigest()

def prepare_file(backup,output,extracted=None,add_data=True,force_data=False):
    """Stream a full card backup; only boot/data volumes reside in RAM."""
    backup,output=Path(backup),Path(output)
    with backup.open('rb') as source:
        info=source.fileno()
        if not stat.S_ISREG(os.fstat(info).st_mode):
            raise ValueError('backup must be a regular image')
        with mmap.mmap(info,0,access=mmap.ACCESS_READ) as image:
            parts=partitions.scan(image,max_logical=32)
            boot,files,config,version=boot_files(image,parts)
            plan=None;volume=None
            report=dict(input_sha256=file_sha(source),data_partition=None,preserved_partitions=[])
            if add_data and (version==1 or force_data):
                volume,details=data_volume(extracted or ROOT/'build/romdisk-extracted',ROOT/'build/storage')
                plan=partitions.append_plan(image,len(volume)//512)
                report.update(data_partition=plan['number'],software=details)
                config['data_partition']=plan['number']
                files['P601.CFG']=(json.dumps(config,indent=2)+'\n').encode('ascii')
            replacement=sd.fat16(files)
            length=plan['bytes'] if plan else len(image)
            length=(length+512*1024-1)//(512*1024)*512*1024
            # Exclusive creation leaves the original backup intact. Copy uses
            # a fixed-size buffer rather than bytearray(the entire SD card).
            with output.open('x+b') as target:
                source.seek(0);shutil.copyfileobj(source,target,4*1024*1024)
                target.truncate(length)
                target.seek(boot.start*512);target.write(replacement)
                if plan:
                    for table,sector in plan['writes'].items():
                        target.seek(table*512);target.write(sector)
                    target.seek(plan['start']*512);target.write(volume)
                target.flush()
                with mmap.mmap(target.fileno(),0,access=mmap.ACCESS_READ) as result:
                    partitions.scan(result,max_logical=32)
                for part in parts:
                    if part.number==1 or part.kind in partitions.EXTENDED:continue
                    old=file_sha(source,part.start*512,part.sectors*512)
                    if file_sha(target,part.start*512,part.sectors*512)!=old:
                        raise ValueError('existing data changed')
                    report['preserved_partitions'].append(dict(number=part.number,start=part.start,sectors=part.sectors,sha256=old))
                report.update(output_sha256=file_sha(target),bytes=length,settings_sha256=sha(files['P601.SET']),boot_files_sha256={n:sha(d) for n,d in files.items()})
    return report
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--backup',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--boot-only',action='store_true');a=p.parse_args()
    if not stat.S_ISREG(a.backup.stat().st_mode):raise ValueError('backup must be a regular image')
    report=prepare_file(a.backup,a.output,add_data=not a.boot_only)
    a.output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k] for k in ['bytes','data_partition','preserved_partitions']},indent=2))
