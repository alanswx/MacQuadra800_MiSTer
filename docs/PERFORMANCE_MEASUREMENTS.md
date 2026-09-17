# Performance measurements — Speedometer 4.02

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

## 13. Alan's AP68040 `299cb36` on the 20260908_3 release recipe (2026-09-08/09)

Candidate `scratch/MacQuadra800_alan299_512cd4f8.rbf` (md5 `512cd4f8…`),
branch `alan-perf-20260908` at `f5ba53e`: the shipped `20260908_3` source
with only the `rtl/ap68040` submodule moved from `5aa596f` to `299cb36`
(queued-opcode retire into decode, resident immediates consumed in decode,
DBcc dispatch from the branch refill sector, one-longword sequential I-cache
lookahead, FPU register bank in MLABs, Adam Polkosnik's cache-invalidation
race and FPU exception-frame fixes). Seed 21, 98 % ALMs, +0.579 ns. Same
disk (Quad Squad, slot 1 second disk and the retail ISO in slot 4 mounted as
on 09-08), Speedometer 4.02, one iteration, operator subagent; screenshots
and the full transcription in `scratch/gate_alan/`.

### Benchmark Mix (Quadra 605 = 1.0), three clean runs

| Test | Run 1 | Run 2 | Run 3 | `5aa596f` (§9) | change |
|---|---|---|---|---|---|
| KWhetstones/sec | 346.185 | 347.467 | 347.528 | 326.2 | +6.5 % |
| Dhrystones/sec | 4577.006 | 4576.791 | 4576.771 | 4173 | +9.7 % |
| Towers (sec) | 2.185 | 2.187 | 2.187 | 2.387 | −8.4 % |
| Quick Sort (sec) | 1.703 | 1.701 | 1.701 | 1.959 | −13.2 % |
| Bubble Sort (sec) | 2.323 | 2.323 | 2.323 | 2.648 | −12.3 % |
| Queens (sec) | 1.366 | 1.366 | 1.366 | 1.534 | −11.0 % |
| Puzzle (sec) | 3.790 | 3.790 | 3.768 | 4.127 | −8.4 % |
| Permutations (sec) | 3.321 | 3.322 | 3.321 | 3.574 | −7.1 % |
| Int. Matrix (sec) | 2.594 | 2.590 | 2.551 | 2.812 | −8.2 % |
| Sieve (sec) | 4.187 | 4.176 | 4.169 | 4.592 | −9.1 % |
| **Average ratio** | **0.394** | **0.395** | **0.396** | 0.361 | **+9.4 %** |

Color QuickDraw (⌘G; only the 8-bit depth was enabled in the dialog this
time): 8-bit 30.370 s, ratio **0.348** (32.540 s / 0.317 in §9, −6.7 %).
FPU (⌘F, Quadra 650 = 1.0): KWhetstones 1515.261, Matrix Mult. 2.408 s,
Fast Fourier 1.130 s, **average 0.279** (0.250, +11.6 %).

Run-to-run spread is under 1 % on every line (Int. Matrix 1.7 %). **No
first-run anomaly**: run 1's Sieve was 4.187 s, in line with runs 2 and 3.

### Boot time went the other way

Finder desktop at **162–202 s** after `load_core` (30 s polling; the splash
was at 20 % with four extension icons at T+100 s, black at T+51 s) against
"about 2 min 15 s" for `20260908_3` on the same disk with the same slot 1
and slot 4 mounts. Everything measured inside the guest is faster, so the
extra 30–60 s is before or around the ROM's disk scan. The Verilator
full-machine boot of a fresh 8.1 install with this CPU never leaves the
ROM's flashing-question-mark stage (26,000 sector reads and counting),
while the same harness at `5aa596f` is being run as the control; see
`RESUME-alan-perf.md`.

### A/UX 3.1 on the same bitstream

