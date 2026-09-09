# MacQuadra800 upstream integration — 2026-09-09

Dani's active repository is now
`https://github.com/danifunker/MacQuadra800_MiSTer.git`. The old
`danifunker/wombat33_MiSTer` repository remains online but stopped at
`f9767d8`; the renamed repository continues from that commit and was 154
commits ahead at `cba1490` when this integration was made.

The local repository now has an `upstream` remote for the renamed URL. The
merge is isolated on branch `integrate-macquadra800-upstream-20260909`, based
on local committed checkpoint `4ef74b0`; the user's dirty CPU/profiler work in
the original worktree was not touched.

Conflict policy:

- take upstream's renamed `MacQuadra800` project/top level, three-target NCR,
  SCSI block cache, CD audio, DAFB CLUT, build recipe, and expanded NCR tests;
- retain local AP68040 `299cb36`, which contains the accepted CPU work and the
  later upstream cache-race/FPU-frame corrections;
- retain the local simulator's multi-block transfer count and 13-bit buffer
  address while using upstream's three-target request/acknowledgement vectors;
- drop the direct NCR batching implementation from `4ef74b0`, because the
  upstream `scsi_cache` now owns batching and issues aligned eight-sector HPS
  transactions. Keeping both would duplicate incompatible batching layers.

Validation completed before the merge commit:

- AP68040 complete suite: pass;
- `tb_scsi_cache` and `tb_scsi_cache_mbcd`: 279,315 checks each, zero failures;
- `tb_ncr53c96`: 476,837 checks, zero failures;
- SDRAM: 45 checks and zero chip-protocol errors;
- bus32, store buffer, and registered-first-miss memory path: pass;
- full-machine Verilator compile/link: pass;
- Quartus Analysis & Synthesis: pass;
- full Quartus seed-21 fit and TimeQuest: pass, zero setup/hold TNS.

Final seed-21 fit:

- 41,057/41,910 ALMs (98%);
- 4,190/4,191 LABs, only one free;
- 25,316 registers;
- 3,532,636 block-memory bits and 477/553 RAM blocks;
- worst setup +0.156 ns, CPU setup +0.325 ns, SDRAM setup +0.771 ns;
- worst hold +0.205 ns, CPU hold +0.448 ns, SDRAM hold +0.265 ns;
- RBF MD5 `dda381e65b508bf010800a5e45d71030`.

The fit is valid but has no practical LAB headroom. Do not layer the current
uncommitted D-cache repeat/sequential prototype on top: that candidate cost
seven LABs in the smaller pre-integration design. Reclaim area or re-evaluate
the release feature switches before resuming CPU expansion.

Hardware validation on the exact merge RBF:

- deployed as
  `/media/fat/_Unstable/MacQuadra800_upstream_cba1490_ap299cb36_seed21_20260909.rbf`;
- the renamed core needs the Quadra ROM at
  `/media/fat/games/MacQuadra800/boot.rom`; after seeding that path, Mac OS
  7.5.5 booted normally from an independent restore of the Speedometer 4.02
  golden disk;
- Speedometer 4.02 CPU Benchmark Mix completed with no capture or input during
  the timed interval;
- the result frame is
  `scratch/integration/upstream_speedo402_results.png` in the original
  worktree, SHA-256
  `f760517837d39cd21047c4dee045e5c07fb2c0e78474c28301674f52346821f9`;
- MiSTer was returned to Menu and the disposable disk was restored to golden
  MD5 `16790b0577e13b45782214433d34954b` after the run.

| CPU Benchmark Mix test | seed-40 control | merged upstream seed-21 | change |
|---|---:|---:|---:|
| KWhetstones/sec | 341.397 | 342.993 | +0.47% |
| Dhrystones/sec | 4584.745 | 4432.219 | -3.33% |
| Towers (s) | 2.189 | 2.176 | +0.60% |
| Quick Sort (s) | 1.703 | 1.751 | -2.74% |
| Bubble Sort (s) | 2.321 | 2.326 | -0.21% |
| Queens (s) | 1.364 | 1.364 | 0.00% |
| Puzzle (s) | 3.776 | 3.781 | -0.13% |
| Permutations (s) | 3.308 | 3.309 | -0.03% |
| Integer Matrix (s) | 2.561 | 2.562 | -0.04% |
| Sieve (s) | 4.176 | 3.978 | +4.98% |
| **average ratio** | **0.393** | **0.394** | **+0.25%** |

