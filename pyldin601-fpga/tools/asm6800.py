#!/usr/bin/env python3
"""Small deterministic two-pass MC6800 assembler for bootstrap firmware.

All absolute operands use extended addressing. Supports labels, EQU, ORG,
DB/DW and classic MC6800 instructions; HD6303 opcodes require explicit opt-in for the resident BIOS.
"""
import argparse
import ast
import operator
from pathlib import Path
import re

INHERENT = dict(nop=0x01,tap=0x06,tpa=0x07,inx=0x08,dex=0x09,clv=0x0a,sev=0x0b,
    clc=0x0c,sec=0x0d,cli=0x0e,sei=0x0f,sba=0x10,cba=0x11,tab=0x16,tba=0x17,
    daa=0x19,aba=0x1b,tsx=0x30,ins=0x31,pula=0x32,pulb=0x33,des=0x34,txs=0x35,
    psha=0x36,pshb=0x37,rts=0x39,rti=0x3b,wai=0x3e,swi=0x3f)
for name, op in dict(neg=0x40,com=0x43,lsr=0x44,ror=0x46,asr=0x47,asl=0x48,
                     rol=0x49,dec=0x4a,inc=0x4c,tst=0x4d,clr=0x4f).items():
    INHERENT[name+'a'] = op
    INHERENT[name+'b'] = op+0x10
BRANCH = dict(bra=0x20,bhi=0x22,bls=0x23,bcc=0x24,bcs=0x25,bne=0x26,beq=0x27,
    bvc=0x28,bvs=0x29,bpl=0x2a,bmi=0x2b,bge=0x2c,blt=0x2d,bgt=0x2e,ble=0x2f,bsr=0x8d)
GENERAL = dict(suba=0x80,cmpa=0x81,sbca=0x82,anda=0x84,bita=0x85,ldaa=0x86,
    staa=0x87,eora=0x88,adca=0x89,oraa=0x8a,adda=0x8b,cpx=0x8c,lds=0x8e,sts=0x8f,
    subb=0xc0,cmpb=0xc1,sbcb=0xc2,andb=0xc4,bitb=0xc5,ldab=0xc6,stab=0xc7,
    eorb=0xc8,adcb=0xc9,orab=0xca,addb=0xcb,ldx=0xce,stx=0xcf)
MEMORY = dict(neg=0x60,com=0x63,lsr=0x64,ror=0x66,asr=0x67,asl=0x68,rol=0x69,
              dec=0x6a,inc=0x6c,tst=0x6d,jmp=0x6e,clr=0x6f,jsr=0xad)
OPS={ast.Add:operator.add,ast.Sub:operator.sub,ast.Mult:operator.mul,
     ast.LShift:operator.lshift,ast.RShift:operator.rshift,ast.BitAnd:operator.and_,ast.BitOr:operator.or_}


def expression(text, labels, first=False):
    text=re.sub(r'\$([0-9a-fA-F]+)',r'0x\1',text.strip())
    def visit(node):
        if isinstance(node,ast.Constant): return ord(node.value) if isinstance(node.value,str) else node.value
        if isinstance(node,ast.Name):
            if first and node.id not in labels: return 0
            return labels[node.id]
        if isinstance(node,ast.BinOp) and type(node.op) in OPS:return OPS[type(node.op)](visit(node.left),visit(node.right))
        if isinstance(node,ast.UnaryOp) and isinstance(node.op,ast.USub):return -visit(node.operand)
        raise ValueError(f'unsupported expression {text}')
    return visit(ast.parse(text,mode='eval').body)


