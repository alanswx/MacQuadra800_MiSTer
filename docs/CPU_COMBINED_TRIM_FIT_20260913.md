# Combined overlap with peripheral trim: successful fit

Full build finished with actual exit 0 in
`/tmp/MacQuadra800_features_combined_seed24.8GkoTk`.
Log: `output_files/build_20260913_155441.log`.
Preserved RBF, fit/STA summaries and log:
`scratch/candidate_cpu_features_combined_seed24/`.

- CPU SHA256: `21d408fa9b2080e73957d6e64b641cc2758797895218a7639317b4ac04958700`
- QSF SHA256: `f8b1b0c97b9674eab56a86058382bfd7dbf1601513eaa7c6219ac640a2a6665d`
- RBF SHA256: `6b7aaa90b712fe845858016d9e15cb35bc1da3e5b8d5ec562d3478a141bdd2a6`

The only source change from the successful trimmed source-only build is the
preserved combined CPU. Seed 24, clocks, constraints and feature profile match.

| Fitted resource | Trim/source-only | Trim/combined |
| --- | ---: | ---: |
| ALMs | 36,538 | 36,616 |
| Occupied LABs / 4,191 | 4,061 | 4,072 |
| Free LABs | 130 | 119 |
| Registers | 23,046 | 23,052 |
| RAM blocks | 459 | 459 |
| Memory bits | 3,435,654 | 3,435,654 |
| DSP blocks | 31 | 31 |

Combined minimum reported setup slack +0.394 ns, hold +0.235 ns,
recovery +3.791 ns, removal +0.933 ns, pulse width +0.505 ns.
Reported TNS values are zero. Existing unconstrained setup/hold warnings
remain; these reports do not validate unconstrained paths.

This retry routes successfully where the earlier untrimmed combined seed-24
build failed. It does not establish which removed module relieved congestion.
The accepted source-only CPU in the active repository remains unchanged.

## Hardware validation

User subsequently authorized continuing. Luna owns the experimental hardware
test through the lifecycle guard, with unique remote target
`/media/fat/_Unstable/MacQuadra800_features_combined_seed24_20260913.rbf`.
Evidence directory: `scratch/perf_features_combined_seed24_20260913`.
Use up to three independently started Speedometer 4.02 all-ten CPU Mix sets,
one iteration each; stop further sets on any impossible timing result.

Same-trim source-only observations were 0.463/0.464/INVALID; they are not an
accepted three-run baseline. Earlier untrimmed accepted mean was 0.458666667.
The recurring negative-timing anomaly predates these feature removals and
remains unresolved. No invalid result may be averaged away, and passing
hardware samples alone cannot establish that this intermittent issue is fixed.
See `CPU_TRIM_SPEEDOMETER_20260913.md` and `SPEEDOMETER_TIMING_DIAGNOSTIC.md`.

Hardware results and guarded post-test restoration are pending at this writing.
