# Resume — CD-ROM boot, Alan's newer CPU tweaks, and the 512x384 mode

Paste this as the opening message of a new session. Repo on `main`, HEAD
`469cad5`, **9 commits ahead of origin/main, not pushed**. Read `CLAUDE.md`
first (build/deploy/sim commands and the hardware binding rules). All four
tasks below are open; they are independent, do them in any order.

**Binding rules that have cost data (unchanged):** never `load_core`/deploy
while a guest is booting or running — shut it down first (Special → Shut Down,
or `shutdown -h now` in an A/UX CommandShell) and confirm the "safe to switch
off" screen with a fresh screenshot you actually LOOK at before deploying.
Judge liveness by `/proc/$(pidof MiSTer)/io` deltas, never `.hda` mtime.
Do not edit the `.qsf`/`.qip` while a Quartus flow is running (it rewrites the
qsf and the fitter dies). Another session builds `sgiindy` on this box — match
a `quartus_*` process's command line to `MacQuadra800` before killing it, and
don't launch a fit while a sgiindy one is listed. Build from Git bash
(`C:\Program Files\Git\bin\bash.exe`), launched detached via PowerShell
`Start-Process` so a tool timeout can't kill Quartus mid-fit.

Current bitstream on the MiSTer: `MacQuadra800.rbf` md5 `0c095133…` (the
"cdC" build: three SCSI targets + CD audio engine, seed 19, 86 % ALMs,
+0.185 ns). It boots Mac OS 8.1 to the Finder normally with **no** CD
mounted (76 MB read). Disks in `/media/fat/games/MacQuadra800/`:
`QuadSquad8.hda` (Mac OS 8.1, slot 0 `.s0`), `HD60_512-AUX3.1-Installed.hda`
(A/UX 3.1), `Open Transport 1.3.1.iso` (a flat HFS CD test image),
`NetBSD-11.0-mac68k.iso`. Slot-4 CD mount memory is `config/MacQuadra800.s4`
(currently renamed to `.s4.off`; rename back to arm it).

---

## 1 + 2. CD-ROM does not work on hardware (THE priority — it's how OSes install)

**User report (2026-09-03):** the MiSTer main deploy worked; but a CD is not
mounted **at boot** (core hangs grey with a disc in slot 4) **nor from within
a booted Mac OS** (no CD icon appears). The user has now installed the Main
fork with `macquadra800` CD support, and it still fails, so this is NOT just
"stock Main doesn't translate" — there is a real bug in our path. The user
believes both symptoms are the same underlying issue. Likely so: the CD target
is never presenting as a working device to the guest.

### What is known to work
- `tb_ncr53c96` 8673 checks, 0 failures — including T16 (CD INQUIRY, no-disc
  sense, READ CAPACITY, 2048-byte READ mapped to HPS blocks 4-7) and T17
  (Apple `$C1` READ TOC header/lead-out/track-1 and `$CC` AUDIO STATUS via
  the `cd_audio` engine).
- The **full-machine Verilator sim boots through the CD scan** with a disc
  mounted: `bash scripts/sim_wsl.sh build`, then run with `--cd <iso>` (see
  `verilator/sim_main.cpp`; `~/MacQuadra800/verilator/cd.iso` was staged from
  `Open Transport 1.3.1.iso`). The ROM's `READ(6)` block 0 to ID 3 returns
  2048 bytes as HPS blocks lba 0-3, completes to STATUS/ICCS, and boot moves
  on to the disk at ID 0. That trace is the reference for "correct."
- With no CD mounted the same bitstream boots Mac OS fine — so the multi-target
  SCSI rewrite did not regress the disk path.

### The gap: sim passes, hardware hangs. Prime suspects, in order
1. **The mount announce/replay to the machine.** `MacQuadra800.sv` was
   rewritten so `ncr53c96` gets a 3-bit `img_mounted` and one 64-bit
   `mach_img_size`, replayed **one target per clock** after every reset
   (`main_mount = {img_mounted[VD_CDROM], img_mounted[VD_DISK1],
   img_mounted[VD_DISK0]}`, the `mount_valid`/`mount_replay`/`mach_img_mounted`
   FSM). The sim exercises `img_mounted` bits directly; hardware goes through
   this FSM. **Check first:** does `img_mounted[2]`'s pulse actually reach
   `ncr53c96` and set `tgt_mounted[2]` / `tgt_blocks[2]` on hardware? The
   size mapping is `img_size[40:9]` (512-byte blocks). A CD ISO's size in
   2048-byte logical blocks is `img_size[42:11]` — the CD engine's
   `img_blocks` is `tgt_blocks[2]` which is 512-byte blocks, and READ scales
   by 4; make sure that is consistent end to end.
