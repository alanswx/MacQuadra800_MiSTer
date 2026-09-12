# Compact shared-decode CPU checkpoint

2026-09-12: active working-tree CPU adopted after three coherent hardware runs.
Not committed or pushed. This is a **CDROM_OFF=1 development build**, not a
full-feature release. The active full-feature QSF was not changed.

## Verified hardware result

Speedometer 4.02, all ten CPU Mix tests, one iteration, quiet intervals of at
least 135 seconds. Parent visually verified all three tables. Run 2's initial
local download was missing; recovered the exact existing capture
`MacQuadra800/20260912_152052-screen.png` from MiSTer's archive after cleanup.
It was not substituted with a new run or a current Menu screenshot.

| Test | Run 1 | Run 2 | Run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 355.267 | 356.320 | 356.505 |
| Dhrystones/sec | 5078.447 | 5079.116 | 5078.409 |
| Towers (sec) | 2.019 | 2.019 | 2.019 |
| Quick Sort (sec) | 1.403 | 1.402 | 1.402 |
| Bubble Sort (sec) | 1.764 | 1.764 | 1.764 |
| Queens (sec) | 1.138 | 1.137 | 1.138 |
| Puzzle (sec) | 3.371 | 3.372 | 3.376 |
| Permutations (sec) | 3.153 | 3.154 | 3.154 |
| Integer Matrix (sec) | 2.348 | 2.346 | 2.348 |
| Sieve (sec) | 3.159 | 3.155 | 3.156 |
| CPU Mix average | **0.447** | **0.447** | **0.447** |

Mean 0.447: +2.87687% versus the 0.4345 register-dispatch checkpoint;
+10.37037% versus the full-feature 0.405 reference. Still far from the 1.9 target.
The smaller memory-ALU predecessor's coherent mean was 0.4395.

Screenshots under `scratch/perf_sharedcompact_cdoff_seed23/`:

- `run1.png`: `4f54ca10d29b546d1803e162c4156ff2c109609c6555a136251427b176bbbbb1`
- `run2_recovered.png`: `9ac38dc9fb231d67102e1d58aa3279c15870a2999957558194103de41ca9a774`
- `run3.png`: `61b29a4794f48c4519f7afa0e34f584c2e373f079ccced77a868bd9be3100bf7`

The broader timing anomaly remains unresolved: earlier and control builds
produced impossible values, as did the first two runs of the larger prototype.
None of those invalid averages counts. These three compact runs are coherent;
that does not establish that the intermittent defect is fixed.

## Area, timing and artifacts

Seed 23: 37,959 ALMs; 4,111/4,191 LABs (80 free); 24,355 registers;
462 RAM blocks / 3,446,620 memory bits; 41 DSPs. Versus register dispatch:
**171 fewer ALMs and 13 fewer occupied LABs**. Versus the first shared-decode
prototype: 3,550 fewer ALMs and 79 fewer occupied LABs.

Worst setup +0.330 ns; CPU +0.827; SDRAM +0.792; worst hold +0.227.
All reported setup/hold/recovery/removal/pulse TNS zero. Seed 22 missed SDRAM
setup by 0.039 ns and was rejected; its RBF must not be deployed.

RBF SHA-256: `622667cace5c827770f8a7ec81d35e5b6bab3996e406eae18aaea9fbba4ead6f`.

- Remote: `/media/fat/_Unstable/MacQuadra800_CPU_sharedcompact_CDoff_seed23_20260912.rbf`
- Persistent local copy, QSF and summaries: `scratch/accepted_cpu_sharedcompact_seed23/`
- Original build: `/tmp/MacQuadra800_sharedcompact_seed23.Ln2cjL`

Main remained unchanged; final guarded cleanup verified MENU and restored the
disposable to golden MD5 `16790b0577e13b45782214433d34954b`.

## Source and verification

Parent base: `33aa273d59a86dfd7a2d7a7667ea8abd2398c6c7`.
AP base: `250813f4bcec4467807a754279124b042feeeb89`.
Full CPU/test recovery patch from that AP base:
`checkpoints/cpu-sharedcompact-accepted-20260912.patch`.

- Core SHA-256: `5ab7603019ab43ffb10bcdc5ef80086d2b0a5b515abd7fdd64d9adfaf0d0f3ff`
- Integer source: `62bf99a131332f304e9ae69ff0c5453c341f172f11d0ad3bfb0f0b3c62de572a`
- Integrated simulator source: `7ebbe53f5fdc70ce92fe3aa70b2c64a473743a6dfbb8928812111a5f062c53e6`

All eleven AP suites, full-machine compilation and first-100 corpus pass.
Corpus: 34,829,460 cycles, 1,900 matching field groups, zero REAL differences.
Focused loop: 109,788 versus 122,788 cycles (-10.59%). The original shared
prototype additionally matched 406 complete corpus records; that partial run
was not full-suite completion. Final active-tree verification also passes:
all eleven suites, full-machine build, both helper tests with warnings-as-errors.
Active Vemu SHA-256:
`531cd0b6722c96fd916b5f8dbba0dcfde1dff5503fb23b0e4dbfb211cc5ba222`.
This final rebuild includes the simulator-only missing-ROM fail-fast guard.
The missing-ROM negative test exits 1 with an explicit error; a valid explicit
ROM completes the bounded 1M-cycle smoke (not a full guest boot).
The screenshot helper also now checks download failure and nonempty output:
positive fresh capture exits 0; intentional directory-as-output failure exits
4 without reporting FRESH. These tooling checks do not alter CPU/RBF identity.
Parent independently rechecked final MENU, unchanged Main hash and restored
golden disposable hash after the tester released the machine.

## Next work

Use the unchanged Speedometer Sieve kernel with checked output and cycle
bracketing to profile integer execution independently of OS stopwatch failures.
The fixture is preserved in rtl/ap68040/tb and documented in
EXACT_SIEVE_PROFILING.md. Compact phase 0 passes both complete output checks;
all eleven ordinary AP suites also pass after adding its optional hooks
(`/tmp/active_ap040_final_fixture_tests.log`). This is a relative CPU-only
fixture, not a full-machine Speedometer replacement.
Then target the measured common EA/operand/cache-hit costs, not another narrow
register-opcode bypass. See CPU_PERFORMANCE_TASKS.md for the pipeline roadmap
and SPEEDOMETER_TIMING_DIAGNOSTIC.md for the separate timing investigation.
