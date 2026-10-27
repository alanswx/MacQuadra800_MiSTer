# Hardware A/B brief: Step 1 (VRAM read-cache RMW fix) vs baseline

Goal: Speedometer 4.02 Graphics PR and Color QuickDraw 8-bit on the DDR3-VRAM
dual core, candidate vs baseline, same box, same disk, same session.

Box: mister192 = root@10.0.2.192, reached only via `ssh misterubuntu "ssh root@10.0.2.192 ..."`
for files; ALL screen/mouse/keyboard via the kvms CLI wrapper from the Mac:
`sh scratch/hw/k.sh <cmd>` (status, screenshot <png>, load-core, key, type,
mouse move/down/up/click, wait-for-change). Clicks must be a continuous
down / hold / up gesture (a down+up sent together wedged the Finder on
2026-10-22); if `mouse down` releases immediately, use
`/usr/bin/python3 scripts/mister_ws.py --host 10.0.2.192 --interactive`.

Guest: Mac OS 8.1 `games/MacQuadra800/QuadSquad8.hda` (slot 0 via
`/media/fat/config/MacQuadra800.s0`), OSD RAM 32 MB, Ethernet Off, 13in 640x480
(the settings the 2026-10-24 sweep used). Disposable image: on 2026-10-24 a copy
`TestImages/Dual040/QuadSquad8_dual.hda` was used; reuse it or copy afresh and
point `.s0` at it. Never deploy or load_core while a guest is up: only from the
"safe to switch off" screen or the MiSTer menu.

Bitstreams (in /media/fat/_Development/ on the box):
- baseline: `MacQuadra800_base_a8ba3fa.rbf` = a preserved copy of the box's
  `MacQuadra800.rbf` of 2026-10-26 14:55 (md5 c6304fda0d82; the build the
  handoff's 0.901 / 12.208 s numbers are believed to come from). Load it with
  `sh scratch/hw/k.sh load-core <local copy>` or by the MiSTer OSD.
- candidate: `MacQuadra800_step1v2_rmw_261026.rbf`, on this Mac under
  `~/dev2/q800_prof_20261026/hw/`; `sh scratch/hw/k.sh load-core <path>` copies it
  to /media/fat/_Development and loads it in one step (md5 in `hw/md5.txt`).

Per bitstream, from the shut-down screen:
1. `k.sh load-core` the rbf (or the mrext `load_core`), wait for the 8.1 desktop
   (clock ticking), screenshot `boot.png`.
2. Open Speedometer 4.02 (desktop icon, double-click), dismiss the splash and
   the registration "Not Yet". Tests menu -> Performance Rating; in the PR
   Tests dialog leave only Graphics checked, Iter 1, OK; wait; screenshot the
   result. Repeat 3 times, record each Graphics PR.
3. Tests menu -> Color QuickDraw (the Color Benchmarks window); run it once
   at the default depth set; record the five times (Monochrome .. Sixteen bit),
   screenshot.
4. Special -> Shut Down via the continuous click gesture; confirm the
   "safe to switch off" screen; screenshot.
Then the other bitstream, same steps. Do candidate first, then baseline (the
baseline numbers exist already; its rerun is the same-session control).

Record: `docs/perf/step1_rmw_20261026/{candidate,baseline}/*.png` and a
`result.md` with a table: bitstream, Graphics PR x3 + median, Color 8-bit s,
the other four depths, boot OK, shutdown OK. Also note anything odd (dialogs,
artifacts, hangs). Report back the medians and whether the screen ever showed
pixel dropouts or garbage (the read cache change could in principle serve a
stale byte; the testbench says no, the screen is the final check).
