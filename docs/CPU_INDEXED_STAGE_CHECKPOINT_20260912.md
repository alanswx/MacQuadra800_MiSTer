# Indexed-address staging checkpoint

Speedometer 4.02 CPU Mix, all ten tests at one iteration, fresh disposable disk:
**0.450 / 0.451 / 0.450**, mean **0.450333**, versus compact **0.447 / 0.447 /
0.447**: **+0.7457%**. Parent independently viewed all three completion images.
This is a modest measured gain, not the approximately 3.3% standalone Sieve gain
and not evidence that the longer-term 1.9 target is close.

The tested CPU source is adopted in the working tree, uncommitted. Active QSF
is deliberately unchanged: this benchmark artifact is the isolated **CD-ROM-off,
seed-24** build, not a claim of a new full-feature fit. The prior accepted RBF
is preserved as a fallback. No commits or pushes were made in this iteration.

## Source and artifact

- CPU SHA256: `16fc1cc1f7f7e4295cbacf6c5449f2aa485d72290f27d75a3af687a2c7c8c79e`.
- Baseline CPU SHA256: `5ab7603019ab43ffb10bcdc5ef80086d2b0a5b515abd7fdd64d9adfaf0d0f3ff`.
- RBF SHA256: `9a73e863005afe62d0e1b7137fa1c1dfb675f382238804a4d1eb31d248b87080`.
- Preserved RBF/reports: `scratch/candidate_cpu_indexedstage_seed24/`.
- Build tree: `/tmp/MacQuadra800_indexed_seed24.l7hbbS`.
- Remote: `/media/fat/_Unstable/MacQuadra800_CPU_indexedstage_CDoff_seed24_20260912.rbf`.
- QSF SHA256: `81cb18081df01d55271185855e01a01a94f20aff8e9919f0b235b316bf45d1cb`.
- Fit: 38,027 ALMs, 4,117/4,191 LABs (74 free), 24,336 registers,
  462 RAM blocks, 3,446,620 RAM bits, 41 DSPs.
- Setup: CPU +0.724 ns, SDRAM +0.187 ns, HDMI +0.318 ns; worst hold +0.246 ns.
  All timing-summary slacks nonnegative, all TNS zero. Seed 23 was rejected
  for HDMI setup -0.173 ns and was never deployed.

## What changed and what passed

The last indexed extension-word consumption also captures the existing index
read-port selection, extension and base bookkeeping, then enters the original
arithmetic stage. Pending register/stack writes keep the old stage. No new EA
adder, speculative data access, cache protocol or full-format arithmetic is added.
The earlier refill experiment is not included.

Local candidate gates passed with actual exit zero: all eleven CPU suites,
directed indexed formats and pending-write fallback (also checked on baseline),
full-machine build, immutable 100-record corpus (34,742,942 cycles; 1,900 matching
field groups; zero real differences), and unchanged focused loops across three
phases (109,010 / 109,788 / 109,788). The original full-100 Sieve completes both
calls with D6=100, D7=1899 and every array/guard check passing: 92,976,362 cold,
92,976,214 repeat, versus 96,114,461 / 96,114,314 compact.

First-pass alignment testing improves 15/16 placements, unchanged at one,
regresses none. Actual CPU/store-buffer/SDRAM integration saves 3.46% at offset
0 and 2.69% at offset 6. Instrumentation proves that 8,191 earlier source reads
coincide with instruction ACK and therefore lose early data issue; the safe
handoff absorbs part of the deleted stage. This is why removed state occupancy
must not be treated as guaranteed end-to-end savings.

Details, reusable fixtures and exact patch:
[candidate handoff](checkpoints/CPU_INDEXED_STAGE_HANDOFF_20260912.md),
[RAM-path profiling](EXACT_SIEVE_INTEGRATION.md).
Final active-tree checks after adoption are tracked below separately.

Final correct-checkout active gates pass with actual exit zero: all eleven CPU
suites; immutable corpus 34,742,942 cycles, 1,900 matching field groups, zero
real differences (`/tmp/cpu-corpus100-gate.u98JRW`); full-machine Verilator build.
Parent verified the core SHA256 and complete RTL-directory equality with the
tested isolated candidate. Active Vemu SHA256:
`82b4973144a1698fec0999d911a0b2b9aaefe81ee531958ce1fe9b30921f3fa5`.
Parent and AP whitespace checks also pass. These checks use the current
`/home/alans/mister/MacQuadra800_MiSTer` checkout, not the old default directory.
An earlier final-gate invocation accidentally used the old checkout and was
discarded when its source hash/cycle count differed; mandatory preflight path
and hash assertions were added to the test workflow before this successful rerun.

## Hardware observations

| Absolute result | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: |
| KWhetstones/sec | 355.148 | 356.486 | 356.272 |
| Dhrystones/sec | 5084.058 | 5085.803 | 5084.450 |
| Towers (sec) | 1.997 | 1.997 | 1.997 |
| Quick Sort (sec) | 1.384 | 1.382 | 1.384 |
| Bubble Sort (sec) | 1.754 | 1.754 | 1.754 |
| Queens (sec) | 1.128 | 1.154 | 1.154 |
| Puzzle (sec) | 3.321 | 3.321 | 3.321 |
| Permutations (sec) | 3.124 | 3.125 | 3.125 |
| Integer Matrix (sec) | 2.305 | 2.281 | 2.307 |
| Sieve (sec) | 3.107 | 3.107 | 3.100 |
| Average ratio (higher is faster) | 0.450 | 0.451 | 0.450 |

Run Set start times reported by the tester (America/Toronto): 16:01:28,
16:06:11, 16:09:31. The prescribed quiet interval was at least 135 seconds.
Tester reports 140-second quiet waits; completion captures were 16:05:11,
16:08:42 and 16:12:13. Guard restoration restarted Main PID 24720 -> 25124.
No negative/impossible times appeared in these three results; the historical
intermittent stopwatch anomaly is not declared fixed by these runs.

Images: `scratch/perf_indexedstage_cdoff_seed24/run{1,2,3}.png`.
SHA256 in order:

```text
fbfd95110f2accb8d40dd03714a71f32276d032fde9d2435a2b472ac250735b1
d4aa23dcc21dd79061439f9126849677c54ffa55428881b478e0e07c1c0db2d8
07457ec9695618151d3dd67ff8bc823f692f6521861ffa1a18cefc40fb3cdf2d
```

Guarded cleanup completed. Parent independently verified MENU, Main PID 25124,
unchanged Main MD5 `dfb5937ba47720c3ae20abc8f381c462`, matching golden/disposable
MD5 `16790b0577e13b45782214433d34954b`, and the remote RBF SHA256 above.

## Next measured work

Start extension requests earlier at the two operand EA callers, while retaining
the current read-port settling, pending-write fallback, extension ownership and
fault behavior. Do not simply relax request/ACK ownership guards. Test all code
placements and real RAM-path timing again before spending another FPGA fit.
Broader operand overlap still needs a precise forwarding/retirement contract;
small state removals alone will not reach the real-040 target.

The full-ROM profiler was separately unblocked by a simulator-only first-word
disk-transfer fix. It now reaches Mac OS startup; a full Speedometer application
interval has not yet been captured. See
[simulator diagnostic](checkpoints/CPU_SIM_BOOT_PROFILE_20260912.md).
