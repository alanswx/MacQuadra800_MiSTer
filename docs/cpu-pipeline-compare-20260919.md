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