2. **The fastboot ROM (sim) vs the real ROM (hardware) differ.** The sim uses
   `quadra800-fastboot.rom.hex`; hardware runs the real ROM's full SCSI bus
   scan. Re-run the sim with the **pristine** ROM (`+rom=quadra800.rom.hex`)
   and `--cd` to see if the real ROM's scan path hangs in sim too — if it
   does, it's debuggable offline against `docs/scsi/` + QEMU.
3. **The hardware SCSI tracer.** `SCSI_TRACE=1` in the qsf (rebuild) dumps the
   protocol out the modem port; `scripts/scsi_trace.sh`. Capture the boot scan
   with a CD mounted and compare to the sim trace above (which is the golden
   sequence). The hang showed only ~1.1 MB read, so it wedges very early —
   likely during or just before the ID 3 selection/READ.
4. **In-OS mount** needs the guest to have the **Apple CD-ROM extension** (or
   a third-party CD driver) in its System Folder, plus the drive answering
   TEST UNIT READY with a disc. Confirm the extension is installed in
   `QuadSquad8.hda` before blaming RTL for the no-icon-in-Finder symptom.
5. **The Main fork's serving of slot 4.** Verify the installed
   `/media/fat/MiSTer` really is the fork (`strings /media/fat/MiSTer | grep
   -i macquadra800` should hit; backup is `/media/fat/MiSTer.bak-*`). The
   fork's CD path is `../Main_MiSTer/support/mac/mac_cdrom.cpp`
   (`mac_cdrom_mount`, TOC blob at HPS block `0x7FFF0000` "MCDA", audio frames
   at `0x40000000+lba`). CUE/CHD go through it; a flat ISO/TOAST passes
   through the generic path. `mac_cdrom_slot()` returns 4 only when the core
   name is in `is_mac_scsi_family()` — that's committed (`be433c6`).

### Fast repro loop
Sim: `scripts/sim_wsl.sh build && scripts/sim_wsl.sh disk <hda>`, then
`wsl -e bash -lc 'cd ~/MacQuadra800/verilator && ./obj_dir/Vemu --headless
--no-cpu-trace +rom=quadra800.rom.hex --disk run.hda --cd cd.iso > sim.log 2>&1'`.
Grep `[NCR` lines (filter `io_ack`/`INT+`) for the command sequence.
Hardware: shut the guest down, rename `.s4.off`→`.s4`, `deploy_screenshot.sh`,
watch `/proc/$(pidof MiSTer)/io` `rchar` — a healthy boot reads ~76 MB.

### Design reference
`docs/cdrom.md` (full CD design), `rtl/ncr53c96.sv` (three targets, one sector
buffer, `cur_tgt`; CD command layer), `rtl/cd_audio.sv` (TOC/audio, ported
from MacLC where `MAME nscsi_cdrom_apple_device` is the byte oracle). CDBs:
groups 6/7 are 10-byte (the Apple `$C0-$CE` set and Toolbox `$D0-$D9`);
`cd_audio`'s `bin2bcd` was fixed (it truncated the tens digit — tell the MacLC
maintainer, the bug is in their tree too). A bus reset / new selection drops
the previous nexus (`abort_nexus`) — needed because the ROM reads block 0 with
a 512-byte request, gets a 2048-byte block, times out, resets the bus.

---

## 3. Alan's newer CPU/DBcc tweaks — fetched, NOT yet integrated

Alan pushed four more commits after the ones we merged. **His branch has
diverged badly**: `alan/cpu-sdram-handoff-seed15` (tip `fd41a27`) is on a
PRE-RENAME, pre-CD base — a full merge would rename `MacQuadra800.*` back to
`wombat33.*` and delete our CD work (the diffstat shows ~8,500 deletions).
**Do NOT `git merge` that branch.** The real logic is in the AP68040
submodule; take it there and bump the pointer.

New AP68040 commits (`rtl/ap68040`, `origin/wombat-retained-line-fill`,
`be0a662..687a8da`):
- `4db6661` Retain instruction fetches across branches
- `fbb5975` Retire memory operands on read acknowledgement
- `687a8da` Collapse prefetched DBcc decrement state

