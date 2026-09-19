# AP68040 pipeline: current design and first executable checkpoint

## Scope and provenance

This updates the September 15 design for the vendored CPU on `add-ethernet`.
Baseline parent commit: `97d2d92c106505e6ded3385093f20476edd61e09`.
The original `CPU_PIPELINE_PLAN_20260915.md` and
`CPU_PIPELINE_REWRITE_HANDOFF_20260915.md` remain available in the local
`profile-speedometer402-20260909` branch. They describe older interfaces,
area figures, fixtures, submodule procedures, and build concurrency rules.
Use current `CLAUDE.md` and `RESUME-handoff-20260919.md` for operations.
In particular, there is one Quartus flow at a time and CPU edits belong in
the vendored tree. No hardware deployment is part of this checkpoint.

The Motorola MC68040 User's Manual, especially integer pipeline and timing
sections, is the architecture reference:
https://www.nxp.com/docs/en/reference-manual/MC68040UM.pdf
The reference defines observable behavior; it does not supply FPGA RTL.

## Target and evidence required

The recorded real Quadra 800 Speedometer 4.02 Mix is 1.897. The current
hardware baseline is approximately 0.925–0.929, depending on machine/run.
The gap is about 2.05x. The Mix is an average of individual test ratings:
an aggregate cycle ratio is only an approximation to its eventual score.
Match per-test results, workload/OS/ROM, and configuration before making a
claim about the real machine. Graphics and FPU need their own comparisons.

The gap is not uniform. Comparing the recorded real-machine photograph
with build 13's eight-run hardware table (same CPU lineage, before the
Ethernet integration) gives these approximate required speedups:

| Test | Additional speedup to match real Q800 |
|---|---:|
| KWhetstones | 2.87x |
| Permutations | 2.69x |
| Towers | 2.29x |
| Dhrystones | 2.11x |
| Queens | 2.00x |
| Puzzle | 1.95x |
| Integer Matrix | 1.58x |
| Bubble Sort | 1.53x |
| Quick Sort | 1.48x |
| Sieve | 1.19x |

Source: `PERFORMANCE_MEASUREMENTS.md`, sections 2 and 22. This favors
investigating the call/operand-heavy workloads, rather than using a large
Sieve gain as the main proxy for progress. Attribute Whetstone's actual
integer, library and floating-point work before assuming that preserving
an unchanged FPU side engine can meet its target. Reaching the Mix average
alone would not demonstrate the same performance distribution as a Quadra.

At a fixed clock, a uniform 2.05x improvement removes about 51.2% of elapsed
cycles. If fraction f of a workload is accelerated by factor r, its ideal
speedup is 1 / ((1-f) + f/r). For example, f=0.70 and r=4 gives 2.105x;
f=0.50 cannot reach 2.05x even with an infinitely fast replacement. These
are scenarios, not predictions. An instruction-class share is not a cycle
share, and fetch/operand waits overlap in a pipeline: do not simply add
all old state counts as independent savings.

The September 15 estimates of 4.8 clocks/dispatch and a target around 2.2
are historical. The old short plan and detailed handoff even disagree on
the remaining sequencer ceiling (1.3 versus 1.0–1.1). Neither is a measured
ceiling for the current RTL. A fresh Speedometer profile is required.

## Architecture contracts before extending the prototype

The intended in-order engine has IF / ID / EA / RD / EX / WB stages. The
first checkpoint implements only resident input / ID / EX / WB. EA and RD
will be inserted when operands can come from memory. Stage count alone is
not the objective: common instructions must overlap without changing their
architectural effects.

1. **One owner of architectural state.** Reuse one register file, CCR/SR,
   MMU/control state and ordered store path. Before a complex instruction,
   stop issue, let older work retire, then give the sequencer exclusive
   register/memory ownership. Resume only after it reports completion or
   exception. The prototype reports a drained fallback boundary; it does
   not yet implement state transfer to the sequencer.
2. **In-order commitment.** Every stage carries valid, instruction PC,
   decoded operation, destination(s), flags and fault metadata. Register
   writes and CCR updates become architectural at WB. An address-register
   update from predecrement/postincrement stays speculative until then;
   younger address calculations may receive its forwarded value. Start
   with a serialized two-write retirement for instructions that write both
   An and Dn. Do not add another register-file port without measuring it.
3. **No premature stores or device reads.** EX may compute store address
   and data, but must not post the store until older instructions are
   committed and its access checks have succeeded. A younger store must
   never survive an older fault or branch cancellation. Serialize I/O and
   cache-inhibited reads so speculative instructions cannot consume device
   state. Existing posted-store bus-error behavior and format-7 fields need
   an explicit audit before memory instructions join the pipeline.
4. **Fault and interrupt boundary.** Latch fault information with its
   instruction, finish older work, discard younger work, and invoke the
   existing exception sequencer at the proper PC/SR. Preserve current trace,
   IPL, A7-bank, restart, and frame semantics. The current core itself lists
   access-error limitations; sharing its side engine does not prove exact
   silicon behavior. A/UX and fault-injection tests remain mandatory.
