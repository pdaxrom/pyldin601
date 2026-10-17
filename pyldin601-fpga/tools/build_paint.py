"""Build Paint with native UniAS/UniAR/UniLD and three standard PGM overlays."""
from pathlib import Path
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get('PAINT_BUILD_OUT', str(ROOT/'build/paint-overlays'))).resolve()
TC = Path(os.environ.get('UNIAS', '/Users/sash/Work/FPGA/hd6303-toolchain/unias')).resolve()
LD = Path(os.environ.get('UNILD', str(TC.parent/'unild'))).resolve()
AR = Path(os.environ.get('UNIAR', str(TC.parent/'uniar'))).resolve()
MODULES = 'PNTMAIN PNTUI PNTCANV PNTDRAW PNTPART PNTPAL PNTDMA PNTLOAD PNTMOD PNTIO PNTPCX PNTIFF PNTFILE PNTVIEW PNTTOOLS PNTTEXT PNTDATA PNTSTATE PNTSTR'.split()
VARIANTS = {'PNTUI', 'PNTDRAW', 'PNTPART', 'PNTPCX', 'PNTIFF', 'PNTFILE', 'PNTVIEW', 'PNTTOOLS', 'PNTTEXT'}


def run(args, name):
    with (OUT/(name+'.log')).open('wb') as log:
        p = subprocess.run(args, cwd=OUT, stdout=log, stderr=subprocess.STDOUT)
    if p.returncode:
        text = (OUT/(name+'.log')).read_text(errors='replace').replace('\r', '\n')
        print('\n'.join(x for x in text.splitlines() if 'Error' in x or 'Line ' in x or 'extent' in x))
        raise RuntimeError(str(OUT/name))


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    for path in (ROOT/'firmware/paint').iterdir():
        if path.is_file():
            shutil.copyfile(path, OUT/path.name)
    for directory, names in [('nc', ('NCCOM.ASM','NCKEY.ASM','NCABI.INC','NCBOX.INC')),
                             ('input', ('MOUSE.ASM',)), ('memory', ('DMA.INC',)), ('gfx', ('PALCOEF.ASM',))]:
        for name in names:
            shutil.copyfile(ROOT/'firmware'/directory/name, OUT/name)
    for name in MODULES+['PNTCOM','NCKEY','MOUSE','PNTEND']:
        modes = [('EDO','PNT_EDIT'),('FIO','PNT_FILES'),('TOO','PNT_TOOLS')] if name in VARIANTS else [('OBJ','PNT_EDIT')]
        for suffix, flag in modes:
            target = name+'.'+suffix
            run([str(TC), '-c', '-D', flag, *(['-D','MOUSE_OBJECT'] if name=='MOUSE' else []),
                 '-l', target+'.LST', '-o', target, name+'.ASM'], target)
    (OUT/'PNTCOM.LIB').unlink(missing_ok=True)
    run([str(AR),'r','PNTCOM.LIB','PNTCOM.OBJ','NCKEY.OBJ','MOUSE.OBJ'], 'archive')
    maps = []
    for suffix, core, mapname, link in [('EDO','PNTCORE','PAINT','PAINT'),('FIO','PNTFIO','PNTFIO','PNTFIO'),('TOO','PNTOPS','PNTOPS','PNTOPS')]:
        expected = ''.join(n+('.'+suffix if n in VARIANTS else '.OBJ')+'\n' for n in MODULES)+'PNTCOM.LIB\nPNTEND.OBJ\n'
        assert (OUT/(link+'.LNK')).read_text()==expected, 'native link file differs from build plan'
        run([str(LD),'-z','16768','-m',mapname+'.MAP','-o',core+'.PGM','@'+link+'.LNK'], core)
        maps.append((OUT/(mapname+'.MAP')).read_text())
    def data_map(text):
        m = [line.split() for line in text.splitlines() if line.startswith('M ')]
        return [(x[1],x[4],x[5]) for x in m]
    assert data_map(maps[0])==data_map(maps[1]), 'overlay BSS layouts differ'
    def symbols(text):
        return {line.split()[1]:int(line.split()[2]) for line in text.splitlines() if line.startswith('S ')}
    a,b,c = map(symbols,maps)
    assert data_map(maps[0])==data_map(maps[2]), 'tool overlay BSS differs'
    for name in ('PAINT_READY','PAINT_IDLE','PAINT_RESTORED','MOUSE_EVENT','PAINT_POINTER','P_PARAMS'):
        assert a[name]==b[name]==c[name], (name,a[name],b[name],c[name])
    for source, target in [('PNTOVL','PNTBOOT'),('PNTNAT','PNTNAT'),('PNTRGB','PNTRGB'),('PNTHAM','PNTHAM')]:
        run([str(TC),'-l',source+'.LST','-o',target+'.PGM',source+'.ASM'],source)
    run([str(LD),'-b','-o','PAINT.PGM','PNTBOOT.PGM','PNTCORE.PGM','PNTFIO.PGM','PNTOPS.PGM'],'bundle')
    print('Paint: shared BSS and IRQ/idle entry points verified; standard native PGM overlays')


if __name__=='__main__':
    build()
