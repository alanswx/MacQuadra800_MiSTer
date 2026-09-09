# releases/

Dated core builds, named `wombat33_YYYYMMDD.rbf` (the convention the sibling
Mac cores use). The date is the **work date** the build belongs to, not
necessarily the wall-clock minute Quartus finished — an overnight session that
starts on the 29th is stamped `20260829` even if the fitter returned after
midnight.

Each entry records the md5 so a core on a MiSTer can be identified without
guessing, and the timing margin, because a build that fits but violates timing
must never be flashed (`scripts/deploy_screenshot.sh` refuses one).

Newer CPU-performance checkpoints are preserved outside this dated release
directory while they remain on the development branch. The current one is
parent commit `a267903`, AP68040 `5aa596f`, with its exact artifacts and
recovery procedure recorded in [`../CPU_PERFORMANCE_TASKS.md`](../CPU_PERFORMANCE_TASKS.md).
Do not infer that the newest file in this directory is the fastest current
development build.

| build | md5 | timing | notes |
|---|---|---|---|
| `MacQuadra800_20260908_3.rbf` | `71102b391b375ebc9614d80432136611` | met, **+0.444 ns setup** (clk_sys +0.797, clk_ram +0.927) | **The CD-ROM refuses MODE SELECT block-length changes like QEMU; ships with the rebased Main fork binary (`MiSTer_20260908`, upstream 20260907 + Mac SCSI family + multi-block CD fill).** Same CPU, CD and multi-block cache as 20260908_2. Both OSes pass the gate. The retail CD shows twice on the Quad Squad desktop: traced to that system folder (QEMU reproduces it from the same disk image; a fresh 8.1 install shows one icon), not the core. Seed 21; 98 % ALMs, 476 RAM blocks. |
| `MacQuadra800_20260908_2.rbf` | `61da22443a3a66ac385eaa3ddc53e3de` | met, **+0.171 ns setup** (clk_sys +0.358, clk_ram +1.008, hold +0.243) | **The same CPU and CD, plus the multi-block SCSI cache, with composite Y/C back in.** Every hps_io transaction moves an aligned 8-sector group instead of one sector; the cache's tag bitmaps are sized to the slot (32/32/16 sectors here); the framework's ALSA path and two scaler refinements are compiled out, Y/C stays. Mac OS 8.1 desktop in 136 s (151), ROM CD boot in 107 s (146). Both OSes and the CD boot pass the gate. Seed 19; 98 % ALMs, 476 RAM blocks. |
| `MacQuadra800_20260908.rbf` | `b882d3fce60b63fac4ab1284755031d6` | met, **+0.343 ns setup** (clk_sys +0.415, clk_ram +0.609, hold +0.158) | **Alan Steremberg's next AP68040 (`5aa596f`) with the CD-ROM still in.** Speedometer 4.02 Benchmark Mix 0.360 (Q605 = 1.0; 0.231 on 20260901), Color QuickDraw 0.317, FPU 0.250. Fits at 98 % with balanced synthesis, the framework's trimmed PLL reconfig core for 512x384, the CD passed through the block cache, and composite Y/C + ALSA compiled out. Both OSes and a CD boot pass the gate. Known cosmetic: the CD can appear twice on the Mac OS 8.1 desktop (the Main's 60 s re-insert; fixed in source after this build). Seed 19. |
| `MacQuadra800_20260907.rbf` | `03f83c62d92d997e5cdf89efbb99c42f` | met, **+0.250 ns setup** (clk_ram +0.721, clk_sys +0.850) | **Mac OS 8.1 installs from the retail CD end to end; SCSI block cache.** Fixes the installer deadlock (a write flush's ack followed cur_tgt across a target switch), adds a per-target read-ahead / write-behind block cache in front of hps_io (32/24/8 KB), ROM CD boot, 512-byte CD block mode, CD audio in the mix, Drive Setup's MODE SENSE page, the 12" 512x384 monitor option. Verified on hardware against BOTH Mac OS 8.1 and A/UX 3.1. Tracer off; seed 19; 91 % ALMs, 502 RAM blocks. |
| `MacQuadra800_20260902.rbf` | `91cf5d727920e387c5cefdf18dc695f4` | met, **+0.420 ns setup / +0.195 ns hold** | **First MacQuadra800 release; Alan Steremberg's CPU/SDRAM speed-ups merged.** BL8 open-page SDRAM, related-clock handoff, retained 16-byte line into the AP040 cache, two-entry store buffer, store-hit cache update. Speedometer 3.23 CPU PR 2.66 → 3.88 on Alan's runs. Verified on hardware against BOTH A/UX 3.1 and Mac OS 8.1. Seed 19; 85 % ALMs. |
| `wombat33_20260902.rbf` | `70716e92871448d1ff81ebb430902f4a` | met, **+0.130 ns** | **A/UX 3.1 boots to multiuser.** Both NCR53C96 SCSI bugs fixed (control-path phase flip + write-path chunk-flush). First build verified on hardware against BOTH A/UX 3.1 and Mac OS 8.1. Tracer off; seed 13; 85 % ALMs. |
| `wombat33_20260901_2.rbf` | `d1d785de28439d132333a1c9e3aab5c5` | met, **+0.270 ns setup / +0.241 ns hold** | Related-clock SDRAM handoff: 151 ns reads, 22.0 MB/s simulated sequential RAM, Speedometer 3.23 CPU PR 2.917. |
| `wombat33_20260831_2.rbf` | `4414e7b3294b3d554a9e43faa16682bd` | met, **+0.062 ns** | **The machine has a serial port.** Ports the Z8530 SCC from MacLC onto the beat bus, plus MIDI-over-SCC and MT32-pi. 85 % ALMs — watch the slack. |
| `wombat33_20260831_1.rbf` | `3901ef5705f58dba3279c0417412f5f8` | met, +0.243 ns | **Sound works.** Fixes the watch-cursor wedge (ASC FIFOSTAT reported an empty FIFO as full) and hooks up the $806 volume slider. |
| `wombat33_20260830.rbf` | `64c79dfb93ceefb549200c78671cdc31` | met, +0.248 ns | **ADB actually works** — the mouse button reaches the guest and motion stops inventing input. |
| `wombat33_20260829.rbf` | `4c46a65c3a48b44ddb6f4fd6808d0422` | met, +0.245 ns | First build that boots Mac OS unattended. |

## `MacQuadra800_20260908_3.rbf`

md5 `71102b391b375ebc9614d80432136611`, seed 21, timing met at **+0.444 ns**
overall (HDMI PLL domain; `clk_sys` +0.797 ns, the 99 MHz SDRAM domain
+0.927 ns), the widest margin since the release recipe. 41,014 ALMs (98 %),
26,005 registers, 476 of 553 RAM blocks. Built from `4f859b3` on `main`
with the qsf-default recipe (balanced synthesis, register duplication off,
`CACHE_CD_OFF`, `CACHE_SMALL`, `MISTER_DISABLE_ALSA`, `MISTER_DOWNSCALE_NN`,
`MISTER_DISABLE_ADAPTIVE`; composite Y/C kept; tracer off). The qsf now
records seed 21.

**Ships with a Main binary:** `releases/MiSTer_20260908` (md5
`916829ffe37e778ac3e7bf41fb5a8eaa`) is the Main fork
(`danifunker/Main_MiSTer`, branch `mac-ethernet-pr`, commit `4857af1`)
rebased onto upstream's `20260907` release. It carries the Mac SCSI family
support this core needs for CUE/CHD discs, CD audio, the BlueSCSI Toolbox
and the CD changer, plus a new multi-block CD data-window fill (a 4 KB run
per hps_io transaction) that a later core build will use (`MB_CD=1`,
`13d7fea`, not in this bitstream). Install it as `/media/fat/MiSTer`; a
flat `.iso` also works on upstream's own Main.

What changed since `20260908_2`:

- `rtl/ncr53c96.sv` -- **the CD-ROM refuses a MODE SELECT block-length
  change** the way QEMU's `scsi-cd` does: a block descriptor the list does
  not contain (the ROM's boot-scan 8-byte list) or any block length but
  2048 gets CHECK CONDITION 05/26/00; the audio control page (0Eh) of a
  well-formed list is still applied; the block length is 2048 always. STATUS
  is delivered only once the list has been judged, so an initiator can
  never fetch a GOOD the parse is about to overturn (an ICCS that arrives
  early is held one cycle). `tb_ncr53c96` 476,837 checks, 0 failures; the
  bench's new cases read the interrupt register before their next command,
  as a 53C96 driver must.
- `rtl/scsi_cache.sv` -- unchanged from `20260908_2` in this bitstream (the
  CD slot still moves single sectors; the multi-block CD path lands with the
  Main above in the next build).

Hardware (2026-09-08, operator run, screenshots `scratch/op*.png`): Mac OS
8.1 (QuadSquad8) Finder desktop at about 2 min 15 s from `load_core`, the
retail CD's window readable, clock 12:06 -> 12:09 over an idle watch with
`write_bytes` flat, mouse and keyboard live, Special -> Shut Down clean.
A/UX 3.1 multiuser Finder desktop in about 3 min 30 s with the UNIX root
volume mounted, About This Macintosh = Quadra 800 / System 7.0.1 / 32 MB
with CommandShell running, Special -> Shut Down to "You may now switch off
your Macintosh safely". Both gates pass.

Known, and traced to the guest after this build: on the Quad Squad boot the
retail Mac OS 8.1 CD shows up twice on the desktop, two windows of the same
volume. The MODE SELECT change above matched QEMU's behaviour and did not
remove it. A request trace on the box showed the HFS volume mounted twice
at +118 s with a command sequence identical to QEMU's, and QEMU itself,
with its own `scsi-cd`, shows the same two icons when it boots a copy of
the Quad Squad disk, while a fresh Mac OS 8.1 install shows one icon on
QEMU and on the FPGA alike. So it is the Quad Squad system folder's
extension set, not the core: with it both the disc's ROM-loaded driver and
the extension's driver keep a drive-queue entry. Its Apple CD-ROM 5.4.2
copy is excluded (swapping in Mac OS 8.1's own, byte for byte, changed
nothing in QEMU); which item does it is not yet bisected. Cosmetic; the install
from the disc works.

## `MacQuadra800_20260908_2.rbf`

md5 `61da22443a3a66ac385eaa3ddc53e3de`, seed 19, timing met at **+0.171 ns**
overall (HDMI PLL domain; `clk_sys` +0.358 ns, the 99 MHz SDRAM domain
+1.008 ns, hold +0.243 ns). 41,181 ALMs (98 %), 476 of 553 RAM blocks, 49
DSP blocks. Built from `43e5d09` on `main` with the recipe that is now the
qsf default: balanced synthesis, register duplication off, `CACHE_CD_OFF`,
`CACHE_SMALL`, `MISTER_DISABLE_ALSA`, `MISTER_DOWNSCALE_NN`,
`MISTER_DISABLE_ADAPTIVE`; composite Y/C output kept; tracer off.

What changed since `20260908` earlier the same day:

- `rtl/scsi_cache.sv` -- **multi-block platform transactions**: a miss into
  an absent aligned 8-sector group fetches the whole group as one hps_io
  read, the prefetcher brings the next two absent groups the same way, a
  fully dirty group flushes as one 8-block write, and a fetched sector is
  valid the moment its last word lands. Each hps_io transaction costs a
  Main_MiSTer main-loop pass, and the core used to pay it per 512 bytes.
  Partly dirty groups flush singly once the engine has been quiet, a miss
  into a group already on its way waits for it, and the flush scanner
  wraps at the slot's size (a latent index-aliasing bug found by the
  32-sector geometry). Tag bitmaps are sized to the largest slot;
  `CACHE_SMALL=1` selects 32/32/16 sectors. The CD slot still uses single
  sectors until the Main fork's CD path is confirmed to honour the block
  count. Bench `tb_scsi_cache` T1-T9 in three geometries, 279,315 checks
  each; `io_blk_cnt` reaches hps_io's `sd_blk_cnt` for the three real
  slots.
- `rtl/ncr53c96.sv` -- a CD mount pulse that names the disc already present
  (same size, not ejected) is a no-op.
- Framework switches: ALSA (audio from the Linux side into the mix) off;
  the scaler's bilinear downscaling and adaptive scanlines off. Composite
  Y/C is compiled IN again (it was out of `20260908`). MT32-pi is
  unaffected by the ALSA switch: it is the user-port I2S module.
- `scripts/guest/menu.sh`, `menuitem_probe.py`, `mac_shutdown.sh` -- the
  operator menu drivers aim at the title centre, measure the mouse scale,
  and recognise System 7's black highlight; not part of the bitstream.

Hardware (2026-09-08, `scratch/gate_L/`): Mac OS 8.1 (QuadSquad8) Finder
at 136 s with the retail CD mounted and its window readable, clock 6:55 ->
7:00 over the idle watch, mouse and keyboard live, a 5.5 MB Finder
duplicate in about 29 s, Special -> Shut Down clean. A/UX 3.1 multiuser
desktop in under 282 s, `uname -a` = `A/UX localhos 3.1 SUR2 mc68040`,
`shutdown -h now` clean in 188 s. ROM boot from the retail CD to its Finder
desktop in 107 s, clean shutdown.

Known and cosmetic, and now better understood: on the Quad Squad boot the
retail CD shows up twice on the desktop, and Get Info on both icons reports
the identical volume at SCSI ID 3. The CD boot and A/UX show it once. So it
is not the core presenting two targets, and the same-disc mount guard did
not change it; the variable is the Quad Squad disk's own extension set,
which most likely carries a second CD driver that mounts the disc too.

The CD audio engine's 12 % diet (`79d3e9b`, `5f52240`, `3098ee3`) is on
`main` but not in this bitstream.

## `MacQuadra800_20260908.rbf`

md5 `b882d3fce60b63fac4ab1284755031d6`, seed 19, timing met at **+0.343 ns**
overall (HDMI PLL domain; `clk_sys` +0.415 ns, the 99 MHz SDRAM domain
+0.609 ns, hold +0.158 ns). 41,108 ALMs (98 %), 499 of 553 RAM blocks.
Built from `ff7f4b0` on `main` with the release recipe in the qsf notes:
`OPTIMIZATION_MODE BALANCED`, `OPTIMIZATION_TECHNIQUE BALANCED`, register
duplication off, `CACHE_CD_OFF=1`, `MISTER_DISABLE_YC=1`,
`MISTER_DISABLE_ALSA=1`. Tracer off.

**Alan Steremberg's next AP68040 step is in** (`5aa596f`: retained
instruction fetches across branches, memory operands retired on read
acknowledge, DBcc collapse, simple An effective addresses and source-EA
dispatch bypassed, register ADD operands preselected in decode). Against the
20260901 numbers in `docs/PERFORMANCE_MEASUREMENTS.md` the Benchmark Mix
average goes 0.231 -> **0.360** (+56 %), Color QuickDraw 0.219 -> 0.317, FPU
0.161 -> 0.250; Permutations 1.97x, Towers 1.78x, Dhrystones 1.75x. The core
is +20 % logic, which is why this build needed:

- the framework's trimmed PLL reconfiguration core (`pll_cfg_hdmi`) behind
  the 12" 512x384 option instead of the generic IP (715 -> ~300 cells);
- the CD-ROM passed straight through the SCSI block cache (`CACHE_CD_OFF`):
  the disks keep their read-ahead and write-behind, the CD loses its 8 KB
  read-ahead;
- the composite/S-Video encoder and the ALSA (audio-over-HPS) path compiled
  out; HDMI and VGA video and HDMI/analog audio are unaffected;
- balanced rather than speed-directed synthesis. Speed synthesis does not
  fit; area synthesis fits but breaks HDMI-domain timing.

Hardware (2026-09-08, `scratch/gate2_b882d3fc/`): Mac OS 8.1 (QuadSquad8)
Finder at 151 s with the retail CD mounted and its window readable, clock
5:25 -> 5:30 over the idle watch, mouse and keyboard live, Speedometer
average 0.360, Special -> Shut Down clean. A/UX 3.1 multiuser desktop in
under 263 s (the CD readable there too), `uname -a` = `A/UX localhos 3.1
SUR2 mc68040`, `shutdown -h now` clean. ROM boot from the retail CD to its
Finder desktop in under 146 s, clean shutdown.

Known and cosmetic: with the CD in the slot at boot the disc can show up
twice on the Mac OS 8.1 desktop when booting from the Quad Squad disk (once
when booting from the CD or under A/UX). Both icons are the same volume at
SCSI ID 3. A same-disc mount guard (`2631967`) was tried against the Main's
60 s re-insert and did not change it (see `20260908_2`); the likely cause is
a second CD driver in that disk's extension set. The multi-block SCSI cache (`f878a6e`) is not in it
either: with this CPU and the CD it sits a seed's worth of variance over
the device; see the resume doc for the geometry option being built.

## `MacQuadra800_20260907.rbf`

md5 `03f83c62d92d997e5cdf89efbb99c42f`, seed 19, timing met at **+0.250 ns**
overall (HDMI PLL domain; the 33 MHz `clk_sys` domain closes at +0.850 ns and
the 99 MHz SDRAM domain at +0.721 ns; hold positive everywhere). 37,939 ALMs
(91 %), 502 of 553 RAM blocks. Fitter/STA summaries next to it as
`MacQuadra800_20260907.{fit,sta}.summary` (gitignored, local only). Built from
`c805300` on `main`; the serial SCSI tracer is compiled out.

**The retail Mac OS 8.1 CD installs end to end on the hardware** (install #9,
2026-09-07: base system plus every optional package, 177 MB written,
"The installation process has finished"), which is what the whole CD-ROM
line of work was for. What changed since `20260902`:

- `rtl/ncr53c96.sv` -- the installer deadlock (`f349e9e`): the engine reports a
  write's GOOD status when its last block *starts* flushing; when the ROM then
  selected the CD, `cur_tgt` switched and the flush's ack was lost, wedging
  `io_busy`. An outstanding flush now follows its own target (`flush_tgt`).
  Also: the disks accept MODE SELECT / VERIFY / SYNCHRONIZE CACHE / FORMAT
  UNIT / REASSIGN BLOCKS / SEND DIAGNOSTIC, answer MODE SENSE page $30 with
  Apple's firmware-ID page (Drive Setup), the CD-ROM honours a MODE SELECT
  block length of 512, and a CD eject lasts only until the next bus reset, so
  the ROM's two-pass CD boot finds the disc again.
- `rtl/scsi_cache.sv` (new, `docs/scsi-block-cache.md`) -- a per-target
  read-ahead / write-behind block cache between the engine and `hps_io`:
  64/48/16 sectors (32 KB disk 0, 24 KB disk 1, 8 KB CD) in one 64 KB
  altsyncram. Reads hit in RAM and prefetch eight sectors ahead; writes ack
  from RAM in ~25 us and flush in the background, so no platform transfer is
  ever outstanding across a target switch. Install write bursts peak at
  11.7 MB/min versus ~9 without it. Bench `tb_scsi_cache` T1-T8, 237,584
  checks; `tb_ncr53c96` 475,299 checks.
- `MacQuadra800.sv` -- the CD-ROM's audio is mixed into the speakers; the
  CD strobe is on slot 4 (it was on the CD-changer slot 5, which is why the
  first CD builds hung with a disc mounted).
- `rtl/dafb.sv` / video -- the 12" RGB 512x384 monitor as an OSD option
  (`docs/video-modes.md`).
- `rtl/wombat_cpu.sv` -- the core stall watchdog is held while an HPS block
  transfer is outstanding and widened to 0.5 s, so an SD-card pause under a
  pseudo-DMA beat is not a bus error.
- Build switches in the qsf: `SCSI_TRACE=1` (debug tracer on the modem port,
  never in a release) and `CDROM_OFF=1` (drops the CD target and its audio
  engine, about 3,000 ALMs, for CPU-area experiments).

Hardware (2026-09-07, `scratch/gate_03f83c62/`): Mac OS 8.1 (QuadSquad8)
Finder at 150 s, clock ticking 5:47 -> 5:52 over the idle watch, mouse and
keyboard live, Special -> Shut Down to "safe to switch off" in 25 s. A/UX 3.1
multiuser desktop at ~4.5 min, `uname -a` = `A/UX localhos 3.1 SUR2
mc68040`, `shutdown -h now` to "You may now switch off" in 2 min 10 s.

Known and not in this build: Alan Steremberg's next AP68040 step
(`5aa596f`, about 2x CPU) is on `main` but does not fit alongside the CD
path (4221 LABs needed of 4191 even with aggressive-area synthesis); it ships
as a `CDROM_OFF` measurement build for now.

## `MacQuadra800_20260902.rbf`

md5 `91cf5d727920e387c5cefdf18dc695f4`, seed 19, timing met at **+0.420 ns
setup / +0.195 ns hold** overall (worst paths are in the HDMI PLL domain; the
33 MHz `clk_sys` domain closes at +1.138 ns and the 99 MHz SDRAM domain at
+0.916 ns setup). 85 % ALMs, 30,750 registers. Fitter/STA reports next to it as
`MacQuadra800_20260902.{fit,sta}.summary` (gitignored, local only).

**First release under the MacQuadra800 name, and the first with Alan
Steremberg's CPU and memory speed-ups** (merged from
`alanswx/wombat33_MiSTer` branch `cpu-sdram-handoff-seed15` in `e744dde` and
`e8eebe9`, with the `rtl/ap68040` submodule moved to `alanswx/AP68040`
`be0a662`). What changed, platform side then CPU side:

