# Real-integration cache-hit latency baseline

Accepted CPU `0c3a81bd...`; no optimized cache RTL in this measurement.
Fixture `/tmp/cache-hit-latency.ZBuCjk` uses the actual wombat_cpu, MMU,
cache and store buffer. Luna's bounded run passed, actual exit 0, completing
in 2,188 clocks. Transaction evidence is `run.log` in that directory.

| Data access | Observations | Request-to-consumption clocks | Shadow early-read eligibility |
| --- | ---: | ---: | ---: |
| Warm TC-off hit | 6 | 3 | 0 |
| Warm translated alias hit ($9000 to $4000) | 7 | 4 | 7 |
| Transparent-translation cacheable hit | 8 | 3 | 0 |
| Cache-inhibited pass | 8 | 5 | 0 |
| Cache-disabled pass | 8 | 5 | 0 |

The first translated access walks the tables and then hits the cache;
its shadow data also matches (8/8 translated data hits including this walk).
Clock-enable pause adds exactly three clocks. An injected snoop forces a
miss; an injected error and RTE restart pass the guest oracle.

Across this deliberately constructed diagnostic, 61 ordinary hits (53
instruction, eight data) meet shadow early-read criteria. This is not actual
Speedometer coverage and not 61 measured saved clocks: RTL is unchanged.
Instruction lookahead already consumes in two clocks TC-off or three with
translation and is not counted as a new opportunity.

## Prototype decision

Proceed in a separate tree with conservative registered completion at cache
admission only when a fresh prior RAM read matches the current request and
physical tag/permissions are fully qualified. Retain ordinary C_LOOK fallback
for every uncertain case, including incompatible early-read availability.
Keep completion registered and validate snoop/invalidate/write collisions,
instruction-lookahead arbitration, reset, CE and errors. No active CPU/cache
adoption, FPGA fit or Speedometer speedup is established by this fixture.

## Parallel timer-observer guest probe

Prepared simulator `84fb65a9...` was run on a fresh owned disk under
`/tmp/speedo-local-run-20260913`. First invocation exited 1 because a binary
ROM was passed where the model requires readmem hex; retry used the prepared
`quadra800.rom.hex`. Retry ran 19:28:04–19:43:04 local, ending with timeout
exit 124. Final logged progress was around 1.31 billion half-edges, beyond
the initial ROM memory test. No application timing trace was obtained.

No screenshots/navigation were actually issued (control file contained only
`wait 1`), so Finder readiness was not visually established or disproved.
The empty observer log after timeout lacks a normal SUMMARY; it is not a
measured zero-identity result or proof of correct timing. Future probes need
scheduled local captures and a normal cycle-bound exit before the wall timeout
to preserve buffered diagnostic output. No MiSTer hardware was touched.