def assemble(source, origin=None, size=None, hd6303=False):
    inherent = {**INHERENT, **(dict(mul=0x3d, abx=0x3a, pshx=0x3c, pulx=0x38,
        xgdx=0x18, lsrd=0x04, asld=0x05) if hd6303 else {})}
    general = {**GENERAL, **(dict(ldd=0xcc, std=0xcd, addd=0xc3, subd=0x83)
                            if hd6303 else {})}
    lines=[]
    for index,line in enumerate(source.splitlines(),1):
        line=line.split(';',1)[0].strip()
        if not line:continue
        label=None
        if ':' in line:label,line=line.split(':',1);line=line.strip()
        parts=line.split(None,2)
        if len(parts)>1 and parts[1].lower()=='equ':
            lines.append((index,parts[0],'equ',parts[2]));continue
        op,_,arg=line.partition(' ')
        lines.append((index,label,op.lower(),arg.strip()))
    labels={}
    output={}
    for first in (True,False):
        pc=origin or 0
        for line,label,op,arg in lines:
            try:
                if op=='equ':
                    labels[label]=expression(arg,labels,first);continue
                if label:
                    if not first and labels[label]!=pc:raise ValueError('unstable label')
                    labels[label]=pc
                if op=='org':pc=expression(arg,labels,first);continue
                data=[]
                if not op:continue
                if op in ('db','dw'):
                    for item in re.findall(r'"[^"]*"|\x27[^\x27]*\x27|[^,]+',arg):
                        item=item.strip()
                        if op=='db' and item.startswith('"'):data.extend(ast.literal_eval(item).encode('ascii'))
                        else:
                            value=expression(item,labels,first)
                            data.extend([value>>8&255,value&255] if op=='dw' else [value&255])
                elif op in inherent:data=[inherent[op]]
                elif op.startswith('lb') and op[1:] in BRANCH:
                    target=expression(arg,labels,first)
                    short=op[1:]
                    if short in ('bra','bsr'):
                        data=[0x7e if short=='bra' else 0xbd,target>>8&255,target&255]
                    else:
                        data=[BRANCH[short]^1,3,0x7e,target>>8&255,target&255]
                elif op in BRANCH:
                    value=expression(arg,labels,first)-pc-2
                    if not first and not -128<=value<=127:raise ValueError('branch out of range')
                    data=[BRANCH[op],value&255]
                elif op in general or op in MEMORY:
                    immediate=arg.startswith('#');indexed=arg.lower().endswith(',x')
                    value=expression(arg[1:] if immediate else arg[:-2] if indexed else arg,labels,first)
                    if op in MEMORY:
                        if immediate:raise ValueError('memory operand cannot be immediate')
                        opcode=MEMORY[op]+(0 if indexed else 0x10)
                    else:
                        if immediate and op in ('staa','stab','stx','sts','std'):raise ValueError('store immediate')
                        opcode=general[op]+(0 if immediate else 0x20 if indexed else 0x30)
                    if indexed and not 0<=value<=255:raise ValueError('indexed offset outside 0..255')
                    wide=not indexed and (not immediate or op in ('ldx','lds','cpx','ldd','addd','subd'))
                    data=[opcode]+([value>>8&255,value&255] if wide else [value&255])
                else:raise ValueError(f'unknown instruction {op}')
                for byte in data:
                    if not first:
                        if pc in output:raise ValueError('overlapping ORG')
                        output[pc]=byte
                    pc+=1
            except Exception as error:raise ValueError(f'line {line}: {op} {arg}: {error}') from error
    lo=min(output) if origin is None else origin
    length=max(output)-lo+1 if size is None else size
    if min(output)<lo or max(output)>=lo+length:raise ValueError('output outside requested ROM')
    binary=bytearray([0xff]*length)
    for address,byte in output.items():binary[address-lo]=byte
    return bytes(binary),labels


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('source',type=Path);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--origin',type=lambda v:int(v,0));p.add_argument('--size',type=lambda v:int(v,0))
    p.add_argument('--mem',type=Path)
    p.add_argument('--hd6303', action='store_true')
    a=p.parse_args();binary,labels=assemble(a.source.read_text(),a.origin,a.size,hd6303=a.hd6303)
    a.output.write_bytes(binary)
    if a.mem:a.mem.write_text(''.join(f'{b:02x}\n' for b in binary))
    print(f'{a.source}: {len(binary)} bytes, {len(labels)} symbols')


if __name__=='__main__':main()
