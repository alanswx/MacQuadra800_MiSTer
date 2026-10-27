# Four-monitor DAFB build, 2026-10-27

Build of the working tree that added the 16" 832x624 and 21" 1152x870
monitors (`docs/video-modes.md`) on top of 430cb56 (16 KB caches, seed 41).

## Quartus (misterubuntu, `~/mister/q800_monitors_20261027`, seed 41)

| | |
|---|---|
| ALMs | 37,725 / 41,910 (90 %), +351 over the 430cb56 fit at the same seed |
| M10K | 332 / 553 (unchanged: the scanline cache already held 4 KB lines) |
| clk_vid constraint | 70.52 MHz (14.18 ns), the /10 static tap of the 704.9 MHz video VCO; derive_pll_clocks picked it up from the counter parameters |
| clk_vid slack | +3.308 ns (Fmax 91.98 MHz) |
| HDMI (pll_hdmi) | +0.509 ns |
| CPU clocks (emu\|pll) | +1.072 / +1.234 ns |
| rbf md5 | 5e996f1cc37f34f9e8525e46a105ff68 (`MacQuadra800_monitors_261027.rbf`) |

Timing met on every clock, so the build is release-grade as far as STA goes.

## Simulation

Verilator full-machine boots of Mac OS 8.1 (fast-boot ROM, 32 MB) with
`+monitor=2` (16") and `+monitor=3` (21").  The ROM's sense probe took both:
after it the DAFB stride register ($08, longwords) read

| monitor | stride written | row pitch | meaning |
|---|---|---|---|
| 13" (reference boot) | 0x100 | 1024 bytes | 640 px at 8 bpp, Apple's padded pitch; fb_base 0x1000 |
| 16" | 0x0D0 | 832 bytes | 832 px at 8 bpp; fb_base 0x80 |
| 21" | 0x090 | 576 bytes | 1152 px at the 4 bpp boot depth; fb_base 0x80 |

which match QEMU's macfb mode table for the same display types.

The first desktop frames (`sim_16in_832x624_oldvrammodel.png`,
`sim_21in_1152x870_oldvrammodel.png`) show the right geometry in their upper
part (full-width menu bar, icons placed at the right edge of 832- and
1152-pixel screens, clean right edges) but repeat a third of the way down:
the simulator's VRAM was still the old 308 KB block-RAM mapper with its
204 KB fold, which the hardware left behind with the DDR3 framebuffer.
`verilator/sim.v` now models the flat 1 MB, and the reruns
(`sim_16in_832x624.png`, `sim_21in_1152x870.png`) show complete, clean
832x624 and 1152x870 desktops in the core's own unscaled frame.

## Hardware (mister192, disk QuadSquad8_dual.hda, 32 MB)

### First build (md5 5e996f1c, monitors only)

All four settings booted to a usable desktop and shut down cleanly; the
Monitors & Sound panel offered B&W..Thousands at 832 x 624
(`hw1_16in_monitors_panel.png`) and B&W..256 at 1152 x 870
(`hw1_21in_monitors_panel.png`).  The run also surfaced two latent VRAM
faults, both reproduced in `tb_vram_ddr3` and fixed the same morning:

- 3f50922: a CPU write landing inside a split fill burst was covered by
  stale fill data, so the next read-modify-write erased it: letters missing
  from the shutdown screen after a 1152x870 session (`hw1_lost_glyphs.png`,
  1 shutdown in 5).  Test 16.
- 5bc9551: a line request arriving under a live prefetch burst restarted
  the bookkeeping, shifting the new line right by the burst's leftover
  beats: sheared "Starting Up" lines (`hw1_sheared_starting_up.png`, both
  640x480 boots), and most likely the "slight horizontal flickering while
  using the Mac" the user saw on this build (not reproduced on the fixed
  build, but not separately proven to be this fault).  Test 17, plus a 128-clock patience
  limit after which a prefetch goes ahead of the CPU, and the DAFB now
  requests the line 16 pixels in instead of at pixel 0 so the swap and the
  request cross into clk_sys further apart.

### Second build (md5 71363cdd, monitors plus both fixes, seed 41)

37,490 ALMs (89 %), 332 M10K, timing met on every clock (HDMI +0.170 ns,
CPU +0.788 / +1.231 ns, clk_vid +3.406 ns).  Sequence 13" (load_core) ->
16" -> 21" -> 13", each change through the OSD and "Reset and close OSD"
from the safe-to-switch-off screen:

| boot | desktop | idle frames with a one-frame glitch | sheared Starting Up | shutdown text |
|---|---|---|---|---|
| 13" 640x480 | `fix_13_desktop.png` | 0 of 170 | none | complete |
| 16" 832x624 | `fix_16_desktop.png` | 0 of 118 | none | complete |
| 21" 1152x870 | `fix_21_desktop.png` | 0 of 203 | none | complete |
| 13" after 21" | pixel-identical to the first 13" desktop | 0 of 194 | none | complete (`fix_13b_shutdown.png`) |

Every changed frame of each boot was recorded (`kvms frames`) and scanned
with `scripts/hw_transient_rows.py`, which flags rows that change for one
frame and return: on these boots it found only the animated watch cursor,
the Finder's zoom outlines, the ROM's boot icon and the mode switch.
Pointer-only movement at 640x480 showed nothing but the pointer.  At
1152x870, scrolling the Control Panels list eight rows down and nine back
up (17 VRAM-to-VRAM copies) left the window pixel-identical to the
original.  The short white bar under the Control Panels window's lower-left
corner in every desktop shot is the bottom of the "Fetch 3.0.3" icon's name
label, which the window covers; it is drawn before the window opens.
