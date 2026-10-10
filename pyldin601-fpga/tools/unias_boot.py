"""Assemble bootstrap sources with UniAS, translating long-branch mnemonics only."""
import os,re,shutil
from pathlib import Path
from build_partitions import assemble
ROOT=Path(__file__).resolve().parents[1]
INVERSE={'eq':'ne','ne':'eq','cs':'cc','cc':'cs','lo':'hs','hs':'lo','hi':'ls','ls':'hi','mi':'pl','pl':'mi','ge':'lt','lt':'ge','gt':'le','le':'gt','vc':'vs','vs':'vc'}
def portable(source):
    # Old bootstrap constants used case to distinguish COMMAND/command etc.
    # UniAS identifiers are case-insensitive; give constants distinct names.
    constants=re.findall(r"^([A-Z][A-Z0-9_]*)\s+equ\b",source,re.M)
    for name in constants:
        source="\n".join("".join(re.sub(r"\b"+name+r"\b","B_"+name,part) if i%2==0 else part for i,part in enumerate(re.split(r'(\"[^\"]*\")',line))) for line in source.split("\n"))
    lines=[];serial=0
    for line in source.splitlines():
        line=re.sub(r'^([A-Za-z_][\w]*):',r'\1',line)
        m=re.fullmatch(r'\s+lb(\w+)\s+([^;]+)(?:;.*)?',line)
        if m:
            op,target=m.groups();serial+=1
            if op=='ra':lines.append('    jmp '+target.strip())
            else:
                label=f'long_branch_{serial}'
                lines.extend(['    b'+INVERSE[op]+' '+label,'    jmp '+target.strip(),label])
        else:lines.append(line)
    return '\n'.join(lines)+'\n'
def build(name='boot',unias=None):
    unias=unias or os.environ.get('UNIAS') or shutil.which('unias') or '/Users/sash/Work/FPGA/hd6303-toolchain/unias'
    unias=shutil.which(unias) or str(Path(unias).resolve())
    out=ROOT/'build/bootstrap';out.mkdir(parents=True,exist_ok=True)
    if name=='boot':
        source=(ROOT/'firmware/boot.asm').read_text()
        # UniAS concatenates ORG segments. Explicit fill retains ROM offsets.
        source=source.replace('    org $fa00','    ds $fa00-*,$ff\n    org $fa00').replace('    org $fff8','    ds $fff8-*,$ff\n    org $fff8')
        source+='\n'+(ROOT/'firmware/setup.asm').read_text()+'    ds $e000-*,$ff\n'
    else:source=(ROOT/'firmware/loader.asm').read_text()
    (out/(name+'.asm')).write_text(portable(source)+'    end\n')
    data=assemble(str(Path(unias).resolve()),out,name+'.asm',name+'.bin')
    labels={}
    for line in (out/(name+'.bin.LST')).read_text().splitlines():
        m=re.match(r'^\s*([0-9A-Fa-f]{4})\s+(?:[0-9A-Fa-f]{2}\s+)*\d+\s+([\w]+)\s*(?:equ|$)',line)
        if m:labels[m.group(2).lower()]=int(m.group(1),16)
    # UniAS symbol table is the authoritative source of cross-segment addresses.
    for line in (out/(name+'.bin.LST')).read_text().splitlines():
        m=re.match(r'^([\w]+)\s*=\$([0-9A-Fa-f]{4,8})\s*$',line)
        if m:labels[m.group(1).removeprefix('B_').lower()]=int(m.group(2),16)
    return data,labels
