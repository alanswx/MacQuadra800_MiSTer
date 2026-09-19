# P6 broader resident-instruction pipeline experiment

P5 fixes the pipeline RF timing path but leaves Speedometer Mix essentially
unchanged (five-run median1.006). P6 extends the supported instruction stream
so fewer indexed-memory and integer operations return to the legacy sequencer.
It is an opt-in experiment, not a validated release or a1.8Mix result.

`AP040_EXPERIMENTAL_PIPELINE_P6` enables register shifts/rotates (all sizes,
register/immediate counts), LEA d16(An),An, brief indexed MOVE loads to Dn/An
and register-to-brief-indexed stores. Missing or full-format index extensions
fall back. Memory operations use the existing ordered request, fault and
retirement mechanism. MOVEA preserves CCR and sign-extends word loads; partial
Dn loads preserve upper bits. Zero-count shifts explicitly implement N/Z/V/C/X.

A fifth RF mirror supplies the third pipeline operand: old destination for
partial loads or base address for indexed stores. The other two pipeline ports
supply source/base and index. Each uses retirement forwarding; every mirror
shares the architectural write, delayed-write bypass and banked A7 semantics.
The legacy sequencer retains its independent two read ports. There is no extra
architectural register file or bulk state transfer.

The QSF trial uses unrestricted entry. The PEA-only option now explicitly
recognizes PEA rather than treating every two-word instruction as PEA. The new
module feature parameters and core P6 switch default off.

## Measurements before fit

Controlled-latency real CPU/MMU/cache/store-buffer simulation, exact Speedometer
kernel bytes, three Towers passes and one Permute pass:

| Entry/configuration | Towers cycles | Permute cycles |
|---|---:|---:|
| P5 production PEA-only |27,509,911|1,519,907|
| P6 unrestricted |26,445,814|1,527,183|
| P6 selective |26,550,438|1,526,387|

Towers improves3.87% over production; Permute costs0.48% more. These are kernel
cycle measurements, not a prediction of hardware Mix. Quartus area/timing,
RAM inference and at least five valid hardware Mix runs remain required.

## Reproduction

From the repository root, with Python3, Icarus Verilog and the existing vasm
fixture available:

```bash
python scripts/cpu/pipeline_p6_load_oracle.py --out scratch/pipeline_p6
python scripts/cpu/pipeline_p6_store_oracle.py --out scratch/pipeline_p6
python scripts/cpu/pipeline_p6_alu_oracle.py --out scratch/pipeline_p6
python scripts/cpu/pipeline_p6_negative.py --out scratch/pipeline_p6
python scripts/cpu/pipeline_p6_faults.py --out scratch/pipeline_p6
python scripts/cpu/pipeline_p6_boundaries.py --out scratch/pipeline_p6
python scripts/cpu/pipeline_handoff.py --extended --loads --stores --pea --p6 --xstore --lea --out scratch/pipeline_p6/handoff
CPU_GATE_PIPELINE=1 CPU_GATE_PIPELINE_LOADS=1 CPU_GATE_PIPELINE_STORES=1 CPU_GATE_PIPELINE_PEA=1 CPU_GATE_PIPELINE_P6=1 CPU_GATE_XSTORE=1 CPU_GATE_LEA=1 bash scripts/cpu_corpus100_gate.sh rtl/ap68040/rtl scripts/fixtures/corpus100/cpu.hex scripts/fixtures/corpus100/results.bin
```

Set `CPU_GATE_VERILATOR` to the Verilator5 executable if needed. The negative
runner consumes the three oracle fixtures and requires deliberate mutations to
fail. Fault/boundary runners use forced admission for instruction coverage;
the main handoff and silicon gates use unrestricted admission for the candidate.

Positive evidence in `scratch/p6_promoted_20260919/`:

- Indexed load/store oracles each check13,166retirements and5,120requests across
  eight delay/stall schedules, including aliases, sizes, index widths/scales,
  signed offsets, actual addresses/data, CCR and all registers.
- Bit-by-bit shift/rotate and signed LEA oracle checks61,424retirements in six
  schedules, including stalls and cancellation/replay.
- Three indexed data-fault cases and six extension-fault/trace/IRQ cases check
  precise exception frames, preserved state, requests and younger cancellation.
- All six semantic mutations are detected: partial merge, store base, third
  operand forwarding, zero-count ROX carry, LEA sign and destination forwarding.
- RF test checks2,637,520port values over16,485cycles, including collision
  poisoning and negative controls for all three bypass groups.
- Full promoted real-core gate passes14,720shared snapshots, all14legacy suites,
  load/store/PEA fault/trace fixtures and all four original IRQ/replay monitors;
  `scratch/p6_promoted_gate.log`.
- First100silicon comparison:1,900matching field groups, zero differences;
  `scratch/p6_promoted_corpus100.log`. This is not the complete CPU corpus.

A/UX validation is explicitly deferred to Dani at the user's request. Mac boot,
shutdown, CD/audio and hardware performance checks still apply to the candidate.

## Targeted-entry follow-up

