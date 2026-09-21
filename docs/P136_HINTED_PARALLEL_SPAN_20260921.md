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