The aggregate result is effectively flat. The opposing Dhrystone, Quick Sort,
and Sieve movements should be treated as run variation unless a second cold
run reproduces them. Mac OS hardware boot and the CPU benchmark gate pass;
A/UX and clean guest shutdown remain untested on this exact RBF.


## CPU continuation

Work now continues from the clean fork checkout
`/home/alans/mister/MacQuadra800_MiSTer` on branch
`cpu-early-data-read-20260909`. `origin` is
`alanswx/MacQuadra800_MiSTer`; `upstream` is the renamed Dani repository above.

AP68040 `cbac732` issues aligned normal operand-pipeline reads in the 32 MB RAM
window while entering `S_MRD`. The deliberately broader first prototype is
hardware-rejected because it broke Speedometer elapsed-time results. The
narrowed seed-21 build is timing-clean, fits at 40,873 ALMs and 4,181 LABs, and
reproduces a 0.399 Speedometer 4.02 CPU average twice versus 0.394 for this
integration. Exact results, validation, hashes, and the original 68040 paper
EAF motivation are in `docs/PERFORMANCE_MEASUREMENTS.md` section 34.

### 2026-09-09 next CPU experiment

AP68040 `d777c5d` issued simple `(An)`, `(An)+`, and `-(An)` operands directly
from `S_PIPE_START`. It passed the complete regression set and reduced the
focused cached phase by 8.52%, but its timing-clean seed-30 fit cost 264 ALMs
and 8 LABs over the accepted checkpoint, leaving only two LABs free. On the
exact hardware RBF, Mac OS 7.5.5 booted normally and Speedometer 4.02 still
reported a 0.399 CPU Benchmark Mix average. The candidate is rejected and the
parent remains on AP68040 `cbac732`, seed 21. Section 35 of
`docs/PERFORMANCE_MEASUREMENTS.md` has the full measurements and artifact
hashes. MiSTer is at Menu and the disposable disk is restored to golden MD5
`16790b0577e13b45782214433d34954b`.

### 2026-09-09 early-write follow-up

The paper-motivated write path was tested at AP68040 `164a376`. Issuing aligned
normal-RAM `S_EXEC` stores while entering `S_MWR` preserves precise completion,
passes all simulation gates, and cuts the first-100 corpus 2.85%. The exact
seed-21 fit is timing-clean at 41,044 ALMs and 4,188 LABs, but two Speedometer
4.02 runs score only 0.405 and 0.406 versus 0.399 accepted. The stable +1.63%
two-run gain is below the 2% area-consuming gate and costs seven LABs, so the
candidate is rejected and preserved only on `cpu-early-store-20260909`. The
parent remains on AP68040 `cbac732`, seed 21. Full details are in measurement
section 36. MiSTer is at Menu and the disk is restored to golden MD5
`16790b0577e13b45782214433d34954b`.

### 2026-09-09 accepted early-write + NCR area reclaim

The exact 8-bit `bin2bcd8` conversions in `rtl/ncr53c96.sv` now use the same
multiply-by-205 reciprocal method as `cd_audio.sv`, eliminating seven `/10`
and seven `%10` divider networks. Combined with AP68040 early-write commit
`164a376`, seed 21 fits timing-clean at 40,523 ALMs, 4,187 LABs, 25,352
registers, 477 RAM blocks, and 64 DSP blocks. Worst setup/hold are +0.398 and
+0.202 ns; CPU and SDRAM setup are +0.739 and +0.904 ns. Compared with the
accepted early-read checkpoint this saves 350 ALMs but uses six more LABs,
leaving four free.

The NCR regression passes 476,837 checks and the complete machine model
compiles and links. Two valid unperturbed Speedometer 4.02 runs both score
0.405 versus 0.399 (+1.50%), reproducing the earlier write-path gain. One first
invocation produced impossible negative late-test values and is explicitly
discarded as an invalid Speedometer run; a cold restored run and its immediate
repeat were stable and identical at 0.405. Full details are in measurement
section 37. MiSTer is at Menu, the disk is restored to golden MD5
`16790b0577e13b45782214433d34954b`, and Main plus its preserved copy both match
MD5 `dfb5937ba47720c3ae20abc8f381c462`.
