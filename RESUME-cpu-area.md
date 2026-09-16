# RESUME — CPU area/perf work (updated 2026-09-15 21:45)

Read this first, then `CLAUDE.md`. Branch `alan-perf-20260908`; commit as
work lands, **the user pushes** (their ssh key is not in the tool shells; a
`github` HTTPS remote exists and pushed up to 1043e4c once). `main` untouched
at cba1490.

## One-paragraph state

Alan's AP68040 **checkpoint 15** is integrated and made ~5,500 ALUTs smaller
by hoisting six multi-site sequencer tasks into single post-`case` carrier
arms (R1..R6, cycle-identical: AP suite 11/11, bench_loop 94368/95166,
corpus-100 0 REAL diffs). Its first hardware run **hung the Mac OS 8.1 boot at
~15 %**; the cause was **a window in the 53C96 SCSI model, not the CPU**, fixed
in `rtl/ncr53c96.sv` (commit 15be2a2) and validated in the full-machine sim.
The fixed bitstream is being fitted (seed walk) and then goes to the .92
hardware gate.

## The hang and its root cause (2026-09-15)

Hardware: the R1..R4 candidate rbf `8c6d48b5` (submodule 8778213, seed 21)
froze the Quad Squad 8.1 splash 5/5 on a restored disk the store head
`ba54b0ee` boots (operator report `scratch/gate_diet/report.md`). The
Verilator sim reproduced it from the pristine image (`~/qs8_pristine.hda` in
WSL, md5 93738964…). Evidence and traces: `scratch/ck15_hang/analysis.md`.

Mechanism: the Apple CD-ROM extension sends a 28-byte MODE SELECT(6) to the
CD target (ID 3, no disc). The model raised Bus Service the cycle the FIFO
drained, then parsed the list (`msel_st` 1..10) and moved the phase to STATUS
~12 cycles later, raising a second Bus Service that merged into the first.
The driver polls the STATUS register for INT; checkpoint 15's loop read it
**9 cycles** after the raise (INT + phase DATA OUT), cleared the ISR, and
waited forever. The store head read it at 13 cycles (INT + STATUS) -- one
cycle of margin. Posting off (tree C) hung identically.

Fix: the data-out drain (PIO and DMA paths) withholds Bus Service when the
drained byte completes a judged CD MODE SELECT list; the verdict's `msel_fin`
raises it with the phase already STATUS. `tb_ncr53c96` passes (476,837
checks). Fixed sim (tree A): the poll sees no INT until STATUS, then ICCS,
message accept, next READ(10) -- and the boot reaches the **full Finder
desktop at 90 s of guest time** (frame 5400; `scratch/ck15_hang/`).

Sim tooling added (all `ifdef VERILATOR` / sim_main.cpp): `[NCRREG]`
register-level 53C96 trace armed by the first MODE SELECT to the CD (cap
80,000 accesses), `INT-` edges, `--trace-on-ncr` (start the CPU trace when
that arms), `--trace-max N`, `@main_time` stamps on trace lines.

## Builds in flight (fits take ~25 min now)

| tree | netlist | seed | result |
|---|---|---|---|
| main | R1..R6 (923c544) + fix | 22 | MISSED, CPU clock -0.619 ns |
| wt2 | R1..R6 (923c544) + fix | 23 | MISSED, CPU clock -1.426 ns (TNS -86.6) |
| main | R1..R6 (923c544) + fix | 24 | MISSED, CPU clock -1.669 ns (TNS -85.4) -- R1..R6 PARKED |
| wt2 | R1..R4 (8778213) + fix | 21 | CPU clock MET +0.267, **HDMI -0.766** (one endpoint), 38,788 ALMs (93 %) |
| main | R1..R4 (8778213) + fix | 22 | CPU clock +0.712, **HDMI -0.095** (one endpoint), 38,711 ALMs; rbf kept as `scratch/MacQuadra800_fix_r4_s22_HDMI-0.095.rbf` |
| main | R1..R4 (8778213) + fix | 24 | fitter could not place (error 11802) |
| wt2 | R1..R4 (8778213) + fix | 23 | HDMI -0.774, CPU -0.004 (52 min fit) |
| wt2 | R1..R4 (8778213) + fix | 27 | fitting since 22:56 (`../MacQuadra800_wt2/scratch/build_fix_r4_s27.log`) |
| main | R1..R4 (8778213) + fix | 25 | fitting since 22:49 (`scratch/build_fix_r4_s25.log`) |
| wt3 | R1..R4 (8778213) + fix | 26 | fitting since 22:49 (`../MacQuadra800_wt3`, a third detached worktree at 378e3a8 with the 8778213 files copied in; `scratch/build_fix_r4_s26.log`) |

