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


## P1: sequencer ownership checkpoint

The opt-in `AP040_EXPERIMENTAL_PIPELINE` compile define connects the experimental
engine to the real core's existing register file and SR. The default/release
configuration remains the original core. `EXTERNAL_STATE=1` removes the
prototype's private register file; pending MLAB write forwarding stays in the
shared register-file module. At this checkpoint the core serializes one
admitted instruction, receives its committed result, and rejoins `S_NEXT`.
IRQ/trace processing therefore remains after settled register/CCR state.
Lookahead dispatch is disabled in this experiment so instructions pass through
the explicit ownership boundary. This deliberately slower configuration proves
handoff correctness before overlapping queue consumption is introduced; it is
not a hardware performance candidate.

`python3 scripts/cpu/pipeline_handoff.py` compares the same 8,608 instruction
snapshots against the independent oracle, then runs the existing integer,
exception, MMU, cache, MOVEM restart, FPU and IRQ program tests under their
standard bus-delay modes. The monitor checks exclusive write ownership,
retirement identity, balanced handoffs and CE pauses. The first straight-line
run passed all 8,608 snapshots in 51,996 bench cycles, with 4,308 paused ownership
cycles. P0's standalone admission/forwarding/flush tests still pass after adding
the external-state interface. Its older Quartus numbers refer to the recorded
P0 source hashes, not to the integrated machine.

All 14 real-core program suites passed with balanced handoffs, including
`loops_irq` (4,044 entries/commits). Artifacts: `scratch/pipeline_p1/`.


## P1b: overlapping resident issue (development, not a performance candidate)

The experimental core now feeds consecutive resident supported words from its
fetch queue while earlier instructions execute and commit. An IRQ/trace at WB
commits that instruction, cancels younger ID/EX work, and supplies the committed
next PC to the existing exception sequencer. Unsupported operations and empty
queues drain before returning to the old sequencer. The register file and SR
remain shared; there is no duplicate architectural state.

Validation: all 8,608 independent-oracle snapshots match; all 14 program suites
pass; immutable first-100 silicon corpus has **1,900 matching field groups and
zero real differences**. A directed full-pipeline IPL test injects three
interrupts across the bench's bus-delay modes, cancels six younger instructions,
checks that the stacked PC exactly matches the committed ADD count, and verifies
complete replay after RTE. Standalone tests also cover cancellation with both
accepting and blocked WB. Logs: `scratch/pipeline_p1b/`; corpus log identifies
its immutable source/payload hashes and artifact directory.

This first overlap experiment is **slower on the directed workloads**, because
short supported runs pay entry/drain costs and the experiment disables the
existing lookahead dispatch. It must not be presented as a speed improvement:

| Phase-0 workload | Default core cycles | P1b cycles |
|---|---:|---:|
| straight-line 8,608-instruction payload | 39,058 | 39,064 |
| bench_loop | 68,100 | 158,590 |
| pipe_bench | 110,696 | 136,660 |
| branch_bench | 119,284 | 164,246 |

No P1b hardware deployment is planned. Preserve existing fast paths for short
runs and extend operand handling before selecting a performance candidate.
The experiment remains behind `AP040_EXPERIMENTAL_PIPELINE`; release builds do
not enable it. `CPU_GATE_PIPELINE=1` enables it in `cpu_corpus100_gate.sh`.
The hardware target requested for continued work is now **at least 1.8 Mix**,
with repeated valid hardware measurements, unchanged authentic clock, and
invalid timer results reported separately.


## First measured hardware candidate: refill-target load decode

Following P1b's negative result, the default sequencer now predecodes MOVE.B/W/L
from `(An)`, `(An)+`, `-(An)`, or `d16(An)` to Dn when the branch refill buffer
supplies the target word. This selects the existing operand pipeline and RF
ports during target installation, eliminating one S_DECODE cycle. It does not
issue memory speculatively or create a decoded-instruction cache; the existing
refill buffer's instruction bytes and invalidation rules remain authoritative.
The ordinary memory arbitration, undo records, and fault paths are reused.
`AP040_DISABLE_REFILL_LOAD_DECODE` is the diagnostic comparison switch.

