# RESUME — CPU area/perf work (updated 2026-09-15 ~20:15)

Read this first, then `CLAUDE.md`. Model note: this session ran as Fable 5.1,
then the harness switched it to **Opus 4.8** at the seed-22 fit notification
(~19:30). Commit attribution from that point is `Claude Opus 4.8`.

## One-paragraph state

Alan's AP68040 **checkpoint 15** is integrated on branch `alan-perf-20260908`
and made ~5,500 ALUTs smaller by hoisting six multi-site sequencer tasks into
single post-`case` carrier arms (R1..R6), **cycle-identical** on the CPU corpus
(AP suite 11/11, bench_loop 94368/95166, corpus-100 0 REAL diffs). **BUT the
candidate does not boot Mac OS 8.1 on hardware** — see the blocking bug below.
Nothing is pushed; `main` is untouched.

## BLOCKING BUG (2026-09-15, unresolved)

The R1..R4 candidate (`8c6d48b5`) **hangs the Mac OS 8.1 boot** on the .92 box at
~15% extension load: frozen splash (byte-identical md5 `ab692d4e`), zero SCSI
reads, cursor still moves. Reproduced 3/3 loads.

Proven to be the **bitstream**, not the disk or box:
- On a freshly restored `QuadSquad8.hda` (from `backup/QuadSquad8.hda.gz`,
  decompressed md5 `93738964c24e06e49b0d90d8baefac01`, 2,146,461,696 bytes) the
  **store head** `ba54b0ee` (pre-checkpoint-15) booted to a full Finder
  (T_finder 86-130 s) and shut down clean; the candidate on that same clean disk
  stalled again.
- **The Verilator sim REPRODUCES the hang** (found 2026-09-15 20:20; the earlier
  "sim boots past it" claim was about the 7.6.1 image, not Quad Squad 8.1).
  `~/MacQuadra800/verilator/sim_qs8_r4_hang.log` (WSL): the frame-3000 screenshot
  is the hardware stall frame; the NCR trace shows the CD-ROM driver (code at
  `$00121000-$0012A000`, `a3 = $50F10000` = 53C96 base) doing MODE SENSE page $0E
  to the CD target (ID 3, no disc), then **MODE SELECT(6) PF=1, 28 bytes**
  (`cdb 15 10 00 00 1c`), two PIO transfers (12 + 16 bytes, each answered
  `INT+ ist=10 ph=0`), and then **nothing**: the CPU polls the 53C96 for 15 s
  and falls into an endless `cmd=1A` (Set ATN) loop every 953 cycles (367k of
  them). The 7.6.1 boot never issues that command. Alan never saw it because his
  profile has no CD target (or no Apple CD-ROM extension).
  Model side: after the list is complete the 53C96 model parses it (msel_st
  1..10, ~12 cycles) and raises a second Bus Service with phase STATUS
  (`msel_fin`); no `INT+` prints for it because irq was still high — so the
  driver had not read the ISR in between. The driver never issues ICCS ($11).

### ROOT CAUSE (found 2026-09-15 20:58, tree A register trace)

Not the CPU. A **window in the 53C96 model** (`rtl/ncr53c96.sv`): for a CD
MODE SELECT the PIO data-out drain raised Bus Service the cycle the FIFO
emptied, while the list parse (`msel_st` 1..10) moved the phase to STATUS ~12
cycles later and `msel_fin` raised a second Bus Service that merged into the
first. The Apple CD-ROM extension polls the STATUS register for INT; the
checkpoint-15 CPU's loop read it **9 cycles** after the raise:

```
[NCR 842358526] INT+ ist=10 ph=0          FIFO drained -> BS, phase still DATA OUT
[NCRREG 842358535] rd rs=4 data=90 ph=0   driver: INT set, phase DATA OUT
[NCRREG 842358547] rd rs=7 data=00 ph=3   (phase is STATUS by now)
[NCRREG 842358558] rd rs=5 data=10        ISR read clears BS -- the STATUS one too
[NCRREG 842359563] rd rs=4 data=13 ...    polls for INT forever (phase 3, no INT)
```

The store head's slower loop read the STATUS register after the phase had
moved, so it saw INT + STATUS and issued ICCS. Tree C (posting off) hangs
identically -- posting is irrelevant. A real target changes phase and
interrupts only once it holds the whole list; QEMU's scsi-cd completes the
request before the guest's next instruction. **Fix:** the drain does not raise
Bus Service when the drained byte completes a judged CD MODE SELECT list
(`msel_pend && sbuf_pos >= dout_len`); the verdict's `msel_fin` raises it with
the phase already STATUS (both the PIO and the DMA drain paths).

