# The FPU benchmark: the time goes to cache refills after Mac OS's flushes (2026-09-27)

Hardware, build `faf9d98` (seed 21) on the write-buffer Main: FPU average
**0.690** (KWhetstones 3864.6, Matrix Mult 1.017 s, Fast Fourier 0.454 s);
the real Quadra 800 scores 1.011.  Color 8-bit 9.879 s, PR 1.203.

## Profile (full-machine sim, Speedometer FPU Benchmarks, Cmd-F)

The sim scores 0.668 (hardware 0.690), so it is a fair model.
`docs/perf/fpu_profile_20260927/` has the profile and the control stream.

- The cache is in **C_FILL 41 %** of the profiled clocks.  There are 15.6 M
  data-line and 19.7 M instruction-line fills, ~15 clocks each.  S_MRD is
  34 % of all clocks, 236 M of them with the cache filling.
- The fills follow **cache flushes by Mac OS**:
  - **23,909 CPUSHA (both caches)** at ROM `$40885032`, reached through the
    `jCacheFlush` vector (`$6F4`) from the Memory Manager at `$40887800`.
    That code sets a block's lock bit and, when CPUFlag (`$12F`) is 4 (a
    68040), flushes both caches.  It is **HLock** (A029: 23,551 calls; HUnlock
    A02A 23,497).  A real Quadra runs the same flushes.
  - **48,937 CPUSHL (both caches)** at RAM `$0009AD6E` (a System patch).
- The FPU's own arithmetic is not the limit: FMUL is a single-cycle 64x64
  multiply, and FDIV/FSQRT produce three bits a clock.

## What was tried

| change | sim | hardware | verdict |
|---|---|---|---|
| CPU caches 16+16 KB (`SETW = 8`) | Color 10.264 -> 10.140 s | -- | not worth it: fits miss by 2 ns or fail to route |
| ROM line into the cache's line-fill port | Color -1 %, FPU unchanged | -- | reverted |
| **P246**: CINVL/CPUSHL invalidate only their line's set (the core cleared the whole selected caches for every scope) | FPU unchanged | FPU 0.688, Mix 1.786/1.786/1.777 | reverted; no gain (`p246_cpushl_line_REJECTED.diff`) |

Seed 21 of P246 met timing (CPU +0.461, HDMI +0.078, SDRAM +0.931).  One of
its four hardware Mix runs showed the project's known intermittent **timer
anomaly** (Permutations 0.480 s and Int. Matrix 0.006 s, aggregate 15.728:
`v9_run2_timer_anomaly.png`).  Earlier builds logged the same pattern
("Towers 0.140", "Int. Matrix 0.521 s and Sieve 0.024 s").  It is not specific
to P246.

## Where the FPU gap is

The 24k whole-cache flushes from HLock force the refills.  What is left:
- faster line fills (a real 68040 bursts a line in ~5-6 clocks, ours takes
  ~15);
- a cheaper CPUSHA for the data cache.  It is write-through and DMA-snooped,
  so a push has nothing to write back, and dropping its invalidate is
  coherence-safe only if every RAM writer is snooped.  The MMU table walker's
  U/M-bit writes are not snooped today, and A/UX relies on those bits, so
  this needs care.
