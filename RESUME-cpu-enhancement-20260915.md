# Resume prompt: AP68040 CPU performance work (2026-09-15)

Paste everything below the line into a fresh LLM session on the new
machine, after cloning the repositories.  It carries what the previous
sessions learned that is not in the code: the working rules, the state
of every candidate, the tools and fixtures a new box needs, and where
the numbers came from.  The long-form design context is in the
repository (`docs/CPU_PIPELINE_REWRITE_HANDOFF_20260915.md` first).

---

You are continuing the CPU performance work on **MacQuadra800_MiSTer**,
a Macintosh Quadra 800 core for the MiSTer FPGA (DE10-Nano) whose CPU is
the **AP68040** (a git submodule at `rtl/ap68040`, remote
`alanswx/AP68040`).  The goal is a faster CPU measured by **Speedometer
4.02 CPU Mix** on the real board: the source was 0.4635, **checkpoint
15 is 0.855** (2026-09-15), the near bar is **above 1.0**, the target
about **1.9**.  Read, in this order: `CLAUDE.md`, `RESUME-cpu-enhancement-20260915.md`
(this file), `docs/CPU_PIPELINE_REWRITE_HANDOFF_20260915.md` (the machine
as it is, every gate with its command, the pipelined-engine plan, the
rules learned), `CPU_PERFORMANCE_TASKS.md` (checkpoints 1 to 15 with
their numbers), `docs/CPU_FAST_READ_20260914.md` (the candidate in
flight), `docs/AGENT_TESTING_WORKFLOW.md` (the hardware procedure).

## Roles and standing instructions from the project owner

- Two roles: **Astra** does architecture, RTL, diagnosis and acceptance
  (the main session); **Luna** runs established tests, builds, the MiSTer
  GUI and Speedometer runs and produces evidence (bounded subagent
  tasks; the owner mapped Astra to the strongest model and Luna to a
  cheaper one).  One FPGA owner at a time; hardware tests go through
  `scripts/cpu_benchmark_core.sh`.
- "Keep iterating until we get a major speed increase above 1.0."
  "Commit after each speed increase."  "Make sure to push after
  commit": push the submodule first, then the parent, right after every
  commit.  Keep the owner informed with short status lines.
- Stay on the trimmed development profile `configs/cpu_development.tcl`
  (now in the repo).  The FPU must stay.  Mac subparts may be reduced in
  the development profile when the benchmark does not need them; the
  release recipe (the `.qsf` defaults) keeps everything.
- Agents never change constraints (`.sdc`), benchmark settings or the
  fixtures; a build-tree experiment on a fitter setting is fine when it
  is reported as such.
- Never deploy a bitstream whose exact RTL has not booted in the
  full-machine simulation; three valid hardware runs per bitstream;
  negative-time runs are invalid and never averaged; the board may be
  used freely unless the owner says it is reserved; look before any
  deploy (`scripts/grab.sh`) and never yank a running guest.

## Where the work stands

| item | state |
|---|---|
| checkpoint 15 | on hardware, 0.853/0.856/0.855 = **0.855**; parent branch `profile-speedometer402-20260909`, submodule `cpu-regalu-capture-retire-20260909` at `167c5e8`; bitstream seed 20 of the diet profile (38,663 ALMs) |
| one-clock data hit ("dovr") | RTL complete and green on every simulation gate, sim CPU Mix **0.861** (about 0.88 expected on hardware); branches `cpu-fastread-20260915` in both repos (submodule `6e65192`); **blocked on the fit**: 20 seeds of its predecessors failed routing or the 33 MHz CPU clock; dovr removed the request's live translation from the acknowledge path (the flow's path report showed it as the 2 ns miss) and its seeds were still fitting when this note was written; the OSD overlays are compiled out for it (`MISTER_DISABLE_HDMI_OSD`, `MISTER_DISABLE_VGA_OSD`, 37.5 K ALMs) |
| step C2 bound (+0.3 % sim) | a one-line fold-in (`n_desc_ok` without the producer bound, `scripts/cpu/handover_descriptor_all_retires.py`) to add to whichever candidate closes a seed |
| next levers | branch target cache / return stack on the fetch engine, reads passing pending stores, then the pipelined engine (the hand-off doc, section 6) |

Profile of the checkpoint 15 Speedometer bracket (4.8 clocks per
instruction): data reads 30 %, stores 12 %, register pipe 10 %, decode
8 %, demand fetch 7 %; archived profiles are not in git (they were in
`scratch/`), the numbers are in the hand-off doc.

## What is on the old machine but not in git (recreate or copy)

- `scripts/local.env` (gitignored): `QUARTUS_BIN`, the MiSTer host and
  key.  **The board's address in `CLAUDE.md` (192.168.99.143) is stale;
  the box used `MISTER_HOST=192.168.1.75`**, ssh key `~/.ssh/mister_only`,
  the mrext remote on `:8182`.  Verify the address before touching the
  board.
- The Speedometer golden disk image `MacQuadra800-Speedometer402-profile.hda`
  (90,224,128 bytes, MD5 `16790b0577e13b45782214433d34954b`): the
  guard's fixture; the MiSTer holds a copy at
  `/media/fat/games/MacQuadra800/Speedometer402-upstream-test.hda`
  that equals the golden after every guard restore (check the MD5).
  Every simulation launcher takes it as `GOLDEN`.
- The fast-boot ROM hex: `verilator/Makefile` builds it from
  `releases/quadra800.rom` (`make fastboot`, see `scripts/sim_wsl.sh`).
- `Speedometer 4.02.rsrc` (the application's resource fork, used by the
  Sieve fixture `scripts/fixtures/wombat_sieve/run.sh`): extract it
  from the disk image (hfsutils or unar) into any directory and pass its
  path.