Phase-0 `bench_loop` improves **68,100 -> 55,916 cycles** (17.89% reduction,
1.218x throughput). `pipe_bench` remains **110,696**, `branch_bench` **119,284**.
These are directed workload results, not a measured Speedometer improvement.
The original 25 self-tests pass. A new `t_refill_load` program also passes all
three standard bus-delay modes: 20 size/addressing combinations, preserved
upper Dn bits and X, signed displacement, An update, and A7 byte stride.
The first-100 silicon corpus again has zero real differences in 1,900 field
groups. `tb_line_dma` passes 16,000 reads, 2,029 stores, 12,766 line acknowledges
and 11,026 DMA beats with zero errors. Logs: `scratch/pipeline_p1b/refill_load_*`.
The full-machine build of this candidate keeps the experimental pipeline off.


## Next operand-engine design constraints

The prepared `pipeline_address_oracle.py` fixture independently checks 6,048
snapshots of all 16 integer registers against the real core. Its proposed
MOVE Dn/An, ADDQ/SUBQ and ADDA/SUBA/CMPA coverage, combined with P0, accounts for
38.01% of observed opcode loads in the old September 15 profile (versus P0's
12.64%). This is a coverage measurement, not a predicted speedup. The private
prototype must model A7 correctly, and integrated execution must retain the
core's live S/M bank selection. MOVEA.W and address arithmetic word operands
sign-extend before full-width execution; address quick operations preserve CCR.

After those register semantics, the first memory instruction should be a
non-updating `(An)` load to Dn. Start with one outstanding operand transaction:
EX holds its metadata under a variable-latency request, older WB may retire,
and younger ID cannot pass it. The core retains sole ownership of the external
memory port and arbitrates against instruction refill. Only issue after older
work is committed; reject an issue on the same edge that an older retirement
recognizes IRQ/trace. Do not assume a logical RAM-looking address cannot map to
I/O. Serial issue at the architectural head avoids consuming speculative device
state regardless of the eventual translation/cache attributes.

A load fault needs the load's PC/opcode/size/address and existing access-error
context, not the advanced fetch PC or last committed instruction. No partial
Dn merge or CCR write may occur on fault. A valid acknowledge can complete the
load, then a pending IRQ cancels younger work at its retirement. First cover
hits, misses, CE pauses, translation errors, physical errors and interrupt
arrival during a wait. Unsupported or unaligned cases must return to the
sequencer without losing/replaying older commits. Postincrement/predecrement
and multi-write retirement come later, with explicit rollback tests.

Variable-length immediate and d16 instructions require an input word count
and acknowledged resident extension words. If an entire instruction is not
resident (especially across a page), leave it to the existing demand-fetch
path rather than stalling forever on a same-page-only speculative refill.
Branches require a retirement redirect that cancels only younger work and
uses the actual taken/fallthrough PC for an interrupt frame. These are required
contracts before broadening issue; a fast register-only throughput number is
not a substitute for them.


Full-machine candidate fit, seed 21, build commit `f7b8e1f`: **36,657 ALMs
(87%)**, worst setup **+0.343 ns**, worst hold **+0.214 ns**. CPU setup
+0.671 ns; SDRAM setup +0.524 ns. Separate crossing reports pass:
`req_tgl -> req_handoff` **+1.290 ns**, RAM-to-system worst **+0.671 ns**.
Build and cross-domain STA both exited zero. Archived RBF/reports/identity:
`scratch/refill_load_fit_20260919/`. Hardware measurement remains outstanding.


## P1c: full integer register addressing and quick arithmetic

