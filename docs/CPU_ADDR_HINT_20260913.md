# Core address hints and per-space translation copy (2026-09-13, candidate)

Follows the accepted micro-TLB checkpoint (`CPU_UTLB_20260913.md`).
Candidate only until the hardware section is filled in.

## Why

After the cache-admission and micro-TLB changes a hit still costs 3 clocks
whenever the cache has not seen the index one clock before the request:
non-sequential instruction fetches (short branch targets, line crossings)
and every data read, because the core presents address and request in the
same cycle. The cache keeps only its last idle read, so the address must be
on the pins during exactly the cycle before the request issues.

## What changes

**`ap040_core.v`**: `mem_addr` and `mem_instr` become wires. While
`mem_req` is low they carry a hint; the registered copies
(`mem_addr_q`, `mem_instr_q`) are what every internal consumer reads, and
nothing downstream acts on `c_addr` without `c_req`. Hint priority:

| state | hint | mirrors |
|---|---|---|
| `S_MRD` before issue | `m_addr_r`, data | the non-pipelined `mrd` issue next cycle |
| `S_DECODE` of a short Bcc (not BSR, disp not 00/FF) | `pc + sxb(disp)`, instruction | `finish_bcc` this cycle |
| `S_PIPE_START` with a memory source | port A value, or minus the (An) adjust for -(An), data | the three `mrd` sites there |
| `S_PIPE_SRD`, or `S_PIPE_DEA` with `p_rmw` | `ea_addr`, data | the post-EA source read and the RMW destination read |
| otherwise | `epf_ftail`, instruction | the fill engine's next sequential fetch |

A wrong hint costs nothing: the cache trusts only its index/validity record
and a fresh tag compare. Cost: a 32-bit 5:1 mux, one 32-bit add (Bcc
target) and one subtract (-(An)) on the pins, no new state.

**`ap040_mmu.v`**: the ATC hit copy becomes two entries indexed by
`c_instr`, because a single entry thrashes between the code page and the
data page on every instruction that touches memory.

Candidate tree `/tmp/hint-cand.fRqM8B`: core SHA256 `3a8a60537e2a3856...`,
mmu `a132b7e34e02b34c...`, cache `77882b83...` (unchanged).

## Fixture results

Handoff latency fixture (`/tmp/hint-lat.k4Cere`, program unchanged):

| step | clocks | note |
|---|---:|---|
| accepted cache-early | 2,127 | |
| + micro-TLB (accepted) | 1,992 | fetches 3 -> 2 |
| + hints (fill/Bcc/S_MRD) | 1,950 | line-crossing fetches 2, non-pipelined data 2 |
| + per-space copy | 1,939 | translated data hits stop thrashing |
| + pipe-state hints, space bit fixed | **1,905** | every warm data hit 2 clocks |

Total -13 % against the pre-cache 2,188. The first pipe-state version drove
the space bit as "instruction" during data hints (found by tracing edges
778 to 800); the fix is one line. The fixture's snoop injection used to
trigger on the cache entering `C_LOOK` for a data read, which no longer
happens; the local copy now injects at the admission edge (the collision
that matters for this design), passes, and reports 1,924 clocks with the
forced-miss refill included. AP suite: 11 of 11 on the corrected core.

Pending: full-machine boot A/B, corpus gate, Sieve sweep (TC off, gains
expected this time), matched fit, hardware.

### Simulation gates (done, all hold; corrected core `3a8a6053...`)

- **Sieve integration sweep** (`/tmp/sieve-hint2.X8SAY0/sieve-out`, TC off):
  every offset faster, none slower; total 13,596,008 -> 12,394,101 cycles,
  **-8.84 %** (per offset -6.2 % to -12.3 %). `imiss` 5, `dmiss` 512,
  `mem_reads` 517, `mem_writes` 23,190 and every oracle marker unchanged at
  all 16 offsets. The fixture's `dhit`/`ihit` counters fall to about zero
  because they count `C_LOOK` hits and the hits now complete at admission;
  the unchanged miss and memory-read counts show the accesses are still
  cache-served.
