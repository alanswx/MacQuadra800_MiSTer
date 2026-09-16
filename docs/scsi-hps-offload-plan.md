# Moving the CD-ROM target's brains to the ARM (branch `optimize-SCSI`)

Plan written 2026-09-16, before any code. The Main side lives on
`../Main_MiSTer` branch `mac-ethernet-pr-with-SCSI-Optimizations`; the core
side on this branch. Section 9 is the live checklist and section 10 the
dated log; sections 1-8 are the design as planned that morning (the
contract in section 4 was updated as built).

## 1. Why, and how much there is to win

The seed-22 build of the shipped 20260915 recipe needs 38,638 of 41,910 ALMs
(92 %) and 497 of 553 M10Ks. The SCSI side of the fitter's entity table
(`output_files/MacQuadra800.fit.rpt`, 2026-09-16 01:20):

| entity | ALMs needed | registers | M10K | DSP | notes |
|---|---:|---:|---:|---:|---|
| `ncr53c96` total | 2,870 | 1,630 | 16 | 23 | chip model + 2 disks + CD command layer + `cd_audio` |
| of which `cd_audio` | 1,346 | 852 | 15 | 13 | TOC parse, three response tables + builders, audio transport, playhead, volume, PCM cadence |
| `ncr53c96` own | 1,525 | | | | the 53C96 itself was ~700 in the 2026-09-02 map; the CD command layer (INQUIRY/MODE SENSE tables, the SY_* response kinds, the $C1/$43 address muxes, MODE SELECT parser, x4 scaling) is most of the rest, ~600 |
| `scsi_cache` | 877 | 635 | 40 | 0 | hard-disk performance feature; `CACHE_CD_OFF` is already the release recipe |
| `hps_io` | 612 | 958 | 0 | 0 | VDNUM 6 |

So the CD-ROM costs ~1,950 ALMs today (`CDROM_OFF` measured 3,036 on
2026-09-03, before the audio-engine diet). Everything the CD target does apart
from moving READ data is response building and playhead bookkeeping, which a
CPU does for free. The 53C96 chip model, the two hard-disk targets, the block
cache and the CD READ data path stay in RTL: the ROM and A/UX's `c94` driver
validated the chip model, and the cache exists precisely because a per-command
ARM turnaround is too slow for the disk.

Expected saving: **1,200-1,600 ALMs and ~13 M10Ks** across two phases (below),
3-4 % of the device. Not the whole 1,950: the READ path, x4 scaling, sense, a
frame buffer and the PCM cadence stay.

## 2. What Main does for IDE (the precedent)

`ide.cpp` / `ide_cdrom.cpp` (root of Main, 3,300 lines) implement a complete
ATA/ATAPI device in software for ao486, PCXT, Minimig and Archie:

- The core (`rtl/ide.v` in Minimig, 314 lines) holds only the IDE task-file
  registers and a data FIFO, exposed through hps_io's `EXT_BUS` DMA channel
  (`UIO_DMA_WRITE` 0x61 / `UIO_DMA_READ` 0x62 / `UIO_DMA_SDIO` 0x63).
- Every `user_io_poll`, `ide_check()` reads a request word; `ide_io()` fetches
  the 12 register bytes, runs the command (`handle_hdd`, `cdrom_handle_cmd`,
  `cdrom_handle_pkt`), and writes registers + data back. The core's FSM only
  knows "command pending / data pending / reset".
- `ide_cdrom.cpp` has the MMC responses (`read_toc`, `mode_sense`,
  `read_subchannel`, `cd_inquiry`, sense), CUE/CHD parsing, and playback:
  when the core sets bit 8 of the request word, `ide_cdda_send_sector()` reads
  one 2352-byte frame at the ARM-side playhead, applies the volume, pushes it
  into the core's FIFO at register offset 0x200 and advances the playhead.
  Position and status come from that playhead.

What we take from it: the **architecture** (software device on the ARM; the
core keeps registers, a data path and a PCM FIFO; the playhead advances per
frame delivered; volume applied on the ARM). What we do not take: the code.
It is ATAPI-shaped (packet states, IDE registers), lives on a transport this
core does not wire (`EXT_BUS`), and is shared by four cores; the Mac needs the
Apple dialect (CDU-8004 identity, $30 page, $C1 BCD TOC, format-2 full TOC,
$C2/$CC) that MAME's `nscsi_cdrom_apple_device` defines and the current RTL is
byte-exact to. Touching `ide_cdrom.cpp` risks ao486 for nothing.

## 3. What the Mac family already has in Main

`support/mac/` (upstream since PR #1255; the fork adds `macquadra800` to
`is_mac_scsi_family()` and the 4 KB multi-block fill):

- hps_io slots: 0/1 disks, 3 Toolbox, 4 CD-ROM, 5 CD changer.
- `mac_sd_service()` intercepts the sector-service loop for those slots.
  Toolbox/changer slots are a **write-then-read round trip**: op 2 with the
  CDB in the block runs the handler, op 1 at lba 0 reads a status block and
  at lba 1+k the staged reply. The CD slot is read-only windows served by
  `mac_cdrom_fill()`: the data window, the `MCDA` TOC blob at 0x7FFF0000,
  raw 2352-byte CD-DA frames at 0x40000000 + lba (Main keys `blksz` = 2352
  on that window).
