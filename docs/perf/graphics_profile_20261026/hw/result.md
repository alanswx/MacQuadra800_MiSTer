# Step 1 (VRAM read-cache RMW fix) vs baseline -- hardware A/B, 2026-10-26

Box: mister192 (10.0.2.192), via kvms CLI + mister_ws.py for buttons. Same session, same disk
(`TestImages/Dual040/QuadSquad8_dual.hda`, Mac OS 8.1), 32 MB (Speedometer Hardware Info: 32768K),
640x480. Candidate first, then baseline. Speedometer 4.02; PR Tests with Graphics only, Iter 1;
Color QuickDraw with all five depths checked, Iter 1 (the dialog defaulted to 16-bit only, so
the other four were ticked by hand on both bitstreams).

| bitstream | md5 | Graphics PR r1 / r2 / r3 | median | Mono s | 2-bit s | 4-bit s | 8-bit s | 16-bit s | boot | shutdown | visual anomalies |
|---|---|---|---|---|---|---|---|---|---|---|---|
| candidate `MacQuadra800_step1v2_rmw_261026.rbf` | ba716328da4fb7cf972e1040507d5e31 | 0.901 / 0.898 / 0.898 | **0.898** | 7.595 | 8.775 | 10.023 | **12.785** | 17.161 | OK | OK | none seen |
| baseline `MacQuadra800_base_a8ba3fa.rbf` | c6304fda0d823cfeda5783cb0b9f56b0 | 0.848 / 0.846 / 0.846 | **0.846** | 8.172 | 9.399 | 10.406 | **13.207** | 17.251 | OK | OK | none seen |
| delta (cand - base) | | | **+0.052 (+6.1 %)** | -0.577 (-7.1 %) | -0.624 (-6.6 %) | -0.383 (-3.7 %) | **-0.422 (-3.2 %)** | -0.090 (-0.5 %) | | | |

Color QuickDraw "Rat." column: candidate 0.909 / 0.870 / 0.867 / 0.828 / 0.791; baseline 0.845 / 0.812 / 0.836 / 0.802 / 0.787.

## Notes / oddities
- The baseline measured today is 0.846, **not** the 0.901 / 12.208 s that the handoff assigns to
  this build. The candidate's Graphics PR (0.898-0.901) matches the handoff's figure instead. Either the
  handoff numbers came from a different build, or something else (e.g. this disk/session state) differs.
  Within this session the A/B is clean: same disk, same settings, back to back.
- Run-to-run spread is tiny (0.003 candidate, 0.002 baseline), so the +0.052 is well outside noise.
- Visual: mid-test frames captured during every PR run and six frames during each Color run
  (`*_during*.png`); all show normal Speedometer drawing (lines, ovals, polygons, pattern fills,
  colour rects). The grey full-screen frame / half-redrawn desktop seen in some frames is the
  depth switch between Color tests and appears on the baseline too. Desktop redrawn cleanly after
  quitting on both (`cand_22_finder.png`, `base_19_finder.png`). No pixel dropouts, stale pixels or
  garbage seen on either bitstream. (Screenshots are spot samples, not every frame.)
- `k.sh load-core` failed (the Mac cannot ssh to 10.0.2.192 directly: publickey denied); the rbf was
  copied via misterubuntu (md5 verified on the box) and loaded with
  `echo load_core <path> > /dev/MiSTer_cmd`, only from the safe-to-switch-off screen.
- Clicks: mister_ws.py `mousebtn:left_down sleep:0.2 mousebtn:left_up` on one websocket (remote.log
  shows down and up as separate messages). Menus were opened as Mac OS 8 sticky menus (click title,
  verify highlighted row in a screenshot, click). Speedometer commands via Cmd-R / Cmd-G / Cmd-Q.
  The "Machine Record not saved" prompt on quit was answered No both times.
- Final state: box on "It is now safe to switch off your Macintosh" with the baseline core loaded.
  The candidate rbf is now also in /media/fat/_Development/.

# A/B #2 -- against the correct a8ba3fa build (md5 1880d854...)

The coordinator noted the A/B #1 baseline rbf (c6304fda) is not the build behind the handoff's
0.901. Rerun on the same box, disk, settings and method, later in the same session (~3:50-4:07 guest
time). Baseline = `misterubuntu:~/mister/q800_ddr3_vram/output_files/MacQuadra800.rbf`, copied to
`/media/fat/_Development/MacQuadra800_a8ba3fa_1880d8.rbf`, md5 checked on the box. Order: a8ba3fa
(3x PR + Color), then candidate (1x PR + Color, drift check). Each core loaded with /dev/MiSTer_cmd
only from the safe-to-switch-off screen. Color dialog: all five depths ticked by hand both times.
Screenshots are prefixed `ab2_`.

| bitstream | md5 | Graphics PR runs | median | Mono s | 2-bit s | 4-bit s | 8-bit s | 16-bit s | boot | shutdown | visual anomalies |
|---|---|---|---|---|---|---|---|---|---|---|---|
| a8ba3fa `MacQuadra800_a8ba3fa_1880d8.rbf` | 1880d854f5ba373080fabc95fc0a358d | 0.885 / 0.883 / 0.883 | **0.883** | 7.604 | 8.833 | 10.013 | **12.754** | 17.167 | OK | OK | none seen |
| candidate rerun `MacQuadra800_step1v2_rmw_261026.rbf` | ba716328da4fb7cf972e1040507d5e31 | 0.905 (1 run) | 0.905 | 7.576 | 8.723 | 9.967 | **12.706** | 17.079 | OK | OK | none seen |
| candidate in A/B #1 (for drift) | ba716328... | 0.901 / 0.898 / 0.898 | 0.898 | 7.595 | 8.775 | 10.023 | 12.785 | 17.161 | OK | OK | none seen |

