# Speedometer 4 on mister192, 2:1 clock builds (2026-10-29/30)

The user ran Speedometer (Benchmark Mix, Color, FPU, Performance Test) once
per build on Mac OS 8.1; screenshots under `scratch/hw/<build>/speedometer.png`.
One run each, so Dhrystones and Int. Matrix carry this core's run-to-run
spread (about 20 %); the others repeat within about 1 %.

| | current core, 55 MHz | release core, 50 MHz | release core, 54 MHz | dual-memory, 54 MHz |
|---|---:|---:|---:|---:|
| build | 7ec4b59 seed 72 (55a) | b294170 seed 72 (r50) | ccbf914 seed 55 (r54) | eeeb7cb seed 70 (m54) |
| rbf md5 | 91cf7646 | 79f3db26 | 7256651e | f62d743b |
| ALMs | 40,398 (96 %) | 37,991 (91 %) | 38,370 (92 %) | 35,258 (84 %) |
| CPU / bus clock | 55 / 27.5 MHz | 50 / 25 MHz | 54 / 27 MHz | 54 / 27 MHz |
| timing | all met (CPU +1.103) | CPU +1.991, HDMI -0.197 | all met (CPU +0.601) | all met (CPU +0.948) |
| **PR** | **2.285** | **2.123** | **2.129** | **2.321** |
| PR CPU | 3.043 | 2.770 | 2.987 | 2.978 |
| PR Graphics | 1.317 | 1.227 | 1.306 | 1.397 |
| PR Disk | 2.670 | 2.558 | 1.952 | 2.582 |
| PR Math | 28.000 | 25.962 | 27.979 | 22.439 |
| Mix average (Quadra 605 = 1) | 3.271 | 2.994 | 3.231 | 3.037 |
| KWhetstones/s | 2,537.1 | 2,361.1 | 2,551.8 | 2,096.6 |
| Dhrystones/s | 41,179 | 37,561 | 40,503 | 40,509 |
| Towers / Quick / Bubble (s) | 0.207 / 0.249 / 0.294 | 0.229 / 0.276 / 0.322 | 0.212 / 0.255 / 0.299 | 0.212 / 0.265 / 0.299 |
| Queens / Puzzle / Permutations (s) | 0.194 / 0.435 / 0.324 | 0.214 / 0.476 / 0.360 | 0.198 / 0.441 / 0.334 | 0.198 / 0.445 / 0.334 |
| Int. Matrix / Sieve (s) | 0.260 / 0.463 | 0.285 / 0.504 | 0.264 / 0.467 | 0.271 / 0.497 |
| Color mono / 2 / 4 / 8 / 16 bit (s) | 5.482 / 6.410 / 7.406 / 9.419 / 12.556 | 6.020 / 7.029 / 8.145 / 10.360 / 13.753 | 5.777 / 6.711 / 7.786 / 9.930 / 13.238 | 5.634 / 6.483 / 7.555 / 9.773 / n/a (no 16-bit) |
| FPU KWhetstones/s | 7,025.8 | 6,725.4 | 7,250.7 | 5,814.9 |
| FPU Matrix Mult / FFT (s) | 0.445 / 0.224 | 0.477 / 0.241 | 0.441 / 0.223 | 0.510 / 0.246 |
| FPU average (Quadra 650 = 1) | 1.407 | 1.323 | 1.427 | 1.222 |

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
