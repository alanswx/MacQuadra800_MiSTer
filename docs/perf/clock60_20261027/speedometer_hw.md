# Speedometer 4 on mister192, 2:1 clock builds (2026-10-29/30)

The user ran Speedometer (Benchmark Mix, Color, FPU, Performance Test) once
per build on Mac OS 8.1; screenshots under `scratch/hw/<build>/speedometer.png`.
One run each, so Dhrystones and Int. Matrix carry this core's run-to-run
spread (about 20 %); the others repeat within about 1 %.

| | current core, 55 MHz | release core, 50 MHz |
|---|---:|---:|
| build | 7ec4b59 seed 72 (55a) | b294170 seed 72 (r50) |
| rbf md5 | 91cf7646 | 79f3db26 |
| ALMs | 40,398 (96 %) | 37,991 (91 %) |
| CPU / bus clock | 55 / 27.5 MHz | 50 / 25 MHz |
| timing | all met (CPU +1.103) | CPU +1.991, HDMI -0.197 |
| **PR** | **2.285** | **2.123** |
| PR CPU | 3.043 | 2.770 |
| PR Graphics | 1.317 | 1.227 |
| PR Disk | 2.670 | 2.558 |
| PR Math | 28.000 | 25.962 |
| Mix average (Quadra 605 = 1) | 3.271 | 2.994 |
| KWhetstones/s | 2,537.1 | 2,361.1 |
| Dhrystones/s | 41,179 | 37,561 |
| Towers / Quick / Bubble (s) | 0.207 / 0.249 / 0.294 | 0.229 / 0.276 / 0.322 |
| Queens / Puzzle / Permutations (s) | 0.194 / 0.435 / 0.324 | 0.214 / 0.476 / 0.360 |
| Int. Matrix / Sieve (s) | 0.260 / 0.463 | 0.285 / 0.504 |
| Color mono / 2 / 4 / 8 / 16 bit (s) | 5.482 / 6.410 / 7.406 / 9.419 / 12.556 | 6.020 / 7.029 / 8.145 / 10.360 / 13.753 |
| FPU KWhetstones/s | 7,025.8 | 6,725.4 |
| FPU Matrix Mult / FFT (s) | 0.445 / 0.224 | 0.477 / 0.241 |
| FPU average (Quadra 650 = 1) | 1.407 | 1.323 |

The two cores are within a few percent per clock: 55/50 = 1.10, and the
current core scores 1.08-1.11x the release core's on PR CPU, Mix and the
integer tests, 1.07x on Graphics.
