# Upstream pipeline benchmark evaluation — 2026-09-20

## Decision

**No speed improvement demonstrated; do not import the rewrite into the Mac.**
Keep the upstream experiment separate. All four original benchmark kernels
encounter unimplemented MOVEA forms. Upstream's small synthetic differential test
passes correctness but the new pipeline takes **32.21% more cycles** than its own
older FSM CPU in that test. Neither observation predicts a hardware Speedometer
Mix, and the synthetic baseline is not our optimized Mac CPU.

Pinned upstream: `62b1dc864f5fd2975d6ceaf7084221fbc5b52dde`.
Mac RTL baseline: P47 (`406a098` CPU implementation), checkout `c36402d`.
No production RTL, FPGA image, or MiSTer state changed for these tests.

## Original kernels on the same memory responder

`verilator/tb_cpu_upstream_compare.sv` connects either the Mac `wombat_cpu`
or upstream `ap040_pipe_sys` to the same 64 KiB, big-endian memory model.
CPU enable is always asserted. Latency is the configurable countdown after the
responder latches a request; it is **not** the entire request-to-return latency.
Requests must stay stable until acknowledgement. The Mac path retains its real
MMU/cache/store buffer, with caches enabled by fixture setup. Upstream lacks the
cache/MMU integration. These are path comparisons, not isolated IPC measurements.

The first run used the preexisting fixtures byte-for-byte at delays 0, 3, and 8:
our Mac passed 12/12. Upstream failed 12/12; its first unsupported setup instruction
was `MOVE.W #$2700,SR`, then even the immediate-to-memory failure marker was
unsupported. Those failures do not measure kernel speed.

`prepare_upstream_kernels.py` therefore generates common wrappers using supported
setup instructions. Both CPUs receive identical new images. All bytes at and
above $1000, including every original kernel and initial data array, are verified
unchanged. It replaces wrapper-side checks with the existing independent host
oracles: nonattacking Queens board and guards; exact sorted Bubble permutation;
8,660 Permute calls and restored array/guards; 16,383 Towers moves, ordered lists,
node partition and guards. No benchmark instruction is rewritten or skipped.
Upstream has no reset-vector loading, so its PC parameter is $400 and the bench
initializes ISP from the same reset vector; this is explicit test scaffolding.

Final common-wrapper results at delay 3:

| Kernel | Current Mac cycles, checks PASS | First upstream exception (vector 4) |
|---|---:|---|
| Queens | 65,744 | $91B0: $246E — MOVEA.L $A(A6),A2 |
| Bubble | 3,270,274 | $958A: $204A — MOVEA.L A2,A0 |
| Permute | 1,380,503 | $65C6: $206E — MOVEA.L $8(A6),A0 |
| Towers | 24,096,007 | $982C: $3043 — MOVEA.W D3,A0 |

There is **no valid upstream completion time or speedup ratio** for these kernels.
The trap cycle counts in logs are diagnostics, not benchmark timings. The initial
adapted sweep reproduced the Queens/Bubble/Towers kernel traps at delays 0/3/8;
Permute still hit a setup displacement-store gap until the final wrapper changed
that store to indirect addressing. The final delay-3 run reaches original kernel
code on all four. Completing MOVEA alone would not establish ISA completeness.

Final results/logs: `scratch/upstream_speed_v3_20260920`.
Original-fixture sweep: `scratch/upstream_speed_20260920`.
Final wrapper images and identity manifest: `scratch/upstream_kernel_wrappers_v3_20260920`.

## Synthetic upstream-to-upstream timing

`profile_upstream_dual.py` instruments the existing milestone-83 bench with two
first-completion counters. It changes no CPU RTL, generated instruction, memory
model, or correctness assertion. All 16 programs pass their original comparison
of 15 final registers. Each program contains 96 generated slots, with branches
and NOP padding; these are not 96 guaranteed retired instructions.

Both sides use the upstream 16-bit bus adapter and matching bus responders.
The FSM has MMU/FPU/cache disabled; pipeline CPU enable is always high, while the
FSM retains its original compatibility-wrapper clock-enable wiring. Counters
include startup, generated code, register dump and done store. The pipeline gets
its reset stack initialized by the original testbench. This is a measurement of
those complete upstream paths, not an equalized execution-stage-only benchmark.

