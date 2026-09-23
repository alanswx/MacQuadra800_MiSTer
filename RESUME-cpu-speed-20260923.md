# RESUME — CPU speed, 2026-09-23 (supersedes RESUME-cpu-speed-20260922b.md)

Goal unchanged: Speedometer 4.02 Benchmark Mix ~1.9 on the MiSTer (real Quadra 800: 1.897,
`docs/perf/real_quadra800.jpg`). User's ruling: 1.9 first, then area (CD-ROM + Ethernet back).
User on 2026-09-23: "keep going until we hit 1.9".

## Hardware ladder

| build | Mix | note |
|---|---:|---|
| P174 (`c152ac4`) | 1.460 | one-clock instruction hit |
| P182 (`122dab4`, seed 24, lite profile, CPU -0.718 ns) | **1.467** | P179-P182: MOVE destination at the read ack, PEA d16 as LEA, FPU (An), the MOVE store hinted in the predicted ack. Dhrystone +1.5 %, Towers +2.2 %, Quick +1.3 %, **Whetstone flat** |

Per-test vs the real machine (P174): Whetstone 60 % of real and 62 % of the Mix gap; Dhrystone 66 %,
Permutations 63 %, Queens 70 %, Towers 74 %; Bubble/Sieve/Quick within 12 %; Puzzle and Int. Matrix
already faster than real.

## The finding that reorders everything: Whetstone is store-drain bound on hardware

- The kernel fixtures' RAM model is fixed-latency and optimistic.  Whetstone with separate read/write
  latency (`scratch/p184_merge/tb_cpu_whetstone_wl.sv`, `+wlatency=`): read latency 3->8 is +0.4 %,
  **write latency 3->8 is +39 %**.  The data cache is write-through (a real Quadra runs copyback), so
  every one of ~2.4M stores per loop drains to SDRAM.  P174->P182 on hardware matched the fixture only
  at the high write latency.
- A store cost ~6 clk_sys on the platform path (store buffer -> wombat_bus32 -> service FSM S_MEM ->
  bridge -> registered acks back), whatever the SDRAM did.
- **P185/P186/P188** (`docs/P185_POSTED_WRITE_PATH_20260923.md`): an eight-entry write FIFO in
  `sdram_beat32` drained back to back on clk_ram; quadra800 pushes store-buffer RAM writes straight
  into it (`DIRECT_WRITES`, `bus_wr_direct`, acknowledged through `bus_miss_ack`); the store buffer
  drains back to back.  tb_line_dma: 4,096 stores 24,576 -> 9,712 clocks, 0 errors (with SONIC DMA,
  sized stores, a negative control).  **Projected Whetstone -17 % on hardware.**
- The full-machine sim (`verilator/sim.v`) acknowledges RAM in one clock: it cannot show memory-path
  effects at all.  The bridge benches (`tb_sdram`, `tb_memory_path*`, `tb_line_dma`) are the ground
  truth for the platform side.

## CPU work landed today (sim, all oracles pass)

- P179-P182 (above).  P184 (`docs/P184_P175_P178_ON_P182_20260923.md`): P175b/P177/P175c/P178 back on
  top, with **the P178 hang fixed** (the cross-line hit's next-row pair read had no same-clock write
  check: `idle_next_valid`) and P175b's Int. Matrix/Sieve regression fixed (hinted fetches leave the
  data banks on the data hint in their first clock).  Both P178 boot configurations that crashed now
  boot to the Finder in the full-machine sim (`scratch/sim_p184/run81{b,d}`).
- P187: a spanning store (2-mod-4 stack longword) captures its merge words so the next read keeps its
  idle read (Whetstone -1.6 % with fast stores).
- P184 vs P182 fixtures (lat 3): Permutations -9 %, Puzzle -8 %, Dhrystone -6 %, Towers -4 %.

## Fits

| fit | ALMs | CPU clock | note |
|---|---:|---:|---|
| P179 seed 24 lite | 39,113 | -3.153 | not run |
| P182 seed 24 lite | 39,229 | -0.718 | measured 1.467 |
| P184 seed 24 lite | 39,567 | — | routing FAILED |
| P186 seed 24 **development** profile | 38,505 | -1.722 | clk_ram->clk_sys crossing -1.369: not run; fixed in P188 |
| P188 seed 24 development profile | | | fitting at hand-off (`q800-p188-fit-20260923`) |

Dev fits now source `configs/cpu_development.tcl` (OSDs, audio out, Y/C off too).  After every fit
check `scratch/<tag>_fit_*/cross.log` (the bridge crossings), not only the .sta summary.

## Fixtures and tools

- `scripts/cpu/speedometer_suite.sh <tree>`: Towers, Puzzle, Quick, Int. Matrix, Sieve, Bubble with
  oracles and negative controls (about a minute).  Whetstone/Dhrystone/Permutations/Queens runners:
  copies in `scratch/p187_span/` (`run_whetstone_wl.py` takes `EXTRA_PLUSARGS=+wlatency=N`).
- Probes worth reusing (`scratch/p186_sb/tb_wf.sv`, `tb_w.sv`): memory-visit histograms (MHIST),
  slow reads by issuing state/opcode (MSLOW), why a hinted read missed the one-clock hit (WHY), the
  cache state while a read waits (WST/WIDLE), per-PC clocks in the SANE add wrapper (PCX).
- Hardware runs: an Opus agent with the P182 prompt (this session) works; `mister_ws.py` mouse
  commands are refused by this box's mrext, so shut down with `/media/fat/Scripts/q800tools/vmouse.py`
  and screenshots.  Speedometer Command-B = keycodes 56 + 48.

## Next

1. Measure P188 on hardware (expect Whetstone up sharply; also confirms the P178 fix on silicon).
2. Whetstone after the store fix (fixtures with writes latency 1): memory states still ~36 % of clocks.
   Hinted reads that miss the one-clock hit: data waiting behind a fetch (164k), misaligned stack
   longwords (194k), no MMU vouch (185k).  SANE add wrapper 63 clocks/call (a real 040 ~45-50).
3. The general "memory states are not states" pipelining (the next request registered in a predicted
   acknowledge clock; P182 is its first instance, the cache's `c_hint_away` guard its safety net).
4. Area, after 1.9.
