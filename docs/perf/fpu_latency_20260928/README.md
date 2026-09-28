# FPU latency and issue interval, 2026-09-28

Measured in simulation on the vendored AP68040 (`rtl/ap68040/rtl`) at
commit `0b2d265`, exported with `git show` so working-tree edits cannot leak
in, through `rtl/wombat_cpu.sv`: real core, FPU, MMU (off), 8+8 KB
caches (`SETW = 7`) and the two-entry store buffer, built with the release
`AP040_*` macros from `MacQuadra800.qsf` (XSTORE, LEA, PIPELINE,
PIPELINE_LOADS/STORES/PEA/P6, PIPELINE_MEMORY_ENTRY, PIPELINE_COMPARE,
PIPELINE_EARLY_DRAIN). `ce` is tied high, so one clock here is one 33 MHz CPU
clock. No RTL was changed.

## Table

Clocks per instruction, steady state, caches warm. **Issue** = 16/32/64
independent copies (different destination registers); **latency** = the same
number of dependent copies (each uses the previous result). Memory rows use a
bus model with 3 wait clocks per transaction (`+latency=3`); rows that change
at `+latency=1` show both as `lat3 / lat1`. Everything else is identical at
both latencies.

| Instruction | Issue | Latency (dep) | 68040 UM ref | Notes |
|---|---:|---:|---:|---|
| FMOVE.X FPm,FPn | 5 | 5 | – | |
| FADD.X, equal exponents | 6 | 6 | 3 | dep chain = FADD.X FP0,FP0 |
| FADD.X, exponent diff 5 | 7 | 7 | 3 | dep chain drifts to diff 6 |
| FADD.X, exponent diff 40 | 7 | 7 | 3 | any nonzero diff costs one alignment clock |
| FSUB.X, heavy cancellation | 7 | 7 | 3 | (1+2^-60) − 1.0, normalize by 60; derived, see below |
| FSUB.X, no cancellation | 8 | 8 | 3 | 1000.5 − 1.1 (diff 9) |
| FMUL.X FPm,FPn | 7 | 7 | 5 | 1.2345 × 1.0000123 |
| FMUL.X by 2.0 | 5 | – | – | power-of-two fast path |
| FDIV.X FPm,FPn | 29 | 29 | 37.5 | |
| FSQRT.X | 29 | 29 | 103 | |
| FMUL.X (A0),FPn | 11 | 11 | – | operand in D-cache |
| FMUL.D (A0),FPn | 12 | 12 | – | |
| FMUL.S (A0),FPn | 11 | 11 | – | |
| FADD.D (A0)+,FPn | 12 | 12 | – | 64 distinct doubles |
| FMOVE.X FPn,(A0) | 18 / 12 | 18 / 16 | – | latency column = FADD.X + store of its result, per pair |
| FMOVE.D FPn,(A0) | 12 / 9 | 16 / 16 | – | same pair form |
| FMOVE.S FPn,(A0) | 7 | 14 | – | same pair form |
| FMOVE.L FPn,(A0) | 9 | 16 | – | same pair form |
| FMOVE.D (A0),FPn | 9 | 9 | – | "dep" = same destination FP0 (a load reads no FP register) |
| FCMP.X FPm,FPn | 5 | 7 | – | latency column = FCMP.X + FBEQ.W on its result, per pair |
| FBEQ.W not taken | 2.3 | – | – | |
| FBNE.W taken (to next insn) | 2.2 | – | – | |
| ADD.L D0,Dn alone | 1 | – | – | integer reference |
| FMUL.X reg + 1 ADD.L | 7 per pair | 7 per pair | – | ADD fully hidden |
| FMUL.X reg + 4 ADD.L | 9 per group | – | – | = 5 + 4 |
| FMUL.X reg + 8 ADD.L | 13 per group | – | – | = 5 + 8 |
| FDIV.X reg + 8 ADD.L | 29 per group | – | – | hidden |
| FDIV.X reg + 24 ADD.L | 29 per group | – | – | = 5 + 24, still hidden |
| FINTRZ.X → vec 11, handler RTE | 65 | – | – | round trip |
| FINTRZ.X → vec 11, handler FSAVE -(SP); FRESTORE (SP)+; RTE | 167 / 163 | – | – | |
| FMOVECR #0 → vec 11, handler RTE | 65 | – | – | same as FINTRZ |
| FMOVECR #0 → vec 11, handler FSAVE/FRESTORE/RTE | 167 / 163 | – | – | |
| TRAP #0, handler RTE | 58 | – | – | |
| A-line $A000, handler ADDQ.L #2,2(SP); RTE | 62 | – | – | the ADDQ is needed: the frame PC is the A-line word |
| BSR.W to RTS (not a trap) | 10 | – | – | reference |