The experimental pipeline now handles Dn/An register MOVE/MOVEA, ADDQ/SUBQ,
ADDA/SUBA/CMPA, and An sources for ordinary non-byte ADD/SUB/CMP. Source/destination
indices are four bits, with the core's existing A7 bank selection. A shared
53-bit decode record drives admission and ID. Word address operands sign-extend
before full-width execution; address writes preserve CCR except CMPA.

The combined independent workload has **14,720 instructions**, including
adjacent An dependencies, and matches all 16 register values and CCR after each
instruction in both standalone pipeline and actual core integration. All six
scheduling/cancellation modes pass; all 65,536 opcode admissions are checked.
Disabling only An forwarding is detected at instruction 8,770, proving those
hazards are exercised separately from Dn hazards. The 14 real-core program
suites, full-pipeline IRQ/replay test, and first-100 silicon corpus pass again.
Reproduce: `python3 scripts/cpu/pipeline_handoff.py --extended --out NEW_OUTPUT`.
Artifacts: `scratch/pipeline_p1c/` and `prototype_extended/`.

The long simulator Speedometer attempt was stopped after screenshot f5311
proved its historical navigation had launched Prince of Persia. No benchmark
number from that attempt is accepted. Hardware is the performance authority.
The hardware original/test-copy disk hashes now match, and the user authorized
resets/recovery on the disposable copy after preserving the original.

P1c standalone Quartus fit completed successfully at commit `5e1b158`: **714
ALMs**, 341 registers, no RAM/DSP blocks. At 33 MHz, worst setup is **+12.942
ns**, worst hold **+0.139 ns**. Reports: `scratch/pipeline_p1c/standalone_fit/`.
This is the isolated execution module, not a full-machine pipeline fit.


## P1d: retain sequencer lookahead outside pipeline ownership

The experimental integration again permits the existing descriptor, operand and
branch lookahead while the sequencer owns execution. Entry remains at S_DECODE
after pending writes settle; pipeline retirement cannot hand an opcode to the
sequencer. `AP040_PIPELINE_FORCE_DECODE` preserves the older diagnostic mode.
The straight-line trace now distinguishes pipeline WB, sequencer retirement,
and the fetch-only S_NEXT boundary after a pipeline drain.

All 14,720 oracle snapshots, 14 real-core suites and precise IRQ/replay pass.
Cycle counts with the experimental pipeline enabled are 56,916 (`bench_loop`),
123,176 (`pipe_bench`) and 149,256 (`branch_bench`). The default refill-load
candidate remains faster at 55,916 / 110,696 / 119,284. These results recover
much of the old regression but do not justify a hardware pipeline candidate.
Artifacts: `scratch/pipeline_p1d/`.

P1d first-100 silicon corpus: 1,900 field groups match, zero real differences
(`scratch/pipeline_p1d/corpus.log`, `/tmp/cpu-corpus100-gate.5OiVFE`).


P1e removes the empty-pipeline S_NEXT bubble by using the normal fetch/IRQ/trace
boundary directly after all stages drain. Descriptor dispatch may run at that
drained boundary; overlapping retirement still cannot pass control to it.
All 14,720 snapshots, 14 real-core suites, directed IRQ/replay and first-100
silicon corpus pass (1,900 matching field groups, zero real differences).
Artifacts: `scratch/pipeline_p1e/`, corpus `/tmp/cpu-corpus100-gate.d4d2eS`.
Cycles: **56,716 / 120,180 / 140,264** for loop/call/branch benches. These remain
slower than the default production candidate; pipeline stays disabled in it.


## Exact recursive Permutations diagnostic

`python3 scripts/cpu/profile_permute.py RESOURCE --out OUTPUT` verifies the
original resource hash, extracts the 200-byte Swap/InitPermute/Permute region,
and loads it at its original CODE 3 addresses. One n=7 invocation must perform
8,660 calls (T(1)=1, T(n)=1+n*T(n-1)), restore its array, and preserve guards.
The real `wombat_cpu` MMU/cache/store buffer wraps a controlled-latency RAM
responder. This does **not** reproduce the SDRAM platform or predict a Mix.
The original timed wrapper invokes this routine 25 times; the diagnostic uses
one call plus checked setup/return code and no guest timer or OS navigation.

