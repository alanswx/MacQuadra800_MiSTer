# Reproduce the partial branch-refill diagnostic

This is a **one-original-outer-pass diagnostic**, not the full 100-pass Sieve
correctness/performance fixture, a Speedometer score, or hardware timing.
See `docs/EXACT_SIEVE_PROFILING.md` for exact-byte provenance and full tests.
`docs/CPU_REFILL_EXPERIMENT_20260912.md` (if present) records acceptance status;
the recipe below does not authorize adopting experimental RTL or deploying it.

## Immutable inputs

- Committed AP baseline: `9ecf647`, core SHA-256
  `5ab7603019ab43ffb10bcdc5ef80086d2b0a5b515abd7fdd64d9adfaf0d0f3ff`.
- Probe: `scripts/fixtures/frontfetch_probe.sv`, SHA-256
  `5d62ff8172d2b5bddd8c70a212f892df932d83aa7fd8fffa83bac450135064ee`.
- Candidate2 patch: `docs/checkpoints/cpu-refill-dispatch-experimental-20260912.patch`.
  Resulting core SHA-256:
  `2bbc1f3d6abbc2e0d082bdcd03935b1a3f4787d19c56e651896249fea519c00d`.
- Original resource: `/tmp/speedo402-unar/Speedometer 4.02.rsrc`, SHA-256
  `af67113bceb4eb906e973a9b747a0b1925b9d64c62f0f9a84bc6f0578839ca80`.
  The resource is an external local fixture; the script rejects any different
  binary. Preserve/recover it separately if /tmp is lost.

## Make an isolated source fixture

Run this setup once. It modifies only the newly allocated /tmp directory and
does not rely on the active CPU worktree matching the baseline commit.

```sh
task_repo=/home/alans/mister/MacQuadra800_MiSTer
probe_root=$(mktemp -d /tmp/ap040-refill-repro.XXXXXX)
mkdir -p "$probe_root/ap68040"
git -C "$task_repo/rtl/ap68040" archive 9ecf647 |
  tar -x -C "$probe_root/ap68040"
cp "$task_repo/scripts/fixtures/frontfetch_probe.sv" "$probe_root/ap68040/tb/"
cp -a "$probe_root/ap68040/rtl" "$probe_root/rtl-candidate"
git -C "$probe_root/rtl-candidate" apply --recount --unidiff-zero \
  "$task_repo/docs/checkpoints/cpu-refill-dispatch-experimental-20260912.patch"
```

Add the opt-in probe instance and its explicitly partial completion path to
the isolated baseline fixture (not the active repository):

```sh
git -C "$probe_root/ap68040" apply --recount --unidiff-zero <<'PATCH'
diff --git a/tb/exact_sieve_monitor.sv b/tb/exact_sieve_monitor.sv
--- a/tb/exact_sieve_monitor.sv
+++ b/tb/exact_sieve_monitor.sv
@@ -8,1 +8,3 @@
+`include "frontfetch_probe.sv"
 module exact_sieve_monitor;
+frontfetch_probe fetch_probe();
diff --git a/tb/run_exact_sieve.sh b/tb/run_exact_sieve.sh
--- a/tb/run_exact_sieve.sh
+++ b/tb/run_exact_sieve.sh
@@ -40,1 +40,5 @@
+if grep -q '^FETCH_PROBE_COMPLETE ' "$output/run.log"; then
+    grep '^FETCH_' "$output/run.log"
+    exit 0
+fi
 grep '^EXACT_SIEVE\|^phase\|ALL TESTS PASSED\|SIEVE_ORACLE\|FAIL' "$output/run.log"
PATCH
sha256sum "$probe_root/ap68040/rtl/ap040_core.v" \
  "$probe_root/rtl-candidate/ap040_core.v"
