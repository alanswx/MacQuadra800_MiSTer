# CPU optimization loop — 2026-09-12

Later fit, extended-corpus and hardware evidence is recorded in
[CPU_VALIDATION_UPDATE_20260912.md](CPU_VALIDATION_UPDATE_20260912.md).

Active repository: `/home/alans/mister/MacQuadra800_MiSTer`.
User authorized restoring the disposable Speedometer disk and repeated CPU
implementation/testing. Preserve Main and accepted RBFs; do not commit/push
without a new request. Astra owns code/diagnosis; Luna runs established tests.

## References and acceptance

- Full-feature Speedometer 4.02 CPU Mix reference: 0.405.
- CD-off register-ALU retirement checkpoint: 0.423, 0.424; mean 0.4235.
- Broader register dispatch: verified clean-disk repeats 0.434 and 0.435, mean
  0.4345 (+2.5974% versus 0.4235; +7.2840% versus 0.405). Hardware-validated.
  An earlier impossible-negative timing run is excluded; the earlier plausible
  0.435 is supporting evidence, not part of the controlled two-run mean.
- All CPU Mix tests, one iteration, at least 135 seconds without remote activity.
- Golden disk `/tmp/MacQuadra800-Speedometer402-profile.hda`, MD5
  `16790b0577e13b45782214433d34954b`, remains intact.
- Restore only the disposable
  `/media/fat/games/MacQuadra800/Speedometer402-upstream-test.hda`, after MENU.

## Experiments

| Candidate | First-100 corpus clocks | Difference from regdispatch | Status |
|---|---:|---:|---|
| Register dispatch | 34,941,315 | reference | Hardware mean 0.4345, accepted CD-off checkpoint |
| Retire at S_PIPE_SDONE only | 34,941,315 | 0 | Rejected: common reads already bypass SDONE |
| Shared memory ALU retirement | 34,838,648 | -102,667 (-0.294%) | Fit/timing pass; hardware repeats pending |

All three pass the eleven AP suites and match 1,900 architectural field groups
in the same immutable 100-case corpus. The register-focused cached loop remains
122,788 clocks. These are simulation results, not inferred hardware speedups.

The shared memory ALU candidate reuses the existing d_err-before-d_ack S_MRD
completion point and replaces the special MOVE-only retirement path with shared
ALU completion. It does not change the acknowledgement protocol or start younger
memory accesses. Added integer tests 194–214 cover partial-register merges,
flags, immediate consumers, memory arithmetic/compare, An update aliasing,
MOVEA sign extension, memory-destination/non-ALU fallbacks, and A7→short-BSR
forwarding. Existing short-BSR coverage was kept in range with a nearby helper.

Source SHA-256 for this candidate:
`448ff7c28c8cb8225ab6aae24e52b7856b10fafc0156f4ba17d33850fe566c4e`.
Isolated fit tree: `/tmp/MacQuadra800_memretire_20260912.snVFk6`.
Logs and corpus results: `rtl/ap68040/tb/build/`, with `memalu100` suffixes.
Full-machine Verilator compiled after both RTL and profiler updates.

## Profiling and workflow corrections

The existing simulator profiler counted only state transitions into S_DECODE,
missing adjacent resident MOVEQ/NOP decode cycles. It now counts a changed
instruction PC within S_DECODE as a new dispatch, without counting stalled
decode clocks repeatedly. Previous CPI/opcode counts from this profiler need
revalidation; state occupancy remains separately reported.

Local X11 connections time out, preventing GUI-based exact Speedometer profiling.
Requested `xvfb` installation; hardware testing is independent of that limitation.
The isolated old-binary profiling fixture is
`/tmp/MacQuadra800_speedo402_profile.e4C41A`; it is not an accepted profile.

Finder Return edits names rather than opening icons. A failed navigation sequence
renamed MacAtrium to Speedometer, then browsed its metadata. Parent restored the
golden and verified the correct Applications→Speedometer 4.02 Folder route.
Exact navigation and arithmetic/OCR checking rules are saved in
`docs/AGENT_TESTING_WORKFLOW.md`.

## Next architecture prototype

An isolated Astra task is implementing shared common-register decode overlapped
with retirement, reusing the existing ALU/control latches. Mandatory gates include
pending-register-write forwarding, partial writes, address/stack registers,
CCR dependencies, precise IRQ/trace/flush behavior, and slow-path fallbacks.
It must not replace the tested candidate until correctness, area, timing, and
hardware measurements justify it. See CPU_PERFORMANCE_TASKS.md Priority 3 for
the full pipeline roadmap toward the user's approximately 1.9 target.

## Verified register-dispatch hardware repeats

| CPU Mix test | Run 1 | Run 2 |
|---|---:|---:|
| KWhetstones/sec | 353.248 | 354.179 |
| Dhrystones/sec | 4968.691 | 4969.277 |
| Towers (sec) | 2.043 | 2.041 |
| Quick Sort (sec) | 1.498 | 1.497 |
| Bubble Sort (sec) | 1.880 | 1.879 |
| Queens (sec) | 1.149 | 1.149 |
| Puzzle (sec) | 3.544 | 3.543 |
| Permutations (sec) | 3.180 | 3.181 |
| Integer Matrix (sec) | 2.401 | 2.397 |
| Sieve (sec) | 3.319 | 3.315 |
| CPU Mix average | 0.434 | 0.435 |

Parent visually verified both tables. Screenshots in
`scratch/perf_regdispatch_cdoff_seed22/verified_run1.png` and `verified_run2.png`.
SHA-256 respectively:
`9620b1518ae701d3040e7b2bac8ff9ad3facb59559bc8e9f52cb043d55f89d43` and
`c53ff7a352afa34abf2b90de6895cd434661ed54fc529fbef2f4382340a90516`.
Tested RBF `/media/fat/_Unstable/MacQuadra800_CPU_regdispatch_CDoff_seed22_20260912.rbf`,
SHA-256 `1243ad4df9bb1331409caf557fb045ad2cf4ccf4bef3a71260a204862ecab6e7`.
Parent independently verified final MENU, restored disk MD5 above, and unchanged
Main `/media/fat/MiSTer` MD5 `dfb5937ba47720c3ae20abc8f381c462`.
