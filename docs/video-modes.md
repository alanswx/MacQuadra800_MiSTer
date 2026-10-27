# DAFB monitors: 640x480, 512x384, 832x624, 1152x870

The OSD's "Monitor (on reset)" picks which monitor the ROM finds on the
DA-15 at boot.  A real Quadra 800 samples the DAFB sense lines once, in the
ROM's boot probe, and QuickDraw lays out for that geometry, so the choice is
latched under reset like the RAM size.  Since 2026-10-27 there are four:

| OSD | monitor | sense | active | frame | dot clock (C0) | refresh | depths with 1 MB VRAM |
|---|---|---|---|---|---|---|---|
| 0 | 13" RGB | code 6 | 640x480 | 800x525 | 25.175 MHz (/28) | 59.94 Hz | 1..8 bpp, 16 bpp |
| 1 | 12" RGB | code 2 | 512x384 | 640x407 | 15.664 MHz (/45) | 60.14 Hz | 1..8 bpp, 16 bpp |
| 2 | 16" RGB | extended 0x2D | 832x624 | 1152x784 | 54.223 MHz (/13) | 60.04 Hz | 1..8 bpp, 16 bpp (1,038,336 bytes) |
| 3 | 21" RGB | code 0 | 1152x870 | 1296x906 | 70.490 MHz (/10) | 60.03 Hz | 1..8 bpp (1,002,240 bytes) |

The frames are shaped for about 60 Hz rather than the real monitors' 66.7,
74.6 and 75 Hz because the HDMI scaler and Main's `vsync_adjust` want that;
the 13" already used VGA timing instead of Apple's 30.24 MHz for the same
reason.  The dividers are the integer taps of the one 704.9 MHz VCO in
`rtl/pll_video.v`; the frame totals were then chosen to land near 60 Hz.

## Where it lives

- `rtl/dafb.sv`: the `mon_sel` input picks the sense-register answer and the
  scanout timing table.  The sense register reads 1 for a line that is LOW: a
  standard monitor grounds a fixed pattern (code = the lines left high), an
  extended-sense monitor leaves all three open and ties two through diodes,
  so a line the ROM drives low pulls its partner low as well.  The 16" ties
  sense 0 to sense 2; the ROM drives each line in turn and reads the other two
  (Apple TN HW30), which spells Apple's extended code 0x2D.  QEMU's
  `macfb_sense_read` is the same model and was the reference.
- `MacQuadra800.sv`: `status[10:9]` is latched into `mon_sel` under reset; the
  `pix_c0` table retargets the video PLL's C0 counter through `sys/pll_cfg`
  (a C0 retarget never drops lock).  `pix_quiet` holds the scanout in reset
  for ~84 ms around a retarget so Main's `vsync_adjust` never measures a
  chimera frame.
- `rtl/pll_video.v`: the STATIC configuration is the fastest tap, /10 =
  70.49 MHz, because `derive_pll_clocks` constrains clk_vid at the static
  rate and every runtime retarget must be slower for STA to cover it.  So a
  21" boot performs no retarget and every other boot retargets once, under
  reset, before the ROM runs (the 12" option has booted that way since it
  shipped).  A `VIDEO_512_OFF` build (no reconfig block) keeps /28 as the
  static tap and is fixed at 13".
- `rtl/vram_ddr3.sv`: nothing to change.  The ping-pong scanline cache holds
  4096 bytes per line (1024 x 32-bit words), enough for 1152 px at 8 bpp, 832
  or 1024 px at 16 bpp and 640 px at 32 bpp; the line DMA fetches
  ceil(stride / 256) 32-beat bursts and the 1 MB wrap keeps every row inside
  the framebuffer.  The CPU snoop into the live line buffers uses the stride
  too.
- `verilator/sim.v`: `+monitor=N` picks the monitor (the sim scans out on
  clk_sys, so only the picture changes, not the sim's frame rate);
  `sim_main.cpp` sizes its frame capture from the same plusarg.

## What was checked

- Verilator full-machine boot of Mac OS 8.1 with `+monitor=2` and `+monitor=3`
  (screenshots under `docs/perf/video_modes_20261027/` once taken).
- Quartus (seed 41, `docs/perf/video_modes_20261027/`): 37,725 ALMs (+351
  for the sense table, the frame table and the 11-bit counters), M10K
  unchanged; the clk_vid domain is now constrained at 70.52 MHz (14.18 ns)
  instead of 25.175 MHz and closes with +3.3 ns (Fmax 92 MHz); HDMI +0.51 ns,
  CPU clocks +1.07 / +1.23 ns.
- Hardware (mister192, `docs/perf/video_modes_20261027/`): boot on each
  monitor, desktop usable, Monitors & Sound offers up to Thousands at
  832 x 624 and up to 256 at 1152 x 870, Shut Down clean, no one-frame
  glitches on idle desktops, and a 21" -> 13" change gives a desktop
  pixel-identical to a cold 13" boot.  The first build's run found two
  VRAM faults (3f50922, 5bc9551) that every monitor could hit under load.

## Not done / ideas

- SVGA 800x600 (VGA sense 0x17 plus the Monitors control panel's resolution
  switch) and the 15" Portrait (640x870, code 1 / 5): the ROM supports them,
  the DAFB table does not yet.
- The Swatch timing registers the ROM programs are stored but not
  interpreted; the frame comes from the OSD choice.  Reading the ROM's
  horizontal/vertical parameters back would let the core follow the guest's
  own mode switches (the Monitors control panel on a multiscan sense code).