- **Boot A/B** (`/tmp/simboot-run-hint.U9spRn`): 57,306,687 dispatches,
  7.329 clocks/dispatch, +7.49 % over the adopted baseline but only +0.06 %
  over the micro-TLB-only run. The boot bracket is dominated by uncached
  I/O polling (`C_PASS` 17 % of cycles) which no hint can shorten, so it is
  insensitive to this change; the Sieve kernel is the relevant predictor.
  Same frame, byte-identical screenshot, same highest LBA, no faults.
- **Corpus gate**: 34,740,491 cycles, identical to baseline, 0 REAL diffs.
- **AP suite**: 11 of 11.

### Matched trimmed seed-24 fit (done, fits, timing met)

Tree `/tmp/MacQuadra800_hint_seed24.v7IVAv`, only `ap040_core.v` and
`ap040_mmu.v` differ from the micro-TLB build; QSF byte-identical. Quartus
exit 0, log `output_files/build_20260913_230917.log`.

| metric | micro-TLB (accepted) | + hints, per-space copy | delta |
|---|---:|---:|---:|
| ALMs needed | 36,698 | 36,826 | +128 |
| LABs occupied / free | 4,069 / 122 | 4,073 / 118 | +4 / -4 |
| registers | 23,071 | 23,164 | +93 |
| M10K / memory bits / DSP | 459 / 3,435,654 / 31 | same | 0 |
| `ap040_core` / `ap040_mmu` / cache ALMs | 23,686 / 771 / 516 | 23,779 / 815 / 535 | +93 / +45 / +19 |
| setup slack, clk_sys 33 MHz (CPU) | +0.885 ns | +1.165 ns | +0.280 |
| setup slack, clk_ram 99 MHz | +0.380 ns | +0.295 ns | -0.085 |
| setup slack, HDMI | +0.346 ns | +0.347 ns | |
| worst hold anywhere | +0.217 ns | +0.209 ns (HDMI) | |

All TNS zero, no Critical Warnings, RAM inference unchanged. RBF SHA256
`9c9b1e976ab3f8e95809d64e78d1ef391c086654d4369c29b12d3fb087870fc1`,
4,388,592 bytes.

### Hardware (three valid runs) and decision

Deployed through the guard (dry-run, deploy, restore all exit 0) as
`/media/fat/_Unstable/MacQuadra800_hint_trim_seed24_20260913.rbf`.
Runs **0.543 / 0.544 / 0.543**, fresh alert each, guest clock 3:39 / 3:43 /
3:46 AM, no invalid time. Parent viewed all three screenshots.

| Test | Run 1 | Run 2 | Run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 399.157 | 400.524 | 400.504 |
| Dhrystones/sec | 6453.483 | 6454.697 | 6454.914 |
| Towers (sec) | 1.695 | 1.695 | 1.696 |
| Quick Sort (sec) | 1.143 | 1.141 | 1.143 |
| Bubble Sort (sec) | 1.306 | 1.306 | 1.306 |
| Queens (sec) | 0.931 | 0.930 | 0.930 |
| Puzzle (sec) | 2.696 | 2.696 | 2.697 |
| Permutations (sec) | 2.594 | 2.593 | 2.594 |
| Integer Matrix (sec) | 1.978 | 1.966 | 1.976 |
| Sieve (sec) | 2.458 | 2.456 | 2.456 |
| CPU Mix | 0.543 | 0.544 | 0.543 |

Mean **0.543333**, **+7.95 %** over the micro-TLB checkpoint 0.503333;
every test faster; Sieve 2.773 -> 2.457 s (-11.4 %), matching the fixture's
-8.8 % cycles plus the translated-hit savings the fixture cannot show.
Evidence `scratch/perf_hint_seed24_20260913/RESULTS.txt` (timestamps: core
load 23:33:16, run starts 23:37:27 / 23:40:51 / 23:44:07).

**Accepted 2026-09-13** (AP68040 `bd55a40`). Cumulative on the trimmed
seed-24 profile today: 0.4635 (source-only) -> 0.485 (cache admission) ->
0.503 (ATC copy) -> 0.543 (hints, per-space copy), +17.2 %.