### In flight (2026-09-15 20:30)
Three traced WSL sims from the pristine image (`~/qs8_pristine.hda`, md5
`93738964…`), each with a 53C96 register trace (`[NCRREG]`, armed by the first
MODE SELECT to the CD) and the CPU instruction trace started by it
(`--trace-on-ncr --trace-max 4000000`, `cpu_trace.log` beside `sim_run.log`):
- `~/MacQuadra800_A` = candidate (HEAD tree + submodule 8778213 = the rbf)
- `~/MacQuadra800_B` = store-head control (74db5cc + submodule 9216f3e)
- `~/MacQuadra800_C` = candidate with `c_post_ok` tied to 0
Expected to arm ~40 min after their 20:28 start. Compare the `[NCRREG]`
sequences A vs B after the MODE SELECT, then read A's `cpu_trace.log`.
The trace patch is `scratch/../patch_trace.py` (scratchpad) and is applied to
the repo tree too (`rtl/ncr53c96.sv`, `verilator/sim_main.cpp`; uncommitted).
Hedge: a **posting-off R1..R4 Quartus build** (befb4fd + 8778213 +
`c_post_ok(1'b0)`, seed 21) runs in `../MacQuadra800_wt2`
(`scratch/build_nopost_r4_s21.log` there; wt2's R1..R6 seed-22 rbf saved as
`scratch/MacQuadra800_diet_r6_s22_2f739338.rbf`).

### Then (state at 21:05)
- Tree A rebuilt with the fix and relaunched from the pristine image (its hang
  evidence kept as `sim_run_hang.log` / `cpu_trace_hang.log`); tree B (store
  head control) still running; tree C killed; the posting-off Quartus hedge
  killed (moot).
- Quartus (fits now take ~25 min): R1..R6 (923c544) + the fix MISSED at
  seed 22 (CPU clock -0.619 ns) and seed 23 (-1.426 ns, TNS -86.6); seed 24
  is fitting in the main tree.  `../MacQuadra800_wt2` builds the more robust
  **R1..R4 (8778213) + fix at seed 21** (its pre-fix fit had +0.361 ns;
  cycle-identical to R1..R6, +1,300 ALMs).  Whichever meets timing is the
  hardware candidate; gate it on the .92 box (Opus operator,
  `scratch/gate_fix/BRIEF.md`, fill in CANDIDATE_RBF and candidate.md5)
  once the sim boot clears the extension load.  Failed rbfs are kept as
  `scratch/MacQuadra800_fix_r6_s22_TIMINGFAIL.rbf` (main) and
  `scratch/MacQuadra800_fix_r6_s23_TIMINGFAIL.rbf` (wt2).
- `tb_ncr53c96` PASSES with the fix (476,837 checks, 0 failures; tree A `tb_ncr.log`).

## Git / artifacts

| thing | value |
|---|---|
| branch | `alan-perf-20260908`, HEAD `2f8872a` (nothing pushed) |
| submodule `rtl/ap68040` at HEAD | `923c544` = R1..R6 early-data (`wombat-area-diet`) |
| R1..R4 rbf (main `output_files/`) | md5 `8c6d48b5`, submodule `8778213`, seed 21, 38,325 ALMs. **HANGS 8.1 boot.** Copy: `scratch/MacQuadra800_diet_r4_s21_8c6d48b5.rbf` |
| R1..R6 seed-22 rbf (`../MacQuadra800_wt2/output_files/`) | md5 `2f739338`, seed 22, timing MET +0.126 ns, 36,982 ALMs. **Shares the suspect wrapper — expected to hang the same way; do not gate until the bug is fixed.** |
| R1..R6 seed-21 | MISSED (-0.269 ns), superseded |
| late-data R5/R6 | submodule branch `wombat-area-diet-late-data`, -4.063 ns, do not use |
| store head (last known-good on hardware) | `ba54b0ee`, submodule `9216f3e`, on the box as `MacQuadra800_store_ba54b0ee.rbf` |

## In flight

- **Opus operator** `a817c151` on the .92 box: doing the extensions-off candidate
  boot + a final store-head control, then reporting. Report:
  `scratch/gate_diet/report.md`. No Speedometer numbers exist (candidate never
  reaches the Finder).
- **Verilator sim** (WSL bg `bzrc1r5px`): booting the candidate RTL on the 2.0 GB
  QuadSquad image; ~34× slower than hardware; screenshots f600/f1800 so far.

## After the bug is fixed
1. Re-gate the fixed candidate: Speedometer 4.02 Mix ×3 + CQD + FPU vs 0.462
   (store head) / 0.360 (release) / 0.855 (Alan). Both OSes boot + clean shutdown.
2. Prefer shipping the **R1..R6 seed-22** core (smaller + faster, timing-met) once
   it carries the fix. Rebuild main at HEAD or adopt the wt2 rbf.
3. Release: `releases/`, `releases/README.md`, commit, update memory
   `next-cpu-arch-fork-merge`.
4. Report to Alan: carrier-hoisting pattern (`docs/cpu-area-consolidation.md`),
   the SBCD/PACK/UNPK reduced-body illegal artefact, the checkpoint-15 hardware
   boot hang, and that his `sys/` switches are unnecessary once the core is small.
5. Separate mission (user's call): move SCSI into `Main_MiSTer`.

## Rules
- Only optimize, remove nothing (CD-ROM stays in). **Never edit `sys/`.** Use the
  **.92 box** (192.168.99.92). Delegate hardware to the Opus operator. Commit as
  work lands. Design mechanism + gates: `docs/cpu-area-consolidation.md`;
  audit `scripts/cpu/audit_task_sites.py`; gates `scripts/cpu_gates_wsl.sh` and
  `scripts/cpu_corpus100_gate.sh`.
