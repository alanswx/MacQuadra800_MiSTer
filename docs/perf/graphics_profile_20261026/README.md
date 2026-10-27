# Graphics profile of the dual-issue core, 2026-10-26

Why Speedometer's Graphics PR is 0.90 on the DDR3-VRAM dual core
(`pipelined-040-ddr3-vram` @ 97e2a4a) when the shipping core scores 1.17 and
a real Quadra 800 1.35, and whether a 256 KB ROM cache is the right lever.

## Method

Full-machine Verilator simulation (`verilator/sim.v`, `obj_dir040/Vemu`, the
dual core behind `quadra_cpu040`) booting Mac OS 8.1 from a disposable copy
of `QuadSquad8.hda` with the fastboot ROM, driven headless by the control
stream, with a new exact-workload profiler for the dual core
(`verilator/sim_prof040.h`, `--cpu-profile FILE`, `profile start/stop`).

The sim's own memory is ideal (ROM and VRAM answer in one or two clocks).
To attribute the hardware's extra time, `sim.v` gained a runtime DDR3
timing model (`model ddr3 1` plus `wrdrain`, `rdmiss`, `romkb`, `rommiss`
from the control stream) abstracting `vram_ddr3.sv` (16-entry write queue,
direct path closed below 12 free, 4 x 32-byte read line cache) and
`rom_cache_128k.sv` (direct-mapped, 16-byte lines). Every run boots
identically with the model off and switches it on just before the profiled
bracket, so one discovered click sequence replays on all of them.

Control-stream additions: `mouse X Y` (closed-loop ADB warp against
RawMouse $82C, small steps, arrives within a pixel), `btn 0|1`, `mv DX DY`,
`model KEY N`; `shot` is allowed while a warp is in progress.

Runs (identical boots; the model differs only inside the bracket):

| run | host | model | purpose |
|---|---|---|---|
| a_ideal | Mac | off | the core alone: CPU-side cost of QuickDraw on ideal memory |
| b_ddr3 | Mac | ddr3, 128 KB ROM cache, defaults | hardware-like |
| c_rom256 | Mac | ddr3, 256 KB ROM cache | the proposed change |
| d_romideal | Mac | ddr3, ROM cache 1 MB / miss 1 | VRAM cost alone |
| e_vramideal | misterubuntu | ddr3, wrdrain 1 / rdmiss 2 | ROM cost alone |
| f_rom64 | misterubuntu | ddr3, 64 KB ROM cache | sensitivity below |
| g_drain4 | misterubuntu | ddr3, wrdrain 4 | slower VRAM drain |
| h_rom512 | misterubuntu | ddr3, 512 KB ROM cache | sensitivity above |

Sim speed: ~380 kHz per process on the M4 Max, ~330 kHz on the i9 with four
processes; the 8.1 desktop appears at 1.73 G cycles (52 guest seconds).

## Results

(filled in from `profile.tsv` of each run; `prof_report.py` summarises)

## Files

