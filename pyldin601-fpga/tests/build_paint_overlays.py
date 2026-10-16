"""Build the production Paint overlays in a private regression directory."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from build_paint import build
build()
