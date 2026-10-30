#!/usr/bin/env python3
"""Group a TimeQuest pairs report (timequest_families.tcl) by start and end
register: the worst slack, the count and the summed negative slack of each
family.  Usage: path_families.py cpu_pairs3000.txt [N]"""
import re, sys

def node(s):
    s = s.strip()
    if 'altsyncram' in s or 'dpram' in s:
        inst = s.split('|altsyncram')[0].split('|dpram')[0]
        s = inst.split('|')[-1] + '.RAM'
    else:
        parts = s.split('|')
        s = parts[-2].split(':')[-1] + '.' + parts[-1] if len(parts) > 1 else parts[-1]
    s = re.sub(r'\[\d+\]', '', s)
    s = re.sub(r'~DUPLICATE|_OTERM\d+|~_Duplicate_\d+', '', s)
    return s

fam = {}
for line in open(sys.argv[1]):
    m = re.match(r';\s*(-?\d+\.\d+)\s*;\s*(\S+)\s*;\s*(\S+)\s*;', line)
    if not m:
        continue
    sl = float(m[1])
    k = (node(m[2]), node(m[3]))
    w, n, t = fam.get(k, (sl, 0, 0.0))
    fam[k] = (min(w, sl), n + 1, t + min(sl, 0.0))
n = int(sys.argv[2]) if len(sys.argv) > 2 else 30
for k, (w, c, t) in sorted(fam.items(), key=lambda x: x[1][0])[:n]:
    print(f'{w:7.3f} {c:5d} {t:9.2f}  {k[0]} -> {k[1]}')
