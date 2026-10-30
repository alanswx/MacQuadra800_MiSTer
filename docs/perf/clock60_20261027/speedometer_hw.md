# Speedometer 4 on mister192, 2:1 clock builds (2026-10-29/30)

The user ran Speedometer (Benchmark Mix, Color, FPU, Performance Test) once
per build on Mac OS 8.1; screenshots under `scratch/hw/<build>/speedometer.png`.
One run each, so Dhrystones and Int. Matrix carry this core's run-to-run
spread (about 20 %); the others repeat within about 1 %.

| | current core, 55 MHz | release core, 50 MHz | release core, 54 MHz |
|---|---:|---:|---:|
| build | 7ec4b59 seed 72 (55a) | b294170 seed 72 (r50) | ccbf914 seed 55 (r54) |
| rbf md5 | 91cf7646 | 79f3db26 | 7256651e |
| ALMs | 40,398 (96 %) | 37,991 (91 %) | 38,370 (92 %) |
| CPU / bus clock | 55 / 27.5 MHz | 50 / 25 MHz | 54 / 27 MHz |
| timing | all met (CPU +1.103) | CPU +1.991, HDMI -0.197 | all met (CPU +0.601) |
| **PR** | **2.285** | **2.123** | **2.129** |
| PR CPU | 3.043 | 2.770 | 2.987 |
| PR Graphics | 1.317 | 1.227 | 1.306 |
| PR Disk | 2.670 | 2.558 | 1.952 |
| PR Math | 28.000 | 25.962 | 27.979 |
| Mix average (Quadra 605 = 1) | 3.271 | 2.994 | 3.231 |
| KWhetstones/s | 2,537.1 | 2,361.1 | 2,551.8 |
| Dhrystones/s | 41,179 | 37,561 | 40,503 |
| Towers / Quick / Bubble (s) | 0.207 / 0.249 / 0.294 | 0.229 / 0.276 / 0.322 | 0.212 / 0.255 / 0.299 |
| Queens / Puzzle / Permutations (s) | 0.194 / 0.435 / 0.324 | 0.214 / 0.476 / 0.360 | 0.198 / 0.441 / 0.334 |
| Int. Matrix / Sieve (s) | 0.260 / 0.463 | 0.285 / 0.504 | 0.264 / 0.467 |
| Color mono / 2 / 4 / 8 / 16 bit (s) | 5.482 / 6.410 / 7.406 / 9.419 / 12.556 | 6.020 / 7.029 / 8.145 / 10.360 / 13.753 | 5.777 / 6.711 / 7.786 / 9.930 / 13.238 |
| FPU KWhetstones/s | 7,025.8 | 6,725.4 | 7,250.7 |
| FPU Matrix Mult / FFT (s) | 0.445 / 0.224 | 0.477 / 0.241 | 0.441 / 0.223 |
| FPU average (Quadra 650 = 1) | 1.407 | 1.323 | 1.427 |

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
