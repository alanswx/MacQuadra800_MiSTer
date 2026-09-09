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
- Hardware gate: __GATE__

## Box / repo state

__STATE__