Trap rows are 65-66 per copy depending on alignment; 65 is the mean
(65.2-65.3). FBcc rows are 2 or 3 clocks per copy by alignment.

The reference column is only the MC68040 User's Manual execution-stage
figures that `docs/FPU_PROFILE_20260927.md` already quotes (section 10.7.3:
FADD/FSUB 3, FMUL 5, FDIV 37.5, FSQRT 103). Those are the FPU execute stage,
not full instruction cost; the other rows were not looked up.

FSUB with cancellation cannot be chained on its own (its result no longer
cancels), so the bench alternates FSUB.X FP7,FPn and FADD.X FP7,FPn with
FP7 = 1.0 and FPn = 1+2^-60: the subtract cancels to 2^-60 and the add
restores the value exactly (exponent difference 60). The pair average is
7.00 in both forms, and FADD with a nonzero difference is 7, so FSUB with
cancellation is 2 × 7 − 7 = 7. Its operands have equal exponents (no
alignment clock) but every effective subtract takes a normalize clock.

## What the numbers say

- **Issue interval equals latency for every FP op.** The FPU runs one
  operation at a time. The core holds the next FP instruction in
  `S_FPU_DEC` until the released (background) operation reports `done`.
  There is no FP pipelining, so independent code gains nothing.
- **No FP instruction takes fewer than 5 clocks.** FMOVE.X, FCMP.X and
  FMUL by 2.0 all take 5. A per-clock trace (`+tracecyc`) of back-to-back
  instructions shows where the clocks go:
  - FMOVE.X: the FPU spends one clock in `F_IDLE` accepting the request,
    then `F_EXEC`, `F_ROUND`, `F_WB`, and one more idle clock. The core
    spends 3 clocks in `S_FPU_GO` and 2 in `S_FPU_DEC`.
  - FMUL.X (7 clocks): the FPU goes `F_IDLE`, `F_BIN`, `F_MULT` ×2,
    `F_ROUND`, `F_WB`, idle. The core spends 3 clocks in `S_FPU_GO` until
    `accepted`, then 4 in `S_FPU_DEC` waiting for `done`.

  The request/accept handshake costs two clocks per operation in which no
  arithmetic happens: the FPU's idle clock after `F_WB`, while the core sees
  `done` and raises `fpu_req`, and its `F_IDLE` accept clock.
- **Integer overlap is real but small for short ops.** The core is blocked
  for at least 5 clocks per FP instruction (3 in `S_FPU_GO`, at least 2 in
  `S_FPU_DEC`). Integer instructions can only fill the rest of the FPU's
  time. For FMUL.X that is 2 clocks, so every ADD beyond two adds a clock
  (FMUL + 4 ADD = 9, + 8 ADD = 13). FDIV/FSQRT hide 24 integer clocks
  (FDIV + 24 ADD = 29 = FDIV alone).
- FADD alignment is one clock for any exponent difference (single-clock
  barrel shift), and zero for equal exponents. Normalize is one clock
  regardless of how far.
- FDIV and FSQRT are both fixed 29 clocks, faster than the 68040's execute
  stage alone (37.5 / 103). FADD (6-8) and FMUL (7) are about twice the
  68040's 3 and 5.
- Memory-operand forms add 4-5 clocks over the register form (FMUL.X (A0)
  11 against 7), with the operand in the D-cache.
- Stores are bus-bound in this model: FMOVE.X writes three longwords and
  takes 18 clocks at 3 wait clocks, 12 at 1. A store of a just-computed
  result waits for the op: FADD + FMOVE.S = 14 = 7 + 7, FADD + FMOVE.D/.L =
  16.
- The unimplemented-instruction trap with a bare RTE costs about as much as
  TRAP #0 (65 vs 58). FSAVE/FRESTORE of the UNIMP frame raises it to ~165,
  and that part depends on store latency. FINTRZ and FMOVECR behave the same.
  The bench counts one vector-11 exception per copy. FRESTORE of the saved
  UNIMP frame did not re-raise the trap.

## Harness

