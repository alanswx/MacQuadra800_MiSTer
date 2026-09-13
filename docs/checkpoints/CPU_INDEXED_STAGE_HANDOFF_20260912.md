# Indexed extension staging candidate

Final status: seed-24 hardware passed at 0.450 / 0.451 / 0.450 versus 0.447.
The tested CPU is now adopted in the uncommitted working tree. MiSTer cleanup
is complete. See [accepted checkpoint](../CPU_INDEXED_STAGE_CHECKPOINT_20260912.md).
The staged pending/not-adopted notes below record the experiment chronology.

Candidate core SHA256:
`16fc1cc1f7f7e4295cbacf6c5449f2aa485d72290f27d75a3af687a2c7c8c79e`.
Baseline accepted compact core:
`5ab7603019ab43ffb10bcdc5ef80086d2b0a5b515abd7fdd64d9adfaf0d0f3ff`.
The refill experiment is NOT included. Exact preserved patch:
`docs/checkpoints/cpu-indexed-stage-experimental-20260912.patch`.

## Change and safety reasoning

When S_IMMF consumes the final single extension word for S_EA_EXTW and no
registered RF/aux write is pending, capture the existing EXTW bookkeeping on
that edge and enter existing S_EA_EXTW2. Captures are extw, rr_b index selection
and base value. No address arithmetic, legality test, EA read/write, exception,
prefetch ownership, or architectural register write is changed.

- Both queue-resident and same-edge forwarded words use the same selected
  word for `imm`, `extw` and `rr_b[3:0]`.
- No extra EA adder or ready flag is added. The original EXTW2 performs all
  brief/full-format arithmetic, scale/sign extension, suppression/indirection
  and illegal-encoding checks unchanged.
- Port A base is already selected by ea_start before S_EA_DISP; it remains
  stable while S_IMMF waits. Port B gets a full qualified edge to settle before
  EXTW2 reads it, exactly as with the original EXTW stage.
- A pending rf_we or aux_we takes the old EXTW path, preserving visibility of
  registered writes and banked A7. No new forwarding network is needed.
- Only existing EXTW callers are S_EA_DISP indexed An / PC forms, all one-word
  immf calls. The S_DECODE immediate-consumption shortcut cannot currently
  reach this return state. Other immediate lengths/return states are unchanged.
- The original EXTW path remains as a safe fallback for pending writes and any
  future caller. Full extension forms are accelerated but not reimplemented.

Directed source is in `regression/tb/asm/t_index_stage.s` (14 architectural
checks), with optional `index_pending_probe.sv` simulation-only injection of
no-op A0 and ISP writes to prove the guarded old-stage fallback. Ordinary
all11/corpus runs do not instantiate/enable that injection. Baseline tests run
in a separate `directed-baseline` tree; no baseline files are overwritten.

## Partial first-pass measurements

All16 AP alignment runs pass independent D7/array/guard checks. Fifteen improve,
offset12 is unchanged, none regresses. This is not a full100 correctness gate.

| Offset | Compact | Candidate | Saved cycles |
| ---: | ---: | ---: | ---: |
| 0 | 961299 | 929919 | 31380 |
| 2 | 920158 | 888777 | 31381 |
| 4 | 913734 | 890545 | 23189 |
| 6 | 916352 | 893163 | 23189 |
| 8 | 918137 | 894947 | 23190 |
| 10 | 895668 | 887477 | 8191 |
| 12 | 907655 | 907655 | 0 |
| 14 | 915639 | 900640 | 14999 |
| 16 | 909350 | 877970 | 31380 |
| 18 | 949639 | 918258 | 31381 |
| 20 | 979967 | 956777 | 23190 |
| 22 | 945832 | 922643 | 23189 |
| 24 | 984367 | 961177 | 23190 |
| 26 | 963997 | 941527 | 22470 |
| 28 | 982073 | 959604 | 22469 |
| 30 | 961498 | 938309 | 23189 |

Actual CPU/storebuffer/SDRAM RAM-only integration profile:

| Offset | Compact | Candidate | Saved cycles |
| ---: | ---: | ---: | ---: |
| 0 | 906241 | 874866 | 31375 |
| 6 | 861298 | 838106 | 23192 |

Integration checks pass array, guards, drained stores and SDRAM protocol.
Every candidate run removes all 31381 EXTW occupancy cycles. Some savings are
hidden by subsequent service waits; deleting a state is not automatically an
equal end-to-end gain. At integration offset 6, FETCH/IMMF occupancy is unchanged
but MRD rises from 30,831 to 39,019 cycles and MWR from 69,574 to 69,575:
31,381 removed EXTW cycles minus 8,189 added memory-state cycles = 23,192 saved.
Cache/request/data transaction counts stay identical in
these integration comparisons. The few-cycle residual difference at offset0
reflects scheduling/SDRAM timing, not a changed workload or byte count.