- `sim_prof040.h`, `sim_main.cpp`, `sim_control.h`, `sim.v`, `Makefile`:
  the sim changes (diff against 97e2a4a's `verilator/`)
- `prof_report.py`: TSV summariser
- `traps.txt`: trap number -> name from MPW 3.2.3 `Traps.h`
- `control_*.txt`: the control streams used
- `profile_*.tsv`: the raw profiles

## Step 1 (2026-10-26 evening): read-modify-write hits the VRAM read cache

`rtl/vram_ddr3.sv` (patch: `step1_vram_ddr3.patch`, file: `vram_ddr3_step1.sv`):

- Mechanism found by reading the RTL after the profile: the 4 x 32-byte read
  line cache invalidated the whole 64-bit beat a CPU write touched AND refused
  a hit whenever the write FIFO held that 64-bit word (`fifo_conflict`).
  QuickDraw's RMW walks a row as read lo / write lo / read hi / write hi, so
  every second read missed, forced a FIFO drain and a 4-beat DDR3 refill.
- Change: valid bits per BYTE (32 per way); a write clears only the bytes it
  wrote; a fill leaves bytes that still have a queued write invalid
  (`line_pending`, the FIFO scanned against the line's tag); hits need no
  conflict check; the fill gate (`fifo_conflict`) is now per 32-bit half.
  No data-merge logic, ~no extra ALMs expected (a few compares + 64 flops).
- Evidence: `verilator/tb_vram_ddr3.sv` + two new tests. Test 14 (8-long RMW
  stream): old RTL 5 line fills, new RTL 1. Test 15 (write queued, line
  filled through a neighbour, read the queued word): never stale. All 13
  original tests still pass on the new RTL.
- Build: misterubuntu `~/mister/q800_step1_rmw_20261026` (unit
  `q800-step1-rmw`, seed 40, the DDR3-VRAM branch recipe), log
  `build_step1.log`.
- Hardware judge: Speedometer Graphics PR and Color QuickDraw 8-bit on
  mister192 vs the 14:55 rbf (0.901 / 12.2 s).
- Area lesson (v1 -> v2): the first version kept a per-byte pending map of
  the line (16-entry FIFO scan with an indexed 8-bit OR per entry) so fills
  could mark only the non-pending bytes valid. Synthesis: vram_ddr3 2,262 ->
  3,450 ALUTs (+1,188). v2 gates the fill on "no queued write in this
  32-byte line" instead (16 tag compares, the same scan the old per-word
  conflict used) and marks every filled byte valid; same testbench results
  (Test 14: 1 fill; Test 15: never stale). v1 build left running for its
  timing number only; v2 (`~/mister/q800_step1v2_rmw_20261026`, unit
  `q800-step1v2-rmw`) is the candidate.
- Baseline on mister192: `_Development/MacQuadra800.rbf` dated 14:55, md5
  c6304fda0d82 (not the 13:02 misterubuntu build, 1880d854f5ba; origin
  unknown), preserved as `MacQuadra800_base_a8ba3fa.rbf` (name is a guess;
  the md5 is the identity). The A/B is same-session on both, so the delta
  stands regardless.
- Builds (2026-10-26 evening, misterubuntu, DDR3-VRAM branch recipe, seed 40):
  * v1 (per-byte pending map): 37,757 ALMs (90 %), HDMI clock -0.097 ns
    (CPU +1.286), rbf not used.
  * v2 (line_conflict, the candidate): 37,438 ALMs (89 %, baseline 36,838),
    vram_ddr3 entity 1,616 -> 1,905 ALMs (+289), 2,262 -> 2,601 ALUTs, regs
    1,966 -> 2,079; timing met on every clock (HDMI +0.320, CPU general[1]
    +0.556, general[0] +0.998). rbf md5 ba716328da4f, on the Mac as
    `~/dev2/q800_prof_20261026/hw/MacQuadra800_step1v2_rmw_261026.rbf`.
    Seeds 41 and 42 of v2 were also run as a hedge (results in their dirs).
  * Hardware A/B delegated to an Opus session with `hw_ab_brief.md`; results
    land in `~/dev2/q800_prof_20261026/hw/results/`.
  * v2 seed 42: timing met (CPU general[1] +0.199, HDMI +0.302, general[0]
    +1.335), rbf md5 575a3a11c1a8. Seed 40 (HDMI +0.320 / CPU +0.556) remains
    the candidate. Seed 41 pending.
  * v2 seed 41: timing met (HDMI +0.407, CPU general[1] +0.485, general[0]
    +1.392), rbf md5 d1d0c8605ce8. All three v2 seeds close timing.
  * Step 1+2 combined (`~/mister/q800_step12_20261026`, seed 40): 37,341 ALMs
    (89 %), timing met on every clock (HDMI +0.430, CPU general[1] +0.610,
    general[0] +1.263), rbf md5 ffc2fa767b7a, on the Mac as
    `hw/MacQuadra800_step12_261026.rbf`. Gate for hardware: the Step 2 full-sim
    Mac OS 8.1 boot (`s2boot/`) must reach the desktop and launch Speedometer.

## Hardware A/B #1 (mister192, 2026-10-26 ~20:20-21:00, delegated session)

Same session, same disk (QuadSquad8_dual.hda), 8.1, 32 MB, 640x480; clicks via
mister_ws.py as down/0.2 s/up; cores loaded from the safe-to-switch-off screen
via /dev/MiSTer_cmd (the Mac cannot ssh to the box directly).

| rbf | Graphics PR (3 runs) | median | Mono | 2-bit | 4-bit | 8-bit | 16-bit |
|---|---|---|---|---|---|---|---|
| candidate step1v2 (ba716328) | 0.901/0.898/0.898 | 0.898 | 7.595 | 8.775 | 10.023 | 12.785 | 17.161 |
| box baseline (c6304fda, 14:55) | 0.848/0.846/0.846 | 0.846 | 8.172 | 9.399 | 10.406 | 13.207 | 17.251 |
| delta | | +0.052 (+6.1 %) | -7.1 % | -6.6 % | -3.7 % | -3.2 % | -0.5 % |

No pixel dropouts/stale pixels/garbage on either (sampled frames). Run-to-run
spread 0.002-0.003.
CAVEAT: the box baseline is NOT the handoff's a8ba3fa build (handoff: 0.901 /
12.208 s); its md5 matches no known build and its numbers match the older
pre-ROM-cache DDR3 builds (~0.85 / 13.2 s). The candidate (= a8ba3fa RTL +
Step 1) lands at the handoff's a8ba3fa figure, so Step 1's gain over the
ROM-cache build is NOT yet established. Proper baseline = misterubuntu
`~/mister/q800_ddr3_vram/output_files/MacQuadra800.rbf` (md5 1880d854f5ba,
built 13:02 from a8ba3fa). A/B #2 requested against it. The depth pattern
(low depths -7 %, 16-bit -0.5 %) is what a read-cache fix would do and what a
ROM cache would not, so some of the delta is likely real.
Results/screenshots: ~/dev2/q800_prof_20261026/hw/results/.

## Hardware A/B #2 (correct a8ba3fa baseline, same session)