- Flat 2048-byte ISOs are `MAC_CDROM_PASSTHRU`: served by the generic
  `sd_image` path, so the TOC-blob read fails there and the RTL synthesizes a
  one-track TOC.

So the transport we need exists on both ends and in the Verilator sim's
block-device model: 512-byte-block reads and writes at magic LBAs on the CD
slot, passed straight through `scsi_cache` (`r_pt`: slot 2 with LBA bit 30 or
31 set, or the whole slot when `CACHE_CD_OFF`). No hps_io change, no new
UIO command, no `EXT_BUS`.

## 4. The contract (new LBA windows on the CD slot)

All new windows sit where no existing core ever addresses (real audio LBAs
end below 0x401C0000). Old cores keep working unchanged. LBAs are in
512-byte units; `op`, `a`, `b` are bytes packed as `op<<16 + a<<8 + b`.

| window | LBA | direction | contents |
|---|---|---|---|
| capability probe | the INQUIRY response window (`0x7E120000`) | read, 1 block | the core reads it after every machine reset and CD mount pulse, while the bus is free, and arms `cd_hps_ok` only if the block starts with the CDU-8004 identity (`05 80 02 02`). Without it the CD target does not answer selection: an old Main or the generic path yields no garbage identity and no hang. The has-data flag rides in the MCDA blob (version 2, byte 12). |
| response | `0x7E000000 + op<<16 + a<<8 + b` | read, 1 block | the DATA IN payload of CD command `op` with the two CDB bytes it depends on: `$12` INQUIRY (54 B); `$1A` MODE SENSE, a = page; `$43` READ TOC, a = cdb[9] format, b = cdb[6] start track; `$C1`, a = cdb[9], b = cdb[5] BCD track; `$42`, a = cdb[3] format, b = cdb[6]; `$C2`; `$CC`, a = cdb[3]. The core serves exactly `clamp(alloc)` bytes from the block, zero-filled, as it does now. |
| command | `0x7D000000 + op<<16` | write, 1 block | the DATA OUT parameter list (MODE SELECT `$15`, AUDIO CONTROL `$CE`) at bytes 0.. exactly where the core's drain left it, the 12-byte CDB at bytes 496..507. For every audio-transport opcode ($45/$47/$48/$4B/$4E/$A5/$01/$0B/$2B, $C8-$CB, $CD), MODE SELECT, eject ($1B LoEj, $C0), PREVENT $1E, SET CD SPEED $BB; pseudo-ops $FF machine reset and $FE SCSI bus reset. The core holds STATUS until the write is acked (the MODE SELECT deferred-ICCS mechanism), so the guest sees one Main poll of extra latency and nothing else. |
| next frame | `0x7C000000` | read, 5 blocks (2560 B, `sd_blk_cnt` 4) | the 2352-byte frame at the ARM playhead, volume applied, then the playhead advances; the pad (bytes 2352..) carries the playback state (playing / paused / end / idle) so the fetch loop knows when to stop without a second transaction. `mac_cdda_window()`'s upper bound tightens to this window so it is served in 512-byte blocks. |

Kept as-is for old cores: the data window, the `MCDA` blob, the raw audio
window. Stays in RTL: TEST UNIT READY, REQUEST SENSE (sense is RTL state),
READ CAPACITY, READ HEADER `$44` (needs the 32-bit LBA; uses the blob's
has-data flag), the no-disc / audio-only CHECKs, eject/prevent state, and
the MODE SELECT parse with its refusal rules (the drive has been
2048-byte-only since 2026-09-08; the ARM mirrors only the page $0E ports
from the forwarded list, for its MODE SENSE).

Latency: a window read is one Main poll (~0.1-1 ms), the same wait the
first sector of every READ already takes; the 53C96 model holds the phase
with `byte_avail` low exactly as for a READ, so the ROM/driver sees nothing
new. If the ROM boot scan's INQUIRY turns out to mind, INQUIRY reverts to
RTL for ~60 ALMs.

## 5. Core side, by phase

**Phase 1: responses from the ARM, playback stays.** `ncr53c96.sv`: the
SY_CDINQ/CDMODE/TOC43(F1/F2)/TOCC1/SUBQ/ASTAT/SUBCH kinds, `cd_inq_byte`,
`cd_mode_byte`, the `c1_*`/`t43_*`/`t2_*` address muxes and the BCD helpers
go; a `SY_FETCH` kind issues the window read into `sbuf` and serves it.
`cd_audio.sv`: the blob parse (M_ACQ..M_BUILT), the `$C1`/`$43`/format-2
builders (M_T43_*, M_T2_*), the three table planes (12 M10Ks) and the
`toc_*` ports go; the engine takes what the playhead still needs
(lead-out, track starts) from the disc-info block plus the existing
per-track blob entries (kept for this phase only). Expected: -700..-900
ALMs, -12 M10Ks. Gate: sim + bench + both OSes + CD on hardware.

**Phase 2: playback on the ARM.** The command block carries every transport
CDB; `cd_audio.sv` shrinks to: FETCH (from the next-frame window, no LBA
bookkeeping, loop while the pad says playing), the two-frame ping-pong
(`frame_ram`, 8 M10Ks, kept), the 44.1 kHz cadence with the linear
interpolation (kept: it is the "CD quality" fix), and nothing else: the
command decode, playhead, track scan, MSF dividers, scan mode, the volume
LUT and its two DSP multiplies go. Status commands come from the response
window. Expected: a further -500..-700 ALMs. Gate: the AppleCD Audio Player
(play/pause/scan/volume slider/status) on a mixed-mode CHD, plus the whole
regression matrix.

