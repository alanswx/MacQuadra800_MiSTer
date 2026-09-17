# RESUME -- optimize-SCSI, hand-off 2026-09-16 ~23:50 (supersedes the 22:45 one)

Read this, then `docs/scsi-hps-offload-plan.md` sections 9 (checklist),
9b (phases) and the tail of 10 (log; the 22:35 entry is the latest), then
the memory notes `pickup-2026-09-08`, `one-quartus-flow-at-a-time`,
`prefer-hardware-over-sim`, `mister-92-box` (off limits),
`bash-tool-heredoc-backslashes`.

## Where things stand

- **Core branch `optimize-SCSI`** (unpushed; the user pushes). RTL tip =
  **`2922294`**; docs/qsf commits after it up to `7eb0f00`. Main fork
  branch `mac-ethernet-pr-with-SCSI-Optimizations` at `ae708d3` (unpushed);
  binary `898854ef` on .143; no Main change pending.
- **Phase 1 RELEASED** as `releases/MacQuadra800_20260916.rbf` (`1eae0fb7`).
- **Phase 2's Audio Player failure needed TWO RTL fixes**, both in and
  bench-proven (`tb_ncr53c96` 477,417 checks / 0; each negative run --
  the bench against the RTL before the fix -- fails):
  1. `3ec22e4`: `abort_nexus` armed `io_discard` on `io_busy`, which
     includes the engine's transfer, so a guest command selected during a
     frame fetch lost its own first read.
  2. `2922294`: a DATA IN phase moves to STATUS only while `nexus_io` is
     quiet, and `nexus_io` included `ca_io_active`; the completion is
     evaluated once, so a poll whose last byte drained while a fetch was
     out stayed in DATA IN for ever -- right after PLAY (the poke and two
     fetches back to back) the driver's first poll hit it every time:
     "drive not responding" 4-8 s in, counter at 00:00. The seed-23 probe
     of fix 1 alone (`scratch/p2b/report.md`) proved the ARM side right
     (Main's seven `cmd 47` lines: the playhead ran the 7:02 disc in real
     time, the guest read its position correctly at every player launch)
     and the polling wrong. Fix: `nexus_io` without `ca_io_active`; the
     data-out chunk completion waits while a full sector is still owed
     (`sbuf_pos == 512`, no list) so a write cannot lose its flush.
- **T20** now forces the same-cycle collision on purpose (the poke in
  flight on a 300,000-cycle platform, a half freed by the cadence so the
  fetch waits in F_REQ, a disk flush / a `$CC` read waiting on io_busy),
  asserts its preconditions, and checks the phase at the chunk end with
  the fetch provably in flight; the platform model serves the lowest slot,
  acks per slot, counts astray disk requests.
- **The fix is PROVEN on hardware** (23:03, `scratch/p2c/report.md`): on
  `a719e24f` (seed 24 of `2922294`, clk_sys -0.727) the AppleCD player
  played 12 min 32 s -- Play (00:12 / 00:43 / 01:14, track 3 at 3:24),
  Pause held 46 s and resumed from 01:15, Next / Prev, scan +16 s, volume
  down / up, Stop to 00:00 -- no dialog; Main's 25 `Mac CD: cmd` lines (47,
  4B, CD, 01 for Stop) match every displayed position to the second; 8.1 +
  retail ISO passed; no memory trouble on the marginal clock.
- **Fits of `2922294`** (the qsf comment block has every seed): 21 clk_sys
  -0.231 on ONE path (rbf `ab1da889`, `scratch/MacQuadra800_phase2c_s21_ab1da889.rbf`,
  staged as `_Unstable/MacQuadra800_phase2c_s21.rbf`), 24 -0.727
  (`a719e24f`, the probe build, staged as `_phase2c_s24`), 22 -1.413 TNS
  -108 (`e7e3280c`). **Seed 23 fitting** since 23:39 (wait-gated,
  `scratch/build_phase2c_s23.log`, a waiter greps for `RESULT:`); after it
  `python scratch/edit_qsf_routability.py on` (FITTER_AGGRESSIVE_ROUTABILITY
  ALWAYS) with seed 21. **The FULL release gate is running on the seed-21
  build** under the try-marginal policy (Opus operator, `scratch/p2d/BRIEF.md`,
  report `scratch/p2d/report.md`: the player first, 8.1 + retail ISO, A/UX
  at 32 MB). If a later seed meets timing it gets a confirmation run and
  ships instead; otherwise `ab1da889` ships with the CPU-clock note.
