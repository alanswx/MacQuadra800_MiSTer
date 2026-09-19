# Indexed compare/test pipeline candidate

AP040_PIPELINE_COMPARE enables brief indexed CMP/TST and register TST.
The module parameter ENABLE_COMPARE defaults to0. Indexed reads retain
the existing ordered memory/fault path, compute flags without writing any
register, and compare against the third RF operand (not the EA index).
QSF selects compare with P6, targeted memory entry and final-WB early drain.
The previously rejected displacement-MOVE and experimental call extensions
are excluded.

Exact promoted validation artifacts: `scratch/compare_promoted_20260919`
and `scratch/compare_promoted_*.log`.

- Memory oracle:13,166retirements and5,120indexed requests per each of8
  latency/CE schedules; all match independent address/value/CCR/register data.
- ALU oracle:63,576retirements per each of6schedules, including registerTST.
- Both deliberate errors (wrong CMP operand and erroneous register writeback)
  are caught by semantic trace differences.
- CMP/TST extension faults, trace and IRQ:all6cases pass under actual
  memory-entry/early-drain policy without FORCE_DECODE.
- CMP/TST operand faults:bothcases×3phases pass with precise framePC600,
  faultaddressf140,CCR and unchanged destination/index/base registers.
- Forced architectural reference:14,720retirements/commits match.
- First100silicon records:1,900fieldgroups,zero differences; artifacts
  `/tmp/cpu-corpus100-gate.UX8DIV`. This is not the full silicon corpus.
- Full normal integration gate terminalPASS: all14legacy suites, memory/PEA
  fault/trace cases, and4precise IRQ/replay monitors.

Independent runners are tracked as scripts/cpu/pipeline_compare_*;
`pipeline_handoff.py` accepts --compare alongside --early-drain, --memory-entry
and existing pipeline options. Corpus runner adds CPU_GATE_PIPELINE_COMPARE=1.
The normal prototype/reference also compiles with compare disabled.

All measured exact-kernel runs preserve their result/guard checks.

| Kernel, controlled RAM latency3 | Prior90b37e4 | Combined candidate |
| --- | ---: | ---: |
| Towers | 26,600,632 | 26,256,329 |
| Permute | 1,519,907 | 1,519,901 |
| Bubble sorting loop | 4,577,936 | 4,429,205 |

Towers improves1.29%, Bubble3.25%, Permute essentially unchanged. These are
CPU-wrapper diagnostics, not a hardware Mix forecast. Bubble uses the
original sorting-loop bytes with a fixed shuffled500-word input and excludes
its allocation/initialization/five-iteration wrapper.

Next fit archive scratch/p7compare_fit_20260919; service
q800-p7compare-fit-20260919.service. Commit before launch and freeze RTL/QSF/
QIP/SDC until terminal flow and cross-domain extraction. No new hardware score
or fit claim exists yet. Latest measured hardware median1.003 remains below1.8.

## Admission and branch-handoff probes during the fit

`profile_bubble.py --profile` now records pipeline issues/occupancy, legacy
current-IR occupancy and exits. Its complete responder/checking bench is
embedded in the script; it no longer depends on ignored scratch/Towers files.
The self-contained run reproduces4,429,205cycles exactly. Current candidate
issues380,436instructions and exits63,406times at BLE.B0x6f18; pipeline
ownership occupies634,548cycles. Current-IR occupancy includes fetch/handoff
and must not be read as retired-instruction latency.

Scratch experiments preserve the frozen fit sources:

| Variant | Bubble | Towers | Permute |
| --- | ---: | ---: | ---: |
| Building1c04a43 | 4,429,205 | 26,256,329 | 1,519,901 |
| Indexed extension wait only | 4,429,205 | 26,256,329 | 1,519,901 |
| Wait plus lookahead routing | 4,327,996 | 26,256,328 | 1,519,901 |
| Above plus branch handoff | 4,203,308 | 26,207,138 | 1,519,901 |

All preserve kernel results/guards. The wait-only probe shows that S_DECODE
waiting alone is ineffective: legacy lookahead already consumed late-extension
indexed MOVE. Routing these opcodes to admission before the extension arrives
raises Bubble pipeline issues to748,500 and conditional exits to124,750 (every
sort comparison). Same-page waits retain the speculative-error/page-boundary
fallback. Full-format extensions remain unsupported and return to legacy.

