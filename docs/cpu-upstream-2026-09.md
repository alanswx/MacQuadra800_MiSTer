# AP68040 upstream review, 2026-09-17: Adam Polkosnik's September commits

Branch `add-CPU-fixes` (cut from `optimize-SCSI`). This note records what
was in `../AP68040` (apolkosnik/AP68040) that our vendored core did not
have, what was taken, what was not, and why. The per-commit history is in
git; this is the map.

## The lie of the land

Adam's `main` and Alan Steremberg's performance stack both fork from
`0e76761` (2026-08-28). Our core was Alan's checkpoint 15 (`167c5e8`) plus
our carrier hoisting R1..R4 (`8778213`, shipped in
`MacQuadra800_20260915.rbf`). Two of Adam's commits since the fork
(`16b674a` t_mmu NeXT fault shape, `a8a50ce` cache-invalidation race + FPU
frame) were already ours as Alan's cherry-picks `9996357`/`299cb36`
(patch-identical bar two testbench lines).

Adam tried the merge himself on his `40_w_Alans_patches` branch
(`b117757`): 43 semantic conflict hunks, 30 of them in `ap040_core.v`,
because both sides independently rebuilt early data issue, whole-line
return to the prefetch queue and cache store handling. He rebased onto
Alan's `de5a202` instead. We did the same in the other direction: his
fixes ported onto our tree, one commit each, the rest left.

The CPU was a git submodule until this work; it is now vendored at
`rtl/ap68040/` (`rtl/ap68040/UPSTREAM.md`). Alan's two further hoists on
the old `wombat-area-diet` branch (R5/R6 `c789ffe`/`923c544`, 1,300 ALMs
smaller but missing the CPU clock) were deliberately not imported and are
to be re-engineered later.

## The evidence: Adam's directed programs against our core

His seven new self-checking programs run unchanged through our
`tb_ap040_program`. Before any fix:

| program | result on `8778213` | what it means |
|---|---|---|
| t_bitfield_mmu | FAIL test 2 | a short memory bitfield at a page end reads a longword and faults on the unmapped next page |
| t_movem_restart | FAIL test 5 | a MOVEM that faults after overwriting its own pointer or index restarts from the wrong address |
| t_atcprobe | FAIL test 2 | failed table searches do not install nonresident ATC entries |
| t_fpu_resume | FAIL test 1 | BUSY-frame FRESTORE with CU_SAVEPC=$fe does not execute the prepared command |
| t_moves_fc | pass | our memory-issue arm never early-issues from S_MOVES_*, so the SFC/DFC race is structurally excluded |
| t_bitfield_cache | pass | |
| t_fpu_frames | pass | revision-$41 frame layouts are right |

The FPU resume matters for a Macintosh, not only NeXT: the Quadra 800
ROM's FPSP builds a $60 BUSY frame, writes `$fe` to CU_SAVEPC at offset 8
and executes `frestore (a7)+` at ROM address `40890100`
(`docs/quadra800-rom-disassembly.asm`). That is the path denormal and
unnormalized operands take under Mac OS, and it silently produced wrong
results.

## Verdict per upstream commit