Not moving: the hard-disk targets (INQUIRY/$30 page are ~50 ALMs; the data
path is the cache's job), the 53C96 model, `scsi_cache`.

## 6. Main side (fork branch `mac-ethernet-pr-with-SCSI-Optimizations`)

- `mac.cpp`: **`is_mac_scsi_optimized()`** = `macquadra800` only (the user's
  "optimized_scsi cores" list). Every new behaviour is inside it; MacLC,
  MacLCII, MacIIvi, MacPlus, LBMacTwo stay byte-identical. The one shared
  edit, the `mac_cdda_window()` upper bound, is unreachable by a real disc.
- `mac_sd_service()`: op 2 on the CD slot inside the command window (only
  when optimized) runs the command instead of returning -1.
- `mac_cdrom.cpp`: window decode in `mac_cdrom_fill()`; flat 2048 images
  become `HANDLED` for optimized cores (the ARM must serve the windows for
  every image; it also fixes the flat-ISO "Fail to seek" open item and
  gives them the one-track blob). The fill loop can read a 4 KB run in one
  `FileReadAdv` instead of eight while there.
- New `mac_cdrom_resp.cpp/.h`: the response builders, **no Main
  dependencies** (plain functions of the TOC, the playhead and the CDB
  fields) so the Verilator sim compiles the same file.
- New `mac_cdrom_play.cpp/.h`: the playhead (SEARCH/PLAY/PAUSE/STOP/SCAN,
  track and MSF status, the measured `(vol/255)^5` volume law from
  `cd_vol_lut.vh`), semantics transcribed from today's `cd_audio.sv` MAIN
  FSM (MAME/Snow/BlueSCSI oracles), shape borrowed from `ide_cdrom.cpp`.
- Build: rsync to WSL `~/Main_MiSTer`,
  `PATH=/opt/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf/bin:$PATH make -j8`.

Compatibility matrix:

| | old Main (fork 4857af1..b95473b, or upstream) | new Main |
|---|---|---|
| **old core** (20260915) | unchanged | unchanged (blob + raw audio still served; a flat ISO now arrives as a one-track blob instead of zeros: same TOC) |
| **new core** | disc-info magic absent, the CD target hides itself; no writes are ever issued, so no hang | full |
| **other family cores** | unchanged | unchanged (predicate false) |

## 7. Verification

1. **Golden bytes.** A host-side test of `mac_cdrom_resp.cpp` against the
   responses the current RTL produces (dumped from `tb_ncr53c96` and the
   full sim for a flat ISO, a CUE and a CHD): $43 formats 0/1/2 for every
   start track, $C1 for every base/track, INQUIRY, the four MODE SENSE pages.
   The RTL is the oracle (hardware-validated, MAME-exact). Where the RTL
   capped a table for area (60 descriptors in format 0, 41 tracks in format
   2) the ARM serves the full 99; that is the only intended difference.
2. **`tb_ncr53c96`**: the synthetic device serves the windows from vectors
   the golden test writes out; T16 keeps passing.
3. **Full-machine sim**: `sim_blkdevice.cpp` links `mac_cdrom_resp.cpp` +
   `mac_cdrom_play.cpp` (copied by `scripts/sim_wsl.sh build` from
   `../Main_MiSTer/support/mac/`), so Mac OS 8.1 boots with a CD and the
   AppleCD player runs in sim before any hardware.
4. **QEMU** stays the SCSI oracle: `SCSI_TRACE` diff of the ROM's CD-boot
   sequence (the 512-byte MODE SELECT dance) before/after.
5. **Hardware, the .143 box**: the release gate (8.1 + A/UX boot and clean
   shutdown) plus Open Transport ISO mount/eject, the retail 8.1 ISO booted
   from CD, TIM CHD audio, A/UX mounting the OT disc; and the matrix above
   (old core on new Main, new core on old Main).
6. **Area**: `build_only.sh --check` for the logic-cell delta after each
   phase, then a full fit and the seed policy in CLAUDE.md.

## 8. Decisions (taken 2026-09-16, the user went with the recommendations)

1. **No RTL fallback.** The new core's CD-ROM needs the fork Main for any
   image; on an older Main the CD target hides itself.
2. **Both phases are planned; phase 2 is gated** on phase 1's measured
   saving and hardware behaviour.
3. **INQUIRY and MODE SENSE go through the window.** INQUIRY reverting to
   RTL (~60 ALMs) is the documented escape hatch if the ROM boot scan minds
   the latency.
4. **`is_mac_scsi_optimized()`**, single member `macquadra800`.
5. Hardware for this work is the **.143** box (user, 2026-09-16).

## 9. Progress (tick as work lands; keep current between commits)

Main side first, on `../Main_MiSTer` branch
`mac-ethernet-pr-with-SCSI-Optimizations`:

- [x] M1 `is_mac_scsi_optimized()` in `mac.cpp`/`mac.h`; window constants in
      `mac_cdrom.h`; `mac_cdda_window()` upper bound = the next-frame window
- [x] M2 `mac_cdrom_resp.cpp/.h`: pure builders (INQUIRY, MODE SENSE pages,
      $43 formats 0/1/2, $C1, $42, $C2, $CC, MCDA blob v2 with the has-data
      flag), byte-exact to today's RTL including its caps (60 / 41 tracks)
- [x] M3 golden-bytes test (core commit `verilator: cd_audio table-dump
      bench...`): `scripts/cd_resp_golden.sh` = `tb_cd_audio_dump` dumps +
      host test; **6,304 checks, 0 failures** on 2026-09-16 (flat ISO, mixed,
      99 and 70 tracks; volume law all 256 entries)
- [x] M4 `mac_cdrom_play.cpp/.h`: the playhead (transcribed from
      `cd_audio.sv` M_CMD/M_APPLY/M_SCAN_GO/M_REF_*), MODE SELECT mirror
      (page $0E ports; the RTL refuses 512-byte blocks since 2026-09-08, so
      there is no blk512 any more), volume law + channel routing,
      reset/eject/data-read/bus-reset semantics; unit-tested in M3
- [x] M5 windows in `mac_cdrom_window_fill()` (response, next frame) and
      `mac_cdrom_command()`; routed by `mac_sd_service()` for optimized cores
      mounted or not; blob v2 for optimized cores only; flat 2048 images
      HANDLED for optimized cores; one read per 4 KB run for flat files
- [ ] M6 build in WSL (`scripts/build_main_wsl.sh`; fork `b692e0d` built
      2026-09-16, staged as `scratch/MiSTer_<md5>`), install on .143 (only
      at a halt screen or the menu), regress the old core: flat ISO
      mount/eject, CHD audio, both OS gates unaffected. Box facts
      2026-09-16: `/media/fat/MiSTer` = release fork `916829ff` (4857af1);
      `_Unstable/MacQuadra800.rbf` = `512cd4f8` (the Sep 8 build M, pre-
      optimization: a valid "old core"); `.s0` QuadSquad8, `.s1`
      MacQuadra800FreshTest, `.s4` MAC_OS_8-1_RETAIL.ISO (flat); no CHD on
      the box yet (TIM_3-mac.chd lives on .92). `scripts/local.env` now
      names .143.
- [ ] M7 docs: `docs/cdrom.md` contract section, this file, commit

Core phase 1 (responses from the ARM, playback stays), branch `optimize-SCSI`:

- [ ] C1 `ncr53c96.sv`: a window read is a one-block platform READ whose
      serve length is the CDB's clamped allocation (`rd_len` replaces the
      fixed 512 on ack-fall); CD INQUIRY / MODE SENSE / $43 / $C1 served
      that way; the CD SY_* kinds, `cd_inq_byte`/`cd_mode_byte`, the
      $C1/$43/format-2 address muxes removed; MODE SELECT (after the parse
      accepts it) / eject / machine + bus reset forwarded through the
      command block (CDB copied to sbuf[496..507] by the synth sequencer,
      `io_wr` at CMD_BLK, STATUS held until the ack like `iccs_pend`);
      capability probe = an INQUIRY window read after reset and on every
      mount, "SONY" at bytes 8..11 arms `cd_hps_ok`, without which the CD
      target does not answer selection (old Main: no garbage identity)