Multiuser Finder desktop in 225 s (fsck seen), CommandShell live (`uname -a`
answers), but `shutdown -h now` printed the broadcast, the usual
`callrpc RPC: Port mapper failure` and four `kill: No such process` lines,
half-erased the Finder and then stopped repainting for 25 minutes. Typed
`sync` and `halt` still moved `write_bytes` (~1 MB, then ~0.5 MB), so the
kernel was alive; Shift taps changed nothing, Returns erased a few more
icon labels. The `20260908_3` gate used Special → Shut Down for A/UX, the
09-02 gate used `shutdown -h now` on the `be0a662` CPU and reached "You
may now switch off". Not yet separated between the CPU and the path.

## 14. Alan's `164a376` tip and the lookup read-ahead (2026-09-12, sim)

Two steps on branch `alan-perf-20260908`, both on the 20260908_3 release
recipe (seed 21 unless noted); design note `docs/cpu-lookup-readahead.md`.

**Step 1 -- Alan's tip** (`4404a15`: AP68040 `164a376` early aligned RAM
reads while entering `S_MRD` and stores while entering `S_MWR`, plus his
exact multiply-by-205 `bin2bcd` in `ncr53c96`/`cd_audio`). His hardware
numbers on the same RTL: Speedometer 4.02 Benchmark Mix 0.405 vs 0.394
for `299cb36`. Our seed-21 fit: 40,265 ALMs (96 %), 25,366 registers,
62 % block memory, clk_sys +0.508 ns, clk_ram +1.189 ns, **HDMI PLL
domain -0.164 ns** -- the usual placement-luck path; not deployable, seed
walk owed. rbf `scratch/MacQuadra800_alan164_s21_6d6a6daf.rbf`.

**Step 2 -- lookup read-ahead** (`d6a1815`/`7d8569d`: AP68040
`d325967`). Simulation only so far:

| `bench_loop` | 164a376 | read-ahead | change |
|---|---:|---:|---:|
| phase 0 (MMU translated) | 147,012 | 133,628 | **-9.1 %** |
| phase 2 (cached) | 147,790 | 134,406 | **-9.1 %** |
| `S_MRD` occupancy | 39,338 | 26,554 | -32 % |
| data read request→ack | 2.0 | 1.0 | |
| ifetch request→ack | 1.7 | 1.3 | |

AP68040 suite passes; first-100 silicon corpus 0 REAL diffs (cycles
unchanged at 31,904,073 -- the corpus runs uncached). Full-machine
Verilator boot of the fresh 8.1 install image in progress with the new
`--prof` sequencer profiler (`verilator/sim_main.cpp`).

**Fit (seed 21, release recipe): 40,584 ALMs (97 %), 25,324 registers,
477 RAM blocks, 64 DSPs, timing MET -- HDMI +0.256 ns, clk_sys +0.307,
clk_ram +0.884, hold +0.208.** +319 ALMs over Alan's tip on the same seed.
rbf `scratch/MacQuadra800_readahead_s21_0018d4a9.rbf` (md5 `0018d4a9…`),
staged on the .92 MiSTer as `/media/fat/_Unstable/MacQuadra800_readahead_0018d4a9.rbf`.
Hardware: owed (the .92 MiSTer is shared with a live IRIX guest).

**Step 3 -- fill hold, branch hint, one-state store** (`c9219a8`: AP68040
`9216f3e`). AP suite passes; first-100 silicon corpus 0 REAL diffs and
31,904,073 -> 30,185,494 cycles (-5.4 %, uncached, so the sequencer alone);
`bench_loop` 134,396. The one-state store alone takes the ROM boot phase from 491.3M to 453.1M half-cycles (-7.8 %); the three steps together are -13.1 % against 164a376. **Fit: seed 21 placed but failed to route (congestion); seed 22 fits in 41,096 ALMs (98 %) with timing met -- clk_sys +0.256 ns, HDMI +0.409, clk_ram +0.593, hold +0.225.** rbf `scratch/MacQuadra800_store_s22_ba54b0ee.rbf`, staged on .92 as `/media/fat/_Unstable/MacQuadra800_store_ba54b0ee.rbf`. Seed 23 was also launched in `../MacQuadra800_wt2` for a second placement.

