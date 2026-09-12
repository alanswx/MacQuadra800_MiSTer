# RESUME — branch `alan-perf-20260908`: Alan's CPU stack + the lookup read-ahead (2026-09-12)

Read `RESUME-open-items.md` for everything that is not the CPU. This file is
the CPU branch: what is on it, what was measured, what is owed.

## State of the branch (newest first)

| commit | what |
|---|---|
| `c9219a8` | **AP68040 `9216f3e`: fill hold behind a resident redirect, short-branch target hint, one-state `MOVE Rn/#imm,(An)/(An)+/-(An)/d16(An)/abs` store (`S_PIPE_STORE`)** -- corpus -5.4 % cycles, 0 REAL diffs; building |
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
| `7d8569d` (read-ahead) | 40,584 (97 %) | **MET**: HDMI +0.256, clk_sys +0.307, clk_ram +0.884, hold +0.208 | `scratch/MacQuadra800_readahead_s21_0018d4a9.rbf`, also `/media/fat/_Unstable/MacQuadra800_readahead_0018d4a9.rbf` on .92 — **the gate candidate** |
| `c9219a8` (+ fill hold, branch hint, one-state store) | 41,096 (98 %) at seed 22 | seed 21 failed to route; **seed 22 MET**: clk_sys +0.256, HDMI +0.409, clk_ram +0.593, hold +0.225 (seed 23 in `../MacQuadra800_wt2`, `scratch/build_store_s23.log`, in flight) | `scratch/MacQuadra800_store_s22_ba54b0ee.rbf`, on .92 as `/media/fat/_Unstable/MacQuadra800_store_ba54b0ee.rbf` -- **the preferred gate candidate**; the read-ahead-only rbf is the fallback |

Alan's own seed-21 fit of the same tip RTL was 40,523 ALMs / +0.398 ns on
his box; ours placed differently. The read-ahead flow itself died after a
successful fit because a qsf comment was edited mid-build (memory note
`never-edit-qsf-during-build`); `quartus_sta` + `quartus_asm` on the finished db produced the report and rbf above.

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

The gate for this branch, once the box is free: load
`_Unstable/MacQuadra800_store_ba54b0ee.rbf` (the `.s0` already points at
`QuadSquad8.hda`), Mac OS 8.1 boot + Speedometer 4.02 Benchmark Mix
(compare with 0.395 for 299cb36 and Alan's 0.405 for 164a376; the
simulation says the boot's ROM phase is 13 % shorter than 164a376), then
A/UX boot + `shutdown -h now` (the 299cb36 gate wedged there; still
unexplained — see "Older notes"). If the store head misbehaves, fall back
to `_Unstable/MacQuadra800_readahead_0018d4a9.rbf`, then to the shipped
20260908_3. Hand the driving to an Opus operator per the memory note.

Boot-time lead from the sim: the ROM spends the whole "black" phase in a
VRAM byte-lane probe (`$408046B6..D4` writing and reading `$F903D028`,
uncached, one byte per iteration); it runs for well over 3G half-cycles in
the sim, the same order as the hardware's 50-second black phase. Making
uncached VRAM byte accesses cheaper (or cacheable for that probe) would cut
boot time far more than any sequencer change; not touched.

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
- **The sim harness stop is fixed (`56a429a`):** every long boot used to
  stall in the ROM SCSI Manager because a block-device *write* completed on
  the ack's first tick with zero bytes moved (the gate results were all
  zeros, the 8.1 boot's first volume write was lost, and `scsi_cache`, left
  mid-transfer, never completed the next read). A write now completes only
  after every word was consumed; the 8.1 boot passes that point (write of
  lba 98, then the read of lba 2282 acknowledged at HB cycle 493M).
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
