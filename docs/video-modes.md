# DAFB monitors: 13" 640x480 and 12" 512x384

The core scans out one of two built-in Quadra 800 monitor shapes, chosen by
the OSD's "Monitor (on reset)" option and latched under reset in
`MacQuadra800.sv` (`mon_12in`), the same way the RAM size is.  The ROM reads
the DAFB monitor-sense lines once during its boot probe and QuickDraw lays
out for that geometry, so a live switch would only confuse a running guest.

| monitor | sense code | sense read (`$1C`, block 0) | active | frame | dot clock | refresh |
|---|---|---|---|---|---|---|
| 13" RGB (Apple High-Res) | 6 | `001 \| ~driven` | 640x480 | 800x525 | 25.175 MHz | 59.94 Hz |
| 12" RGB | 2 | `101 \| ~driven` | 512x384 | 640x407 | 15.664 MHz | 60.14 Hz |

The sense answer is QEMU macfb's "normal sense" formula,
`(~code & 7) | (~driven & 7)`; the codes are MAME `dafb.cpp`'s table (Apple
TN HW26).  The 12" timing is the 512-active shape MAME uses and MacLC's
`maclc_v8_video.sv` 12" table (sync 528-576 / 385-388); the real DAFB drives
15.6672 MHz, the PLL's nearest integer divider gives 15.664.

## Pixel clock

`rtl/pll_video.v` is MacLC's runtime-reconfigurable PLL: one output clock,
whose C0 divider is retargeted through `sys/pll_cfg` (the ao486 pattern)
from /28 to /45 with the 704.9 MHz VCO untouched.  A clock mux is not an
option because `sys_top` feeds `CLK_VIDEO` into its own clock-select blocks,
which require a raw PLL output (Fitter Error 15836).

Two things about the FSM in `MacQuadra800.sv` matter:

- The static PLL configuration is the 13" divider and the FSM's change
  detect inits to it, so a 13" boot performs **no** reconfig.  MacLC's first
  pixel-clock build retargeted at boot and the PLL unlock/relock glitched
  `CLK_VIDEO` while the HPS was mounting images (BERR storm, hard wedge).
- The retarget never drops PLL lock, so without help the scanout would step
  to the new rate mid-frame; Main's `vsync_adjust` measures one chimera
  frame and latches an out-of-spec HDMI mode.  `pix_quiet` holds the video
  reset from retarget-pending until ~84 ms after the FSM consumed it, so a
  change presents as a clean blank-and-return.

`MacQuadra800.sdc` constrains `clk_vid` at the derived 25.175 MHz; the 12"
rate is slower, so STA covers both.  A faster monitor (Portrait, 21") would
need the static configuration moved to the fastest divider first.

## Scanout and VRAM

`rtl/dafb.sv` keeps one pixel per `clk_vid`; the H/V constants became wires
selected by a 2FF-synced copy of `mon_12in`.  The Swatch timing registers
the ROM programs (`hparam`/`vparam`) are stored for readback but do not
drive the counters.

VRAM needs nothing: 384 rows of whatever pitch the ROM programs fit the
existing mapper in `MacQuadra800.sv` (a 1024-byte pitch compacts to the 640
visible bytes per row, anything narrower maps linearly).

## Verifying

Both guests at 13" first (no regression), then switch the OSD option, reset,
and confirm the ROM picks 512x384 (the Monitors control panel offers only
that resolution, as on a real 12" RGB) and the HDMI output shows a
`512 x 384` mode in the Main's log (`INFO: Video resolution: 512 x 384`).
The Verilator sim ties `mon_12in` to 0.
