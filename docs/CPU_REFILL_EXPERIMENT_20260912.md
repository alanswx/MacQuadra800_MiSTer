# Branch-refill replenishment experiment

Baseline is the committed compact shared-decode checkpoint: parent `15eeaaf`,
AP `9ecf647`, hardware CPU Mix 0.447. Plan review is parent `2f32697`.
This experiment is isolated; it is not yet a hardware-accepted replacement.

## Diagnosis

The corrected unchanged-code Sieve prefix stops at the first completed outer
pass, forwarding a pending D6 write into the stop predicate. It executes exactly
8191 initialization stores and one D6 increment. Earlier mislabeled two-pass
logs are excluded from the one-pass comparison.

| CPU | Prefix cycles | Fetch requests | I-cache misses | Killed acknowledgements |
|---|---:|---:|---:|---:|
| Register dispatch | 966333 | 189401 | 5 | 16180 |
| Compact shared decode | 961299 | 130128 | 5 | 1901 |
| Replenishment candidate | 924551 | 130128 | 5 | 1901 |

These are CPU-only partial diagnostics, not full output-verification or hardware
scores. Logs and instrumentation: `/tmp/ap040-fetch-probe.riwUfB/`, especially
`baseline-one.log`, `compact-one.log`, and `candidate-one.log`.

Compact decode changes the timing of the short branch-refill seed. It reduces
traffic and killed requests, but reaches the end of the seed before subsequent
register operations have their opcodes. More FETCH occupancy is therefore not
evidence of more cache misses. The candidate permits the existing self-fill
engine to replenish a branch-refill-seeded queue from `S_PIPE_REGS` when at
most two words remain. All existing page/context, port ownership, lock, EA,
fault, and flush conditions still apply. No additional buffer or execution
unit is introduced.

Candidate core SHA-256:
`9d636190207b436dabfeec08d49ff86537f8d835ba79b09123963bc9ca66ae93`.
RTL: `/tmp/ap040-fetch-probe.riwUfB/candidate-rtl`.
Patch: `/tmp/ap040-fetch-probe.riwUfB/refill-regs.patch`.

Prefix savings: 36748 cycles (3.82%). Full Sieve, ordinary regression, corpus,
full-machine compilation, fit/timing and hardware gates remain required. In
particular, check that earlier instruction replenishment does not increase
data-port contention on other workloads. Do not infer a CPU Mix gain yet.

## First candidate rejected; restricted follow-up

The first candidate passed all eleven CPU suites and full Sieve phase 0:
92,439,661 / 92,439,514 cycles, array and guards PASS. All savings were FETCH
clocks. However, focused-loop phases 1/2 regressed 109,788 -> 133,988. Data-port
waits remained zero: extra speculative requests blocked DBcc's inline refill
guard. Inline refills fell 12,663 -> 263 and instruction requests rose
1,420 -> 13,820. It must not replace the baseline.

Candidate 2 restricts the extra refill opportunity to an actual qualified
shared register dispatch (`rd_queue_pop && rd_valid && regs_alu_fire &&
!aux_we`) as well as the original state/count test. Unsupported branch/DBcc
heads keep their quiet refill policy. This reuses existing eligibility logic;
there are no benchmark addresses or special-case opcode checks.

Core SHA: `2bbc1f3d6abbc2e0d082bdcd03935b1a3f4787d19c56e651896249fea519c00d`.
Isolated RTL `candidate2-rtl`, patch `refill-dispatch.patch`, under the probe
directory above. Prefix: 932,741 cycles, required counts/D6/D7 PASS. Focused
loop: 109,010 phase 0 and 109,788 phases 1/2, all PASS and no regression.
Full phase-0 Sieve also passes: 93,258,661 / 93,258,514 cycles, both complete
array/guard/D6/D7 checks PASS. Savings are exactly 2,855,800 FETCH cycles per
call (2.97155%); no other state or CE-stall count changes. All eleven ordinary
CPU suites and full-machine Verilator compilation pass. Corpus100 is unchanged
at 34,829,460 cycles, 1,900 matching field groups, zero REAL differences
(`/tmp/cpu-corpus100-gate.OO2YT6`).