- [x] C2 `cd_audio.sv`: builders and the three table planes removed; blob v2
      header parse keeps n_tracks / lead-out / has-data (the version byte
      guards the flag; the probe in C1 is what hides the target on an old
      Main)
- [x] C3 `MacQuadra800.sv`: CD slot `sd_wr` untied for the command block
      (`scsi_cache` already passes slot-2 writes at LBA bit 30/31 through)
- [x] C4 (bench half) `tb_ncr53c96` serves the windows through
      `cd_win_dpi.cpp` -> `sim/cd_window.cpp` -> the Main fork's own
      builders (mirrored by `scripts/sync_main_mac.sh`): **476,837 checks,
      0 failures**; the same device is in `sim_blkdevice.cpp` for disk 2.
      Found on the way: a forwarded write must not pose as the nexus's
      flush (`nexus_io`), the probe must never touch the buffer, and a
      held ICCS must die with its nexus.
- [ ] C4 (sim half) full sim boots the gate image with `cd.iso` on the
      CD-ROM: ROM scan (probe, INQUIRY window, MODE SELECT forward), then
      the Apple CD-ROM extension's mount. First attempts stalled in the
      *sim's block-device model*, not the RTL: its mount countdown shares
      `ack_delay` with transfers and, expiring while the probe was held,
      raised an ack for nothing and never dropped it (fixed, `+blkdbg` now
      traces ack edges). With the fix, 1.5 G cycles of the Quad Squad copy
      + `cd.iso`: reset notice ($FF) and both ROM bus resets ($FE) written
      to the command block, the probe read the INQUIRY window after reset
      and after the mount pulse (`0580 0202 -> cd_hps_ok=1`), blob v2
      fetched, the ROM's CD block-0 read served in one 8-block group, the
      hard-disk boot streaming. The ROM scan issues no INQUIRY/TOC; the
      response window's first use is the Apple CD-ROM extension. The
      4.8 G-cycle run (145 s of machine time, pre-`f612084` RTL) shows it:
      INQUIRY window reads, MODE SENSE page 0 and page $0E reads, two
      accepted MODE SELECT lists forwarded through the command block,
      twelve CD data-window reads by the driver, the machine still
      running at the end (no TOC request yet within the run; the
      hardware CD boot already proved $43/$C1). A longer run with
      screenshots on the rebuilt sim follows
