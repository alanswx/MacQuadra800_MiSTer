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

### P19 Bubble regression — do not promote as-is

Matched P19 core/module Bubble run completed with independent sorted-permutation
and guard checks PASS, but 4,200,476 cycles versus P13's 4,077,142: 3.025%
more cycles. Pipeline occupancy1,562,064 cycles,1,185,833 issues. Together with
Towers25,227,008 (~0.95% fewer) and unchanged Permute1,457,331, this is a mixed
result, not an unqualified speed improvement. Do not promote P19 as-is. Diagnose
branch redirect/admission cost or prioritize already-qualified P18 after P13 fit.
Log: scratch/p19_branchpipe_20260919/bubble/compare/run.log.

### P13 fit complete; P18 selected for next fit

P13 ef4f71d archived fit/source/cross exit0. Timing met:39,772ALMs,
26,361registers,491RAM,43DSP; CPU+.757,HDMI+.135,SDRAM+.200ns,
worsthold+.238; sys->ram+.200,ram->sys+.757. Cache tag M10K and
512-bit bank E MLAB retained. Root independently verified archived RBF SHA256
`e97fc787dd8d4f6d81acdaf8f39b369de9a88d6cf428441b03104084500679e8`,
4,538,688 bytes. Hardware operator assigned five-run P13 trial from P12 safe
halt using archived artifact only. No P13 hardware results yet.
P18 stack-family speculative refill threshold promoted after prior full gate,
silicon100, branch/RTS boundaries and three benchmark kernels passed.
RTL differs from qualified scratch copy only by comment/whitespace.
Next fit archive/service: scratch/p18stack_fit_20260919,
q800-p18stack-fit-20260919.service. Check live state before further RTL edits.
P20 scratch branch-refill variant leaves Bubble unchanged at4,200,476 cycles.
Its branch profile:124,750 BLE.B retirements,61,667 taken,zero taken redirects
with epf_pend/mem_req/mem_ack busy. Regression123,334cycles is exactly two per
taken branch. Speculative fetch contention at redirect is not supported by this
measurement. P19/P20 remain unpromoted. Best hardware median1.043,goal1.8unmet.

### P21/P22/P23 branch and extension measurements

Scratch P21 (`scratch/p21_bra_only_20260919`) restricts P19 branch support to
short even BRA; conditional Bcc retains legacy lookahead. On P13 core/cache,
Towers25,371,528 cycles PASS (98,295 fewer than P13, ~0.386%), Bubble4,077,142
unchanged PASS. Not yet fully qualified or promoted. P19 full Bcc+BRA remains
faster for Towers but regresses Bubble. All original kernel/output checks retained.
P22 (`scratch/p22_ext_20260919`) independently adds optional EXT.W/EXT.L/EXTB.L/
SWAP decode using existing ALU on P18 core/cache. Bubble4,077,142 unchanged:
conditional Bcc already terminates the pipeline before its EXT.L boundary.
New reusable `scripts/cpu/pipeline_extension_values.py` checks 4 operations,
8 data registers,12 boundary values,2 X states,3 bus phases:2,304 pipeline
extension retirements PASS. Independent result and SR checks cover word upper-half
preservation, sign extension, SWAP, NZVC and preserved X, with immediate load-to-EX
forwarding. Initial CMP-entry fixture passed architecture but had zero pipeline
coverage and was rejected; indexed-load producer fixture achieves all2,304.
Mutation changing EXT.W to longword size fails architectural checks in all phases
(scratch/p22_ext_20260919/bad/run.log). No production pipeline edits.
P23 combines P19 branch support and P22 extension decode on P13 core/cache.
Bubble4,137,455 cycles PASS,still60,313 (~1.48%) slower than P13; do not promote.
Next performance candidate to qualify is P21, or improve taken-branch resolution
without its two-cycle penalty. Neither P22 nor P23 is a measured standalone gain.
P18 build7eef632 remains active MainPID1564390; live source SHA check PASS.
P13 hardware operator running, first completed screenshot exists but no aggregate
accepted yet. Best verified hardware median remains1.043; goal1.8notachieved.

### P21 BRA correctness qualification

