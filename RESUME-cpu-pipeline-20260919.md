# RESUME — CPU pipeline, day 3 (2026-09-19 06:00)

Read this first, then `RESUME-cpu-pipeline-20260917.md` (the earlier
state and the increments 1-10 in detail), then
`docs/cpu-pipeline-increments-20260917.md` (every increment, every gate
number, every build), `docs/PERFORMANCE_MEASUREMENTS.md` sections 16-20
(the hardware numbers), then `CLAUDE.md`.  Branch **`CPU-pipeline`**,
head **f1ef706** (increments 1-15).  Nothing is pushed; **the user
pushes**.  Commit as work lands.

## The user's standing instructions (this session)

- Keep going with the CPU plan, as fast as possible before the next
  release; keep them updated after each build and each hardware run.
- **ONE synthesis at a time** on this box, and finish analysing a build
  before starting the next increment.  Other sessions build other cores
  here (sgiindy): `Get-CimInstance Win32_Process` for `quartus*` before
  launching; launch `scripts/build_only.sh` WITHOUT `--no-wait` so its
  wait-gate queues behind their flow.  Never kill a `quartus_*` that is
  not this project's.
- **Fewer builds, combine gated increments** (2-3 per build); intermediate
  rbfs are kept only as free bisect points.
- The hardware operator is an Opus subagent driving the .143 box only
  (briefs: `scratch/pipeline_b*/BRIEF.md`; the prompt used for builds 9
  and 10 is in the design note's Builds section style: read the brief,
  the gate_store brief, the previous report, CLAUDE.md; look before you
  load; deploy the COPY by hand with an md5 check; three valid Mix runs,
  invalid ones reported and replaced; park at the halt screen).
- Rule 3 of the branch, generalised: every `issue_ifetch` site takes the
  ONE shared target wire `go_pc_t_early`; carriers only enable.  Every
  qualifier of a same-cycle acknowledge is a register or the MMU's
  registered verdict (`c_post_ok_hint`, never the live `c_post_ok`).
- Run the cross-domain STA on every fitted tree BEFORE its db is
  overwritten: from `../MacQuadra800_wt3`, `quartus_sta -t
  scratch/tq_cross_b10.tcl` (edit the output names); the request handoff
  `sdram_beat32 req_tgl -> req_handoff` margin goes in the Builds table.

## Where everything is

| what | where |
|---|---|
| build worktree | `../MacQuadra800_wt3`, detached; builds run there, logs in its `scratch/build_b*_s21r.log`, rbf in `output_files/` |
| staged bitstreams | `scratch/pipeline_b7/` (7b, 9e3b7d9d), `_b8/` (69c53878), `_b9/` (f061d1fc), `_b10/` (28a7e6dc); each with `candidate.md5`, fit/sta summaries, BRIEF.md, and `report.md` where run |
| the .143 box | parked at the Mac OS 8.1 halt screen on **build 9's rbf** (`/media/fat/_Unstable/MacQuadra800_b9_s21r_f061d1fc.rbf`), `.s0` QuadSquad8.hda; `.s1`/`.s4` are the user's MacLC disk and CD, never touch them |
| CPU gates | `wsl.exe -e bash -lc 'bash /mnt/c/Temp/mistercore/MacQuadra800_MiSTer/scripts/cpu_gates_wsl.sh /mnt/c/Temp/mistercore/MacQuadra800_MiSTer/rtl/ap68040 <label>'` (copies the tree first; suite 25 legs incl. `t_branch_early`, `t_loops_irq`; bench_loop, pipe_bench, branch_bench; corpus-100).  The CPU-only bench now POSTS stores (wrapper `AP040_POST_STORES`) |
| head gate numbers (posting on) | suite 25/25; bench_loop 55,914; pipe_bench 110,696; branch_bench 119,284; corpus 32,248,984, 0 diffs |
| store buffer unit bench | WSL: `cd /mnt/c/.../verilator && make tb_store_buffer` (T4 = increment 14) |
| memory notes | `cpu-pipeline-plan-location`, `one-synthesis-at-a-time-focus`, `sdram-open-row-crossing` |

## Builds and hardware, in one table