Directories: scratch/p7_index_wait_20260919, p7_index_wait_route_20260919,
p7_branch_handoff_20260919. Routing variant full integration terminalPASS,
plus all12MOVE/compare boundary cases and5operand-fault cases×3phases.
It still needs explicit late/full-format fallback coverage and silicon100
before promotion.

The branch probe lets existing Bcc.B lookahead run at final pipelineWB,
forwards pipe_ccr, and adds the existing instruction-target hint. It retains
trace/IRQ, odd-target and memory-port guards. `branch_conditions.py` tests
all15supported short conditions across8CMPpatterns and3latency/CEphases:
360actual final-WB boundaries,192taken/168untaken,720pipeline commits,
all architectural checks pass. Removing the CCR forward causes actual
program failures in all3phases (before the coverage assertion), proving
the test detects stale flags. This is not complete branch qualification:
full integration is running, and targeted odd-target/trace/IRQ boundaries
and silicon100 still need checking. No prototype is part of the active fit.

## Completed P7 fit and continued qualification

The 1c04a43 seed21 fit completed with39,559ALMs (94%),26,405registers,
491RAMblocks and43DSPs. CPU setup is-0.012ns, HDMI+0.308ns,
SDRAM+0.424ns; worst hold+0.220ns. Crossings sys→ram+0.462ns and
ram→sys+0.790ns. The fifth RF bank remains a512-bit MLAB and cache
tags remain M10K. Source verification and cross-domain extraction exit0.
The build wrapper exits1 for timing; this is an authorized experimental
hardware trial, not a release-qualified image.

Archive: `scratch/p7compare_fit_20260919/`. Immutable artifact
`MacQuadra800_p7compare_1c04a43.rbf` is4,532,040bytes, SHA256
`702e23482a2203befc88b190446b68bfe182ef37a4c848057a866875305d9700`.
Hardware operator is testing this artifact on the disposable disk; no score
is available yet. Source freeze ended after terminal extraction.

The scratch admission+branch candidate now passes the full integration gate
and five boundary cases×three timing schedules: taken odd target, untaken
odd target, T1, T0 and IRQ. Each case proves three indexed-CMP pipeline
retirements; IRQ also proves three injected interrupts. The first untaken
odd fixture incorrectly expected fallthrough. Both committed and candidate
cores rejected it; existing `t_exceptions.s` explicitly verifies that the
68040 validates odd Bcc targets even for a false condition. Correcting the
fixture to check the format2 address-error frame makes both cores pass.
No RTL was changed to resolve this fixture error.

Combined-candidate silicon100 is running from an isolated copied source
snapshot. Late/full-format admission fallback remains to be explicitly
qualified before promotion. Scratch branch changes are not in the fitted
P7 artifact.

## Promoted admission and branch handoff

The next candidate now includes the late indexed-extension wait, routing
past legacy lookahead, and final-WB Bcc flag forwarding/target hint described
above. Existing trace, IRQ, odd-target and memory-port guards remain intact.
No clock or timer configuration changes.

Exact scratch source qualification completed: full integration;14,720
forced-decode reference snapshots; immutable silicon100 with1,900matching
field groups and zero real differences (`/tmp/cpu-corpus100-gate.GBqvn3`);
all12MOVE/compare extension-fault/trace/IRQ cases; five operand-fault
cases×three timing schedules;360branch conditions with stale-CCR mutation
rejected; and five branch boundary cases×three schedules.

New reusable runners accept explicit `--core` and `--out`:
`pipeline_branch_conditions.py`, `pipeline_branch_boundaries.py`, and
`pipeline_indexed_fallback.py`. Their exact tracked versions pass against
the promoted candidate. Fallback tests cover MOVE load/store and CMP/TST
with both brief and full-format extensions across a cache-line boundary.
Each case observes69actual wait cycles over three schedules; each brief
case records three claims and each full-format case zero claims. All
check register, memory and CCR results. The original fault rerun used an
output path longer than the bench's128-byte filename buffer and could not
load the program; rerunning with short paths passes. That run is not CPU
failure evidence.