Candidate remains scratch/p21_bra_only_20260919 (P13 core/cache plus short-even
unconditional BRA continuation; conditional branches stay legacy).
Permute completed1,457,331cycles unchanged PASS; Towers25,371,528 and
Bubble4,077,142 as recorded. First100 silicon reference passed1,900fieldgroups,
zero real differences, `/tmp/cpu-corpus100-gate.jendKz`; not full corpus.
New reusable scripts/cpu/pipeline_bra_boundaries.py tests wrong-path indirect
read suppression, target-fetch bus-error frame SR/PC/format/faultaddress, and
negative short displacement. Each requires3pipeline BRA retirements across
three bus phases; all PASS. Disabling branch kill raises actual younger-load
launch assertion (bad/wrong_read.log), proving the cancellation check is active.
Retirement IRQ frame test with BRA passes3injections/3precedingCMPcommits.
BRA odd target/T1/T0/predecessorIRQ checks pass3phases each; legacy not-taken odd
Bcc case also passes. BRA younger-store oracle passes24taken/0untaken pipeline
branches with independent memory checks across8predecessor-flag pairs×3phases.
Fullintegration session56427 still running lastseen through pipeline_load_fault;
log scratch/p21_bra_only_20260919/gate.log. Do not promote before terminalPASS,
and do not overwrite P18 prefetch change when merging this P13-based candidate.
P18 fit remains live MainPID1564390, production source freeze unchanged.
P13 hardware agent active, four completed run screenshots exist; aggregate and
normal shutdown still pending. Best accepted hardware median1.043;1.8unmet.

### P13 accepted hardware median1.050; P24 qualified and promoted

P13 five validMix1.047/1.050/1.049/1.050/1.050,mean1.0492,median1.050.
No timer-invalid results. Full table appended to PERFORMANCE_MEASUREMENTS.
Root viewed run5 completion and final_halt_visible2 explicit safe-switch-off
screen. Earlier final_halt_visible.png showed Finder and was not accepted as
halt evidence. Normal quit/save(unique P13cross-record-20260920)/Finder/shutdown.
Best accepted hardware median now1.050; target1.8 remains unmet.
P18 fit7eef632 terminal:39,696ALMs,26,346registers,491RAM,43DSP; HDMI-.173ns,
CPU+.612,SDRAM+.949,worsthold+.213,cross+1.614/+.612. Buildexit1 timingonly,
sourcecheck/cross exits0; RAM inference retained. Archived RBF4,497,280bytes,
SHA25606b58fcab57712e6d2bffeab7fcc897ed33bafad8875b525f3c5c5ff6ac931f7.
Hardware operator assigned marginal P18 trial from verified P13 halt; no release
claim. Build source freeze ended after terminal archive/cross extraction.
P24 combines P18 refill guard with P21 BRA continuation. Fullintegration12621
terminalPASS, silicon1001,900groups0diff(/tmp/cpu-corpus100-gate.b3TsCU), all
BRA fault/backward/read/IRQ/trace/store tests PASS. Three original kernels:
Permute1,439,538,Towers25,223,939,Bubble4,077,142,allindependentchecksPASS.
Production core is semantically identical to qualified P24 scratch (comments and
whitespace normalized); module byte-identical. Next single fit wrapper/archive
scratch/p24stackbra_fit_20260919 and serviceq800-p24stackbra-fit-20260919.
Check service live state before editing RTL. P25 scratch displacement-CMP support
onP18 baseline gives Bubble4,079,134vs4,077,142(+1,992cycles),PASSvalues but
no performance gain; not promoted or fully qualified.

### P26 within-page unaligned early issue improves call-heavy kernels

Scratch candidate scratch/p26_unaligned_issue_20260919 starts from committed
P24 RTL. The only RTL delta replaces mem_issue's alignment-only early-admission
guard with within-4KB guards: byte always, word offset!=fff, long offset<=ffc.
State whitelist, on-board address class, shared-port arbitration and completion/
fault paths remain unchanged. Transfers crossing4KB keep old delayed issue and
MMU split behavior (also conservative for8KB pages). Not yet promoted.
Original latency3 kernels independently PASS: Permute1,391,673vsP24 1,439,538
(-47,865cycles,3.325%); Towers24,525,593vs25,223,939(-698,346,2.769%);
Bubble4,077,142unchanged. These are simulation cycles,not hardwareMix scores.
Silicon1001,900fieldgroups0diff PASS,/tmp/cpu-corpus100-gate.uITaev.
Existing memory-MOVE source/destination/postinc/predec/extension fault cases PASS.
RTS9cases×3phases PASS with default stack and new --word-aligned-stack option
in scripts/cpu/pipeline_rts_boundaries.py. Added mode uses7002stack, checks7006
post-returnSP and adjusted precise frames/sourcefaultaddress; splitcase remains
6fff->7003. Initial scratch conversion left stale7004expectedSP and was rejected;
corrected fixture passes allcases. Existing default behavior rerunPASS.
Fullintegration15015 still running lastseen throughcache; log gate.log underP26.
P24fitservice remains activeMainPID1605366,inputfreezeunchanged. P18 hardware
operator active. Best accepted hardwaremedian1.050;goal1.8notmet.