Default-core cycles for 0 / 3 / 8 extra RAM wait cycles are **1,799,168 /
2,157,673 / 3,092,466**. All count/array/guard checks pass. Reproduction logs
and source hashes: `scratch/permute_repro_20260919/`. The old 16-bit compatibility
wrapper took 2,670,817 cycles and is not the machine's data path; use the 32-bit
wrapper for further operand experiments.

A conservative retained-data-line prototype improved these to 1,775,837 /
2,134,602 / 3,072,093 cycles, only about 1.1% at latency 3. It was archived,
not retained in RTL or selected for fitting. Patch and source are preserved in
`scratch/permute_dline_20260919/`; it received kernel checks, not a full cache
regression gate. The stronger next hypothesis is cross-line stack stores:
those currently invalidate both data-cache sets, potentially forcing later
recursive stack loads to refill. Investigate before implementing more logic.


## Posted cross-line store candidate

`AP040_EXPERIMENTAL_XSTORE` enables a bounded cache change: a cacheable store
that crosses a 16-byte line and is already qualified for non-faulting posting
updates each resident half after downstream acknowledgement. The first merge
uses the existing store lookup; two additional states read and merge the second
row. Different hit ways and set/tag wrap are handled independently. Other
writes retain the original invalidation path. The cache remains busy to the
MMU walker until the delayed merge finishes. No speculative memory access or
additional architectural write is introduced, and the register pipeline stays
disabled in the selected hardware configuration.

Free-running invalidations of the second row are remembered across CE pauses;
no invalidated row is revalidated. A defensive unexpected posted-write error
invalidates both affected rows, including the partial physical-write case. This
does not claim architectural rollback for a store already promised non-faulting.

All 26 existing CPU checks pass with the feature compiled, including the cache
snoop/fill/error suite. The new byte-addressed cache bench passes **100 cases**:
all crossing sizes/offsets, posted and ordinary writes, both/one/neither line
resident, different hit ways, preservation of unrelated ways, set/tag wrap,
snoop timing sweeps, CE-frozen snoops, and partial physical-write error recovery.
Disabling the second merge is detected by the independent byte comparisons.
The bench is added to the standard suite (now 27 checks). First-100 silicon
corpus: 1,900 matching field groups, zero real differences; artifacts in
`scratch/xstore_gate_20260919/`, corpus `/tmp/cpu-corpus100-gate.1r6wG2`.

Exact Permute cycles at 0 / 3 / 8 extra RAM wait cycles become **1,538,989 /
1,588,970 / 1,927,971**, versus **1,799,168 / 2,157,673 / 3,092,466**. At latency
3 this is a 26.36% cycle reduction. Recursion count, array and guards pass in
every run. Artifacts: `scratch/permute_xstore_20260919/`; final-source reproduction
at latency 3 is `scratch/permute_xstore_final_20260919/`.
Combining it with the experimental register pipeline takes **1,680,485** cycles,
so the hardware candidate enables only XSTORE. These are controlled-memory
kernel results, not a predicted Speedometer Mix. Quartus/hardware gates follow.


The isolated exact Towers probe also passes: original CODE 3 bytes
`0x95f0:0x9888` (664 bytes, SHA-256
`d220be94a7c8f839a679a0ad4560c280655771abe0e8bdab1e7ed28205e76374`),
loaded at their original addresses, execute the original three Tower-14 passes.
At controlled RAM latency 3, baseline takes **34,118,877 cycles**, XSTORE
**29,647,247 cycles** (13.11% fewer). Both finish with 16,383 moves in the final
pass, target stack ordered 1..14, the remaining four nodes in the free list,
all 18 nodes unique and accounted for, empty source/auxiliary stacks, and intact
guards. Evidence and source hashes: `scratch/towers_probe_20260919/identity.json`
and its two run logs. This scratch-only probe uses actual wombat_cpu with a
controlled RAM responder; it does not model platform SDRAM or predict Mix.