- `rtl/sdram_beat32.sv`: the 33 ↔ 99 MHz request/completion toggles cross on
  the falling edge of `clk_ram` instead of through two-flop synchronisers —
  the clocks are phase-related outputs of one PLL, and `derive_pll_clocks`
  times the half-cycle paths. Isolated read 212 → 151 ns.
- `rtl/sdram.sv`: BL8 open-page controller — rows stay open per {rank, bank}
  with tRAS/tRP tracking, refresh precharges both ranks explicitly. Every
  read captures a full 16-byte line that the bridge retains.
- `rtl/quadra800.sv`: aligned RAM longword reads that hit the retained line
  (or are the first miss of one) complete through registered pulses without
  crossing `wombat_bus32`; everything else keeps the service-FSM cadence.
- `rtl/ap68040` (`ap040_cache`): a line fill takes its remaining three words
  from the retained line instead of issuing three more bus reads; an aligned
  cacheable store now updates the resident data-cache word instead of
  invalidating the whole set.
- `rtl/wombat_store_buffer.sv` (new, below the cache): a two-entry ordered
  queue acknowledges non-faulting physical-RAM stores at capture and drains
  them behind cache hits. Reads, walker cycles and device writes wait for it.
- `ap040_core`: the exception format is carried in the entry state, removing
  a 50-level decode path that had stopped seeds 18–20 closing.