### P26 full gate complete; P27 memory attribution; P28 rejected

P26 fullintegration15015 terminalPASS including precise load/store/PEA IRQ replay.
It is simulation-qualified for a future fit after activeP24 completes. Keep
production inputs frozen (q800-p24stackbra-fit-20260919,MainPID1605366).
P27 scratch/p27_memory_profile_20260919/run.py and detail.py instrument original
Permute/Towers benches using exact P26 core/module and retain output checks.
Identical total cycles confirm instrumentation neutrality. Non-overlapping
S_MRD categories [prefetchwait,setup,error,ack,operandwait]:
Permute[68,5046,0,129769,153253]; Towers[147780,318841,0,2162642,2209669].
S_MWR samecategories: Permute[71960,51178,0,129762,39788];
Towers[179792,319670,0,1770106,933297]. Cache-state occupancy during operandwait
is overlapping detail,not additional cycles. Both have zero cycles without MMU
output request during operandwait. Logs profile.log/detail/{permute,towers}/run.log.
Permute writeprefetchwait topfamilies:JSR4eba27162,MOVEM48e717048,
PEA487012067,ADDQ52ad8684,LINK4e565053. Towers dominated by indexedstore3186
49191,push3f0549157,LINK4e5649190,MOVEM48e732098;JSRonly16.
P28 scratch/p28_call_fetch_20260919 extends P18 four-word refill threshold to
JSR/BSR/PEA on P26. OriginalkernelsPASS,but Permute1,393,414vs1,391,673
(+1,741cycles),Towers24,525,593unchanged,Bubble4,077,138vs4,077,142(-4).
RejectP28; notpromoted/notfullyqualified. Generic queue throttling remains a
tradeoff,not an assumed speedup. Next larger opportunity worth inspecting is
memory-to-memory MOVE destination EA overlap with the source read, using real
opcode/state evidence and preserving two-access fault order.
P18 hardware operator stillactive; root requested status because no completed-run
artifacts yet. No accepted P18 score. Best hardwaremedian1.050,goal1.8unmet.

### P24 fit timing met; P26 promoted for next fit

P24 0177679 terminal build/source/cross exits0.39,716ALMs,26,334registers,
491RAM,43DSP. CPU+.518,HDMI+.119,SDRAM+.804,worsthold+.229ns;
crosssys->ram+.804,ram->sys+.518. Root verified cachetagM10K/bankE512bitMLAB
and archived4,506,028byteRBF SHA256
86f6cc7824c20c3320f774be04baa163d1eb64236f27e8220a69fc0c20e23604.
Hardware operator queued P24 after finishing P18 retry, five valid runs and normal
shutdown per candidate; explicit archived artifacts only.
P26 within-page unaligned early issue promoted after fullintegration, silicon100,
RTS(default+wordaligned),memMOVEfault and3originalkernel gates PASS.
Production core normalized-equal to qualified scratch; comments updated to explain
4KB conservative guard for both MMU page sizes. Next fit wrapper/archive
scratch/p26unaligned_fit_20260919; serviceq800-p26unaligned-fit-20260919.
P29 scratch destination-register peek during S_MRD gives all3kernel totals
identical toP26; notpromoted/notfullyqualified. P30 prepares selectors on source
read issue, peeking past any source extension popped on that edge; only after
source success may its brief destination extension be consumed and existing
S_EA_EXTW2 used. P30 stillunqualified; Bubble session2725/log
scratch/p30_move_issue_peek_20260919/bubble.log. Do not promote based on hypothesis.
Best hardwaremedian1.050,goal1.8unmet. P18 retry active; earlier failure claim was
not supported by root-reviewed normal registration/splash images.


