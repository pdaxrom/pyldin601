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

def bios_symbols(listing):
    return {name:int(value,16) for name,value in
            re.findall(r'^([A-Z][A-Z0-9_]*) =\$([0-9A-F]+)$',listing,re.M)}

def shift_frame_operands(source, label, replacements):
    """Adjust native routines which directly inspect the SWI stack frame."""
    start=re.search(r'^'+label+r'\s*(?:proc\b)?',source,re.M)
    if not start:raise ValueError('cannot locate native frame consumer: '+label)
    end=source.index('\t\tendp',start.end())
    body=source[start.start():end]
    for old,new in replacements:
        if body.count(old)!=1:raise ValueError('unexpected frame operand in '+label+': '+old)
        body=body.replace(old,new)
    return source[:start.start()]+body+source[end:]

def monitor_frame(unias,out,native):
    # The supplied UniBIOS binary differs from UNIBIOS.ASM. Retain every native
    # instruction/address and font byte; assemble only the two changed sites.
    from make_sd import rom_files
    rom=rom_files(native)['ROM0.BIN'][:8192]
    signature=b'\x31'*10+b'\x7a\x00\x00\x8d'
    if rom.count(signature)!=1:raise ValueError('cannot locate native monitor frame unwind')
    unwind=rom.index(signature);entry=unwind-15
    if rom[entry:entry+3]!=bytes.fromhex('30ee08') or rom[unwind+15]!=0x7e:
        raise ValueError('unexpected native monitor breakpoint')
    displacement=rom[unwind+14];displacement-=256 if displacement>=128 else 0
    regdump=0xc000+unwind+15+displacement
    loop=int.from_bytes(rom[unwind+16:unwind+18],'big')
    (out/'MONLAYOUT.INC').write_text(f'MON_REGDUMP equ ${regdump:04x}\nMON_LOOP equ ${loop:04x}\npaged_breakpoint_return equ $f800\n')
    for name,data in [('MONPREFIX.INC',rom[:entry]),('MONBODY.INC',rom[entry+3:unwind]),
                      ('MONTEXT.INC',rom[unwind+3:6143]),('MONFONT.INC',rom[6144:])]:
        (out/name).write_text(data_source(data))
    data=assemble(unias,out,'MONPAGES.ASM','UNIBIOS.ROM')
    if len(data)!=8192 or sum(data)%256:raise ValueError('invalid paging monitor ROM')
    changed={entry+2,*range(unwind,unwind+3),6143}
    if any(a not in changed and data[a]!=rom[a] for a in range(8192)):
        raise ValueError('unrelated native monitor bytes changed')

def paging_bios(source, symbols, model):
    # Relocate the dispatch into the now-unused floppy routine. Trampolines
    # and explicit pads retain ALL native BIOS public addresses and vectors.
    # Replace only the first three-byte instruction of IRQ entry; the native
    # keyboard/timer dispatcher and all absolute BIOS entry points stay put.
    entry='irqhndl\n\t\tldab\tswipag+4'
    if source.count(entry)!=1:raise ValueError('cannot locate native IRQ entry')
    source=source.replace(entry,'irqhndl\n\t\tjmp\taudio_irq_dispatch',1)
    source=f'audio_native_irq equ ${symbols["IRQHNDL"]+3:04x}\n'+source
    start=source.index('irqhndl1\tldaa\trompage')
    end=source.index('\t\tendp',start)
    source=source[:start]+('irqhndl1\tjmp\tpaged_irq\n'
             f'\t\tds\t${symbols["SWIHNDL"]:04x}-*,1\n')+source[end:]
    match=re.search(r'^swihndl\s+proc\b.*?^\s*endp\b',source,re.M|re.S)
    if not match:raise ValueError('cannot locate native SWI dispatcher')
    source=source[:match.start()]+('swihndl\tproc\n\t\tjmp\tpaged_swi\n'
             f'\t\tds\t${symbols["RESET"]:04x}-*,1\n\t\tendp')+source[match.end():]
    match=re.search(r'^int17\s+proc\b.*?^\s*endp\b',source,re.M|re.S)
    if not match:raise ValueError('cannot locate unused native floppy routine')
    stop=symbols['RS232C' if model=='BIOS' else 'INT20']
    source=source[:match.start()]+('int17\tproc\n\t\tsei\n\t\tldaa\t#1\n\t\trts\n'
             '\t\tinclude\tBIOSPAGES.INC\n'
             '\t\tds\t$f800-*,$ff\n\t\tinclude\tMONRETURN.INC\n'
             f'\t\tds\t${stop:04x}-*,$ff\n\t\tendp')+source[match.end():]
    source=shift_frame_operands(source,'int_37',[
        ('stab\t2,x','stab\t3,x'),('stab\t8,x','stab\t9,x'),
        ('staa\t9,x','staa\t10,x'),('ldaa\t3,x','ldaa\t4,x'),
        ('ldab\t4,x','ldab\t5,x'),('ldaa\t5,x','ldaa\t6,x'),
        ('ldx\t6,x','ldx\t7,x')])
    return source

