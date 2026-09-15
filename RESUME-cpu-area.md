# RESUME — Alan's checkpoint 15 in the full-feature core (2026-09-15)

Read this before `RESUME-alan-perf.md` (the earlier branch state) and
`RESUME-open-items.md` (everything that is not the CPU).  Design note:
`docs/cpu-area-consolidation.md`.

## What happened today

The user asked for Alan's newest CPU work with every feature kept and
`sys/` untouched, and for the 68040 RTL to be made more efficient.

- Alan's tips since our merge (`../quadra800_alan`, fetched over HTTPS
  from `alanswx/AP68040`): `cpu-regalu-capture-retire-20260909` =
  **checkpoint 15** (`167c5e8`, 0.855 Speedometer CPU Mix on his trimmed
  profile), and `cpu-fastread-20260915` = the one-clock data hit
  (`6e65192`, simulated 0.861, never fitted: it failed routing on every
  seed at 92 % on his profile).  His parent branches also carry `sys/`
  development switches (OSD/audio/video-calc/shadowmask removal) that we
  do NOT take.
- Checkpoint 15 is integrated on branch `alan-perf-20260908` (parent
  `f0c2572`): submodule pointer + his wrapper wiring (line offer, posted
  stores, `c_busy`), `c_post_ok` widened to the DAFB VRAM window, his
  corpus-100 gate taken as tooling.  In the full-feature core it
  synthesized to 64,723 ALUTs / est. 41,919 ALMs -- over the device
  (our shipped store head: 62,527 / 41,116 fitted).
- The submodule branch `wombat-area-diet` (on `167c5e8`) hoists the
  multi-site sequencer tasks into single post-case arms keyed on
  blocking carriers, cycle-identical (AP suite, `bench_loop`
  94368/95166, corpus 33335739 cycles / 0 REAL diffs):

| commit | step | ALUTs | est. ALMs |
|---|---|---:|---:|
| `167c5e8` | Alan's checkpoint 15 | 64,723 | 41,919 |
| `817feda` | R1 `fetch_next` | 60,199 | 38,754 |
| `5a25931` | R2 `mrd`/`mwr` (area-neutral, kept for the `mem_addr_q` path) | 60,306 | 38,818 |
| `5bd2ca7` | R3 `exc` + the SBCD reduced-body artefact fix | 59,165 | 38,222 |
| `8778213` | R4 `immf` | 58,786 | 37,951 |
| `c789ffe` | R5 `go_pc`, early-data form (the late-data form `0e8314b` measured 57,329 / 36,952 but missed timing) | | |
| `923c544` | R6 `decode_dbcc_brf`, early-data form (late-data `6fd4e88`: 56,595 / 36,504, timing miss -4.06 ns on the CPU clock) | | |

The late-data pair is kept as submodule branch `wombat-area-diet-late-data`.

## Gates and tools

- `scripts/cpu_gates_wsl.sh <ap68040 dir> <label>` runs the three CPU-only
  gates in WSL (iverilog/vasm in `~/local/bin`, Verilator 5.020).
- `scripts/cpu/audit_task_sites.py CORE.v TASK` before hoisting a task.
- Analysis & Synthesis `--check` in `../MacQuadra800_wt2` (detached at the
  branch head, submodule file copied in) for the per-entity table; the
  map reports of each step are kept there as `output_files/*.map.rpt`.
- Full-machine sim: `scripts/sim_wsl.sh build`; the Mac OS 7.1 image
  (`../MacAtrium-7.1.hda`) does not boot (no Quadra enabler), the fresh
  8.1 install parks in the ROM video identification (open item), the
  System 7.6.1 image (`/c/Temp/MacAtrium_Sys-QT_761.hda`) boots into the
  System (in progress as this was written).

## Open

- **R1..R4 fits at seed 21 with timing met** (38,325 ALMs, 91 %; rbf
  `scratch/MacQuadra800_diet_r4_s21_8c6d48b5.rbf`, md5 8c6d48b5): the
  hardware gate on the .92 box runs on it (`scratch/gate_diet/`).  The
  late-data R1..R6 fit at 37,189 ALMs but missed the CPU clock by 4.06 ns;
  the early-data R5/R6 (`923c544`) are fitting in `../MacQuadra800_wt2`
  (`scratch/build_r56e_s21.log` there).
- The one-clock data hit (`6e65192`) as the next increment once there is
  routing headroom; Alan's hand-off plan (`docs/CPU_PIPELINE_REWRITE_HANDOFF_20260915.md`
  in his tree) lists the levers after it.
- Report to Alan: the hoisting (his `rd_queue_pop` pattern generalised),
  the SBCD/PACK/UNPK `default: go_illegal` left by `reduce_decode_body.py`
  (a spurious queue flush on every one of them), and that his `sys/`
  switches are not needed once the core is ~4,000 ALMs smaller.