Simulation kernels remain Bubble4,203,308, Towers26,207,138 and
Permute1,519,901cycles. Hardware P7compare trial remains in progress on the
previous1c04a43bitstream. The new candidate needs its own Quartus fit and
five-run hardware trial; these cycle reductions do not establish Mix1.8.

## P7 hardware result and next memory-MOVE probe

P7compare1c04a43 completed five valid33MHz hardware Mix runs:
1.011/1.013/1.014/1.013/1.013, median1.013 and mean1.0128, no timer
outliers. Section30 of PERFORMANCE_MEASUREMENTS records all ten component
scores and the limitation that the benchmark session was reloaded before
shutdown; only the subsequent recovery boot cleanly halted.

The promoted f2b2770 admission/branch candidate is now fitting under user
service `q800-p7handoff-fit-20260919.service`. Use `systemctl --user`, not
the system manager, to query it. Archive `scratch/p7handoff_fit_20260919`;
source freeze remains active through terminal compile and crossing extraction.

Scratch `p8_memmove_ack_20260919` begins a MOVE memory destination EA on
the successful source-read acknowledgement. It bypasses S_PIPE_SDONE and
S_PIPE_DST; faulting and split source reads keep their old path. Bubble
falls from4,203,308 to4,077,142cycles and Towers26,207,138 to25,617,018,
both results/guards pass. Permute rises from1,519,901 to1,529,979cycles
(a0.66%regression), so this broad variant is not being promoted. Its full
integration gate is still running.

The indexed-destination-only variant in `scratch/p8_memmove_indexed_20260919`
restores Permute exactly to1,519,901cycles, with result/guards PASS. Towers
and Bubble runs are pending. This remains a scratch experiment requiring
precise read/write/extension-fault and interrupt qualification before any
promotion. None of these source changes affect the running fit.

Restricted MOVE probe measurement completed: Bubble4,077,142cycles,
Towers26,010,464cycles and Permute1,519,901cycles, all results/guards
PASS. Relative to f2b2770 these are3.0%fewer Bubble cycles,0.75%fewer
Towers cycles and unchanged Permute. This retains less of the broad
variant's Towers gain but avoids its Permute regression. Qualification
is still incomplete; no memory-MOVE RTL has been promoted.

## Indexed memory-MOVE correctness checkpoint

The exact indexed-only scratch core passes the complete real-core integration
gate and immutable silicon100 sample (1,900 field groups, zero differences;
`/tmp/cpu-corpus100-gate.64l6Ys`). This is sample evidence, not a full-corpus
claim. Its source remains outside the active Quartus fit.

Two reusable runners, `pipeline_memmove_faults.py` and
`pipeline_memmove_boundaries.py`, accept `--core` and `--out`. Their exact
tracked versions pass on both the scratch candidate and committed f2b2770
core, each under three timing schedules:

- Source-read and destination-write access errors, with precise format7
  PC/fault address/SR, destination preservation and unchanged registers.
- Destination faults following post-increment/pre-decrement source reads,
  verifying rollback of the updated source address register.
- Persistent destination-extension fetch fault across a page boundary.
- Deferred level2 IRQ and T1 trace, checking the completed destination write
  and exception frame before any following instruction executes.
- Shared source/destination base register, full-format indexed destination,
  and a page-split source with transparent MMU translation enabled.

The MOVE_ACK monitor counts eligible normal source-read acknowledgements,
not execution of the new branch itself; baseline intentionally satisfies
the same count. Source faults and the split-source case count zero. The
split case also asserts actual S_MRD_B occupancy, proving fallback coverage.

The initial extension fixture used a one-shot fetch fault. It fired during
speculation while the source read was active, and both cores later retried
successfully, so it could not establish a demand-fault requirement. The
final test keeps the fault asserted at address0x2000 across retries; both
cores deliver the expected format7 frame. The initial split test left the
MMU disabled and therefore used a normal transfer; enabling transparent
translation exercises the intended byte-split path. Neither fixture
correction changed RTL or relaxed the final architectural checks.

The candidate still needs broader B/W/L value/alias coverage before
promotion. The fit of f2b2770 remains active. Hardware operator is performing
an additional P7compare run followed by application quit and clean Finder
shutdown to resolve the earlier shutdown-evidence gap; retain the original
five-run statistics separately.

