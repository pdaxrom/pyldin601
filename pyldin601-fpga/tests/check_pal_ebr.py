"""Audit the actual Synplify PAL ROM bit planes and optionally simulate Lattice EBR.

Run after synthesis, before programming. This caught the 8192-word RGB332
address reversal that a behavioural $readmemh simulation cannot detect.
The vendor libraries stay outside the repository.
"""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def children(node, kind):
    return [x for x in node if isinstance(x, list) and x and x[0] == kind]


def name(node):
    return node[2][1:-1] if isinstance(node, list) and node[0] == 'rename' else node


def parse(text):
    stack = [[]]
    for token in re.findall(r'"(?:\\.|[^"\\])*"|[()]|[^\s()]+', text):
        if token == '(':
            child = []
            stack[-1].append(child)
            stack.append(child)
        elif token == ')':
            if len(stack) == 1:
                raise ValueError('unbalanced EDIF')
            stack.pop()
        else:
            stack[-1].append(token)
    if len(stack) != 1:
        raise ValueError('incomplete EDIF')
    return stack[0][0]


def pal_roms(edif):
    for lib in children(edif, 'library'):
        for cell in children(lib, 'cell'):
            if not str(name(cell[1])).startswith('classic_pal_encoder'):
                continue
            contents = children(children(cell, 'view')[0], 'contents')[0]
            connections = {}
            for net in children(contents, 'net'):
                for port in children(children(net, 'joined')[0], 'portRef'):
                    instance = children(port, 'instanceRef')
                    if instance and isinstance(port[1], str):
                        connections[(name(instance[0][1]), port[1])] = name(net[1])
            for inst in children(contents, 'instance'):
                ref = children(children(inst, 'viewRef')[0], 'cellRef')[0][1]
                if ref not in ('SP8KC', 'DP8KC'):
                    continue
                props = {p[1]: p[2][1].strip('"') for p in children(inst, 'property')}
                props['_primitive'] = ref
                props['_pins'] = {pin: net for (label, pin), net in connections.items() if label == name(inst[1])}
                yield name(inst[1]), props


