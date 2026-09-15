# Bounded Speedometer timer observer (simulation only)

No guest/VIA/CPU fix and no FPGA instrumentation. The accepted CPU remains
`0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`.
This fixture owns the observer, tests and preparation script. Simulator
build outputs belong in new /tmp trees; production RTL is not modified.

## Reproduce preparation and tests

```sh
python3 scripts/fixtures/speedometer_timing_observer/run_tests.py \
  --resource "/tmp/speedo402-unar/Speedometer 4.02.rsrc"
python3 scripts/fixtures/speedometer_timing_observer/prepare.py \
  --source /tmp/MacQuadra800_operand_source_seed24.zXuurP \
  --dest /tmp/NEW-UNUSED-observer-simulator
make -C /tmp/NEW-UNUSED-observer-simulator/verilator -j4 \
  V=/home/alans/verilator5/bin/verilator
```

Run these commands from the repository root. The destination must not exist. Preparation verifies exact CPU and original
sim_main.cpp hashes before copying into the new tree. It writes a unified
sim_main.cpp patch and installs the two observer includes; no RTL is patched.
Source tree must include its existing simulator build and ROM. Unit tests
verify the immutable original Speedometer resource, both unique signatures,
all 40 event opcodes, synthetic relocated address spaces, CE/fault exclusion,
reset/flush invalidation, stale-code rearming rejection, carry/backwards raw
times, split elapsed reads, aggregation, fallback traps, capture caps, startup
context churn, pending RF writes and all three stack-pointer banks.

## Future guest capture (NOT executed in this bounded task)

Use a **new disposable copy** of the known-good Speedometer disk; the simulator
opens disks read/write. Never pass the golden profile disk or an existing
user simulator disk directly. Start from the prepared simulator's `verilator`
directory, preserving original ROM and workload identity:

```sh
./obj_dir/Vemu --headless --no-cpu-trace \
  --disk /tmp/OWNED-DISPOSABLE-COPY.hda \
  +rom=quadra800.rom.hex \
  --control /tmp/OWNED-EXISTING-CONTROL-FIFO \
  --speedometer-observe /tmp/NEW-timer-events.log \
  --speedometer-limit 512 --max-cycles YOUR_EXPLICIT_BUDGET
```

Those placeholder paths/budget require explicit preparation. Existing
sim_control syntax supports local keys, waits and screenshots; it is not the
hardware keyboard protocol. `--max-cycles` uses the existing simulator's
half-clock-edge budget; observer timestamps are `main_time/2`, 33 MHz rising
edges. Existing main-loop batching can overshoot the requested budget.
No resumable simulator state/live Vemu was found during inspection. Therefore
capturing an actual Speedometer run requires a fresh, potentially lengthy
guest boot/navigation. This task proves observer capability, not reproduction
or diagnosis of the intermittent hardware anomaly. Do not restart a different
existing simulator or change disk/ROM identity to work around boot issues.

## What is observed

The adapter samples successful core-side bus transfers immediately before
each rising eval and opcode-load events after eval/NBA. It uses the existing
perf_dispatch_toggle observer, including fast register-decode paths. sim.v
ties machine CE high; prepare.py asserts that integration. The standalone
collector still rejects CE-low and failed transfers. A different simulator
CE integration needs an adapter change.

Instruction bytes come from actual acknowledged **logical CPU requests**,
after the real MMU/cache answered. No physical-RAM lookup uses a virtual PC,
and the observer does not implement an approximate page-table walk. Only
4096 direct-mapped captured bytes are retained; collision/missing evidence
prevents identification instead of guessing.

Identification requires all of:

1. Two freshly dispatched MOVE.W immediate/A5-relative instructions followed
   immediately by their JSR, with the known PC spacing.
2. The actual successful writes of `4` and `0x92` (Queens) or `0xe2` (Sieve)
   to the two known A5-relative destinations.
3. Matching immutable non-relocated prefix bytes from observed instruction
   responses. The JSR's relocated address is not part of the signature.

These signatures each occur exactly once in the verified resource. The loaded
CODE 3 base is derived from the executing logical PC, never assumed from a
file offset. Subsequent event opcodes and the actual kernel-selector immediate
are checked. Context-register changes, PFLUSH and CINV invalidate identity and
captured bytes. The prefix execution requirement prevents stale cached bytes
alone from rearming after code unload/reuse. A completed bracket's BCS
fallthrough also disarms identity; a repeating bracket retains it. Interrupts
within the short prefix can conservatively prevent recognition.

These are safeguards for this immutable workload, not a general OS code-loader
tracker. Unannounced aliases/PTE edits without architectural flushes, arbitrary
in-place code mutation during a live bracket, or a different resource require
fresh validation; no universal MMU/coherence claim is made. Context changes
before identification are counted silently and cannot exhaust the record cap.

Records include full register snapshots at selected Queens/Sieve boundaries,
actual timer-selector/stack/task accesses, Microseconds start/stop returns,
host unsigned-64-bit deltas and backwards flags, fallback timer trap entries,
guest subtraction return, the actual elapsed operand read by ADD.L, D4 before
and after accumulation, D5 updates and TickCount/deadline comparison. RF storage
can lag a retirement by one edge: snapshots explicitly report and overlay the
pending registered write, matching the existing CPU forwarding boundary.

`AGGREGATE_CHECK` compares the actual elapsed read against the low32 raw delta
and the wrapped D4 sum. Low32 agreement is **not** proof of a correct clock:
retain raw high words and the backwards flag. `KERNEL_CALL`/`KERNEL_RETURN`
cycle brackets include call/return dispatch overhead and are diagnostic, not
the isolated Sieve fixture's exact-loop performance number. Fallback records
expose raw task-count accesses and D0 on return; no invented Microseconds
delta is computed for fallback. Memory watchpoints use actual logical requests;
the static fallback task location follows the verified application artifact.

The default cap is 512 records (maximum 4096); reaching it does not stop or
alter the guest. A normal bounded simulator exit flushes output and appends
SUMMARY. `identities=0` means no verified workload capture, not a passing guest
timing test. The existing ordinary CPU trace remains unsuitable for MMU-on
extension-word inspection and should stay disabled for this capture.

## Validated artifacts (2026-09-13)

Luna ran the strengthened tests with actual exit 0:
`/tmp/speedometer-observer-test.t5w61onf/test.log`.
The prepared full-machine simulator compiled with actual exit 0:
`/tmp/speedometer-timing-observer.0z4YdU/simulator/verilator-build-retry.log`. No guest simulator run was performed.
The first adapter compile failed on two optimized signal aliases; the corrected
adapter uses the generated CPU-wrapper names for PFLUSH/CINV requests.

SHA256 identities:

```text
observer header 0037e31276810cf6dc3d50c6a175c59e37b109f8815181e7e26e0fb62821e1be
adapter include 2d1dfac578116bc30f954dcc7ec0e634ab585bff350665df163dafff1c003bbe
instrumented sim_main.cpp d84074c223907dbd0b1a39d84fdf814dfeb73b22bb942cd8d4899be820fd17bc
sim_main.cpp patch 4e9f324a6ed66c7251c1d25b3139d0ab1893d303b41f2e7463b2bea1a9715ba0
built Vemu 84fb65a9999e090f5a25a1165f473af3054f0e38be04851d7ef304016141e8d9
```

The unified patch at `simulator-observer.patch` passes
`git apply --check` against the active, unmodified simulator source. Applying
that patch alone is insufficient: also install `speedometer_observer.h` and
`adapter.inc` as `verilator/speedometer_adapter.inc`; prepare.py does both in
a new isolated tree. Active CPU and simulator sources remained unchanged.