**Full-machine A/B, Verilator, fresh 8.1 install image**, half-cycles from
reset to the ROM boot's first volume write (lba 98; the same 239 sector
reads at the sim's fixed 16,000-tick latency are inside the number):

| core | half-cycles to first write | vs 164a376 |
|---|---:|---:|
| Alan's 164a376 | 521,367,641 | |
| + read-ahead (d325967) | 492,953,061 | -5.5 % |
| + fill hold and branch hint (no store path) | 491,296,965 | -5.8 % |
| + one-state store (9216f3e) | 453,064,767 | **-13.1 %** |

### Hardware gate of the store head (2026-09-12, the .92 MiSTer)

`MacQuadra800_store_ba54b0ee.rbf` (`c9219a8`, seed 22) on 192.168.99.92:
Quad Squad 8.1 disk (slot 0 only, no second disk, no CD; the core's RAM
option at its 32 MB default -- Speedometer reports 32768K), operator
subagent, log and 135 screenshots in `scratch/gate_store/`. As a control
the shipped `20260908_3` was run on the same box, disk and settings; it
reproduces its historical numbers (Mix 0.360 vs 0.361, Queens 1.534,
Bubble Sort 2.652 vs 2.648, FPU 0.251 vs 0.250), so the 32 MB setting does
not distort the comparison.

| item | store head | shipped 20260908_3 (same box) |
|---|---|---|
| Mac OS 8.1: Finder menu bar after `load_core` | **103 s** (icons 142 s) | 135 s |
| Mac OS 8.1: Special -> Shut Down to the halt screen | 41 s, 61 s (and one hang, below) | 56 s |
| A/UX 3.1: multiuser desktop | **137 s**, no fsck | -- |
| A/UX 3.1: `shutdown -h now` to "You may now switch off" | **PASS, 130 s** (299cb36 wedged here) | -- |

Speedometer 4.02 Benchmark Mix (Quadra 605 = 1.0; four candidate runs
0.460 / 0.462 / 0.462 / 0.460, run 3 shown):

| test | shipped 20260908_3 | store head | change |
|---|---:|---:|---:|
| KWhetstones/sec | 326.569 | 385.724 | +18.1 % |
| Dhrystones/sec | 4104.703 | 5771.238 | +40.6 % |
| Towers (s) | 2.376 | 1.845 | -22.3 % |
| Quick Sort (s) | 2.013 | 1.480 | -26.5 % |
| Bubble Sort (s) | 2.652 | 1.944 | -26.7 % |
| Queens (s) | 1.534 | 1.131 | -26.3 % |
| Puzzle (s) | 4.145 | 3.210 | -22.6 % |
| Permutations (s) | 3.576 | 2.829 | -20.9 % |
| Int. Matrix (s) | 2.823 | 2.240 | -20.7 % |
| Sieve (s) | 4.425 | 3.340 | -24.5 % |
| **average ratio** | **0.360** | **0.462** | **+28.3 %** |

Color QuickDraw 8-bit (Cmd+G): 31.435 s / 0.337 -> **25.575 s / 0.414**
(+22.8 %). FPU (Cmd+F, Quadra 650 = 1.0): KWhetstones 1687.809, Matrix
Mult. 2.201 s, Fast Fourier 1.064 s, **average 0.305** vs 0.251 (+21.5 %).
Against the 299cb36 gate (§13, 0.395) the store head is +17 %. Run-to-run
spread under 1 %; no first-run anomaly.

**The one anomaly:** the first Mac OS 8.1 Shut Down (after ~50 min of
uptime with Speedometer's CQD and FPU suites, a file rename, window drags,
zooms and collapses, and Find File still running) closed the Special menu
and then never moved again for 12 minutes: clock frozen, no guest disk
writes, the Finder's event loop not tracking the menu bar, only the
interrupt-driven cursor alive. The next boot reported "not shut down
properly" and the disk was fine. Two later candidate shutdowns (a clean
desktop; and Find File plus a Speedometer run again, ~11 min uptime) and
the release with Find File open all halted cleanly, so it stands as one
hang in three candidate shutdowns, not reproduced and not attributed. A
shutdown soak (repeated boot/activity/shutdown cycles on the candidate and
the release) is the next step before this build is released.

