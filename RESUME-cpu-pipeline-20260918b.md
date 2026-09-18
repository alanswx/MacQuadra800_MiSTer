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

## Update 2026-09-18 about 08:45: build 13 measured, 11/12 reverted, A/UX gate running

- **Build 13 on hardware** (section 22): boots (Finder <= 100 s), **Mix
  0.9285, mean of EIGHT valid runs** (+2.4 % over build 8, +8.6 % over the
  shipped 0.855; Sieve +6.0 %, Permutations +3.7 %), CQD 0.670, FPU
  0.466/0.468, **0 anomalous values in 11 series**, clean 47 s shutdown.
- **Increments 11 and 12 are reverted on the branch** (4abb118, RTL only,
  tests kept; the commit says the evidence is statistical).  The branch
  head's synthesizable RTL is byte-identical to build 13's tree (4d09389),
  so **build 13's rbf IS the head's bitstream**: no new build is needed
  for a release candidate.
- **The A/UX 3.1 half of the release gate is running on build 13** (Opus
  operator, brief `scratch/pipeline_b13_aux/BRIEF.md`, report to
  `scratch/pipeline_b13_aux/report.md`): pristine A/UX image from the
  zip, `.s0` via the ready-made `.s0.aux`, boot to multiuser, CommandShell
  `uname -a` / `ls` / `df`, `shutdown -h now`; on a wedge, a control run
  on build 8's rbf; `.s0` restored to QuadSquad8 at the end.  The box is
  at the 32 MB RAM option (`MacQuadra800.CFG` all zeros) and has been for
  every measurement on this branch.  Increment 13's write-side MMU verdict
  is what this tests.
- Still owed for a release: CD audio by ear (the user), then
  `releases/MacQuadra800_YYYYMMDD.rbf` + README row.  Their call.
