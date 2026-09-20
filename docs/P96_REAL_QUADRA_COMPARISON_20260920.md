# P96 hardware versus real Quadra 800 — 2026-09-20

Real-machine source: [real_quadra800.jpg](perf/real_quadra800.jpg), visually
transcribed. P96 source: scratch/hardware_p96devmemread_20260920/valid_run5_complete.png.
The table uses the fifth complete hardware run consistently. Percentages are
throughput ratios: candidate/reference for operations per second, and
reference/candidate for elapsed times. These are not percentages of elapsed time.

| Test | Real Quadra | P96 | P96 speed relative to real |
|---|---:|---:|---:|
| Whetstone (K/sec) | 1978.474 | 921.390 | 46.6% |
| Dhrystone (/sec) | 24999.350 | 13986.870 | 55.9% |
| Towers (sec) | 0.469 | 0.764 | 61.4% |
| QuickSort (sec) | 0.532 | 0.624 | 85.3% |
| Bubble Sort (sec) | 0.566 | 0.687 | 82.4% |
| Queens (sec) | 0.307 | 0.525 | 58.5% |
| Puzzle (sec) | 0.799 | 0.984 | 81.2% |
| Permutations (sec) | 0.619 | 1.214 | 51.0% |
| Integer Matrix (sec) | 0.599 | 0.662 | 90.5% |
| Sieve (sec) | 0.974 | 1.029 | 94.7% |

The real screenshot's Mix is **1.897**. P96's five valid all-ten, one-iteration
runs are **1.207, 1.211, 1.211, 1.212, 1.212**: median **1.211**, mean **1.2106**.
No invalid timer results were observed; no runs were excluded. Earlier files
named run1_start/run1_complete are navigation screenshots, not benchmark evidence.
The reviewed benchmark evidence uses the valid_runN_setup/complete filenames.

P96 runs at authentic 33 MHz, 32 MB on the disposable test disk. The real
reference reports 122880K physical RAM, so this is not an identical RAM setup.
The P96 development build omits CD/audio and Ethernet, and its HDMI setup
misses by 0.450 ns; CPU timing passes by 0.174 ns. It is not a release-qualified core.

## What the comparison changes

Whetstone rating is 3.133 versus 6.727: its 0.3594 Mix-point deficit accounts
for approximately 52.5% of the 1.897−1.212 gap. Matching Whetstone alone would
raise this run to about 1.5714, still below 1.8. Permutations, Dhrystone,
Queens and Towers are the next substantial deficits. Matrix and Sieve are
already relatively close; more small queue gains cannot close the whole gap.

Next priority is a faithful original Whetstone fixture/profile, including its
SANE traps and runtime helpers, plus Permutations/Dhrystone instruction and
memory profiles. A low full-run fraction in dedicated FPU RTL states does
not establish that Whetstone is cheap or identify its bottleneck: SANE and
runtime/shared instruction/memory work can execute elsewhere. We must measure
that workload before choosing arithmetic-unit versus general CPU changes.

The unique machine record was saved as p96-record-20260920. Clean shutdown was visually verified in final_shutdown.png: “It is now safe
to switch off your Macintosh.” No Main/core restart was needed during testing.