| Round | New pipeline cycles | Upstream FSM cycles |
|---:|---:|---:|
| 0 | 1325 | 989 |
| 1 | 1253 | 984 |
| 2 | 1311 | 988 |
| 3 | 1303 | 973 |
| 4 | 1347 | 1003 |
| 5 | 1305 | 1002 |
| 6 | 1255 | 951 |
| 7 | 1274 | 975 |
| 8 | 1307 | 994 |
| 9 | 1333 | 996 |
| 10 | 1338 | 994 |
| 11 | 1292 | 985 |
| 12 | 1306 | 987 |
| 13 | 1347 | 1007 |
| 14 | 1329 | 993 |
| 15 | 1245 | 965 |
| **Total** | **20,870** | **15,786** |

Aggregate FSM/pipeline cycle ratio: **0.7564x**; pipeline takes
**32.21% more cycles** (about 24.36% lower throughput).
Every measured round is slower. This does not rule out gains with an integrated
cache or a different workload. The bus-facing fetcher currently requests words
through a serialized interface; a pipeline's standalone Fmax alone does not imply
better system throughput. No bottleneck attribution was measured here.

Results, source identities, generated bench and logs:
`scratch/upstream_synthetic_speed_20260920`.

## What can be adopted individually

The new stages, forwarding and branch recovery are coupled architectural changes;
they are not a sequence of drop-in speed patches for our CPU. The differential
and memory-delay testing methods are useful immediately and the comparison tools
are now retained here. Upstream's exception-address timing optimization computes
SP-8 and SP-12 in parallel then selects the result. That is a separable technique,
but its reported gain is in upstream static timing, not execution cycles; port it
only if our own critical path warrants it. No RTL import is justified by these
performance measurements.

Recommended next CPU work remains the already-qualified local mechanisms and
our area/timing problem (P47 failed placement; P52 is still an unqualified scratch
candidate). Revisit the upstream rewrite after its ISA and cache integration can
execute these unchanged kernels, then repeat the same comparison before merging.

## Reproduction

From the project root, with the isolated upstream snapshot and existing fixtures:

```sh
python3 scripts/cpu/prepare_upstream_kernels.py --out scratch/upstream_kernel_wrappers_v3_20260920 --queens scratch/q52/program.hex --bubble scratch/p52_bubble/program.hex --permute scratch/p4/pea_entry/program.hex --towers scratch/towers_probe_20260919/towers.hex
python3 scripts/cpu/evaluate_upstream_pipeline.py --upstream scratch/minimig-ap040-eval-62b1dc8 --out scratch/upstream_speed_v3_20260920 --queens scratch/upstream_kernel_wrappers_v3_20260920/queens.hex --bubble scratch/upstream_kernel_wrappers_v3_20260920/bubble.hex --permute scratch/upstream_kernel_wrappers_v3_20260920/permute.hex --towers scratch/upstream_kernel_wrappers_v3_20260920/towers.hex --latencies 3
python3 scripts/cpu/profile_upstream_dual.py --upstream scratch/minimig-ap040-eval-62b1dc8 --out scratch/upstream_synthetic_speed_20260920
```

The evaluator writes explicit PASS/failure records for each run; failures are
expected for this pinned upstream version. A successful evaluator process means
it completed the report, not that its guest CPU passed. Scratch binaries/resources
are local artifacts, not bundled in this commit. Queens/Bubble/Permute fixture
creation and resource identity are recorded in the existing profiling scripts;
Towers uses the previously extracted local fixture. The final program hashes
are recorded below for identifying the exact inputs.

| Kernel | Final program SHA-256 (binary bytes) |
|---|---|
| queens | `dfbaf6ecd3f7b2d0edcf59f585722bbc90affd58cd52a11cb181c7ce7529062f` |
| bubble | `3131c372421976d835264842d6169e5425971b937c16535f5927ca71cc302389` |
| permute | `5638d1c0914db61ab82dfd3bcc0c881fc3ba70ea4c43e679dda7e2ffd5ebf39d` |
| towers | `61e56cb4e59a474af889a4da6f04ebf4849102910f03da42bb6239e81a67bbe7` |