| rbf | Graphics PR | median | Mono | 2-bit | 4-bit | 8-bit | 16-bit |
|---|---|---|---|---|---|---|---|
| a8ba3fa (1880d854f5ba) | 0.885/0.883/0.883 | 0.883 | 7.604 | 8.833 | 10.013 | 12.754 | 17.167 |
| step1v2 rerun (ba716328) | 0.905 | 0.905 | 7.576 | 8.723 | 9.967 | 12.706 | 17.079 |
| step1v2 in A/B #1 | 0.901/0.898/0.898 | 0.898 | 7.595 | 8.775 | 10.023 | 12.785 | 17.161 |

Step 1 vs a8ba3fa: Graphics PR +0.015..+0.022 (+1.7..2.5 %), every candidate
run above every baseline run; Color depths within ~1 % (noise). Visually clean.
The handoff's a8ba3fa numbers (0.901 / 12.208 s) did not reproduce (0.883 /
12.754 s today): different conditions, not a regression of ours.
=> The RMW read-miss was real but small (~2 % of Graphics PR), not the 11 %
DDR3 gap. The rest of the DDR3 penalty is elsewhere: candidates are sequential
source-read misses every 32 bytes (no prefetch), the read-hit latency through
the registered ack (~3-4 CPU clocks vs 2 for BRAM), display-DMA collisions,
and the write FIFO closing the direct path under burst fills.

## Step 2 correctness gate (full sim, 2026-10-26 ~22:15)

`s2boot/`: the Step 2 core (dmu+biu change) booted Mac OS 8.1 from the
disposable image to the desktop, launched Speedometer 4.02 by double-click,
dismissed the splash and the registration dialog, and showed the Hardware
Information window -- screenshots f4340/f4814/f5325/f5522 identical in content
to the reference a_ideal run; 26 BERR lines identical to the reference (ROM
slot probe), no CPU halt, no visible corruption. (First attempt's clicks fired
at 29 guest s because the wait was given in ticks, not edges; redone.)
=> Hardware A/B #3 requested: step12 (ffc2fa767b7a) vs a8ba3fa (1880d854f5ba).
- Step 3 (VRAM reads gated on st_older instead of dm_older): no effect in the
  microbench (K3 21.0 -> 21.0, K6 read+mul 20.0 -> 20.0); reverted. The
  uncached read's cost is the engine's load sequence + bus handshake, not the
  serialization. See gfxbench/RESULTS.md.

## Hardware A/B #3 (step12 = Step 1+2 vs a8ba3fa, same session)

| rbf | Graphics PR | median | Mono | 2-bit | 4-bit | 8-bit | 16-bit |
|---|---|---|---|---|---|---|---|
| step12 (ffc2fa767b7a) | 0.926/0.922/0.922 | 0.922 | 7.532 | 8.607 | 9.774 | 12.286 | 16.405 |
| a8ba3fa (1880d854f5ba) | 0.893/0.890/0.891 | 0.891 | 7.619 | 8.847 | 10.001 | 12.778 | 17.183 |
| delta | | +0.031 (+3.5 %) | -1.1 % | -2.7 % | -2.3 % | -3.9 % | -4.5 % |

Stable (boot ~75 s, 3x PR, Color, quit, shutdown), visually clean (76 sampled
frames). Cumulative: Step 1 ~+2 %, Step 2 ~+1.5..2 % (16-bit, the pure-store
test, gained most). Per-access VRAM fixes are yielding single digits; the
profile's big terms (instruction supply ~31 % of cycles, RAM data misses 13 %,
core-internal 20 %) are the next targets: I-cache / D-cache capacity (8 KB
each today, QuickDraw's ROM working set is 49 KB) and the clock.

## Next lever: 16 KB + 16 KB caches (CSB 7 -> 8), 2026-10-26 22:40

`rtl/ap68040_faster/rtl/ap68040_pkg.sv` `localparam int CSB = 8;` (the
package says CSB <= 8 keeps the set index inside the page offset, so this is
the designed-in maximum). tb_quadra_cpu040 PASS x3 (cycle counts rise 37.9k ->
42.5k: the cache sweeps cover twice the sets). Microbench: the 16 KB RAM
kernels now fit the D-cache (K4 cached fill 10.1 -> 4.5, K5 cached RMW 13.5 ->
4.0); VRAM kernels unchanged. Rationale: the profile put ~31 % of cycles in
instruction supply and 13 % in RAM data misses with 8 KB caches against a
49 KB QuickDraw working set. Risk: the shipping core missed the CPU clock at
16+16 KB; this core has +0.6 ns at 8+8. Build: `~/mister/q800_step12_csb8_20261026`,
unit `q800-step12-csb8`.
- First 16 KB build failed in synthesis: `a[11:CSH+1]` (the page-offset bits
  above the set index in the physical tag) is zero bits wide at CSB 8 and
  Quartus rejects the reversed part-select (Verilator did not). Rewritten in
  three places (dmu 643/653, fetch 538) as
  `(CTW'({...}) << (11-CSH)) | CTW'(a[11:0] >> (CSH+1))`; at CSB 7 the
  regression reproduces the original cycle counts exactly (37926/36414/37926),
  at CSB 8 it passes (42486/41308/42468). Rebuild: unit `q800-step12-csb8b`.