- [~] C5 `build_only.sh --check`: `cd_audio` 2,566 -> 1,535 ALUTs. **Full
      fit (seed 22, the release recipe, 2026-09-16 08:00): 38,070 ALMs
      (91 %), -568 vs the shipped 38,638; `ncr53c96` 2,469 (was 2,870),
      of which `cd_audio` 994 (was 1,346); RAM 491/553 (was 497); DSP 59
      (was 64); registers 25,471 (was 25,605). Timing: clk_sys (33 MHz CPU
      clock) VIOLATED -0.931 ns, TNS -2.585; HDMI +0.003; clk_ram +1.054.**
      TimeQuest (`scratch/clk_sys_paths.tcl`): all 40 worst paths are
      inside `ap040_core` (`rr_a` -> `epf_data`, `pc` -> `state`), none in
      the SCSI logic: the placement lottery, not the change. **Seed 21
      (worktree wt2, 08:26): 38,012 ALMs, clk_sys +0.712, clk_ram +0.914,
      HDMI -0.076 (one `sys_top` video register)** = the hardware
      candidate, `scratch/MacQuadra800_phase1_s21_58653a0c.rbf`, staged on
      .143 as `_Unstable/MacQuadra800_phase1_s21.rbf`; seed 21 is now the
      qsf default. Hardware gate on .143 so far: retail ISO CD boot PASS,
      the slot-1 disk mounts, A/UX boot PASS with the CD mounted, `uname`
      matches; A/UX `shutdown -h now` wedges, and does so identically on
      the shipped 20260915 with a CD in slot 4 (pre-existing, see the log).
      Still owed: 8.1 from disk (the Quad Squad volume repaired, or the
      slot-1 image as startup), OT ISO mount/eject, CHD audio. **The
      rebuild with the serialized forwards (`f612084`, seed 21, 10:00)
      MEETS TIMING: 38,128 ALMs (91 %), worst +0.247 ns (HDMI +0.442,
      clk_sys +0.729, clk_ram +0.732), RAM 491, DSP 59; rbf `1eae0fb7`,
      `scratch/MacQuadra800_phase1_s21b_1eae0fb7.rbf`, staged on .143 as
      `_Unstable/MacQuadra800_phase1_s21b.rbf`** -- the release-quality
      candidate for the rest of the gate
- [ ] C6 commit + measured numbers in this file and `docs/area-budget.md`

Core phase 2 (playback on the ARM), gated on C5's numbers:

- [ ] D1 transport CDBs forwarded; status ops from the response window;
      FETCH from the next-frame window; MAIN FSM, dividers, volume LUT gone.
      Sketch from the phase-1 mechanics: every opcode that today raises
      `ca_cmd_stb` calls `fwd_cdb(cdb[0])` instead (STATUS held until the
      ack, as MODE SELECT is now); `$42`/`$C2`/`$CC` become `fetch` calls
      (a = cdb[3], b = cdb[6]); `cd_audio.sv` keeps only the blob header
      parse (mounted / has-data), a fetch loop that reads `$7C000000` as a
      5-block transaction into the free frame half whenever the last pad
      said "playing" (byte 2352 = 0) or a transport command was just
      forwarded, drops both halves when the pad's flush generation
      (2354..2357) changes, and the SAMPLE cadence + interpolation as is;
      the ARM applies volume, so the LUT and its two multipliers go. The
      raw-audio window and the MODE SELECT page-$0E ports leave the RTL.
- [ ] D2 sim + bench; AppleCD Audio Player gate on .143 (play/pause/scan/
      volume/status) with a mixed-mode CHD
- [ ] D3 `--check` delta, fit, gate, release entry, `docs/cdrom.md`,
      `releases/README.md`, commit

## 9b. Phases remaining (2026-09-16 hand-off)

Three, in this order. Each ends with a hardware gate on .143, a release
entry and a commit; the sim is only for short directed reproductions.

**Phase 1 close-out (core rbf `1eae0fb7` staged, timing met):**

- [~] P1a `.s0` back to Quad Squad (`cp -p .s0.quadsquad .s0`), load
      `_Unstable/MacQuadra800_phase1_s21b.rbf` (both DONE 11:35; the box
      was found at 12:05 on that core at the halt screen with `.s0` Quad
      Squad, `.s4` retail ISO), the 8.1 gate (operator run from 12:15,
      brief `scratch/p1a/BRIEF.md`, evidence `scratch/p1a/`): Finder,
      clock ticking for several minutes, the retail ISO's icons, open the
      CD, hot-mount the OT ISO from the OSD (a new disc: the probe re-arms,
      the driver must see it by TEST UNIT READY), eject it from the Finder
      (the eject forward), Speedometer Mix unchanged (0.858 reference),
      Special -> Shut Down to the halt screen
- [ ] P1b A/UX with `.s4` EMPTY: boot, `uname -a`, `shutdown -h now` to the
      halt screen (the 20260915 gate conditions); with a CD it wedges on
      the shipped core too, see the W track
- [ ] P1c old-core compatibility: the 20260915 rbf on Main `898854ef` still
      boots 8.1 with the retail ISO (flat ISO now HANDLED, no repulse)
