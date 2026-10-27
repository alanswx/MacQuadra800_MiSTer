#!/usr/bin/env python3
"""Summarise a sim_prof040.h profile (profile.tsv) as readable tables.

usage: prof_report.py profile.tsv [--windows] [--lat] [--hot N] [--trim-idle]
--trim-idle drops trailing 2^20-cycle windows whose VRAM beat count is below
5 % of the peak window (the idle tail after the benchmark completes) and
reports what fraction of the bracket that was.
"""
import sys
from collections import defaultdict


def load(path):
    rows = defaultdict(list)
    for line in open(path):
        parts = line.rstrip("\n").split("\t")
        if parts and parts[0]:
            rows[parts[0]].append(parts[1:])
    return rows


def isnum(s):
    try:
        int(s); return True
    except (ValueError, TypeError):
        return False


def main():
    args = sys.argv[1:]
    path = args[0]
    rows = load(path)
    # drop header rows (second field non-numeric) from the tabular sections
    for k in ("STALL", "BUSY", "XACT", "LAT", "RETIRE", "ROMCACHE", "WINDOW", "TRAP", "HOT"):
        rows[k] = [r for r in rows.get(k, []) if len(r) > 1 and (isnum(r[1]) or k in ("ROMCACHE",))]
    summ = {r[0]: r[1] for r in rows["SUMMARY"]}
    cycles = int(summ["cycles"])
    retire = int(summ["retirements"])
    print(f"bracket: {cycles:,} cycles = {cycles/33.33e6:.2f} s at 33 MHz, {retire:,} retirements, IPC {float(summ['ipc']):.3f} (CPI {float(summ['cpi']):.2f})")
    if "--trim-idle" in args:
        wins = [r for r in rows["WINDOW"] if r[0] != "idx"]
        beats = [int(w[2]) for w in wins]
        peak = max(beats) if beats else 0
        n = len(wins)
        while n > 1 and beats[n - 1] < 0.05 * peak:
            n -= 1
        print(f"idle tail: {len(wins) - n} of {len(wins)} windows ({(len(wins) - n) / max(1, len(wins)) * 100:.1f} % of the bracket) below 5 % of the peak VRAM beat rate")
    print()
    print("retirements per cycle:")
    for r in rows["RETIRE"]:
        print(f"  {r[0]:>12} {int(r[1]):>14,} {r[2]:>8}")
    print()
    print("zero-retire cycles by heuristic reason:")
    for r in rows["STALL"]:
        print(f"  {r[0]:<26} {int(r[1]):>14,} {r[2]:>8}")
    print()
    print("cycles with a core-side transfer outstanding (class, cycles, % of bracket, retirements under it):")
    for r in rows["BUSY"]:
        extra = f"  retires {int(r[3]):,}" if len(r) > 3 else ""
        print(f"  {r[0]:<18} {int(r[1]):>14,} {r[2]:>8}{extra}")
    print()
    print("transactions (class, count, cycles, mean latency, max, per 1000 retirements):")
    for r in rows["XACT"]:
        if len(r) >= 6:
            print(f"  {r[0]:<22} {int(r[1]):>12,} {int(r[2]):>14,} {float(r[3]):>7.2f} {int(r[4]):>6} {float(r[5]):>8.2f}")
        else:
            print(f"  {r[0]:<22} {int(r[1]):>12,} {int(r[2]):>14,} {float(r[3]):>7.2f}")
    print()
    print("external ROM cache sweep (16-byte lines; the stream the core's own caches let through):")
    for r in rows["ROMCACHE"]:
        if r[0] in ("line_refs", "distinct_lines"):
            print(f"  {r[0]:<14} {' '.join(r[1:])}")
        elif r[0] != "cache":
            print(f"  {r[0]:<12} refs {int(r[1]):>10,} misses {int(r[2]):>9,} miss {r[3]:>8} per-1000-retire {float(r[4]):>6.2f}")
    print()
    print("VRAM:")
    for r in rows["VRAM"]:
        if r[0].endswith("gap_log2") and r[1] == "bucket":
            continue
        print(f"  {' '.join(r)}")
    print()
    print("time by trap (nearest preceding trap-table entry; cycles charged to the retiring instruction):")
    for r in rows["TRAP"][:40]:
        if r[0] == "name":
            continue
        print(f"  {r[0]:<28} {int(r[1]):>14,} {r[2]:>8}  retires {int(r[3]):>12,}  cpi {float(r[4]):>6.2f}")
    nhot = 20
    if "--hot" in args:
        nhot = int(args[args.index("--hot") + 1])
    print()
    print("hottest 16-byte PC buckets:")
    for r in rows["HOT"][:nhot + 1]:
        if r[0] == "pc_bucket":
            continue
        print(f"  {r[0]} {int(r[1]):>12,} {r[2]:>7}  retires {int(r[3]):>10,}  cpi {float(r[4]):>6.2f}  {r[5]}")
    if "--lat" in args:
        print()
        print("latency histograms:")
        cur = None
        for r in rows["LAT"]:
            if r[0] == "class":
                continue
            if r[0] != cur:
                cur = r[0]
                print(f"  {cur}:")
            print(f"    {int(r[1]):>4} {int(r[2]):>12,}")
    if "--windows" in args:
        print()
        print("windows (2^20 cycles): idx retires vram_beats stall_if_rom stall_dr_vram stall_dw_vram stall_dr_ram stall_if_ram stall_dmu stall_internal")
        for r in rows["WINDOW"]:
            print("  " + " ".join(r))


if __name__ == "__main__":
    main()
