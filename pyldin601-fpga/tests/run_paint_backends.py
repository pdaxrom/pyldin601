"""Execute actual MC6800 Paint row modules in ordinary and banked RAM."""
import argparse
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cc',default='cc');a=p.parse_args()
runner=ROOT/'build/paint/test_backends'
subprocess.run([a.cc,'-O2','-I../pyldin601/src','tests/test_paint_backends.c','-o',str(runner)],cwd=ROOT,check=True)
for model in ('601','601a'):
 for cpu in ('mc6800','hd6303'):subprocess.run([str(runner),model,cpu],cwd=ROOT,check=True)