Full-machine XSTORE fit at c328ae7, seed 21 passed: 36,871 ALMs (88%), 491 RAM
blocks, 43 DSP; setup +0.068 ns, hold +0.243 ns. CPU +0.979 ns, SDRAM +0.800 ns;
sys->ram +1.514 ns and ram->sys +0.979 ns. RAM inference preserved. Archived
reports and SHA-verified unique RBF: `scratch/xstore_fit_20260919/`. Five-run
hardware evaluation is now assigned to the operator; no new Mix result yet.


## LEA displacement overlap candidate

The exact Towers opcode-attribution probe (cycles charged to the live IR, not
retirement CPI) puts LEA d16(A5),A0 at 12.43% of cycles with XSTORE enabled.
Evidence: `scratch/towers_probe_20260919/profile_top.txt`. The new opt-in
`AP040_EXPERIMENTAL_LEA` selects the base register while the existing immediate
fetch task obtains d16(An), then retires LEA at completed displacement arithmetic.
PC-relative LEA also retires at completed displacement arithmetic; its fetch
path remains unchanged. The existing IRQ/trace retirement task and extension
fault handling are reused. No operand bus access or CCR write is introduced.
The QSF selects XSTORE plus LEA for the next fit; the register pipeline stays off.

All 27 existing CPU checks pass with both macros compiled. New compact tests
cover all 64 source/destination An pairs at five signed displacement values,
CCR preservation and successive dependent LEAs, in all three bus modes. A
separate demand extension fault at a page boundary verifies no destination
write and the precise format-7 frame PC, also in all three modes. Compact test
assembly is byte-identical to the executed 320-case fixture. Both tests are now
in the normal runner (29 checks); `CPU_TEST_LEA=1 CPU_TEST_XSTORE=1` enables the
features and `CPU_TEST_WORK` selects an isolated output directory. Existing27
plus the two separately executed programs were checked; no claim of a second
full29 run. First-100 silicon corpus: 1,900 field groups match, zero differences
(`/tmp/cpu-corpus100-gate.pZcv2X`, `scratch/lea_gate_20260919/corpus.log`).

Controlled latency-3 original Towers: XSTORE 29,647,247 -> XSTORE+LEA 27,509,911
cycles (7.21% fewer), with all count/list/guard checks passing. Original Permute:
1,588,970 -> 1,577,469 (0.72% fewer), all count/array/guard checks passing.
Evidence: `scratch/towers_lea_20260919/`, `scratch/permute_lea_20260919/` and
`scratch/lea_gate_20260919/`. These remain kernel checks, not Mix predictions.


LEA full-machine fit94d922f passed at seed21:36,997ALMs88%,491RAM,43DSP;
setup +0.311ns,hold +0.238ns,CPU +1.025ns,SDRAM +0.555ns; both crossing reports
positive (+0.555/+1.025ns). Cache RAM inference retained. Archived reports and
unique RBF are in `scratch/lea_fit_20260919/`; five-run hardware trial is assigned.

A scratch-only P2 load prototype now exists in `scratch/pipeline_load_p2_20260919/`.
It admits MOVE.B/W/L (An),Dn with one head-ordered read, stable request until
acknowledgement, response capture across CE pause, cancellation drain, and a
fault retirement token with no register write. Four latency schedules and an
independent768-retirement/192-load oracle pass; a premature-read mutation fails.
Loads-disabled compatibility passes all14,720register snapshots in six schedules
and both forwarding negative controls. This is not integrated with the real
MMU/cache/exception owner and is not a performance claim; see its README.md for
contracts, remaining integration and limitations.


