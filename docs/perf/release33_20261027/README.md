# 33 MHz release candidate, 2026-10-27

Branch `pipelined-040-ddr3-vram`, source 0766b3f (dual-issue AP68040 at
33 MHz, DDR3 VRAM with the 3f50922 / 5bc9551 fixes, 16 KB caches, the four
DAFB monitors), the qsf recipe as committed (seed 41, 33/33/99).

| | |
|---|---|
| build | misterubuntu `~/mister/q800_rel33_20261027`, stamp 261027 (not yet shipped: last release 20261022) |
| fit | 37,659 ALMs (90 %), 332 / 553 M10K |
| timing | all met: HDMI +0.094, CPU +0.749 / +1.049, clk_vid +3.292 ns |
| rbf md5 | d6abd49ed007f8e708a06c4ac2bd7205 |

## Regression gate on this exact bitstream (mister192, 32 MB)

| check | result |
|---|---|
| Mac OS 8.1 (QuadSquad8_dual) | desktop in ~70 s, menu-bar clock ticking over 5 min idle (6:50 -> 6:53), Special -> Shut Down reaches "It is now safe to switch off your Macintosh." with the text complete (`rc_desktop.png`, `rc_shutdown.png`) |
| A/UX 3.1 (disposable copy of AUX_3_1_1GB) | multiuser Finder in ~100 s, CommandShell answers `uname -a` / `date` / `df` (`rc_aux_cmds.png`), `shutdown -h now` prints the usual port-mapper line and reaches "You may now switch off your Macintosh safely." after 119 s (`rc_aux_shutdown.png`) |
| CD audio (ToneTest.cue from `scripts/make_tonedisc.py` in slot 4) | the disc mounts as "Audio CD 1" on the 8.1 desktop (`rc_cd_desktop.png`); **play / pause / resume / stop by ear at the display: pending, the user's check** |

The same 8.1 and A/UX checks also passed on the four-monitor build earlier
the same day (`docs/perf/video_modes_20261027/`), whose RTL differs only by
0766b3f's cycle-identical stall-flag registering.

Once the CD check passes: copy the rbf to `releases/MacQuadra800_20261027.rbf`
and commit.