P26 fit launched on c8c58bf, serviceq800-p26unaligned-fit-20260919 active
MainPID1640390. Production RTL/QSF/QIP/SDC frozen through terminal archive/cross.
P30 Bubble terminalPASS4,140,222vsP26 4,077,142(+63,080cycles,1.547%).
State deltas: S_IMMF8 -63,083, S_EA_DISP11 -63,083, S_MWR10 +189,246;
allotherstatesunchanged. Removing two address-setup cycles adds three write-state
cycles per affected memoryMOVE, offset slightly by setup edges. Cache latencyclass0
also rises63,080; do not assume fewer sequencer states implies lower totalcycles.
P30 remains scratch-only, unqualified and not a candidate for promotion as-is.
Source-fault/extension ordering remains a requirement for any follow-up experiment.

### P30 stall attribution and P31/P32 guard controls

Matched observation-only Bubble profiles underP30 all/ andbase_all/ preserve
candidate4,140,222/baseline4,077,142 cycles and independent sorted-output checks.
MemoryMOVE3193 itself always takes63,083ack cycles andzero extra wait/setup.
Following registerstore3686 changes fromzero prefetch/setup stalls to126,166
prefetchwait+63,083setup cycles. Cache response wait remainszero for bothstores.
Launch trace(P30launch_detail/) sees63,083prefetches inS_PIPE_START20,IR3686,
p_src1,p_dst2,rr_a11,rr_b6,p_sreg6,dstmode2,p_rmw0.
P31scratch/p31_move_store_guard_20260919 adds simple-register-store S_PIPE_START
withsettledRF selectors to ea_state onP30. P32sameguard onP26. Results:
P31Bubble4,140,222unchanged;P32Bubble4,077,142unchanged;bothoutputsPASS.
P31launch/ confirmsguardDOESremoveall3686prefetch/setupstalls andtargetprefetch
launches, but S_MRD gains189,249cycles whileS_MWR loses189,249: wait merely
moves to subsequentread. Thus initial no-total-change result didnotmean guard
failedtoapply. NeitherP31norP32promoted/fullyqualified. Consider scheduling
prefetch earlier in safe address-computation slots, not just deferring it.
P26fit remainsactiveMainPID1640390; live sourceSHAcheckPASS. P18retry hasthree
completed-run artifacts now; root viewedrun1 normal completionMix1.049,all10
iteration1. No aggregate accepted yet. BestmedianremainsP13 1.050,goal1.8unmet.


### P26 fit completed with positive timing

Candidate c8c58bf, archived under scratch/p26unaligned_fit_20260919.
Build, source-check and cross-report exits all 0; wrapper terminal, source freeze
ended. 39,730/41,910 ALMs (95%), 26,362 registers, 491 RAM blocks, 43 DSPs.
CPU setup +0.775 ns, HDMI +0.113 ns, SDRAM +0.668 ns, minimum hold +0.205 ns.
Cross sys->ram +1.186 ns; ram->sys +0.775 ns. Cache tags remain M10K;
register bank E remains a 512-bit MLAB. Root verified archived bitstream hash:
MacQuadra800_p26unaligned_c8c58bf.rbf, 4,497,876 bytes, SHA256
2702dabbd7400e31aaf5953d24615bdb841507173f938b49c98a89bf6dfc5316.
P26 hardware trial queued after P24, five valid runs each on disposable disk.
P18 operator reports five scores with median1.052; root verified run5=1.053
and visible safe shutdown, but exact duplicate pairs of subtest values warrant
checking independent-run evidence before accepting the aggregate.
P33 scratch experiment allows speculative fetch during brief indexed destination
EA_EXTW2 for ordinary memory-to-memory MOVE on P30. No promotion; Bubble
measurement pending under scratch/p33_move_early_fetch_20260919.
Goal1.8 remains unmet; accepted P13 median1.050 unchanged pending P18 audit.


### P33 early fetch restores benefit of MOVE destination overlap