Matching top-level commits (submodule bump + seed only, plus rename noise):
- `e663dad` Accelerate branch instruction refills
- `751655b` Accelerate memory-source operand retirement
- `74b89ad` Accelerate prefetched DBcc retirement
- `fd41a27` Select timing-clean seed for DBcc core

**How to integrate:** `git -C rtl/ap68040 fetch origin` (done), then
`git -C rtl/ap68040 checkout 687a8da`, `git add rtl/ap68040`, commit the
submodule bump. Read `fd41a27` for the seed Alan landed on (the DBcc netlist
is seed-sensitive — the SDRAM `open_row → command[0]` cross-clock path is the
usual offender, now mitigated by `48dd854`'s `ramstyle=logic`, but re-check).
Regress: `rtl/ap68040/tb/run_tests.sh` (needs iverilog+vasm; verilator can run
`tb_ap040_cache_snoop` alone), the SingleStepTests corpus, then a full build
and both-OS hardware boot. `alan` remote is HTTPS
(`https://github.com/alanswx/wombat33_MiSTer.git`); his SSH URL isn't readable
here. See `[[next-cpu-arch-fork-merge]]` in memory.

---

## 4. Add the 512x384 screen mode (12" RGB) — real Quadra 800 built-in mode

Today the DAFB scanout is **hardwired to 640x480**. To add 512x384:

- **Timing constants**, `rtl/dafb.sv` lines ~290-291, currently
  `localparam H_ACT=640, H_FP=16, H_SYNC=96, H_TOT=800;` and
  `V_ACT=480, V_FP=10, V_SYNC=2, V_TOT=525;`. These must become
  mode-dependent. MacLC's `../MacLC_MiSTer/rtl/maclc_v8_video.sv` is the
  precedent: its 12" RGB case (monitor sense `4'h1`) uses `h_total=832`,
  `h_active=640` (it drives 512-active into a 640 window), `v_total=407`,
  `v_active=384`. Decide whether to present a true 512-active window or the
  V8's 640-window-with-512-content trick; the HDMI scaler (`ascal`) upscales
  either.
- **Dot clock.** 512x384 @ 60.15 Hz is **15.6672 MHz** (vs 25.175 for
  640x480). `rtl/pll_video.v` currently emits one output (C0 = 25.175 MHz).
  Add a second PLL output at 15.667 MHz and switch `clk_vid` per mode, or
  reconfigure the PLL. MacLC pulls "25.175 / 15.664" from its pll_video —
  copy that arrangement. `MacQuadra800.sdc` blesses the current `clk_vid`
  crossing; a second video clock needs the same false-path/clock-group care
  (see the `pll_video` note at the top of the sdc).
- **Monitor sense.** The guest's Monitors control panel picks a resolution
  from the DAFB monitor-sense lines read at register `$1C` (block 0, `rsel
  6'h07`), today hardwired to 13" 640x480: `rdata <= 3'b001 | ~sense_drive`,
  commented "13\" 640x480 (code 6), QEMU macfb normal-sense formula". 12" RGB
  512x384 is a different sense code (verify against MAME `dafb.cpp` /
  `macfb` and MacLC — believed sense code 1, `%001`, but confirm). Either
  hardwire 512x384, or make the sense switchable so the guest offers both and
  the mode register (`swatch`/`timing_ctrl` writes) selects which timing the
  scanout uses. Check what the ROM/QuickDraw actually writes to pick a mode.
- **VRAM.** 512x384x8bpp = 192 KB, well under the 512 KB VRAM; stride changes.
  The VRAM address mapper in `MacQuadra800.sv` (`vram_map`, uses `vid_stride`)
  must follow the new stride — it already compacts per stride, so verify it
  handles the 512 case.

Oracle references: `docs/quadra800-developer-notes.md` (VRAM/modes), MAME
`dafb.cpp`, QEMU `macfb`, and MacLC's video for the working 512x384 shape.
Regress both existing OSes at 640x480 first (no regression), then switch the
guest to 512x384 via Monitors and confirm the scanout + HDMI.

---

## Memory notes
[[cdrom-plan-and-area]], [[next-cpu-arch-fork-merge]],
[[sdram-open-row-crossing]], [[look-before-deploy]],
[[other-sessions-share-quartus]], [[never-reset-mister-mid-boot]],
[[mister-remote-input-no-hotplug]].
