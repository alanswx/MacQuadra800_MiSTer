# RESUME — Alan's 299cb36 CPU on branch `alan-perf-20260908` (2026-09-08 evening)

Read `RESUME-open-items.md` for the state of everything else; this file is
only the CPU bump. Branch `alan-perf-20260908`, cut from `main` at `cba1490`
at the user's request ("pull in Alan's latest performance enhancements, go
nuts, make a new branch").

## What was taken

`rtl/ap68040` moved from `5aa596f` (the shipped 20260908_3 CPU) to Alan's
`299cb36`, the tip of `origin/wombat-upstream-fixes`. Alan publishes one
branch per step, each stacked on the last; that branch is the newest and
contains all of them (`docs`: the graph is in the memory note
`alan-ap68040-branch-layout`). Ten commits:

| commit | what |
|---|---|
| 8231eec | FPU register bank inferred in MLABs (`ap040_fp_regfile`, `ramstyle = "MLAB, no_rw_check"`); the FPU drops from 8,559 to 7,044 cells |
| d543f2d | CMP.L Dn,Dn selects both register-file ports in decode and skips PIPE_START |
| 8ab1057 | a resident queued opcode retires directly into decode (no S_FETCH cycle); BSR.B / MOVE USP,An get same-edge forwarding of A7/USP |
| 0a84732, c897d77 | resident immediate extension words are consumed in S_DECODE instead of an empty S_IMMF cycle (refuses an outstanding prefetch or same-edge memory ack) |
| 95319b4, c9ecf79 | a taken DBcc whose target window is resident in the branch refill sector dispatches from the refill queue (`decode_dbcc_brf`) |
| 8951fd2 | one-longword sequential instruction-cache lookahead (`ipred_*` in `ap040_cache.v`): the idle data-RAM cycle after an I-hit reads the next longword and serves it from C_IDLE |
| 9996357 | Adam Polkosnik: t_mmu replay of the NeXTSTEP loadable-kernel-server fault shape (checks 200-212) |
| 299cb36 | Adam Polkosnik: a cache-invalidation race (`store_inv_lost` now gates `rd_accept` and the C_IDLE accept) and the FPU raising vector 55 for packed stores without preparing the BUSY frame |

Also in the stack: the fetch-queue / branch-refill / m16 payload arrays are
no longer reset (only their valid/count controls are), an FPGA packing
saving. No top-level port or parameter changed; `rtl/wombat_cpu.sv` is
untouched.

**Not taken** (Alan did not carry them forward): `wombat-inline-branch-refill`
(dispatch of every `go_pc` target from the refill sector; conflicts with the
DBcc line that superseded it) and `wombat-predecode-regalu` (ADD.L Dn,Dm
predecoded at retirement with a register-file forwarding mux; merges cleanly
onto 299cb36, tested in a scratch worktree, but his later icache-lookahead
commit was built without it). Both are one `git merge` away if wanted.

One thing to raise with Alan: the I-cache lookahead buffer (`ipred_data`)
is a private copy of an instruction longword that is cleared by CINV, reset
and any non-matching instruction request, but **not by a bus snoop**
(`s_stb`) that invalidates its source line. The window is one longword and
needs code being DMA'd over while it executes, so it is theoretical for
Mac OS / A/UX; noted, not patched (the snoop port is ce-independent, so the
clear would need the `fill_snooped`-style sticky flag, not a one-liner).

## Verification so far

- Verilator (WSL, sources synced 23:04): `tb_wombat_bus32` 6/6,
  `tb_store_buffer` all pass, `tb_memory_path_registered_first_miss` 0
  failures (52.4 MB/s, 304 ns average fill), `tb_sdram` 45/45 with 0 chip
  protocol errors, and the AP68040 `tb_ap040_cache_snoop` (including Adam's
  new invalidation-race test) ALL TESTS PASSED under Verilator
  (`scratch/wsl_benches.log`). WSL has no iverilog/vasm, so Alan's full
  self-test suite was not run here (the user's standing instruction: Alan
  runs it; build and fire onto hardware).
- Build (this tree, `scratch/build_alan_s21.log`): release recipe unchanged,
  seed 21, **fits first try**: 41,060 / 41,910 ALMs (98 %), setup +0.579 ns
  (HDMI PLL domain; clk_sys +0.753, clk_ram +0.943), hold +0.225 ns,
  recovery +3.98; Analysis & Synthesis 3 min, whole flow 20 min. rbf md5
  `512cd4f8869ca815ec27b0cc0af150e2`, copy in
  `scratch/MacQuadra800_alan299_512cd4f8.rbf`. Post-placement checks: no
  `open_row` altsyncram in the map report (the page table stayed in logic),
  `ap040_fp_regfile` inferred as `altdpram` (MLAB). CPU hierarchy 37,779
  cells vs 38,138 for 5aa596f (`ap040_core` own 25,076, FPU 7,044, cache 721).