Scratch candidate scratch/p33_move_early_fetch_20260919 combines P30 source-read
register-selector preparation/direct brief destination calculation with allowing
background instruction fetch in that destination S_EA_EXTW2 slot. Ordinary
memory-to-memory MOVE only; source success still precedes destination extension
consumption; existing memory-port, page and fault guards remain.
Original controlled kernels: Bubble4,014,059 vsP26 4,077,142 (-63,083;1.547%);
Towers24,427,253 vs24,525,593 (-98,340;0.401%); Permute1,391,673 unchanged.
All independent output/guard checks PASS. These are simulation cycle counts,
not hardware Mix predictions.
MOVE faults(source,destination,postinc,predec,extension) PASS; boundaries IRQ/T1,
alias/full-extension/split PASS across three bus phases. Value suite144fixtures
across three phases passes432acknowledgements with315direct-EA transitions.
New --require-direct-ea coverage option rejects unchanged P26 (zero transitions)
after its architectural checks pass, preventing a vacuous fast-path result.
Silicon first100 rows:1900fieldgroups match,0diffs; artifacts
/tmp/cpu-corpus100-gate.3xjC7s. Full integration still running; do not promote yet.
Sessions: fullgate78655. P24/P26 hardware trials remain queued/active with operator;
P18 duplicate-pair audit pending. Goal1.8 remains unmet.


P33 fullintegration terminalPASS including MMU, MOVEM restart, FPU and precise
load/store/PEA interrupt replay. Promoted candidate core after all above gates;
production differs from qualified scratch only in whitespace/comments (normalized
comparison PASS). QSF records completed P26 fit. Next fit will use P33 source;
no hardware performance claim yet. Best accepted median remains1.050 pending
P18 independent-run audit; goal1.8 unmet.


### P34/P35 controls; P36 read retirement and hardware audit

P34 scratch/p34_branch_continue_20260919 keeps pipeline ownership over an untaken
short Bcc at an empty-pipeline boundary and enables prior tested EXT decoder.
Bubble4,014,059 unchanged vsP33, outputPASS; more pipeline coverage but no total
cycle benefit. Not promoted or fully qualified.
P35 scratch/p35_read_retire_20260919 bypasses WB on successful reads; Bubble
unchanged4,014,059 and UNOPTFLAT feedback through branch cancellation. Rejected.
P36 scratch/p36_read_handoff_20260919 separates registered-WB retirement/branch
signals from direct-read retirement and permits immediate legacy handoff after
an otherwise-empty successful read. No UNOPTFLAT in Bubble compile. Bubble
3,951,038 (-63,021 vsP33;1.570%), independent output/guardPASS; Permute1,391,673
andTowers24,427,253 unchanged. Fullintegration initially stops on old ownership
monitor (it only allowed S_EXPERIMENT_PIPE retirement); scratch monitor now
permits only successful S_MRD ack, active read, noIRQ/trace, emptyWB and readEX,
retaining all other assertions. Rerun full_v2 session47622 ongoing.
IRQ completion test injects external+qualified IRQ on exact read ack; direct
retirement suppressed and normal WB cancels younger work. All3busphases PASS,
framePC602,loadedD1=55,youngerD2=0; injections3/cancels3. Candidate unpromoted.

Root audit rejects P18/P24 five-run aggregates. Identical pairs1/2 and3/4 were
not independent runs: root viewed each run2 image, old scores with NO completion
modal. Operator command sequence CmdB thenReturn while oldcompletionmodalopen
means CmdBignored andReturndismissesoldmodal. Only1/3/5currentlycount,3validruns
per candidate; two additional actualstarts/completions required for each. Root
prepended correction notices to both scratch reports; earlier operator audit
claiming deterministic repeated values is superseded. Operator instructed to
verify startdialog before timing and completionmodal after; P26trialactive.
P33Quartusservice activeMainPID1680006, sourcefreeze remains. Goal1.8unmet;
bestacceptedfive-runmedian remainsP13 1.050.


P36 qualification update: full_v2 terminalPASS, including MMU/MOVEMrestart/FPU,
load/store/PEA faults and preciseIRQreplay. Silicon100 terminalPASS1900groups,
0diffs; /tmp/cpu-corpus100-gate.okLiIn. Permute/Towers remainP33cyclecounts.
Reusable scripts/cpu/pipeline_read_completion_irq.py passes all3busphases
with injections3/cancels3; caller supplies P36core andmodule. Mutation bad_irq.v
removes IRQguard. First mutation harness held forcedIRQ too long, causing
secondary artificial mask errors; corrected irq_completion_oracle.py releases
on ANY cancellation. irq_bad2 then fails actual assembly checks exactly once
perphase (test8609), with ownership/read-suppression assertions removed, proving
architectural oracle sensitivity. Do not cite the earlier noisy mutation result.

