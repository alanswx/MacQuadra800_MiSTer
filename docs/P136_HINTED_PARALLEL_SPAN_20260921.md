# P136 hinted parallel spanning reads

Unqualified isolated prototype over P135. Cache SHA256 `654b8750cdafcb19235367b8e7f5ddab8f2d5b8a4896d15b0cd2b53750ec58ba`; snapshot `scratch/p136_hinted_parallel_span_20260921/ap040_cache.v`. The unapplied `scripts/cpu/hinted_parallel_span.patch` reproduces the change over P135.

P135's idle pair path uses the live translated address/tag. P136 instead uses the existing qualified data-hint admission conditions, registered hint lane and hint way selection to choose both words. The first C_LOOK pair path remains unchanged. This is intended to reduce dependence on the live MMU path, but no timing improvement is established without a fit. Restricting idle admission to vouched hints may reduce performance compared with P135.

Original workload screens completed with explicit P109 core/P120 pipeline and latency 3:

| Workload | P135 loop clocks | P136 loop clocks | P136 returned clocks |
|---|---:|---:|---:|
| Whetstone | 26,382,413 | 26,243,771 | 26,244,399 |
| Dhrystone | 107,504,277 | 107,504,306 | 107,505,196 |

Whetstone saves 138,642 clocks (0.526%); Dhrystone adds 29 clocks. Root independently matched all eight captures and every non-cache source/fixture/ROM/flag/latency identity to P135. The independent 50,000-iteration Dhrystone end-state checker passes. Evidence: `scratch/{whetstone,dhrystone}_full_p136_20260921`. No hardware speed or timing improvement is claimed.

Full CPU/IRQ integration is root-verified: all 22 programs and 4 interrupt cases pass; accounting balances; each IRQ has 3 injections with at least 3 killed entries; store/PEA cases make exactly 3 stores; handoff/reference traces match; every source hash matches. Evidence: `scratch/p136_full_integration_20260921/root_audit.txt`. Hint rejection/fault/snoop/CE tests, mirror-array correctness, RAM inference, timing and hardware validation remain required. Production sources remain frozen for P130 seed 24.

## Directed qualification

Root inspected the final hint bench and accepted logs: actual qualified idle8/lookup2 acknowledgements, two rejected hint/lane cases, an external bus fault, a real snoop, three paused C_LOOK clocks, and a four-way fast-hit mask0xF. Explicit pair reads after byte/word writes include the changed bytes and require actual hinted-path acceptance. The external model now merges big-endian partial stores. Final bench SHA256105faaf92c803afcc6cfbde2bf79b1ecec6165cdf33cdaaeabdd96330acfdd65. Root also checked passing P135-aware exact-span/no-gap, snoop, XSTORE100 and posted216 terminal logs.

Reproduction is preserved in `scripts/cpu/hinted_parallel_span_checks.patch` and `.md`; patches remain unapplied during the live fit. Together with the independently verified original workload outputs and full CPU/IRQ integration, this qualifies P136 for FPGA evaluation. RAM inference, area, timing and hardware speed remain unverified.

## Prepared FPGA evaluation

The next cache evaluation is planned with P109 core/P120 pipeline/P136 cache, seed24, CDROM_OFF and ETHERNET_OFF. This keeps the CPU core unchanged to measure the cache change before the separate P137 decoder improvement. `scripts/cpu/fit_hinted_parallel_span.sh` preserves the reviewed current-checkout recipe: it requires deliberate source promotion and exact hashes, refuses concurrent Quartus, records all tracked HDL/QSF/QIP/SDC identities before and after the full wrapper, archives only fresh reports/RBF, and runs STA only when a fresh successful fitter summary exists. Failed fits explicitly skip timing analysis instead of reading an old database.

The recipe is prepared, not launched. P130 seed24 still owns the checkout and database; its entire wrapper must terminate before source promotion or any next flow. The staged P136 cache patch is `scratch/p136_hinted_parallel_span_fit_20260921/p136_over_p130.patch`; the tracked constituent patches also reproduce it.

Promoted the exact qualified P136 cache for a seed-24 FPGA evaluation after P130 seed24 routing failed and the entire previous wrapper ended. Production CPU remains P109 and pipeline P120, isolating cache performance from P137/P141 CPU changes. The reviewed `scripts/cpu/fit_hinted_parallel_span.sh` records fresh reports, RAM inference, timing and complete-flow source hashes. No FPGA or hardware result yet.

Fit launched from commit `65440d0` under `q800-p136-hinted-parallel-span-fit-20260921.service`, wrapper PID 424301 / Quartus flow 424351 / mapper 424413. Root verified live processes. Archive `scratch/p136_hinted_parallel_span_fit_20260921`; tracked HDL/QSF/QIP/SDC frozen through full wrapper termination.