The unrestricted P6 hardware trial regressed: five valid Mix runs have median
0.963 versus P5's1.006, with no timer outliers. Towers improved but several other
integer tests slowed down. See measurements section28; no release was made.

`AP040_PIPELINE_MEMORY_ENTRY` now selects a narrower entry rule while retaining
P6's instruction support inside an active stream. Start at brief indexed MOVE
or PEA, leaving isolated cheap register instructions and LEA on legacy fast
paths. A resident brief indexed MOVE must also bypass the legacy lookahead
consumer to reach this admission point. Merely restricting S_DECODE entry left
Towers with zero pipeline issues because lookahead had already consumed them.
The extension must be resident and brief-format; existing queue flush and
exception checks still qualify the original lookahead pop.

ID admission may overlap the preceding registered RF write. Operands are read
later in EX, using the existing architectural RF and pending-write bypass.
The auxiliary-write exclusion remains. Both changes default off with the new
switch, and no P7compare or P8call additions are included.

Exact-kernel scratch measurements: Towers26,600,632cycles versus P5's27,509,911
(-3.31%); Permute1,519,907, exactly matching P5. These do not prove hardware Mix.

Reproduce the selected recipe with `--p6 --memory-entry` on pipeline_handoff.py
and `CPU_GATE_PIPELINE_P6=1 CPU_GATE_PIPELINE_MEMORY_ENTRY=1` on the silicon gate,
alongside the existing pipeline/load/store/PEA/XSTORE/LEA switches. The normal
register-only reference intentionally has zero pipeline admissions, so also run
the handoff's `--only-reference --force-decode` case to verify pipeline coverage.
Run the exact-policy boundary and predecessor-write checks with:

```bash
python scripts/cpu/pipeline_p6_boundaries.py --memory-entry --out scratch/pipeline_entry
python scripts/cpu/pipeline_entry_faults.py --out scratch/pipeline_entry
```

The latter executes ADDQ.L#4,A0 immediately before indexed MOVEA.W, MOVE.W to Dn
or indexed store, then checks precise access-error state. Its monitor requires
admission with rf_we high in every latency phase, not just matching final output.

### Exact candidate profile during the targeted-entry fit

The committed 90b37e4 recipe reproduces Towers at **26,600,632 cycles**
with 1,327,424 pipeline issues, zero empty pipeline exits and all result,
list and guard checks passing. Pipeline ownership occupies 2,704,557 cycles.
The reproducible scratch driver and source SHA manifest are in
`scratch/p6entry_profile_20260919/` (`run.py`, `normal_identity.json`,
`normal_run.log`). Frozen build sources were not changed.

The same binary with the controlled RAM responder's added delay changed from
3 to 0 passes at **25,399,026 cycles**, a 4.52% reduction. This is sensitivity
to that model parameter, not zero memory latency, a full-machine result, or
a hardware performance ceiling. The caches are enabled (CACR 0x80008000).

Current-IR/state occupancy for MOVEM store/load, RTS, LINK, JSR(pc), and UNLK
is preserved as STACK_STATE rows. These include fetch/handoff time and are
not individual retired-instruction latencies. Global read-wait state occupies
5,834,210 cycles, write-wait 3,725,312, decode 2,849,915 and fetch 2,100,260.

A second instrumentation run reproduces exactly 26,600,632 cycles and counts
353,091 same-line spanning read lookups, 113,826 cross-line read lookups,
and 1,302,317 fast data hits. Of the same-line cases, MOVEM loads account
for 147,447, RTS for 94,518 and UNLK for 92,385. Removing one cycle from
every same-line case would save only 1.33% in this run before any secondary
effects; this does not justify prioritizing a split-cache shortcut over
broader pipeline execution/handoff improvements. Existing cache support
already assembles spanning reads; they are not all external-memory bypasses.

The background fit remains active under q800-p6entry-fit-20260919.service;
wait for terminal build, source-hash verification and crossing extraction
before editing any build inputs or deploying its uniquely named RBF.

### Scratch follow-up: retire directly into legacy lookahead

`scratch/p6_drain_lookahead_20260919` tests returning to the legacy decoder
on the final WB commit when ID/EX and the pending-memory slot are empty.
The prototype exports `empty_after_retire` separately from the strict `idle`
signal. Both the exit condition and the legacy lookahead ownership guard
must use the new boundary. Pipeline interrupt cancellation retains priority.
No tracked RTL or frozen Quartus inputs have changed.

| Exact kernel, latency 3 | 90b37e4 control | Corrected scratch handoff |
| --- | ---: | ---: |
| Towers | 26,600,632 | 26,403,899 |
| Permute | 1,519,907 | 1,519,901 |

Both pass their result and guard checks. Towers improves 0.74%; this is a
small simulation gain, not evidence of hardware Mix improvement. The control
Permute was rebuilt from current tracked sources with the same bench/flags.

Initial `p6_early_drain_20260919` changed the exit but accidentally retained
the idle-only lookahead suppression: Towers26,551,441, Permute1,569,674.
A memory-port guard (`p6_guarded_drain_20260919`) did not change those numbers.
The lost call shortcut was caused by that separate lookahead suppression,
not the hypothesized busy port. Correcting the ownership guard removes the
regression. Keep both unsuccessful probes as evidence; do not promote them.