P36 remains scratch-only pending P33fit completion. To promote later, copy
qualified core/module and adapt rtl/ap68040/experimental/handoff_monitor.sv
from scratch monitor: retain old assertions but permit successful read retirement
only with activeS_MRD,issued/ack/noerror,noIRQ/trace,emptyWB and readEX. Newmodule
exports retire_wb_valid and retire_branch_taken so cancellation does not form a
combinational loop through fast_read_retire. Fast read retirement optional
ENABLE_FAST_READ_RETIRE=0 bydefault; core enables it. Buffered/split returns,
faults,stores,trace andpendingIRQ keep normalWBretirement. No production edits
during active P33fit; service stillactiveMainPID1680006, physicalsynthesisstage.

Root reviewed P26run2_start.png: valid RunSet dialog withallten iteration1tests.
P26operator now using explicit completiondismissal/startdialogverification;
P18/P24stillneedtwoadditionalvalidruns each. No newacceptedfive-runmedian.


### P26 accepted hardware; P37 resident register target decode

P26c8c58bf fivevalidMix1.075,1.078,1.079,1.078,1.079; median1.078,
mean1.0778,range1.075–1.079,zero timeranomalies. Root independently viewed all
fivecompletionimages (allten iteration1), run2RunSet startdialog and explicit
safehalt. Fulltable appended docs/PERFORMANCE_MEASUREMENTS.md. Unique saved
recordP26unaligned-record-20260920; originaldisk preserved. Newacceptedbest1.078
(+2.667%vsP13). Operator queued two missing actualruns eachP24/P18; earlier
stale captures2/4 remainexcluded. Goal1.8unmet, A/UXdeferredtoDani,CD/audioopen.

P37 scratch/p37_refill_regmove_20260919 adds ordinary register MOVE/MOVEA decode
in decode_dbcc_brf_now on topof qualifiedP36. Settles RFselectors and enters
S_PIPE_REGS while installing validatedresidenttarget; byteAninvalid remains
legacydecode, MOVEA.Wsignextends andpreservesCCR. Bubble3,887,632 vsP36
3,951,038 (-63,406;1.605%); Permute1,391,667(-6),Towers24,427,200(-53),
allindependentoutputguardsPASS. New scripts/cpu/pipeline_refill_regmove.py has
96fixtures (sizes,values,Dn/An inclA7,aliases), fourloopiterations×threebusphases.
Everyfixtureexercisesnewpath;573observedDBCC1->PREGS transitions. Initialfixture
onlypassedfallback(noidlebus); addedNOPs andfourthiteration to require actual
coverage. BaselineP36 passesvalues withzero fasttransitions. Signextensionmutation
bad_sign.vfailsactualfixture42 inall3phases, provingarchitecturaloraclesensitivity.
P37fullgateongoing session6589; unpromotedpendingcompletion+silicon100.
P33fit stillactiveMainPID1680006; quartus_fit1689128 consumingCPU, sourcefreeze.


P37 qualification complete in scratch: fullintegration terminalPASS; silicon100
1900groups0diffs /tmp/cpu-corpus100-gate.1PdvSK. ExpandedrefillMOVEfixture now101
cases including5DBRAupdates-to-MOVE-source cases; allpass across3busphases and
everycasehitsfastpath (603directtransitions). BaselineP36passesextendedfixture
with0directtransitions. Reusable read-completion IRQ gate alsoPASS3injections/
3cancels onP37. P37readyforpromotionafterP33fit ends, subjectto finalsourceaudit;
copy core,module and updatedhandoffmonitor fromscratch/P37. Core/module include
P36changes; do not promote onlythecorewitholdmodule/monitor. No hardwareclaim.
P38scratch/p38_refill_quick_20260919 addsregisterADDQ/SUBQresidenttargetdecode;
Bubble3,887,632unchanged vsP37, outputPASS. Notpromoted/notfullyqualified.
P33fit liveMainPID1680006; exactsourceSHAcheckPASS, archive/live_source_check.log.
No RTL/QSF/QIP/SDC edits until terminalwrapperincludingcross/archive. P26accepted
bestfive-runmedian1.078; goal1.8unmet. Hardwareoperator repairingP24/P18missing
runs; P33hardwaretrial canqueueonceitsarchivefullyverified.


### P33 clean fit; P39 64-byte refill candidate promoted

