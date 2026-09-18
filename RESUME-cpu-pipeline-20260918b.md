# RESUME — CPU pipeline, day 3 continued (2026-09-18, machine clock)

Read this first, then `RESUME-cpu-pipeline-20260919.md` (the previous
hand-off; its dates ran a day ahead of the machine clock, it was written
on 2026-09-18 about 06:00), then the design note
`docs/cpu-pipeline-increments-20260917.md` (sections 13-14 and Builds),
`docs/PERFORMANCE_MEASUREMENTS.md` sections 20-21, `CLAUDE.md`.  Branch
**`CPU-pipeline`**; nothing is pushed, **the user pushes**.

## The user's instructions today (on top of the standing ones)

- Go quickly; do not wait for them unless they ask a question.
- Prefer the hardware to the sim ("just go directly to the hardware").
  The sim is still the right tool for an early-boot hang: minutes, and it
  named the cause of build 12's hang before the hardware could.
- If disk corruption is suspected, restore the image from the backup
  instead of repairing it.  Restore points on the .143 box, in
  `/media/fat/games/MacQuadra800/backup/`:
  `QuadSquad8_20260918_clean_after_b9.hda` (plain copy, md5
  0c3a754ee40f91a2ce3c57b8987bbe13 = the live image after build 9's clean
  shutdown, WITH Speedometer) and the user's `QuadSquad8.hda.zip`
  (2026-09-17 15:20, `unzip -t` clean).  `BUILD.md`'s
  `backup/QuadSquad8.hda.gz` is no longer on the box.
- They asked whether pipeline work proper had started.  Answer at the
  time: no new increment; the session went to the bisect, a bug and a
  fix.  The next increment is to be chosen from a CURRENT profile (below).

## What happened, in order

1. **Build 12** (build tree edca43e = build 8 + increments 13, 14, 15,
   without 11/12) met every clock (CPU +1.241, 36,071 ALMs, request
   handoff +1.384), rbf 555a954b.  Its flow ran under build 11's launcher,
   which had survived its "stop" in the wait-gate (only the outer shell
   had died); content verified by git before staging; build 12's own
   waiter killed so nothing recompiled over the fitted db.  To cancel a
   queued build, kill every bash whose command line is
   `scripts/build_only.sh`.
2. **Build 12 on hardware DOES NOT BOOT**: bare grey screen, no pointer,
   no disk access (section 21).  So the bisect question (impossible
   Speedometer times without the record cache?) was not answered by it.
3. **The cause: a hole in increment 14** (`wombat_store_buffer.sv`
   `pass_ok`), found by inspection before the hardware result arrived:
   the compare covered only the first 16-byte line of each transfer, and
   the cache posts line-crossing stores unsplit and invalidates both
   lines, so the fill of the second line passed the queued store and
   cached stale bytes.  Fix cf06fe6 (`xfer_cross`, two LUTs), unit bench
   T5 (fails on the old RTL at its first check).  The full-machine sim
   confirmed it: build 12's tree sits at the grey screen through frame
   840, build 13's shows the Happy Mac at frame 480 like the build-8
   control (`scratch/pipeline_b13/sim_*.png`).
4. The full-machine sim harness had not compiled on this branch (MLAB
   regfile, hint bus signal names): repaired in 8359fa3.
   `scripts/sim_tree_wsl.sh <name> <commit>` (run inside WSL) builds a
   sim tree `~/MQ_<name>` from any commit; copy `run.hda` in and run
   `./obj_dir/Vemu --headless --no-cpu-trace +rom=quadra800-fastboot.rom.hex
   --disk run.hda --screenshot F1,F2,.. --stop-at-frame N`.  Compare
   frame md5s across trees.
5. **Build 13** (build 12's tree + cf06fe6; build tree 4d09389) met every
   clock: CPU +0.772, RAM +0.668, HDMI +0.527, hold +0.204, 36,089 ALMs,
   request handoff **+0.727** (watch this one: a two-LUT change moved it
   from +1.384).  rbf fde49a3c in `scratch/pipeline_b13/` with its brief.
   The Opus operator was launched on it at about 06:57: boot check, then
   EIGHT Mix runs (the anomaly tally is the headline), CQD, FPU x2, park.
   If it hangs at grey, the brief has build 10's rbf as a free bisect
   point (build 9 + increment 13 only).
6. The CPU gates on the core with 11/12 reverted in RTL only (byte-
   identical to build 12/13's core): suite ALL PASSED, bench_loop 68,100,
   pipe_bench 110,696, branch_bench 119,284, corpus 32,266,129, 0 diffs
   (`scratch/pipeline_b12/gates_revert1112.log`).  The revert itself is
   NOT yet committed on the branch: the head still carries 11 and 12.

## The open question is still open

Impossible single-test times: build 9 (2 of 5 Mix runs), build 7b (two
smaller ones, no record cache!), the 2026-09-02 negative Queens on a much
older core; build 8's three clean Mix runs had a ~22 % chance of being
clean by luck at build 9's rate.  So the fault class predates 11/12 and
the evidence against the record cache is circumstantial.  Build 13's
eight runs are the next data: clean -> revert 11/12 on the branch (their
value was +0.4 %), saying that the evidence is statistical; anomalies ->
not the record cache alone; then eight runs of build 8's rbf
(`scratch/pipeline_b8/`, no new build) establish whether it predates
increment 9, before anyone touches `sdram_beat32`.  STA margins on the
crossing have been positive on every build (+0.7 to +2.5 ns, same PLL,
`derive_clock_uncertainty`), which argues against the physical
hypothesis more than for it.

## Next steps

1. Build 13's operator report -> section 22, the Builds row, the qsf
   ledger, the decision on 11/12 (above), commit.
2. A release candidate needs the full gate (A/UX 3.1 at 32 MB, CD audio
   by ear): the user's call.
3. The next pipeline increment, chosen from a current profile: a
   profiled 8.1 boot of build 13's tree runs in WSL
   (`~/MQ_b13/verilator/sim_prof.log`, `[PROF]` blocks are cumulative at
   every heartbeat; started about 07:05, stops at frame 7201).  Alan's
   map at checkpoint 14 (`../quadra800_alan/docs/CPU_DECODE_HISTOGRAM2_20260915.md`):
   S_MRD 28 %, S_DECODE 13 %, S_MWR 11 %, S_PIPE_REGS 9 %, S_PIPE_START
   7 %, S_FETCH 6.5 %; 63 % of dispatches paid a decode cycle, led by
   memory-source MOVE/CMP/TST.  Much of that is covered by the record
   handover now; measure before choosing.  Candidates from the hand-off:
   a Bcc.W / JSR (An) target table, a one-clock instruction fetch, Alan's
   two-sector refill buffer (+2,300 ALMs), then the engine itself.
4. Rule learned today: every address compare below the cache has to be
   read against "misaligned word/long transactions appear here unsplit"
   (`wombat_cpu.sv`'s bus contract); the pre-existing fast paths in
   `quadra800.sv` are safe because they require aligned longs.  And a
   store-path or cache change gets the three-tree sim frame comparison
   BEFORE its fit.
