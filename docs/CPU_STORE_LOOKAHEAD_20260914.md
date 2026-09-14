# Lookahead dispatch after a completed store (2026-09-14, candidate)

Builds on checkpoint 8 (`CPU_MEM_DST_20260914.md`). One condition in the
core.

## Why

The core predecodes the next opcode from the fetch queue (`rd_*`, the
register-only descriptor) and dispatches it straight into `S_PIPE_REGS`,
skipping `S_DECODE`, but only when the retiring instruction is an ALU
operation with a register destination (`regs_alu_fire`). A completed
store retires through the same `fetch_next` yet always paid the decode
cycle: 22.1 M `S_MWR -> S_DECODE` transitions per Speedometer run, and in
the Sieve inner loop the `addq` after every store.

## What

The lookahead apply condition also accepts `S_MWR` with `d_ack` and
`r_m_ret == S_NEXT`. At that point the store writes no register (its
address-register update happened in the EA states), it cannot change the
A7 bank or emit an aux write, and a store into the fetch window has
already flushed the queue, which blocks the pop that gates the lookahead.

## Results so far

- AP suite 11/11; corpus 33,558,325 cycles (-0.45 %), 0 REAL diffs;
  latency fixture 1,916 (unchanged).
- Sieve (checkpoint 8 in parentheses): offset 0 **483,999** (523,834,
  -7.6 %), 6 481,207 (504,402, -4.6 %), 16 554,740 (577,938, -4.0 %), 30
  511,319 (564,506, -9.4 %); arrays and guards PASS.

Pending: boot A/B, simulated Speedometer, fits (seeds 22 and 21),
hardware. Tree `/tmp/pd-cand.*`. Jobs now run as systemd user units
(`systemctl --user list-units | grep -e sim- -e fit-`) after three
episodes of every background simulation being killed at once.

**Boot A/B:** 80,441,522 dispatches (+0.01 % over checkpoint 8): the boot
workload rarely follows a store with a descriptor-class opcode. **Fit:**
seed 21 failed in routing at 38,517 ALMs; seed 22 running.

### Descriptor extension on top (`/tmp/rd2-cand.*`)

MOVEQ and `ORI/ANDI/SUBI/ADDI/EORI/CMPI #imm,Dn` join the register-only
descriptor for lookahead dispatch; the immediate word(s) are read from the
queue behind the opcode and popped with it (the descriptor requires them
resident). In `S_DECODE` these opcodes keep their own bodies (`immf_reg`
covers the immediates there). AP suite 11/11, corpus 33,534,567 cycles,
0 REAL diffs, latency fixture 1,916. Sieve (store-lookahead candidate in
parentheses): offset 0 452,615 (483,999, -6.5 %), 6 437,148 (481,207,
-9.2 %), 16 523,362 (554,740, -5.7 %), 30 469,842 (511,319, -8.1 %).

Fixture contract change: `tb_wombat_sieve.sv` detected the end of the
first outer pass by the outer-loop compare entering `S_DECODE`; under
lookahead it enters `S_PIPE_REGS` directly, so the detector now accepts
either state (a run without it timed out after nine passes with correct
results).

**Fits of the store producer:** seed 22 also failed in routing (38,466
ALMs; checkpoint 8 routed at 38,094 at that seed). The added term puts the
memory acknowledge into the dispatch enable cone of every pipeline
register, and the fitter duplicates it. Parked; the descriptor extension
is carried on without it.

### Descriptor extension alone (`/tmp/rc-cand.*`)

Checkpoint 8 plus MOVEQ and the `#imm,Dn` family in the lookahead
descriptor. AP suite 11/11, corpus 33,687,092 cycles, 0 REAL diffs.
Sieve (checkpoint 8 in parentheses): offset 0 475,891 (523,834, -9.2 %),
6 460,345 (504,402, -8.7 %), 16 546,560 (577,938, -5.4 %), 30 503,213
(564,506, -10.9 %): the common `addq / cmpi / bcc` shape follows a
register operation and needs no store producer. Synthesis of the stacked
tree put the extension at about +255 LUT-equivalents. Fit (seed 22), boot
A/B and simulated Speedometer running.

### Fit of the full stack (store producer + descriptor extension)

Seed 21 closes: tree `/tmp/MacQuadra800_rd2_v512s21.*`, 38,320 ALMs
(91 %), all 39 TNS zero, worst setup +0.383 ns (HDMI), clk_sys
+0.570 ns, clk_ram +0.905 ns, worst hold +0.258 ns, no Critical Warnings.
RBF SHA256 `04eacaab04c21e8e75183cb3820f177752f76cad6283b589753603eaa138eeb9`
(4,437,228 bytes); core `ded89c2f...`, cache, MMU and `wombat_cpu.sv`
unchanged from checkpoint 8. Boot A/B of this tree: 80,511,177
dispatches, same frame. RTL identical to the boot-simulated tree.
Hardware run in progress (seed 22 still fitting as a spare).

### Hardware (done, three valid runs) — accepted 2026-09-14

`/media/fat/_Unstable/MacQuadra800_rd2_v512_seed21_20260914.rbf` through
the lifecycle guard (dry-run, deploy, restore all exit 0), fresh alert
each run, no anomaly:

| Test | run 1 | run 2 | run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 493.062 | 494.866 | 494.660 |
| Dhrystones/sec | 8981.672 | 8983.934 | 8985.040 |
| Towers (s) | 1.373 | 1.373 | 1.373 |
| Quick Sort (s) | 0.900 | 0.898 | 0.899 |
| Bubble Sort (s) | 0.996 | 0.996 | 0.996 |
| Queens (s) | 0.717 | 0.717 | 0.717 |
| Puzzle (s) | 2.060 | 2.060 | 2.079 |
| Permutations (s) | 2.038 | 2.039 | 2.038 |
| Integer Matrix (s) | 1.429 | 1.420 | 1.421 |
| Sieve (s) | 1.407 | 1.405 | 1.404 |
| **CPU Mix** | **0.724** | **0.726** | **0.725** |

Mean **0.725000**, **+2.55 %** over checkpoint 8 (0.7070) and +56.4 % over
the source-only 0.4635. Sieve -13 % (1.620 -> 1.405 s), Quick Sort
-1.5 %, Bubble Sort -1.1 %, Queens -1.8 %. Evidence
`scratch/perf_rd2_seed21_20260914/`. Board restored to MENU, Main and
disposable disk verified.