P33build/source/cross exits0, wrapperterminal. 39,823ALMs95%,26,373registers,
491RAM,43DSP. CPU+.546,HDMI+.292,SDRAM+.376,hold+.199ns;
cross+.376/+.546. CachetagM10K andbankE512bitMLABverified. ArchivedRBF
scratch/p33move_fit_20260919/MacQuadra800_p33move_32fb678.rbf,4544708bytes,
SHA256c9b2e3a57e98dfa98bdf9d34c6660c4f8f4bf5759fdd03c789b7087d36aa7e35.
Hardwareoperatorqueuedfiveverifiedruns afterP18/P24repairs.

P39scratch/p39_refill64_20260919 enlargesBRF32->64bytes atopP37. Alltag/index,
line-offer masks,per-wordvalidbits,runlength/seedindices andCPUstoreinvalidation
updated consistently. Logical/supervisorcontext andarchitecturalflushrules same.
Originalkernels Bubble3,456,612 vsP37 3,887,632 (-431,020;11.087%);
Permute1,390,747 vs1,391,667(-920);Towers24,427,200unchanged. OutputsPASS.
FullintegrationterminalPASS;silicon1001900groups0diffs,
/tmp/cpu-corpus100-gate.0vkHLM. ReadcompletionIRQ3phasesPASS;101registertarget
cases eachhitfastpath,603transitionsPASS. Newpipeline_refill_coherence.py checks
CPUwrites to residentupper-half target outsidefetchqueue andlongwrite starting
beforesector butendinginsideit. Both3phasesPASS onP39 andpreviousP37. Monitor
initiallyusedhierarchical$bits inlocalparam;Icarusreturned0,sofixturegeometrynow
parsedfromcandidateBRFtagdeclaration. NoRTLbugfromthatfixturefailure.
DisablingBRFstoreinvalidation causesactualpatched-code resultchecktofailinall3
phases; normalqueueflushcannotmasktest because monitorassertsqueueexclusion.
P39 core,module,handoffmonitor promoted normalized-equal toqualifiedscratch;
onlycommentchanges. QSF recordsP33result. Nextfit archive/servicep39refill64.
P24repairedset1/3/5/6/7 reportsmedian1.051,rootviewed6/7completionandrepairhalt;
fulltable/originalthreevisualreviewpending. BestacceptedP26median1.078;
goal1.8unmet,A/UXdeferredtoDani,CD/audiooutstanding.


### P40/P41: 128-byte refill window and bounded prefix logic

P40 (`scratch/p40_refill128_20260919`) expands the qualified 64-byte buffer
consistently to 128 bytes. Original kernels pass: Bubble 3,270,270 cycles
(vs P39 3,456,612; 5.391% fewer), Permute 1,380,671 (vs 1,390,747),
Towers 24,390,329 (vs 24,427,200). Geometry-aware coherence tests pass for
upper-half target 0x840 and crossing store 0x87e->target0x880, all three phases.
The updated fixture also passes on the 32-byte baseline with its own geometry.

P41 (`scratch/p41_refill128_prefix_20260919`) replaces the 64-word recursive
valid-run computation with an eight-bit prefix function for each position.
`refill_run_lengths.py` extracts the actual RTL and checks an independent scan:
42,770 patterns, exhausting every eight-bit window at every offset with both
zero/one surroundings, plus random full-buffer patterns. P40 and final P41 pass.
P41 Bubble remains 3,270,270 cycles, correct output/guards. Coherence passes;
removing only the end-address overlap check keeps the upper-half case passing
but fails the crossing-patch architectural result in all three phases.
P41 silicon100 passes 1900 groups, zero differences; /tmp/cpu-corpus100-gate.9XJBXr.
Full integration is still running (session22296); Permute/Towers rerun pending.
P40 full_v2 integration session79768 is also running. Neither candidate promoted.

IMPORTANT testbench follow-up after P39 fit freeze ends: new pipeline output
ports retire_wb_valid/retire_branch_taken exposed a wildcard-port elaboration
error in rtl/ap68040/experimental/tb_pipeline_integer.sv. Add explicit unused
connections `.retire_wb_valid(), .retire_branch_taken()` to that DUT instance.
This bench is not synthesis input, but all tracked SV sources are frozen/hash
recorded during the fit; do not edit it now. Scratch P40/P41 prototype.py runners
make an identified local bench copy with those connections and preserve all
oracle/mutation checks. Production CPU reference snapshots pass; this failure
was testbench wiring, not an architectural mismatch. Fix the tracked bench
before the next promotion and rerun the standard prototype command.

