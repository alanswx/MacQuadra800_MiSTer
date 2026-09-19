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