- [ ] P1d release: `releases/MacQuadra800_YYYYMMDD.rbf` + README row and
      section (md5, seed 21, +0.247 ns, 38,128 ALMs, "requires the Main
      fork `ae708d3` or later for any CD image"), `docs/area-budget.md`
      numbers, commit; the user pushes both branches

**W. The A/UX shutdown wedge with a CD mounted** (pre-existing in
20260915; the same VRAM streaks + stopped CPU on both cores; the passing
gate had no CD):

- [ ] W1 pin it: on 20260915, A/UX boot + `shutdown -h now` with `.s4`
      empty (expect the halt screen) and again with the OT ISO (a second,
      smaller disc) -- if only the CD runs wedge, it is the CD path at
      shutdown
- [ ] W2 the golden reference: QEMU `q800` with the same A/UX image and
      the retail ISO as scsi-cd (`../qemu`, the recipe in the
      `qemu-golden-reference` memory): does A/UX halt cleanly there? Trace
      its CD traffic at shutdown (QEMU scsi trace events) to learn what
      A/UX sends: eject (START/STOP), PREVENT/ALLOW, TEST UNIT READY after
      the eject, a bus reset
- [ ] W3 the core side: a `SCSI_TRACE` debug build (qsf switch, hijacks
      the serial port) of the phase-1 head, the same shutdown, capture the
      last commands before the freeze; diff against W2. Suspects: an eject
      while the RTL holds STATUS, TEST UNIT READY on an ejected disc
      returning NOT READY / $3A where A/UX expects $B0 or GOOD, the RTL's
      `cd_present`/`cd_ejected` state after the eject, a bus reset owed by
      the halt path meeting the forwarded notice. MAME's model (unit
      attention on media change, `$B0` no-disc) is the reference for the
      right answer
- [ ] W4 fix, bench test for the sequence, rebuild, both A/UX gates (with
      and without a CD) on .143, release entry; add "A/UX shutdown with a
      CD mounted" to the standing regression gate in CLAUDE.md

**Phase 2 (playback on the ARM), gated on P1d and W4:** D1..D3 below.

## 10. Log

- 2026-09-16: plan approved; Main side started.
- 2026-09-16 06:52: fork `b692e0d` built (`MiSTer` md5 `399daf2e…`,
  `scratch/MiSTer_399daf2e`) and installed on .143 from the menu core;
  the previous binary is `/media/fat/MiSTer.bak_20260916_916829ff`. The
  20260915 release rbf is staged as `_Unstable/MacQuadra800_20260915.rbf`
  for the old-core regression.
- 2026-09-16 06:55: old core (20260915) + new Main + retail 8.1 ISO (now
  HANDLED, "raw image, 1 track"): Finder at ~06:53 with no CD icon, then by
  06:54 the disc is mounted with ONE "Mac OS 8.1" icon and its root window
  auto-opened (17 items). The Main read the disc through the flat-file run
  path (track fd at 1.89 MB). Two icons were the 20260908_3 behaviour on the
  generic path; the 20260915 rbf was gated on .92 with no CD in slot 4, so
  the control run (same core + disc on the old Main `916829ff`) follows
  (an Opus operator is running the A/B on .143).
- 2026-09-16 08:10, the A/B (operator report, screenshots in
  `scratch/ab_cd/`): **the two icons are guest-side and identical on both
  Mains** (two independently mountable volumes from the one flat ISO; my
  "one icon" was the second hidden behind the open windows). **The new
  Main hung the old core's boot**: with flat ISOs now HANDLED the 60 s
  boot repulse fires for them too, its re-insert landed at T0+54 s while
  the extensions loaded, and the boot froze one icon short of the Apple
  CD-ROM extension (10 min, zero I/O); the old Main never repulses a flat
  ISO and booted to the Finder both times. Fix: no repulse for optimized
  cores (fork `ae708d3`; the Quadra core replays mounts after reset
  itself), Main `898854ef` installed 08:15 with a forced core reload of
  the hung guest (backup `QuadSquad8.hda.gz` of Aug 31 on the box). Also
  from the run: the remote mouse was dead on the first new-Main session
  and fine after the core reload (a wedged ADB mouse, not a Main change,
  most likely); `mac_shutdown.sh` / `shutdown_finder.sh` aim at Help
  (x=229) where this Finder has Special at x=181.
- 2026-09-16 08:20, **the repulse-as-cause story is withdrawn** (the user:
  look at MAME instead). MAME `nscsi_cdrom_device` (`src/devices/bus/
  nscsi/cd.cpp`): `device_reset` syncs a media sequence counter, so a
  disc present at boot raises nothing and the driver finds it by TEST
  UNIT READY = GOOD; any later load/unload makes the next non-INQUIRY
  command CHECK with sense key 06 UNIT ATTENTION (the Apple variant
  inherits this through its default arm); no disc = NOT READY / $B0.
  There is no re-insert timer anywhere: a re-mount of the same image IS a
  media change to MAME and the driver would re-examine the disc. What the
  evidence actually supports: the old core on the new Main booted to the
  Finder twice and hung once at the Apple CD-ROM extension's INIT; the
  RTL ignores a same-disc mount pulse and `hps_io` 'h1c is a plain pulse,
  so the repulse has no path into an in-flight transfer; the hang is
  unexplained and may be the checkpoint-15 boot race family
  (`ck15-hardware-boot-hang`, "~15 %" before 15be2a2). The repulse stays
  off for optimized cores because MAME has no such thing, not because it
  is proven guilty. The forced reload (08:14) left the Quad Squad volume
  unbootable: the ROM booted the retail CD instead (its Finder, one
  volume icon); `QuadSquad8.hda` needs Disk First Aid or the Aug 31
  backup -- the user's call.