- Full-machine Verilator boot of `scratch/install8_result.hda` (fresh 8.1
  install) started 23:10 in WSL (`~/MacQuadra800/verilator/sim_run.log`,
  screenshots `screenshot_f*.png` every 1200 frames): ROM start-up and the
  disk-search icon at 20 guest-seconds; slow (~85x) with the gate sim
  beside it. The oracle gate sim (`gate.hda`, `sim_gate.log`) started 23:33;
  score it with the recipe in `RESUME-cpu-merge.md` when `[HB] pc` parks at
  `000400FA` (results at sector 1398, 2048 sectors).
- Hardware gate: **Mac OS 8.1 PASS, A/UX FAIL at shutdown** (operator run 23:28–00:45,
  `scratch/gate_alan/`, 71 screenshots, `speedometer.md`): Finder desktop
  at 162–202 s (previous build ~135 s, same mounts), clock ticks, mouse and
  menus live, Speedometer Benchmark Mix **0.394/0.395/0.396 vs 0.361**
  (Queens 1.366 s, Bubble 2.323 s, Permutations 3.321 s, Dhrystones 4577),
  CQD 0.348 vs 0.317, FPU 0.279 vs 0.250, no first-run anomaly, Special →
  Shut Down clean. A/UX: multiuser desktop 225 s, CommandShell answers
  `uname -a`, but `shutdown -h now` stalled after its kill lines with a
  half-erased Finder; `sync`/`halt` still flushed to disk, no repaint for
  25 min, never "You may now switch off". Full table in
  `docs/PERFORMANCE_MEASUREMENTS.md` §13.
- **Experimental build B** (`../MacQuadra800_wt2`, submodule `6d50064` =
  299cb36 + `wombat-predecode-regalu`): fits at 99 % but fails timing,
  clk_ram −1.045 ns and HDMI −0.064 ns (`scratch/build_B_regalu_s21.log`
  there). Not pursued; the tree is left checked out at it.

## Box / repo state

- **MiSTer:** `MacQuadra800` (the candidate, `/media/fat/_Unstable/MacQuadra800.rbf`,
  md5 512cd4f8) with the **A/UX guest wedged mid-shutdown** on
  `HD60_512-AUX3.1-Installed.hda` (`scratch/gate_alan/46_final_state.png`).
  The operator typed `sync` and `halt` (both flushed) and did not reload;
  slot 0 is already restored to `games/MacQuadra800/QuadSquad8.hda`. A
  `load_core` over it is the user's call (binding rule 1); expect a long
  fsck on the next A/UX boot. The SGI Indy session that had the box before
  was idle for hours and is not running.
- **Repo:** branch `alan-perf-20260908` (from `main` `cba1490`): `bffbd3b`
  submodule bump, `f5ba53e` qsf note, `bfb3b37` README/RESUME, then this
  update. `main` untouched. Nothing pushed. Scratch worktree of the
  submodule with the merged experiment: scratchpad `ap_merge_test`
  (`git worktree prune` in `rtl/ap68040` removes the stale entry).
- **WSL sims** (`~/MacQuadra800*`): the 299cb36 boot and gate runs were
  killed (both stuck at the ROM's disk-scan loop, pc 408099B0); the control
  at `5aa596f` (`~/MacQuadra800_ctl`, `sim_ctl.log`, screenshots at 1200 and
  2400 frames) and four bisect trees `~/MacQuadra800_b_<commit>` (8ab1057,
  c897d77, c9ecf79, 8951fd2) with `run.hda` = the fresh 8.1 install image
  were set up -- **void**: the control at `5aa596f` shows the same
  flashing "?" at frames 1200 and 2400 on `install8_result.hda`, so that
  image does not boot in this harness with either CPU (the sim's SCSI
  target or the image, not the CPU). The live sim check is the proven gate
  image: `~/MacQuadra800_ctl/verilator/sim_gate_ctl.log` (5aa596f on
  `gate_ctl.hda`) against `~/MacQuadra800/verilator/sim_gate.log` (299cb36,
  killed at cycle 3.36G with 18,664 reads, no `io_wr`, pc still in ROM) and
  the four bisect trees now running `gate.hda` (`sim_gate_b.log`); a pass
  shows `io_wr` lines and `[HB] pc` leaving `40xxxxxx` for RAM.

## Next

1. Decide the box: reload the candidate (or the release) over the wedged
   A/UX; then re-run the A/UX half with Special → Shut Down AND with
   `shutdown -h now` on both this candidate and `20260908_3` to separate
   the CPU from the path.
2. Finish the sim bisect (control first). If a commit is guilty, report
   it to Alan with the sim recipe; hardware boot time (162–202 s vs 135 s)
   is the second symptom to give him.
3. No release from this branch until A/UX shuts down cleanly and the boot
   time is explained.