Alan's Speedometer 3.23 PR numbers on Mac OS 7.5.5 (his disk, one iteration
each; see `docs/PERFORMANCE_MEASUREMENTS.md` §8–12): CPU 2.661 → **3.878**,
Graphics 3.487 → **5.130**, Math 15.841 → **29.395**.

**Verification on this tree:**

| check | result |
|---|---|
| `tb_sdram` | 45 checks, 0 failures, 0 chip protocol errors (both ranks modelled), 43.7 MB/s |
| `tb_wombat_bus32`, `tb_store_buffer` | 6/6; all store-buffer ordering/backpressure tests pass |
| `tb_memory_path`, `..._registered_first_miss` | 0 failures, 52 MB/s integrated |
| `tb_ncr53c96`, `tb_easc` | 6556/6556, 18/18 |
| AP68040 `tb_ap040_cache_snoop` | ALL TESTS PASSED (incl. T10 retained-line fill, T11 store-hit update) |
| Full-machine Verilator gate (`gate-emu.hda`, fastboot ROM) | cpu 717 rows: 13,585 groups match, the 2 known memory-indirect diffs; fpu 270, saverestore 8, integration 1328 rows clean; mmu_full 24 rows: 13 diffs that the **pre-merge base `f9767d8` reproduces identically** (pre-existing in this harness, not a regression) |