## Memory-MOVE value oracle complete

`pipeline_memmove_values.py --core ... --out ...` independently generates
144 cases spanning B/W/L, zero/one/signed edges/all-ones/alternating bits,
(An)/(An)+/-(An)/d16(An) sources, shared and distinct source/destination
base registers, signed long indices and all four index scales. It checks
CCR including preserved X and cleared V/C, both address registers, the
index register, moved data and byte guards on both sides of each write.
Three timing schedules produce432 eligible source acknowledgements.

The exact reusable runner passes for both committed f2b2770 and the
indexed-only scratch candidate. A deliberate candidate mutation XORs the
source result with1 at the new acknowledgement shortcut: all schedules
fail architectural program checks, so the oracle detects corrupted data
rather than merely a coverage mismatch. Logs/artifacts are
`scratch/p8_memmove_indexed_20260919/{rvalues,basevalues,badvalues}`.

Together with full integration, silicon100 and the10fault/boundary cases,
this completes the planned simulation qualification for the indexed-only
shortcut. It is ready for promotion after the current fit's source freeze
ends; no hardware gain or fit result exists for this shortcut yet. The broad
variant remains rejected because it regressed Permute.

## Permute call/stack occupancy and RTS probe

New `profile_permute_occupancy.py --program PROGRAM_HEX --out DIR [--core CORE]`
profiles the existing checked kernel fixture, records program/source SHA256s,
and reuses the tracked real CPU/cache/store-buffer bench. The exact reusable
runner reproduces1,519,901cycles and all result/array/guard checks. Artifact
`scratch/permute_profile_20260919/reusable/` includes the full occupancy table.
Pipeline ownership accounts for109,604cycles (7.2%);40,326issues include20,163
stores and no pipeline loads. Exits include10,078JSR(d16,PC) instructions.

Largest legacy current-IR occupancies:

| Opcode | Instruction | Cycles |
| --- | --- | ---: |
| 4cdf | MOVEM load | 161,469 |
| 4e75 | RTS | 155,335 |
| 48e7 | MOVEM store | 131,819 |
| 4e56 | LINK | 126,632 |
| 4e5e | UNLK | 100,095 |
| 3290 | memory-to-memory MOVE | 80,643 |

The first five sum to675,350cycles (44.4%). Occupancy includes fetch and
handoff; it is not retired-instruction latency or an attainable speedup
bound. Existing cache line forwarding already fills the instruction queue
from128-bit line offers, so adding that mechanism again is not a solution.

Scratch `p9_rts_ack_20260919` tests completing ordinary even RTS returns
on source-read acknowledgement and supplying mem_rdata to the existing
shared redirect target. Odd targets, trace, pending IRQ, RTR/RTD and split
reads retain the old path. It is based on f2b2770, without the P8 MOVE
shortcut, to isolate the result. Permute1,504,787cycles (0.99%fewer) and
Towers26,133,410cycles (0.28%fewer), all kernel results/guards PASS. This
is not correctness-qualified or promoted. Redirect changes still need
odd-target, access-fault, IRQ/trace and broader integration tests.

## RTS correctness checkpoint and combined candidate

The standalone P9 RTS prototype passes the full real-core integration gate
and immutable silicon100 sample:1,900field groups match with zero differences
(`/tmp/cpu-corpus100-gate.D3fWR0`). New reusable
`pipeline_rts_boundaries.py --core ... --out ...` passes on both candidate
and committed baseline. Nine cases×three timing schedules check normal and
word-aligned targets, odd target address error, source-read and persistent
target-fetch access errors, T1/T0 trace, IRQ during return, and a page-split
stack read under transparent translation. Tests assert stack pointer,
frame SR/PC/format/fault address and absence of younger target execution.
The split case requires actual S_MRD_B occupancy. Eligible-ack counts
identify shortcut opportunities; baseline intentionally meets the same count.

A mutation changes the shortcut's A7 increment from4 to8. Normal-return
program assertions reject it in all timing schedules. Thus test failure
comes from architectural state, not merely missing coverage. Evidence:
`scratch/p9_combined_20260919/bad_stack/normal.log`.