- 2026-09-16 08:30, **phase-1 core on hardware** (seed-21 rbf, Main
  `898854ef`): loaded from the CD-booted Finder (nothing writable was
  mounted), the ROM booted the retail 8.1 CD again through the new
  windows -- INQUIRY, TOC and the data reads all served by Main -- Finder
  in ~100 s (`scratch/p1_boot3.png`), and the fresh 8.1 disk on slot 1
  ("MacOS8-MiSTer") mounted, so the hard-disk path is intact. The Finder
  offered to *initialize* the unreadable 1.9 GB Quad Squad volume
  (Initialize the default button); cancelled with Escape via
  `MISTER_HOST=192.168.99.143 python scripts/mister_ws.py raw:1`. The
  volume is damaged, not just dirty.
- 2026-09-16 08:40: the CD-booted Finder shut down cleanly by an Opus
  operator (Special -> Shut Down driven closed-loop against
  `scripts/guest/probe_cursor.py`; both scripted walkers fail on this
  Finder, a follow-up task chip carries the calibration). Command is
  Left Alt (keycode 56) in this core's ADB map, not keycode 125. Box at
  the halt screen; the A/UX half of the gate started on the phase-1 core
  with `.s0` switched to `HD60_512-AUX3.1-Installed.hda` (the Quad Squad
  name saved as `.s0.quadsquad`).
- 2026-09-16 09:30, **A/UX gate on the phase-1 core (seed 21)**: boot PASS
  (551 s with a 357 s fsck of the unclean volume, ~194 s otherwise vs the
  148 s reference), `uname -a` = `A/UX localhos 3.1 SUR2 mc68040`, the
  retail ISO mounted under A/UX's Finder (17 items) through the windows;
  **`shutdown -h now` WEDGED** after the RPC port-mapper message: screen
  frozen 19.5 min with white streaks of random coloured pixels in VRAM
  (`scratch/p1_aux/71_zoom_streaks.png`), read/write bytes flat, cursor
  dead (operator report, `scratch/p1_aux/`). The 20260915 release passed
  this shutdown in 127 s, and Alan's unreleased 299cb36 had an A/UX
  shutdown wedge, so a control run of the same boot + shutdown on the
  shipped 20260915 rbf is running before phase 1 is blamed. No `Mac CD:`
  forwards in the Main log (a data-only disc logs none). Possible
  suspects if it is phase 1: the ROM's shutdown eject of the CD ($1B/$C0)
  now forwarded with STATUS held, or a bus-reset notice ($FE) issued while
  the halt path expects the channel.
- 2026-09-16 09:45: walking that sequence found a real hole: a nexus
  forward (eject, MODE SELECT) raised while the bus-reset notice was still
  being written overwrote `fwd_st`, so the notice's ack-fall published the
  buffer as if a read had landed and the second block went out from a
  half-reset state. Forwards now queue (`fwd_q`): the second starts when the
  first is acked, STATUS stays held for both, a queued forward dies with
  its nexus. Bench test T18 (bus reset, then the eject selected 60 cycles
  later on a 3000-cycle device: both blocks reach the ARM, GOOD, TUR then
  CHECKs) added. Whether this is the A/UX wedge is still open: the control
  run on 20260915 decides whether phase 1 is implicated at all.
- 2026-09-16 09:55, **control run on the shipped 20260915 rbf** (operator,
  `scratch/aux_control/`): same boot (desktop at 554 s incl. fsck, the
  retail ISO mounted on the A/UX desktop, `uname` identical), same
  `shutdown -h now` **wedge**: `callrpc RPC: Port mapper failure`, five
  `kill: pid=` lines, then the VRAM streaks and a stopped CPU, frozen
  376 s with flat I/O; the phase-1 core had frozen a few lines earlier.
  **The A/UX shutdown wedge is pre-existing in 20260915, not phase 1.**
  The release gate that passed this shutdown in 127 s ran with no CD in
  slot 4; both wedged runs had the retail ISO mounted, so the CD's
  presence at shutdown (A/UX unmounting / ejecting it) is the prime
  suspect. A no-CD control run would settle it, at the cost of another
  reload of a wedged guest (the A/UX volume fscks each time). Box left
  wedged on 20260915, `.s0` = A/UX, `.s4` = retail ISO.