**Hardware result (192.168.99.143, 2026-09-02):**

| guest | result |
|---|---|
| A/UX 3.1 (`HD60_512-AUX3.1-Installed.hda`) | multiuser Finder desktop 4 min after `load_core`, no fsck; Apple menu → CommandShell; `uname -a`, `ls`, `uptime`, `sum /unix` all answer; sync writes at idle; `shutdown -h now` → "You may now switch off." |
| Mac OS 8.1 (`QuadSquad8.hda`) | Finder 2 min after `load_core`; menu-bar clock ticks at idle (2:35 → 2:41); Cmd-W closes a window, pointer tracks; Special → Shut Down → "It is now safe to switch off." |

## `wombat33_20260902.rbf`

md5 `70716e92871448d1ff81ebb430902f4a`, timing met at **+0.130 ns** (seed 13,
`SCSI_TRACE` off). Fitter/STA reports next to it as
`wombat33_20260902.{fit,sta}.summary` (gitignored, local only).

**A/UX 3.1 now boots to the multiuser Finder desktop.** Two NCR53C96 SCSI bugs
in `rtl/ncr53c96.sv`, both needed:

1. **Control path:** non-DMA `$10` TRANSFER INFO flips phase to STATUS on the
   request's last byte. Killed "Protocol Error Processing SCSI request"; A/UX
   reaches `fsck`.