- **The user's "no video" (22:00)**: the MiSTer was power-cycled; the
  MENU core shows no picture. Established read-only: the FPGA is
  configured, the ADV7513 is PLL-locked and sees the sink (a Realtek
  device whose EDID prefers 1280x720), Main's startup log is clean, and
  the Mac core's picture is perfect through the same scaler and HDMI path
  (the boot screen and the Finder captured after a `load_core` at 22:15).
  Every menu-core capture on this box since at least 06:50 today, and one
  from 09-07, is noise: the menu's Linux-framebuffer path (the Linux
  image, Main and menu.rbf were all updated 09-07/08). Not the core, not
  tonight's work; the user has not yet said what the display shows with
  the Mac core up. Main is relaunched by hand (pid 1364, 22:13), stdout
  appended to **`/media/fat/nohup_video.log`** (the `Mac CD:` lines are
  there now, not in nohup.out).
- Remote mouse MOTION dies across every `load_core` and only a Main
  relaunch at the menu core revives it (event15 is MiSTer's own node; the
  mrext devices are event16-18; never restart the remote service). The
  p2c brief relaunches Main before every load and runs the player first.
- The A/UX shutdown "wedge" is the 128 MB RAM option (32 MB halts); the
  core's RAM decode is a flat power-of-two window with open bus above it.

## Do next, in order

1. Read the gate operator's report (`scratch/p2d/report.md`) and the
   seed-23 result. Timing met on 23 -> stage it (`scratch/stage_phase2b.sh`,
   rename `_phase2c_s24` to the seed) and run a confirmation gate (the
   player + 8.1 + A/UX) on it; otherwise the seed-21 build is the release
   if its gate passed.
2. Release phase 2: `releases/MacQuadra800_20260916_2.rbf` (or a 20260917
   name), the README row + section from `scratch/release_phase2_draft.md`
   (fill the fit numbers of the shipped seed, `__HW_81_REL__`, `__HW_AUX__`;
   three channel fixes; the CPU-clock note if marginal), `docs/area-budget.md`,
   the plan's D3 tick, commit. The user pushes.
3. Follow-ups: the menu-core picture (framework side); the 128 MB A/UX
   shutdown hang (a 64 MB run; the trace build
   `_Unstable/MacQuadra800_trace7_phase1.rbf`); Speedometer on an image that
   has it; the 8.1 boot freeze at the extension icons seen once at 08:10.

## Box (.143) state at 23:40 (before the p2d operator)

Core `_Unstable/MacQuadra800_phase2c_s24.rbf` at the Mac OS 8.1 halt
screen; Main pid 3365, stdout `/media/fat/nohup_video.log` (5,928 lines);
`.s0` Quad Squad (clean), `.s1` FreshTest, `.s4` the retail ISO; RAM 32 MB;
the A/UX image pristine; `AudioTest.cue/.bin` in `games/MacQuadra800/`;
`_Unstable/` holds `MacQuadra800_phase2c_s21.rbf` (`ab1da889`, the gate
candidate), `_phase2c_s24` (`a719e24f`), `_phase2b_s24` (`4bf9629c`),
`_phase2b_s23` (`0d374d4a`), `_phase2_s22` (`c2a902cb`), `_phase1_s21b`
(`1eae0fb7` = the release), `MacQuadra800_20260915.rbf`,
`MacQuadra800_20260908_3.rbf`, `MacQuadra800_trace7_phase1.rbf`. The
operator's report says where it left things.

## Rules (user)

Only the .143 box. One Quartus flow at a time (check `Get-CimInstance
Win32_Process` for `quartus*`). Hardware over the sim (short directed
benches only). Restore a damaged image from `backup/`; for A/UX never wait
for the fsck. A/UX gates at 32 MB. Opus operators for all guest driving
(resume the same agent on an HTTP 529). Commit as work lands, do not push.
Command = keycode 56 (Left Alt), Option = 125, `MISTER_HOST=192.168.99.143`.
Never reload a core while a guest runs unless it is provably dead. Edit
scripts go in `scratch/edit_*.py` via the Write tool (heredocs with `$`,
quotes or backslashes break).
