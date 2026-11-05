# Handoff: lean DDR3 core at 54 MHz, two video bugs found — 2026-11-05

## Resume here

Branch **`dual-memory-ddr3-lean`** (pushed to `alanswx`; never `origin`).
Head at handoff: the pixel-clock retarget check (`e960c5d`), its seeds
(`74fb539`), and the docs of this handoff.  Clock set 54/27/81 MHz
(`CLK_54_27_81`, CPU 2:1), built with `MHZ=54 sh scratch/hw/fit.sh TAG SEED
COMMIT` on misterubuntu (add `MACRO="DIAG_COUNTERS=1"` for the diagnostic
build; wait with a loop like the scratchpad `waitn.sh`: it polls for
`families.txt` in `~/mister/q800_TAG_*`).

The question this branch answers (user, 2026-10-30): can the DDR3 video
(16-bit colour, the 16"/21" monitors) come back while the core stays near
the dual-memory checkpoint's 84-86 %?  Answer so far: **88 %** (36,991 ALMs
with the fixes below), 1,700 ALMs above the checkpoint and 1,400 below the
20261027 release core at the same clock.

**Waiting on hardware.**  Three builds of `e960c5d` are on mister192 in
`/media/fat/_Development/`; the user loads cores themselves:

| file | build | timing | what it shows |
|---|---|---|---|
| `Q800_diag2_s41.rbf` (6963acdc) | e960c5d + `DIAG_COUNTERS`, seed 41 | all met | clk_vid = 25,175,000 and the retry count (`retries=` in `diag_read.py`) |
| `Q800_pixfix_s70.rbf` (a2792d8c) | e960c5d, seed 70 | all met, CPU +0.495 | the real test: seed 70 was slow on every earlier load; PR Graphics should be ~1.27 |
| `Q800_pixfix_s55.rbf` (40235aa8) | e960c5d, seed 55 | all met, CPU +0.339 | like-for-like control |

Read the counters with `ssh misterubuntu 'ssh root@10.0.2.192 "python3
/media/fat/diag_read.py 10"'` (one row per second; read-only, safe under a
running guest).  The plain builds have no counters.

## What was found

1. **Horizontal lines: the DMA-take race** (fixed in `3b1761d`).  In
   vram_ddr3's S_IDLE a pending line-DMA burst could issue on the clock
   `dma_take` restarted the line, with the old line's `dma_cur_addr`, and
   land 32 beats of the wrong row in slots 0-31 of the new line: the left
   fifth of a random 16-bit row, a different one each frame, on some
   placements.  `verilator/tb_vram_scan.sv` reproduces it (75 head-bad
   lines over 54 seed/traffic mixes before, none after, same throughput).
2. **Slow graphics on some seeds: the pixel clock left at 70.49 MHz**
   (fixed in `e960c5d`).  pllv powers up at the 21" divider so STA covers
   every monitor, and is retargeted at boot for the others.  On the slow
   loads (seeds 41 and 70 at 54 MHz, several RTL versions, every reload)
   the retarget write was taken and the PLL did not move: a 13" screen
   scanned 168 times a second, the line DMA took ~70 % of the DDR3 port's
   clocks instead of ~27 %, and VRAM drawing queued behind it -- PR Graphics
   1.17 instead of 1.27, every colour depth 8-10 % slower, integer and FPU
   untouched, the picture normal (the HDMI scaler hides the rate).  Found
   with the `DIAG_COUNTERS` build (`e99494d`): seed 55 counted clk_vid
   25,175,000/s, seed 70 70,490,000/s.  Why the write does not take on
   some placements is **still unknown** (the framework's trimmed
   `sys/pll_cfg/pll_cfg_hdmi.v` driving a second PLL, the DPRIO path);
   the fix makes it not matter: `pix_reconfig` measures clk_vid/8 against
   CLK_50M over 1.31 ms once idle and repeats the write sequence while the
   rate is more than 1/16 off nominal, at most 15 times.  The C0
   synchronisers now power up at the static word, not zero.  Bench:
   `verilator/tb_pix_retarget.sv` (a copy of the block; regenerate it if
   the block changes).
3. **The line DMA fetches a fixed 2,048 bytes a line** (8 bursts of 32
   beats: the count follows the stride, not the depth), about 27 % of the
   DDR3 port at 13" 60 Hz whatever is on screen.  Not a bug, but the
   obvious next graphics lever: fetch only `width x depth` bytes.

**Both bugs are in the shipped 20261027 release** (`ff42944`, branch
`pipelined-040-ddr3-vram`): the same `dma_late` branch in
`rtl/vram_ddr3.sv` and the same unchecked retarget.  Whether the shipped
rbf's pixel clock is right was never measured; a `DIAG_COUNTERS` build of
it, or the two fixes ported and re-fitted, would tell.  Porting both to
the release line is the main open decision for the user.

## Results

Speedometer tables, counters and screenshots:
`docs/perf/ddr3_lean_20261030/speedometer_hw.md`; fits:
`docs/perf/ddr3_lean_20261030/README.md`; every seed is in the `.qsf`
comment block.  PR Graphics, Performance Test alone unless noted:

| build | seed 55 | seed 70 | seed 41 |
|---|---:|---:|---:|
| b06c1b6 step 1 (release vram_ddr3, 8 KB caches) | 1.272 (all windows) | 1.169 (lines) | |
| f594bb5 step 2 (FIFO rework, in logic) | 1.248 (all windows), 1.269 | | lines |
| 3b1761d DMA-take fix | | 1.126 (all windows), 1.173 | |
| e99494d diag counters | 1.238 (all windows) | 1.173 (clk_vid 70.49 MHz) | |
| e960c5d pixel-clock check | pending | pending | pending (diag) |

## Hardware state at handoff

- mister192 (10.0.2.192, through misterubuntu; direct ssh fails).
  Screenshots with `sh scratch/hw/k.sh screenshot <png>` (kvms).  Last
  seen: `Q800_diag_s70.rbf` on the Mac OS 8.1 desktop after a Performance
  Test (`TestImages/Dual040/QuadSquad8_dual.hda` in slot 0).  **Look at
  the screen before anything**; only the user loads cores.
- Main was restarted by init (the MiSTer was rebooted on 2026-10-31 at the
  user's OK after a hand-launched logging Main); `MiSTer.ini` is back to
  `video_info=0` (md5 matches `MiSTer.ini.bak_videoinfo`).  The release
  recipe sets `MISTER_DISABLE_VIDEO_CALC`, so Main never reports video
  timing for this core; the `video_info` popup cannot work.
- `/media/fat/_Development/` holds the kept cores (release54, dualmem54,
  step1 s55, A step2 s55, B step1 s70, C fix s70, diag s41/55/70, diag2
  s41, pixfix s55/s70); 34 older Quadra cores are in `_Development/old/`.
- **Never touch the other MiSTer (.92)**, not even read-only.
- The local Mac disk is nearly full: avoid long `kvms frames` captures
  (~750 KB a frame).

## Next

1. The three hardware runs above.  If `Q800_pixfix_s70` scores ~1.27 and
   the diag build counts 25,175,000, the branch is a release candidate at
   88 %: then the full gate (CLAUDE.md: Mac OS 8.1, A/UX 3.1 at 32 MB, CD
   audio by ear by the user), and the user's call on shipping at 54 MHz.
2. Ask the user about porting `3b1761d` and `e960c5d` to the release line.
3. Optional: the root cause of the failed retarget (a diag build that
   records the reconfig core's state, or a full `pll_cfg` instead of the
   trimmed HDMI one), and the depth-sized line DMA.