2. **Write path:** saio splits one WRITE into `$90` TIs of TC=256; the old
   completion arm flushed a part-filled sector buffer at every chunk boundary,
   so each sector got 256 real bytes + stale zeros and fsck saw "BAD SUPER
   BLOCK: MAGIC NUMBER WRONG." Fix: a chunk end is an interrupt only; only
   `sbuf_pos == 512` flushes. (Mac OS writes single-TI and never tripped it,
   which is why every prior build booted Mac OS but corrupted A/UX.)

Pinned in sim by `verilator/tb_ncr53c96.sv` T1–T15 (6556 checks). Full story in
`RESUME-aux-superblock.md`, `docs/scsi/rtl-gap-analysis.md` item 19, and
`docs/scsi/aux-startup-boot-path.md` §9.

**This is the tracer-off release of the seed-13 build.** `SCSI_TRACE` (the
`rtl/iosb.sv` modem-TX debug mux) is commented out in `wombat33.qsf`, so the
SCC reaches the serial pin normally. Removing the tracer logic reroutes the
netlist, so this is a distinct fit from the 09-01 `scratch/seeds` seed-13
backup (`abb5ede4…`, +0.132 ns) — same seed, different bytes.

**Hardware result (192.168.99.143, 2026-09-02):**

| guest | result |
|---|---|
| A/UX 3.1 (`HD60_512-AUX3.1-Installed.hda`) | boots through fsck → multiuser Finder desktop; 16+ min interactive (CommandShell, menus); `shutdown -h now` → "You may now switch off." |
| Mac OS 8.1 (`QuadSquad8.hda`) | boots to Finder; keyboard + mouse responsive; menu-bar clock ticks at idle; clean Shut Down. No regression. |

