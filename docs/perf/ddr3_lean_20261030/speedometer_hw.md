# Speedometer 4 on mister192, 2:1 clock builds (2026-10-29/30)

The user ran Speedometer (Benchmark Mix, Color, FPU, Performance Test) once
per build on Mac OS 8.1; screenshots under `scratch/hw/<build>/speedometer.png`.
One run each, so Dhrystones and Int. Matrix carry this core's run-to-run
spread (about 20 %); the others repeat within about 1 %.

| | current core, 55 MHz | release core, 50 MHz | release core, 54 MHz | dual-memory, 54 MHz | lean DDR3, 54 MHz | step 1 (old vram_ddr3), 54 MHz |
|---|---:|---:|---:|---:|---:|---:|
| build | 7ec4b59 seed 72 (55a) | b294170 seed 72 (r50) | ccbf914 seed 55 (r54) | eeeb7cb seed 70 (m54) | b48a3f4 seed 41 (l2) | b06c1b6 seed 55 (l1) |
| rbf md5 | 91cf7646 | 79f3db26 | 7256651e | f62d743b | 2a480467 | 6c603e11 |
| ALMs | 40,398 (96 %) | 37,991 (91 %) | 38,370 (92 %) | 35,258 (84 %) | 36,499 (87 %) | 37,268 (89 %) |
| CPU / bus clock | 55 / 27.5 MHz | 50 / 25 MHz | 54 / 27 MHz | 54 / 27 MHz | 54 / 27 MHz | 54 / 27 MHz |
| timing | all met (CPU +1.103) | CPU +1.991, HDMI -0.197 | all met (CPU +0.601) | all met (CPU +0.948) | all met (CPU +1.072) | all met (CPU +0.948) |
| **PR** | **2.285** | **2.123** | **2.129** | **2.321** | **2.070** | **2.211** |
| PR CPU | 3.043 | 2.770 | 2.987 | 2.978 | 2.972 | 2.968 |
| PR Graphics | 1.317 | 1.227 | 1.306 | 1.397 | 1.122 | 1.272 |
| PR Disk | 2.670 | 2.558 | 1.952 | 2.582 | 2.608 | 2.589 |
| PR Math | 28.000 | 25.962 | 27.979 | 22.439 | 22.378 | 22.439 |
| Mix average (Quadra 605 = 1) | 3.271 | 2.994 | 3.231 | 3.037 | 3.014 | 3.030 |
| KWhetstones/s | 2,537.1 | 2,361.1 | 2,551.8 | 2,096.6 | 2,074.3 | 2,079.9 |
| Dhrystones/s | 41,179 | 37,561 | 40,503 | 40,509 | 40,397 | 40,436 |
| Towers / Quick / Bubble (s) | 0.207 / 0.249 / 0.294 | 0.229 / 0.276 / 0.322 | 0.212 / 0.255 / 0.299 | 0.212 / 0.265 / 0.299 | 0.213 / 0.267 / 0.300 | 0.212 / 0.265 / 0.299 |
| Queens / Puzzle / Permutations (s) | 0.194 / 0.435 / 0.324 | 0.214 / 0.476 / 0.360 | 0.198 / 0.441 / 0.334 | 0.198 / 0.445 / 0.334 | 0.199 / 0.447 / 0.334 | 0.198 / 0.445 / 0.334 |
| Int. Matrix / Sieve (s) | 0.260 / 0.463 | 0.285 / 0.504 | 0.264 / 0.467 | 0.271 / 0.497 | 0.273 / 0.511 | 0.271 / 0.499 |
| Color mono / 2 / 4 / 8 / 16 bit (s) | 5.482 / 6.410 / 7.406 / 9.419 / 12.556 | 6.020 / 7.029 / 8.145 / 10.360 / 13.753 | 5.777 / 6.711 / 7.786 / 9.930 / 13.238 | 5.634 / 6.483 / 7.555 / 9.773 / n/a (no 16-bit) | 6.351 / 7.310 / 8.396 / 10.603 / 14.753 | 5.604 / 6.578 / 7.616 / 9.617 / 12.954 |
| FPU KWhetstones/s | 7,025.8 | 6,725.4 | 7,250.7 | 5,814.9 | 5,814.3 | 5,825.7 |
| FPU Matrix Mult / FFT (s) | 0.445 / 0.224 | 0.477 / 0.241 | 0.441 / 0.223 | 0.510 / 0.246 | 0.514 / 0.247 | 0.510 / 0.246 |
| FPU average (Quadra 650 = 1) | 1.407 | 1.323 | 1.427 | 1.222 | 1.218 | 1.224 |

