# RESUME — CPU vendored + Adam Polkosnik's fixes ported (2026-09-17)

**RELEASED 2026-09-17 15:xx as `releases/MacQuadra800_20260916_2.rbf`**
(md5 `8552a409`, replacing the 00:42 file `ab1da889` of the same name at
the user's request): Speedometer 4.02 by the user on the .143 box -- Mix
**0.855** (0.858 on 20260915), CQD 0.641 over four depths (8-bit 0.629 vs
0.605), PR 0.810; Mac OS 8.1 booted with a second disk and a CD mounted,
the MLAB register file's first hardware run passed. A/UX and CD audio NOT
re-run on this file (unchanged RTL outside the CPU). Row + section in
`releases/README.md`, numbers in `docs/PERFORMANCE_MEASUREMENTS.md` s.15.
All the CPU tweaks that were going to be taken are in; nothing of Adam's
remains queued (the skips are deliberate, `docs/cpu-upstream-2026-09.md`).
The user put Speedometer 4.02 into `Quad Squad:Utilities:` on the box.

Read this first, then `CLAUDE.md`. Branch **`add-CPU-fixes`** (cut from
`optimize-SCSI` at 68c4068). Commit as work lands, **the user pushes**.

## What happened today

1. **The AP68040 is no longer a submodule.** `rtl/ap68040/` holds the tree
   at the shipped commit `8778213` as plain files (`2c14d90`); origin and
   how to port upstream patches are in `rtl/ap68040/UPSTREAM.md`. The old
   submodule repo is still at `.git/modules/rtl/ap68040` with all of
   Alan's branches (R5/R6 on `wombat-area-diet` are NOT imported: they
   miss the CPU clock, to be re-engineered). `../AP68040` is Adam's repo;
   it is fetched into that old repo as remote `adam` (+ `adam-origin/*`).
2. **Adam's seven directed programs are in `run_tests.sh`** (`a72a48d`).
   Four of them failed on the shipped core; each fix below makes one pass.
3. **Fixes landed**, one commit each, in this order:
   `64d493e` memind reserved encodings (our own 2026-08-30 patch, finally
   in), `86c9edc` bitfield read sizing, `92245f7` FPSP BUSY-frame resume
   (the Quadra ROM uses it: `move.b #$fe,8(a7); frestore (a7)+` at
   `40890100`), `2928823` MOVEM CM/saved-EA continuation, `64d2606`
   nonresident ATC entries, `5e63cd8` ALU adder + FPU normalizer sharing,
   `6de9473` integer registers in MLABs (**the first thing to revert if
   hardware misbehaves**; Adam's first MLAB version did not boot).
   The map of every upstream commit and its verdict:
   `docs/cpu-upstream-2026-09.md`.
4. **Gates:** AP suite 23/23 legs; `bench_loop` 94368/95166/95166 and
   corpus-100 33,335,739 cycles / 0 REAL diffs, both identical to
   checkpoint 15 (`scripts/cpu_gates_wsl.sh`, WSL logs
   `~/gates_fixesC.log` after `64d2606`, `~/gates_final.log` on the final
   tree).

## The build (done 13:52)

- **Seed 21 fits and MEETS TIMING first try**: 37,144 ALMs (89 %), worst
  slack +0.244 ns (HDMI +0.255, clk_sys +0.442, clk_ram +0.851), 31 min.
  rbf md5 `8552a409`, kept as `scratch/MacQuadra800_cpufixes_6de9473.rbf`
  (also `output_files/MacQuadra800.rbf` until the next build). Ledger line
  in the `.qsf` (`45cd875`). The last release (20260916_2) shipped with
  clk_sys -0.231 at the same seed; this one is clean.
- The integer register banks were inferred as MLAB `altdpram`s (map.rpt
  `ap040_regfile:regfile|altdpram:bank_a/b`), not flops; no `open_row`
  altsyncram in the map report (the `docs/sdram-open-row-crossing.md`
  check).
- `~/gates_final.log`: 23/23, bench_loop and corpus identical (see above).
- Box state at 13:54: the MacQuadra800 core loaded with QuadSquad8 in
  slot 0, screen a noise pattern (not a Finder, not the halt screen), zero
  disk I/O over 12 s. Unknown state -> NOT deployed; ask the user.

## Next

1. The A/UX 3.1 (32 MB) and CD-audio halves of the gate on this file, when
   convenient -- the SCSI/CD RTL is `ab1da889`'s, which passed them. The register file has a hardware-only failure mode (MLAB
   read-during-write); if 8.1 does not boot, revert `6de9473` first and
   rebuild.
2. Push (the user).
3. Boot chime: the ROM plays the Mac II sound, not the Quadra's (user,
   2026-09-17) -- see `RESUME-open-items.md`, Correctness items owed.
4. Later: re-engineer R5/R6 (`git --git-dir=.git/modules/rtl/ap68040 show
   c789ffe 923c544`) against the CPU-clock miss; watch Adam's
   `40_w_Alans_patches` branch for new Alan-compatible work.

## Gotchas met today

- Python on Windows: `open(p,'w')` writes CRLF; use `newline=''` and match
  `\r\n` explicitly when editing these CRLF working files. `git ls-files
  --eol` is the truth about what is stored (index blobs are LF).
- The Bash tool's heredoc eats backslashes: a `\` line continuation
  written from heredoc Python came out as a literal `\n` in
  `run_tests.sh`. Keep shell commands on one line.
- Adam's benches instantiate the ALU with `.*`: this tree's ALU has
  `fast_flags`/`fast_ok`, declared in the bench for the binding.
- Adam's new state numbers collide with ours (191..193 are
  `S_EXC0_F2/F3/F4`); the free block starts at 197.