Both guests were exercised at idle and shut down cleanly. An apparent Mac OS
"foreground wedge" seen mid-session was traced to a test-harness bug (a guest
menu-driver script killed by a timeout left the mouse button held down), not
the bitstream; it did not reproduce with clean input.

## `wombat33_20260901_2.rbf`

MD5 `d1d785de28439d132333a1c9e3aab5c5`, seed 15. Overall timing closes at
**+0.270 ns setup and +0.241 ns hold**; the 99 MHz SDRAM domain is +1.353 ns
setup and +0.431 ns hold. Targeted TimeQuest reports put every new handoff
path above +1.353 ns setup and +3.191 ns hold.

This build replaces the conservative two-flop request and completion
synchronisers in `rtl/sdram_beat32.sv`. The 33 and 99 MHz clocks are
phase-related 1:3 outputs of one PLL, so the handoff is captured on the falling
edge of the 99 MHz clock and checked as a timed half-cycle path.

Measured against the seed-13 SDRAM-fast-path control:

| | seed 13 | seed 15 |
|---|---:|---:|
| isolated RAM read | 212 ns | **151 ns** |
| sequential RAM | 16.4 MB/s | **22.0 MB/s** |
| Speedometer 3.23 CPU PR | 2.661 | **2.917 (+9.6%)** |