P18/P24 repaired five-run sets are now accepted after root reviewed all five
valid completions and final safe halts. Full corrected tables are in
PERFORMANCE_MEASUREMENTS.md: P18 median1.052, mean1.0514; P24 median1.051,
mean1.0506. Original stale captures2/4 excluded from both. P26 remains best at
1.078. P33 hardware measurement is active with correct start/completion captures.
P39 fit remains active MainPID1759655; production source freeze continues.

## Original Queens kernel profile

`profile_queens.py` extracts the original recursive solver unchanged and checks
its output independently for column/diagonal conflicts and array bounds guards.
At controlled bus latency 3, P39 uses 70,034 cycles and P41 uses 69,938.
An isolated P42 extension for pipeline `TST (An)` uses 68,209 (2.47% fewer
than P41), with 1,554 pipeline issues instead of 339. Latencies 0 and 8 also
pass the board/guard checks. P42 remains unqualified pending the full CPU gates.
The fixture runs one solve, excluding the original outer 250 iterations and
initializer, and is not a prediction of hardware Benchmark Mix.

P42 follow-up qualification passes full core integration and the first100
silicon corpus (1900 field groups, zero differences). Bubble3270270,
Permute1380671 andTowers24390329 cycles remain unchanged from P41 with correct
outputs. The expanded independent memory oracle checks25526 architectural
snapshots and5360 requests in eight delay/stall combinations, including240
indirectTST cases. Fault-frame tests and acknowledgement-edge IRQ tests pass
for all three sizes in three bus phases. A deliberately enabled TST register
writeback is rejected by the oracle. P42 remains scratch-only while P39 fits.

## Resident compare admission and read-retirement timing

P46 routes supported resident CMP/TST memory instructions through the existing
pipeline admission policy instead of retirement lookahead selecting legacy EA.
Queens improves from68,209 to65,775 cycles; Towers24,390,329 to24,096,159.
Bubble3,270,270 andPermute1,380,671 are unchanged. Outputs/guards pass.
Fullintegration, silicon100, extension faults, trace, IRQ and read faults pass.

P39's completed fit used41,347ALMs and missed CPU setup by3.701ns. Its worst
path crosses the pipeline general ALU flags into branch/refill dispatch.
P47 uses the ALU's existing bounded fast_flags for successful read retirement;
all such flag-writing operations are MOVE/TST/CMP. The other retirement paths
are unchanged. P47 passes fullintegration, silicon100(1900groups0diffs), and
Queens remains65,775cycles. The independent oracle checks25,526snapshots and
5,360reads in8stall/delay combinations, explicitly proving fast-path execution
on delayedreads. A corrupted Zflag fails the architecturaloracle. FPGA timing
improvement remains unproven until the nextfit; no hardwareMix prediction.

## P52: qualified 64-byte refill with fast read flags

P47 failed placement: 4356 LABs required, 4191 available. No fresh RBF was
produced. P52 reduces its refill sector from128 to64bytes consistently across
data/tag/valid arrays, prefix selection, line fill and store invalidation. It
retains bounded prefix computation, indirectTST, resident compare admission and
fast read-retirement flags. The pipeline module is byte-identical to P47.

Qualification: full integration PASS, prefix oracle26386patterns PASS, upper
and crossing self-modifying-code checks PASS, silicon first100:1900fieldgroups
match/zero differences (/tmp/cpu-corpus100-gate.WWT3sf). This is not full-corpus
coverage. All four original kernel output oracles pass at controlled latency3:

| Kernel | P47 128-byte cycles | P52 64-byte cycles |
|---|---:|---:|
| Queens | 65,775 | 65,832 |
| Bubble | 3,270,270 | 3,456,612 |
| Permute | 1,380,671 | 1,390,747 |
| Towers | 24,096,159 | 24,133,030 |

This trades some simulated speed for a chance to fit; it is not evidence of
a hardware Mix improvement. Candidate core SHA256:
`e1e1cb74622a13eeb5d29b458a24f4d4bc1a52696e1abad16acfb5d8940eb08e`.
Logs/sources: scratch/p52_refill64_fastflags_20260919. Next: full FPGA fit and
CPU/cross-domain timing checks before evaluating the fresh artifact on hardware.
