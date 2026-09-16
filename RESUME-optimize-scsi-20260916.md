# RESUME -- optimize-SCSI, hand-off 2026-09-16 ~19:50 (updated from the 18:40 one)

Read this, then `docs/scsi-hps-offload-plan.md` sections 9 (checklist),
9b (phases) and the tail of 10 (log; the 19:40 entry is the latest), then
the memory notes `pickup-2026-09-08`, `one-quartus-flow-at-a-time`,
`prefer-hardware-over-sim`, `mister-92-box` (off limits),
`bash-tool-heredoc-backslashes`.

## Where things stand

- **Core branch `optimize-SCSI`** (unpushed; the user pushes). Tip =
  `f4d45c7` (docs) over `eb53c50` (plan) over **`3ec22e4` (the fix)** over
  `97ea3eb` (the owner register, WIP then) over `31de7a8` (the 18:40
  hand-off). Main fork branch `mac-ethernet-pr-with-SCSI-Optimizations` at
  `ae708d3` (unpushed); binary `898854ef` on .143; no Main change pending.
- **Phase 1 RELEASED** as `releases/MacQuadra800_20260916.rbf` (`1eae0fb7`).
- **Phase 2's Audio Player failure is understood and fixed in RTL:**
  1. The WIP T20 chased a phantom: a CD data READ raises `read_stb`, which
     idles the engine, so no fetch could collide with the read ("collision
     cycles seen: 0" was true), and its "stale" byte 1024 was HPS block 10,
     overwritten by T14's WRITE(6) at LBA 10 earlier in the run.
  2. T20 is rewritten (`3ec22e4`) as a forced same-cycle collision: the
     engine's status poke in flight on a 300,000-cycle platform, the
     cadence frees a half so the frame fetch waits in F_REQ, a nexus
     request waits on io_busy (part c: a disk WRITE(6) flush pushed as one
     TC=512 TI; part d: a guest `$CC` window read); both fire the cycle the
     poke's ack falls; preconditions asserted. The bench's platform model
     now serves the lowest slot (scsi_cache's priority), acks per slot,
     counts astray disk requests (`bad_disk_req`). **The pre-owner RTL
     (`450445b`) fails it the way hardware did** (the flush at the frame
     window's address with block count 4, ack masked, served for ever: 527
     failures, `scratch/t20/prewip.log`).
  3. With the owner register, part d still failed: the `$CC` bytes came
     back `$FF` and the DATA IN ended empty. **The real hardware bug:
     `abort_nexus` armed `io_discard` on `io_busy`, which includes the
     engine's transfer (`ca_io_active`), so a guest command selected while
     a frame fetch or the poke was out lost its OWN first read** -- the
     player's status polls read nothing ("drive not responding" 7 s into
     Play); a disk READ selected the same way came back one block off (a
     candidate for the error-41 image). In every release since 26b5e67
     (2026-09-02); phase 2's 13 ms fetches made it bite. Fix: only the old
     nexus's own read in flight (`io_rd_i || io_ack_i`) arms the discard.
     Bench: **477,415 checks, 0 failures**.
- **The fit is running**: seed 22 (qsf default), launched 19:38,
  `scratch/build_phase2b.log`, ~40 min; a background waiter greps for
  `RESULT:`. The RTL in it = `3ec22e4`.
- The A/UX shutdown "wedge" is the OSD RAM option (128 MB hangs, 32 MB
  halts; see the 18:40 hand-off text in git for the six-run evidence); the
  box is left at 32 MB; the core's RAM decode is a flat power-of-two window
  with open bus above it (`rtl/quadra800.sv` `ram_limit`), so the 64 MB
  point and then the trace build are the next probes.

## Do next, in order

1. When the build ends: read `output_files/MacQuadra800.sta.summary` /
   the log's `Timing (STA)` line and the fitter's ALM count. Timing met is
   the release bar, but a marginal build gets tried (`try-builds-dont-
   wait-for-timing`); a CPU-clock miss is noted. Record the seed result in
   the `.qsf` comment block (never while a flow runs).
2. `bash scratch/stage_phase2b.sh` (Git bash): keeps
   `scratch/MacQuadra800_phase2b_s22_<md5>.rbf`, stages
   `_Unstable/MacQuadra800_phase2b_s22.rbf` on .143 with an md5 check, and
   fills `__MD5__` in `scratch/p2b/BRIEF.md`.
3. Hand `scratch/p2b/BRIEF.md` to an Opus operator (background). Step 0
   relaunches MAIN at the MENU core (Main holds event8..18 but not
   event15, the remote mouse node created 18:04 -- hence "motion dead";
   inittab starts Main once at sysinit, no respawn; never restart the
   remote service). Then 8.1 + retail ISO, A/UX at 32 MB, the AppleCD
   Audio Player on `AudioTest.cue` (Play >= 60 s, Pause, Play, Next, Prev,
   scan, volume, Stop) with Main's `Mac CD: cmd` lines as evidence.
4. Release phase 2: `releases/MacQuadra800_20260916_2.rbf`, the README row
   + section from `scratch/release_phase2_draft.md` (fill the numbers and
   the hardware results), `docs/area-budget.md` (the phase-2b fit), the
   plan's D3 tick, commit. The user pushes.
5. Follow-ups: the 128 MB A/UX shutdown hang (a 64 MB run; then
   `_Unstable/MacQuadra800_trace7_phase1.rbf` + `scripts/scsi_trace.sh`);
   Speedometer on an image that has it (ask the user); the one-in-three
   8.1 boot freeze at the extension icons seen once at 08:10.

## Box (.143) state at 19:20 (read-only look)

MENU core; Main `898854ef` started by hand at 18:04, stdout to
`/media/fat/nohup.out` (19,323 lines; the two `Mac CD: cmd 47` lines of
the failed player runs are 15041 and 18658); `.s0` Quad Squad (restored
18:13, clean), `.s1` FreshTest, `.s4` retail ISO; RAM 32 MB (`cfg` byte 0 =
0; `.bak128` = the 128 MB original); A/UX image pristine (16:48);
`games/MacQuadra800/AudioTest.cue/.bin` (4 audio tracks, 7:02); the
damaged Quad Squad copies kept (`_damaged_`, `_damaged2_`, `_postyank_`,
all the pristine size); `_Unstable/`: `MacQuadra800_phase2_s22.rbf`
(`c2a902cb`, the failed-gate build), `MacQuadra800_phase1_s21b.rbf`
(`1eae0fb7` = the release), `MacQuadra800_20260915.rbf`,
`MacQuadra800_20260908_3.rbf`, `MacQuadra800_trace7_phase1.rbf`; remote
service running (`remote_update.sh -service status`).

## Rules (user)

Only the .143 box. One Quartus flow at a time (worktrees included; check
`Get-CimInstance Win32_Process` for `quartus*` first). Hardware over the
sim (short directed benches only). Restore a damaged image from `backup/`;
for A/UX never wait for the fsck, restore instead. A/UX gates at 32 MB.
Opus operators for all guest driving (resume the same agent on an HTTP
529). Commit as work lands, do not push. Command = keycode 56 (Left Alt),
Option = 125, `MISTER_HOST=192.168.99.143`. Never reload a core while a
guest runs unless it is provably dead. Edit scripts go in
`scratch/edit_*.py` via the Write tool (heredocs with `$` or quotes break).
