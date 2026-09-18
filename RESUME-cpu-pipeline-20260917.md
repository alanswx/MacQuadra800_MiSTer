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
| build 4 (31445e5: + the cache qualifies/selects the fast hit from its own registered copy of the hint, cycle-identical) | seed 21 + the switch: routed, 36,326 ALMs (87 %), CPU clock -2.362 (HDMI +0.135, clk_ram +0.950). Worst path (reports in `scratch/pipeline_b4/`): sr[13] -> A7 bank -> port A -> shift count -> the ALU's ROXx modulo, a 33-bit DIVIDER from `n % (nbits+1)` -> shifter -> flags -> lookahead -> the carriers muxing the two hoisted bodies' targets -> seed cone -> epf_ftail, 32 ns |
| build 5 (24579aa: + constant-modulus ROXx count, + `dbrf_a_early = go_pc_t_early`; cycle-identical, zero early-target mismatches) | seed 21 + the switch: routed, 35,926 ALMs (86 %), CPU clock -1.042 (HDMI +0.341, clk_ram +0.408). Worst path (`scratch/pipeline_b5/`): ATC RAM -> hit -> pipe entry -> walk decision -> the cache's inv_wren (store term carries c_req) -> fast_hit -> c_rdata -> ALU -> lookahead -> seed cone -> epf_ftail. rbf `595297fb` (`scratch/pipeline_b5/`) run on the .143 box as a labelled TIMING PROBE by the Opus operator (report `scratch/pipeline_b5/report.md`) |
| build 6 (c84a5e7: + fast_hit tests !snoop_wr instead of !inv_wren and compares the snoop row against the registered hint's set; cycle-identical) | seed 21 + the switch: **35,797 ALMs (85 %), CPU clock MET +0.139, clk_ram +0.445, HDMI -0.001** on one `sys_top` video register (the seed-sensitive endpoint, try-builds policy). rbf `cda6ba11` = `scratch/pipeline_b6/MacQuadra800_b6_s21r_cda6ba11.rbf`, brief `scratch/pipeline_b6/BRIEF.md` ready; the build-5 probe (same RTL) measured **Mix 0.900/0.902/0.902**; build 6 itself on hardware: **Mix 0.900/0.902/0.903**, CQD 0.660, FPU 0.464/0.467, boot <= 85 s, clean 46 s shutdown, no artefact in any captured frame (`scratch/pipeline_b6/report.md`) |
| the .143 box | left by the build-6 operator (20:45) at the Mac OS 8.1 halt screen on **build 6's rbf** (`/media/fat/_Unstable/MacQuadra800_b6_s21r_cda6ba11.rbf`), `.s0` QuadSquad8.hda; `.s1` (a MacLC disk) and `.s4` (a MacLC CD) are the user's, untouched |
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
9. (2026-09-18) BRA.W/.L, BSR.W/.L, JSR/JMP abs.W/abs.L/d16(PC) dispatch
   from the retire that pops them straight into S_BCC_EXT/S_JSR1/S_JMP1
   with the target fetch out in that cycle, hinted (`dispatch_branch`,
   `sgo`, `hint_bd`); go_pc_now dispatches a resident target itself; the
   S_MWR acknowledge folds S_BSR_PUSH/S_JSR2 when the stream is already
   at br_tgt.  The plan's item 2 done exactly, without a table, for every
   form whose target is in the queue words.  pipe_bench 122,190 ->
   120,194, the new branch_bench 129,778 -> 118,784, corpus 32,980,201
   with 0 diffs, the new t_branch_early leg passes on both cores.
10. (2026-09-18) DBcc dispatched from the pop into S_DBCC1
    (`dispatch_dbcc`; refused when the retiring arm writes its Dn,
    `rfw_now`): bench_loop 81,202 -> 68,354 (-15.8 %), pipe_bench
    118,696, branch_bench 117,286, corpus 32,979,913 with 0 diffs.
    Not in build 7 (which is increment 9 alone).
9b. (2026-09-18) Build 7 (8a9b392, seed 21 + the switch) routed at
    36,388 ALMs (87 %) but MISSED the CPU clock by 1.575 ns: the early
    fetch's second issue_ifetch target let the lookahead's flags select
    the seed cone's target (rule 3; `scratch/pipeline_b7/`).  Fix: the
    early fetch takes go_pc_t_early (default arm `rd_is_bcc ? rd_bcc_t :
    bd_t`) and is skipped in S_BCC_EXT/S_DBCC1/S_FBCC/S_FDBCC; cycle-
    identical on the benches.  Build 7b = the fix on increment 9 alone.
    An RTS/RTD/RTR-from-the-pop increment was tried and withdrawn
    (cycle-neutral: UNLK/RTS is bound by the acknowledge cycle); its
    tests stay.

Synthesis: 55,210 ALUTs at 77aa72a against the release's 56,965; 55,598
at 8a9b392 (build 7, increment 9).

User instruction 2026-09-18 22:05: ONE synthesis at a time, and finish
analysing a build before starting the next increment.

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

1. DONE: build 6 measured on hardware (section 17 of docs/PERFORMANCE_MEASUREMENTS.md), the routability switch is in the committed qsf, the recipe reproduces build 6. Open: the user judges the HDMI 0.001 ns miss at the display; a release needs the full gate (A/UX 3.1 at 32 MB, CD audio by ear) -- the user's call. If a later build fails, copy the rbf to
   `scratch/pipeline_b4/` (or a b5 dir), fill the brief, run the Opus operator (the
   step-1 prompt in this session's transcript works verbatim), write
   section 17 of `docs/PERFORMANCE_MEASUREMENTS.md`, the ledger line in the
   `.qsf`, the Builds row in the design note. If it fails routing: seed 22
   with the switch, then 23; if it misses the CPU clock: the path report
   (`scripts/cpu/timequest_worst_paths.tcl`) and the increment it names.
2. A release needs the full gate (A/UX 3.1 at 32 MB, CD audio by ear): the
   user's call; nothing in `releases/` was touched.
3. Build 7b (increment 9 + the 9b timing commit 788ab35, cherry-picked
   onto 8a9b392 in `../MacQuadra800_wt3` as its detached commit 2d9a8a0,
   seed 21 + the switch) MEETS TIMING on every clock: CPU +0.580 (build
   6: +0.139), HDMI +0.364, RAM +0.527, hold +0.147, 35,807 ALMs (85 %),
   synthesis 55,143 ALUTs -- the valid-run seed count paid for increment
   9's logic.  rbf 9e3b7d9d in `scratch/pipeline_b7/`, brief filled
   (`scratch/pipeline_b7/BRIEF.md`); the Opus operator runs it on the
   .143 box (the box was at the 8.1 halt screen on build 6).  Expect the
   call-heavy tests to move (JSR abs.L 9 -> 6 cycles, BSR.W 8 -> 6,
   JMP/BRA.W -2/-3).  Build 8 (78ba885, the branch head = increments 9
   + 10 + 788ab35, seed 21 + the switch) also MEETS every clock: CPU
   +1.114 (the branch's best), HDMI +0.217, RAM +0.914, hold +0.258,
   35,952 ALMs (86 %), rbf 69c53878 in `scratch/pipeline_b8/` with its
   brief; it runs on the box after build 7b's run (one operator at a
   time on the .143 box).
4. The rest of the plan's item 2, in order of expected value: RTS's pop
   read issued from the retire that pops it (exact, one cycle per
   return, no prediction); BRA.B/BSR.B after a non-producer retire
   through the lookahead arm (cond 0000 needs no flags); then the table
   proper for Bcc.W/.L and JSR/JMP (An) with a mispredict path that
   re-arms the fall-through (design in section 9 of the design note).
5. Further increments that are designed but not built: MOVEM's S_MOVEM_SET2
   folded into SET (decode selects An); the record applied to a resident
   target word in S_FETCH; the two-sector refill buffer (Alan's brf2, corpus
   -10 %, +2,300 ALMs, never pushed); the six-stage engine itself.