5. **Backpressure and dependencies.** Valid records hold under stalls;
   older stages can drain while a younger stage waits. Forward full register
   values and CCR, including preserved upper bytes of byte/word writes and
   X. Detect load-use dependencies before issuing the dependent instruction.
   Forward speculative An updates only with matching instruction validity.
6. **Memory arbitration.** The current core interface shares one port for
   instruction and data traffic. An IF request, operand read, and retiring
   store cannot simultaneously own it. State the arbitration and store-drain
   fairness rules, maintain the early hint/request pairing, and retain the
   second-master protection verified by `tb_line_dma`. The old instruction
   'stall RD only' still requires explicit backpressure through EA/ID/IF.
7. **Control flow.** Resolve branches correctly before adding prediction.
   A redirect kills only younger instructions; preserve the resolving
   branch and older instructions. A branch target table and return stack
   are later predictions, never architectural truth. Tag/flush speculative
   fetches on exception, context change, and relevant invalidation. Never
   deliver a fault from a discarded speculative fetch.
8. **Area and timing.** The complete machine is already 88% occupied.
   Share the existing ALU/register file and remove superseded sequencer
   paths when integrating. The old statement that roughly 18K ALMs can be
   replaced is an estimate, not a guaranteed area budget. Standalone timing
   does not establish full-machine timing or SDRAM crossing margins.

## Executable checkpoint P0

Files: `rtl/ap68040/experimental/ap040_pipeline_integer.sv`, its two benches,
and `scripts/cpu/pipeline_prototype.py`. They are absent from `files.qip`
and the release `.qsf`; the installed CPU is unchanged.

Supported: MOVEQ; MOVE.B/W/L Dn,Dn; ADD/SUB/CMP/AND/OR.B/W/L Dn,Dn;
EOR.B/W/L Dn,Dn; NOP. Unsupported encodings are held at ID until EX/WB
drain, then exposed through `fallback_valid` with PC/opcode. No unsupported
encoding silently retires. The input source supplies resident words; there
is no instruction-fetch unit, MMU, memory access, branch or exception path.

The prototype reuses `ap040_alu` and `ap040_regfile`. EX reads the register
file late and forwards the older WB value, including the partial-write
merge operand. CCR forwarding preserves X through operations that leave it
unchanged. A blocked WB holds younger work. All transfers are clock-enable
qualified. `flush` cancels unretired ID/EX/WB records on an enabled edge;
committed registers remain intact. An external flush must be held until
an enabled edge. This is a cancellation primitive, not a completed branch
or exception implementation.

Reproduce from repository root:

```sh
python3 scripts/cpu/pipeline_prototype.py
```

The runner generates a fixed semantic workload and independent Python
integer/CCR oracle. It executes the same machine words on the current core
in its existing program bench, and checks all eight D registers, CCR,
PC and opcode after every completed instruction. That limited observer
uses the actual pre-edge CE and overlays both registered CPU writes and
pending MLAB writes. It is not a general exception/branch retirement trace.
The prototype must match the same snapshots in four scheduling scenarios.

Results on 2026-09-19:

| Check | Result |
|---|---|
| Current core versus independent oracle | 8,608 / 8,608 instruction snapshots match |
| Decoder admission | all 65,536 opcode words checked against generated support map |
| Resident, unstalled pipeline | 8,608 retirements, fallback visible at cycle 8,611 |
| Input bubbles, blocked WB, CE pauses | 8,608 matches, cycle 16,356 |
| Flush a full pipeline before any commit | 8,608 matches after replay, cycle 8,617 |
| Flush younger work after a committed prefix | 8,608 matches, cycle 8,620 |
| Disable WB data forwarding in a copied candidate | oracle mismatch, as required |
| Existing AP68040 self-test suite | ALL TESTS PASSED |

Directed phase-0 baselines from the current tree: `bench_loop` **68,100**,
`pipe_bench` **110,696**, `branch_bench` **119,284** cycles, each self-checking
and passing. The handoff's 55,914 loop result refers to an earlier CPU
configuration; do not silently substitute it for the measured current tree.

The steady-state rate is one retirement per enabled clock with resident
instructions and an accepting WB. This is **not a Speedometer speedup**:
the prototype input deliberately omits fetch/memory delays. The current
CPU's 39,058-cycle program-bench run includes reset, fetch and the pass
mailbox and is not a like-for-like comparison with 8,611 prototype cycles.

