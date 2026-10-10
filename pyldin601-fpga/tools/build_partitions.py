#!/usr/bin/env python3
"""Build MC6800 partition ROMs and patched native boot with the real UniAS."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
ROOT=Path(__file__).resolve().parents[1]

def assemble(unias,out,source,output,defines=()):
    r=subprocess.run([unias,*defines,'-l',output+'.LST','-o',output,source],cwd=out,capture_output=True,text=True)
    (out/(output+'.log')).write_text(r.stdout+r.stderr)
    if r.returncode or 'Error:' in r.stdout:
        raise RuntimeError('\n'.join(l for l in (r.stdout+r.stderr).splitlines() if 'Error:' in l or 'Line ' in l or 'unias:' in l))
    return (out/output).read_bytes()

def data_source(data):
    return ''.join('    db '+','.join(f'${n:02x}' for n in data[k:k+16])+'\n' for k in range(0,len(data),16))

def build(unias):
    unias=shutil.which(unias) or str(Path(unias).resolve())
    out=ROOT/'build/partitions';out.mkdir(exist_ok=True,parents=True)
    native=ROOT.parent/'native-src'
    for p in (ROOT/'firmware/partitions').glob('*'):
        if p.is_file():shutil.copyfile(p,out/p.name)
    for n in ('DIRECTSD.ASM','RAWSD.ASM','SERVICES.ASM'):shutil.copyfile(ROOT/'firmware/extension'/n,out/n)
    shutil.copyfile(ROOT/'firmware/gfx/GFXCLIP.ASM',out/'GFXCLIP.ASM')
    shutil.copyfile(native/'MEMORY.INC',out/'MEMORY.INC')
    shell=(native/'UNIDOS.ASM').read_text(encoding='latin1')
    shell=shell.replace('\t\tclr\tfdcslct\n\t\tinc\tfdcslct\n','')
    a=shell.index('\nver_ok\n')+len('\nver_ok\n');b=shell.index('floppyok\tclr\tlast_drive',a)
    shell=shell[:a]+shell[b:]
    # Native COPY fills almost up to its own SP. Nested DOS -> SD/HG SWIs
    # need stack space below that SP while the file buffer is populated.
    # Reserve 512 bytes before rounding the transfer length to whole sectors.
    old="\t\tsbcb\tbuff_ptr\n\t\tandb\t#$FE\n\t\tbne\tmem_ok\n"
    new="\t\tsbcb\tbuff_ptr\n\t\tsuba\t#0\n\t\tsbcb\t#2\n\t\tbcs\tcopy_no_memory\n\t\tandb\t#$FE\n\t\tbne\tmem_ok\ncopy_no_memory\n"
    if shell.count(old)!=1:raise ValueError('cannot locate native COPY stack budget')
    shell=shell.replace(old,new)
    (out/'SHELL.ASM').write_text(shell,encoding='latin1')
    shell_data=assemble(unias,out,'SHELL.ASM','SHELL.CMD')
    split=8000
    (out/'SHELLTAIL.INC').write_text(f'SHELL_SPLIT equ {split}\nSHELL_LENGTH equ {len(shell_data)}\nshell_tail\n'+data_source(shell_data[split:]))
    (out/'SHELLROM.ASM').write_text('''    org $c000
    dw $5aa5
    db "UniShell"
    jmp shell_init
    jmp shell_init
    db $e3
    dw shell_copy
    db 0
shell_init
    rts
shell_copy
    ldx #shell_bytes
    stx $bf8c
    ldx #$1000
    stx $bf9a
shell_loop
    ldx $bf8c
    ldaa 0,x
    inx
    stx $bf8c
    ldx $bf9a
    staa 0,x
    inx
    stx $bf9a
    cpx #$1000+8000
    bne shell_loop
    rts
shell_bytes
'''+data_source(shell_data[:split])+'''    checksum
    ds $e000-*,$ff
    end
''')
    built={}
    for src,name,defines in [('DIRECTSD.ASM','SD.ROM',('-D','GFXCLIP_ROM')),('SHELLROM.ASM','SHELL.ROM',()),('PARTS.ASM','PARTS.ROM',())]:
        data=assemble(unias,out,src,name,defines)
        if len(data)!=8192 or sum(data)%256:raise ValueError('invalid checksummed ROM: '+name)
        built[name]=len(data)
    # Keep native BIOS addresses: replace the floppy boot block with an INT E1
    # entry and pad to the original reset loop. UniAS computes the ROM checksum.
    for model in ['BIOS','BIOS_A']:
        source=(native/(model+'.ASM')).read_text(encoding='latin1')
        (out/(model+'.ASM')).write_text(source,encoding='latin1')
        original=assemble(unias,out,model+'.ASM',model+'-BASE.ROM')
        # The native source disables listings inside the reset procedure.
        # Its fallback loop is INT 1; BRA back to INT 1. Locate that unique
        # sequence in the assembled original so later entry points stay fixed.
        loop=bytes.fromhex('3f0120fc')
        positions=[i for i in range(1024) if original[i:i+4]==loop]
        if len(positions)!=1:raise ValueError('cannot locate native reset loop')
        limit=0xf000+positions[0]
        start=source.index('\t\tcli\n\t\tldaa\tfdcstat')
        end=source.index('nofloppy\nresetloop',start)
        source=source[:start]+f'\t\tcli\n\t\tldaa\t#7\n\t\tint\t$e1\n\t\tds\t${limit:04x}-*,1\n'+source[end:]
        (out/(model+'.ASM')).write_text(source,encoding='latin1')
        data=assemble(unias,out,model+'.ASM',model+'.ROM')
        if len(data)!=4096 or sum(data)%256:raise ValueError('invalid system BIOS')
        built[model+'.ROM']=len(data)
    (out/'manifest.json').write_text(json.dumps(dict(assembler=unias,roms=built,shell_bytes=len(shell_data)),indent=2)+'\n')
    print('UniAS partition ROMs built: '+', '.join(built))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--unias',default='unias');a=p.parse_args();build(a.unias)