Scratch `p9_combined_20260919/ap040_core.v` combines the indexed-only P8
memory-MOVE shortcut with P9 RTS. All four reusable MOVE/RTS runners pass
on this exact combined core, including432MOVE value cases and all fault/
boundary cases. Full integration and silicon100 are running on the combined
sources; their earlier standalone passes do not substitute for these checks.
Combined Permute measures1,504,787cycles, preserving the standalone RTS gain.
Combined Towers/Bubble measurements are pending. No combined RTL has been
promoted while the f2b2770fit source freeze remains active.

## P7handoff fit terminal; next candidate promoted

f2b2770 seed21 completed with39,591ALMs94%,26,347registers,491RAMblocks,
43DSPs. CPU setup-0.862ns/TNS-4.710; HDMI-0.069/TNS-0.394;
SDRAM+0.727; worst hold+0.201; crossings sys→ram+0.771/ram→sys+0.611.
RF bankE remains512-bitMLAB; cache tags remainM10K. Source/archive/cross
checks pass. Archived4,529,544-byte artifact SHA256
`e12627b49d97fd2efd41433c058e1c28906c7959317a63c52544cd655b26759e`
in `scratch/p7handoff_fit_20260919`. The existing operator is performing
an authorized experimental five-run hardware trial; this timing miss
prevents release qualification regardless of benchmark outcome.

Worst CPU path is regfile pend_we through forwarded operands and the
general ALU shift/result/flag mux into pc[22],27logic levels. Reports
`worst_paths.txt` and `worst_detail.txt` are archived before db replacement.
Three CAS/CAS2 decisions used general alu_fl[2] even though decode fixes
the operation to CMP. The next candidate selects the existing alu_fast_fl[2]
for these decisions, preserving architectural flag writes. This is a
structural timing hypothesis; only the next fit can establish improvement.

The combined MOVE/RTS implementation completed full integration and
silicon100 (1,900groups match, zero differences;
`/tmp/cpu-corpus100-gate.FSVPEg`). Its kernels pass with Bubble4,077,142,
Towers25,936,736 and Permute1,504,787cycles. These improvements are not
hardware Mix claims. The combined RTL plus the fast-CAS decision correction
is now promoted for the next fit. Scratch exact source is
`p9_fastcas_20260919/ap040_core.v`; promoted RTL adds comments only.

The existing independent arithmetic testbench now checks fast_flags and
fast_ok against its independent oracle for ADD/SUB/CMP. Its1,479,840total
ALU comparisons pass. The corrected core already passes integer (including
CAS/CAS2), exceptions, MMU and bitfield-MMU integration programs; the rest
of the full integration suite continues during build preparation. No
instruction clock or timer configuration changed.

### MOVEM follow-up profiling: no gain from final-store retirement

On the current combined core, the Permute kernel passes at 1,504,787 cycles.
Scratch `p10_movem_20260919` retires an ordinary final MOVEM store at its
acknowledgement. It exercises 8,660 eligible acknowledgements, but saves no
cycles: S_MOVEM_LOOP falls from 69,280 to 60,620 while S_MRD grows from
406,083 to 414,743. The full integration regression passes. Do not promote
this change on correctness alone; the measured performance is unchanged.

The independent current-core operand profile in
`scratch/p10_memory_profile_20260919/permute/both/run.log` separates read
cycles into waiting for a prefetch (17,843), request setup (52,514), issued
request awaiting acknowledgement (205,957), and acknowledgement (129,769).
Store categories respectively count 83,770 / 84,948 / 23,220 / 129,762.
These are state occupancy, not a hardware score. Leading issued-read waits
include MOVEM load (53,457), opcode 362e (45,431), UNLK (32,905), and RTS
(32,903). The cache already handles both within-line and cross-line spanning
reads; only the aligned/single-longword case supports the fast hint response.
Investigate spanning-read lookup costs before proposing redundant storage.

Scratch `p11_movemhint_20260919` corrects the predecrement MOVEM hint from
mm_addr to the actual decremented store address. Permute still passes at
1,504,787 cycles. This is also not promoted; a matching hint by itself does
not establish a performance benefit.

### P12: begin a matched spanning cache read at idle admission

