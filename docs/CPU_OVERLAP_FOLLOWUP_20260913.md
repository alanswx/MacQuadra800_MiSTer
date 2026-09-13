# CPU overlap follow-up, 2026-09-13

## Selected combination: completed correctness gates

CPU `21d408fa...` passed all eleven AP suites, actual exit 0. Immutable
first-100 corpus: 34,679,579 cycles, 1,900 field groups matching, zero REAL
differences (0.1753% fewer cycles than source-only). Full original 100-pass
Sieve: 89,962,063 cold / 89,961,914 repeat cycles, D6=100/D7=1899 and
complete array/guard checks passing, actual exit 0. Saves 2,195,200 cycles
per pass, or 2.3820% repeat cycles versus source-only.
Evidence: `/tmp/cpu-corpus100-gate.6cKWjh`,
`/tmp/cpu-retirement-forward.NKvcGq/combined-regression/all11.log`,
`/tmp/cpu-retirement-forward.NKvcGq/combined-full-sieve/run.log`; key logs
also retained in `scratch/cpu_combined_overlap_20260913/`.

Luna owns the prepared full-machine/Quartus build tree below. Fit and hardware
are still pending; no timing result or hardware gain is implied by these gates.
Accepted source-only hardware was freshly confirmed at 0.458/0.459/0.459,
mean 0.458667 (+1.85048%); see `CPU_SOURCE_OVERLAP_CONFIRMATION_20260913.md`.
The investigation snapshots below are historical where marked pending.

## Selected follow-up: combine destination overlap with retirement forwarding

The selected isolated CPU is `21d408fa9b2080e73957d6e64b641cc2758797895218a7639317b4ac04958700`.
It combines the earlier destination extension-request overlap with the actual
returning-opcode mux. It does not include the destination-selection alternative.
All sixteen RAM-integration oracles pass: fifteen placements improve, including
2.533% at offset 0 and 2.581% at offset 16; offset 10 regresses 0.168%.
Focused boundary tests (17 cases, 73 checks) and existing operand/fault-restart
tests pass. All eleven CPU suites pass; remaining gates are being collected.
Full evidence and reproducible patches:
`scripts/fixtures/retirement_forward/README.md`.

The old two-caller regression really does expose 14,999 eligible arriving
register opcodes at offset 16. Combining the mux recovers those opportunities.
The isolated destination-selection variant regresses offset 16 and is not
selected. The sections below preserve the investigation order, not the queue.
Build tree prepared: `/tmp/MacQuadra800_operand_combined_seed24.ntjCwN`;
CD-off seed 24, original constraints. Full-machine compile and Quartus follow
correctness gates; no FPGA timing or hardware gain is claimed yet.

Base: committed source-only operand overlap, AP68040 `7a0306c`, core SHA256
`0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`.
Parent checkpoint `eb78e09`; hardware repeat-audit correction `5f5da78`.
Experiments below remain isolated, not adopted or FPGA-tested.

## Arriving-opcode retirement bypass

Tree `/tmp/cpu-retirement-forward.NKvcGq`, candidate core SHA256
`9d80fe4e66ddaf5dae144c7aa450472d1a8b8fc16b7fcfee51fd650cbd35d063`.

A successful instruction response can provide the next register opcode at
register-ALU retirement while the queue is empty. A 16-bit mux feeds that
actual word into the existing shared decoder, independently of descriptor
validity. Boundary checks still govern consumption; the central queue engine
handles response append minus opcode pop. Other callers retain their path.

The observer confirms stale queue storage can contain a different opcode:
descriptor validity must come from the arriving word, not the old queue head.
Actual candidates include ADD.W D5,D4, ADDQ.W #3,D5 and ADDQ.W #1,D3.

Luna reports the unchanged RAM-path first-pass Sieve oracle passes all sixteen
placements, with no regressions. Only offsets 4, 8, 20 and 24 improve, saving
1,178 / 1,181 / 1,645 / 1,649 cycles respectively (about 0.14–0.19%). The
other twelve placements tie, including the default. Existing operand/fault
and pending-register tests pass. At offset 2, 1,899 saved DECODE cycles are
exactly absorbed by 1,899 additional FETCH cycles: removing a state does not
necessarily improve throughput. Do not spend an FPGA fit on this alone yet.

New isolated focused tests reported by the code agent exercise actual/stale
word selection, word/longword queue append/pop and wrap, page crossing,
register RAW and CCR forwarding, auxiliary-write fallback, other callers,
non-register opcodes, kill/context/PC mismatches, instruction error,
IRQ/trace/flush and CE gaps. Baseline 60 checks and candidate 66 checks pass;
broader corpus and independent review are pending at this writing.

## Next experiment: overlap destination selection, retain EA calculation

Investigate selecting the destination effective-address inputs during source
capture/setup for common memory-destination operations. Retain the original
S_EA_DISP boundary and arithmetic stages; remove only the intervening
S_PIPE_DST bookkeeping stage when its inputs are already qualified.

This differs from the earlier rejected destination-extension-request overlap:
that skipped S_EA_DISP and regressed one placement. Earlier EA-state indication
can change speculative-fetch suppression and shared-port timing; never assume
the new schedule wins simply because it removes a state.

The measured first pass has 23,190 destination-stage entries. Removing one
cycle each is an opportunity bound around 2.8% at offset 16, not a predicted
speedup. Preserve immediate/extension ownership, source value capture,
PC-relative base, register/stack-bank forwarding and full fault restart.

Required gates: exact source identity, directed coverage and fault restart,
all CPU suites and immutable first-100 corpus, full Sieve correctness, all
sixteen RAM placements and full-machine compile. Fit and hardware follow only
if measured coverage/gain justify them. Keep the accepted code unchanged.

## Larger target

The current score is still far from 1.9. These experiments establish the
forwarding and scheduling rules needed for broader in-order overlap; they do
not demonstrate a silicon-like pipeline. Full Speedometer workload profiling,
common memory-operand overlap and internal cache-hit service remain the larger
path. Do not sum state occupancies as independently removable cycles.
