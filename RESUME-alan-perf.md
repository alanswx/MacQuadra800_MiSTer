# RESUME — branch `alan-perf-20260908`: Alan's CPU stack + the lookup read-ahead (2026-09-12)

Read `RESUME-open-items.md` for everything that is not the CPU. This file is
the CPU branch: what is on it, what was measured, what is owed.

## State of the branch (newest first)

| commit | what |
|---|---|
| `0651e59` | docs: `docs/cpu-lookup-readahead.md`, §14 of `docs/PERFORMANCE_MEASUREMENTS.md`, sim `--prof` profiler, `run_corpus.sh` tolerates BLKLOOPINIT |
| `7d8569d` | AP68040 `d325967`: Quartus single-driver fix for the read-ahead index |
| `d6a1815` | **AP68040 `b80a79e` (branch `wombat-lookup-readahead`): cached hits resolve in the acceptance cycle** — idle read-ahead of the tag row and data ways in `ap040_cache`, plus a one-cycle-early lookup hint from the sequencer (`pre_valid/pre_addr/pre_fc/pre_instr`) through the MMU (ATC row read on the hint) to the cache. `rtl/wombat_cpu.sv` carries the new wires. |
| `4404a15` | AP68040 to Alan's `164a376` (`cpu-early-store-20260909`): aligned normal-RAM reads issue while entering `S_MRD`, aligned `S_EXEC` stores while entering `S_MWR` |
| `6452ac9` | Alan's exact multiply-by-205 `bin2bcd` in `ncr53c96`/`cd_audio` (~692 ALUTs), `build_only.sh --check` generates `build_id.v` |
| `e4c08e2` | verilator: the sim block device serves multi-block (`sd_blk_cnt`) transactions with the 13-bit buffer address; the gate image runs to its result write again |
| `945ff6b`… | the 299cb36 bump and its gate notes (below) |

