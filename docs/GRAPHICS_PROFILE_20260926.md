# Why 8-bit QuickDraw runs at 59 % of a real Quadra 800 (2026-09-26)

Speedometer's Color Benchmark, 8 bit: **13.967 s on hardware** (build
`31b6e99`), **8.211 s on the real machine**.  The CPU Benchmark Mix is at
94 %, so the missing time is not general CPU speed.

## How it was measured

The full-machine Verilator sim of `31b6e99` (pipeline and `SCSI_CACHE_OFF`
macros) booted the `MacQuadra800-Speedometer402-profile.hda` fixture (Mac OS
7.5.5) with the fast-boot ROM.  Navigation went through the control stream
(`simkeys.py`, PS/2 scancodes; `color8_control.txt` is the exact stream):
MacAtrium -> Esc -> Tab Tab -> Return -> the Finder -> Mac7-5-5 ->
Applications -> Speedometer 4.02 Folder -> Speedometer 4.02 -> Cmd-G ->
`profile start` -> Return.

The sim ran the test in **12.442 s** (`sim_color8_result.png`).  That is
close enough to the hardware's 13.967 s (Mac OS 8.1 there) to use as a
model.  Two instruments were used:

- the CPU profiler (`--cpu-profile`, `color8_profile.tsv`), for state
  cycles and the memory-path counters;
- simulation-only counters in `quadra800.sv` (`gfx_counters.diff`).  They
  count, per 2^24 clocks, the cycles a CPU beat is presented to VRAM or RAM
  and the beats completed (`color8_vram_counters.log`;
  `boot81_vram_counters.log` is the Mac OS 8.1 boot for comparison).

## Findings

- **Every VRAM access costs 4 clocks at the platform**, reads and writes
  alike.  The sequence is: decode in S_IDLE, S_MEM, the VRAM port's
  capture/deliver phases, the registered `b_ack`, then the adapter's guard
  cycle.
- **Seen from the CPU, a VRAM read costs ~7.4 clocks.**  S_MRD spends 76 M
  clocks with the cache in C_PASS (uncached) over 10.3 M VRAM reads.
- **Posted writes block other accesses.**  S_MRD waits 21.5 M clocks and
  S_MWR 34.6 M clocks for the store buffer to drain (VRAM writes queued
  ahead).  The store buffer holds two entries.
- **MOVE16 is a large share of the test.**  2.5 M MOVE16 instructions, each
  moved as 4 separate longword reads and 4 separate writes, with a state per
  longword step (S_M16_RD/RD2/WR/WR2: 40 M clocks, 7.4 %).  MOVE16 makes 29 %
  of all S_MRD entries and 38 % of all S_MWR entries.  A real 68040 moves the
  line with one burst read and one burst write.
- Whole-test shares: S_MRD 36.9 %, S_MWR 15.0 %, S_FETCH 8.7 %, S_DECODE
  7.9 %; 6.58 clocks per dispatched instruction; VRAM bus time 17 % of all
  clocks (reads 7 %, writes 10 %).

## What to change, in order of expected gain

1. **A shorter VRAM path in the platform:**
   - a VRAM write acknowledged in S_IDLE and written straight into the
     BRAM, so the store buffer drains at 2 clocks per beat instead of 4;
   - a VRAM read without the capture/deliver phase.
   Both sit outside the CPU core's critical paths.
2. **MOVE16 as a line move:** chain the four reads at the acknowledge (as
   the MOVEM load chain does) and the four writes likewise, dropping the
   per-longword RD2/WR2 states.  Longer term, one 16-byte transfer each way.
3. **A deeper store buffer for VRAM** (or route VRAM writes through the
   SDRAM bridge's 8-entry posted FIFO).