- **A current profile** is in the design note ("Where the clocks go on
  build 13's core"): in the 8.1 boot bracket S_MRD 41 %, S_MWR 14.5 %,
  S_FETCH 10 %, all the sequencer states together under 20 %; a RAM store
  costs 4.9 clocks at the margin although posted.  Tool:
  `scripts/cpu/sim_prof_diff.py <sim_prof.log> <fraction>`; the log is
  `~/MQ_b13/verilator/sim_prof.log` in WSL (the run stops at frame 7201).

## The recommended next increment

**The store drain's write rate** (`rtl/sdram_beat32.sv` + `rtl/sdram.sv`):
a posted longword is drained as two complete 16-bit SDRAM write
transactions, each with its own ready handshake (`acc`), about 6 clk_sys
per longword sustained (`docs/sdram-fast-path.md`: 21.7 MB/s for 64
sequential writes).  While a drain is in flight the bridge is `busy`, so
fills queue behind it too.  Issuing the two halves as consecutive WRITE
commands to the open row (or a two-beat write burst; the mode register
has `NO_WRITE_BURST = 1` today) should roughly halve that.  Expected: a
few percent on boot/launch/block moves, under 1 % on the Speedometer Mix
(Sieve and the store-heavy tests most).  Gates: `make tb_sdram` (both
ranks, ZERO protocol errors), `tb_memory_path_registered_first_miss`,
`tb_store_buffer`, the three-tree sim frame comparison, then the fit with
the clk_ram and crossing reports (clk_ram has +0.67 ns on build 13 and the
controller's command path is the historically tight one).  It adds a
handful of LUTs.  After it: a store admitted while an instruction fill is
in progress (a third of the store clocks in the boot bracket), then the
plan's step 4.

## Update 2026-09-18 about 09:00: the A/UX gate is BLOCKED on the user's slot 4, and the box is NOT at a halt screen

`scratch/pipeline_b13_aux/report.md` (21 screenshots).  Build 13 booted
A/UX 3.1 from a pristine image (restored from the zip) to the multiuser
Finder desktop between T0+342 s and T0+497 s: no panic, no garbled
console, no streaks.  **(a) boot: PASS.**  (b) CommandShell and (c)
`shutdown -h now` were NOT REACHED: a modal "This disk is unreadable: Do
you want to initialize it?" came up at T0+122 s and never left.  Main's
log names the cause: slot 4 holds the user's AUDIO CD
(`games/MacLC/CD3/TIM_3-mac.CUE`), which A/UX's System 7 environment
cannot read; Eject (17 times), Return, Escape and Cmd-. do not dismiss it;
the Apple menu opens but CommandShell and Special -> Shut Down are greyed.
Not attributable to the build (8.1 ran 59 minutes on the same core with
the same slot 4).  The operator never went near Initialize.

**STATE OF THE BOX: build 13 is RUNNING A/UX multiuser with that dialog
up.  The user's `games/MacLC/MacLC_7-1-MiSTer.hda` (slot 1) is mounted
READ-WRITE in it as "Macintosh HD".  Do NOT load a core over it** (rule 1;
it is the user's disk).  `.s0` was already restored to QuadSquad8.hda (it
takes effect at the next load); `.s1`/`.s4`/CFG untouched.  The way out
needs the user: either they shut that guest down / dismiss the dialog at
the display, or they say that `.s4` may be moved aside for A/UX runs
(`mv MacQuadra800.s4 MacQuadra800.s4.off`, restore afterwards, as the
2026-09-16 p2d gate did) and how they want the running guest ended.  The
rerun is about 20 minutes once slot 4 is empty; the pristine A/UX image
should be restored from the zip again first (this boot will not end
cleanly).

Operator finding worth folding into the guest scripts: A/UX never sees a
button press with no pointer motion (the held-down frame is byte-identical);
a press with a 1-pixel jiggle inverts the button.  That is why `menu.sh`
works on A/UX and `click.sh`'s static click does not.

## Update 2026-09-18 about 09:05: the A/UX gate PASSES on build 13; the box is at the A/UX halt text

The user ejected the unreadable disc at the display (their Eject also
emptied `/media/fat/config/MacQuadra800.s4`: Main wrote a NUL at byte 0 at
08:53; that was THEIR action, the file was never touched by us; they may
want to remount their CD).  The operator then finished the gate on the
running guest, loading nothing: root CommandShell, `uname -a` = `A/UX
localhos 3.1 SVR2 mc68040`, `ls -l /etc | head -20` and `df` sane,
`shutdown -h now` to "You may now switch off your Macintosh safely."
within 127 s.  Section 22 has it.  They answered "touch neither" about
parking `.s1`/`.s4`: those stay theirs.

**Build 13 (rbf fde49a3c = the branch head's RTL) has now passed: Mac OS
8.1 boot, 59 minutes of Speedometer with zero anomalies, clean 8.1
shutdown, A/UX 3.1 boot, shell and shutdown at 32 MB.**  Owed for a
release: the CD audio check (ToneTest.cue in slot 4, Main with its stdout
in a file, and the user's EARS, see CLAUDE.md), then
`releases/MacQuadra800_YYYYMMDD.rbf` + the README row.  Their call.
State of the box: build 13 loaded, A/UX halt text, `.s0` =
QuadSquad8.hda (effective at the next load), so the next `load_core` is
allowed after a look.

## Update 2026-09-18 about 10:20: RELEASED, and the Main fork rebuilt

- **`releases/MacQuadra800_20260918.rbf`** (md5 fde49a3cf474d5c07aff26c592200125,
  commit 71011be) at the user's request: build 13 = the branch head's RTL
  and qsf settings (verified by diff).  The README section records the gate
  as run (8.1 + Speedometer, A/UX 3.1 at 32 MB) and says plainly that the
  **CD-audio item was NOT run on this bitstream** (CD/SCSI RTL unchanged
  from 20260916_2).  It still wants the ToneTest pass and the user's ears.
- **The Main fork was rebuilt** at the user's request after their rebase:
  `../Main_MiSTer` branch `mac-ethernet-pr-with-SCSI-Optimizations`, head
  2d93232 (the twelve Mac commits) on upstream 3d7a844 (2026-09-18, past
  Release 20260912).  Clean build (`scripts/build_main_wsl.sh`, no object
  older than today, 0 warnings): **`scratch/MiSTer_bb1a08d3`**, md5
  bb1a08d3a829814c47d18888ee43ca73, 1,211,428 bytes, ARM ELF, carries
  `macquadra800` and the `Mac CD: cmd` log line.  NOT installed on the box
  and NOT copied into `releases/`: it has not run on hardware, and replacing
  `/media/fat/MiSTer` is the user's step (the box runs
  `releases/MiSTer_20260916`, md5 431da61a).  When it has passed the CD
  audio check it becomes `releases/MiSTer_20260918`.

## Update 2026-09-18 about 10:30: the rebuilt Main is INSTALLED on the .143 box (the user asked)

For the user's end-to-end CD audio test.  The box was at the MiSTer menu
(the user had loaded it).  `/media/fat/MiSTer` = **bb1a08d3a829814c47d18888ee43ca73**
(`scratch/MiSTer_bb1a08d3`, also kept on the box as `MiSTer.new_bb1a08d3`),
relaunched by hand on `menu.rbf` with its stdout appended to
`/media/fat/nohup_video.log` (a `=== relaunch ... Main bb1a08d3 ===` marker
line precedes it), so `Mac CD: cmd` lines will be there.  The previous
binary is untouched as `/media/fat/MiSTer.clean_431da61a` (md5 431da61a =
`releases/MiSTer_20260916`).  Revert:
`cd /media/fat && killall MiSTer; cp MiSTer.clean_431da61a MiSTer && sync`
and relaunch (or power-cycle).  A power cycle starts Main WITHOUT the
stdout log.  The release core is on the box as
`/media/fat/_Unstable/MacQuadra800_20260918.rbf` (md5 verified).  `.s4` is
still empty from the user's Eject; `games/MacQuadra800/ToneTest.cue` is
there for them to mount.  Screenshots do not show the HDMI output (the
2026-09-17 stale-object Main gave a black menu on HDMI only): the user
judges the menu at the display.  If the CD audio test passes, copy
`scratch/MiSTer_bb1a08d3` to `releases/MiSTer_20260918`, note it in
`releases/README.md` and CLAUDE.md's gate text, and strike the "CD audio
NOT RUN" caveat from the 20260918 release section.