Corrected prototype passes all six indexed extension-fault/trace/IRQ cases
and all three predecessor-write fault cases. The full integration gate is
still running; its reference has14,720matching snapshots with zero pipeline
entries under the restricted policy, and integer suite has9commits. Neither
that reference nor kernel checks alone prove the new handoff safe. Remaining
qualification includes full gate completion, forced-reference coverage,
explicit final-WB handoff coverage and silicon first100 before promotion.

### Targeted-entry fit terminal and handoff qualification complete

The90b37e4 fit ended17:42:49EDT; crossing extraction ended17:42:54.
Fitter succeeded:39,603ALMs(94%),26,364registers,491RAMblocks,43DSP.
SetupCPU +0.904ns, SDRAM +0.608ns, HDMI -0.187ns(TNS -0.568),
worst hold +0.208ns; crossing minima sys→ram +0.608 / ram→sys +0.904.
RFbankE remains512bitMLAB and cache tags M10K. Source hashes and crossing
extraction pass. build.exit1 denotes the HDMI timing miss; trial authorized
under the existing marginal-fit instruction, release timing bar not met.
Archived RBF4,542,356bytes SHA256
`d35e6b42edb653aab94cb95f6a5a92eefea8d8cf9b640d679a5b7055ca95df68`.
Operator initially observed before extraction completed; terminal recheck
found cross.exit0 and the uniquely archived RBF. Five-run hardware trial
is delegated to the existing operator; results remain pending.

The separate corrected early-drain scratch candidate now passes full normal
integration (all legacy/memory/PEA suites and4IRQ/replay cases), forced
reference14,720retirements, and silicon first100:1,900groups,zero differences
(`/tmp/cpu-corpus100-gate.MPe9nl`). Its six boundaries and three RF-write
fault cases also pass. `handoff_edges.py` proves12actual final-WB handoffs:
three each into dependent TST(An), DBcc, CMPI.L and JSR with updatedA7.
All3latency/CE phases check flags, registers, stack values and no residual
pipeline work after handoff. Early drain remains scratch-only pending a
clean opt-in implementation and exact promoted-recipe checks.

### Additional workload: original Bubble sorting loop

`scripts/cpu/profile_bubble.py` extracts unchanged CODE3bytes0x9586..0x95d1
from the hash-verified Speedometer4.02 resource. It runs the original sorting
loop on500distinct signed words shuffled with seed20260919, then independently
checks all sorted values and adjacent guards. Initialization, allocation and
the original five-iteration wrapper are excluded; the exit RTS is outside
the preserved loop bytes. The resource is supplied locally, not redistributed.

Reproduce with `python3 scripts/cpu/profile_bubble.py RESOURCE --out OUTPUT`
and optionally `--compare-module PATH` to hold core/entry flags constant while
changing only the experimental module. RAM latency3; real MMU/cache/storebuffer
wrapper, no full-platform SDRAM/retained-line model. Results in
`scratch/bubble_probe_20260919`: current90b37e4 **4,577,936cycles**, prior
P7compare module with current memory-entry policy **4,492,550cycles**(-1.87%).
Both sorted-permutation/guard checks pass; data read/write counts identical.
This expands diagnostic workload coverage, not hardware Mix validation or
full qualification of the combined P7/current-policy configuration.

### Promoted opt-in final-WB handoff

`AP040_PIPELINE_EARLY_DRAIN` selects the qualified final-WB exit and matching
legacy lookahead guard. It defaults off and is not yet enabled in QSF.
The pipeline exports `empty_after_retire` separately; strict `idle` retains
its prior meaning. `pipeline_handoff.py`, P6 boundary and entry-fault runners
accept `--early-drain`; the silicon runner uses
`CPU_GATE_PIPELINE_EARLY_DRAIN=1`. New `pipeline_drain_edges.py --out OUTPUT`
checks the12dependent final-WB handoffs.

Exact promoted option passes that directed check, six boundary cases, three
entry-fault cases, forced reference14,720retirements, default-off forced
reference14,720retirements, and first100silicon1,900fieldgroups/zero differences
(`/tmp/cpu-corpus100-gate.sEqLlv`). Standalone prototype six schedules and
both forwarding mutation controls pass. The newly exported port initially
failed wildcard testbench elaboration; all three wildcard benches now
explicitly leave the status output unconnected, and affected checks reran.
The full promoted integration gate is terminalPASS, including all14legacy
suites, memory/PEAfault/trace and4IRQ/replay cases. Log:
`scratch/drain_promoted_gate.log`.

Bubble with promoted early drain alone: **4,514,530cycles** (-1.385% from
4,577,936). P7compare plus early drain: **4,429,205cycles** (-3.25% overall).
Both pass exact sorted-permutation/guard checks; total data transactions
unchanged. The optional compare module must implement the current output
interface; `scratch/p7_drain_compare_20260919/ap040_pipeline_integer.sv`
adapts the old scratch module by adding only `empty_after_retire`.
The combined compare feature is not yet promoted or fully qualified.
