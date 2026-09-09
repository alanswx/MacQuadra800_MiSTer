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

Hardware boot and guest regression have not yet been run for this exact merge
RBF. Do not call it a release until Mac OS and A/UX boot/shutdown gates pass.