The two cores are within a few percent per clock: 55/50 = 1.10, and the
current core scores 1.08-1.11x the release core's on PR CPU, Mix and the
integer tests, 1.07x on Graphics.  The release core at 54 MHz lands where
its clock puts it (54/50 = 1.08: Mix 1.079x, PR CPU 1.078x, Dhrystones
1.078x its 50 MHz run) and within 1-2 % of the current core at 55 on
Mix (3.231 / 3.271), PR CPU and Graphics, its FPU average a hair ahead
(1.427 / 1.407, run-to-run).  Its PR total (2.129) is low only because
of the Disk score, 1.952 against 2.558-2.670 on the other two runs: the
disk test goes through the SD card and Main, not the CPU clock, so one
run's Disk number is not evidence against the build; rerun it before
reading anything into it.

**Dual-memory checkpoint against the release core, both at 54 MHz**
(screenshot `speedometer_dualmem54_s70.png`).  The dual-memory build is
6bfd9c0 (2026-10-23) with only the clock plumbing added; the release core
is it plus the DDR3 VRAM, the 128 KB ROM cache, the store buffer's posted
VRAM stores, the 16+16 KB caches and the FPU store/FMOVEM work, for about
3,100 ALMs more (38,370 against 35,258).

- Integer work is the same: PR CPU 2.978 / 2.987, Dhrystones 40,509 /
  40,503, Towers, Bubble, Queens and Permutations identical.  The 16 KB
  caches show only in the tests with larger working sets: Quick Sort 4 %,
  Int. Matrix 3 %, Sieve 6 % faster on the release core.
- Graphics goes the other way: the BRAM framebuffer is 7 % faster than
  DDR3 on PR Graphics (1.397 / 1.306) and 1.5-2.5 % on each colour depth.
  It has no 16-bit mode (no 16-bit time).
- The gap is the FPU: the release core's Whetstones are 1.22x (2,552 /
  2,097), FPU average 1.17x, PR Math 1.25x.  The Mix average (3.231 /
  3.037, 1.064x) moves with the Whetstone row; without it the integer
  rows are within the 0-6 % above.
- PR total favours the dual-memory build (2.321 / 2.129) only because of
  the release run's low Disk score; with its Disk at 2.58 the release
  core would score about the same.

So the ~3,100 ALMs bought the 1 MB DDR3 framebuffer (16-bit colour and the
16"/21" monitors, at a few percent graphics speed), a 17-25 % faster FPU
and a few percent on cache-bound integer code.

**Lean DDR3 core at 54 MHz** (b48a3f4 seed 41, screenshot
`speedometer_ddr3lean54_s41.png`; this copy of the table carries the earlier
columns from `docs/perf/clock60_20261027/speedometer_hw.md` on
pipelined-040-ddr3-fast60).  Integer work is the same as both other 54 MHz
builds (PR CPU 2.972, Dhrystones 40,397), and the FPU matches the
dual-memory checkpoint (FPU average 1.218 / 1.222, Whetstones 2,074 /
2,097), as expected without the FP store work.  Graphics is the surprise:
PR Graphics 1.122 against 1.306 on the release core, and every Color depth
is 7-11 % slower (mono 6.351 / 5.777 s, 8-bit 10.603 / 9.930, 16-bit
14.753 / 13.238).  The Color tests set their own depths, so the screen's
depth does not explain it.  The two changes from the release core that
can reach drawing are the 8 KB caches (the 2026-10-26 A/B with the 16 KB
caches, read cache and DMU release together was 3-4 % on graphics at 33
MHz) and the vram_ddr3 FIFO rework (cycle-for-cycle identical to the old
module in the lockstep bench).  The step-1 fit (b06c1b6, old FIFO, 8 KB
caches) separates the two.


**Step 1 at 54 MHz** (b06c1b6 seed 55: the same CPU and 8 KB caches,
the release core's vram_ddr3).  No horizontal lines, and graphics is back:
PR Graphics 1.272, every Color depth as fast as or faster than the release
core's run (mono 5.604 / 5.777 s, 8-bit 9.617 / 9.930, 16-bit 12.954 /
13.238).  So the 8 KB caches cost drawing nothing measurable here, and the
lean build's horizontal lines and 14 % graphics loss come from the
vram_ddr3 FIFO rework (b48a3f4), although it matched the old module cycle
for cycle in the lockstep bench.  What the bench does not see is the
netlist: Quartus put the eight 16x8 FIFO arrays in M10Ks (not the MLABs
asked for) with a retimed read address and its own bypass registers.