| build | RTL | ALMs | timing | hardware |
|---|---|---|---|---|
| 6 | c84a5e7, increments 1-8 | 35,797 | CPU +0.139 | Mix 0.902, CQD 0.660 |
| 7b | + 9 (unconditional transfers redirect at the pop) + 788ab35 (shared target wire, brf_run) | 35,807 | CPU +0.580 | Mix 0.907 (+0.55 %), CQD 0.662; two non-reproducing short last-of-series timings |
| 8 | + 10 (DBcc from the pop) | 35,952 | CPU +1.114 | Mix 0.907, CQD 0.666, clean in six series |
| 9 | + 11 (S_FETCH pop to the chain) + 12 (loop-top record cache) | 36,400 | CPU +1.007 | **FINDING**: 2 of 5 Mix runs with impossible loop times (Bubble Sort 0.022 s); valid 0.911, Sieve +2 % slower (section 20) |
| 10 | + 13 (one-clock posted store) | 36,428 | CPU +1.145; SDRAM handoff crossing +1.27 (b8 +2.51) | not run (fewer builds) |
| 11 | + 14 + 15 (the head) | | stopped in the wait-gate | not built |
| 12 | **bisect**: build 8 + 13 + 14 + 15, WITHOUT 11 and 12 (wt3 detached edca43e) | | **in the fitter at 06:00** (`scratch/build_b12_s21r.log` in wt3) | the next run |

## The open question, and the decisive experiment

Build 9's impossible loop times are wrong execution (a loop that did not
run).  Two hypotheses: (a) the loop-top record cache (increment 12),
which replays a cached decode at every refill-buffer dispatch; (b) the
SDRAM bridge's half-cycle 33/99 MHz request handoff (`rtl/sdram_beat32.sv`,
`req_tgl -> req_handoff` on clk_ram's falling edge), which assumes PLL
phase alignment the constraints do not model (`docs/sdram-open-row-crossing.md`;
the 2026-09-02 negative-time fault was this family; build 7b's two short
readings fit it too).  The CPU-only simulation does not reproduce (a):
`t_loops_irq` passes with and without 11+12.  **Build 12 decides**: if
its run (ask the operator for FIVE Mix runs) is clean, the fault follows
11/12 and they stay out (revert them on the branch with a commit that
says why; the cache's value was +0.4 % anyway); if it shows impossible
times, the cause is physical and the fix to propose is a proper
two-flop toggle synchronizer with the payload held for two clk_ram
cycles in `sdram_beat32` (about one 99 MHz cycle per request, the
user's call), verified by `verilator/tb_memory_path` and the store
buffer bench.

## Next steps, in order

1. Build 12: when `Timing Analyzer was successful` appears, take the
   cross-domain STA (`scratch/tq_cross_b10.tcl` pattern), stage the rbf
   as `scratch/pipeline_b12/MacQuadra800_b12_s21r_<md5>.rbf` with
   `candidate.md5`, write `scratch/pipeline_b12/BRIEF.md` from
   `scratch/pipeline_b10/BRIEF.md` (candidate, timing, "build 8 plus
   13/14/15; increments 11-12 held out"; references: build 8's numbers,
   Mix 0.905/0.908/0.908, CQD 0.666, FPU 0.468/0.465; ask for five Mix
   runs and any impossible time reported in full), launch the Opus
   operator (the box is at the halt screen on build 9's rbf), record the
   result (measurements section 21, the Builds row, the qsf ledger).
2. Decide per the experiment above; commit the decision.
3. If clean: 13+14+15 measured together against build 8 (stores are 12 %
   of the bracket, reads behind stores 5 %); then the release gate the
   user asked about earlier (A/UX 3.1 at 32 MB, CD audio by ear) and a
   `releases/` row are their call.
4. Remaining levers after that: a Bcc.W/JSR (An) target table (small),
   Alan's two-sector refill buffer (+2,300 ALMs), a one-clock
   instruction fetch (the fetch queue's ring write failed by 7 ns once),
   the six-stage engine (months).

## Rules learned this session (all cost a build or a run)

- A second `issue_ifetch` target next to the shared wire lets the
  lookahead's flags select the seed cone's target (build 7: -1.575 ns).
- `brf_run` (valid runs precomputed from the registered `brf_valid`)
  turned an eight-step chain into one mux and gave +0.44 ns and -455
  ALUTs at once.
- The CPU-only bench's write path is a 16-bit bus with a seven-cycle
  memory: store-path gains are invisible there; hardware decides.
- Enabling posting in the bench needed three adaptations (the magic
  page not posted, the FC check attributing drains via `c_posting`, the
  double-fault bench unposted): each a property of posting, not a bug.
- `t_loops_irq`-style checksummed workloads under an interrupt storm are
  the right shape for hunting a dispatch bug; when they pass and the
  board fails, look at the memory path and the clock crossing.
- Increment RTS-from-the-pop was withdrawn (cycle-neutral: UNLK/RTS is
  bound by the acknowledge cycle); increment 11 is neutral on every
  bench.
