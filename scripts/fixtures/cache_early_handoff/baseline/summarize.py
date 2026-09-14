#!/usr/bin/env python3
"""Summarize actual transactions, never raw combinational look_hit cycles."""
import argparse
import collections
import pathlib
import re

p = argparse.ArgumentParser()
p.add_argument('log', type=pathlib.Path)
a = p.parse_args()
lines = a.log.read_text().splitlines()
assert any(x.startswith('LATENCY_GUEST_PASS ') for x in lines), 'guest incomplete'
rows = []
for line in lines:
    if line.startswith('LATENCY_TX '):
        fields = dict(re.findall(r'(\w+)=(-?[0-9a-f]+)', line))
        rows.append({k: int(v, 16 if k in ('pc', 'addr') else 10)
                     for k, v in fields.items()})
print('phase data_reads hits misses passes faults early_success current_request_read latency(cycles,walk,CE,hit):count')
for phase in range(1, 10):
    data = [r for r in rows if r['phase'] == phase and not r['instr'] and not r['write']]
    counts = collections.Counter((r['cycles'], r['walk'], r['ce_stalls'], r['hit']) for r in data)
    print(phase, len(data), *(sum(r[k] for r in data) for k in ('hit', 'miss', 'pass', 'fault')),
          sum(r['early'] and r['hit'] and not r['fault'] for r in data),
          sum(r['current_read'] for r in data), dict(counts))
print('actual_idle_completions', sum(x.startswith('IDLE_HIT ') for x in lines))
print(next(x for x in lines if x.startswith('LATENCY_GUEST_PASS ')))