- 2026-09-16 10:00: the phase-1 head with the serialized forwards
  (`f612084`) fits at seed 21 with timing met (+0.247 ns; 38,128 ALMs,
  -510 vs the shipped 38,638), rbf `1eae0fb7`, staged on .143 (not
  loaded: the box is wedged pending the user's decisions).
- 2026-09-16 10:15, the user: spend less time on the sim (it is really
  slow), focus on the MiSTer directly; restore the Quad Squad disk from
  the backup rather than repairing it from the CD boot. The 7 G-cycle sim
  run was stopped; `QuadSquad8.hda` is being restored from
  `backup/QuadSquad8.hda.gz` (the damaged image kept as
  `QuadSquad8_damaged_20260916.hda`); next: `.s0` back to Quad Squad,
  load the timing-clean phase-1 rbf, the 8.1 gate with the OT ISO.
- 2026-09-16 10:25, session hand-off: the restore completed
  (`QuadSquad8.hda` 2,146,461,696 bytes, md5 `1a40aa8a77af35cabfe76d4dea9ccf13`
  = the Aug 31 backup). Box: 20260915 rbf loaded, A/UX wedged
  mid-shutdown, `.s0` = A/UX image (`.s0.quadsquad` = the Quad Squad
  name), `.s4` = retail ISO, Main `898854ef`. Nothing pushed on either
  branch. Next session: `.s0` -> Quad Squad, `load_core
  _Unstable/MacQuadra800_phase1_s21b.rbf` (1eae0fb7), the 8.1 gate, then
  A/UX with `.s4` empty, then the release entry; phase 2 after that.
- 2026-09-16 11:10, the shutdown walkers recalibrated (the 08:40
  follow-up): `scripts/mac_shutdown.sh` is the one walker
  (`guest/shutdown_finder.sh` and `guest/shutdown.sh` run it) and follows
  the operator's closed loop: the pointer is found against the pinned frame
  and put on Special (x=181) with the button up, the press comes only then,
  and the release happens in place only when the lit row sits on the panel's
  bottom border (Shut Down). Exit 0 means the halt screen was seen; every
  trappable exit sends `left_up`, and `--release` frees the button after a
  kill. A/UX's Finder is refused (its Special menu ends in Logout). New
  `scripts/finder_probe.py`. Offline, a simulated guest built from today's
  frames ran the real script through 26 cases (scale 1.2-2.5 px/event,
  jitter, coalescing, a window behind the menu, refusals, dead capture,
  signals mid-walk) with no wrong selection. Not yet run on .143.
- 2026-09-16 11:35, **the reload (user go-ahead) and the walker on
  hardware**: the wedged A/UX guest (write_bytes flat 30 s, frame
  unchanged since 11:12) was reloaded with `.s0` -> Quad Squad (the A/UX
  name saved as `.s0.aux`) into the phase-1 core `1eae0fb7`
  (`load_core _Unstable/MacQuadra800_phase1_s21b.rbf` at 11:35:08).
  Quad Squad booted to the Finder by 11:37:26 with the retail ISO in slot
  4 (its window auto-opened, the two guest-side CD icons as before), no
  dialogs; write_bytes flat for 60 s and the menu-bar clock ticking.
  `bash scripts/mac_shutdown.sh` then shut it down on the first try in
  58 s: pointer on Special at (181,8) at 1.49 px/event, the panel border
  read at y=112 with the CD window behind it, one 64-event walk onto Shut
  Down (96..111), halt screen 22 s after the release, exit 0
  (`scratch/walker_hw/`). Box: phase-1 core loaded, at the "safe to
  switch off" screen, I/O idle; `.s0` = Quad Squad, `.s1` FreshTest,
  `.s4` retail ISO. For the 8.1 gate on phase 1 this covers boot to the
  Finder, a 2-minute idle and the mouse-driven shutdown; the
  several-minute idle clock, keyboard, CD icons and the OT ISO hot
  mount/eject are still to do.
- 2026-09-16 12:05, resume: the box was already on the phase-1 core
  `1eae0fb7` (the MiSTer process command line names
  `_Unstable/MacQuadra800_phase1_s21b.rbf`), at the Mac OS 8.1 halt screen
  from the 11:39 walker run, `write_bytes` flat, `.s0` Quad Squad, `.s1`
  FreshTest, `.s4` retail ISO, Main `898854ef`. So P1a's reload half is
  done; the rest of the 8.1 gate (idle clock, keyboard, CD icons/window, a
  Finder eject = the eject forward, the OT ISO hot mount from the OSD = the
  probe re-arming on a different-size disc, its eject, the retail re-mount,
  three Speedometer Mixes against 0.858, `mac_shutdown.sh`) went to an Opus
  operator at 12:15 (`scratch/p1a/BRIEF.md`). Facts for the brief: Main's
  stdout is `/media/fat/nohup.out` (every CD mount logs `Mac CD: raw image,
  1 track(s), leadout N`; the OT ISO is 3473 sectors, the retail ISO
  205343, NetBSD 176484; forwarded ejects/MODE SELECTs are not logged, only
  the audio-transport set), screenshots do not show the OSD (it is overlaid
  after the scaler buffer the capture reads), the OSD opens with its cursor
  on the first item and the slot-4 browser on the mounted file, so the hot
  mount is the blind sequence F12, Down x2, Enter, Down x2, Enter, F12. In
  the RTL a Finder eject leaves the disc out until the next bus reset or a
  different-size mount pulse (a same-size re-mount is a no-op), hence the
  order eject retail, mount OT, eject OT, re-mount retail.
- 2026-09-16 07:40: core phase 1 committed (`3d5e32d`): tb_ncr53c96
  476,837 / 0. Analysis & Synthesis (`--check`): `cd_audio` 1,535 ALUTs /
  707 regs (was ~2,566 / 852), `ncr53c96` own 2,571 ALUTs. Full build
  launched 07:38 (`scratch/build_phase1.log`, sgiindy fitting alongside);
  full-machine sim rebuilt after a WSL restart, CD boot run pending.
