# Performance measurements — Speedometer 4.02

Latest accepted checkpoint (2026-09-13): source-only operand overlap,
Speedometer 4.02 all-ten CPU Mix, one iteration, CD-off seed 24:
**0.458 / 0.460 / 0.460**, mean 0.459333333, +1.99852% versus indexed-stage.
Parent visually reviewed all three; one perturbed run excluded. 38,003 ALMs,
4,093 LABs (98 free), positive constrained timing and zero reported TNS.
See [checkpoint](CPU_SOURCE_OVERLAP_CHECKPOINT_20260913.md) for full evidence.

The following September 12 snapshots are historical.

Latest CPU Mix checkpoint (2026-09-12): indexed-address staging, CD-ROM-off
seed 24, **0.450 / 0.451 / 0.450**, mean 0.450333, +0.7457% versus compact
0.447. All three completion images independently verified, all FPGA timing
passes, disposable restored and Main unchanged. Exact artifact, all ten
absolute results and validation: [indexed-stage checkpoint](CPU_INDEXED_STAGE_CHECKPOINT_20260912.md).

> **2026-09-01 follow-up:** a timing-clean related-clock SDRAM handoff now
> measures 151 ns per isolated read and 22.0 MB/s sequentially in
> `tb_sdram`. On hardware, Speedometer **3.23 PR Tests** improved from CPU
> 2.661 on the seed-13 control to **2.917** on seed 15 (+9.6%). Version 3.23's
> PR score is not the same metric as the 4.02 Benchmark Mix below; see §8.
> A 2026-09-02 BL8/open-page follow-up raises that same 3.23 CPU score to
> **3.139** and passes the full suite; see §9.

Three-way comparison of a **real Quadra 800**, the **Wombat33 core before the
SDRAM fast path**, and the **core with it**. Measured 2026-09-01 on hardware
(DE10-Nano + MiSTer SDRAM board), same disk image, same ROM, same Mac OS.

| | Benchmark Mix | Color QuickDraw |
|---|---|---|
| Real Quadra 800 | **1.897** | **1.283** |
| Wombat33 `20260831_2` (before) | 0.200 | 0.198 |
| Wombat33 seed 13 (after) | **0.231** | **0.219** |
| **Gain from the SDRAM work** | **+15.5 %** | **+10.6 %** |
| **Still short of real hardware by** | **8.2×** | **5.9×** |

Speedometer's ratios are against a **Quadra 605 = 1.0** (FPU against a Quadra
650). Higher is better. For the `(sec)` rows a *lower* absolute is better; for
the `/sec` rows a *higher* absolute is better.

The headline: the memory work is worth a solid, reproducible **15 %** of real
CPU throughput — and the emulated Quadra is still **roughly eight times slower
than the machine it is emulating**.

---

## 1. What was compared

| | Real Quadra 800 | Before | After |
|---|---|---|---|
| Bitstream | — | `releases/wombat33_20260831_2.rbf` | seed 13 of `cpu-speed-sdram` |
| md5 | — | `4414e7b3294b3d554a9e43faa16682bd` | `abb5ede4f776d20ccd74367813aa1d28` |
| Provenance | photograph | commit `cc53fbd` | branch `cpu-speed-sdram`, `3d1f28c` |
| Timing (STA) | — | met, +0.062 ns | **met, +0.132 ns** |
| CPU | MC68040 | MC68040 | MC68040 |
| FPU / MMU | Integral / Integral | Integral / Integral | Integral / Integral |
| ROM | `$067C`, 1024K | `$067C`, 1024K | `$067C`, 1024K |
| Physical RAM | 122880K | 32768K | 32768K |
| Bus clock | 33.33 MHz | 33.000 MHz | 33.000 MHz |

Both Wombat33 md5s were verified **on the MiSTer after the push**, not just
locally. The guest was shut down from the Apple menu before every core swap.

Seed 13 is the fit that **meets timing** — `scripts/deploy_screenshot.sh`
passed it with "Timing OK — worst slack +0.132 ns" and no override, the only
build in this campaign that did. Seed 8 (−0.501 ns) was measured first and
produced numbers identical to seed 13 within noise, which is the expected
result: a fitter seed changes placement, not throughput. See
`wombat33.qsf` for the full seed walk.

Two differences from the real machine worth keeping in mind: it has 128 MB
against our 32 MB (irrelevant to these tests, which are cache- and
bandwidth-bound rather than capacity-bound), and its bus is 1 % faster.

![Real Quadra 800](perf/real_quadra800.jpg)

## 2. Benchmark Mix

Absolute values. One iteration of every test, which is what the reference
photograph used.

| Test | Real Q800 | Before | After | After vs before | After vs real |
|---|---|---|---|---|---|
| KWhetstones/sec | 1978.474 | 157.809 | 190.895 | **+21.0 %** | 10.4× slower |
| Dhrystones/sec | 24999.350 | 2033.948 | 2378.625 | **+17.0 %** | 10.5× slower |
| Towers (sec) | 0.469 | 5.048 | 4.250 | **−15.8 %** | 9.1× |
| Quick Sort (sec) | 0.532 | 3.396 | 3.016 | −11.2 % | 5.7× |
| Bubble Sort (sec) | 0.566 | 3.885 | 3.569 | −8.1 % | 6.3× |
| Queens (sec) | 0.307 | 3.047 | 2.622 | −14.0 % | 8.5× |
| Puzzle (sec) | 0.799 | 5.739 | 5.366 | −6.5 % | 6.7× |
| Permutations (sec) | 0.619 | 8.575 | 7.051 | **−17.8 %** | 11.4× |
| Int. Matrix (sec) | 0.599 | 4.766 | 4.335 | −9.0 % | 7.2× |
| Sieve (sec) | 0.974 | 5.821 | 5.187 | −10.9 % | 5.3× |
| **Average ratio** | **1.897** | **0.200** | **0.231** | **+15.5 %** | **8.2×** |

The spread across tests is itself informative. Permutations (+17.8 %) and
Towers (+15.8 %) gain most — both are pointer-chasing, cache-missing workloads
that spend their time waiting on memory. Puzzle (+6.5 %) and Bubble Sort
(+8.1 %) gain least, being tight loops that mostly stay in the '040's caches
and were never waiting on SDRAM. That is exactly the signature the change
should produce, and it is a useful sanity check that the gain is real rather
than measurement drift.

## 3. Color QuickDraw

All four depths from 1-bit to 8-bit; 16 bits/pixel is greyed out in Speedometer
on this hardware and was not run on the real machine either.

| Test | Real Q800 | Before | After | After vs before | After vs real |
|---|---|---|---|---|---|
| Monochrome (sec) | 5.356 | 36.804 | 32.936 | −10.5 % | 6.1× |
| Two Bit (sec) | 5.961 | 40.341 | 36.285 | −10.1 % | 6.1× |
| Four Bit (sec) | 6.806 | 43.115 | 39.054 | −9.4 % | 5.7× |
| Eight bit (sec) | 8.242 | 49.479 | 45.212 | −8.6 % | 5.5× |
| **Average ratio** | **1.283** | **0.198** | **0.219** | **+10.6 %** | **5.9×** |

Colour gains less than the CPU mix (~10 % against ~15 %), which fits: QuickDraw
here is drawing into **VRAM, which is on-chip BRAM**, not SDRAM. Only the
source data and the drawing code itself come through the memory path this
branch touched, so only part of the work could speed up.

## 4. FPU

Not run on the previous release (agreed to skip). Seed 8 only, for the record,
against a Quadra 650 = 1.0:

| Test | Abs. | Rat. |
|---|---|---|
| KWhetstones/sec | 827.979 | 0.159 |
| Matrix Mult. (sec) | 4.572 | 0.154 |
| Fast Fourier (sec) | 1.679 | 0.171 |
| **Average** | | **0.161** |

## 5. How much to trust these numbers

**Benchmark Mix reproduces to under 1 %, across two different bitstreams.**
Four independent runs — three on seed 8 (the last after a flash to the
previous release and back) and one on seed 13:

| Test | s8 run 1 | s8 run 2 | s8 run 3 | seed 13 |
|---|---|---|---|---|
| KWhetstones/sec | 190.959 | 191.395 | 191.015 | 190.895 |
| Dhrystones/sec | 2378.068 | 2379.446 | 2378.287 | 2378.625 |
| Towers | 4.250 | 4.249 | 4.250 | 4.250 |
| Permutations | 7.050 | 7.048 | 7.051 | 7.051 |
| Sieve | 5.186 | 5.169 | 5.187 | 5.187 |
| **Average** | **0.231** | **0.231** | **0.231** | **0.231** |

The previous release was likewise run twice (average 0.200 both times, every
test within 2 %). A 0.200 → 0.231 difference is an order of magnitude larger
than that noise. That seed 8 and seed 13 agree to three decimals is also the
expected control: a fitter seed changes placement and timing closure, not what
the machine computes per second.

**The 8-bit colour test has one bad sample, now identified.** Four
measurements of it on this RTL: 43.713, **32.440**, 45.184 and 45.212 seconds.
Three cluster tightly around 45 s; the 32.440 s reading is a lone outlier. An
earlier sweep that caught it suggested a 22 % colour gain — that number is
wrong, and it is recorded here only so nobody rediscovers it and believes it.
The table in §3 uses the reproducible value. Monochrome, 2-bit and 4-bit
repeat to within 0.5 % across every run. **What produced the single fast
sample is still unexplained and worth a look.**

**A screensaver is armed on this disk** and its idle timeout sits somewhere
between 250 s and 400 s. One early run ended with it up; that run was repeated
inside a shorter window and agreed to three decimals, so it did no harm, but
any future timing work on this machine should keep runs inside ~250 s of the
last input or disable it first.

## 6. Method

Speedometer 4.02, from `Quad Squad:Utilities:`. Driven over the MiSTer remote
websocket (`scripts/mister_ws.py`); helper scripts in `scratch/perf/`.

- The guest's **Command key is PS/2 Left Alt** (`rtl/adb.sv:530` maps it to ADB
  `$37`), i.e. Linux keycode 56, so ⌘B is `down:56 raw:48 up:56`. Speedometer's
  shortcuts — ⌘B Benchmark Mix, ⌘G Color QuickDraw, ⌘F FPU — make the whole
  run keyboard-driven; only the checkboxes need the mouse.
- Navigation to the app used the Finder's **type-select + ⌘O**, which is far
  more reliable than clicking icons.
- **No screenshots were taken during a run.** The capture is an HTTP POST the
  core services, and it perturbs what is being timed.
- Mouse positioning is a closed loop, because mrext sends *relative* motion and
  Mac OS accelerates it — the event-to-pixel scale measured anywhere from 1.3
  to well over 8 px per event depending on how many events got coalesced into
  one ADB report. `scratch/perf/click.sh` pins the pointer into the top-left
  corner (the one position the screen edge makes certain) and then walks to the
  target, re-measuring the scale from a screenshot after every move.
- A dialog screenshotted immediately after it opens can be caught mid-redraw,
  missing its title, static text and button labels. That is not a rendering
  fault; give it a few seconds before grabbing. (It briefly looked like a
  regression from this branch until the same dialog was re-grabbed with a
  settle delay and drew perfectly.)

### Screenshots

Before — `releases/wombat33_20260831_2.rbf`:

![Before](perf/wombat33_20260831_2_baseline.png)

After — seed 13 of `cpu-speed-sdram`, the fit that meets timing:

![After](perf/wombat33_seed13_sdram-fastpath.png)

The seed-8 capture (`perf/wombat33_seed8_sdram-fastpath.png`) is kept as the
independent second sample.

## 7. What this says about the SDRAM work

`docs/sdram-fast-path.md` measured the memory path in isolation with
`verilator/tb_sdram.sv`: an isolated store fell from 242 ns to 30 ns and a read
beat from 272 ns to 212 ns. This document is the end-to-end consequence of
that: **+15.5 % on the CPU mix, +10.6 % on colour**, on real silicon running
real Mac OS, in a build that meets timing.

That ratio is worth understanding rather than being disappointed by. An 8×
store latency win does not become an 8× machine win because most instructions
are not stores and most stores were already overlapping with something. The
tests that gained most are the ones that miss cache most, which is the
signature of a genuine memory-path improvement.

**The gap that remains is the interesting part.** At 8.2× slower than a real
Quadra 800 on the CPU mix, the bottleneck is no longer only the platform's
memory path:

- A read beat is now 212 ns of which the SDRAM row cycle is ~81 ns; the rest is
  the two clock-domain crossings. Removing them (§1c of the speed plan) is the
  next platform item and is worth more than its position in the running order
  suggested.
- Page mode (§1d) is the structural prerequisite for real-Quadra bandwidth;
  the follow-up prototype shows it must be paired with a full-line path.
- Beyond that the remaining terms are inside the CPU core — the write-through
  cache with no write buffer, and the lack of an early ack on line fills — which
  live in the `rtl/ap68040` submodule.

A useful next measurement would be the same three-way comparison after the
page-mode work (§1d) lands, to see how much of the 8.2× is memory and how much
is the core.

## 9. Alan's AP68040 `5aa596f` on the block-cache core (2026-09-07)

Build `scratch/MacQuadra800_cpu_nocd_ecd5705e.rbf` (md5 `ecd5705e…`): `main`
`17767e8` -- the SCSI block cache release source plus the `rtl/ap68040`
submodule at Alan Steremberg's `5aa596f` (retained instruction fetches across
branches, memory operands retired on read acknowledge, DBcc collapse, simple
An effective addresses and source-EA dispatch bypassed, register ADD operands
preselected in decode) -- with `CDROM_OFF=1`, because that core is +20 %
logic cells and no longer fits next to the CD-ROM target (4221 LABs of 4191
even with aggressive-area synthesis). 93 % ALMs, timing met at +0.494 ns.
Same disk (Quad Squad), Speedometer 4.02, one iteration, driven by the
operator subagent; screenshots in `scratch/perf_ecd5705e/`.

Boot to the Finder desktop: 136 s (150 s on the 03f83c62 cache release the
same evening), 78.65 MB read.

### Benchmark Mix (Quadra 605 = 1.0), three clean runs

| Test | Run 1 | Run 2 | Run 3 | 2026-09-01 (§2 "After") | vs 09-01 |
|---|---|---|---|---|---|
| KWhetstones/sec | 325.239 | 326.340 | 326.166 | 190.895 | 1.71× |
| Dhrystones/sec | 4173.212 | 4173.257 | 4172.981 | 2378.625 | 1.75× |
| Towers (sec) | 2.387 | 2.387 | 2.386 | 4.250 | 1.78× |
| Quick Sort (sec) | 1.961 | 1.959 | 1.959 | 3.016 | 1.54× |
| Bubble Sort (sec) | 2.648 | 2.648 | 2.648 | 3.569 | 1.35× |
| Queens (sec) | 1.534 | 1.533 | 1.534 | 2.622 | 1.71× |
| Puzzle (sec) | 4.144 | 4.121 | 4.127 | 5.366 | 1.30× |
| Permutations (sec) | 3.574 | 3.574 | 3.574 | 7.051 | 1.97× |
| Int. Matrix (sec) | 2.823 | 2.812 | 2.808 | 4.335 | 1.54× |
| Sieve (sec) | **0.494** (bogus, see below) | 4.592 | 4.593 | 5.187 | 1.13× |
| **Average ratio** | (0.608) | **0.361** | **0.361** | 0.231 | **+56 %** |