Verification: `tb_sdram` 33/33 with zero chip-protocol errors, `tb_easc`
18/18, ten SingleStep rows with 170 matching field groups and zero real
differences, Mac OS boot, full Speedometer 3.23 PR suite, and clean guest
shutdown. The complete measurements and screenshots are in
`docs/PERFORMANCE_MEASUREMENTS.md` §8.

## `wombat33_20260831_2.rbf`

md5 `4414e7b3294b3d554a9e43faa16682bd`, timing met at **+0.062 ns**.

The Quadra 800 gets a serial port for the first time: `rtl/scc.v` (the Zilog
85C30) ported from the MacLC/MacIIvi lineage, hung off the beat bus through a
new adapter in `rtl/iosb.sv` at `$5000C000`, plus MIDI-over-SCC and the
MT32-pi user-port block. Full rationale and the port map in
`docs/scc-port-survey.md`.

**Hardware result (192.168.99.143, 2026-08-31):** boots clean to the Mac OS 8
desktop with the SCC live. This was the real risk — the space previously
decoded as present-but-inert (reads 0, writes discarded, always acked), so the
ROM's `InitSCC` and its loopback selftest now get real answers for the first
time. A wrong answer there does not fail quietly: the sibling `lbmactwo` core
hit exactly this and the ROM dropped into the Test Manager. This one walks
straight through ROM → "Welcome to Mac OS" → extensions → Finder, and the
Serial Driver loads without the freeze that had to be fixed on the LC.

**Utilization moved, and the slack with it.**

| | before | after |
|---|---|---|
| Logic (ALMs) | 34,223 / 41,910 (82 %) | **35,436 / 41,910 (85 %)** |
| Registers | 28,980 | 29,886 |
| DSP blocks | 47 (42 %) | 51 (46 %) |
| RAM blocks | 421 (76 %) | 423 (76 %) |
| Worst slack | +0.243 ns | **+0.062 ns** |

+1,213 ALMs buys the whole feature set (both SCC channels, four UART
serializers, the MT32-pi block). The four extra DSPs are the baud arithmetic
introduced by the `SYS_CLK_HZ` parameterisation — one operand is constant, so
they can be forced into logic if DSPs ever get tight.

**62 ps is the number to watch.** It met, and every other domain is
comfortable (HDMI next at +0.243 ns), but this core is seed-sensitive and the
next netlist change could push `clk_sys` negative. Expect a seed re-roll rather
than a structural problem if it does.

Still unproven on hardware: PPP, MIDI and MT32-pi end to end. Those need
guest-side setup (a PPP client and MacTCP/OT) and, for MT32-pi, a Pi on the
user port. The RTL paths are covered in simulation by
`verilator/tb_iosb_scc.v`, which measures 1056 clk/bit on `scc_txd_a` — 31250
baud at 33 MHz — through the real bus adapter.

## `wombat33_20260831_1.rbf`

md5 `3901ef5705f58dba3279c0417412f5f8`, timing met at +0.243 ns (seed 6).

Two changes, both in `rtl/easc.sv`.

**The watch-cursor wedge is fixed.** `$804` FIFOSTAT bits 1/3 read
`(cap == 0) || (cap >= 1023)`, so an EMPTY FIFO reported itself FULL. A guest
that fills until the full flag sets therefore wrote nothing; with no bytes
queued nothing ever popped, so the half-empty edge never fired and no refill
interrupt was ever raised. The wait never ended. Mac OS sat at a fully drawn
desktop with a watch cursor and a stopped menu-bar clock while ADB kept
tracking the mouse at interrupt level -- interrupts were fine all along, the
foreground was simply blocked forever.

Scored on hardware against `wombat33_20260830.rbf`, every run on a freshly
restored disk:

| build | scanout | ASC IRQ | menu-bar clock |
|---|---|---|---|
| `20260830` (known good) | 33 MHz | n/a | ticks |
| pre-fix | 25.175 MHz | off | FROZEN |
| pre-fix | 33 MHz | off | FROZEN |
| pre-fix | 25.175 MHz | off | FROZEN (2nd sample) |
| this build | 25.175 MHz | **on** | ticks |

Note rows 2-4: the wedge reproduced with the ASC interrupt DISCONNECTED and
with the DAFB scanout forced back off the 25.175 MHz pixel clock. Both of
those were the prime suspects and both are innocent. Do not re-investigate
them; the fault was always the status register.

**The Sound control panel's volume slider works.** `$806` was stored and
ignored (MAME does not apply it either). Bits 7-5 are the eight steps the
panel offers; the gain table is `x*256/7` so step 7 is EXACTLY unity and a
machine at maximum sounds identical to before. `volume` resets to `0xE0`
(max), not 0 -- the boot chime is ROM-generated before Mac OS loads any sound
preference, and a zero reset would silence it.

`make tb_easc` passes 18/18, including `stat after reset = 05`.