Prototype: `scratch/p12_idlespan_20260919/ap040_cache.v`; current tracked
core and pipeline module, candidate cache only. A translated within-line
spanning read whose idle RAM indices/tags match can start the existing
whole-line read at acceptance. The next C_LOOK cycle uses the existing
look2 assembly and snoop fallback. It adds no cache storage. Requests with
unsettled metadata, invalidation, faults, or misses retain the prior path.

Qualification so far:

- Full reference/pipeline integration: PASS, including exceptions, MMU,
  MOVEM restart, cache, and precise pipeline interrupt/replay cases.
- Existing snoop suite and XSTORE 100-case suite: PASS.
- `scripts/cpu/cache_spanning_reads.py`: baseline and candidate pass 15
  additional data checks covering nine within-line longword spans, three
  word spans, and snoops at admission, assembly, and a CE-paused assembly.
  All nine primed longword spans take three cycles, versus four baseline.
  A wrong-cache-way mutation fails the actual data comparisons.
- Immutable first-100 silicon corpus: 1,900 field groups, zero differences;
  `/tmp/cpu-corpus100-gate.sWPcLL`. This is not the full silicon corpus.
- Permute: 1,466,887 cycles versus 1,504,787, a 2.52% reduction, with array
  and guard checks passing. Bubble: unchanged at 4,077,142, sorted output
  and guards passing. RAM latency is the controlled three-cycle fixture;
  neither result predicts a hardware Mix score by itself.

The active Quartus build remains commit28b164d without this cache change.
P12 remains a scratch candidate pending remaining benchmark/fit checks.

Towers completed PASS at25,583,649 cycles versus25,936,736 (1.36% fewer),
16,383 moves,18 nodes, list and guard checks passing. All three kernel
runs are terminal. Current Quartus source manifest recheck also passes.

### P13 cross-line lookup prototype: qualification in progress

Scratch `p13_idlexline_20260919/ap040_cache.v` extends matched idle
admission to the second-line lookup. The first word is captured at
admission, and the existing cross-line assembly/miss path handles the
second. No storage array is added. An explicit next-line snoop during a
CE pause exposed stale data in the first prototype; a free-running sticky
invalidation guard fixes it. Disabling that guard reproduces the failure.

The reusable spanning test now adds24 cross-line cases: every supported
longword/word offset, cold first line, missing second line, double hit,
and set/tag wrap. Candidate and trackedP12 baseline pass. All8 primed
cross-line cases take3cycles versus4baseline. Three next-line snoop cases
(admission, assembly, CE-paused assembly) also pass; the earlier15
within-line/snoop checks remain passing. The flat memory responder is
byte-correct for these added cases, including fallback reads.

Corrected-candidate results: silicon first100,1900fieldgroups,0differences
(`/tmp/cpu-corpus100-gate.G5bROd`); XSTORE100case suitePASS.
Permute1,457,331 vsP12 1,466,887; Towers25,469,823 vsP12 25,583,649;
Bubble4,077,142 unchanged. Independent kernel output/guard checks pass.
Full reference/pipeline integration remains running. P13 is not promoted
or built. P12fit1fb24fc and P9hardware trial run independently.

P13 full reference/pipeline integration subsequently completed PASS,
including all precise load/store/PEA interrupt and replay checks.

### Displacement-load pipeline exploration (not promoted)

P14 scratch adds MOVE/MOVEA d16(An) loads to the existing pipeline module,
including a signed extension EA and two-word admission. On trackedP12
cache/core, Permute passes but regresses1,466,887->1,487,041cycles; pipeline
loads rise0->15,117 and total issues40,326->55,443. Towers passes unchanged
at25,583,649. Supporting more opcodes does not by itself improve throughput.

A continuation-only variant excludes displacement loads from initial
pipeline admission but allows them after an existing owner. Permute returns
to1,466,887 withzero pipeline loads, so this fixture offers no suitable
continuation sequence. Both experiments remain scratch-only; neither has
complete correctness qualification or measured performance benefit.
Artifacts: scratch/p14_dispload_20260919 and its continuation subdirectory.

### Pipeline occupancy explains displacement-load regression

