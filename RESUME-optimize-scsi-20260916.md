# RESUME -- optimize-SCSI, hand-off 2026-09-16 ~18:40

Read this, then `docs/scsi-hps-offload-plan.md` sections 9 (checklist),
9b (phases) and the tail of 10 (log), then the memory notes
`pickup-2026-09-08`, `one-quartus-flow-at-a-time`, `prefer-hardware-over-sim`,
`mister-92-box` (off limits), `bash-tool-heredoc-backslashes`.

## Where things stand

- **Core branch `optimize-SCSI`** (unpushed; the user pushes). Tip = the WIP
  commit after `450445b`. Main fork branch
  `mac-ethernet-pr-with-SCSI-Optimizations` at `ae708d3` (unpushed);
  binary `898854ef` installed on .143; no Main change is pending.
- **Phase 1 RELEASED**: `releases/MacQuadra800_20260916.rbf` (`1eae0fb7`,
  seed 21, +0.247 ns, 38,128 ALMs), README row + section (`f33cde7`).
  Both gates passed on .143 (8.1 with the retail ISO incl. the Finder
  ejects and the OT ISO hot mount; A/UX at 32 MB). Speedometer not
  re-measured (the restored Quad Squad image has no Speedometer).
- **The A/UX shutdown "wedge" is the OSD RAM option**: at 128 MB A/UX 3.1
  hangs `shutdown -h now` after the port-mapper line (the kernel console
  keeps echoing at 1 bpp into the 8-bpp frame = the "streaks"); at 32 MB
  it halts in ~127-131 s. Six wedges at 128 MB across phase 1, 20260915,
  20260908_3, with/without a CD, without the slot-1 disk and with the Aug
  28 Main; every passing gate ever ran 32 MB. CLAUDE.md now says: A/UX
  gates at 32 MB. Why 128 MB hangs is an open follow-up (a 64 MB point,
  then what the shutdown touches above 64 MB; the SCSI_TRACE build
  `scratch/MacQuadra800_trace7_efcf5ffb.rbf` = phase 1 + tracer, staged as
  `_Unstable/MacQuadra800_trace7_phase1.rbf`, brief `scratch/w3/BRIEF.md`,
  decoder `scripts/scsi_trace.sh --decode-only`).
- **Phase 2 (playback on the ARM) is in RTL** (`d5442fe`): `cd_audio.sv` =
  header parse + $CC status poke + 5-block frame fetch + sample engine;
  transport CDBs forwarded; `scsi_cache` takes `e_blk_cnt`. Fit at seed 22
  meets timing: `c2a902cb`, 37,155 ALMs (89 %), clk_sys +0.232;
  `scratch/MacQuadra800_phase2_s22_c2a902cb.rbf`, staged on .143 as
  `_Unstable/MacQuadra800_phase2_s22.rbf`; qsf default seed 22.
  **Gate on .143** (`scratch/p2/`): 8.1 + retail ISO PASS, A/UX (32 MB)
  PASS, **the AppleCD Audio Player FAILS**: the PLAY forward lands (Main:
  `Mac CD: cmd 47 ... -> st 1 cur 0 stop 31652`), the counter runs ~7 s,
  then "The Apple CD-ROM drive is not responding" (2/2); the Quad Squad
  image was damaged in that session (error 41; restored; damaged copy
  `QuadSquad8_damaged2_20260916.hda`). The pure-audio test disc the
  operator built is `games/MacQuadra800/AudioTest.cue` + `.bin` (4 tracks
  of silence; it mounts as "Audio CD 1"; the PC Engine CHDs are
  mixed-mode and do NOT mount).
