# Combined trimmed CPU hardware: not adopted

RBF SHA256 `6b7aaa90b712fe845858016d9e15cb35bc1da3e5b8d5ec562d3478a141bdd2a6`;
CPU `21d408fa...`. Fit and source identities: `CPU_COMBINED_TRIM_FIT_20260913.md`.
Luna's guarded dry-run/deploy returned exit 0. The accepted active CPU remains
unchanged. This experiment is not adopted as a performance improvement.

## Speedometer 4.02 CPU Mix

All ten tests, one iteration, independent setup/start per run. Parent viewed
setup 1 and all three completed screenshots. Luna reports fresh setup checks
and 140-second quiet intervals. Exact start timestamps were requested but not
included in its final report; capture timestamps alone do not prove duration.

| Test | Run 1 | Run 2 | Run 3 (INVALID) |
| --- | ---: | ---: | ---: |
| KWhetstones/sec | 360.697 | 361.886 | 0.232 |
| Dhrystones/sec | 5181.678 | 5181.808 | 2147483.647 |
| Towers (sec) | 1.953 | 1.953 | -16311.000 |
| Quick Sort (sec) | 1.348 | 1.346 | 0.007 |
| Bubble Sort (sec) | 1.732 | 1.732 | 0.014 |
| Queens (sec) | 1.109 | 1.110 | 0.020 |
| Puzzle (sec) | 3.069 | 3.069 | -8387.000 |
| Permutations (sec) | 3.093 | 3.093 | -7711.000 |
| Integer Matrix (sec) | 2.207 | 2.182 | -54125.000 |
| Sieve (sec) | 3.127 | 3.123 | -63026.000 |
| Displayed average | 0.460 | 0.461 | 9.212 (excluded) |

The plausible first two scores are below same-trim source-only 0.463/0.464.
Neither sequence establishes an accepted three-run mean: both third runs
are invalid. No invalid result is averaged away. The simulation gains did
not translate into a demonstrated hardware gain in this experiment.
The intermittent invalid-timing symptom also predates both trim and combined
overlap; its cause is unresolved, not attributed to this CPU change.

## Evidence and cleanup

Directory: `scratch/perf_features_combined_seed24_20260913/`.
Setup 1 capture: `20260913_215809-screen.png`.

| Screenshot | Capture timestamp | SHA256 |
| --- | --- | --- |
| run1_completed.png | 20260913_220052 | 8aa35bc09d1ed76db0d8fa36d6d595e80a871c85199d7f98264d64bf12096ab4 |
| run2_completed.png | 20260913_220412 | ab3aea977d982b194d2d1a70551d71140a3acf739b2a7c60eebe1ba2388143f7 |
| run3_completed.png | 20260913_220730 | b4ef58b2b2232aa3552434dde7cd44f8530592619668b6199a6b010e97ef0083 |

Parent corrected Luna's shifted run-3 Queens/Puzzle/Permutations labels by
viewing the image. No further runs after the first impossible result.
Guarded restore exit 0; MENU verified, Main MD5 unchanged
`dfb5937ba47720c3ae20abc8f381c462`, disposable restored MD5
`16790b0577e13b45782214433d34954b`; slot unchanged. FPGA ownership released.

## Next gate

Prioritize bounded simulator timer-return/subtraction/aggregation observation
as described in `SPEEDOMETER_TIMING_DIAGNOSTIC.md`. An isolated host-only
observer is under development at `/tmp/speedometer-timing-observer.0z4YdU`;
its tests and adapter compile remain pending. No guest anomaly reproduction
or timer/CPU fix is claimed. Avoid further blind repeats or speculative fixes.
