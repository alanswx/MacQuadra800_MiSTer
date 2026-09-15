# Trimmed core Speedometer result, 2026-09-13

Candidate and fit identities: `CPU_TRIM_HARDWARE_RETRY_20260913.md`.
Luna deployed through the unchanged lifecycle guard, with corrected `_Unstable`
target. Dry-run and deployment returned exit 0. CPU remained accepted source-only.

## Results: incomplete validation, not an accepted three-run mean

All ten Speedometer 4.02 CPU Mix tests selected, one iteration. Each set was
started separately after visually checking setup; completion alerts were
dismissed before reopening setup. Luna reports 140-second quiet intervals.
Parent independently viewed all three completion screenshots and setup 1/3.

| Test | Run 1 | Run 2 | Run 3 (INVALID) |
| --- | ---: | ---: | ---: |
| KWhetstones/sec | 362.680 | 363.868 | 363.720 |
| Dhrystones/sec | 5200.261 | 5200.860 | 13040.074 |
| Towers (sec) | 1.951 | 1.951 | -17070.000 |
| Quick Sort (sec) | 1.346 | 1.345 | 0.005 |
| Bubble Sort (sec) | 1.729 | 1.729 | 0.011 |
| Queens (sec) | 1.107 | 1.106 | 0.018 |
| Puzzle (sec) | 3.045 | 3.045 | -31407.000 |
| Permutations (sec) | 3.077 | 3.076 | 0.062 |
| Integer Matrix (sec) | 2.186 | 2.162 | -72891.000 |
| Sieve (sec) | 3.080 | 3.075 | -25223.000 |
| Displayed average | 0.463 | 0.464 | 11.091 (excluded) |

Prior accepted baseline: 0.458/0.459/0.459, mean 0.458666667.
The two plausible results do not establish anomaly-free validation or justify
averaging away the invalid third result. No CPU speedup is accepted here.

Evidence: `scratch/perf_features_seed24_20260913/`.
Capture archive timestamps: run 1 `20260913_194618`, run 2 `20260913_194931`,
run 3 `20260913_195245`. Local setup 2 mtime 15:47:02 and setup 3 15:50:15.
Exact start timestamps were not provided in Luna's final report; the reported
quiet intervals are not independently reconstructed from image timestamps.

Screenshot SHA256:

- Run 1: `91680dc4480dbe5935f2f1a9fd86846ace24541a1cee888cd01811873edc3f10`
- Run 2: `1c9975b8642a93a754b831bd9e3528c82cdc6e466039d178b6236565812ce227`
- Run 3: `9a1488197647575c543e3454c0b6a802add22ea7f27e2ca0b9f01b4685fb7666`

Guarded restore returned exit 0; MENU confirmed, disposable MD5 restored to
`16790b0577e13b45782214433d34954b`, Main MD5 unchanged
`dfb5937ba47720c3ae20abc8f381c462`. Slot remained the specified disposable.
Luna released FPGA ownership. No additional runs were used to hide the anomaly.

## Interpretation and next action

`CPU_VALIDATION_UPDATE_20260912.md` records the same symptom on the older
accepted register-dispatch control (two plausible runs, then an invalid third).
This predates the peripheral trim but does not establish the present cause.
See `SPEEDOMETER_TIMING_DIAGNOSTIC.md` for the existing bounded timer-path plan.

The requested combined-overlap build is proceeding separately in
`/tmp/MacQuadra800_features_combined_seed24.8GkoTk`; only CPU core differs from
the trimmed source-only tree. CPU SHA256 is
`21d408fa9b2080e73957d6e64b641cc2758797895218a7639317b4ac04958700`.
Compilation is authorized, not deployment or adoption. Accepted CPU stays
unchanged; further hardware performance claims require resolving this gate.