## P2: ordered pipeline loads through the existing memory sequencer

`AP040_EXPERIMENTAL_PIPELINE_LOADS` (also requires the experimental pipeline)
adds MOVE.B/W/L (An),Dn. The pipeline presents one head-ordered read only after
all older WB work commits. The core routes it through existing mrd/S_MRD and
page-split states; the ordinary access-error sequencer builds faults using
latched load PC/opcode. There is no second RF, MMU, cache or store buffer.
Pipeline integer read-port ownership remains active across the memory return,
including CE pauses. A directed partial-write test caught an initial error in
that ownership window; it was fixed before acceptance of the following results.

Validation with the corrected source: 14,720 shared-state snapshots, 14 existing
real-core suites, existing three-injection IRQ/replay check, and immutable
first-100 silicon comparison (1,900 fields, zero differences). Artifacts:
`scratch/p2/load/`, `scratch/p2/corpus.log`, `/tmp/cpu-corpus100-gate.7aG7mL`.
Two forced-admission programs additionally check all192An/Dn/BWL combinations,
partial writes/CCR, odd and page-crossing reads, and a real bus fault preserving
Dn/younger state with precise format-7 PC/address; all three bus modes pass.
A new interrupt-at-load test checks the frame names the following instruction,
load data commits, younger ADDQ is cancelled/replayed exactly once, and completes
three injections/three cancellations. Evidence `scratch/p2/direct/`.
The runner now includes these directed programs and IRQ test when --loads is
selected, forcing admission only for these directed tests.

Reproduce the integrated gate with:
`python3 scripts/cpu/pipeline_handoff.py --extended --loads --xstore --lea --out scratch/p2/new`.
Use a short output path: legacy benches have a128-byte filename field.
--loads is also available with --pipeline in profile_permute.py; optional
--force-decode disables the old lookahead to diagnose actual coverage.

At latency3, normal lookahead Permute takes **1,668,981 cycles**, with56,236
pipeline issues but **zero pipeline loads**. Forced decode exercises10,078loads
and83,646pipeline issues, taking **1,929,759 cycles**. Both pass the unchanged
kernel result checks. Production XSTORE+LEA takes1,577,469cycles. The P2 path is
therefore a correctness checkpoint, NOT a faster hardware candidate; neither
pipeline macro is selected in QSF. Next work is reducing load handoff overhead
and covering extension-bearing operands while retaining useful old fast paths.


## P2 load handoff follow-up

Registered load requests now supply the existing data-cache hint and can issue
through the aligned in-place path. Ordinary read acknowledgements forward into
pipeline WB directly; split reads retain the buffered return. The pipeline
buffers responses when CE is paused or WB cannot advance.

Final combined gate passed in `scratch/p2/direct_gate.log`: 14,720 oracle and
shared-state snapshots, six stall schedules and negative controls, all 14 prior
real-core suites, both directed load programs, and both precise IRQ/replay tests.
Current-source first-100 silicon comparison passed (1,900 field groups, zero real
differences) in `scratch/p2/direct_corpus.log`. Standalone response tests passed
at delays 0/1/3/8, including CE pauses, WB stalls, cancellation and fault handling;
the independent 768-retirement/192-load oracle passed (`scratch/p2/response_unit/`).

Forced-load Permute at latency 3 improves from 1,929,759 to **1,899,527 cycles**
with 10,078 loads. Matched forced register-only control takes 1,849,139 cycles;
production XSTORE+LEA takes 1,577,469. Thus this removes about three cycles per
load but remains slower overall. Pipeline macros remain off in QSF; no new
hardware performance claim or full-machine pipeline fit is made.

Latest accepted hardware Mix remains median **1.005** across five valid LEA
runs. The 1.8 goal remains unmet. A/UX compatibility is pending: its image and
backup named in the notes are absent from MiSTer and the searched local fixture
paths; the user has been asked for their location.
