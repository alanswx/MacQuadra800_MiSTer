# Resume — CD-ROM works on hardware; 512-byte block mode, 512x384, Alan's CPU in flight

Session of 2026-09-03 (morning). Read `CLAUDE.md` first. Repo `main` is at
the CD wiring fix; the rest of the day's work is on branches in a worktree.

## 1. The CD-ROM hang — root cause and fix (DONE, on main)

Both symptoms in `RESUME-cdrom-and-video.md` (grey boot hang with a disc in
slot 4, wedged Finder after an in-OS mount) had one cause, found by watching
the Main's file positions during a boot (`/proc/$(pidof MiSTer)/fdinfo/<fd>`
for the `.iso` and `.hda`): it never read a byte of either image.
`MacQuadra800.sv` built `sd_rd` as a packed literal that put the CD's strobe
at **bit 5** (the BlueSCSI CD-changer control slot) while the image, lba,
data and ack are on **slot 4**. Every CD read — the `cd_audio` TOC fetch that
fires on mount before the ROM sends anything — was answered on slot 5, the
core waited for `sd_ack[4]` forever, `io_busy` never dropped, and the next
SCSI transfer to any target hung. The sim never saw it because
`verilator/sim.v` instantiates `quadra800`, not `emu`: **nothing in
`MacQuadra800.sv` is covered by the full-machine sim** (now in CLAUDE.md).

- Fix: `a1680e8` — the strobes are assigned per slot by name.
- Build: `output_files/MacQuadra800.rbf` md5 `e34c700424e3e04e93c748f6294eb600`,
  seed 19, 86 % ALMs, timing met +0.184 ns (clk_sys +1.2, clk_ram +0.79);
  `open_row` confirmed uninferred (logic) in the map report. Deployed to
  `/media/fat/_Unstable/MacQuadra800.rbf`.
- Hardware: Mac OS 8.1 boots with the Open Transport disc armed in `.s4`
  and shows the CD icon on the desktop; the user rebooted and used it.
  The pristine-ROM sim with `--cd` also boots through the CD scan (the ROM
  reads block 0 of ID 3 as 4 HPS blocks, then boots ID 0).
- Watch item: after the first boot the hard-disk icon was garbled (stable
  garbage across redraws, everything else clean); it healed when an app
  launched and stayed clean after a reboot. Most likely a leftover from the
  morning's dirty resets. Not reproduced since.
- **Release gate still open for e34c7004:** A/UX 3.1 has not been booted on
  it yet (the user was using Mac OS on the box). Do the A/UX boot + clean
  shutdown, then the `releases/` row + section.

Permission note: the project allow-list matches exact command prefixes;
run `bash scripts/deploy_screenshot.sh` / `bash scripts/grab.sh <file>` bare
(no `export …;` prefix, no trailing pipe) or the auto-mode classifier gets
asked and may refuse. The classifier also refuses to let Claude edit the
permission settings; the user adds rules.

## 2. Worktree `C:/Temp/mistercore/MacQuadra800_wt` — two branches

- **`work/cd512`** (main + video + docs + block mode, CPU unchanged):
  - `bf371f4` video: "Monitor (on reset)" OSD option, 13" 640x480 or 12"
    512x384. Sense code 2, 640x407 frame at 15.664 MHz via MacLC's
    runtime-reconfigurable `pll_video` + `sys/pll_cfg` (static config stays
    the 13" divider; `pix_quiet` blanks ~84 ms on a retarget). Latched
    under reset like the RAM size; the user applies it with the OSD's
    "Reset and close OSD". `docs/video-modes.md`. **Untested on hardware.**
  - `9ff8a77` scsi: MODE SELECT block descriptor of 512 puts the CD in
    512-byte blocks (`cd_blk512`): READ unscaled, READ CAPACITY / MODE SENSE
    follow; survives a bus reset (MAME `nscsi_cdrom_device`). Needed because
    the Mac ROM and the Apple CD-ROM driver switch an AppleCD to 512-byte
    blocks to read the driver descriptor map. `tb_ncr53c96` T16h,
    9207/9207.
  - A full build of this branch was launched at ~06:17 in the worktree
    (`scratch/build_cd512.log` there). If it closes timing: deploy, regress
    Mac OS 8.1 at 640x480 with the CD, then try the **retail disc**
    (`games/MacQuadra800/MAC_OS_8-1_RETAIL.ISO`, Apple partition map, 420 MB):
    (a) in-OS mount from the HD; (b) ROM boot from it — unmount `.s0` (rename
    it away), `.s4` = the ISO, reload. Then switch the OSD monitor to 12",
    reset, check the Main's log for `Video resolution: 512 x 384`.
- **`work/side`** = the same three commits + `4f5e2f7` AP68040 submodule bump
  to Alan's `687a8da` (branch refill, operand retirement, DBcc). A gate sim
  on `gate-emu.hda` with that CPU is running in WSL (`sim_side.log`); when
  the `[HB]` pc parks at `000400FA`, score it per the recipe in
  `RESUME-cpu-merge.md` (`split_allinone_results.py` + `score_vs_oracle.py`;
  expected: cpu 2 known memory-indirect diffs, mmu_full 13 pre-existing).
  The on-screen bench counter read `trap=3` mid-run; find out whether the
  baseline shows the same before taking the bump. Alan's seed note: 25.

Merging: `main` ← fast-forward to `work/cd512` once its build passes on
hardware, then `work/side` on top once the CPU scores clean and builds.

## 3. What the ROM sends a bootable CD (sim in flight)

`~/MacQuadra800/verilator/sim_cdboot.log` in WSL: pristine ROM, no disk,
`--cd cd_retail.iso`. The real ROM spends ~20 min of sim in its memory test
before the SCSI scan. Grep `[NCR` lines (drop `io_ack`/`INT+`) for the CDB
sequence at ID 3: look for a `15` (MODE SELECT) before the `08` reads — that
is the 512-byte switch the block mode exists for. QEMU's q800 note: its
`scsi-cd` refuses the block-size change yet boots Mac OS from CD, so the ROM
may have a 2048-byte path too; the sim will show which it uses here.

## Hardware state at hand-off

MiSTer runs build `e34c7004` with `QuadSquad8.hda` on slot 0 and the Open
Transport ISO on slot 4 (`config/MacQuadra800.s4`; the old `.s4.off` copy
is still there). Mac OS 8.1 was at the Finder with the user driving it.
Main fork is installed (md5 `0783ef1a…`), started with nohup, log at
`/media/fat/nohup.out`.
