# The timing-clean pipeline build against a real Quadra 800 (2026-09-26)

Core: `31b6e99`, seed 24 (RBF md5 `8481fce4`).  It has the pipeline back
(P243/P244), `SCSI_CACHE_OFF`, three release-lite trims and 8+8 KB CPU
caches.  Timing is met on every clock: CPU +1.141, HDMI +0.158, SDRAM
+0.791 ns.  Main: the write-buffer build (`3dd49cd2`).  The guest has 32 MB
(the real machine had 120 MB).  The real machine's numbers come from the
photos `real_quadra800.jpg` and `speedometerrealquadra.png` in this
directory.

## Benchmark Mix (median run of five: 1.768, 1.779, 1.778, 1.784, 1.777)

| test | MiSTer | real Q800 | MiSTer / real (speed) |
|---|---|---|---|
| KWhetstones/sec | 1793.4 | 1979.9 | 91 % |
| Dhrystones/sec | 19385.6 | 24922.1 | **78 %** |
| Towers (s) | 0.476 | 0.468 | 98 % |
| Quick Sort (s) | 0.529 | 0.531 | 100 % |
| Bubble Sort (s) | 0.632 | 0.565 | 89 % |
| Queens (s) | 0.363 | 0.306 | **84 %** |
| Puzzle (s) | 0.766 | 0.798 | 104 % |
| Permutations (s) | 0.709 | 0.617 | **87 %** |
| Int. Matrix (s) | 0.479 | 0.598 | 125 % |
| Sieve (s) | 1.051 | 0.972 | 92 % |
| **Mix** | **1.778** | **1.899** | **94 %** |

## FPU Benchmarks (Quadra 650 = 1.0)

| test | MiSTer | real Q800 | speed |
|---|---|---|---|
| KWhetstones/sec (FPU) | 3854.99 | 5456.61 | **71 %** |
| Matrix Mult. (s) | 1.025 | 0.713 | **70 %** |
| Fast Fourier (s) | 0.454 | 0.288 | **63 %** |
| **Average** | **0.687** | **1.011** | **68 %** |

## Color Benchmarks

| test | MiSTer | real Q800 | speed |
|---|---|---|---|
| Eight bit (s) | 13.967 | 8.211 | **59 %** |
| Monochrome, 2 and 4 bit | not run (the dialog needs mouse clicks) | 5.264 / 5.957 / 6.772 | |
| Sixteen bit | not available (the core has no 16 bpp mode) | 10.239 | |

## Performance Rating

| | MiSTer | real Q800 |
|---|---|---|
| CPU | 0.895 | 1.186 |
| Graphics | 1.031 | 1.347 |
| Disk | 1.595 | 3.443 |
| Math | 20.942 | 20.011 |
| **PR** | **1.152** | **1.605** |

## Where the distance is

1. **Graphics (8-bit QuickDraw 59 %)** is the largest gap, and it is not
   CPU-bound: the CPU Mix is at 94 %.  The likely cause is the VRAM path:
   uncached VRAM reads through the platform, and how posted VRAM writes
   and reads interleave in the store buffer.  It needs a profile of a
   QuickDraw blit before any change.
2. **The FPU (68 %)** is the iterative FPU's per-instruction latency (FMUL,
   FDIV, FADD) against the 040's pipelined FPU.  Whetstone in the Mix (91 %)
   hides this because it is dominated by memory traffic.
3. **Dhrystone (78 %), Queens, Permutations, Bubble** are the integer
   paths P243 slowed (the lookahead now waits a cycle after a memory
   operand).
4. **Disk (46 %)**: Main's per-sector round trip and the ~4.9 MB/s link.

Evidence: `scratch/hw_s24/` (`run*_table.png`, `fpu_done.png`,
`color_done.png`, `pr_done.png`).
