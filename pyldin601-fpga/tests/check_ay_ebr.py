"""Check the synthesized AY DP8KC initialization and optional vendor chip test."""
import argparse
from pathlib import Path
import subprocess
from check_pal_ebr import parse, children, name
ROOT=Path(__file__).resolve().parents[1]

def inspect(path):
    found=[]
    for lib in children(parse(path.read_text()),'library'):
        for cell in children(lib,'cell'):
            if not str(name(cell[1])).startswith('classic_ay8910'):
                continue
            contents=children(children(cell,'view')[0],'contents')[0]
            pins={}
            for net in children(contents,'net'):
                for port in children(children(net,'joined')[0],'portRef'):
                    instance=children(port,'instanceRef')
                    if instance and isinstance(port[1],str):
                        pins[(name(instance[0][1]),port[1])]=name(net[1])
            for inst in children(contents,'instance'):
                ref=children(children(inst,'viewRef')[0],'cellRef')[0][1]
                if ref!='DP8KC':continue
                props={p[1]:p[2][1].strip('"') for p in children(inst,'property')}
                label=name(inst[1])
                # x9 writes require the low address pin as a byte enable.
                # Correct initialization alone cannot catch a disconnected
                # write port, so inspect the actual synthesized connections.
                assert pins[(label,'ADA0')]=='VCC','AY x9 byte-write enable must be high'
                assert pins[(label,'ADA1')]==pins[(label,'ADA2')]=='GND'
                for bit in range(13):
                    actual_pin=pins[(label,f'ADB{bit}')]
                    expected_pin=f'address_0_iv_i[{bit-3}]' if 3<=bit<=6 else 'GND'
                    assert actual_pin==expected_pin,(bit,actual_pin,expected_pin)
                found.append(props)
    assert len(found)==1,'AY must occupy exactly one physical EBR'
    props=found[0]
    assert props['DATA_WIDTH_A']==props['DATA_WIDTH_B']=='9'
    assert props['REGMODE_A']==props['REGMODE_B']=='NOREG'
    assert props['WRITEMODE_A']==props['WRITEMODE_B']=='READBEFOREWRITE'
    init=sum(int(props[f'INITVAL_{n:02X}'],16)<<(320*n) for n in range(32))
    actual=[(init>>(20*(a//2)+9*(a%2)))&511 for a in range(1024)]
    expected=[int(v,16) for v in (ROOT/'rtl/ay8910.mem').read_text().split()]
    assert actual==expected,'synthesized AY register/counter/volume/microcode RAM differs'
    print('PASS synthesized AY DP8KC: one 1024x9 EBR, all words, port modes and initialization',flush=True)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('netlist',type=Path);p.add_argument('--vendor-library',type=Path)
    p.add_argument('--output',type=Path,default=ROOT/'build/ay/vendor')
    args=p.parse_args();inspect(args.netlist)
    if not args.vendor_library:return
    args.output.mkdir(parents=True,exist_ok=True)
    source=(ROOT/'tests/tb_ay8910.v').read_text()
    # Full long-period test runs in the ordinary chip reference test. Here
    # exercise the actual primitive, both ports and all shapes without
    # repeating 131080 slow vendor-model ticks for the 65535 envelope period.
    source=source.replace('frames(131080)','frames(256)').replace('checks<150000','checks<10000')
    fixture=args.output/'tb_ay_vendor.v';fixture.write_text(source)
    binary=args.output/'tb_ay_vendor'
    subprocess.run(['iverilog','-g2012','-DSYNTHESIS','-s','tb_ay8910','-o',str(binary),
                    str(ROOT/'rtl/classic_ay8910.v'),str(fixture),
                    *[str(args.vendor_library/(n+'.v')) for n in ('DP8KC','GSR','PUR')]],check=True,cwd=ROOT)
    subprocess.run(['vvp',str(binary)],check=True,cwd=ROOT)
if __name__=='__main__':main()
