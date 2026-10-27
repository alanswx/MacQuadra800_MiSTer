#!/usr/bin/env python3
"""Find one-frame video glitches in a kvms `frames` directory.

A row is transient in frame i when it differs from frame i-1 while frame i+1
matches frame i-1 on that row: the picture went somewhere for one frame and
came back.  Drawing (progress bars, the pointer, windows) does not do that;
a torn, shifted or flickering scanline does.  Capture noise is handled with a
per-pixel threshold and a minimum count of differing pixels per row.
Usage: transient.py DIR [--min-px N]
"""
import sys, os, glob
import numpy as np
from PIL import Image

d = sys.argv[1]
min_px = 12
if '--min-px' in sys.argv:
    min_px = int(sys.argv[sys.argv.index('--min-px') + 1])
files = sorted(glob.glob(os.path.join(d, 'frame_*.png')))
def load(f):
    return np.asarray(Image.open(f).convert('RGB'), dtype=np.int16)
def rowdiff(a, b):
    if a.shape != b.shape:
        return None
    m = (np.abs(a - b).max(axis=2) > 48)
    return m.sum(axis=1)
hits = []
prev = load(files[0]) if files else None
cur = load(files[1]) if len(files) > 1 else None
for i in range(1, len(files) - 1):
    nxt = load(files[i + 1])
    d_pc = rowdiff(prev, cur)
    d_pn = rowdiff(prev, nxt)
    if d_pc is not None and d_pn is not None:
        rows = np.where((d_pc >= min_px) & (d_pn < 2))[0]
        if len(rows):
            hits.append((os.path.basename(files[i]), len(rows), int(rows.min()), int(rows.max()), int(d_pc[rows].max())))
    prev, cur = cur, nxt
print(f'{d}: {len(files)} frames, {len(hits)} with transient rows')
for h in hits:
    print(f'  {h[0]}: {h[1]} rows, y {h[2]}..{h[3]}, up to {h[4]} px/row')