def build(unias):
    unias=shutil.which(unias) or str(Path(unias).resolve())
    out=ROOT/'build/partitions';out.mkdir(exist_ok=True,parents=True)
    native=ROOT.parent/'native-src'
    for p in (ROOT/'firmware/partitions').glob('*'):
        if p.is_file():shutil.copyfile(p,out/p.name)
    for n in ('DIRECTSD.ASM','RAWSD.ASM','SERVICES.ASM'):shutil.copyfile(ROOT/'firmware/extension'/n,out/n)
    shutil.copyfile(ROOT/'firmware/gfx/GFXCLIP.ASM',out/'GFXCLIP.ASM')
    shutil.copyfile(native/'MEMORY.INC',out/'MEMORY.INC')
    for p in (ROOT/'firmware/memory').glob('*'):
        if p.is_file():shutil.copyfile(p,out/p.name)
    monitor_frame(unias,out,ROOT.parent/'native')
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
    shell=shift_frame_operands(shell,'terminate',[
        ('staa\tx, 2','staa\tx, 3'),('staa\tx, 9','staa\tx, 10'),
        ('staa\tx, 8','staa\tx, 9')])
    # Release expansion-RAM leases before disposing of the current PCB.
    # This covers normal return, INT38, nested commands and JOB/error exits.
    anchor='close_PCB\tproc\n'
    start=shell.index(anchor)
    pos=shell.index('\t\tldx\tcurrent_PCB\n',start)
    shell=shell[:pos]+'\t\tldaa\t#3\n\t\tint\t$e5\n'+shell[pos:]
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
    built={'UNIBIOS.ROM':8192}
    for src,name,defines in [('DIRECTSD.ASM','SD.ROM',('-D','GFXCLIP_ROM')),('SHELLROM.ASM','SHELL.ROM',()),('PARTS.ASM','PARTS.ROM',()),('RAMMAN.ASM','RAMMAN.ROM',())]:
        data=assemble(unias,out,src,name,defines)
        if len(data)!=8192 or sum(data)%256:raise ValueError('invalid checksummed ROM: '+name)
        built[name]=len(data)
    # Keep native BIOS addresses: replace the floppy boot block with an INT E1
    # entry and pad to the original reset loop. UniAS computes the ROM checksum.
    for model in ['BIOS','BIOS_A']:
        source=(native/(model+'.ASM')).read_text(encoding='latin1')
        (out/(model+'.ASM')).write_text(source,encoding='latin1')
        original=assemble(unias,out,model+'.ASM',model+'-BASE.ROM')
        symbols=bios_symbols((out/(model+'-BASE.ROM.LST')).read_text(encoding='latin1'))
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
        source=paging_bios(source,symbols,model)
        layout=(out/'MONLAYOUT.INC').read_text().replace('paged_breakpoint_return equ $f800\n','')
        source=layout+source
        (out/(model+'.ASM')).write_text(source,encoding='latin1')
        data=assemble(unias,out,model+'.ASM',model+'.ROM')
        if len(data)!=4096 or sum(data)%256:raise ValueError('invalid system BIOS')
        updated=bios_symbols((out/(model+'.ROM.LST')).read_text(encoding='latin1'))
        for name,address in symbols.items():
            if name in updated and updated[name]!=address:
                raise ValueError(f'native BIOS address moved: {model} {name}')
        built[model+'.ROM']=len(data)
    (out/'manifest.json').write_text(json.dumps(dict(assembler=unias,roms=built,shell_bytes=len(shell_data)),indent=2)+'\n')
    print('UniAS partition ROMs built: '+', '.join(built))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--unias',default='unias');a=p.parse_args();build(a.unias)
