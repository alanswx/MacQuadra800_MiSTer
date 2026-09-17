# RESUME — CPU vendored + Adam Polkosnik's fixes ported (2026-09-17)

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

## In flight when this note was written

- **Full Quartus build** of the final tree launched 13:21, detached, log
  `scratch/build_cpufixes.log` (release recipe, unchanged `.qsf`). Read
  `output_files/MacQuadra800.fit.summary` / `.sta.summary` when it ends;
  record the seed result in the `.qsf` comment block as usual. Expect the
  MLAB register file and the adder sharing to take area OUT; note whether
  the 33 MHz CPU clock still meets.
- `~/gates_final.log` in WSL: the same three gates on the final tree.

## Next

1. Build result -> if it fits, **hardware gate on the .143 box** (look
   before you deploy; both guests; A/UX at 32 MB; CD audio by the user's
   ear). The register file has a hardware-only failure mode (MLAB
   read-during-write); if 8.1 does not boot, revert `6de9473` first and
   rebuild.
2. Release per `CLAUDE.md` if the gate passes (rbf + `releases/README.md`
   row + section).
3. Later: re-engineer R5/R6 (`git --git-dir=.git/modules/rtl/ap68040 show
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