`main` is untouched at `cba1490`. Nothing is pushed. The AP68040 submodule's
branch `wombat-lookup-readahead` (3 commits on Alan's `164a376`) lives only in
`rtl/ap68040`'s local repo; his remote branches were fetched (HTTPS) — see
the memory note `alan-fork-layout-2026-09` and `../quadra800_alan`.

## What the read-ahead does (short; the design note has the rest)

A translated cached read went core → MMU ATC row read → cache tag/data read
→ compare → ack in four cycles because every stage waited for the one in
front. The cache now reads its RAMs in every idle cycle at the address being
presented (the set index is inside the page offset, so it is correct before
translation), re-validates that read against the accepted request, and acks
a hit in the acceptance cycle; the sequencer additionally announces its next
data access / queue fill one cycle early so the ATC and cache rows are
already read when the request registers. Translated cached read 4 → 2
cycles; untranslated 3 → 2. Snoops on the read-ahead edge or in the
acceptance cycle fall back to the old `C_LOOK` path (directed test T14).

Verified in simulation: complete AP68040 suite, first-100 silicon corpus
(0 REAL diffs), `bench_loop` **-9.1 %** (147,790 → 134,406; `S_MRD` -32 %,
data-read request→ack 2.0 → 1.0 cycles). Not yet built or run on hardware.

## Builds (release recipe, seed 21)

| head | ALMs | timing | rbf |
|---|---|---|---|
| `4404a15` (Alan's tip) | 40,265 (96 %) | **HDMI PLL domain -0.164 ns**; clk_sys +0.508, clk_ram +1.189, hold +0.198 | `scratch/MacQuadra800_alan164_s21_6d6a6daf.rbf` — not deployable, seed walk owed |
| `7d8569d` (read-ahead) | in flight since 01:13 (`scratch/build_readahead_s21.log`; the fitter was still placing at 01:55, longer than the 20-minute tip flow) | | |

Alan's own seed-21 fit of the same tip RTL was 40,523 ALMs / +0.398 ns on
his box; ours placed differently. If the read-ahead build also misses the
HDMI domain, walk seeds (22, 23, …) — it is the known placement lottery, not
the RTL (see the qsf comment block).

## Hardware and the .92 box

`scripts/local.env` now points at **192.168.99.92** (the user: .143 is not
at home). It is a shared box: it was found running the **SGIIndy core with a
live IRIX 5.3 desktop** (`scratch/p92_initial.png`), so binding rule 1
applies — no `load_core` until the user says the Indy can go. Seeded for
us meanwhile: `games/MacQuadra800/boot.rom`, `QuadSquad8.hda` (from the
08-31 backup, `backup/QuadSquad8.hda.gz`), `HD60_512-AUX3.1-Installed.hda`
(pristine md5 b44b7623…, from `backup/…zip`). No `config/MacQuadra800.s0`
yet — `deploy_screenshot.sh` seeds it. Its Main (`/media/fat/MiSTer`, md5
d6d63ec4) has `mac_eth` strings but is not verified to be the 20260908 fork
build the CD path needs.

The gate for this branch, once a timing-clean rbf exists and the box is
free: Mac OS 8.1 boot + Speedometer 4.02 Benchmark Mix (compare with
0.395 for 299cb36 and Alan's 0.405 for 164a376), then A/UX boot +
`shutdown -h now` (the 299cb36 gate wedged there; still unexplained — see
"Older notes"). Hand the driving to an Opus operator per the memory note.

## Simulation infrastructure that now works

- WSL `~/local/bin`: `iverilog`/`vvp`/`vasm` built from source (memory note
  `wsl-ap68040-toolchain`). `~/ap040_base` = 164a376, `~/ap040_work` = the
  read-ahead; `bash run_tests.sh`, then `vvp build/tb_prog.vvp
  +prog=build/bench_loop.hex +prof +memlat`. Strip CRs after every rsync.
- `SingleStepTests/preboot/sim040/run_corpus.sh` under WSL Verilator 5.020
  with `AP68040_RTL=~/ap040_work/rtl` (Retro68 at
  `~/repos/Retro68-build/toolchain`). The corpus payload runs with the
  caches OFF, so its cycle count does not see cache work.
- Full-machine sim (`scripts/sim_wsl.sh build|disk|run`): the block device
  now honours `sd_blk_cnt`, so images boot again; `--prof` prints the
  sequencer state histogram, clocks/dispatch, port-wait cycles, `S_MRD`/
  `S_MWR` split by cache FSM state and address region, and acceptance-cycle
  hit counts at every heartbeat (5M cycles). `+blkdbg` traces block-device
  requests on stderr.
- **Known sim harness bug, not the CPU:** every long boot so far (gate
  image on both 5aa596f and 299cb36; the fresh 8.1 install on the
  read-ahead CPU) stops in the ROM SCSI Manager (`pc 408D21DE`/`408D22FC`)
  after a few hundred sector reads: the last `io_rd+` never gets its
  `io_ack+` from `verilator/sim/sim_blkdevice.cpp`. The 8.1 boot's case was
  the second read of lba 2282, right after the boot's first *write*
  (lba 98). The `+blkdbg` run started at 01:58 (`~/MacQuadra800/verilator/
  sim_blk.log`) is meant to catch it. Until it is fixed the sim cannot
  reach the Finder.
- The earlier "bisect" trees `~/MacQuadra800_b_*` are void (all six ran the
  gate corpus to its result write and then hit the same harness stop).

## First real-workload profile (read-ahead CPU, ROM init, 145M cycles)

6.52 clocks per dispatch. `S_MRD` 25.7 %, `S_DECODE` 16.6 %, `S_FETCH`
11.7 %, `S_MWR` 6.6 %, `S_DBCC1` 6.2 %, `S_PIPE_START` 5.5 %, `S_EXEC`
5.1 %, `S_IMMF` 5.0 %, port-wait (data access held behind a queue fetch)
2.5 %. This is ROM start-up code, not the OS; the uncapped `--prof` boot
will give the Finder-era numbers. Alan's Speedometer profile on 299cb36 was
12.05 clocks/dispatch with `S_MRD` 35 %.

## Next

1. Read-ahead build result → seed walk if HDMI misses → gate on .92 when
   the Indy is released (ask the user).
2. Fix the sim block-device stop (above) so a full boot can be scored in
   simulation; then profile the Finder/Speedometer phase and pick the next
   sequencer target from it (`S_DECODE` and `S_FETCH` are the next largest
   after `S_MRD`; the data-side gain is now mostly in misses).
3. Report to Alan: the read-ahead (submodule branch `wombat-lookup-readahead`
   on his 164a376) and the T12 baseline change; his tip misses HDMI timing
   at seed 21 on our build.

## Older notes (the 299cb36 gate, 2026-09-08/09)

`299cb36` fitted at seed 21 (98 %, +0.579 ns), Mac OS 8.1 passed with
Speedometer Benchmark Mix 0.395 vs 0.361, A/UX 3.1 reached the desktop but
`shutdown -h now` wedged (kernel alive, no repaint), and the Finder desktop
came 30–60 s later than 20260908_3. Full table in
`docs/PERFORMANCE_MEASUREMENTS.md` §13, operator screenshots in
`scratch/gate_alan/`. The Verilator "boot failure" attributed to that CPU
was the block-device harness (fixed in `e4c08e2`), so it is not evidence
against 299cb36; the A/UX wedge and the slower boot remain to be separated
between CPU and path on the next gate.