Runs 2 and 3 agree to 0.3 % on every line. Color QuickDraw (⌘G, four depths):
mono 21.989 s, 2-bit 24.806, 4-bit 27.610, 8-bit 32.540, **average 0.317**
(0.219 on 09-01, +45 %). FPU (⌘F, Quadra 650 = 1.0): KWhetstones 1382.456,
Matrix Mult. 2.735 s, Fast Fourier 1.260 s, **average 0.250** (0.161, +55 %).

**Against the 2026-09-02 release** (`MacQuadra800_20260902`, submodule
`be0a662`, Alan's previous step) only two numbers were ever recorded, in
`docs/sdram-open-row-crossing.md`: Queens 1.574 s and Bubble Sort 2.754 s.
This build: 1.534 s and 2.648 s, i.e. **−2.5 % and −3.8 %**. So on those two
tests most of the gain over 09-01 was already in the 09-02 core; whether
`5aa596f` moves the branch-heavy tests (Permutations, Towers, Dhrystones)
as much as its description suggests needs the full Benchmark Mix on the
09-02 release or on `MacQuadra800_20260907` (same `be0a662` core plus the
cache), same disk, same method. That run is owed.

### First-run anomaly, again

Run 1 reported **Sieve = 0.494 s (ratio 2.780)** -- twice as fast as a real
Quadra 800 (0.974 s), impossible -- against 4.59 s on every later run, and it
alone lifted run 1's average to 0.608. This is the same signature as the
`Queens = −17,482 s` first run in `docs/sdram-open-row-crossing.md`: the
first pass through one test after a fresh launch times wrongly and never
reproduces. Sieve is the last test of the set, so it is not a warm-up of the
first test executed. Worth chasing on its own (timer/VIA or Time Manager
side, or the first cold miss path in the core): anyone reading only the
first run reports a number that is not real.

Method notes from this run: Speedometer's splash is modal and needs a mouse
click (⌘B does nothing until the splash and the registration nag are
cleared); ⌘B/⌘G/⌘F open a setup dialog whose default button starts the run,
so Return suffices. Source `scripts/local.env` before `mister_ws.py`.

## 8. Related-clock handoff follow-up (Speedometer 3.23)

The current disposable MacAtrium test disk contains Speedometer 3.23, not the
4.02 copy used above. That prevents a direct update of the real-Q800 comparison,
but it still gives a controlled before/after measurement on one disk and one
benchmark version.

| Speedometer 3.23 PR Test | seed-13 control | seed-15 handoff | gain |
|---|---:|---:|---:|
| CPU | 2.661 | **2.917** | **+9.6%** |
| Graphics | 3.487 | **3.903** | **+11.9%** |
| Disk | 0.671 | **0.679** | +1.2% |
| Math | 15.841 | **18.446** | **+16.4%** |
| Old PR | 3.829 | **4.318** | **+12.8%** |
| New PR | 1.850 | **1.946** | **+5.2%** |

The seed-15 RBF is `releases/wombat33_20260901_2.rbf`, MD5
`d1d785de28439d132333a1c9e3aab5c5`. Quartus reports +0.270 ns overall
setup and +0.241 ns overall hold; the 99 MHz domain is +1.353 ns setup and
+0.431 ns hold. The guest booted Mac OS, completed the PR suite, and was shut
down normally before the disk or core was touched again.

Seed-13 control:

![Speedometer 3.23 PR control](perf/wombat33_seed13_speedometer323_pr.png)

Seed-15 related-clock handoff:

![Speedometer 3.23 PR handoff](perf/wombat33_seed15_cdc_speedometer323_pr.png)

The 4.02 application came from `Quad Squad:Utilities:` on the original 2 GB
Quad Squad image. The currently mounted `QuadSquad8.hda` is a 90 MB disposable
clone of the MacAtrium disk, so recovering that original image from the NAS or
archive is the prerequisite for rerunning the published 4.02 tables.

## 9. BL8/open-page follow-up (Speedometer 3.23)

The next memory-only step keeps the machine's established registered bus
completion but changes the SDRAM side to an open-page controller and captures
the complete BL8 read as a retained 16-byte line. The requested longword is
returned critical-word-first while the burst tail finishes in the background.
The controller tracks open rows independently for all eight `{rank,bank}`
combinations and refreshes both ranks.

A fresh run of the seed-15 handoff RBF immediately before the experiment is
the control below. Both runs used the same pristine `QuadSquad8.hda` image,
Speedometer 3.23, Mac OS 7.5.5, and one iteration of every PR category.

| Speedometer 3.23 PR Test | seed-15 control | BL8/open-page | gain |
|---|---:|---:|---:|
| CPU | 2.917 | **3.139** | **+7.6%** |
| Graphics | 3.817 | **4.159** | **+9.0%** |
| Disk | 0.672 | **0.684** | +1.8% |
| Math | 18.224 | **20.843** | **+14.4%** |
| Old PR | 4.269 | **4.724** | **+10.7%** |
| New PR | 1.928 | **2.013** | **+4.4%** |

The hardware RBF is `Wombat33_BL8_stockmachine_seed17_20260902.rbf`, MD5
`e20f8dfff1d27b4df2195708bcdecc39`. Quartus reports +0.185 ns overall setup
and +0.244 ns overall hold. The full PR suite completed normally, including
Disk. The directed SDRAM model reports 43.7 MB/s for sequential bridge reads,
181 ns for a cold critical word, 121 ns for an open-page read, and 30 ns for a
retained-line read. The whole stock machine transport remains slower at an
estimated 19.5 MB/s / 819 ns per 16-byte fill because each longword still
crosses the registered transaction adapter and service FSM.

Two more aggressive handshakes were rejected on hardware. Both completed CPU
and Graphics but froze during Disk; one included the full pre-adapter line
bypass, while the other disabled that bypass and retained only direct memory
acknowledgement. The passing stock-machine build therefore clears BL8 and the
open-page controller and isolates the remaining fault to the shortened
completion path. Future work should shorten RAM completion only, leaving the
ROM, VRAM, IOSB, DAFB, and open-bus cadence unchanged, and must pass the full
Disk test before it replaces this baseline.

### Registered retained-line service

The first safe follow-up exposes the retained BL8 line to `quadra800`, but
serves its words through the existing registered service-FSM acknowledgement.
It removes three redundant bridge transactions per fill without changing the
transaction adapter's completion cadence. The integrated model improves from
19.5 to **25.1 MB/s**, and a 16-byte fill falls from 819 to **636 ns**.

| Speedometer 3.23 PR Test | BL8/open-page | registered line | gain |
|---|---:|---:|---:|
| CPU | 3.139 | **3.258** | **+3.8%** |
| Graphics | 4.159 | **4.373** | **+5.1%** |
| Disk | 0.684 | 0.679 | -0.7% |
| Math | 20.843 | **21.694** | **+4.1%** |
| Old PR | 4.724 | **4.920** | **+4.1%** |
| New PR | 2.013 | **2.039** | **+1.3%** |

The RBF is `Wombat33_BL8_regline_seed17_20260902.rbf`, MD5
`628021ac778ef96c45d84d9232e4644a`. Quartus reports +0.289 ns setup and
+0.252 ns hold. It booted Mac OS and completed the full PR suite, including
Disk. Against the fresh seed-15 control at the start of this section, the
cumulative CPU gain is **+11.7%** (2.917 to 3.258).

### Registered pre-adapter line hits

The next step bypasses `wombat_bus32` only for aligned longword reads that are
already present in the retained BL8 line. The completion remains a registered
one-cycle pulse. The adapter's active state and previous acknowledgement both
gate the bypass, preventing the just-completed critical word from being
acknowledged twice. A first miss, byte/word or misaligned access, page-table
walk, write, and every non-RAM device continue to use the established adapter
and service-FSM path. A request for the still-arriving tail of the same line
waits instead of launching a duplicate SDRAM transaction.

The integrated post-cache model improves from 25.1 to **43.7 MB/s** and a
16-byte fill falls from 636 to **365 ns**. It passes 64 sequential reads and
2,048 mixed posted-write/read operations in order, while the independent SDRAM
test remains 45/45 with zero chip-protocol errors and the bus adapter remains
6/6. The complete Verilator machine also builds successfully.

| Speedometer 3.23 PR Test | registered line | registered bus line | gain |
|---|---:|---:|---:|
| CPU | 3.258 | **3.378** | **+3.7%** |
| Graphics | 4.373 | **4.536** | **+3.7%** |
| Disk | 0.679 | **0.681** | +0.3% |
| Math | 21.694 | **22.639** | **+4.4%** |
| Old PR | 4.920 | **5.112** | **+3.9%** |
| New PR | 2.039 | **2.072** | **+1.6%** |

The RBF is `Wombat33_BL8_regbusline_seed17_20260902.rbf`, MD5
`df9e97bfc14612b1221cd10112e9dad3`. Quartus reports +0.139 ns setup and
+0.183 ns hold, with zero setup or hold TNS. It booted Mac OS 7.5.5 and
completed one iteration of every PR category, including Disk, before a clean
guest shutdown. The disposable test disk was then restored byte-for-byte from
the pristine image; both copies had MD5 `9c685af4dd7016cf1e664a908e2d9cbe`.

Against the fresh seed-15 control, the cumulative gains are **+15.8% CPU**,
**+18.8% Graphics**, and **+24.2% Math**. The bridge itself has now reached
43.7 MB/s, so the remaining gap to the real Quadra 800's 50--65 MB/s is no
longer dominated by repeated SDRAM reads within a cache fill. The conservative
next memory-only target is first-miss latency: shorten only the RAM critical
word path while retaining a registered CPU-visible acknowledgement and the
adapter's ownership/order checks. Broad direct memory acknowledgement remains
rejected because it froze the hardware Disk test even when line bypass was
disabled.

### Registered direct first miss

Aligned longword reads to decoded RAM now bypass `wombat_bus32` on the first
miss as well as on retained-line hits. The SDRAM completion still enters a
dedicated register before it reaches the CPU, so this does not restore the
combinational direct-ack path that failed the Disk test. Writes, byte/word and
misaligned accesses, page-table walks, and every non-RAM target retain the
established adapter and service-FSM path.

The integrated post-cache model improves from 43.7 to **52.4 MB/s**, inside the
real Quadra 800's 50--65 MB/s sequential-RAM range. A 16-byte fill falls from
365 to **304 ns**. It passes 64 sequential reads and 2,048 mixed
posted-write/read operations in order; the independent SDRAM test remains
45/45 with zero chip-protocol errors, the transaction adapter remains 6/6,
and the complete Verilator machine builds.

| Speedometer 3.23 PR Test | registered bus line | registered first miss | gain |
|---|---:|---:|---:|
| CPU | 3.378 | **3.425** | **+1.4%** |
| Graphics | 4.536 | **4.542** | +0.1% |
| Disk | 0.681 | **0.682** | +0.1% |
| Math | 22.639 | **22.957** | **+1.4%** |
| Old PR | 5.112 | **5.165** | **+1.0%** |
| New PR | 2.072 | **2.082** | +0.5% |

The RBF is `Wombat33_BL8_regfirstmiss_seed17_20260902.rbf`, MD5
`4a92a48e907a3f060e0bdae77905d5ba` and SHA-256
`677c60e85fcd766c59faa026564b511e5433051cb6690078467b11ed68fd30d8`.
Quartus reports +0.143 ns setup and +0.250 ns hold with zero setup or hold
TNS. It booted Mac OS 7.5.5, completed one iteration of every PR category,
including Disk, and shut down cleanly. Against the fresh seed-15 control, the
cumulative gains are **+17.4% CPU**, **+19.0% Graphics**, and **+26.0% Math**.

The MiSTer auto-mount file points at
`games/Wombat33/QuadSquad8.hda`; that is the disposable image. Cleanup after
this run exposed that the previous 9c685... restore command had treated that
mounted file as the source and copied it over the unmounted MacAtrium copy, so
the exact 9c685... snapshot is no longer present. A new cleanly shut-down
golden was established at
`games/MacIIvi/MacAtrium-7.5.5-fullcolor_speedtest.hda`, MD5
`0c4f774b4a2eccd5656e92f16119875f`, with a restore-verified compressed copy at
`games/Wombat33/backup/MacAtrium-7.5.5-fullcolor_speedtest_golden_20260902.hda.gz`.
Future runs must copy or decompress that golden **to** `QuadSquad8.hda`; the
golden must never be used as the restore destination or mounted by the core.

## 10. AP040 retained-line cache fill (Speedometer 3.23)

The first CPU-side optimization reuses the 16-byte line already retained by
`sdram_beat32`. A normal registered RAM read still starts a cache miss. Once the
complete physical line is valid, `ap040_cache` copies its remaining words into
the selected cache way locally, one word per CPU clock, instead of issuing three
more post-cache bus transactions. The tag is validated after all four words are
written, and the CPU receives its acknowledgement only in the existing
`C_TAGW` state. This preserves the completion contract that passed every prior
hardware gate while removing redundant transaction-adapter and service-FSM
handshakes.

An earlier critical-word early-ack implementation was rejected despite passing
the AP68040 suite, SingleStepTests, full-machine simulation, and timing. Two
independent timing-clean all-cacheable builds and a post-overlay physical-RAM-
only build all produced a black screen, while the unchanged memory baseline
booted immediately from the same restored disk. Releasing the CPU before its
cache line is committed is therefore not part of the accepted design.

The accepted seed-17 line-assist build passed the complete AP68040 suite. Its
directed cache test checks that exactly one external read is issued, the other
three words come from the completed-line sideband, the requested word is
correct, and all four later line hits generate no bus traffic. The complete
Wombat Verilator model builds, and the first 100 SingleStepTests corpus rows
match all 1,696 architectural field groups with zero real differences.

| Speedometer 3.23 PR Test | registered first miss | AP040 line assist | gain |
|---|---:|---:|---:|
| CPU | 3.425 | **3.494** | **+2.0%** |
| Graphics | 4.542 | **4.707** | **+3.6%** |
| Disk | 0.682 | 0.679 | -0.4% |
| Math | 22.957 | **23.477** | **+2.3%** |
| Old PR | 5.165 | **5.293** | **+2.5%** |
| New PR | 2.082 | **2.096** | +0.7% |

The RBF is `Wombat33_CPU_lineassist_seed17_20260902.rbf`, MD5
`cee04efa7c3db4e0539e757fafa1d645` and SHA-256
`54cf0f7f6d2c8526d8eab44cfe889f0ff63ce8d629ca40848f155efc2ff715a3`.
Quartus reports +0.348 ns setup and +0.244 ns hold with zero setup or hold TNS.
It booted Mac OS 7.5.5 and completed every PR category, including Disk. Mac OS
was shut down to its safe-to-switch-off screen, the MiSTer returned to its menu,
and the disposable disk was restored from the pristine golden; both images then
matched MD5 `0c4f774b4a2eccd5656e92f16119875f`.

## 11. Two-entry CPU RAM store buffer (Speedometer 3.23)

The next CPU-side optimization hides write-through RAM-store latency behind
later cache hits. A two-entry ordered queue sits below `ap040_cache` and gives a
registered acknowledgement when it captures a non-faulting physical-RAM write.
The queued transactions then drain through the unchanged post-cache platform
bus. Reads, ROM/device writes, and other unqualified transactions wait for all
older stores; MMU table walks are also held, and retained SDRAM lines are hidden
while a store is pending so neither path can observe stale memory. The boot
overlay and all non-RAM address regions retain their previous completion path.

The directed store-buffer test passes direct completion, early store capture,
read-after-write ordering, two-entry FIFO order, full-queue backpressure,
host-disabled bypass, and clock-enable freeze. The complete Wombat Verilator
model builds, and the first 100 SingleStepTests CPU corpus rows match all 1,696
architectural field groups with zero real differences.

Seed 17 was rejected before deployment at -0.323 ns setup and +0.197 ns hold.
TimeQuest placed its only setup failure on the already documented seed-sensitive
SDRAM `open_row` to `command[0]` cross-clock path, not in the CPU or store
buffer. The identical seed-18 netlist meets timing at **+0.165 ns setup** and
**+0.248 ns hold**, with zero setup and hold TNS.

| Speedometer 3.23 PR Test | AP040 line assist | two-entry store buffer | gain |
|---|---:|---:|---:|
| CPU | 3.494 | **3.626** | **+3.8%** |
| Graphics | 4.707 | **4.804** | **+2.1%** |
| Disk | 0.679 | **0.698** | **+2.8%** |
| Math | 23.477 | **26.744** | **+13.9%** |
| Old PR | 5.293 | **5.706** | **+7.8%** |
| New PR | 2.096 | **2.160** | **+3.1%** |

The RBF is `Wombat33_CPU_storebuf_seed18_20260902.rbf`, MD5
`50b318db7b83bba6e418f15ad4e6085a` and SHA-256
`2992d426897f089a7401eca95327507707e9fcf1753986bb8bbe9dc93e4dbe1c`.
It booted Mac OS 7.5.5 and completed one iteration of every PR category. Mac OS
then reached its safe-to-switch-off screen, the MiSTer returned to its menu, and
the disposable disk was restored from the pristine golden. Both images matched
MD5 `0c4f774b4a2eccd5656e92f16119875f` after restoration.

## 12. Preserve data-cache lines on write-through store hits (Speedometer 3.23)

AP040 previously invalidated all four ways in a data-cache set for every
write-through store. An aligned cacheable store now reads the tags and data ways
in parallel with the external write, then merges byte, word, or longword data
into the matching resident way only when the downstream write acknowledges.
The cache remains write-through and has no dirty state. A bus error leaves the
old cached word intact, while cache-inhibited, misaligned, and line-crossing
stores retain the conservative touched-set invalidation path.

The directed cache test fills four tags in one set, updates one resident line,
and requires all four lines to remain hits with no refill traffic. It also
checks big-endian byte and word merges and proves that a faulting store does not
commit speculative lookup data. The complete AP68040 suite and Wombat Verilator
build pass, and the first 100 SingleStepTests CPU rows match all 1,696
architectural field groups with zero real differences.

The first timing attempts exposed an existing 50-level `ir` to `exc_fmt`
instruction-decode cone: seeds 18, 19, and 20 missed setup by 0.610, 1.740, and
2.223 ns respectively. Exception format is now encoded in a registered entry
state and loaded from that shallow decode without changing exception latency or
frame contents. That removed the CPU path. The refactored seed-18 build then
missed only the known placement-sensitive SDRAM `open_row` to `command[0]`
crossing by 1.030 ns; seed 19 meets timing at **+0.378 ns setup** and **+0.251 ns
hold**, with zero setup and hold TNS.

| Speedometer 3.23 PR Test | two-entry store buffer | store-hit update | gain |
|---|---:|---:|---:|
| CPU | 3.626 | **3.878** | **+6.9%** |
| Graphics | 4.804 | **5.130** | **+6.8%** |
| Disk | 0.698 | 0.685 | -1.9% |
| Math | 26.744 | **29.395** | **+9.9%** |
| Old PR | 5.706 | **6.167** | **+8.1%** |
| New PR | 2.160 | **2.190** | **+1.4%** |

The RBF is `Wombat33_CPU_storehit_seed19_20260902.rbf`, MD5
`e6cf83d9a3a49685abd5f2e8235d33cf` and SHA-256
`8a1e268f1a49bf55d5fb507abccc6d6020d0139454f8f0da386405ced26cef23`.
It booted Mac OS 7.5.5 and completed one iteration of every PR category. Mac OS
then reached its safe-to-switch-off screen, the MiSTer returned to its menu, and
the disposable disk was restored from the pristine golden. Both images matched
MD5 `0c4f774b4a2eccd5656e92f16119875f` after restoration.

## 13. AP040 instruction branch-refill buffer (Speedometer 3.23)

The execution prefetch queue is forward-only, so every taken backwards branch
previously discarded its words and repeated the instruction-cache/MMU
handshake. AP040 now retains one 32-byte sector of completed instruction-fetch
data, tagged by logical address and supervisor context. A redirect can seed the
queue when all four contiguous words beginning at its target are valid. Normal
speculative filling resumes after those words drain. Exceptions, CINV, PFLUSH,
MOVEC, and other architectural prefetch flushes invalidate the sector; ordinary
control-flow redirects preserve it.

Packing the sector as eight 32-bit words and requiring a complete four-word
redirect window matters for the target FPGA. Earlier per-word and two-bank
designs did not fit. A 16-bit version fit at exactly 4,191/4,191 LABs but was
placement-fragile. The accepted form uses 39,685/41,910 ALMs and 4,185/4,191
LABs. Placement seed 24 closes timing at **+0.417 ns setup** and **+0.244 ns
hold**, with zero setup or hold warnings.

The complete AP68040 suite and Wombat Verilator build pass. The first 100
SingleStepTests CPU rows match all 1,696 architectural field groups with zero
real differences. The focused `bench_loop` result falls from 326,674 to
289,956 clocks, an **11.24% reduction**.

| Speedometer 3.23 PR Test | store-hit update | branch refill | gain |
|---|---:|---:|---:|
| CPU | 3.878 | **4.282** | **+10.4%** |
| Graphics | 5.130 | **5.177** | +0.9% |
| Disk | 0.685 | 0.680 | -0.7% |
| Math | 29.395 | **29.809** | +1.4% |
| Old PR | 6.167 | **6.383** | **+3.5%** |
| New PR | 2.190 | **2.228** | +1.7% |

![Speedometer 3.23 PR branch refill](perf/wombat33_cpu_branchrefill_seed24_speedometer323_pr.png)

The RBF is `Wombat33_CPU_branchrefill_seed24_20260902.rbf`, MD5
`37eb6c6900e508d52d56baa51980ac82` and SHA-256
`38bb27f1633965f71323c3ca490dd17b368c7046ecf24bf1d5e16701721d8b47`.
The exact Quartus build is preserved at
`/home/alans/builds/wombat33_cpu_branchrefill_seed24_20260902`. Mac OS 7.5.5
booted, completed every PR category including Disk, and reached its safe-to-
switch-off screen. The MiSTer then returned to its menu and the disposable disk
was restored from the compressed pristine golden; both disk copies matched MD5
`0c4f774b4a2eccd5656e92f16119875f` afterward.

A combined experiment that retired register-to-register ALU operations early
and collapsed DBcc by one state cut the focused benchmark by a further 15.75%
in simulation, but its timing-clean hardware image froze at Happy Mac. Neither
change was retained. This is evidence against a broad execution-state collapse
as the next step; subsequent pipeline work should be split into small,
independently hardware-tested changes with exception and interrupt boundaries
left intact.

## 14. AP040 memory-source operand retirement (Speedometer 3.23)

Profiling the accepted branch-refill core showed that external read latency was
no longer the dominant cost in the focused loop: 12,784 of 12,801 data reads
completed in two clocks. The remaining memory-source path nevertheless spent a
separate `S_PIPE_SDONE` clock copying the completed read into the operand
registers. For the common memory-source/register-destination case, port B has
already been parked on the destination register by `S_PIPE_SRD`. The read
acknowledgement now captures both operands directly and enters `S_EXEC`, while
page-crossing reads and every other return path retain the original sequence.
This does not add the long register-file-to-ALU combinational path that made the
earlier broad pipeline experiment unsafe.

The complete AP68040 suite and Wombat Verilator build pass. The first 100
SingleStepTests CPU rows match all 1,696 architectural field groups with zero
real differences. That corpus falls from 36,531,511 to 36,241,181 clocks
(-0.79%). The focused `bench_loop` falls from 289,956 to 277,158 clocks, a
**4.41% reduction**, and `S_PIPE_SDONE` disappears from its steady-state
profile as expected.

| Speedometer 3.23 PR Test | branch refill | memory-source retirement | gain |
|---|---:|---:|---:|
| CPU | 4.282 | **4.303** | +0.5% |
| Graphics | 5.177 | **5.218** | +0.8% |
| Disk | 0.680 | **0.685** | +0.7% |
| Math | 29.809 | **29.958** | +0.5% |
| Old PR | 6.383 | **6.419** | +0.6% |
| New PR | 2.228 | **2.244** | +0.7% |

The seed-24 image uses 39,705/41,910 ALMs and 4,187/4,191 LABs. It closes
timing at **+0.536 ns setup** and **+0.246 ns hold**, with zero setup or hold
TNS. The RBF is `Wombat33_CPU_loadretire_seed24_20260902.rbf`, MD5
`4df7fe6317ef39330e02b44c6408d35f` and SHA-256
`c0fc37bbcde912b78964b2d4a21d07b2536b109355d3054e034b324d03ec835c`.
The exact Quartus build is preserved at
`/home/alans/builds/wombat33_cpu_loadretire_seed24_20260902`. Mac OS 7.5.5
booted and completed every PR category, then reached its safe-to-switch-off
screen. The MiSTer returned to its main menu and the disposable disk was
restored from the compressed golden; both disk copies matched MD5
`0c4f774b4a2eccd5656e92f16119875f` afterward.

## 15. AP040 prefetched DBcc retirement (Speedometer 3.23)

DBcc occupied two execution states even though its displacement fetch provides
enough time to select Dn on the combinational register-file port. Decode now
selects that register before entering `S_IMMF`; `S_DBCC1` therefore performs
the decrement, writeback, and branch decision together. Odd-target checking
still happens before the condition, and `go_pc` retains its post-writeback
interrupt barrier. This is deliberately narrower than the rejected broad
register/ALU shortcut: it adds no state-dependent register-file address mux and
does not put the main ALU on the retirement path.

The complete AP68040 suite and Wombat Verilator build pass. The first 100
SingleStepTests CPU rows again match all 1,696 architectural field groups with
zero real differences; the corpus contains little DBcc and changes by only 288
clocks. The focused `bench_loop` falls from 277,158 to 263,496 clocks, a further
**4.93% reduction** and a cumulative **9.13%** reduction from the accepted
branch-refill build's 289,956 clocks.

| Speedometer 3.23 PR Test | memory-source retirement | prefetched DBcc | gain |
|---|---:|---:|---:|
| CPU | 4.303 | **4.413** | **+2.6%** |
| Graphics | 5.218 | 5.224 | +0.1% |
| Disk | 0.685 | 0.684 | -0.1% |
| Math | 29.958 | 29.958 | 0.0% |
| Old PR | 6.419 | **6.465** | +0.7% |
| New PR | 2.244 | **2.254** | +0.4% |

Seed 24 missed CPU setup by 0.188 ns and was rejected without deployment. The
accepted seed-25 image uses 40,566/41,910 ALMs and 4,180/4,191 LABs. It closes
timing at **+0.078 ns worst setup overall** (+0.170 ns on the CPU clock) and
**+0.204 ns hold**, with zero setup or hold TNS. The RBF is
`Wombat33_CPU_loadretire_dbcc_seed25_20260902.rbf`, MD5
`6db5e64aee81ccf280b34e23a8247916` and SHA-256
`a3e84325f3cc1a066afef515eee933c8a74ab51d39f62fb527792b76b89744b5`.
The exact Quartus build is preserved at
`/home/alans/builds/wombat33_cpu_loadretire_dbcc_seed25_20260902`. Mac OS 7.5.5
booted, completed every PR category, and shut down normally. The MiSTer then
returned to its menu and the disposable disk was restored from the compressed
golden; both disk copies matched MD5
`0c4f774b4a2eccd5656e92f16119875f` afterward.

## 16. AP040 simple-An effective-address dispatch (Speedometer 3.23)

Simple `(An)`, `(An)+`, and `-(An)` effective addresses previously spent one
state selecting the address register and a second state consuming it. The
register file has asynchronous read ports, so `ea_start` now selects An while
entering the EA engine. On the following clock, `S_EA_DISP` computes the
address, performs any predecrement or postincrement writeback, and returns
directly to the requesting pipeline state. Displacement and indexed modes keep
their existing multi-state paths, and the memory transaction protocol is
unchanged.

The complete AP68040 suite and Wombat Verilator build pass. The first 100
SingleStepTests CPU rows match all 1,696 architectural field groups with zero
real differences. That corpus falls from 36,240,893 to 35,268,206 clocks, a
**2.68% reduction**. The focused `bench_loop` falls from 263,496 to 250,634
clocks, a further **4.88% reduction** and a cumulative **13.56%** reduction
from the branch-refill build's 289,956 clocks. `S_EA_BASE` disappears from the
profile while the number and latency of data reads remain unchanged.

| Speedometer 3.23 PR Test | prefetched DBcc | simple-An EA dispatch | gain |
|---|---:|---:|---:|
| CPU | 4.413 | **4.613** | **+4.5%** |
| Graphics | 5.224 | **5.287** | +1.2% |
| Disk | 0.684 | **0.685** | +0.1% |
| Math | 29.958 | **30.814** | **+2.9%** |
| Old PR | 6.465 | **6.649** | **+2.8%** |
| New PR | 2.254 | **2.279** | +1.1% |

The accepted seed-25 image uses 39,810/41,910 ALMs and 4,191/4,191 LABs. It
closes timing at **+0.368 ns worst setup overall** and **+0.252 ns worst hold
overall** (+0.433 ns on the CPU clock), with zero setup or hold TNS. The RBF is
`Wombat33_CPU_eafast_seed25_20260903.rbf`, MD5
`48adead0b8be54573cbf0d8810e48465` and SHA-256
`24b66028ea8156ab16b3635309facd36926aef18d49f88f4d0f93499314da1fb`.
The exact Quartus build is preserved at
`/home/alans/builds/wombat33_cpu_eafast_seed25_20260903`. Mac OS 7.5.5 booted,
completed every PR category, and reached its safe-to-switch-off screen. The
MiSTer then returned to its menu and the disposable disk was restored from the
compressed golden; both disk copies matched MD5
`0c4f774b4a2eccd5656e92f16119875f` afterward.

## 17. AP040 decode-preselected source EA (Speedometer 3.23)

The previous simple-An optimization still sent generic source-memory operands
through `S_EA_DISP`, even though decode already knows their address-register
number. Decode now preselects that An on the asynchronous register-file port;
special instructions which need a different port-A register override the
selection in their existing decode branches. When `S_PIPE_START` sees `(An)`,
`(An)+`, or `-(An)` as its source, it computes the address and any register
update directly and proceeds to `S_PIPE_SRD`. Displacement, indexed, absolute,
and PC-relative modes continue through the generic EA engine, and the memory
transaction and retirement paths are unchanged.

The complete AP68040 suite and Wombat Verilator build pass. The first 100
SingleStepTests CPU rows match all 1,696 architectural field groups with zero
real differences. That corpus falls by another 1,387 clocks, from 35,268,206
to 35,266,819. The focused `bench_loop` falls from 250,634 to 237,836 clocks, a
further **5.11% reduction** and a cumulative **17.98% reduction** from the
branch-refill build's 289,956 clocks. `S_EA_DISP` falls from 13,066 visits to
266 while data-read count and latency remain unchanged.

| Speedometer 3.23 PR Test | simple-An EA dispatch | source-EA bypass | gain |
|---|---:|---:|---:|
| CPU | 4.613 | **4.688** | **+1.6%** |
| Graphics | 5.287 | **5.350** | +1.2% |
| Disk | 0.685 | 0.676 | -1.3% |
| Math | 30.814 | **31.049** | +0.8% |
| Old PR | 6.649 | **6.720** | +1.1% |
| New PR | 2.279 | 2.271 | -0.4% |

Seed 25 was rejected without deployment because HDMI setup missed by 0.140 ns,
although the CPU clock had +0.389 ns setup margin. Seed 26 fixed HDMI but was
also rejected without deployment because CPU setup missed by 0.433 ns. The
accepted seed-27 image uses 40,599/41,910 ALMs and 4,186/4,191 LABs. It closes
timing at **+0.502 ns worst setup overall** (+0.631 ns on the CPU clock) and
**+0.243 ns worst hold overall** (+0.431 ns on the CPU clock), with zero setup
or hold TNS.

The RBF is `Wombat33_CPU_sourceea_seed27_20260903.rbf`, MD5
`2ef2aa130fd04fa6da4dc0f938d06c69` and SHA-256
`f36a85b1373384a605e84925a08ec081c66fab2b5da3777768be73629c769c4f`.
The exact Quartus build is preserved at
`/home/alans/builds/wombat33_cpu_sourceea_seed27_20260903`. Mac OS 7.5.5
booted, completed every PR category, and reached its safe-to-switch-off screen.
The MiSTer then returned to its menu and the disposable disk was restored from
the compressed golden; both disk copies matched MD5
`0c4f774b4a2eccd5656e92f16119875f` afterward.

## 18. AP040 memory-source MOVE retirement (Speedometer 3.23)

The common non-page-crossing `MOVE`/`MOVEA` from memory to a register now
retires on the successful data-read acknowledgement. The source-EA path has
already selected the destination register on register-file port B while the
read is in flight, so ordinary `MOVE` can merge byte/word results and update
NZVC directly, while `MOVEA.W` applies its required sign extension. The
existing `fetch_next` boundary still handles trace and interrupts after the
registered writeback. Faulted reads, split page-crossing reads, memory
destinations, and non-MOVE users of the MOVE ALU operation retain the generic
pipeline and `S_EXEC` path.

The complete AP68040 suite and Wombat Verilator build pass. The first 100
SingleStepTests CPU rows match all 1,696 architectural field groups with zero
real differences. That corpus falls from 35,266,819 to 35,204,643 clocks,
saving 62,176 clocks. The focused `bench_loop` falls from 237,836 to 225,036
clocks, a further **5.38% reduction** and a cumulative **22.39% reduction**
from the branch-refill build's 289,956 clocks. All 12,800 eligible loads leave
`S_EXEC`; its occupancy falls from 25,668 to 12,872 while data-read count and
latency remain unchanged.

| Speedometer 3.23 PR Test | source-EA bypass | MOVE read retirement | gain |
|---|---:|---:|---:|
| CPU | 4.688 | **4.739** | **+1.1%** |
| Graphics | 5.350 | **5.438** | **+1.6%** |
| Disk | 0.676 | **0.683** | +1.0% |
| Math | 31.049 | **31.228** | +0.6% |
| Old PR | 6.720 | **6.786** | +1.0% |
| New PR | 2.271 | **2.297** | +1.1% |

The accepted seed-27 image uses 40,755/41,910 ALMs and 4,183/4,191 LABs. It
closes timing at **+0.026 ns worst setup overall** (HDMI), +0.830 ns on the CPU
clock and +0.813 ns on the 99 MHz SDRAM clock. Worst hold is **+0.245 ns
overall**, +0.257 ns on the CPU clock and +0.432 ns on the SDRAM clock, with
zero setup or hold TNS.

The RBF is `Wombat33_CPU_moveretire_seed27_20260903.rbf`, MD5
`0416e38b6f2a6bf05f8d1f51532743f0` and SHA-256
`b840435b33eb76fef411d844979b52c63e077bfde6b4e7d20926346381b2288d`.
The exact Quartus build is preserved at
`/home/alans/builds/wombat33_cpu_moveretire_seed27_20260903`. Mac OS 7.5.5
booted, completed every PR category, and reached its safe-to-switch-off screen.
The MiSTer then returned to its menu and the disposable disk was restored from
the compressed golden; both disk copies matched MD5
`0c4f774b4a2eccd5656e92f16119875f` afterward.

## 19. AP040 register-ADD decode preselection (Speedometer 3.23)

The common `ADD.L Dn,Dn` form previously entered `S_PIPE_START` only to select
the two asynchronous register-file ports before continuing to the combined
operand-capture state. Decode now selects those ports and enters `S_PIPE_REGS`
directly. Operand capture and `S_EXEC` remain unchanged; other sizes, address-
register sources, and every other opcode retain the generic path.

The complete AP68040 suite and Wombat Verilator build pass. The first 100
SingleStepTests CPU rows match all 1,696 architectural field groups with zero
real differences. That corpus falls from 35,204,643 to 35,196,127 clocks,
saving 8,516 clocks. The focused `bench_loop` falls from 225,036 to **212,238**
clocks, a further **5.69% reduction** and a cumulative **26.80% reduction** from
the branch-refill build's 289,956 clocks. `S_PIPE_START` falls from 25,669 to
12,868 visits while `S_PIPE_REGS` and `S_EXEC` are intentionally unchanged.

| Speedometer 3.23 PR Test | MOVE read retirement | ADD decode selection | change |
|---|---:|---:|---:|
| CPU | 4.739 | **4.726** | -0.3% |
| Graphics | 5.438 | **5.445** | +0.1% |
| Disk | 0.683 | **0.680** | -0.4% |
| Math | 31.228 | **31.202** | -0.1% |
| Old PR | 6.786 | **6.780** | -0.1% |
| New PR | 2.297 | **2.288** | -0.4% |

All six hardware scores are within 0.5% of the preceding run. This change is
therefore accepted as a verified focused-workload improvement with a tiny area
reduction, but it is **not claimed as a measurable Speedometer gain**.

The seed-27 image uses 40,738/41,910 ALMs and 4,182/4,191 LABs, 17 ALMs and one
LAB fewer than the preceding checkpoint. It closes timing at **+0.070 ns worst
setup overall**, +0.772 ns on the 33 MHz CPU clock and +0.070 ns on the 99 MHz
SDRAM clock. Worst hold is **+0.245 ns overall**, +0.263 ns on the CPU clock and
+0.430 ns on the SDRAM clock, with zero setup or hold TNS.

The RBF is `Wombat33_CPU_adddecode_seed27_20260903.rbf`, MD5
`cb83d1a71d262a61af9a5508a443506d` and SHA-256
`512558ea68f5bc5e9dfeb79be9bd0860e44f2d2046e4909bb3c6096c6e24816a`.
The exact Quartus build is preserved at
`/home/alans/builds/wombat33_cpu_adddecode_seed27_20260903`. Mac OS 7.5.5
booted, completed every PR category including Disk, and reached its safe-to-
switch-off screen. The MiSTer then returned to its menu and the disposable disk
was restored from the compressed golden; both disk copies matched MD5
`0c4f774b4a2eccd5656e92f16119875f` afterward.

## 20. AP040 FPU register bank in MLABs (area reclaim)

This pass creates headroom for later CPU work; it is not intended to change
instruction timing. The FPU now captures both command-time operands once and
uses the existing destination shadow thereafter. FMOVEM stores share the
ordinary source read port. FP0--FP7 are held in two mirrored 8x80
simple-dual-port MLAB memories, providing two asynchronous reads and one shared
synchronous write. An 8-bit valid mask supplies the architectural reset NaN
without reset muxes on the 640 payload bits.

Quartus infers exactly 1,280 MLAB memory bits in eight Memory LABs. The complete
synthesis netlist falls from 80,721 to 79,252 logic cells, while the FPU falls
from 8,462 logic cells/2,243 registers to 7,091/1,617. The seed-27 physical fit
uses **39,358/41,910 ALMs** and **4,176/4,191 LABs**, respectively 1,380 ALMs
and six LABs below the preceding checkpoint. LAB packing therefore remains the
limiting resource even though the 3.4% ALM reduction is substantial. Timing is
clean at +0.290 ns setup overall (+0.649 ns CPU, +0.591 ns SDRAM) and +0.244 ns
hold overall (+0.262 ns CPU, +0.434 ns SDRAM), with zero TNS.

The complete AP68040 suite, 212,238-cycle focused loop, full-machine Verilator
build, first 100 CPU rows, all 270 FPU rows, all 8 save/restore rows, and all
1,328 CPU/FPU integration rows pass with zero real differences. The hardware
run used Speedometer 3.23 `Run ALL Tests`, not just the PR shortcut, and
completed its additional Color and FPU groups at averages 1.615 and 2.446.

| Speedometer 3.23 PR Test | ADD decode checkpoint | FPU MLAB bank | change |
|---|---:|---:|---:|
| CPU | 4.726 | **4.726** | 0.0% |
| Graphics | 5.445 | **5.452** | +0.1% |
| Disk | 0.680 | **0.685** | +0.7% |
| Math | 31.202 | **31.512** | +1.0% |
| Old PR | 6.780 | **6.814** | +0.5% |
| New PR | 2.288 | **2.301** | +0.6% |

These differences are normal run-to-run variation, so no speed gain is claimed.
The important hardware result is that the asynchronous MLAB reads and shared
write port remain stable throughout the exhaustive CPU/FPU workload. The RBF is
`Wombat33_CPU_fpu_mlab_seed27_20260903.rbf`, MD5
`c4fd9f3140da2658c366156febf8201f` and SHA-256
`4a68ab336a31dda029c1de75bcb6bfeee2b58422d1ef9b5d1fa2745e8a28cd5c`.
The exact Quartus build is preserved at
`/home/alans/builds/wombat33_cpu_fpu_mlab_seed27_20260903`.

Mac OS reached its safe-to-switch-off screen, the MiSTer returned to `MENU`,
and only the disposable `QuadSquad8.hda` was restored from the validated
compressed golden. Both it and the untouched pristine reference then matched
MD5 `0c4f774b4a2eccd5656e92f16119875f`.

## 21. DAFB palette in explicit M10K mirrors (area reclaim)

The DAFB RAMDAC palette needs one CPU read view and one independent scanout
read view. Quartus implemented the original three arrays as three M10Ks plus a
6,144-register second read copy. Parent commit `3a960b5` makes the two views
explicit, writes both, and keeps the video read registered in the `clk_vid`
domain. Quartus instead infers six simple-dual-port M10Ks and preserves the
existing one-pixel palette lookup latency.

The complete synthesis netlist falls from 79,252 to 70,386 logic cells. In the
seed-27 fit, DAFB itself falls from 3,607.5 fitted ALMs/6,782 registers/3 M10Ks
to 406.9 fitted ALMs/610 registers/6 M10Ks. The complete design uses
**36,525/41,910 ALMs**, **4,099/4,191 LABs**, 24,187 registers, and 428 M10Ks.
That is 2,833 ALMs, 77 LABs, and 6,056 registers below the preceding FPU-MLAB
checkpoint at a cost of three M10Ks and 6,144 block-memory bits. Average/peak
routing utilization also falls from 58.9%/85.5% to 48.1%/74.8%.

Timing is clean with zero TNS: +0.447 ns setup overall (+0.587 ns CPU,
+0.552 ns SDRAM), and +0.244 ns hold overall (+0.251 ns CPU, +0.442 ns SDRAM).
The focused independent-clock palette readback/scanout test, full-machine
Verilator build, and first 100 SingleStepTests CPU rows all pass; the latter
matches 1,696 architectural field groups over 35,196,127 cycles with zero real
differences.

The hardware run booted Mac OS 7.5.5 in full color and completed Speedometer
3.23 `Run ALL Tests`, including FPU and Color averages of 2.446 and 1.618.

| Speedometer 3.23 PR Test | FPU MLAB bank | DAFB palette M10Ks | change |
|---|---:|---:|---:|
| CPU | 4.726 | **4.726** | 0.0% |
| Graphics | 5.452 | **5.430** | -0.4% |
| Disk | 0.685 | **0.683** | -0.3% |
| Math | 31.512 | **31.538** | +0.1% |
| Old PR | 6.814 | **6.810** | -0.1% |
| New PR | 2.301 | **2.295** | -0.3% |

These movements are ordinary run variance; the reclaim is not a speed change.
Its value is physical headroom: cumulatively the FPU and palette passes recover
4,213 ALMs and 83 LABs from the register-ADD checkpoint, leaving 92 LABs free.

![Speedometer 3.23 PR DAFB palette checkpoint](perf/wombat33_dafb_palette_seed27_speedometer323_pr.png)

The exact build is preserved at
`/home/alans/builds/wombat33_dafb_palette_m10k_seed27_20260903`. The RBF is
`Wombat33_DAFB_palette_m10k_seed27_20260903.rbf`, MD5
`c43a310d2c39171e4be7f781904405c4` and SHA-256
`6dbbd34b30d767a32255049cb0e2dad3a9f75dc6454344ac24da9c881d29037c`.
Mac OS reached its safe-to-switch-off screen, the MiSTer returned to its menu,
and the disposable disk was restored from the compressed golden. Both it and
the untouched pristine reference then matched MD5
`0c4f774b4a2eccd5656e92f16119875f`.

## 22. DAFB timing registers in one MLAB (area reclaim)

Parent commit `cec2f3f` combines Swatch's ten horizontal and seven vertical
12-bit timing words in one power-of-two 32x12 MLAB. Their CPU-visible register
addresses remain unchanged. Quartus previously rejected the two small arrays
for memory inference and implemented 204 scattered registers.

The fair comparison is seed 28 on both forms:

| seed-28 metric | palette control | timing MLAB | change |
|---|---:|---:|---:|
| fitted ALMs | 36,659 | **36,592** | **-67** |
| LABs used | 4,096 | **4,080** | **-16** |
| registers | 24,141 | **23,944** | **-197** |
| MLAB bits | 1,280 | 1,664 | +384 |
| routing average/peak | 49.1%/77.1% | **48.4%/76.2%** | lower |

The accepted seed-28 fit leaves 111 of 4,191 LABs free and closes timing with
zero TNS: +0.291 ns setup overall (+0.862 ns CPU, +0.291 ns SDRAM) and +0.243
ns hold overall (+0.254 ns CPU, +0.433 ns SDRAM). Seed 27 fits in 36,463 ALMs
and 4,070 LABs but is rejected because SDRAM setup is -0.453 ns with -0.692 ns
TNS. This is why the committed QSF changes its default seed to 28.

The focused first/boundary/last timing-register and palette test passes. The
full-machine Verilator build passes, and the first 100 SingleStepTests CPU rows
remain exactly 35,196,127 cycles with 1,696 matching architectural field groups
and zero real differences.

Mac OS 7.5.5 booted in full color and completed Speedometer 3.23 `Run ALL
Tests`, including the full Benchmark, PR, Disk, Math, FPU, and Color groups.
Progress screenshots were mistakenly taken while Graphics and Disk were being
timed, contrary to the method in section 6, so the run is accepted as a
functional soak but not as a controlled speed comparison. Its results were CPU
4.726, Graphics 5.204, Disk 0.676, Math 31.565, Old PR 6.743, New PR 2.267,
FPU average 2.453, and Color average 1.613. CPU and the later untouched groups
remain consistent with the prior run; the unperturbed palette checkpoint
remains the performance reference.

![Speedometer 3.23 timing-MLAB completion](perf/wombat33_dafb_timing_mlab_seed28_speedometer323_complete.png)

![Speedometer 3.23 timing-MLAB PR](perf/wombat33_dafb_timing_mlab_seed28_speedometer323_pr.png)

The exact build is preserved at
`/home/alans/builds/wombat33_dafb_timing_mlab_seed28_20260903`. The RBF is
`Wombat33_DAFB_timing_mlab_seed28_20260903.rbf`, MD5
`f6db788d637aaf2baf275ef82e015c2a` and SHA-256
`ae937e62a675a248124e2b065db984e29d16ffc916f840d8a0f6abe2c552fd01`.
Mac OS reached its safe-to-switch-off screen, the MiSTer returned to its menu,
and both the restored disposable disk and untouched pristine reference matched
MD5 `0c4f774b4a2eccd5656e92f16119875f`.

## 23. Rejected SUB.L register preselection

The next isolated experiment extended the accepted decode-time register-port
selection from `ADD.L Dn,Dn` to `SUB.L Dn,Dn`. It passed the complete AP68040
suite and full-machine Verilator build. The focused `bench_loop` remained
exactly 212,238 cycles and contained no eligible SUB form. The first 100
SingleStepTests rows fell from 35,196,127 to 35,195,412 cycles, a saving of only
715 cycles (about 0.002%), with all 1,696 architectural field groups matching.

The exact rejected fit is preserved at
`/home/alans/builds/wombat33_cpu_subdecode_seed28_20260904`. At the same seed as
the accepted timing-MLAB checkpoint it used 36,560 ALMs and 4,083 LABs, versus
36,592 ALMs and 4,080 LABs: 32 fewer ALMs but three more LABs. More importantly,
the 99 MHz SDRAM setup path fell from +0.291 ns to -0.296 ns with -0.324 ns TNS.
The CPU setup path remained positive at +1.074 ns and all hold paths passed.
Because the dynamic benefit is negligible and timing no longer closes, the RTL
was reverted without producing or deploying a hardware candidate. Do not
seed-walk this form unless a representative workload later shows substantial
SUB.L register-register traffic.

The analogous `AND.L Dn,Dn` experiment passed the complete AP68040 suite and
left the focused `bench_loop` exactly at 212,238 cycles, again with no eligible
instances. It reduced the first 100 SingleStepTests rows from 35,196,127 to
35,195,381 cycles, saving only 746 cycles (about 0.0021%), with all 1,696 field
groups matching. Since this is the same negligible dynamic benefit as SUB and
cannot move application-level performance, it was reverted before Quartus.

`OR.L Dn,Dn` also passed the complete AP68040 suite and left the focused loop
at 212,238 cycles. The first 100 SingleStepTests rows measured 35,196,088
cycles, only 39 cycles (about 0.00011%) below the accepted checkpoint, with all
1,696 field groups matching. It was reverted without a Quartus build.

`EOR.L Dn,Dn` produced the same result: the complete AP68040 suite passed, the
focused loop remained 212,238 cycles, and the first 100 SingleStepTests rows
measured 35,196,088 cycles with all 1,696 field groups matching. Its 39-cycle
gain was rejected before Quartus.

## 24. AP040 register-CMP decode preselection (Speedometer 3.23)

AP68040 commit `d543f2d` extends the narrow, accepted ADD technique to only
`CMP.L Dn,Dn`: decode selects both asynchronous register-file ports and enters
`S_PIPE_REGS`, skipping `S_PIPE_START` while retaining operand capture and
`S_EXEC`. Other CMP sizes and addressing modes are unchanged. Parent RTL
commit `b0e6174` records the submodule pointer.

The complete AP68040 suite and full-machine Verilator build pass. The focused
loop stays at 212,238 cycles because it contains no eligible CMP. In contrast,
the first 100 SingleStepTests rows fall from 35,196,127 to 35,168,444 cycles,
saving 27,683 cycles (0.0787%), with all 1,696 architectural field groups
matching and zero real differences.

The same-seed physical comparison is also favorable:

| seed-28 metric | timing-MLAB control | CMP preselection | change |
|---|---:|---:|---:|
| fitted ALMs | 36,592 | **36,446** | **-146** |
| LABs used | 4,080 | **4,063** | **-17** |
| LABs free | 111 | **128** | **+17** |
| registers | 23,944 | **23,938** | **-6** |
| MLAB bits | 1,664 | 1,664 | 0 |
| setup overall/SDRAM | +0.291 ns | +0.133 ns | pass |
| setup CPU | +0.862 ns | **+1.192 ns** | pass |
| hold overall | +0.243 ns | +0.242 ns | pass |

All setup and hold domains have zero TNS. The complete `Run ALL Tests`
hardware pass produced:

| Speedometer 3.23 PR Test | unperturbed control | CMP preselection | change |
|---|---:|---:|---:|
| CPU | 4.726 | **4.765** | **+0.83%** |
| Graphics | 5.430 | 5.394 | -0.66% |
| Disk | 0.683 | 0.676 | -1.02% |
| Math | 31.538 | 31.480 | -0.18% |
| Old PR | 6.810 | 6.808 | -0.03% |
| New PR | 2.295 | 2.280 | -0.65% |

The CPU increase is accepted as a measurable benefit: the PR tests ran without
screen captures or remote input during their timed intervals, the RTL change
is confined to CPU CMP decoding, and the corpus independently predicts a
cycle reduction. The smaller unrelated-category movements are treated as run
variance. FPU average was 2.432 and Color average 1.614. A progress capture was
taken while the final Color group was still running, but only after every PR
test had completed; the completion dialog below was captured after all groups
finished.

![Speedometer 3.23 CMP completion](perf/wombat33_cpu_cmpdecode_seed28_speedometer323_complete.png)

![Speedometer 3.23 CMP PR](perf/wombat33_cpu_cmpdecode_seed28_speedometer323_pr.png)

The exact build is preserved at
`/home/alans/builds/wombat33_cpu_cmpdecode_seed28_20260904`. The RBF is
`Wombat33_CPU_cmpdecode_seed28_20260904.rbf`, MD5
`40ba7971e90a2af461276bee0f2159ae`, SHA-256
`44fba87ab5864a42cd4fe0ad6022c01e8f2905272fd03a9da9e4a5d673207f3e`.
Mac OS reached its safe-to-switch-off screen, MiSTer returned to `MENU`, and
the disposable disk was restored to MD5
`0c4f774b4a2eccd5656e92f16119875f`. The untouched golden gzip remains at MD5
`671894be51b1cd1e0c0c8fb4ec39173e`.

## 25. Rejected AP040 register-MOVE decode preselection

A full-machine profile after the accepted CMP checkpoint covered 125 million
CPU clocks and 11,126,598 dispatches, or 11.23 clocks per dispatch. The largest
state occupancies were `S_MRD` 35.2%, fetch 13.2%, decode 8.9%, `S_IMMF` 7.3%,
and `S_MWR` 5.5%. In a bounded 71,209-instruction trace, `MOVE.L` accounted for
33,874 instructions. The exact `MOVE.L (A1),(A2)+` copy form alone accounted
for 29,254, while `MOVE.L Dn,Dn` accounted for only 1,494 (2.1% of the trace).

The low-risk register form was nevertheless tested as a calibration point.
Decode selected both register-file ports for only `MOVE.L Dn,Dn` and entered
`S_PIPE_REGS`, skipping `S_PIPE_START`. The complete AP68040 suite and
full-machine Verilator build passed. The focused loop stayed at 212,238 cycles
because it contains no eligible instruction. The first 100 SingleStepTests rows
fell from the CMP checkpoint's 35,168,444 cycles to 35,099,648, saving 68,796
cycles (0.1956%), with all 1,696 architectural field groups matching and zero
real differences.

Seeds 28 and 29 failed unrelated SDRAM hold/setup paths. Seed 30 closed all
domains with the following result. Because the accepted and candidate fits use
different seeds, the physical deltas below describe the deployable images, not
a controlled same-seed netlist comparison. At the same seed 28, the candidate
actually used 44 fewer ALMs and 21 fewer LABs, but failed SDRAM hold by 0.449 ns
with -0.887 ns TNS.

| metric | CMP checkpoint, seed 28 | register MOVE, seed 30 | change |
|---|---:|---:|---:|
| fitted ALMs | 36,446 | 36,453 | +7 |
| LABs used | 4,063 | 4,070 | +7 |
| LABs free | 128 | 121 | -7 |
| registers | 23,938 | 23,974 | +36 |
| MLAB bits | 1,664 | 1,664 | 0 |
| setup overall/SDRAM | +0.133 ns | +0.183 ns | pass |
| setup CPU | +1.192 ns | +0.954 ns | pass |
| hold overall | +0.242 ns | +0.242 ns | pass |
| hold CPU/SDRAM | +0.245 ns / pass | +0.266 ns / +0.450 ns | pass |

Mac OS 7.5.5 booted normally and completed Speedometer 3.23 `Run ALL Tests`
without screenshots or remote input during the timed interval:

| Speedometer 3.23 PR Test | CMP checkpoint | register MOVE | change |
|---|---:|---:|---:|
| CPU | **4.765** | 4.752 | -0.27% |
| Graphics | 5.394 | 5.190 | -3.78% |
| Disk | 0.676 | 0.681 | +0.74% |
| Math | 31.480 | 31.862 | +1.21% |
| Old PR | 6.808 | 6.780 | -0.41% |
| New PR | 2.280 | 2.280 | 0.00% |

FPU averaged 2.487 and Color averaged 1.611. The category movement is broader
than this CPU-only RTL change can explain and is treated as run variance. Most
importantly, CPU PR did not improve. The small synthetic saving therefore does
not justify retaining a timing-clean image with seven fewer free LABs, so the
RTL was reverted and the CMP checkpoint remains accepted.

The exact rejected build is preserved at
`/home/alans/builds/wombat33_cpu_movedecode_seed30_20260904`. Its RBF is
`Wombat33_CPU_movedecode_seed30_20260904.rbf`, MD5
`811c543776171cb3139096ca61614257`, SHA-256
`eb335a042534e741751a438bff29b2924f69ae22a54d26e6e6c8755a3c5d82af`.
Mac OS reached the safe-to-switch-off screen and the disposable disk was
restored to MD5 `0c4f774b4a2eccd5656e92f16119875f`. No further Wombat core was
loaded. The user then reserved the MiSTer for another project; that reservation
was explicitly lifted before the following experiment.

## 26. Rejected AP040 memory-to-memory MOVE retirement

The next experiment targeted the boot profile's dominant exact form,
`MOVE.L (An),(Am)+` with distinct address registers. While the source read was
outstanding, register-file port B held the destination address register. On a
successful non-page-crossing read, the core updated and rollback-recorded the
destination register, updated MOVE condition codes, and entered the existing
registered `S_MWR` path directly. This removed `S_PIPE_SDONE`, `S_PIPE_DST`,
`S_EA_DISP`, `S_PIPE_DEA`, and `S_EXEC` without reintroducing the unsafe direct
bus-acknowledgement path.

The complete AP68040 suite passed, including new exact cache-hot data/address/
CCR checks and a destination write-protection fault whose handler repairs the
mapping and restarts the instruction. The restarted store incremented the
destination register exactly once. Full-machine Verilator also passed. The
focused loop stayed at 212,238 cycles and the first 100 SingleStepTests rows
stayed at 35,168,444 because neither contains the form. An expanded corpus ran
406 complete rows before the harness's 2.5-billion-cycle timeout; all 6,740
completed field groups matched with zero real differences.

Seed 28 met every timing domain with zero TNS:

| metric | CMP checkpoint | memory-to-memory MOVE | change |
|---|---:|---:|---:|
| fitted ALMs | 36,446 | 36,664 | +218 |
| LABs used | 4,063 | 4,079 | +16 |
| LABs free | 128 | 112 | -16 |
| registers | 23,938 | 23,946 | +8 |
| MLAB bits | 1,664 | 1,664 | 0 |
| setup overall | +0.133 ns | +0.323 ns | pass |
| setup SDRAM | +0.133 ns | +0.758 ns | pass |
| setup CPU | +1.192 ns | +1.067 ns | pass |
| hold overall | +0.242 ns | +0.243 ns | pass |
| hold CPU / SDRAM | +0.245 / +0.431 ns | +0.262 / +0.434 ns | pass |

Mac OS 7.5.5 booted normally and completed every Speedometer 3.23 `Run ALL
Tests` category. No capture or input occurred during either timed interval;
the only interruption was Speedometer's required scratch-drive prompt, where
the disposable `Mac7-5-5` volume was selected before the quiet run resumed.

| Speedometer 3.23 PR Test | CMP checkpoint | memory-to-memory MOVE | change |
|---|---:|---:|---:|
| CPU | **4.765** | 4.726 | -0.82% |
| Graphics | 5.394 | 5.438 | +0.82% |
| Disk | 0.676 | 0.690 | +2.07% |
| Math | 31.480 | 31.486 | +0.02% |
| Old PR | 6.808 | 6.808 | 0.00% |
| New PR | 2.280 | 2.311 | +1.36% |

FPU averaged 2.446 and Color averaged 1.615. The CPU score did not improve and
the other movements are within the cross-category variance seen in prior runs.
The candidate therefore does not justify 218 ALMs and 16 LABs. Its RTL and
directed tests were reverted; accepted AP68040 commit `d543f2d` remains the
checkpoint.

The exact rejected build is preserved at
`/home/alans/builds/wombat33_cpu_movemempostinc_seed28_20260904`. Its RBF is
`Wombat33_CPU_movemempostinc_seed28_20260904.rbf`, MD5
`ca44e2cfcf5a364b2b0dcf1073a0c1c6`, SHA-256
`9ecec53f26e50ad250dfd3deaada1c3527ea1a31fd844350c54482fb0da84c02`.
Mac OS reached the safe-to-switch-off screen, MiSTer returned to `MENU`, and
both the disposable and pristine-reference disks were restored/verified at
MD5 `0c4f774b4a2eccd5656e92f16119875f`. The untouched golden gzip remains MD5
`671894be51b1cd1e0c0c8fb4ec39173e`. The user has re-authorized FPGA use for
the continuing CPU plan.

## 27. Accepted AP040 resident-opcode inline retirement

The first broader front-end experiment removed the normal `S_FETCH` retirement
bubble when `fetch_next` already has the next opcode resident in the prefetch
queue. IRQ and trace checks still run first, queue flushes still win, and a
queue miss still uses the original fetch state. The focused phase-1 loop fell
from 212,238 to 186,380 cycles, saving 25,858 cycles or 12.18%. The first 100
SingleStepTests CPU rows fell from 35,168,444 to 32,935,620 cycles, saving
2,232,824 cycles or 6.35%; all 1,696 architectural field groups match with zero
real differences. The complete AP68040 suite and full-machine Verilator build
also pass.

The first timing-clean implementation failed its hardware boot immediately
with Sad Mac `0000000F / 00000003`, an illegal-instruction system error. This
was a real retirement-order bug, not a fitter or disk failure. The core's main
and auxiliary register-file write strobes commit inside `ap040_regfile` on the
following qualified edge. The removed `S_FETCH` state had implicitly hidden
that latency. Most instructions only select asynchronous read ports in decode
and consume them later, but two paths use architectural values immediately:
short `BSR.B` begins its push from A7, and `MOVE USP,An` reads USP directly.

Two narrow forwarding paths now cover those consumers. Permanent directed
tests warm the fetch queue and exercise `MOVE.L A0,A7; BSR.B` plus
`MOVE A0,USP; MOVE USP,A1`. Removing either bypass makes its corresponding test
fail in all three memory phases; restoring it passes. AP68040 commit `8ab1057`
contains the accepted RTL and tests, and parent RTL checkpoint `9d0cad0`
advances the submodule to it.

The repaired seed-28 fit closes every timing domain with zero TNS:

| metric | CMP checkpoint | inline retirement | change |
|---|---:|---:|---:|
| fitted ALMs | 36,446 | 36,704 | +258 |
| LABs used | 4,063 | 4,099 | +36 |
| LABs free | 128 | 92 | -36 |
| registers | 23,938 | 23,974 | +36 |
| MLAB bits | 1,664 | 1,664 | 0 |
| setup overall | +0.133 ns | +0.208 ns | pass |
| setup SDRAM | +0.133 ns | +0.934 ns | pass |
| setup CPU | +1.192 ns | +1.122 ns | pass |
| hold overall | +0.242 ns | +0.243 ns | pass |
| hold CPU / SDRAM | +0.245 / +0.431 ns | +0.257 / +0.441 ns | pass |

Mac OS 7.5.5 then booted past the exact point where the unfixed image failed
and completed Speedometer 3.23 `Run ALL Tests`. No screenshots or input
occurred during either timed interval; only the required `Mac7-5-5` scratch
volume prompt was serviced between them.

| Speedometer 3.23 PR Test | CMP checkpoint | inline retirement | change |
|---|---:|---:|---:|
| CPU | 4.765 | **4.985** | **+4.62%** |
| Graphics | 5.394 | **5.818** | **+7.86%** |
| Disk | 0.676 | **0.687** | **+1.63%** |
| Math | 31.480 | **33.079** | **+5.08%** |
| Old PR | 6.808 | **7.185** | **+5.54%** |
| New PR | 2.280 | **2.348** | **+2.98%** |

The CPU benchmark average is 13.185, FPU average 2.664, and Color average
1.707. Result captures are
`docs/perf/wombat33_cpu_inlinefetch_wb_seed28_speedometer323_pr.png` and
`docs/perf/wombat33_cpu_inlinefetch_wb_seed28_speedometer323_detail.png`.

The exact Quartus tree is
`/home/alans/builds/wombat33_cpu_inlinefetch_wb_seed28_20260904`. The preserved
RBF is `Wombat33_CPU_inlinefetch_wb_seed28_20260904.rbf`, MD5
`73568cd19f467334e149a77b3b6c9ecd`, SHA-256
`d82388d8b4f71dc42c8cb188befc3998f3cadda21e1e37ef3e375d5dfe020f13`.
After the run Mac OS reached the safe-to-switch-off screen, MiSTer returned to
`MENU`, and both disposable and pristine-reference disks were verified at MD5
`0c4f774b4a2eccd5656e92f16119875f` after the golden restore.

## 28. Accepted AP040 resident-immediate consumption

After inline opcode retirement, the focused profile still spent 13,915 cycles
in `S_IMMF`. The first experiment tried retiring directly from the instruction
bus forward path (`epf_fwd`), but the focused benchmark never exercised that
condition and its cycle count did not move. That version was reverted. The
accepted target instead handles the common case in which decode asks `immf`
for extension words that are already resident in the prefetch queue.

AP68040 RTL commit `0a84732` consumes one or two resident words during
`S_DECODE` and advances directly to the requested return state. Later-state
callers remain on the established `S_IMMF` path because several build
multi-part EA or FPU operands around that boundary. The inline path also
requires no outstanding prefetch and no same-edge `mem_ack`; it asserts
`epf_issue` while popping the words so that the ordinary speculative-fill
logic cannot claim the port on the same edge.

Those ownership restrictions came from two failures in the first broad
candidate. Exception test 136 failed in phase 0 when its expected timing
boundary disappeared. The MMU suite also reported the page-table walker and
16-bit CPU bus active together at PC `$000004E8`, on the first translated MOVE
after `MOVEC TC`. Advancing into the return state while an old or newly issued
speculative fetch still owned the physical bus caused the overlap. Restricting
the bypass to an idle resident queue fixes both failures without weakening the
immediate hit case.

All pre-hardware gates pass. The focused phase-1 loop falls from 186,380 to
173,718 cycles, saving 12,662 cycles or 6.79%; `S_IMMF` occupancy falls from
13,915 to 1,250 visits. Phase 0 completes in 172,940 cycles. The first 100
SingleStepTests CPU rows fall from 32,935,620 to 32,841,873 cycles, saving
93,747 cycles or 0.285%; all 1,696 architectural field groups match with zero
real differences. Relative to the CMP checkpoint, the cumulative reductions
are 18.15% in the focused loop and 6.62% in the first-100 corpus. The complete
AP68040 suite and full-machine Wombat Verilator build also pass.

The clean seed-28 Quartus fit closes every timing domain with zero TNS:

| metric | resident opcode | resident immediate | change |
|---|---:|---:|---:|
| fitted ALMs | 36,704 | 36,937 | +233 |
| LABs used | 4,099 | 4,092 | -7 |
| LABs free | 92 | 99 | +7 |
| registers | 23,974 | 23,943 | -31 |
| MLAB bits | 1,664 | 1,664 | 0 |
| setup overall | +0.208 ns | +0.342 ns | pass |
| setup CPU | +1.122 ns | +1.267 ns | pass |
| setup SDRAM | +0.934 ns | +0.357 ns | pass |
| hold overall | +0.243 ns | +0.249 ns | pass |
| hold CPU / SDRAM | +0.257 / +0.441 ns | +0.256 / +0.442 ns | pass |

Mac OS 7.5.5 booted normally and completed Speedometer 3.23 `Run ALL Tests`.
No capture or remote input occurred during either timed interval; only the
required scratch-volume prompt was serviced between them.

| Speedometer 3.23 PR Test | resident opcode | resident immediate | change |
|---|---:|---:|---:|
| CPU | 4.985 | **5.088** | **+2.07%** |
| Graphics | 5.818 | 5.718 | -1.72% |
| Disk | 0.687 | 0.686 | -0.15% |
| Math | 33.079 | 33.133 | +0.16% |
| Old PR | 7.185 | 7.201 | +0.22% |
| New PR | 2.348 | 2.349 | +0.04% |

CPU benchmark average is 13.239, FPU average 2.673, and Color average 1.718.
The Graphics movement is treated as run variance: this CPU-only change does
not alter that subsystem, the other categories are stable, and both the CPU PR
and simulation cycle counts improve in the expected direction. This is the new
accepted CPU checkpoint.

The exact Quartus tree is
`/home/alans/builds/wombat33_cpu_inlineimm_seed28_20260904`. The preserved RBF
is `/media/fat/_Unstable/Wombat33_CPU_inlineimm_seed28_20260904.rbf`, MD5
`396140cb1b45c213022ff64d8954e140`, SHA-256
`bccbaec9d1956eeccd651a9001316117c2165c2390455ccc0e997fd1436cb076`.
Result captures are
`docs/perf/wombat33_cpu_inlineimm_seed28_speedometer323_pr.png` and
`docs/perf/wombat33_cpu_inlineimm_seed28_speedometer323_detail.png`.

After the run Mac OS reached the safe-to-switch-off screen, MiSTer returned to
`MENU`, and the disposable disk was restored from the golden. Both disposable
and pristine-reference images match MD5
`0c4f774b4a2eccd5656e92f16119875f`; the golden gzip remains MD5
`671894be51b1cd1e0c0c8fb4ec39173e`.

## 29. Rejected generic AP040 branch-refill dispatch

After resident opcode and immediate consumption, the focused phase-1 profile
still spent 14,820 cycles in `S_FETCH`; 12,663 of those visits consumed an
already complete branch-refill window. AP68040 commit `7a6579f` tested the
broadest safe bypass: `go_pc` directly dispatched the first target opcode and
seeded the following three words whenever the complete four-word window was
valid, no request or acknowledge owned the memory port, and neither trace nor
interrupt processing took priority. Commit `bc582ef` added source-state
attribution to the testbench profiler.

All AP68040 tests and the full-machine Verilator build passed. The focused
phase-1 loop fell from 173,718 to 161,256 cycles, saving 12,462 cycles or
7.17%; only 201 contested refill hits retained `S_FETCH`. The first 100
SingleStepTests CPU rows fell from 32,841,873 to 32,784,319 cycles, saving
57,554 cycles or 0.175%; all 1,696 field groups matched with zero real
differences. Relative to the CMP checkpoint, the cumulative reductions were
24.02% in the focused loop and 6.78% in the first-100 corpus.

The seed-28 fit closed every timing domain, but the generic bypass was costly:

| metric | resident immediate | generic refill dispatch | change |
|---|---:|---:|---:|
| fitted ALMs | 36,937 | 38,159 | +1,222 |
| LABs used | 4,092 | 4,125 | +33 |
| LABs free | 99 | 66 | -33 |
| registers | 23,943 | 23,880 | -63 |
| MLAB bits | 1,664 | 1,664 | 0 |
| setup overall | +0.342 ns | +0.280 ns | pass |
| setup CPU | +1.267 ns | +1.216 ns | pass |
| setup SDRAM | +0.357 ns | +0.280 ns | pass |
| hold overall | +0.249 ns | +0.199 ns | pass |
| hold CPU / SDRAM | +0.256 / +0.442 ns | +0.260 / +0.449 ns | pass |

Mac OS 7.5.5 booted normally and completed Speedometer 3.23 `Run ALL Tests`.
The two timed intervals received no capture or input; only the required
`Mac7-5-5` scratch-volume chooser was serviced between them.

| Speedometer 3.23 PR Test | resident immediate | generic refill dispatch | change |
|---|---:|---:|---:|
| CPU | 5.088 | **5.148** | **+1.18%** |
| Graphics | 5.718 | 5.818 | +1.75% |
| Disk | 0.686 | 0.684 | -0.29% |
| Math | 33.133 | 33.079 | -0.16% |
| Old PR | 7.201 | 7.249 | +0.67% |
| New PR | 2.349 | 2.356 | +0.30% |

CPU benchmark average was 13.265, FPU average 2.665, and Color average 1.720.
The CPU gain is real but too small to justify a 1,222-ALM increase and one
third of the remaining LAB headroom. The generic implementation is therefore
rejected; the parent submodule pointer remained on resident-immediate commit
`c897d77` until the DBcc-only successor in section 30 passed. The generic
source and profiler are preserved on AP68040 branch
`wombat-inline-branch-refill` rather than discarded.

The exact Quartus tree is
`/home/alans/builds/wombat33_cpu_inlinebrf_seed28_20260904`. The preserved RBF
is `/media/fat/_Unstable/Wombat33_CPU_inlinebrf_seed28_20260904.rbf`, MD5
`2ff5c0f37f20d2fc70912a45a6c58cda`, SHA-256
`c01da89326351a570c099f756dbbcdb68a06dfb3831a2c6392b6d5e3174be46a`.
Result captures are
`docs/perf/wombat33_cpu_inlinebrf_seed28_speedometer323_pr.png` and
`docs/perf/wombat33_cpu_inlinebrf_seed28_speedometer323_complete.png`.

Mac OS reached the safe-to-switch-off screen, MiSTer returned to `MENU`, and
the disposable disk was restored from the golden. Both writable test copies
match MD5 `0c4f774b4a2eccd5656e92f16119875f`; the golden gzip remains MD5
`671894be51b1cd1e0c0c8fb4ec39173e`.

## 30. Accepted AP040 DBcc-only branch-refill dispatch

The generic refill experiment's source-state profiler showed that all 12,462
useful direct dispatches in the focused loop came from `S_DBCC1`. That made a
narrow follow-up possible: only a taken, decrementing DBcc with a complete
resident target window can bypass `S_FETCH`. Trace and interrupt priority,
odd-target handling, registered DBcc writeback, bus ownership, and the normal
miss path are unchanged.

The first narrow implementation duplicated the wide branch-buffer-to-queue
writers. It passed simulation, but seed 28 grew to 37,142 ALMs and 4,133 LABs
and failed SDRAM setup at -0.066 ns. AP68040 commit `c9ecf79` instead reuses
the established `issue_ifetch` seeding path and consumes its first target word
locally. This preserves the cycle saving while substantially reducing logic.

All AP68040 tests and the full-machine Verilator build pass. The focused
phase-1 loop falls from 173,718 to 161,256 cycles, saving 12,462 cycles or
7.17%; 12,462 resident DBcc targets dispatch directly and only 201 contested
refill hits retain `S_FETCH`. The first 100 SingleStepTests CPU rows fall from
32,841,873 to 32,841,589 cycles, saving 284 cycles or 0.0009%; all 1,696
architectural field groups match with zero real differences. Relative to the
CMP checkpoint, the cumulative reductions are 24.02% in the focused loop and
6.62% in the first-100 corpus.

Placement remains seed-sensitive. Seed 28 passed with only +0.016 ns SDRAM
setup slack; seed 29 failed that clock at -0.436 ns with -0.818 ns TNS. The
accepted seed-30 fit closes every timing domain with comfortable margin:

| metric | resident immediate, seed 28 | DBcc refill, seed 30 | change |
|---|---:|---:|---:|
| fitted ALMs | 36,937 | 37,063 | +126 |
| LABs used | 4,092 | 4,122 | +30 |
| LABs free | 99 | 69 | -30 |
| registers | 23,943 | 23,929 | -14 |
| MLAB bits | 1,664 | 1,664 | 0 |
| setup overall | +0.342 ns | +0.512 ns | pass |
| setup CPU | +1.267 ns | +1.510 ns | pass |
| setup SDRAM | +0.357 ns | +0.778 ns | pass |
| hold overall | +0.249 ns | +0.207 ns | pass |
| hold CPU / SDRAM | +0.256 / +0.442 ns | +0.260 / +0.397 ns | pass |

The source-identical seed-28 image completed the controlled Mac OS 7.5.5
Speedometer 3.23 `Run ALL Tests` measurement. No capture or remote input
occurred during either timed interval; only the required `Mac7-5-5` scratch
volume prompt was serviced between them.

| Speedometer 3.23 PR Test | resident immediate | DBcc refill | change |
|---|---:|---:|---:|
| CPU | 5.088 | **5.133** | **+0.88%** |
| Graphics | 5.718 | 5.792 | +1.29% |
| Disk | 0.686 | 0.688 | +0.29% |
| Math | 33.133 | 33.051 | -0.25% |
| Old PR | 7.201 | 7.234 | +0.46% |
| New PR | 2.349 | 2.363 | +0.60% |

CPU benchmark average is 13.230, FPU average 2.656, and Color average 1.724.
This retains about three quarters of the generic candidate's hardware CPU gain
while avoiding its 1,222-ALM expansion. It does still consume 30 LABs in the
timing-clean placement, so this is the final narrow state-bypass checkpoint;
future work must target staged overlap with a materially larger measured gain.

The measured seed-28 RBF is
`/media/fat/_Unstable/Wombat33_CPU_dbccbrf_reuse_seed28_20260904.rbf`, MD5
`284864f09d559bd1e76852bb36304be3`, SHA-256
`56ea14a2abd06c6c2d075cd7f74d4db1d7e0e01ddd7c79d12957ab9cc4cbdd54`.
The accepted reproducible tree is
`/home/alans/builds/wombat33_cpu_dbccbrf_reuse_seed30_20260904`; its final RBF
is `/media/fat/_Unstable/Wombat33_CPU_dbccbrf_reuse_seed30_20260904.rbf`, MD5
`f6aa3aad50c283b884132dffd4d7e157`, SHA-256
`db6e2243c81710bcda96479058e72301fb323370e125f724b273618f00c60b99`.
That exact image smoke-booted to full-color MacAtrium before a clean shutdown.
Result captures are
`docs/perf/wombat33_cpu_dbccbrf_seed28_speedometer323_complete.png`,
`docs/perf/wombat33_cpu_dbccbrf_seed28_speedometer323_pr.png`, and
`docs/perf/wombat33_cpu_dbccbrf_seed28_speedometer323_detail.png`.

After both runs Mac OS reached the safe-to-switch-off screen and MiSTer
returned to `MENU`. The disposable and pristine-reference disks both match
MD5 `0c4f774b4a2eccd5656e92f16119875f`; the untouched golden gzip remains MD5
`671894be51b1cd1e0c0c8fb4ec39173e`.

## 31. Rejected one-entry `ADD.L Dn,Dn` predecode

The first staged-overlap experiment captured an exact resident
`ADD.L Dn,Dn` at retirement and dispatched it without a separate `S_DECODE`
visit. A one-sided forwarding path lets a preceding load supply the source
operand; a destination dependency waits one capture edge. Unsupported,
serializing, faulting, interrupt, and trace cases retain the ordinary state
sequence. The source and directed tests are preserved at AP68040 commit
`8eaa12d` on branch `wombat-predecode-regalu`.

The complete AP68040 suite and full-machine Verilator build pass. The focused
phase-1 loop falls from 161,256 to 148,258 cycles, saving 12,998 cycles or
8.06%; 12,800 exact ADD operations take the inline path. Relative to the CMP
checkpoint, the cumulative focused-loop reduction is 63,980 cycles or 30.15%.
The first 100 SingleStepTests CPU rows fall only from 32,841,589 to 32,840,479
cycles, saving 1,110 cycles or 0.0034%. All 1,696 architectural field groups
match with zero real differences; 204 reported changes are test-layout deltas,
not architectural mismatches.

An initial two-sided forwarding version grew the CPU hierarchy by 458 ALMs and
failed seed-30 setup at -0.369 ns; seed 31 also failed at -0.699 ns. The final
one-sided version fits and closes every timing domain, but still spends scarce
placement headroom:

| metric | accepted DBcc, seed 30 | ADD predecode, seed 30 | change |
|---|---:|---:|---:|
| fitted ALMs | 37,063 | 37,334 | +271 |
| LABs used | 4,122 | 4,145 | +23 |
| LABs free | 69 | 46 | -23 |
| registers | 23,929 | 23,984 | +55 |
| setup overall | +0.512 ns | +0.354 ns | pass |
| setup CPU | +1.510 ns | +1.262 ns | pass |
| setup SDRAM | +0.778 ns | +0.739 ns | pass |
| hold overall | +0.207 ns | +0.177 ns | pass |
| hold CPU / SDRAM | +0.260 / +0.397 ns | +0.256 / +0.439 ns | pass |

Mac OS 7.5.5 booted normally and completed Speedometer 3.23 `Run ALL Tests`.
No capture or remote input occurred during either timed interval; only the
required `Mac7-5-5` scratch-volume chooser was serviced between them.

| Speedometer 3.23 PR Test | accepted DBcc | ADD predecode | change |
|---|---:|---:|---:|
| CPU | 5.133 | **5.164** | **+0.60%** |
| Graphics | 5.792 | 5.566 | -3.90% |
| Disk | 0.688 | 0.686 | -0.29% |
| Math | 33.051 | 33.133 | +0.25% |
| Old PR | 7.234 | 7.186 | -0.66% |
| New PR | 2.363 | 2.348 | -0.63% |

CPU benchmark average is 13.254 versus 13.230 (+0.18%); FPU average is 2.704
versus 2.656, and Color average is 1.723 versus 1.724. The focused loop is
strongly biased toward the newly handled load/ADD sequence, while neither the
first-100 corpus nor the full hardware benchmark sees a material gain. The
candidate is therefore rejected: +271 ALMs and 23 LABs are not justified by a
0.60% CPU PR movement and 0.18% CPU-average movement. The accepted parent
submodule pointer remains at `c9ecf79`.

The exact Quartus tree is
`/home/alans/builds/wombat33_cpu_addl_predecode_seed30_20260904`. The preserved
RBF is
`/media/fat/_Unstable/Wombat33_CPU_addl_predecode_seed30_20260904.rbf`, MD5
`28d57a5d1d6adc6f220edc15a340fef9`, SHA-256
`88ff81cb31e97da1081f6e973ec95609b83ff3939ae6ee290127e290561d5afb`.
Result captures are:

- `docs/perf/wombat33_cpu_addl_predecode_seed30_speedometer323_complete.png`
- `docs/perf/wombat33_cpu_addl_predecode_seed30_speedometer323_results.png`
- `docs/perf/wombat33_cpu_addl_predecode_seed30_speedometer323_pr.png`
- `docs/perf/wombat33_cpu_addl_predecode_seed30_speedometer323_detail.png`

After the run Mac OS reached the safe-to-switch-off screen and MiSTer returned
to `MENU`. The disposable and pristine-reference disks both match MD5
`0c4f774b4a2eccd5656e92f16119875f`; the untouched golden gzip remains MD5
`671894be51b1cd1e0c0c8fb4ec39173e`.

## 32. Accepted sequential instruction-cache lookahead

The actual Speedometer 3.23 CPU interval, rather than the focused synthetic
loop, selected this target. At the accepted DBcc checkpoint the profile records
167,686,915 raw instruction-fetch requests and 10.6% cache-state occupancy.
AP68040 commit `8951fd2` adds one private lookahead longword to `ap040_cache`.
On a sequential I-cache hit that remains inside the current 16-byte line, the
cache records the following physical word and way. An exact request can then be
acknowledged directly from idle, successive hits may chain, and unrelated data
traffic does not consume the entry. Reset, `CINV`, a nonmatching instruction
request, and every unsafe line or ownership case clear it. The mechanism never
starts speculative bus traffic and never advances architectural PC.

Directed cache-snoop test T12 checks correct byte lanes, chaining, survival
across data traffic, and absence of extra bus beats. The complete AP68040 reset,
double-fault, walker-CDC, 16-bit bus-gap, timeout, cache-snoop, integer, and
exception suites pass. Full-machine Verilator passes. The focused loop changes
from 161,256 to 160,650 cycles (-606, -0.376%). The first 100 SingleStepTests
rows are exactly unchanged at 32,841,589 cycles; all 1,696 architectural field
groups match with zero real differences.

The unperturbed local Speedometer CPU run shows the broad-workload effect:

| profiled metric | accepted DBcc | I-cache lookahead | change |
|---|---:|---:|---:|
| CPU benchmark average | 13.550 | **13.968** | **+3.08%** |
| profiled CPU clocks | 1,856.5 M | 1,797.5 M | -3.18% |
| dynamic dispatches | 150.059 M | 149.213 M | -0.56% |
| clocks per dispatch | 12.37 | 12.05 | -2.59% |
| raw instruction fetches | 167,686,915 | 151,112,038 | -9.88% |
| cache-state occupancy | 10.6% | 5.7% | -4.9 points |

The candidate records 96,214,523 lookahead hits, equal to 64.48% of dynamic
dispatches. This explains why the real benchmark moves while the focused loop
barely does: the optimization covers ordinary instruction streams broadly
rather than one hot opcode sequence.

Quartus seeds 30 and 31 are rejected. Seed 30 fails setup at -0.128 ns; seed 31
fails setup at -0.090 ns and hold at -0.222 ns. Seed 32 closes all domains:

| metric | accepted DBcc, seed 30 | I-cache lookahead, seed 32 | change |
|---|---:|---:|---:|
| fitted ALMs | 37,063 | 37,357 | +294 |
| LABs used | 4,122 | 4,152 | +30 |
| LABs free | 69 | 39 | -30 |
| fitted registers | 23,929 | 24,026 | +97 |
| setup overall | +0.512 ns | +0.115 ns | pass |
| setup CPU | +1.510 ns | +0.785 ns | pass |
| setup SDRAM | +0.778 ns | +0.115 ns | pass |
| hold overall | +0.207 ns | +0.213 ns | pass |
| hold CPU / SDRAM | +0.260 / +0.397 ns | +0.250 / +0.413 ns | pass |

The seed-32 fit uses 3,135,384 block-memory bits and 428 RAM blocks, with zero
setup or hold TNS. The exact timing-clean RBF booted Mac OS 7.5.5 and completed
Speedometer 3.23 `Run ALL Tests`; no capture or remote input occurred during
the timed interval.

| Speedometer 3.23 result | accepted DBcc | I-cache lookahead | change |
|---|---:|---:|---:|
| CPU benchmark average | 13.230 | **13.588** | **+2.71%** |
| CPU PR | 5.133 | **5.195** | **+1.21%** |
| Graphics PR | 5.792 | 6.074 | +4.87% |
| Disk PR | 0.688 | 0.680 | -1.16% |
| Math PR | 33.051 | 34.011 | +2.90% |
| Old PR | 7.234 | 7.437 | +2.81% |
| New PR | 2.363 | 2.362 | -0.04% |
| FPU average | 2.656 | 2.722 | +2.48% |
| Color average | 1.724 | 1.748 | +1.39% |

The 12 hardware Benchmark Mix timings are KWhetstone 317.460 s, Dhrystone
5059.021 s, Towers 2.167 s, Quick 1.400 s, Bubble 2.000 s, Queens 1.450 s,
Puzzle 3.483 s, Permutations 3.750 s, FFT 6.700 s, FP Matrix 3.283 s, Integer
Matrix 1.550 s, and Sieve 3.500 s. Their average is 13.588.

![Speedometer 3.23 lookahead completion](perf/wombat33_cpu_icache_lookahead_seed32_speedometer323_complete.png)

![Speedometer 3.23 lookahead results](perf/wombat33_cpu_icache_lookahead_seed32_speedometer323_results.png)

![Speedometer 3.23 lookahead PR](perf/wombat33_cpu_icache_lookahead_seed32_speedometer323_pr.png)

Preserved artifacts:

- AP68040 branch/commit: `wombat-icache-lookahead` / `8951fd2`
- parent pointer/seed commit: `f846901`
- Quartus tree:
  `/home/alans/builds/wombat33_cpu_icache_lookahead_seed32_20260905`
- MiSTer RBF:
  `/media/fat/_Unstable/Wombat33_CPU_icache_lookahead_seed32_20260905.rbf`
- RBF MD5: `202f64a6d77495db9f090b57eda9efc8`
- RBF SHA-256:
  `b41ba46f55bc77796c69b59a4cbd48bf093694acf0e1c6d0b918c8cd1bcafaec`
- Additional detail capture:
  `docs/perf/wombat33_cpu_icache_lookahead_seed32_speedometer323_detail.png`

Mac OS reached the safe-to-switch-off screen after the run, MiSTer returned to
`MENU`, and the disposable image was restored from the golden gzip. The
disposable and pristine-reference disks both match MD5
`0c4f774b4a2eccd5656e92f16119875f`; the golden gzip matches MD5
`671894be51b1cd1e0c0c8fb4ec39173e`.

## 33. Upstream AP68040 cache/FPU correctness integration

Upstream AP68040 advanced to `c6a9c63` on 2026-09-05. Its functional change
`a8a50ce` fixes two bugs: a cache read could race a displaced pending store
invalidation, and an unsupported packed-decimal FPU operation could raise its
exception without first preparing the BUSY frame, operand payload, and FPIAR
expected by the handler. Commit `16b674a` also adds a NeXTSTEP MMU regression
covering supervisor transparent translation, SRP selection, a retargeted
pointer descriptor plus `PFLUSH`, and U/M-bit writebacks.

Those upstream commits were integrated on top of the accepted instruction
lookahead as AP68040 commits `9996357` and `299cb36`. The cache conflict kept
Wombat's write-hit update and lookahead invalidation behavior while adding the
upstream `store_inv_lost` read guard. The FPU conflict kept the MLAB-backed
register-file paths while adopting upstream's exception-state capture.

All logic-level gates pass:

- complete AP68040 suite, including cache race T13, MMU checks 200--212, and
  packed-decimal FPU test 650 in all three memory phases;
- full-machine Verilator build;
- focused phase-1 loop: exactly 160,650 cycles;
- first 100 SingleStepTests CPU rows: exactly 32,841,589 cycles, 1,696 field
  groups, zero real differences;
- all 270 FPU rows: 122,289,740 cycles, 5,000 field groups, zero real
  differences;
- all 8 save/restore rows: 4,508,359 cycles, 8 field groups, zero real
  differences.

Seed 32 was rejected without deployment because CPU setup fell to -0.321 ns.
Seed 33 is timing-clean:

| metric | I-cache lookahead, seed 32 | upstream fixes, seed 33 | change |
|---|---:|---:|---:|
| fitted ALMs | 37,357 | **37,131** | -226 |
| LABs used | 4,152 | **4,118** | -34 |
| LABs free | 39 | **73** | +34 |
| fitted registers | 24,026 | 24,035 | +9 |
| setup overall | +0.115 ns | **+0.145 ns** | pass |
| setup CPU | +0.785 ns | **+0.145 ns** | pass |
| setup SDRAM | +0.115 ns | **+0.911 ns** | pass |
| setup HDMI | +0.553 ns | **+0.482 ns** | pass |
| hold overall | +0.213 ns | **+0.244 ns** | pass |
| hold CPU | +0.250 ns | **+0.434 ns** | pass |
| hold SDRAM | +0.413 ns | **+0.256 ns** | pass |

Every setup and hold domain has zero TNS. The 226-ALM/34-LAB movement is a
post-fit placement result, not an RTL area-reclaim claim. Simulated cycle
counts are unchanged, so the controlled I-cache-lookahead hardware scores in
section 32 remain the performance baseline.

The exact RBF booted Mac OS 7.5.5 in full color and completed all six
Speedometer 3.23 groups. A status capture landed during the late FPU/Color
timing, so this run is deliberately recorded only as a functional soak, not a
controlled speed comparison. Mac OS then reached the safe-to-switch-off
screen, MiSTer returned to `MENU`, and the disposable image was restored from
the golden gzip. Both disk copies match MD5
`0c4f774b4a2eccd5656e92f16119875f`; the golden gzip remains
`671894be51b1cd1e0c0c8fb4ec39173e`.

Preserved artifacts:

- AP68040 branch/commit: `wombat-upstream-fixes` / `299cb36`
- parent pointer/seed commit: `c6c6d91`
- Quartus tree:
  `/home/alans/builds/wombat33_cpu_upstream_fixes_seed33_20260905`
- MiSTer RBF:
  `/media/fat/_Unstable/Wombat33_CPU_upstream_fixes_seed33_20260905.rbf`
- RBF MD5: `6147a2cc478f084c1ea77c2bb418811a`
- RBF SHA-256:
  `cc1088e7639bf0662a4a6d59558fe77c333ff8e5037c6251c55117f59df25a68`


## 34. Early normal-RAM operand reads (Speedometer 4.02)

The original 68040 implementation papers describe a six-stage pipeline in
which the EAF address buffer automatically initiates a load, and report that
roughly 40% of instructions perform a data read. The AP68040 core instead
spent its first `S_MRD` cycle copying an already registered request onto the
shared memory port. Issuing an aligned request while entering `S_MRD` removes
that setup cycle without changing translation, cache lookup, acknowledgement,
fault, or retirement behavior.

The first prototype applied this to every aligned `mrd` helper. Although the
complete AP suite passed and 406 CPU-corpus rows produced 6,740 matching field
groups with zero real differences, hardware exposed missing sequencing outside
the normal operand path: Speedometer returned near-zero elapsed times and a
negative Puzzle time. That RBF is rejected. The accepted candidate is limited
to `S_PIPE_SRD`/`S_PIPE_DEA` accesses in the 32 MB RAM window; MMIO,
exception/return, MOVES, indirect-EA, and system/FPU helper reads retain their
old setup cycle.

The narrowed candidate passes the integer, exception, MMU, cache, FPU, reset,
double-fault, and cache-snoop suites. The focused phase-1 loop falls from
160,650 to 147,852 cycles (-7.96%). Seed 21 fits with zero timing TNS:

| metric | merged upstream baseline | early RAM operand read | change |
|---|---:|---:|---:|
| fitted ALMs | 41,057 | **40,873** | -184 |
| LABs used | 4,190 | **4,181** | -9 |
| fitted registers | 25,316 | 25,279 | -37 |
| RAM blocks | 477 | 477 | 0 |
| DSP blocks | 49 | 54 | +5 |
| worst setup | +0.156 ns | **+0.088 ns** | pass |
| CPU setup | +0.325 ns | **+0.899 ns** | pass |
| SDRAM setup | +0.771 ns | **+0.918 ns** | pass |
| worst hold | +0.205 ns | **+0.245 ns** | pass |

Two independently cold-restored Speedometer 4.02 runs both report a 0.399
average. The second run is compared with the exact merged-upstream seed-21
baseline below; each timed interval had no remote input or screen capture.

| CPU Benchmark Mix test | upstream seed 21 | early RAM read | change |
|---|---:|---:|---:|
| KWhetstones/sec | 342.993 | 344.598 | +0.47% |
| Dhrystones/sec | 4432.219 | 4509.069 | +1.73% |
| Towers (s) | 2.176 | 2.146 | +1.40% |
| Quick Sort (s) | 1.751 | 1.725 | +1.51% |
| Bubble Sort (s) | 2.326 | 2.263 | +2.78% |
| Queens (s) | 1.364 | 1.347 | +1.26% |
| Puzzle (s) | 3.781 | 3.676 | +2.86% |
| Permutations (s) | 3.309 | 3.287 | +0.67% |
| Integer Matrix (s) | 2.562 | 2.519 | +1.71% |
| Sieve (s) | 3.978 | 3.948 | +0.76% |
| **average ratio** | **0.394** | **0.399** | **+1.27%** |

The gain is below the old 2% threshold for an area-consuming CPU change, but
this combined checkpoint also replaces duplicate CD-audio divide/modulus logic
with an exact 8-bit reciprocal conversion and is smaller than the baseline.
It therefore improves both performance and the limiting LAB headroom.

![Speedometer 4.02 early RAM operand result](perf/macquadra800_cpu_earlyread_ram_seed21_speedo402.png)

Preserved artifacts:

- AP68040 branch/commit: `cpu-early-data-read-20260909` / `cbac732`;
- parent branch/commit: `cpu-early-data-read-20260909` / `6b3b520` before docs;
- MiSTer RBF:
  `/media/fat/_Unstable/MacQuadra800_CPU_earlyread_ram_seed21_20260909.rbf`;
- RBF SHA-256:
  `cf87f84e70e6621e1ef6ebd3f341c06f2d87dc66dea5b7a3f70ba730aeab9427`.

After both runs the MiSTer was returned to `MENU`; the disposable disk was
restored to golden MD5 `16790b0577e13b45782214433d34954b`. The installed
Main and its preserved pre-test copy both match MD5
`dfb5937ba47720c3ae20abc8f381c462`.

## 35. Source-EA issue from `S_PIPE_START` (rejected)

After the accepted early normal-RAM read in section 34, the next experiment
moved request issue one stage earlier for the three simple source addressing
modes `(An)`, `(An)+`, and `-(An)`. Extension-bearing modes, MMIO,
misalignment, exception/return, MOVES, indirect-EA, and system/FPU helpers kept
the accepted cadence. Postincrement/predecrement restart records and destination
register-port selection were retained.

The implementation is preserved on AP68040 branch
`cpu-simple-source-issue-20260909`, commit `d777c5d`, but is **rejected**. The
complete integer, exception, MMU, cache, FPU, reset, double-fault, cache-snoop,
walker-CDC, 16-bit-gap, and timeout suites pass, and the full-machine Verilator
model compiles and links. In the focused cached phase, `S_PIPE_SRD` occupancy
falls from 12,806 to 199 cycles and total time falls from 147,852 to 135,252
cycles (-8.52%). An immutable 100-row CPU corpus also has zero real result
differences and falls from 32,841,589 to 32,805,897 cycles (-0.109%).

Seed 21 fit logically, but an unrelated HDMI path missed setup by 0.309 ns.
Seed 30 is timing-clean and was the exact hardware image:

| metric | accepted early-read seed 21 | simple-source seed 30 | change |
|---|---:|---:|---:|
| fitted ALMs | 40,873 | 41,137 | +264 |
| LABs used | 4,181 | 4,189 | +8 (2 free) |
| fitted registers | 25,279 | 25,300 | +21 |
| RAM blocks | 477 | 477 | 0 |
| DSP blocks | 54 | 54 | 0 |
| worst setup | +0.088 ns | +0.376 ns | pass |
| CPU setup | +0.899 ns | +0.809 ns | pass |
| SDRAM setup | +0.918 ns | +0.566 ns | pass |
| worst hold | +0.245 ns | +0.219 ns | pass |

Mac OS 7.5.5 booted normally in full color. Speedometer 4.02 was run once from
a freshly restored golden disk, with no capture or remote input during the
timed interval:

| CPU Benchmark Mix test | accepted early read | simple-source issue | change |
|---|---:|---:|---:|
| KWhetstones/sec | 344.598 | 345.069 | +0.14% |
| Dhrystones/sec | 4509.069 | 4555.694 | +1.03% |
| Towers (s) | 2.146 | 2.139 | +0.33% |
| Quick Sort (s) | 1.725 | 1.726 | -0.06% |
| Bubble Sort (s) | 2.263 | 2.264 | -0.04% |
| Queens (s) | 1.347 | 1.341 | +0.45% |
| Puzzle (s) | 3.676 | 3.676 | 0.00% |
| Permutations (s) | 3.287 | 3.287 | 0.00% |
| Integer Matrix (s) | 2.519 | 2.517 | +0.08% |
| Sieve (s) | 3.948 | 3.949 | -0.03% |
| **average ratio** | **0.399** | **0.399** | **0.00%** |

The synthetic hot-loop gain therefore does not survive the full application,
and the candidate consumes nearly all of the reclaimed LAB headroom. It fails
the hardware/area gate and is not the parent submodule revision.

Two DAFB timing-register packing experiments made before this CPU candidate are
also rejected. Mapping the array to MLABs passed its directed test and timing
but used 4,187 LABs despite saving 161 ALMs and 171 registers. A synchronous
M10K version passed its directed test and timing and saved 304 ALMs and 173
registers, but still used 4,187 LABs and one additional RAM block. Neither
improves the limiting free-LAB count over the accepted 4,181-LAB fit.

![Rejected simple-source Speedometer 4.02 result](perf/macquadra800_cpu_simple_source_seed30_speedo402.png)

Preserved artifacts:

- AP68040 branch/commit: `cpu-simple-source-issue-20260909` / `d777c5d`;
- MiSTer RBF:
  `/media/fat/_Unstable/MacQuadra800_CPU_simple_source_seed30_20260909.rbf`;
- RBF SHA-256:
  `0d7e5794828448ce11508cb39aaa6c6fc2d127a9bcb7340c17e417784d747414`;
- result screenshot SHA-256:
  `1b2c726c4e34f5f728aa80384e4c6f54fc8e40ea3d387b288c1ef94da6484dcd`.

After the run MiSTer returned to `MENU`, and the disposable disk was restored
to golden MD5 `16790b0577e13b45782214433d34954b`.

## 36. Early aligned RAM destination writes (rejected)

The 68040 memory-design paper says writes are handed to the data-memory
controller and stored in a write buffer so the integer unit can proceed. This
core already implements that architecture below `ap040_cache`: the two-entry
`wombat_store_buffer` accepted in section 11 acknowledges non-faulting physical
RAM writes on capture, drains them in order, and blocks later reads and device
transactions behind older stores. The bounded follow-up here removed the
remaining AP68040 request-setup cycle. An aligned byte, word, or longword write
from `S_EXEC` claimed an idle port while entering `S_MWR`; completion and bus
fault handling still occurred in `S_MWR`, so no instruction retired early.
MMIO, page-crossing transfers, exception frames, and specialized multi-write
helpers retained their old cadence.

The candidate passes the complete AP integer, exception, MMU, cache, FPU,
reset, double-fault, cache-snoop, walker-CDC, 16-bit-gap, and timeout suites,
and the full-machine Verilator model compiles and links. The focused cached
phase improves only from 147,852 to 147,790 cycles (-0.042%), but the immutable
first-100 CPU corpus falls from 32,841,589 to 31,904,074 cycles (-937,515,
-2.85%). All 1,696 architectural field groups match the hardware oracle with
zero real differences (204 payload-layout differences only).

The exact seed-21 hardware image fits with zero setup and hold TNS:

| metric | accepted early-read seed 21 | early-write seed 21 | change |
|---|---:|---:|---:|
| fitted ALMs | 40,873 | 41,044 | +171 |
| LABs used | 4,181 | 4,188 | +7 (3 free) |
| fitted registers | 25,279 | 25,280 | +1 |
| RAM blocks | 477 | 477 | 0 |
| DSP blocks | 54 | 54 | 0 |
| worst setup | +0.088 ns | +0.162 ns | pass |
| CPU setup | +0.899 ns | +1.044 ns | pass |
| SDRAM setup | +0.918 ns | +0.162 ns | pass |
| worst hold | +0.245 ns | +0.244 ns | pass |

Mac OS 7.5.5 booted normally in full color. Two Speedometer 4.02 CPU Benchmark
Mix runs, each with no remote input or capture during the timed interval,
reported 0.405 and 0.406 versus the accepted core's two 0.399 runs. The repeat
is shown below against the accepted reference:

| CPU Benchmark Mix test | accepted early read | early write run 2 | change |
|---|---:|---:|---:|
| KWhetstones/sec | 344.598 | 349.433 | +1.40% |
| Dhrystones/sec | 4509.069 | 4667.178 | +3.51% |
| Towers (s) | 2.146 | 2.083 | +3.02% |
| Quick Sort (s) | 1.725 | 1.701 | +1.41% |
| Bubble Sort (s) | 2.263 | 2.240 | +1.03% |
| Queens (s) | 1.347 | 1.305 | +3.22% |
| Puzzle (s) | 3.676 | 3.664 | +0.33% |
| Permutations (s) | 3.287 | 3.250 | +1.14% |
| Integer Matrix (s) | 2.519 | 2.477 | +1.70% |
| Sieve (s) | 3.948 | 3.870 | +2.02% |
| **average ratio** | **0.399** | **0.406** | **+1.75%** |

The two-run average is 0.4055 (+1.63%). That is reproducible but below the 2%
gate for an area-consuming CPU change, and the fit sacrifices seven of the ten
free LABs. A broader `ret == S_NEXT` variant saved only one additional corpus
cycle. A longword-only variant retained just 141,989 cycles (0.43%), showing
that a narrow width restriction cannot preserve the gain. The candidate is
therefore rejected from the parent but preserved for future area-reclaim work.

![Rejected early-write Speedometer 4.02 repeat](perf/macquadra800_cpu_earlywrite_seed21_speedo402.png)

Preserved artifacts:

- AP68040 branch/commit: `cpu-early-store-20260909` / `164a376`;
- MiSTer RBF:
  `/media/fat/_Unstable/MacQuadra800_CPU_earlywrite_seed21_20260909.rbf`;
- RBF SHA-256:
  `843d87c12bf53a34fed199364eb91046a0057788a7919857d402a4eb36a40402`;
- repeat screenshot SHA-256:
  `b072af67e308595f453dd3fe06df41ac84c1ae0260238227ae12747b15066e94`.

After the repeat, MiSTer returned to `MENU` and the disposable disk was restored
to golden MD5 `16790b0577e13b45782214433d34954b`.

## 37. Early writes with NCR BCD area reclaim (accepted)

Section 36 rejected early aligned RAM write issue only because its +1.63%
two-run hardware gain cost 171 ALMs and seven of the ten free LABs. Inspection
of the full synthesis hierarchy then found seven `/10` and seven `%10`
networks in `ncr53c96.bin2bcd8`. Replacing them with the exact 8-bit
multiply-by-205 reciprocal already used by `cd_audio` is exhaustive for all
256 inputs: `t=(v*205)>>11`, `u=v-10*t`. The NCR testbench passes all 476,837
checks, and the complete machine Verilator model compiles and links.

The reciprocal conversion removes about 692 combinational ALUTs from the NCR
hierarchy (5,362 to 4,670) in exchange for ten DSP blocks. Combined with
AP68040 early-write commit `164a376`, the exact seed-21 hardware fit has zero
setup and hold TNS:

| metric | accepted early-read seed 21 | early-write + NCR BCD | change |
|---|---:|---:|---:|
| fitted ALMs | 40,873 | **40,523** | -350 |
| LABs used | 4,181 | **4,187** | +6 (4 free) |
| fitted registers | 25,279 | 25,352 | +73 |
| RAM blocks | 477 | 477 | 0 |
| DSP blocks | 54 | 64 | +10 |
| worst setup | +0.088 ns | **+0.398 ns** | pass |
| CPU setup | +0.899 ns | **+0.739 ns** | pass |
| SDRAM setup | +0.918 ns | **+0.904 ns** | pass |
| worst hold | +0.245 ns | **+0.202 ns** | pass |

A cold-restored run and its immediate repeat both report a 0.405 CPU average.
The repeat is shown below against the accepted early-read reference; neither
timed interval had remote input or screen capture.

| CPU Benchmark Mix test | accepted early read | combined candidate | change |
|---|---:|---:|---:|
| KWhetstones/sec | 344.598 | 349.027 | +1.29% |
| Dhrystones/sec | 4509.069 | 4664.089 | +3.44% |
| Towers (s) | 2.146 | 2.085 | +2.93% |
| Quick Sort (s) | 1.725 | 1.703 | +1.29% |
| Bubble Sort (s) | 2.263 | 2.242 | +0.94% |
| Queens (s) | 1.347 | 1.305 | +3.22% |
| Puzzle (s) | 3.676 | 3.666 | +0.27% |
| Permutations (s) | 3.287 | 3.248 | +1.20% |
| Integer Matrix (s) | 2.519 | 2.502 | +0.68% |
| Sieve (s) | 3.948 | 3.872 | +1.96% |
| **average ratio** | **0.399** | **0.405** | **+1.50%** |

One earlier invocation is excluded: it displayed impossible negative values
for the late tests and an average of -13.104. After returning to Menu and
restoring the golden disk, the cold run and immediate repeat were valid and
identical at 0.405. This is accepted because it preserves the reproducible CPU
gain while reducing fitted ALMs below the prior accepted checkpoint. The LAB
trade remains explicit: four LABs are free rather than ten.

![Speedometer 4.02 early-write plus NCR BCD result](perf/macquadra800_cpu_earlywrite_ncrbcd_seed21_speedo402.png)

Preserved artifacts:

- NCR parent commit: `edc5330`;
- AP68040 branch/commit: `cpu-early-store-20260909` / `164a376`;
- combined parent branch/commit before documentation:
  `cpu-early-store-area-20260909` / `dd13663`;
- MiSTer RBF:
  `/media/fat/_Unstable/MacQuadra800_CPU_earlywrite_ncrbcd_seed21_20260909.rbf`;
- RBF MD5: `5b5052589283480efe637aad12bb1f67`;
- RBF SHA-256:
  `4be8597a1b6ac6a5d31a603f610d56f83e65886aacb79f56b8cf2d7ff296d499`;
- accepted result screenshot SHA-256:
  `47a382be2e5a7f3d051d2e905dbea5c59b520e0140283c9f63c00f53e2b3d31f`.

After validation the MiSTer returned to `MENU`; the disposable disk was
restored to golden MD5 `16790b0577e13b45782214433d34954b`. Installed Main and
its preserved pre-test copy both match MD5
`dfb5937ba47720c3ae20abc8f381c462`.