After that point the fast-boot ROM runs ahead into the boot blocks and
then parks forever in the ROM's video identification (`$40802F3A` and the
probe-list walk from `$2F70`): the System asks for the video ID the cold
boot saved and the patched warm path never saved one -- except that the
pristine ROM lands in the same loop after its RAM test, so it is a
sim-vs-hardware difference in what the System reads at start-up, still
unexplained (see `RESUME-alan-perf.md`); the OS-phase profile waits on it.

## 15. The vendored AP68040 with Adam Polkosnik's fixes (2026-09-17, hardware)

`releases/MacQuadra800_20260916_2.rbf` as replaced on 2026-09-17 (md5
`8552a409`, seed 21, timing met +0.244 ns, 37,144 ALMs): the 20260915 CPU
(checkpoint 15 + R1..R4) with the bitfield sizing, FPSP BUSY resume, MOVEM
CM continuation, nonresident ATC, memind, shared ALU/FPU datapaths and the
MLAB integer register file (`docs/cpu-upstream-2026-09.md`). Speedometer
4.02 on the .143 box, Mac OS 8.1 from QuadSquad8.hda with a second disk and
a CD mounted, one iteration of each test, run by the user; screenshot
`perf/speedometer402_vendored_cpu_20260917.png`. The 20260915 column is
run 1 of the three-run operator session of 2026-09-16 00:45
(`scratch/gate_fix/report.md`), same image before its restore.

![Speedometer 4.02 on the vendored CPU](perf/speedometer402_vendored_cpu_20260917.png)

### Benchmark Mix (Quadra 605 = 1.0)

| test | this build abs. | ratio | 20260915 abs. | ratio |
|---|---|---|---|---|
| KWhetstones/sec | 641.245 | 2.180 | 640.080 | 2.176 |
| Dhrystones/sec | 9983.463 | 0.578 | 9983.682 | 0.578 |
| Towers (sec) | 1.229 | 0.520 | 1.196 | 0.534 |
| Quick Sort (sec) | 0.817 | 0.872 | 0.812 | 0.877 |
| Bubble Sort (sec) | 0.886 | 0.857 | 0.887 | 0.857 |
| Queens (sec) | 0.687 | 0.587 | 0.686 | 0.588 |
| Puzzle (sec) | 1.605 | 0.680 | 1.597 | 0.684 |
| Permutations (sec) | 1.883 | 0.432 | 1.882 | 0.432 |
| Int. Matrix (sec) | 1.027 | 0.784 | 1.027 | 0.783 |
| Sieve (sec) | 1.296 | 1.058 | 1.296 | 1.058 |
| **Average** | | **0.855** | | **0.857** (runs 2/3: 0.859) |

Every row is within 3 % of the 20260915 run and eight of the ten are within
one unit of the last digit; Towers is the one mover (+33 ms), on a single
iteration with four Finder windows and a CD mounted. The sim gates had
already said this: `bench_loop` and the corpus run are cycle-identical
between the two CPUs. The fixes are correctness and area, not speed.

### Color QuickDraw

| depth | this build abs. (s) | ratio | 20260915 |
|---|---|---|---|
| Monochrome | 10.689 | 0.646 | not run |
| Two bit | 11.983 | 0.637 | not run |
| Four bit | 13.308 | 0.653 | not run |
| Eight bit | 16.847 | 0.629 | 17.497 s = 0.605 |
| Sixteen bit | greyed out | | |
| **Average** | | **0.641** (four depths) | 0.605 (8-bit only) |

The 8-bit row is the comparable one: 3.7 % faster than 20260915, within
what the video-side idle traffic (a second disk and a CD this time) and a
single iteration can move. The four-depth average is a new baseline.

### Performance Rating

