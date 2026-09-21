# P136 hinted parallel spanning reads

Unqualified isolated prototype over P135. Cache SHA256 `654b8750cdafcb19235367b8e7f5ddab8f2d5b8a4896d15b0cd2b53750ec58ba`; snapshot `scratch/p136_hinted_parallel_span_20260921/ap040_cache.v`. The unapplied `scripts/cpu/hinted_parallel_span.patch` reproduces the change over P135.

P135's idle pair path uses the live translated address/tag. P136 instead uses the existing qualified data-hint admission conditions, registered hint lane and hint way selection to choose both words. The first C_LOOK pair path remains unchanged. This is intended to reduce dependence on the live MMU path, but no timing improvement is established without a fit. Restricting idle admission to vouched hints may reduce performance compared with P135.

Original Whetstone/Dhrystone screens are queued against P135's 26,382,413 and 107,504,277 loop clocks with explicit P109 core/P120 pipeline. All capture identities, hint rejection/fault/snoop/CE tests, mirror-array correctness, CPU/IRQ integration, RAM inference, timing and hardware validation remain required. Production sources remain frozen for P130 seed 24.