- **Diagnosis (mine, from the RTL) and the WIP fix**: the nexus's block
  requests (`io_rd_i`/`io_wr_i` on `!io_busy`) and the audio engine's
  (`ca_io_rd` on `ca_grant`) are decided in the same cycle from the same
  registered state; when both fire, the platform saw one merged slot-2
  request with the engine's address/block count, or the disk's request
  with `io_lba` at the frame window (a lost disk write = the error-41
  image), and the nexus's ack stayed masked by `ca_io_active` (= the
  driver's timeout). The WIP commit adds `eng_owns` in `ncr53c96.sv`
  (nexus priority: the engine's request is shown only once granted;
  `io_lba`, `io_blk_cnt`, the ack mask, the engine's ack/data strobes and
  the sector buffer's platform port follow it) and **T20** in
  `tb_ncr53c96.sv`, which forces the collision (PLAY, then a 4-block CD
  READ(10) on a 150,000-cycle device so a frame boundary falls inside).
  **T20 FAILS: byte 1024 (block 3 of the read) comes back stale (got 03,
  want 46), then the completion interrupt never comes; "collision cycles
  seen: 0"** -- so either the grant happens between blocks without a
  same-cycle collision and the nexus's next block is served while
  `eng_owns` is 1 (its data then never lands: `we_s = sd_buff_wr &&
  !eng_owns`), or the tb device model (one transaction at a time, samples
  `io_rd||io_wr` and `io_lba` in state 0) needs to honour the new
  ownership. Suspects, in order: (1) the grant condition
  `!eng_owns && ca_io_rd && !nexus_req && !io_ack_i && !io_ack_d` is met
  while the nexus's NEXT block prefetch is about to be raised (the nexus
  checks `!io_busy`, and `io_busy` includes `ca_io_active` = the engine's
  pending request, so it should wait -- verify `io_busy` really gates the
  prefetch at line ~819 and the flush at ~992); (2) the engine's `old_ack`
  now tracks the masked `ca_io_ack`, so `ack_fall`/`fr_act` timing shifted
  by a cycle against `eng_owns` release; (3) the sector buffer's port-S
  gate `!eng_owns` vs the cycle in which `eng_owns` is granted while the
  nexus's last words still stream. Run with `+define+TB_DEBUG` / the
  `[NCR]` trace (`make tb_ncr53c96`, then `./obj_dir_tb/tb_ncr53c96 | grep
  -a "io_rd+\|io_ack\|T20"`) and add `$display`s on `eng_owns` edges.

## Do next, in order

1. Make T20 pass (and everything before it: 477,900 checks). Then
   `--check`, then ONE fit (seed 22 first; the qsf default), one Quartus
   flow at a time on this machine (user rule).
2. Stage the fixed rbf on .143 (`_Unstable/MacQuadra800_phase2_<seed>.rbf`),
   gate with `scratch/p2/BRIEF.md` steps 1-4 (8.1 + retail ISO, A/UX at
   32 MB, the AppleCD Audio Player on `AudioTest.cue`: Play, Pause, Play,
   Next, Prev, scan, volume, Stop, with the Main `Mac CD: cmd` lines as
   evidence). Before the gate: the box's remote mouse MOTION is dead
   (buttons and keyboard work) -- at the MENU core, restart the mrext
   remote service (safe when no core runs) or reboot the MiSTer; note that
   a reboot returns Main's stdout to the serial console (inittab), so to
   see `Mac CD:` lines relaunch Main with `stdbuf -oL ... >> /media/fat/nohup.out`
   as the last operator did (see `scratch/p2/` and its final report in
   the plan log 18:15).
3. Release phase 2 (README row + section: md5, seed, slack, ALMs 37,155,
   the CD target 1,639, "requires Main `ae708d3`+", the Audio Player
   evidence, the 32 MB note) and update `docs/cdrom.md` / `area-budget.md`
   with the fitted numbers (already there for seed 22).
4. Follow-ups: the 128 MB A/UX shutdown hang (64 MB point; trace); the
   unexplained one-in-three 8.1 boot freeze at the extension icons seen
   at 08:10 (not reproduced since); Speedometer on a Quad Squad image that
   has it (the .92 image had it -- but .92 is off limits; ask the user).

## Box (.143) state at hand-off

MENU core; Main `898854ef` (relaunched by hand with `stdbuf -oL`, stdout
appended to `/media/fat/nohup.out`); `.s0` Quad Squad (restored 18:13,
clean), `.s1` FreshTest, `.s4` retail ISO; **RAM option 32 MB**
(`MacQuadra800.cfg.bak128` = the 128 MB original); A/UX image pristine;
`_Unstable/`: `MacQuadra800_phase1_s21b.rbf` (1eae0fb7 = the release),
`MacQuadra800_phase2_s22.rbf` (c2a902cb), `MacQuadra800_20260915.rbf`,
`MacQuadra800_20260908_3.rbf`, `MacQuadra800_trace7_phase1.rbf`;
`/media/fat/MiSTer.aug28_d6d63ec4` (the .92 Main, staged, not needed);
`games/MacQuadra800/AudioTest.cue/.bin`; remote mouse motion dead.

## Rules (user)

Only the .143 box. One Quartus flow at a time. Hardware over the sim
(short directed benches only). Restore a damaged image from `backup/`;
for A/UX never wait for the fsck, restore instead. A/UX gates at 32 MB.
Opus operators for all guest driving (they hit HTTP 529 twice today;
resume the same agent id, or spawn a new one with the brief). Commit as
work lands, do not push. Command = keycode 56. Edit scripts go in
`scratch/edit_*.py` (heredocs with `$` or quotes break).