```

## Run serially; do not share the tb/build directory concurrently

```sh
cd "$probe_root/ap68040/tb"
VASM=/tmp/wombat-vasm/vasmm68k_mot \
VERILATOR=/home/alans/verilator5/bin/verilator JOBS=4 \
sh run_exact_sieve.sh '/tmp/speedo402-unar/Speedometer 4.02.rsrc' \
  "$probe_root/ap68040/rtl" "$probe_root/baseline" +phase=0 +fetchprobe

VASM=/tmp/wombat-vasm/vasmm68k_mot \
VERILATOR=/home/alans/verilator5/bin/verilator JOBS=4 \
sh run_exact_sieve.sh '/tmp/speedo402-unar/Speedometer 4.02.rsrc' \
  "$probe_root/rtl-candidate" "$probe_root/candidate" +phase=0 +fetchprobe
```

Require actual exit zero and `FETCH_PROBE_COMPLETE`; this mode intentionally
does NOT print the full fixture's `ALL TESTS PASSED`. Omitting `+fetchprobe`
leaves the supplementary probe inactive and runs the full original fixture.
The interpreter/compiler and baseline RTL/source hashes must match when
comparing measured prefixes.

## Boundary and counter checks

The start is post-NBA S_DECODE at PC_i=$2000. Stop is post-NBA S_DECODE at
PC_i=$204A, with **effective D6=1**, before the next CMP #100,D6 executes.
The immediately preceding ADDQ may still have its RF write pending, so the
probe forwards rf_wdata when rf_we and rf_waddr=6. Checking raw registered D6
is wrong: it can miss the first boundary and stop after TWO passes.

Verify these invariants, not merely the printed label:

- `FETCH_PC pc=200a dispatch=8191` (one array-initialization pass).
- `FETCH_PC pc=2048 dispatch=1` (one outer-loop increment).
- Printed effective D6=1 and D7=1899.
- Per-PC dispatch counts identical across variants.

The old `/tmp/ap040-fetch-probe.riwUfB/{baseline,compact}` logs predate that
forwarding fix and span two passes. Correct one-pass logs are `{baseline-one,
compact-one,candidate2-one}`; preserve the old logs only as explicitly
mislabeled historical diagnostic evidence.

`FETCH_PC` bins S_FETCH by target PC and mutually exclusive resident, forwarded,
pending, killed-pending, rearm, port-gap, or other condition. `brf` is an
additional subset. `im_cycles` belongs to the opcode's PC_i. `from_fetch`
counts ENTERING S_FETCH after that prior instruction; its name does not mean
an opcode dispatched from S_FETCH. PC-change dispatch counting is valid only
for this fixed kernel with no consecutive same-PC instructions, not a general
replacement for the core dispatch toggle. I-cache lookup/prediction counters
are ce-qualified actual events, not inferred from S_FETCH occupancy.

## Recorded candidate2 result and interpretation

Corrected compact prefix: **961,299 cycles**. Candidate2: **932,741 cycles**,
28,558 fewer (2.9708%). Exactly 14,279 requests move from issue in S_FETCH
to issue in S_PIPE_REGS. Only S_FETCH occupancy changes: target $2036 loses
14,279 pending cycles and 14,279 issue/other cycles. Both variants have
130,128 instruction requests, 52,747 regular I hits, 77,376 predicted I hits,
5 I misses, and 1,901 killed acknowledgements in this bracket.

Candidate2 preserves focused bench_loop at 109010/109788/109788 cycles across
all latency phases, with 12663 inline DBcc refills and zero operand port-wait.
The first broader predicate (only S_PIPE_REGS/count<=2) was rejected: it
started unnecessary fetches ahead of DBRA, prevented guarded inline refill,
and regressed that loop to 133210/133988/133988. The corrected predicate
requires actual qualified shared register-lookahead dispatch, so unsupported
branch heads retain the original policy. All existing port, EA, page, lock,
fault and flush guards remain intact. Full gates and fit are separate from
these partial observations; no hardware gain is implied.