- `tb_fpu_latency.sv` is modelled on `verilator/tb_cpu_permute.sv`. It has
  `wombat_cpu` with `ce` = 1, 128 KB of RAM, and a fixed-latency responder
  (`+latency=N` wait clocks per 32-bit transaction). It is **not** the
  quadra800 SDRAM path, so memory-bound rows are model numbers.
  - A word write to `$F108` is a stamp. At its bus acknowledge the bench
    prints the clocks since the previous stamp, plus the exception entries
    (`S_EXC0*`) and the last vector.
  - The **BODY** line gives the clocks from the decode PC (`pc_i`) reaching
    the first body instruction to it reaching the closing `FNOP`. It
    excludes the stamp stores and the closing FNOP's wait.
  - `+tracelo=/+tracehi=` (hex) with optional `+tracecyc` prints a PC, core
    state and FPU state trace for a window.
- `fpu_latency.py` generates `fpu_latency.s`, assembles it with vasm, and
  builds the bench with Verilator 5 using the production macros, as
  `scripts/cpu/run_whetstone_image.py` does. It runs the bench at latency 3
  and 1 and prints the tables. It also checks the exception counts: each
  trap row has exactly one exception of the expected vector per copy, and
  every other row has none.
  - Each test is a straight-line block of 16, 32 and 64 copies. Each block
    starts with `FNOP; NOP; move.w #1,$F108` and ends with
    `FNOP; move.w #tag,$F108`.
  - Each block runs twice, and only the second (warm-cache) pass is used.
  - The reported figure is `(BODY(64) − BODY(32)) / 32`, which removes all
    fixed start and end costs. The stamp-to-stamp slopes (`32-16`, `64-32`)
    and `(stamp16 − empty block)/16` are in the results files. They agree
    except where the closing FNOP's wait varies with code alignment (FBcc,
    FMOVE.D store at latency 3).
- `fpu_latency.s` is the generated program. It is committed so it can be
  read without running the generator. The per-test instruction bodies are
  defined in `fpu_latency.py` (list `T`).
- `results_lat3.txt` and `results_lat1.txt` hold the raw output of the run
  above. Columns: stamp clocks for 16/32/64 copies, the 64-copy cold pass,
  the stamp slopes, per16, BODY clocks for 16/32/64 copies, and the reported
  `body` slope.

## Re-run

```bash
docs/perf/fpu_latency_20260928/run.sh              # ~1 min; latencies 3 and 1
docs/perf/fpu_latency_20260928/run.sh --latency 3 --keep-obj   # keep the Verilator build for tracing
docs/perf/fpu_latency_20260928/run.sh --worktree --out scratch/fpu_latency_20260928/worktree  # working-tree RTL
docs/perf/fpu_latency_20260928/run.sh --rev <commit>                      # another commit's RTL
scratch/fpu_latency_20260928/obj/Vtb_fpu_latency +prog=scratch/fpu_latency_20260928/fpu_latency.hex \
    +latency=3 +tracelo=2888 +tracehi=28b0 +tracecyc        # addresses from scratch/.../fpu_latency.lst
```

`run.sh` starts a transient user unit (`systemd-run --user --collect
--pipe --wait`). Outputs go to `scratch/fpu_latency_20260928/`: hex,
listing, logs and `results_lat*.txt`. The Verilator `obj` directory is
deleted afterwards unless `--keep-obj` is given. It needs vasm at
`/home/alans/mister/MacQuadra800_fixtures/wombat-vasm/vasmm68k_mot` (or
`$VASM`) and Verilator 5 at `/home/alans/verilator5/bin/verilator` (or
`$VERILATOR`).

## Side measurement: uncommitted P250 working tree

While this was being measured, another session had an uncommitted edit to
`rtl/ap68040/rtl/ap040_core.v` in the working tree ("P250: FPU issue
overlap"). It adds `S_FPU_ISSUE`, so the decode, EA and operand read of the
next FP instruction overlap the background operation. `run.sh --worktree`
measured that tree once (not qualified, and it may have changed since):

| Row | 0b2d265 | P250 tree |
|---|---:|---:|
| FMUL.X (A0),FPn | 11 | 8 |
| FMUL.D (A0),FPn | 12 | 9 |
| FMUL.S (A0),FPn | 11 | 9 |
| FADD.D (A0)+,FPn | 12 | 10 |
| FMOVE.D (A0),FPn | 9 | 8 |

Every other row, including all register-to-register rows, was unchanged.
Those rows are set by the handshake described above, not by the decode
wait.

## Limits

- Timing is from the 33 MHz CPU domain with a fixed-latency memory model;
  hardware SDRAM latency changes the store rows and the FSAVE handler row,
  not the register rows.
- Only data with ordinary operands was timed: no denormals, NaNs, infinities
  or zeros (FSUB x,x giving an exact zero takes a shorter path than the
  cancellation row).
- The FSQRT dependent chain converges towards 1.0. FSQRT is a fixed
  22-iteration loop, so the timing is not data dependent.
