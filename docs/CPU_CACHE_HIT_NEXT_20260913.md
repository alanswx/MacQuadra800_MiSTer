# Next experiment: registered cache-hit admission

User approved measuring internal cache-hit latency before choosing the next
optimization. Start from accepted source-only CPU `0c3a81bd...`, not the
combined-overlap candidate that failed to demonstrate a hardware gain.

## Established structure, not yet a performance result

The normal cache hit already uses parallel tag/data RAM reads:
`C_IDLE` admission/read, `C_LOOK` registered completion, then CPU consumption.
The instruction lookahead already avoids `C_LOOK` for its eligible accesses.
Do not describe this cache as an unoptimized three-stage tag-then-data lookup.
The MMU's ATC hit path and request admission must be measured with the cache;
the downstream acknowledgement must remain registered to avoid restoring the
previous long translation-to-CPU acknowledgement timing path.

Existing simulator `look_hit_cycles` counts a Boolean signal each sampled
cycle, not qualified completed hit transactions. It is not a cache hit rate.
Measure per-request latency with clear admission/completion boundaries,
separating translation, cache lookup, memory waits and CE pauses.

## Candidate to quantify

Cache set and word indexing use address bits within a page. A speculative
RAM read might overlap translation, allowing a registered hit completion at
admission once physical tag and permissions are valid. It must never answer
from an old idle address or bypass translation/protection checks.

First measure eligibility and saved-cycle bounds using the actual CPU/MMU/
cache integration, including TC-off, ATC hits/remaps, transparent translation,
cache-inhibited traffic, snoops, reset, errors and CE pauses. Also check RAM
read/write collisions and arbitration with instruction lookahead. Only then
prototype the limited registered fast path in an isolated tree. No production
cache change or speedup is claimed at this writing.

Focused simulation establishes mechanism and correctness, not MacOS workload
coverage or a Speedometer score. A gain must survive real workload profiling,
regressions, fit/timing review and hardware measurement before adoption.

## Timing diagnostic status

The bounded host-only timer observer is preserved in
`scripts/fixtures/speedometer_timing_observer/`. Synthetic tests and its
isolated full-machine adapter compilation passed. No timer fix is implied.
Luna is running a fresh disposable-disk guest probe with the original ROM,
bounded to 2,500,000,000 half-edges and 900 seconds; it was still in ROM memory
test at the latest observation. This is not yet an application timer capture.
An existing fastboot ROM must be explicitly selected and identified in a
separate run if needed; do not silently substitute ROMs or relabel boot data
as a benchmark profile. MiSTer is not used by this simulator work.