## `wombat33_20260830.rbf`

The build where ADB input is correct. Deployed to the MiSTer at
192.168.99.143 and verified against the pristine *Quad Squad* image (md5
`f4287aee9ff9a4413fa1e5fd9f2d63b4`) on two separate boots.

One RTL hunk, in **`rtl/via6522.sv`**: in ACR modes `011`/`111` CB1 is an input
and the internal shift clock IS the pin, but the RTL forced `shift_clock` high
whenever `shift_active` was low. Clearing `shift_active` on an `sr_ext_complete`
therefore drove it 0→1, and that rising edge shifted the byte the completion had
just loaded one place left, with `cb2_i` (tied low) in the LSB — **every byte the
ADB shim delivered, every time**.

An ADB mouse Talk R0 byte 0 is `{~button, dy[6:0]}`, so the button is exactly the
bit a left shift throws away, and what took its place was the old bit 6, the sign
of dy. That is both halves of the fault the previous entry lists as a known
issue: clicks did nothing, and plain motion with dy ≥ 0 read as button-down,
which is why mouse movement alone opened menus and appeared to type.

Scored against a control build differing only in that hunk — same disk, same ROM,
same injected mouse traffic — non-`$00` bytes surviving from the transceiver to
the driver went from **0 / 82** to **670 / 670**. Full derivation and the
measurement method: `docs/adb-via-shift.md`.

Also here: fitter `SEED` 2 → 3. Seed 2 gave −0.283 ns hold on the 99 MHz
`clk_ram` domain, which a `clk_sys`-domain change cannot reach — the placement
swing the qsf comment warns about, not the RTL.

What this build makes possible: `scripts/mac_shutdown.sh` now drives Special →
Shut Down unattended, so a core can be swapped without power-cutting a mounted
HFS volume.

**Known issues.**

- **Boot stalls roughly 1 in 3.** Frozen at "Starting Up…", disk `pos` frozen,
  screen byte-identical for minutes. Present before this build and not caused by
  it; reproduced here on a freshly restored pristine image. See
  `RESUME-adb-and-corruption.md` for the ADB-deadlock hypothesis and the
  detector committed to test it.
- **Host keystrokes never reach the guest.** Host-side, not the core —
  `kbd:osd` does not open the MiSTer OSD either, so nothing is arriving at the
  Main. The core's ADB keyboard path is therefore untested end to end.
- The Mac reads exactly one hour behind the host (minutes dead-on), which looks
  like standard vs daylight time in what the Main sends.

## `wombat33_20260829.rbf`

First core that reaches the Mac OS desktop with no operator intervention:
core load → `SC0` auto-mount of `games/Wombat33/QuadSquad8.hda` → Finder.
Verified on the MiSTer at 192.168.99.143 against the pristine *Quad Squad*
image (md5 `f4287aee9ff9a4413fa1e5fd9f2d63b4`).

Fixes in this build, over the first hardware run:

- **`ncr53c96`** — a non-DMA transfer-info that underflows now ends the data
  phase (`PH_STAT` + `I_BUS`) instead of waiting forever for a byte the target
  will never produce. This was the freeze at "Starting Up…": an INQUIRY with a
  `$24` allocation length delivered all 36 bytes and the chip then sat in
  DATA-IN. Matches QEMU `esp.c:667-671`.
- **`iosb`** — the A_SDMA hold-off got an escape (a wedged pseudo-DMA beat
  releases into a bus error rather than deadlocking the machine), and that
  escape's watchdog is frozen while a platform block transfer is outstanding,
  so SD latency cannot trip it.
- **`iosb`** — the ADB transceiver handshake moved into the `adb_en` domain.
  Driving it at full `clk` dropped command bytes and delivered response bytes
  more than once.
- **`wombat33.sv`** — CONF_STR `S0` → `SC0` so the mount is remembered, plus a
  latch that replays a mount arriving while the machine is held in reset.
- **`wombat33.qsf`** — fitter `SEED` 1 → 2; seed 1 produced a −0.122 ns hold
  violation on the 99 MHz `clk_ram` domain.

**Known issue (RESOLVED in `wombat33_20260830.rbf`, and the guess below was
wrong — it was the VIA shift register, not the heartbeat):** occasional phantom
keystrokes remain. The ADB duplicate-byte
defect is fixed and measured (VIA deliveries per transceiver byte dropped from
~2.3× to ~1.3×), and mrext is ruled out — it sends only `mouseMove`/`mouseBtn`,
never `kbd`. The residue is most likely the idle-autopoll heartbeat
re-delivering a stale `kbd_to_mac`; see `RESUME-first-hardware-run.md`.

The Quadra 800 ROM (`quadra800.rom`) is **not** committed — Apple firmware, see
`.gitignore`. Put your own 1 MB image there; the deploy seeds it to the MiSTer
as `games/Wombat33/boot.rom`.
