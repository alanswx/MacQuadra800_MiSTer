# RESUME -- CD audio on the .143 MiSTer, hand-off 2026-09-17 ~09:55

Read this, then `RESUME-optimize-scsi-20260916.md` (the phase-2 release and
its two RTL fixes), the plan log tail in `docs/scsi-hps-offload-plan.md`
(the 02:05 entry: the mis-linked Main), and the memory notes
`main-wsl-stale-objects`, `pickup-2026-09-08`, `prefer-hardware-over-sim`,
`opus-operator-for-mister`, `mister-92-box` (off limits).

## The situation

The user, testing by eye and ear on the display for the first time,
reports: with a "regular bin/cue" audio disc **no sound and an error**.
Screenshot `scratch/cdbin/01_user_error.png` (09:46): the AppleCD Audio
Player with **"The Apple CD-ROM drive is not responding"**, the playlist
showing Track 4 02:02, Cancel button, the Mac OS 8.1 desktop behind.

Facts read from the box at 09:46 (read-only):

- **The loaded bitstream is NOT the release.** Main's cmdline says
  `/media/fat/_Unstable/MacQuadra800.rbf`, md5 **`512cd4f8`** = the Sep-8
  "build M" (pre-offload: the playhead still in the FPGA, and it carries the
  2026-09-02 `abort_nexus` discard bug that this exact dialog comes from).
  The release, `releases/MacQuadra800_20260916_2.rbf` = `ab1da889`, is on the
  card as **`_Unstable/MacQuadra800_phase2c_s21.rbf`** (md5 verified). The
  generic name under `_Unstable/` is a trap: it points at the old build.
- **The disc in slot 4 is `games/MacQuadra800/AudioTest.cue`** -- the
  operator's four tracks of SILENCE (7:02). Hearing nothing from it is
  expected; it is the only CUE/BIN on the card. A real audio CUE/BIN (or a
  CHD with audio tracks; CHD CD-DA is byte-swapped by Main, see the answer
  in the chat log) is needed for a listening test.
- Main is the clean build **`431da61a`** (pid 1399, started by inittab after
  the user's reboot, stdout -> `/dev/console`, so its `Mac CD:` lines of
  this boot are NOT captured anywhere). The menu shows on HDMI with it: the
  user's black-menu problem was the mis-linked 16-Sep Main binaries (stale
  28-Aug `video.cpp.o` after `cfg.h` changed), fixed by
  `scripts/build_main_wsl.sh` (clean builds) -- commits `5350b9a`, `5e492a0`.
- Slots: `.s0` Quad Squad, `.s1` FreshTest, `.s4` AudioTest.cue. RAM 32 MB.
  The guest is RUNNING (the Finder, the player open with the dialog).

## What to do next, in order

1. **Do not reload anything under the running guest.** The user shuts the
   Mac down (Special -> Shut Down, or the Cancel button then Special), or an
   operator does it with `scripts/mac_shutdown.sh` after a fresh screenshot.
2. Get the `Mac CD:` lines captured for the next test: at the halt screen,
   `load_core /media/fat/menu.rbf`, then relaunch Main with its stdout in a
   file (the recipe in `scratch/p2d/BRIEF.md`, "fact 1": `killall MiSTer`,
   `cd /media/fat && nohup stdbuf -oL /media/fat/MiSTer /media/fat/menu.rbf
   >> /media/fat/nohup_video.log 2>&1 </dev/null &`). This also revives the
   remote mouse motion for an operator. The user with a real mouse does not
   need it, but the log does.
3. **Load the release**: `load_core /media/fat/_Unstable/MacQuadra800_phase2c_s21.rbf`
   (or from the OSD, the `_phase2c_s21` file -- NOT `MacQuadra800.rbf`).
   Consider first installing the release under the generic name so the
   obvious OSD choice is right:
   `cd /media/fat/_Unstable && mv MacQuadra800.rbf MacQuadra800_20260908_M_512cd4f8.rbf && cp MacQuadra800_phase2c_s21.rbf MacQuadra800.rbf`
   (a file copy; safe at the menu or a halt screen).
4. Repeat the user's test on the release: AudioTest.cue mounts as "Audio CD
   1"; the player's counter must run (the p2c/p2d gates: Play, Pause,
   Next/Prev, scan, volume, Stop all worked, 14 min, on the mis-linked Main
   whose Mac objects were current). If it fails on the clean Main `431da61a`
   too, read the captured `Mac CD:` lines: the 47/4B/CD/01 forwards prove
   the ARM side; a missing `cmd 47` means the forward never reached Main.
5. For SOUND: put a real audio CUE/BIN (or an audio CHD) in slot 4 and
   listen (continuity, pitch, the volume slider). The engine's cadence and
   frame path have never been heard on this core; the 2352-byte frames come
   from Main's next-frame window at 75 Hz. Underrun forensics live in the
   engine (`dbg_cdur`: starvation entries / clocks) if audio stutters.
6. Then the release entry gets the confirmed-by-eye/ear lines and the user
   pushes both branches (core `optimize-SCSI`, Main fork
   `mac-ethernet-pr-with-SCSI-Optimizations`; the shipping Main is
   `431da61a`, README corrected).

## Rules (user)

Only the .143 box. One Quartus flow at a time. Never reload a core while a
guest runs unless it is provably dead (screenshot first, READ it). Opus
operators for guest driving (they cannot hear audio -- the user can).
Commit as work lands, do not push. Command = keycode 56, `MISTER_HOST=
192.168.99.143`, `MSYS_NO_PATHCONV=1`. Edit scripts go in `scratch/edit_*.py`.
A/UX gates at 32 MB. Restore damaged images from `backup/`.
