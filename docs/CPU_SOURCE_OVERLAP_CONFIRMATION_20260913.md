# Source-overlap hardware confirmation

Fresh three-run confirmation closes the modal-navigation audit. Accepted CPU
SHA256 `0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`
(AP commit `7a0306c`), exact RBF SHA256
`cf700b23e84fb9a1ca36fee0a2a7b8406436c4dbca04a67fd9fdf62c2d4e7011`.
Fit identities and retained artifact: `CPU_SOURCE_OVERLAP_CHECKPOINT_20260913.md`
and `scratch/candidate_cpu_operand_source_seed24/`.

Speedometer 4.02 all ten CPU Mix tests, one iteration, CD-ROM off. Each start
was preceded by visual setup verification and each completed capture by a
140-second quiet wait. Repeats explicitly dismissed the previous completion
modal before opening setup. All three final screenshots show fresh completion
alerts. Parent viewed the screenshots, not merely the tester's transcription.

| Test | Fresh 1 | Fresh 2 | Fresh 3 |
| --- | ---: | ---: | ---: |
| KWhetstones/sec | 358.314 | 359.277 | 359.559 |
| Dhrystones/sec | 5158.092 | 5159.995 | 5159.764 |
| Towers seconds | 1.968 | 1.968 | 1.967 |
| Quick Sort seconds | 1.358 | 1.356 | 1.356 |
| Bubble Sort seconds | 1.743 | 1.743 | 1.743 |
| Queens seconds | 1.115 | 1.116 | 1.115 |
| Puzzle seconds | 3.072 | 3.073 | 3.075 |
| Permutations seconds | 3.101 | 3.101 | 3.101 |
| Integer Matrix seconds | 2.208 | 2.185 | 2.207 |
| Sieve seconds | 3.106 | 3.104 | 3.103 |
| CPU Mix | **0.458** | **0.459** | **0.459** |

Mean **0.458666667**, **+1.85048%** versus indexed-stage mean 0.450333333.
The tester initially transcribed fresh run 2 as 0.458; parent corrected it
from the image. The previous 0.459333333 mean is superseded: its third repeat
was not established as independent and is excluded, not pooled with this set.

Evidence: `scratch/perf_operand_source_confirm_20260913/`.
Completed screenshots `run1_completed.png`, `run2_completed.png`,
`run3_completed.png`, SHA256 respectively:

- `3b295100f78478fe35bfce5d66fe0efb3d5c5eaba8d957deaab7ee2eb6a0ad8b`
- `e67ce7b0fc073f2f5bbb1c4a6304351e75cfba9c6b5a3ff69a710dbd6f2444f7`
- `b519aa6ca0e25db3bbdc4898eafb1902be0da0e94a8b2e58a69e6330d57d0a3b`

Completion capture identifiers: `20260913_130432`, `20260913_130752`,
`20260913_131057`. Setup evidence: `setup_ready.png`, `setup2.png`,
`setup3.png`. These are capture identifiers, not measured benchmark runtimes.

Guarded deployment and restoration returned exit 0. After Luna released
ownership, parent independently verified MENU, Main PID 17849, Main MD5
`dfb5937ba47720c3ae20abc8f381c462` and restored disposable MD5
`16790b0577e13b45782214433d34954b`. No Main or golden-image replacement.

This supports accepting source-only overlap. It does not prove the previously
observed intermittent guest stopwatch anomaly is fixed. New experimental CPU
variants still require their own correctness, timing and hardware gates.