Color "Rat." column: a8ba3fa 0.908 / 0.864 / 0.868 / 0.830 / 0.791; candidate rerun 0.912 / 0.875 / 0.872 / 0.834 / 0.795.

Delta, candidate vs a8ba3fa:
- Graphics PR: +0.015 (+1.7 %) using the A/B #1 candidate median of 0.898; +0.022 (+2.5 %) using the
  0.905 rerun. All four candidate runs (0.898-0.905) are above all three a8ba3fa runs (0.883-0.885).
- Color 8-bit: -0.048 s (-0.4 %) on the rerun, +0.031 s (+0.2 %) on the A/B #1 run. That is inside the
  run-to-run noise, so 8-bit shows no real change. The other depths are also within about 1 %.
- Candidate drift between A/B #1 and A/B #2: PR 0.898 median -> 0.905 (+0.007), 8-bit 12.785 -> 12.706 s
  (-0.6 %). That is small next to the +0.015-0.022 PR gap.

Notes:
- a8ba3fa measured 0.883 here, not the handoff's 0.901. Its 8-bit time (12.754 s) is also slower than
  the handoff's 12.208 s. So even the correct build does not reproduce the handoff's numbers on this
  box/disk/session.
- The c6304fda rbf from A/B #1 (0.846, 8-bit 13.207 s) is clearly a different, slower build than
  a8ba3fa/1880d8.
- Visual: six mid-run frames per Color run plus two per PR run (`ab2_*during*`) all show normal
  Speedometer drawing. The grey full-screen frame is the depth switch, and the partly drawn
  polygons are drawing in progress. The desktop redrew cleanly after quitting on both cores. No
  pixel dropouts, stale pixels or garbage were seen on either core.
- The guest menu-bar clock reads 3:55 on the candidate's boot after showing 3:57 at the a8ba3fa
  shutdown; the RTC appears not to run between core loads. Harmless.
- Final state: the box is on "It is now safe to switch off your Macintosh" with the candidate core loaded.

# A/B #3 -- step12 (VRAM read-cache + CPU store-path change) vs a8ba3fa

This run used the same box, disk (QuadSquad8_dual.hda), 32 MB, 640x480 and method as A/B #2, later in
the same session (guest clock about 5:20-5:37). The candidate was `MacQuadra800_step12_261026.rbf`,
copied via misterubuntu with its md5 checked on the box. The order was step12 first, then a8ba3fa. Each core was loaded with
/dev/MiSTer_cmd only from the safe-to-switch-off screen. Boot was sampled every ~7.5 s
(`ab3_*_boot_t*.png`). The Color dialog had all five depths ticked by hand both times. Each PR run got
four mid-run frames and each Color run sixteen (~2-3 s apart). Screenshots are prefixed `ab3_`.

| bitstream | md5 | Graphics PR runs | median | Mono s | 2-bit s | 4-bit s | 8-bit s | 16-bit s | boot | shutdown | visual anomalies |
|---|---|---|---|---|---|---|---|---|---|---|---|
| step12 `MacQuadra800_step12_261026.rbf` | ffc2fa767b7ae5eeef51a5d889b75b6b | 0.926 / 0.922 / 0.922 | **0.922** | 7.532 | 8.607 | 9.774 | **12.286** | 16.405 | OK, desktop ~75 s | OK | none seen |
| a8ba3fa `MacQuadra800_a8ba3fa_1880d8.rbf` | 1880d854f5ba373080fabc95fc0a358d | 0.893 / 0.890 / 0.891 | **0.891** | 7.619 | 8.847 | 10.001 | **12.778** | 17.183 | OK, desktop ~75 s | OK | none seen |
| delta (step12 - a8ba3fa) | | | **+0.031 (+3.5 %)** | -1.1 % | -2.7 % | -2.3 % | **-0.492 s (-3.9 %)** | -4.5 % | | | |

Color "Rat." column: step12 0.917 / 0.887 / 0.890 / 0.862 / 0.828; a8ba3fa 0.907 / 0.863 / 0.869 / 0.829 / 0.790.

Notes:
- Stability: step12 had no hang, freeze, bomb or error dialog anywhere in boot, 3x PR, Color, quit or
  shutdown.
- Boot: the two cores showed the same sequence at the same times (black to ~25 s, grey to ~40 s,
  "Mac OS / Starting Up" with extension icons at ~45-62 s, desktop at ~70-75 s). Nothing looked
  different on step12.
- Visual: all step12 mid-run frames show correct test drawing (patterned rects, ovals, polygons, orange
  and 16-bit gradient fills). Colours matched the same tests on a8ba3fa. The Hardware Information,
  Performance Test and Color Benchmarks windows and the desktop redrew cleanly after each depth switch and
  after quitting (`ab3_cand_19_finder.png`). Some frames show a test window half-filled (black or
  partly drawn polygon). That is a capture landing mid-draw, and the same kind of frame shows on a8ba3fa
  (`ab3_base_13_pr3_during_a.png`) and in A/B #2. No stale, missing or misplaced pixels, wrong colours
  or garbage were seen. The screenshots are spot samples (~76 frames per core), not every frame.
- a8ba3fa drift: 0.891 median here vs 0.883 in A/B #2. 8-bit 12.778 s vs 12.754 s.
- Final state: the box is on "It is now safe to switch off your Macintosh" with the a8ba3fa core loaded.