| Adam's commit | verdict | our commit |
|---|---|---|
| `3458e64` size memory bitfield reads by span | **taken** as is (cherry-picks clean) | `86c9edc` |
| `745be02` narrow only at a page end | RTL **skipped** (Adam reverted it himself in `95e29fb`); its `t_bitfield_cache` test taken | `a72a48d` |
| `95e29fb` MOVES carries SFC/DFC on the issue carriers | RTL **skipped**: our early-issue whitelist excludes the MOVES states and `t_moves_fc` passes; the test is taken and the invariant is written into `mem_issue` | `a72a48d` |
| `880b81c` part 1: FPSP BUSY-frame resume, `AP040_FPU_REVISION` | **ported** (three-way merge on `ap040_fpu.v`, the FPU-related core hunks by patch); Alan's MLAB FP bank is what Adam's diff assumes, so the FPU delta is the resume path alone | `92245f7` |
| `880b81c` part 2: MOVEM saved-EA / SSW.CM continuation | **ported**; new states renumbered 197..199 (Adam's 191..193 are our `S_EXC0_F2/F3/F4`); `mm_resume` is cleared at our four opcode-load sites through `movem_mem_op()` because this core has no single dispatch task; Adam's `t_mmu.s` update (handler CM check, cases 151-154) taken | `2928823` |
| `880b81c` part 3: nonresident ATC entries | **ported** (three-way merge on `ap040_mmu.v`; Alan's per-space hit copies keep working because they copy the whole entry and `fill_we` invalidates them) | `64d2606` |
| `880b81c` part 4: revision-$40 NeXT ABI, `AP040_DEBUG_EXCEPTIONS` taps | parameter comes along at its `$41` default; the debug taps **skipped** (Improv/NeXT-specific, add ports) | |
| `7431dcb` ADD/ADDX + SUB/SUBX/CMP adder sharing, FPU normalizer sharing | **taken** (ALU hunk by hand: Alan's fast-flag block reads the same adders and stays exact since the extend is gated on the ADDX/SUBX opcode); both unit benches taken | `5e63cd8` |
| `7431dcb` integer registers in mirrored MLABs with a pending-write bypass | **taken as its own commit**; Adam's first MLAB version did not boot on hardware, so this one is the first to revert if the fitted build misbehaves | `6de9473` |
| `7431dcb` exception-entry hoist (`e_go`) | **skipped**: duplicates our `xgo` hoist (`docs/cpu-area-consolidation.md`) | |
| `284be28` flatten exceptions (`exc_fmt` predicates) | **skipped**: our `exc_now` carries the format in the entry state, one write site, no 130-site enable tree | |
| `1c3a9e9` Minimig sequencer, update-on-hit cache, MMU sweep pipelining, `tick` | **skipped**: Adam's own version of the early-issue / direct-dispatch / update-on-hit work, mutually exclusive with Alan's (which we ship); `tick` and the sweep fix are for a divided clock enable, ours is tied to 1 |
| `9be2325` snoop-bench don't-care rows, dpram rdw model | **skipped**: bench targets Adam's cache; our Quartus flow substitutes `rtl/dpram.v` anyway |
| our own `docs/ap68040-memind-reserved.patch` | **applied** at last (verified 2026-08-30 against Quadra 800 captures, never committed into the submodule) | `64d493e` |

## Gates

`scripts/cpu_gates_wsl.sh` after the behaviour fixes (through `64d2606`)
and again on the final tree:

| gate | result |
|---|---|
| AP suite | all legs pass (18 after the fixes, 23 with the unit benches and the must-fail bypass control) |
| `bench_loop` | 94368 / 95166 / 95166 cycles, identical to checkpoint 15 |
| corpus-100 (silicon captures) | 33,335,739 cycles, 0 REAL diffs, identical to checkpoint 15 |

The bitfield sizing changes memory traffic only for bitfields at odd
addresses, which neither `bench_loop` nor the first 100 corpus rows
contain; the corpus rows run with TC=0 and cannot see the MMU changes.

The hardware gate (Mac OS 8.1, A/UX 3.1 at 32 MB, CD audio) is owed on
the first fitted build of this branch, with the MLAB register file the
first suspect if anything regresses that the gates above did not see.

## Still open upstream

- Adam's `t_fpu_frames`/`t_fpu_resume` revision-$40 legs and
  `run_fpu_frames.sh` need a `FPU_REVISION` parameter on
  `tb_ap040_program`; not carried, we are a Quadra.
- His `tb_ap040_cache_snoop` don't-care coverage has no counterpart for
  Alan's cache.
- Whether his `40_w_Alans_patches` branch moves again is worth a look each
  time he pushes: it is the branch he keeps Alan-compatible.