def rom_values(props, count):
    width = int(props.get('DATA_WIDTH', props.get('DATA_WIDTH_A', 9)))
    assert width in (1, 9), width
    assert props.get('REGMODE', 'NOREG') == 'NOREG', 'unexpected EBR output register'
    if props['_primitive'] == 'DP8KC':
        assert props.get('DATA_WIDTH_B') == '1' and width == 1
        assert props.get('REGMODE_A', 'NOREG') == props.get('REGMODE_B', 'NOREG') == 'NOREG'
        assert props.get('WRITEMODE_B') == 'READBEFOREWRITE'
    init = sum(int(props[f'INITVAL_{n:02X}'], 16) << (320 * n) for n in range(32))
    # Lattice DP8KC: each 20 INIT bits store 18 physical bits; x1 skips parity.
    memory = [(init >> (20 * (i // 18) + i % 18)) & 1 for i in range(9216)]
    return [sum(memory[width * a + (a // 8 if width == 1 else 0) + b] << b
                for b in range(width)) for a in range(count)]


def inspect(path):
    roms = list(pal_roms(parse(path.read_text())))
    planes = {}
    legacy = None
    for label, props in roms:
        if label.startswith(('rgb.value_2_0_', 'table_rgb_1_table_rgb_')):
            bit = int(label.rsplit('_', 1)[1])
            assert bit not in planes
            if props['_primitive'] == 'DP8KC':
                pins = props['_pins']
                assert pins['DIB1'] in (f'cpu_out[{bit}]', f'palette_data[{bit}]'), 'incorrect x1 CPU data pin'
                assert pins['DOA0'] == f'value[{bit}]' and pins['DOB0'] == f'palette_result[{bit}]'
                for n in range(13):
                    assert pins[f'ADB{n}'] == f'palette_address[{n}]'
                    fast_port = pins['CLKA'] == 'clk_fast'
                    expected_pin = (f'picture_phase[{n}]' if n < 5 else f'read_address[{n}]') if fast_port else \
                        'phase[31]' if n == 4 else f'carrier_phase[{n}]' if n < 4 else f'rgb_pixel[{n-5}]'
                    assert pins[f'ADA{n}'] == expected_pin
                assert pins['CLKB'] == 'clk' and pins['CLKA'] in ('clk', 'clk_fast')
            planes[bit] = props
        elif label == 'sample_2_0_0':
            legacy = props
        else:
            raise AssertionError(f'unexpected PAL EBR {label}')
    assert set(planes) == set(range(6)) and legacy is not None, 'missing PAL EBR'
    bits = [rom_values(planes[b], 8192) for b in range(6)]
    rgb = [sum(bits[b][a] << b for b in range(6)) for a in range(8192)]
    expected = [int(v, 16) for v in (ROOT / 'rtl/pal_rgb332.mem').read_text().split()]
    classic = [int(v, 16) for v in (ROOT / 'rtl/pal_waveform.mem').read_text().split()]
    assert len(expected) == 8192 and len(classic) == 1024
    for label, actual, wanted in [('RGB332', rgb, expected),
                                  ('IRGB/burst', rom_values(legacy, 1024), classic)]:
        bad = [a for a, (x, y) in enumerate(zip(actual, wanted)) if x != y]
        if bad:
            at = bad[0]
            raise AssertionError(f'{label}: {len(bad)} wrong EBR words; address {at:04x}: '
                                 f'DAC {actual[at]} != {wanted[at]}')
    print('PASS synthesized EBR: 8192 RGB332 and 1024 IRGB/burst words, correct address order', flush=True)
    return planes, legacy


def vendor_test(planes, legacy, library, output):
    output.mkdir(parents=True, exist_ok=True)
    lines = ['`timescale 1ns/1ps', 'module tb_pal_ebr;',
             'reg clk=0; always #25 clk=~clk; reg fast=0;always #6.25 fast=~fast;', 'reg[12:0] addr=0;',
             'wire[5:0] rgb; wire[8:0] classic;',
             'GSR GSR_INST(1\'b1); PUR PUR_INST(1\'b1);']
    for bit, props in list(planes.items()) + [(6, legacy)]:
        params = ','.join(f'.{key}({value if key.startswith("DATA_WIDTH") else chr(34)+value+chr(34)})'
                          for key, value in sorted(props.items()) if key != 'syn_ramstyle' and not key.startswith('_'))
        if props['_primitive'] == 'DP8KC':
            pins = [f'.AD{port}{b}({"addr["+str(b)+"]" if port=="A" else "write_addr["+str(b)+"]"})'
                    for port in ('A', 'B') for b in range(13)]
            # Lattice x1 writes use DI1 (x1 reads use DO0).
            pins += [f'.DI{port}{b}({"write_data["+str(bit)+"]" if port=="B" and b==1 else "1\'b0"})'
                     for port in ('A', 'B') for b in range(9)]
            for port in ('A', 'B'):
                pins += [f'.CE{port}(1\'b1)', f'.OCE{port}(1\'b1)', f'.WE{port}({"write_enable" if port=="B" else "1\'b0"})',
                         f'.RST{port}(1\'b0)', f'.CLK{port}({"fast" if port=="A" and props["_pins"]["CLKA"]=="clk_fast" else "clk"})']
                pins += [f'.CS{port}{b}(1\'b0)' for b in range(3)]
            pins += [f'.DOA0(rgb[{bit}])', f'.DOB0(readback[{bit}])']
            lines.append(f'DP8KC #({params}) rom{bit}({",".join(pins)});')
            continue
        pins = [f'.AD{b}({"addr["+str(b)+"]" if bit < 6 else "addr["+str(b-3)+"]" if b >= 3 else "1\'b0"})'
                for b in range(13)]
        pins += [f'.DI{b}(1\'b0)' for b in range(9)]
        pins += ['.CE(1\'b1)', '.OCE(1\'b1)', '.WE(1\'b0)', '.RST(1\'b0)', '.CLK(clk)',
                 '.CS0(1\'b0)', '.CS1(1\'b0)', '.CS2(1\'b0)']
        pins += [f'.DO0(rgb[{bit}])'] if bit < 6 else [f'.DO{b}(classic[{b}])' for b in range(9)]
        lines.append(f'SP8KC #({params}) rom{bit}({",".join(pins)});')
    lines[5:5] = ['reg[12:0]write_addr=0;reg[5:0]write_data=0;reg write_enable=0;wire[5:0]readback;']
    lines += ['reg[5:0] expected[0:8191]; reg[5:0] expected_classic[0:1023];',
              'initial begin', '$readmemh("rtl/pal_rgb332.mem",expected);',
              '$readmemh("rtl/pal_waveform.mem",expected_classic);',
              'repeat(3)@(negedge clk);',
              'for(integer a=0;a<8192;a=a+1)begin',
              '@(negedge clk);addr=a;@(posedge clk);#2;',
              'if(rgb!==expected[a])$fatal(1,"vendor RGB address %d got %h expected %h",a,rgb,expected[a]);',
              'if(a<1024&&classic!=={3\'b0,expected_classic[a]})$fatal(1,"vendor IRGB address %d",a);',
              'end']
    if all(p['_primitive'] == 'DP8KC' for p in planes.values()):
        lines += ['for(integer a=0;a<8192;a=a+1)begin',
                  '@(negedge clk);write_addr=a;write_data=(a*37+(a>>5)+19)&63;write_enable=1;',
                  '@(posedge clk);#2;if(readback!==expected[a])$fatal(1,"vendor read-before-write address %d",a);',
                  '@(negedge clk);write_enable=0;addr=a;@(posedge clk);#2;',
                  'if(rgb!==write_data||readback!==write_data)$fatal(1,"vendor dual-port write/read address %d",a);end']
    lines += ['$display("PASS Lattice SP8KC/DP8KC: all PAL addresses, dual-port write/readback and synchronous latency");',
              '$finish;end endmodule']
    source = output / 'tb_pal_ebr.v'
    source.write_text('\n'.join(lines).replace('#2;', '#8;') + '\n')
    binary = output / 'tb_pal_ebr'
    subprocess.run(['iverilog', '-g2012', '-s', 'tb_pal_ebr', '-o', str(binary), str(source),
                    *[str(library / (n + '.v')) for n in ('SP8KC', 'DP8KC', 'GSR', 'PUR')]],
                   check=True, cwd=ROOT)
    subprocess.run(['vvp', str(binary)], check=True, cwd=ROOT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('netlist', type=Path)
    parser.add_argument('--vendor-library', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/pal-ebr')
    args = parser.parse_args()
    planes, legacy = inspect(args.netlist)
    if args.vendor_library:
        vendor_test(planes, legacy, args.vendor_library, args.output.resolve())


if __name__ == '__main__':
    main()