Follow-up guard attribution proves the handoff cost at offset 6: all 8,191
baseline S_PIPE_SRD calls issue their data request early with prefetch/request/
ack guards clear. All 8,191 candidate calls coincide with the instruction
acknowledgement (all three guards set), so the existing safe path defers data
issue until S_MRD. The cache is idle in both cases; no address/size guard fails.
This adds exactly 8,191 setup clocks, partly offset by three fewer cache-fill
clocks. Both instrumented runs retain identical cycle counts and pass the oracle.
Evidence: `/tmp/wombat-sieve-mrdguard.uBSjP1/{compact,candidate}/offset-6.log`.
Changing this handoff requires protocol/fault proof, not simply removing guards.

Full original100 Sieve, all11, immutable100 corpus, focusedloop, and fullmachine
compile results are being collected by Luna; do not infer acceptance from
these partial profiles. Quartus/hardware validation requires parent approval.

Source-only fullmachine fixture:
`/tmp/MacQuadra800_indexed_seed23.hymfyf`.
QSF is identical to accepted seed23/CD-off:
`180c82c2d919b7a7d50e807e0a0499b16600c449da68b6b2643798415e6db1f1`.
No production CPU source is modified or adopted by this experiment.

## Subsequent full100 gate

Parent/Luna report actual exit0 for original unchanged full100 fixture:
cold92976362, repeat92976214, both complete array/guard checks PASS.
Accepted compact was96114461/96114314; repeat saves3138100 cycles (3.265%).
Candidate directed ordinary and pending-write runs also report ALL TESTS PASSED
with both pending-write injection kinds exercised. Baseline directed, all11,
immutable100 corpus, focusedloop and fullmachine gates remain separately
tracked by parent; no fit/hardware acceptance is implied.

Completed local gates (actual exit zero):

- Accepted-baseline directed tests also pass ordinary and pending-write cases.
- All eleven CPU suites pass (including MMU, cache, exceptions and FPU).
- Immutable corpus: 34,742,942 cycles versus 34,829,460; all 1,900 field groups
  match, zero real architectural differences. Evidence:
  `/tmp/cpu-corpus100-gate.Jnigov`.
- Focused loop unchanged: 109,010 / 109,788 / 109,788 across three phases.
- Isolated full-machine build passes; Vemu SHA256
  `1c771333b4ca2e69ab510555f2fceda562b29cff2f8cf9aca2b950a4f69b49ff`.
  Log: `/tmp/MacQuadra800_indexed_seed23.hymfyf/fullmachine-build.log`.
- Seed-23 Quartus build authorized after these gates. No hardware result yet.

Preserved new directed fixture:
`scripts/fixtures/indexed_stage/run.sh COMPLETE_AP_RTL NEW_OUTPUT`.
This copies only fixture inputs into a new isolated tree; normal regressions
and production sources never instantiate the pending-write force module.

## FPGA fit attempts

Seed 23 is rejected: 38,112 ALMs, 4,113/4,191 LABs (78 free), 24,370 registers,
462 RAM blocks, 41 DSPs. HDMI setup -0.173 ns with -0.173 TNS; CPU setup
+1.069 ns, SDRAM +0.443 ns, worst hold +0.225 ns. Quartus flow returned zero,
but this is NOT a timing-clean artifact and must not be deployed. RBF SHA256
`cbf6d330457544b12347f984236336044127c7497ff90acc7ae65b5d03cf7b2d`.
Evidence: `/tmp/MacQuadra800_indexed_seed23.hymfyf/output_files`.
Source-identical seed 24 is being fitted in `/tmp/MacQuadra800_indexed_seed24.l7hbbS`;
only the placement seed changes, not RTL or timing constraints.

Seed 24 passes: 38,027 ALMs, 4,117/4,191 LABs (74 free), 24,336 registers,
462 RAMs and 41 DSPs. CPU setup +0.724 ns, SDRAM +0.187 ns, HDMI +0.318 ns;
worst hold +0.246 ns. Every timing-summary slack is nonnegative and every TNS
is zero; parent checked exact source and artifact hashes. RBF SHA256:
`9a73e863005afe62d0e1b7137fa1c1dfb675f382238804a4d1eb31d248b87080`.
Guarded hardware testing is authorized; no score or adoption claimed yet.