| component | ratio |
|---|---|
| CPU | 0.684 |
| Graphics | 0.741 |
| Disk | 0.859 |
| Math | 8.052 |
| **PR** | **0.810** |

First Speedometer 4.02 Performance Rating recorded on this core; earlier PR
tables in this file are Speedometer 3.23 on Mac OS 7.5.5 and do not compare.
The FPU test (Cmd+F) was not run this time; 20260915's was 0.449.

## 16. CPU pipeline step 1: the one-clock data-cache hit (2026-09-17, hardware)

Branch `CPU-pipeline`, commit 86b6b04 (the shipped 20260916_2 CPU plus Alan
Steremberg's one-clock data hit on a dedicated hint bus, AP68040 6e65192;
`docs/cpu-pipeline-increments-20260917.md`), seed 21, timing met on every
clock (CPU +0.036 ns, HDMI +0.056 ns), 37,439 ALMs (89 %), rbf d157f555.
Speedometer 4.02 on the .143 box, Mac OS 8.1 from QuadSquad8.hda with a
second disk and a CD mounted, one iteration of each test, three Benchmark
Mix runs by the Opus operator (`scratch/pipeline_step1/report.md`, 53
screenshots). Physical RAM 32 MB on this boot. Baseline = section 15 (the
user's run of the shipped CPU on this box).

### Benchmark Mix (Quadra 605 = 1.0)

| test | run 1 | run 2 | run 3 | ratio (run 3) | section 15 abs. | change |
|---|---|---|---|---|---|---|
| KWhetstones/sec | 652.385 | 656.763 | 656.707 | 2.233 | 641.245 | +2.2 % |
| Dhrystones/sec | 10756.451 | 10755.794 | 10756.326 | 0.622 | 9983.463 | +7.7 % |
| Towers (sec) | 1.161 | 1.161 | 1.161 | 0.550 | 1.229 | -5.5 % |
| Quick Sort (sec) | 0.813 | 0.812 | 0.812 | 0.877 | 0.817 | -0.6 % |
| Bubble Sort (sec) | 0.890 | 0.890 | 0.890 | 0.854 | 0.886 | +0.5 % |
| Queens (sec) | 0.659 | 0.659 | 0.659 | 0.612 | 0.687 | -4.1 % |
| Puzzle (sec) | 1.572 | 1.564 | 1.568 | 0.697 | 1.605 | -2.3 % |
| Permutations (sec) | 1.842 | 1.842 | 1.842 | 0.441 | 1.883 | -2.2 % |
| Int. Matrix (sec) | 1.007 | 1.002 | 0.992 | 0.812 | 1.027 | -2.6 % |
| Sieve (sec) | 1.264 | 1.261 | 1.260 | 1.089 | 1.296 | -2.7 % |
| **Average** | **0.875** | **0.878** | **0.879** | | **0.855** | **+2.6 %** (mean 0.877) |

Spread 0.004 across the three runs, no invalid time, no first-run outlier.
Nine of ten tests faster; Bubble Sort is 0.5 % slower in all three runs (its
inner loop is register/branch bound, and the change touches data reads
only). The simulated prediction for this change was +2.5 %.

### Color QuickDraw and FPU

| test | this build | section 15 |
|---|---|---|
| CQD average (Monochrome 0.663, Two bit 0.643, Four bit 0.643, Eight bit 0.621) | **0.643** | 0.641 (+0.3 %) |
| FPU average (KWhetstones 2449.5/s 0.470, Matrix Mult. 1.408 s 0.502, FFT 0.682 s 0.421) | **0.464** | 0.449 (+3.3 %) |

The CQD dialog on this launch had only 8 bits/pixel checked; the operator
re-checked the four depths of section 15 before running. Boot to the Finder
in 82 to 123 s, clean Special -> Shut Down in 45 s through
`scripts/mac_shutdown.sh`, no artefacts or dialogs in 36 minutes of use.
The CPU-side gates for this RTL: `bench_loop` 94,368 -> 81,600 cycles, the
first-100 corpus identical (33,335,739, 0 real diffs).
