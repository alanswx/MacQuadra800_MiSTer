# RESUME — CPU pipeline, the increments (2026-09-17)

Read this first, then `docs/cpu-pipeline-increments-20260917.md` (the
design note: every increment, why it is safe, every gate number), then
`CLAUDE.md`. Branch **`CPU-pipeline`** (cut from `add-CPU-fixes` at
3aa7953). Commit as work lands, **the user pushes**.

## What the user asked for and decided

"Implement the CPU pipeline correctly" per the plan in Alan's tree
(`../quadra800_alan/docs/CPU_PIPELINE_PLAN_20260915.md` and the 514-line
`CPU_PIPELINE_REWRITE_HANDOFF_20260915.md`, branch `cpu-fastread-20260915`):
three increments on the sequencer, then a six-stage engine (months).
Decision 2026-09-17 15:30: **the increments first**, on a new branch, the
.143 box, "go nuts". Area must not grow (the user: "we are running tight on
space"). Speedometer 4.02 is now `Quad Squad : Utilities :` (the operator
found a desktop alias and used it).

## State at hand-off

| what | value |
|---|---|
| branch head | see `git log --oneline -12` on `CPU-pipeline`; RTL head 5206845, docs/qsf after it |
| step 1 on hardware | rbf `d157f555` (seed 21, timing met, 37,439 ALMs): **Speedometer Mix 0.877** (0.875/0.878/0.879, +2.6 % over the shipped 0.855), CQD 0.643, FPU 0.464, 8.1 boot <= 123 s, clean shutdown; `docs/PERFORMANCE_MEASUREMENTS.md` section 16, `scratch/pipeline_step1/report.md` |
| build 2 (77aa72a, items 1-5) | seed 21 FAILED IN ROUTING (congestion, placement fine), 36,330 ALMs (87 %, -1,109 vs step 1); no rbf |
| build 3 (5206845, items 1-8) | seed 21 + `FITTER_AGGRESSIVE_ROUTABILITY_OPTIMIZATION ALWAYS` (build tree only, `scratch/edit_qsf_routability.py on` in `../MacQuadra800_wt3`): ROUTED, 36,010 ALMs (86 %), but the CPU clock MISSES by 3.760 ns (TNS -576). TimeQuest on the fitted db (`scripts/cpu/timequest_worst_paths.tcl`, reports in `scratch/pipeline_b3/`): state -> hint mux -> the cache's fast-hit word select -> ALU -> lookahead -> seed count -> epf_ftail, a 33 ns FALSE path (the hint bus carries the registered request in the request cycle, the analyzer follows the hint side) |
| build 4 (31445e5: + the cache qualifies/selects the fast hit from its own registered copy of the hint, cycle-identical) | seed 21 + the switch, launched 17:40, log `../MacQuadra800_wt3/scratch/build_b4_s21r.log`; the brief `scratch/pipeline_b3/BRIEF.md` serves it (rename the directory or the file's title) |
| the .143 box | left by the operator at the Mac OS 8.1 halt screen on the step-1 core, `.s0` QuadSquad8.hda; `.s1` (a MacLC disk) and `.s4` (a MacLC CD) are the user's, untouched |
| CPU gates | `scripts/cpu_gates_wsl.sh rtl/ap68040 <label>` now also runs `pipe_bench` (`rtl/ap68040/tb/asm/pipe_bench.s`); head: AP 23/23, bench_loop 81202/82000, pipe_bench 122190, corpus 32991462 with 0 REAL diffs |

## The increments (all on the branch, all gated)

1. 86b6b04 Alan's one-clock data-cache hit on a dedicated hint bus (AP68040
   6e65192 + wrapper b546572), applied unchanged. bench_loop -13.5 %.
2. fe6f226 R5/R6 carrier hoists (go_pc, decode_dbcc_brf), cycle-identical,
   about -1,100 ALMs at the fit.
3. d028821 redirect states hint their target (S_BCC_EXT, S_DBCC1,
   S_BSR_PUSH, S_JSR2, S_JMP1, S_RET2/3).
4. 3aac77e in-place issue + data hint for RTS/RTD/RTR/UNLK pops and MOVEM
   loads/stores (the hint alone did nothing; the whitelist matters).
5. 77aa72a forward taken Bcc.B from the lookahead arm through the go_pc
   carrier, only when the port is free (a redirect from an ack cycle is
   deferred and loses the sector adoption: corpus +1.3 % in that form).
6. 384d8f0 MOVEM loads retire on the acknowledge (corpus -0.66 %).
7. 62be250 pushes issue in place (BSR.B/.W, JSR, PEA, LINK).
8. 5206845 MOVEM stores from the loop (port A one register ahead), LINK and
   PEA retire on the acknowledge.

Synthesis: 55,210 ALUTs at 77aa72a against the release's 56,965.

## Rules learned today

- The corpus gate does not see cache-hit latency (identical cycles for
  step 1); `pipe_bench` and hardware do. The corpus does see MOVEM/RTS
  state folds.
- Every in-place issue site was withdrawn by Alan because it fed the
  `mem_addr_q` mux on the hint-to-acknowledge path; on the dedicated hint
  bus `mem_addr_q` is a register input, and the same sites now fit.
- A redirect raised where the port is busy is deferred to the fill engine
  and never adopts the target's sector; check `!epf_pend && !mem_req &&
  !mem_ack` before raising go_pc from anywhere new.
- The gate script copies the tree at start: a copy made before
  `build_tests.sh` learned `pipe_bench` reports a bogus "access outside
  memory model" FAIL in the pipe_bench section, not a core fault.
- Routing at 87 % can still fail at a seed; the routability optimization is
  the lever Quartus itself names, kept out of the committed recipe until it
  has proven itself.
- Anything combinational the core drives onto the hint bus is followed by
  the timing analyzer into every combinational consumer of that bus in the
  cache, request cycle or not (it cannot see that `mem_req ? mem_addr_q :
  hint_addr` selects the registered side then).  The fast hit's index
  compares and word/lane select therefore use the cache's registered copy
  of the hint (31445e5); the live hint bus may only feed RAM address inputs
  and the MMU's hint registers.  Keep it that way when adding hint sources.

## Next

1. Build 3's result: if it fits and meets timing, copy the rbf to
   `scratch/pipeline_b3/`, fill the brief, run the Opus operator (the
   step-1 prompt in this session's transcript works verbatim), write
   section 17 of `docs/PERFORMANCE_MEASUREMENTS.md`, the ledger line in the
   `.qsf`, the Builds row in the design note. If it fails routing: seed 22
   with the switch, then 23; if it misses the CPU clock: the path report
   (`scripts/cpu/timequest_worst_paths.tcl`) and the increment it names.
2. A release needs the full gate (A/UX 3.1 at 32 MB, CD audio by ear): the
   user's call; nothing in `releases/` was touched.
3. Further increments that are designed but not built: MOVEM's S_MOVEM_SET2
   folded into SET (decode selects An); the record applied to a resident
   target word in S_FETCH; the two-sector refill buffer (Alan's brf2, corpus
   -10 %, +2,300 ALMs, never pushed); the six-stage engine itself.