Matched full phase-2 held-ack/wait Sieve also passes both complete checks:
compact 102,936,057 / 102,935,818 versus candidate 100,080,257 / 100,080,018.
The same 2,855,800-cycle saving persists (2.7755%). Logs are each full fixture's
`run-phase2.log`. Phase 1 has ordinary CPU-suite coverage but no full-Sieve
measurement in this experiment.

The seed23/CD-off fit passes in `/tmp/MacQuadra800_refill_regs_seed23.bIGn47`;
its QSF matches the accepted compact fit. Fitted area is 37,864 ALMs and
4,091/4,191 LABs (100 free), 95 fewer ALMs and 20 fewer occupied LABs.
Setup +0.270 ns, CPU +0.815 ns, SDRAM +1.063 ns; worst hold +0.205 ns.
All reported TNS groups are zero. Registers 24,330; RAM blocks 462; DSPs 41.
RBF SHA: `586ef4fe3a9a7146ab2c00522ed710c006a1cfacc8ecd562b605230e523f5a5e`.
Persistent RBF/QSF/summaries: `scratch/candidate_cpu_refilldispatch_seed23/`.
Hardware testing completed as below. The active AP source remains committed
compact `9ecf647`; this candidate is NOT adopted as a CPU throughput upgrade.

## Hardware decision: no measured throughput improvement

Speedometer 4.02 CPU Mix, all ten tests, one iteration, three quiet runs.
Parent independently viewed setup and all three local result images.

| Test | Run 1 | Run 2 | Run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 355.166 | 356.402 | 356.376 |
| Dhrystones/sec | 5078.623 | 5078.348 | 5079.009 |
| Towers sec | 2.018 | 2.019 | 2.019 |
| Quick Sort sec | 1.417 | 1.415 | 1.416 |
| Bubble Sort sec | 1.766 | 1.767 | 1.766 |
| Queens sec | 1.138 | 1.137 | 1.138 |
| Puzzle sec | 3.374 | 3.371 | 3.394 |
| Permutations sec | 3.154 | 3.154 | 3.153 |
| Integer Matrix sec | 2.347 | 2.346 | 2.350 |
| Sieve sec | 3.159 | 3.155 | 3.153 |
| CPU Mix | 0.446 | 0.447 | 0.446 |

Mean 0.446333 versus accepted 0.447 (-0.1491%). Do not interpret the small
aggregate difference as a precisely established slowdown, but there is no
hardware speedup. In particular, hardware Sieve does not reproduce the ~3%
CPU-only fixture gain. The improved fitted headroom remains useful evidence,
not permission to replace the accepted throughput checkpoint.

Screenshots in `scratch/perf_refilldispatch_cdoff_seed23/`, SHA-256:

- run1.png: `990446b325806a6641b92607b391d45052dea4d00913780a63379812e022a877`
- run2.png: `1b43bb6c2ac94815a7e3b06f7f12a8fb099a9d98b2af2a64f60cb350bdcf244f`
- run3.png: `b2ac549bab112a140b7219bec2cea6eacb180f9db8b67903f1f24b0b545dd0f8`

Next: profile actual wombat_cpu/cache/djMEMC integration before selecting another
throughput patch. Keep exact kernels for mechanism and correctness checks,
and require full-machine/hardware evidence for candidate ranking and acceptance.

Guarded cleanup completed: MENU, Main PID 22254 -> 22687, disposable restored
to MD5 `16790b0577e13b45782214433d34954b`, Main unchanged. Parent independently
rechecked MENU, Main/disposable hashes and slot-0 path after the tester finished.
No experimental CPU source was adopted; generated build/log directories remain local.