Standalone Quartus 17.0.2 fit, Cyclone V 5CSEBA6U23I7, seed 21,
30.303 ns clock on physical clock pin V11, virtual data/control I/O:
**611 ALMs, 283 registers**, worst setup slack **+13.748 ns**, worst hold
**+0.144 ns**. The standalone fit has no
MMU/cache/side engine or full-machine routing. It proves synthesizability
of P0 and is not a prediction of final core area. Reports and the exact
standalone project are in `scratch/pipeline_prototype/fit_clock_pin_v2/`. Reproduce with
`bash scripts/cpu/fit_pipeline_prototype.sh NEW_OUTPUT_DIRECTORY` in a
`systemd-run --user` unit while no other Quartus flow is active. An initial
all-virtual-pin fit (607 ALMs) was superseded because its clock input was
also virtual; a subsequent failed fit exposed QSF quoting that is fixed in
the reproduction script.

## Measurement tools and timer issue

The current simulator's old `--prof` counter counted entries into S_DECODE
and therefore missed bypassed decode and consecutive dispatches. It now
uses the existing `perf_dispatch_toggle`, sampled continuously after each
rising-edge evaluation and resynchronized during reset. Restored control
and profile-gating tests cover reset, stalls, same-PC/state dispatches,
start/stop boundaries, command parsing, and input pacing.

`--control PATH --cpu-profile FILE` restores a bounded profile bracket
with local `profile start` / `profile stop` commands and optional key input.
The profile's dispatch count includes faulting instructions. It is not a
retired-instruction count: a short branch folded into its producer may
complete without loading a distinct opcode. A synthetic ROM containing
three ADDQ instructions and one folded BRA per loop gave 15,002 observed
opcode loads in a 20,002-clock bracket; the old decode-entry counter would
see only about 5,000. Do not call either counter architectural CPI.
Cache/store indicators sampled after evaluation
are labelled as occupancy/signal samples, not exact bus transactions.

`--speedometer-observe FILE` enables the recovered timing observer. It
recognizes the immutable Speedometer resource signatures from acknowledged
logical instruction reads, follows the two timer wrappers, and records raw
timer values and simulated clock context. Its register adapter now handles
the MLAB pending write and the CPU's newer pending write in the correct
order. Tests check the actual resource signatures and synthetic carry,
backwards timestamps, split reads, MMU changes, fault/CE rejection, capture
bounds, and pending writes. A normal simulated run would not rule out the
hardware-only VIA/clock-domain hypotheses. The proposed high-frequency
guest `Microseconds` stress program remains separate follow-up work.

A timer-path inspection does not yet justify changing the VIA. The current
RTL returns live low/high counter bytes separately. WDC's compatible-VIA
reference, [W65C22 tables 2-6 and 2-9](https://www.westerndesigncenter.com/wdc/documentation/w65c22.pdf),
describes individual counter-byte reads and their interrupt-flag effects;
it does not specify a high-byte snapshot on a low-byte read. That modern
compatible-device document is not proof of the Quadra IOSB's exact behavior.
An absent snapshot latch by itself is therefore not a demonstrated bug:
observe the guest's actual read/retry/interrupt sequence before adding one.

The first cold-boot attempt reached MacAtrium, then the host crashed on the
first scripted key. Restoring `input.ps2_key = &model.ps2_key` fixed the
missing connection. A real-simulator synthetic-ROM integration test now
checks key press/release, the profile bracket, graceful `quit`, and the
observer's final summary before a long run is launched. The restarted
baseline in `scratch/pipeline_baseline_20260919c/` uses the documented
simulation-only fastboot ROM and a 660-million-clock initial wait, with a
fresh copy of the original disk. The ROM differs only at the RAM-test gate
and checksum, verified against the original. This is a development profile,
not a pristine-ROM acceptance run; later simulator comparisons must use this
same recipe. The intermediate `b` run was stopped during RAM testing:
`+warmstart` seeds a different ROM cookie and does not skip this test, as
`docs/quadra800-ram-test.md` already explains.

The simulation uses a disposable disk copy. No baseline number should be
recorded until screenshots prove the intended benchmark ran to completion.
The current simulator bypasses the physical SDRAM bridge and disables SONIC;
its memory timing and results are a simulation baseline, not hardware truth.

## Next implementation checkpoints

P1: specify and test the drain/ownership interface to the existing sequencer,
including import/export of architectural state and interruption at boundaries.
Keep common register operations pipelined and everything else serialized.

P2: add EA/RD and simple loads with synthetic hit/miss/walk delays and faults,
then verify the real MMU/cache wrapper. Add dependent load-use and partial
register tests, page/line crossings, and postincrement rollback.

P3: commit-ordered stores and branches without prediction. Add older-fault /
younger-store, I/O serialization, branch-kill, DMA coherence and self-modifying
code cases. Only then add a measured branch predictor and return stack.

At each boundary, compare architectural outcomes, synthesize representative
logic, and run the relevant full-machine gates. Before deployment: full
CPU/corpus gates, simulated boot, fitted cross-domain STA, and the current
hardware regression lifecycle. Report at least five valid hardware Mix runs
with invalid timing runs listed separately, plus A/UX and Ethernet checks.