`scratch/p15_pipe_profile_20260919` repeats the exact Permute fixture on
trackedP12 and the P14 displacement-load module. Both pass independent
array/guard checks. Counters apply only while pipe_rf_owner is true and
are overlapping categories, not additive attribution:

| Counter | P12 current | P14 displacement loads |
|---|---:|---:|
| Total kernel cycles | 1,466,887 | 1,487,041 |
| Pipeline ownership cycles | 109,604 | 160,019 |
| EX memory waiting for completion | 49,108 | 74,328 |
| WB valid while sequencer owns memory | 0 | 0 |
| Queue lacks next opcode during ownership | 0 | 20 |
| Resident next opcode unsupported | 51,791 | 76,994 |
| Input offered while ID not ready | 27,572 | 42,686 |
| Retirements | 40,326 | 55,443 |
| ID valid while EX cannot advance | 27,593 | 47,746 |

Current ownership is7.47% of kernel runtime. This bounds the benefit of
optimizing only existing owned cycles: most execution remains elsewhere.
Expanded load support adds15,117retirements but50,415ownershipcycles and
20,154totalcycles. It does not fix isolated admission/drain overhead or
unsupported control/stack boundaries. Within owned sequences instruction
queue starvation is negligible; a deeper queue alone is not supported by
this evidence. The counters do not measure legacy frontend starvation or
predict whole Speedometer Mix. Next larger architectural work should target
longer useful sequences across observed boundaries, with precise exception
and branch handling, rather than assuming opcode count equals throughput.

### Prefetch arbitration follow-up on P13 baseline

P17 divides the previous four-word prefetch threshold by ownership.
With trackedP13 cache, current Permute is1,457,331cycles. Limiting prefetch
only during pipeline ownership gives1,458,667 (regression), Bubble4,077,142
unchanged. Limiting only legacy ownership givesPermute1,441,991 butBubble
4,393,201 (regression). Neither is promoted. Artifacts:
`scratch/p17_fetch_owner_20260919`, all compared kernel checksPASS.

P18 applies the threshold only while the current instruction is LINK/UNLK,
RTS, or MOVEM; other instructions keep the original refill policy. This is
an instruction-family policy, independent of benchmark addresses/data.
Scratch `p18_stack_fetch_20260919`: Permute1,439,538PASS (1.22% fewer cycles
than P13), Bubble4,077,142PASS unchanged. Towers and full integration are
still running. No RTL promotion or hardware performance claim yet.

P18 qualification update: Towers25,297,658PASS versusP13 25,469,823
(0.68% fewer cycles); Permute1,439,538 versus1,457,331 (1.22% fewer),
Bubble4,077,142 unchanged. Silicon first100:1900fieldgroups0differences,
`/tmp/cpu-corpus100-gate.MQbKNs`. Reusable RTS boundaries9cases×3phases
and branch boundaries5cases×3phases pass. These exercise source/target
faults, odd targets, splits, T1/T0, and IRQ boundaries. Full integration
is still running; no promotion yet. Active P13fit sourcehashcheck passes.

P18 full reference/pipeline integration completed PASS, including precise
load/store/PEA interrupt and replay checks. It is ready for fit consideration
after the active P13 compile/crossing extraction finishes.

### P19 short-branch pipeline experiment started

Towers exits about49,191times at BLE.B opcode6f12 and49,149times at BRA.B
6002, in addition to MOVEM and memory-MOVE boundaries. ScratchP19 adds only
short even-displacement BRA/Bcc (not BSR), evaluates conditions against
forwarded CCR in EX, records the selected nextPC in WB, and redirects on
retirement while cancelling younger pipeline work. Trace entry retains
legacy handling. Odd/word/long branches remain unsupported. This is an
unqualified prototype, not a completed branch implementation or a default
change. Permute is unchanged1,457,331PASS with unchangedissuecount; Towers
is the relevant pending measurement. Files:scratch/p19_branchpipe_20260919.

P19Towers terminalPASS25,227,008 versusP13 25,469,823 (0.95%fewer),
issues1,913,043vs1,376,616; noAP040redirectmismatch/FAILdiagnostics.
Broadgate startedsession36346 in scratch/p19_branchpipe_20260919/gate.log.
Stillunqualified, targetwrongpathmemory/IRQ/trace coverage required.