- Tools: Quartus Prime 17.0.2 Lite; Verilator 5.050 built from source
  (the distribution's is too old); iverilog; vasm (`vasmm68k_mot`, built
  from the vasm source with `CPU=m68k SYNTAX=mot`); Python 3; ripgrep
  (`rg`) for `scripts/cpu_corpus100_gate.sh`.  The scripts default to
  the old box's paths and take `VASM`, `VERILATOR`, `MQ_REPO`,
  `CPU_GATE_VERILATOR` as environment overrides.
- Build trees: copy the repository to `/tmp/<name>` (without `db/`,
  `incremental_db/`, `output_files/`), set the `SEED` in the copied
  `.qsf`, run `bash scripts/build_only.sh --no-wait` there; the diet
  recipe is applied by the `.qsf` in the copy (the committed
  `configs/cpu_development.tcl` lists the macros; make sure the copied
  `.qsf` carries them).  A fit takes 40 to 60 minutes and 4 GB; a
  fitter silent for more than an hour is stuck.
- The full-machine simulator: `verilator/` (`make -j6 V=<verilator>`),
  then `scripts/fixtures/sim_speedometer/launch_candidate.sh` (boot A/B
  of 420 M CPU clocks with the per-state profile, then the simulated
  Speedometer through `run_speedometer_sim.sh`; about 25 minutes plus
  2.5 hours).  The Speedometer result is read from the last screenshot
  PNG (the Average line of the Benchmark Mix window).
- The corpus gate's payload and reference are now committed:
  `scripts/fixtures/corpus100/cpu.hex` (sha256 `989ba287…`, checked by
  the script) and `results.bin`; the latency fixture is
  `scripts/fixtures/line_latency/` (`python3 run.py` in a copy with the
  candidate's `rtl/`); the TimeQuest path script is
  `scripts/cpu/timequest_worst_paths.tcl` (use it after adding
  `TIMEQUEST_REPORT_WORST_CASE_TIMING_PATHS ON` to the tree's `.qsf`
  and re-running `quartus_sta MacQuadra800 -c MacQuadra800`; a bare
  script run without the fit's own settings reported nonsense once).

## Rules learned that are not obvious from the code

- Long jobs must not run as children of a tool call: use
  `systemd-run --user --quiet --collect --unit=NAME -p WorkingDirectory=DIR /bin/bash -c '...'`
  and check with `systemctl --user list-units`.  Never `pkill -f` on a
  binary name or on any string that appears in the running command:
  it matched the tool's own shell (exit 144) and, in a simulator driver,
  killed every simulator on the box each time a run finished.  Kill by
  pid found through `/proc/<pid>/cwd`.  After fixing a long-running
  script, restart every running instance of it (bash keeps the old text).
- Fit results at 90 to 92 % of the device are a lottery: compare
  candidates by simulation, walk six seeds in parallel, never conclude
  from one seed.  Placement noise between bitstreams of identical logic
  is about 0.5 % on hardware.  The fitter inserts about 1 us of
  hold-fix delay inside the 33 MHz domain on every build (clock-network
  skew); fitter effort multipliers and area synthesis do not help.
- PLL output 0 of the core PLL is the **33 MHz CPU clock**, output 1 the
  99 MHz RAM clock; the HDMI PLL is the third domain.
- The boot bracket (ROM-heavy) ranks candidates but under-states
  benchmark gains and penalises removing decode cycles that the fetch
  engine and the store drain were using; decide on the Speedometer sim.
- A task inlined at many call sites is one copy per site: the decode
  record handover inside `fetch_next` (83 sites) cost 8,400 ALMs; keep
  such logic in one arm keyed on a shared flag.
- The fitter shares logic the RTL duplicates: reducing the decode body
  after the record was generated recovered nothing.
- The register-class descriptor's opcodes no longer exist in the decode
  body (submodule `9ecf647`); the record cannot replace the descriptor
  without re-creating them.
- The full-machine harness reads `machine.cpu.mem_instr`; the hint bus
  turned that wire into an alias Verilator removes, so
  `launch_candidate.sh` patches the harness to read the core's
  registered flag.
- Hardware runs: the Speedometer "tests are done" alert must be
  dismissed and the window re-opened between runs; wait 135 s with no
  input before the capture; a run with a negative time is the known
  SDRAM-handoff anomaly (about 1 in 6), record it and run another.
- Documentation is part of the work: one dated `docs/CPU_*.md` per
  change with the design, every gate's number and what was withdrawn;
  the checkpoint entry in `CPU_PERFORMANCE_TASKS.md` carries the
  hardware numbers; commit and push after each step.

## First things to do on the new machine

1. Clone both repositories with submodules, check out
   `profile-speedometer402-20260909` (parent) with the submodule at
   `167c5e8`; create `scripts/local.env` from the sample.
2. Install the tools, build Verilator 5 and vasm, run the AP suite
   (`cd rtl/ap68040 && VASM=... sh tb/run_tests.sh`) and the corpus gate
   on checkpoint 15 to confirm the environment reproduces "ALL TESTS
   PASSED" and "CORPUS DONE in 33335739 cycles, REAL diffs: 0".
3. Build the simulator, run the boot A/B of checkpoint 15 and confirm
   76,218,560 dispatches in the 420 M bracket.
4. Fit checkpoint 15 at seed 20 on the diet profile and confirm timing
   met at about 38.66 K ALMs, then run the guard's dry run against the
   board.
5. Continue with the fast-read candidate branches: fit walk with the
   OSD overlays out, hardware when a seed closes, then fold in the C2
   bound, then the next levers in the hand-off plan.