The HDMI clock is the framework's 148.5 MHz pixel clock. TimeQuest on the
seed-23 db (`../MacQuadra800_wt2/scratch/hdmi_worst_*.txt`, script
`scratch/hdmi_paths.tcl` there): the failing endpoint is `sys_top`'s own
`hdmi_dv_hs -> hs` register pair with -0.578 ns clock skew (the launch FF
placed at FF_X37_Y2 with 2.3 ns of clock insertion) -- a placement artefact
inside `sys/`, not our RTL; the next HDMI paths are `ascal` at +0.117. The
CPU clock's worst path is `rr_a[0] -> epf_data[6][1]` (the hint adder cone).
Seeds are the lever; three trees walk in parallel.

R1..R4 and R1..R6 are cycle-identical; R1..R6 is ~1,300 ALMs smaller but its
CPU-clock path is a lottery with the fix in (three misses, growing). R1..R4's
CPU clock holds (+0.27..+0.36); its HDMI endpoint is the usual seed-sensitive
one. Ship the first R1..R4 seed that meets both. Failed rbfs are kept as
`scratch/MacQuadra800_fix_r6_s2{2,3,4}_TIMINGFAIL.rbf` (main/wt2) and
`../MacQuadra800_wt2/scratch/MacQuadra800_fix_r4_s21_HDMIFAIL.rbf`.

## Next

1. Hardware gate of the timing-met rbf on the .92 box (Opus operator):
   `scratch/gate_fix/BRIEF.md` -- fill in CANDIDATE_RBF and write
   `scratch/gate_fix/candidate.md5` first. Box state: store head at the 8.1
   halt screen, `.s0` = QuadSquad8.hda (restored, clean), no `.s1`/`.s4`.
   Both OSes boot + clean shutdown; Speedometer 4.02 Mix ×3 + CQD + FPU vs
   0.462 (store head) / 0.360 (release) / 0.855 (Alan's trimmed profile).
2. Release: `releases/MacQuadra800_YYYYMMDD.rbf`, `releases/README.md` row +
   section, commit, push; update memory `next-cpu-arch-fork-merge`.
3. Submodule publication: `rtl/ap68040` `origin` is alanswx/AP68040 (no write
   access) and no danifunker/AP68040 fork exists, so 923c544 / 8778213 /
   9216f3e are unpublished -- the pushed superproject branch dangles for
   anyone else. Needs a fork (user's call) and `.gitmodules` pointing at it.
4. Report to Alan: carrier-hoisting pattern (`docs/cpu-area-consolidation.md`),
   the SBCD/PACK/UNPK reduced-body illegal artefact, this 53C96 window (his
   profile has no CD target, so he could not see it), and that his `sys/`
   switches are unnecessary once the core is small.
5. Separate mission (user's call): move SCSI into `Main_MiSTer`.

## Git / artifacts

| thing | value |
|---|---|
| branch | `alan-perf-20260908` = `github/alan-perf-20260908` |
| submodule at HEAD | `923c544` (R1..R6 early-data, branch `wombat-area-diet`); `8778213` = R1..R4 |
| store head (last known-good on hardware) | rbf `ba54b0ee`, submodule `9216f3e`, on the box as `MacQuadra800_store_ba54b0ee.rbf` |
| hung candidate | rbf `8c6d48b5` = `scratch/MacQuadra800_diet_r4_s21_8c6d48b5.rbf` (pre-fix) |
| pre-fix R1..R6 seed-22 rbf | `../MacQuadra800_wt2/scratch/MacQuadra800_diet_r6_s22_2f739338.rbf` (hangs the same way) |
| WSL sims | `~/MacQuadra800_A` (candidate, now with the fix; hang evidence `sim_run_hang.log`/`cpu_trace_hang.log`), `_B` (store-head control), `_C` (posting off, killed) |

## Rules
- Only optimize, remove nothing (CD-ROM stays in). **Never edit `sys/`.** Use the
  **.92 box** (192.168.99.92). Delegate hardware to the Opus operator. Commit as
  work lands; do not push (the user pushes). Design
  mechanism + gates: `docs/cpu-area-consolidation.md`; audit
  `scripts/cpu/audit_task_sites.py`; gates `scripts/cpu_gates_wsl.sh` and
  `scripts/cpu_corpus100_gate.sh`.
