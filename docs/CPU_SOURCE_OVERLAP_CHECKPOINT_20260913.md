# Source-operand overlap checkpoint — repeat audit pending

**2026-09-13 correction:** the reported third valid run (run 4) is not
established as independent. Run 3 still showed its completion modal; the next
command sent Command-B then Return without first dismissing that modal.
The identical run-4 table without a modal is consistent with dismissal only.
Exclude run 4 and the three-run mean below pending fresh controlled repeats.
Runs 1 and 3 remain observed 0.458 and 0.460. The code is committed and
architectural gates pass, but three-run hardware acceptance is reopened.
Luna is running a fresh set with an explicit modal dismissal and visual setup
verification before every timed start. Historical claims below are superseded.

Accepted 2026-09-13 after hardware testing on September 12. Supersedes the
indexed-stage checkpoint; both optimizations are included. Destination overlap
remains experimental because it regresses one measured code placement.

## Hardware evidence

Speedometer 4.02, all ten CPU Mix tests, one iteration each, CD-ROM disabled.
Parent independently viewed all three completed screenshots.

| Test | Run 1 | Run 3 | Run 4 |
| --- | ---: | ---: | ---: |
| KWhetstones/sec | 358.114 | 359.635 | 359.635 |
| Dhrystones/sec | 5158.863 | 5159.904 | 5159.904 |
| Towers seconds | 1.968 | 1.967 | 1.967 |
| Quick Sort seconds | 1.358 | 1.355 | 1.355 |
| Bubble Sort seconds | 1.743 | 1.743 | 1.743 |
| Queens seconds | 1.115 | 1.116 | 1.116 |
| Puzzle seconds | 3.072 | 3.071 | 3.071 |
| Permutations seconds | 3.101 | 3.101 | 3.101 |
| Integer Matrix seconds | 2.208 | 2.184 | 2.184 |
| Sieve seconds | 3.106 | 3.102 | 3.102 |
| CPU Mix | 0.458 | 0.460 | 0.460 |

Mean 0.459333333 versus indexed-stage 0.450333333: **+1.99852%**.
Run 2 was perturbed by Return without reopening setup and is excluded.
Identical displayed values in runs 3/4 are retained as reported repeats;
screenshots alone do not establish their timing history. Luna reports distinct
completed runs with the required quiet intervals. Intermittent invalid guest
stopwatch results remain an open issue, not proven fixed by coherent runs.

Evidence: `scratch/perf_operand_source_cdoff_seed24/run{1,3,4}_completed.png`.
Screenshot MD5s, respectively:

- `3c1666f37c09af97398c138928ac3df4`
- `d52a6d0d0897c3cbd869a4f440eaf173`
- `4a4569d71d4d7cbd8851e294731291e8`

## Exact build and resource identity

- CPU SHA256: `0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`.
- RBF SHA256: `cf700b23e84fb9a1ca36fee0a2a7b8406436c4dbca04a67fd9fdf62c2d4e7011`.
- Build: `/tmp/MacQuadra800_operand_source_seed24.zXuurP`.
- RBF: `output_files/MacQuadra800.rbf`, 4,428,012 bytes.
- Log: `output_files/build_20260912_215252.log`; actual Quartus exit 0,
  elapsed 14m32s; fit, assembler, and timing analysis successful.
- Configuration: CD-ROM off, seed 24; QSF SHA256
  `81cb18081df01d55271185855e01a01a94f20aff8e9919f0b235b316bf45d1cb`.
- 38,003 ALMs, 4,093/4,191 LABs (98 free), 24,348 registers,
  462 RAM blocks, 3,446,620 memory bits, 41 DSP blocks.
- Relative to indexed-stage: 24 fewer ALMs and 24 fewer LABs.
- Setup slack: CPU +0.648 ns, SDRAM +0.480 ns, HDMI +0.163 ns.
  Worst hold +0.246 ns; all reported TNS zero. Existing unconstrained-path
  warnings remain; passing constrained timing is not proof of full coverage.
- Remote: `/media/fat/_Unstable/MacQuadra800_CPU_operand_source_CDoff_seed24_20260912.rbf`.

Active project QSF is unchanged: this does not establish a full-feature fit.
The selected source-only patch is relative to indexed-stage SHA `16fc1cc1...`.
See `CPU_OPERAND_OVERLAP_20260912.md` for simulation gates, exact patch identity,
all sixteen RAM-path alignments, and the rejected destination-overlap results.

## Cleanup and next step

Luna reports guarded deployment and restoration completed. Parent independently
verified MENU, one running Main PID 3025, unchanged Main MD5
`dfb5937ba47720c3ae20abc8f381c462`, restored disposable MD5
`16790b0577e13b45782214433d34954b`, and the remote RBF SHA above.
No Main replacement, no golden-image change; FPGA ownership released.

Next: measure the actual arriving instruction's eligibility for direct decode
at register-ALU retirement. Reuse the shared decoder only with a descriptor
matching that instruction, preserving queue append/pop, faults, flushes,
interrupts/trace, CE, and register/CCR forwarding. Keep experiments isolated;
run architectural/fault gates, alignment comparisons, fit/timing and hardware
repeats before adoption. Do not enable destination overlap merely because its
average cycle count improves. The 1.9 target still needs roughly 4.14x this score.
