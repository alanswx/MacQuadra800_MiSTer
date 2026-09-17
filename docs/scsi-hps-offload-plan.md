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

- [x] D1 (2026-09-16 12:55, `d5442fe` on `optimize-SCSI`) transport CDBs
      forwarded; status ops from the response window; FETCH from the
      next-frame window (5 blocks: `e_blk_cnt` through the cache); MAIN
      FSM, dividers, volume LUT gone; the status poke after each forward;
      the forward-request gating race found by T19 (a forward raised during
      a frame fetch went out at the frame window's address).
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
- [~] D2 bench: `tb_ncr53c96` 476,872 / 0 (T19), `tb_scsi_cache` 279,315 / 0
      x2; **`--check` 12:59 clean: `cd_audio` 371 ALUTs / 320 regs (phase 1:
      1,535 / 707; before the offload 2,566 / 852), `ncr53c96` self 2,329
      (was 2,571), the target with its engine 2,700 (was 4,106), DSP 43 (was
      59), block memory -8 Kbit (the blob RAM)**; seed 21 failed in routing,
      **seed 22 MEETS TIMING (13:50): 37,155 ALMs (89 %, -973 vs phase 1,
      -1,556 vs 20260915), clk_sys +0.232 / clk_ram +0.452 / HDMI +0.638,
      25,231 regs, 490 RAM, 43 DSP; fitted `ncr53c96` 1,639 (self 1,408,
      `cd_audio` ~230; phase 1: 2,568 / 1,569 / 999); rbf `c2a902cb` =
      `scratch/MacQuadra800_phase2_s22_c2a902cb.rbf`, staged on .143 as
      `_Unstable/MacQuadra800_phase2_s22.rbf`; seed 22 is the qsf default**;
      **gate 18:15: 8.1 + retail ISO PASS, A/UX (32 MB) PASS, the AppleCD
      Audio Player FAILS ("not responding" ~7 s into Play, 2/2) -- see the
      log**. **Fixed 2026-09-16 19:35 (`3ec22e4`, on top of the owner
      register `97ea3eb`): the real bite was `abort_nexus` arming
      `io_discard` on io_busy = also the engine's transfer, so a guest
      command selected during a frame fetch lost its own first read (the
      player's status poll read nothing); T20 rewritten as a forced
      same-cycle collision on a slot-faithful platform model, 477,415 / 0,
      and 527 failures against the pre-owner RTL; fit at seed 22 launched
      19:38 (`scratch/build_phase2b.log`)**. Still owed after the fix: the
      AppleCD Audio Player gate on .143 (play/pause/scan/volume/status) with
      the 4-track `AudioTest.cue` the operator built (the PC Engine CHDs
      are mixed-mode and do not mount); old note:
      `TIM_3-mac.chd` is on neither box, but .143 has PC Engine CD CHDs with
      audio tracks in `games/TGFX16-CD/` (Valis II/III/IV, Rainbow Islands,
      Prince of Persia) that the Audio CD Access extension mounts as an
      Audio CD
- [~] D3 **fit of the fixed head (`3ec22e4`): seed 22 failed in routing,
      seed 23 fits but clk_sys -0.752 ns (rbf `0d374d4a`, the fix probe
      on hardware), seed 24 MEETS TIMING (20:43): worst +0.244 ns (HDMI
      +0.255, clk_sys +0.762, clk_ram +0.605), 37,056 ALMs (88 %), 25,269
      regs, 490 RAM, 43 DSP; rbf `4bf9629c` =
      `scratch/MacQuadra800_phase2b_s24_4bf9629c.rbf`, staged on .143 as
      `_Unstable/MacQuadra800_phase2b_s24.rbf`; seed 24 is the qsf
      default.** Gate brief `scratch/p2c/BRIEF.md` (the full gate incl.
      A/UX at 32 MB), then the release entry (`scratch/release_phase2_draft.md`
      has the numbers), `docs/cdrom.md` (done), `releases/README.md`, commit

## 9b. Phases remaining (2026-09-16 hand-off)

Three, in this order. Each ends with a hardware gate on .143, a release
entry and a commit; the sim is only for short directed reproductions.

**Phase 1 close-out (core rbf `1eae0fb7` staged, timing met):**

- [x] P1a **PASSED 13:11** (operator run 12:13-13:13, `scratch/p1a/report.md`):
      Finder at T0+126 s (the retail CD's window auto-open, 17 items, the two
      guest-side icons), the idle clock in step with wall time over 4 min
      (`write_bytes` flat), Cmd+W / Cmd+O (the directory read through the
      response windows), both guest volumes of the retail disc put away
      from the Finder within 9 s each (the eject forward: no dialog, no
      freeze), the OT ISO hot-mounted from the OSD (`Mac CD: ... leadout
      3473`, the Finder icon within 30 s, its window 9 items), put away,
      the retail disc re-mounted (one icon this time), `mac_shutdown.sh`
      exit 0 in 61 s. **Speedometer NOT run: the app is not on the restored
      Aug 31 Quad Squad image** (Find File: 0 items; the 0.858 runs used
      the .92 box's image) -- the CPU/SDRAM path is unchanged from 20260915,
      so the release entry says "not re-measured". Lesson: after a file is
      chosen the OSD closes itself; a trailing F12 re-opens it and eats the
      keyboard. The plan text was: Finder,
      clock ticking for several minutes, the retail ISO's icons, open the
      CD, hot-mount the OT ISO from the OSD (a new disc: the probe re-arms,
      the driver must see it by TEST UNIT READY), eject it from the Finder
      (the eject forward), Speedometer Mix unchanged (0.858 reference),
      Special -> Shut Down to the halt screen
- [ ] P1b **FAILED 13:31 -- WEDGE WITH NO CD** on the phase-1 core (after
      the 6-min fsck; `uname` fine; `scratch/p1b/report.md`). Then, on the
      pristine image, **W1a (20260915, no CD) WEDGED too (13:52)** and
      **W1b (20260915, OT ISO) wedged**: the CD does not decide whether it
      wedges, only how far the shutdown gets (the no-CD runs freeze right
      after the port-mapper line, the CD run reached the `kill: pid=`
      lines). Typed characters after the wedge add streaks = the kernel
      console echoing at 1 bpp: **the kernel is alive, the shutdown is
      hung, not halted**. The same 20260915 rbf, ROM and image passed this
      shutdown on the .92 box (127 s), whose Main is the Aug 28 fork build
      `d6d63ec4` (.143 runs today's `898854ef`); this core has no working
      Ethernet (the SONIC decode is inert), so the network is not it.
      P1b as written: A/UX with `.s4` EMPTY: boot, `uname -a`, `shutdown -h now` to the
      halt screen (the 20260915 gate conditions); with a CD it wedges on
      the shipped core too, see the W track
- [x] P1c PASSED 15:15 (operator): the 20260915 rbf on Main `898854ef`
      boots 8.1 with the retail ISO (Finder T0+130 s, the CD window, the
      two guest-side icons), `mac_shutdown.sh` exit 0 -- no freeze at the
      extension icons this time (the morning's one hang stays unexplained)
- [x] P1d RELEASED 18:20 as `releases/MacQuadra800_20260916.rbf`
      (`1eae0fb7`): the A/UX check at 32 MB on the phase-1 rbf passed
      (desktop T0+120 s, halt in 131 s, operator step A, `scratch/p2/`);
      README row + section, the 128 MB note; the user pushes. Old text:
      `releases/MacQuadra800_YYYYMMDD.rbf` + README row and
      section (md5, seed 21, +0.247 ns, 38,128 ALMs, "requires the Main
      fork `ae708d3` or later for any CD image"), `docs/area-budget.md`
      numbers, commit; the user pushes both branches

**W. The A/UX shutdown wedge with a CD mounted** (pre-existing in
20260915; the same VRAM streaks + stopped CPU on both cores; the passing
gate had no CD):

- [x] W1 pinned the other way (13:52-14:40, `scratch/p1b/report.md`): on
      20260915 the shutdown wedges WITHOUT a CD (pristine image) and with
      the OT ISO alike -- **it is not the CD path**; the trigger is in the
      .143 environment, and the one difference left against the passing
      .92 run is the Main build (Aug 28 fork `d6d63ec4` there, today's
      `898854ef` here). W1c (20260908_3 + retail ISO) was in progress at
      14:55; next: W1d = 20260915, no CD, pristine image, with the .92
      Main (`/media/fat/MiSTer.aug28_d6d63ec4`, staged on .143) installed
      -- a halt there pins the Main; and the W3 trace run, which shows
      whether a disk write is left without its ack (a hung `sync` with a
      live console is exactly that). **W1c (20260908_3 + retail ISO, the
      older CPU) wedged as well (15:02)**: three cores, two CPU
      generations, with and without a CD -- not the core.
- [x] W2 DONE 13:20 but NOT a golden reference for the halt path: QEMU's
      A/UX stalls at `INIT: New run level: S` with and without the CD (31
      min), before the teardown the MiSTer reaches; what it did establish
      (`scratch/w2/`): no CD command from Return to the stall, the disc
      PREVENT-locked from mount on, the boot identification set, and that
      A/UX's kernel text console draws 1 bpp regardless of the frame's
      depth (the QEMU streaks decoded to the console text). The golden
      reference: QEMU `q800` with the same A/UX image and
      the retail ISO as scsi-cd (`../qemu`, the recipe in the
      `qemu-golden-reference` memory): does A/UX halt cleanly there? Trace
      its CD traffic at shutdown (QEMU scsi trace events) to learn what
      A/UX sends: eject (START/STOP), PREVENT/ALLOW, TEST UNIT READY after
      the eject, a bus reset
- [ ] W3 -- NOT NEEDED as a wedge control any more (the wedge is the
      128 MB RAM setting, W1f); keep the build for the 128 MB follow-up.
      (The debug build of `ba67548` + SCSI_TRACE=1, seed 21, done
      13:05 in `../MacQuadra800_wt2`: rbf `efcf5ffb`, 39,830 ALMs (95 %),
      HDMI -0.351 ns, clk_sys +0.157, clk_ram +0.162 -- a video-only miss;
      `scratch/MacQuadra800_trace7_efcf5ffb.rbf`, staged on .143 as
      `_Unstable/MacQuadra800_trace7_phase1.rbf`; the capture is
      `scripts/scsi_trace.sh --capture-only <s>` after a hand `load_core`,
      and the decoder also lists bus faults (`B`/`b`) and the CPU stall
      watchdog (`W`), which is what a CPU-side crash would leave) the core
      side: a `SCSI_TRACE` debug build (qsf switch, hijacks
      the serial port) of the phase-1 head, the same shutdown, capture the
      last commands before the freeze; diff against W2. Suspects: an eject
      while the RTL holds STATUS, TEST UNIT READY on an ejected disc
      returning NOT READY / $3A where A/UX expects $B0 or GOOD, the RTL's
      `cd_present`/`cd_ejected` state after the eject, a bus reset owed by
      the halt path meeting the forwarded notice. MAME's model (unit
      attention on media change, `$B0` no-disc) is the reference for the
      right answer
- [ ] W4 -- now: A/UX gates run at RAM = 32 MB (the setting every passing
      gate used); the 128 MB shutdown hang is a follow-up investigation
      (a 64 MB point, then what the shutdown touches above 64 MB), noted
      in the release entry. Old text: fix, bench test for the sequence, rebuild, both A/UX gates (with
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
- 2026-09-16 12:55, **phase 2 in RTL** (`d5442fe`, while the P1a operator
  and the W2 QEMU run are out): `cd_audio.sv` rewritten (blob-header
  parse, the $CC status poke after every forwarded transport command, the
  5-block frame fetch with the pad, the sample engine; no playhead,
  dividers, tables or volume law), the transport arms of `ncr53c96.sv`
  forward the CDB with STATUS held, $42/$C2/$CC fetch from the window, the
  page $0E ports are gone, `scsi_cache` honours an engine block count for
  pass-through reads.  T19 found a real race: a forward raised while the
  engine's frame fetch was in flight was sampled by the platform at the
  frame window's address (io_lba follows ca_io_active, which drops a cycle
  after the ack); the forward's request bits now wait for the engine's
  transfer.  Bench 476,872 / 0.  Lane order pinned on the way: the real
  hps_io is little-endian (byte 0 in [7:0]), the sim/bench models
  big-endian, and both `ncr53c96` and now `cd_audio` swap under
  `ifdef VERILATOR`.
- 2026-09-16 13:01: phase-2 Analysis & Synthesis clean (0 errors): the
  target + engine 4,106 -> 2,700 ALUTs, DSP 59 -> 43, one M10K fewer;
  full fit launched (seed 21) alongside the W3 trace build (which is in
  its fitter).  W2 first read (run 1, CD mounted and read by A/UX's
  Finder: PREVENT, ~30 READ(6)s of the HFS structures, TEST UNIT READY
  polling between them): **A/UX sends the CD nothing at all during
  `shutdown -h now`** -- no eject, no ALLOW, no TUR, no bus reset; only
  WRITE(6)s to the root disk until the log goes quiet.  If QEMU halted
  (the operator's report decides), the MiSTer wedge is not CD command
  traffic at shutdown; a mounted CD then differs only in the kernel's
  memory layout / process set at halt, i.e. a CPU-side suspect (the
  checkpoint-15 core in 20260915 and phase 1).  Cheap control added to the
  next hardware brief (`scratch/p1b/BRIEF.md` step 3b): the same A/UX +
  retail-ISO shutdown on `20260908_3` (the older CPU).
- 2026-09-16 13:08: the W3 trace build is in (`efcf5ffb`, 95 %, HDMI
  -0.351 / clk_sys +0.157) and staged on .143 next to the 20260908_3
  release (`71102b39`, the older CPU, for the W1c control); the P1a
  operator had passed steps 0-4 (boot 2m20s, idle clock in step over 4 min,
  Cmd+W, the CD window through the windows, both guest volumes of the
  retail disc put away from the Finder within 5-10 s each: the eject
  forward with STATUS held works on hardware, no dialog, no beachball)
  and was on the OT hot mount.
- 2026-09-16 13:30, **P1a passed** (see the checklist) except Speedometer,
  which is not on the restored Quad Squad image. **W2 is in**: QEMU's
  A/UX never completes a shutdown at all -- with or without the CD it
  stalls at `INIT: New run level: S` after the port-mapper line, so QEMU
  is no golden reference for the halt path; what it did show is that A/UX
  sends the CD nothing during the shutdown, keeps it PREVENT-locked from
  mount to the end, and that the "streaks" in QEMU are the kernel's 1-bpp
  text console drawn into a 24-bpp frame (the operator decoded them).
  Applied to the MiSTer wedge frames: inverting the screenshot through the
  Apple 256-colour CLUT gives glyph-like bytes at x = 0, 128, 256, 384, 512
  on paired frame rows -- exactly a 1-bpp console at the DAFB's 1-bpp pitch
  (128 bytes) written into the 8-bpp frame (1024-byte pitch). So the
  MiSTer's streaks are the kernel console's last lines (a halt message, or
  a panic) drawn at the wrong depth; decoding them is in progress
  (`scratch/w3/decode_streaks*.py`). The A/UX operator (P1b + the three
  controls) is on the box from 13:30.
- 2026-09-16 13:25, **the wedge screen read**: inverting the MiSTer's
  wedge screenshots through the Apple 256-colour CLUT gives glyph bytes at
  x = 0/128/256/384/512 on paired frame rows, and re-rendering the frame
  as a 1-bpp image at a 128-byte pitch shows console text ("WELCOME TO
  A/UX", the shell lines) in the streaks: **the streaks are A/UX's kernel
  console repainting its text buffer at 1 bpp (the DAFB's 1-bpp pitch)
  into a frame the DAFB still shows at 8 bpp**. A passing halt
  (`scratch/gate_fix/40_aux_halt.png`) is a Mac-style dialog on black,
  drawn by the Mac environment -- so in the wedge the Mac environment has
  already died and the kernel owns the screen; whether it then halts,
  panics or hangs is what the operator's keyboard-echo test and the W3
  trace (CD commands in the last epochs, bus faults, the watchdog) decide.
  QEMU stalled before that phase, so its "no CD traffic" does not cover it.
  Only ~2 of 16 glyph scanlines survive in a 640-px screenshot, so the
  last lines could not be read (`scratch/w3/decode_streaks*.py`).
- 2026-09-16 13:18: **the phase-2 fit at seed 21 failed in routing**
  ("Fitter routing phase terminated due to routing congestion", peak 92 %
  in X56_Y11..X66_Y22; placement had succeeded) -- the placement lottery,
  not capacity (the design is 1,400 ALUTs smaller). Seeds 22 (wt2) and 23
  (main tree) were launched in parallel at 13:17 -- **wrong: the user's
  rule is one Quartus flow at a time, worktrees included**; the seed-23
  flow was killed at 13:40 (its fitter, shell and launch chain matched to
  the main-tree command), the main tree's qsf restored to seed 21, and
  seed 22 runs alone in `../MacQuadra800_wt2` (`scratch/build_phase2_s22.log`
  there). Seeds walk one after another from now on; the
  aggressive-routability switch is the lever after that.
- 2026-09-16 13:50: **phase 2 fits at seed 22 with timing met** (37,155
  ALMs = 89 %, clk_sys +0.232 ns; rbf `c2a902cb`, staged on .143). The
  hardware gate brief is `scratch/p2/BRIEF.md` (8.1 boot with the retail
  ISO, A/UX with no CD, then the AppleCD Audio Player on a PC Engine CHD
  from `games/TGFX16-CD/`); it runs after the A/UX operator (P1b + the
  three controls) has the box free.
- 2026-09-16 15:05, **W1 results and the reading**: P1b (phase 1, no CD)
  and W1a (20260915, no CD, pristine image) and W1b (20260915, OT ISO) all
  wedge on .143; after the wedge, typed characters draw more streaks (the
  1-bpp console echo): the kernel lives, the shutdown is hung. The same
  rbf, ROM and image halted on .92. Environment differences checked: same
  ROM md5, same backup zip, no working Ethernet in this core (inert SONIC
  decode; QEMU's SONIC is real, so QEMU's stall is not comparable), the
  Main build differs (.92: Aug 28 fork `d6d63ec4`; .143: today's fork
  `898854ef`, rebased onto upstream 20260907 on 09-08). Staged the .92
  Main on .143 as `/media/fat/MiSTer.aug28_d6d63ec4` for a swap test.
  The operator was cut off by an API overload at 14:55 mid-W1c and resumed
  at 14:58.
- 2026-09-16 15:05, **W1c wedged too**: the 20260908_3 release (the
  older CPU, pre-checkpoint-15) with the retail ISO, on the pristine image
  and today's Main, shows the same port-mapper line and 1-bpp console
  streaks (`scratch/p1b/zz_check_1502.png`). So the wedge does not care
  about the core (phase 1, 20260915, 20260908_3), the CPU generation, or
  the CD; on .143 every `shutdown -h now` hangs, on .92 the same rbf, ROM
  and image halted. The environment is the variable and the Main build
  is the one difference found (`d6d63ec4` of Aug 28 on .92, pre-`dbae5ff`,
  vs today's `898854ef`): W1d (the .92 Main installed on .143, 20260915,
  no CD, pristine image) is queued to the operator behind P1c. The
  operator was cut off twice by API overloads (14:55, 15:12) and resumed
  each time; the wedged W1c guest is provably dead and may be reloaded.
- 2026-09-16 15:15, the user: **use ONLY the .143 box** from now on (the
  .92 box belongs to another session; today's read-only looks at it and
  the copy of its Main binary are the last access). The operator's own
  comparison adds two variables shared by every hanging run and absent
  from the passing .92 gate besides the Main build: **the slot-1 disk
  (`.s1` FreshTest) mounted, and the RAM setting (128 MB here, 32 MB in
  the passing gate)**. Queued to the operator after P1c, cheapest first:
  W1e = 20260915, no CD, no `.s1`, pristine image; W1f = the same with
  RAM (on reset) = 32 MB (OSD, verified by About This Macintosh); then
  W1d = the Main swap. Then everything back (`.s1`, Quad Squad, retail ISO,
  today's Main).
- 2026-09-16 16:00, **the A/UX shutdown wedge is the RAM setting**
  (`scratch/p1b/report.md` steps 4b/4c): on 20260915, no CD, no `.s1`,
  pristine image, today's Main -- **128 MB wedges (W1e), 32 MB halts
  cleanly (W1f)**. All five wedges today ran at 128 MB (the .143 box's
  OSD setting); every passing A/UX gate on record ran at 32 MB. P1c (the
  old core, 8.1 with the retail ISO on today's Main) PASSED. The Main
  swap (W1d) and the trace run (W3) are cancelled as controls; the
  question left is *why* A/UX 3.1 hangs its shutdown with 128 MB
  (A/UX's own limit, or the core's memory map above 64 MB: a 64 MB point
  and a look at what the shutdown touches up there are the follow-up).
  Single trial at 32 MB; a repeat comes with the phase-2 gate's A/UX
  step, which runs at 32 MB. The operator restores the box (`.s1`, Quad
  Squad, retail ISO, RAM left at 32 MB, today's Main) and stops.
- 2026-09-16 16:25, the A/UX operator's final report
  (`scratch/p1b/report.md`, 527 lines): **six runs at 128 MB wedged --
  phase 1, 20260915 with and without a CD, 20260908_3, without the slot-1
  disk, and with the Aug 28 Main (`d6d63ec4`, W1d ran before the skip
  reached it) -- and the one run at 32 MB halted in 126 s** (the .92
  reference: 127-130 s). P1c (20260915 + retail ISO on today's Main):
  Finder at T0+130 s, `mac_shutdown.sh` exit 0. Wedge onset 125-157 s
  after Return every time; keyboard input still changes pixels (more
  streaks), mouse does not. Box left in the MENU core, Main `898854ef`
  back, `.s0` Quad Squad / `.s1` FreshTest / `.s4` retail, **RAM left at
  32 MB** (`MacQuadra800.cfg.bak128` holds the 128 MB original), the A/UX
  image pristine. Next: one operator run = the phase-1 A/UX check at
  32 MB, then the phase-2 gate (`scratch/p2/BRIEF.md`).
- 2026-09-16 18:15, **the phase-2 gate** (operator, `scratch/p2/`,
  screenshots only -- its harness refused the report file): step A the
  phase-1 A/UX check at 32 MB PASSED (desktop 120 s, halt 131 s) -> phase 1
  released. On the phase-2 rbf `c2a902cb`: **8.1 with the retail ISO PASS**
  (Finder T0+111 s, idle clock, Cmd+W, both ejects, `mac_shutdown.sh` 45 s)
  and **A/UX at 32 MB PASS** (desktop 131 s, halt 127 s). **The AppleCD
  Audio Player FAILS**: the PC Engine CHDs are mixed-mode with a data
  track (unreadable-disk dialog, no Audio CD volume), so the operator
  built a 4-track pure-audio CUE/BIN (`games/MacQuadra800/AudioTest.cue`,
  silence); it mounts as "Audio CD 1", the player shows the four tracks
  and the 07:02 total (the TOC path is right); **Play**: Main logs
  `Mac CD: cmd 47 00 00000200 07040200 -> st 1 cur 0 stop 31652` (PLAY
  AUDIO MSF, the playhead started), the elapsed counter runs to 00:07,
  then "The Apple CD-ROM drive is not responding" (2/2, no other
  transport command was ever forwarded, no Main error). Also: the Quad
  Squad image was damaged during that session (system error 41 on the
  next boots, with or without a CD; restored from backup, the damaged copy
  kept as `QuadSquad8_damaged2_20260916.hda`), and the remote mouse motion
  died at ~17:30 (buttons and keyboard fine; the mrext restart is the
  untried lever, at the menu core it is safe). Box: MENU core, Main
  `898854ef` relaunched by hand with `stdbuf -oL` and stdout appended to
  `nohup.out` (the inittab start logs to the serial console, which is why
  no `Mac CD:` lines were seen after the 16:21 reboot), `.s0` Quad Squad
  (restored 18:13), `.s1` FreshTest, `.s4` retail, RAM 32 MB.
  **Reading (mine, from the RTL):** the engine's channel requests and the
  nexus's block requests are decided in the same cycle from the same
  registered state (`ca_grant` vs `!io_busy`); when both fire, the cache
  sees one merged request bit for slot 2 -- or the disk's request with
  `io_lba` = the engine's address -- so a disk WRITE can be sent to the
  frame window's LBA (a lost write: the error-41 image), a guest CD read
  can be served 5 blocks into a 1-block buffer, and the nexus's ack is
  masked while `ca_io_active` (a command that never completes = "drive not
  responding"). Phase 1 had the same race with the blob/audio fetches;
  phase 2 fetches every 13 ms while playing, so it shows at once. Fix
  next: the nexus has priority -- the engine's request is hidden while any
  nexus request is up, `io_lba`/`io_blk_cnt` follow the nexus when it has
  one, and the engine withdraws a request raised in the collision cycle
  and retries.
- 2026-09-16 18:40, hand-off (`RESUME-optimize-scsi-20260916.md`): the
  collision fix is a WIP commit (`97ea3eb`): `eng_owns` in `ncr53c96.sv`
  (nexus priority; the engine's request shown only once granted; io_lba,
  io_blk_cnt, the ack mask, the engine's ack/data strobes and the sector
  buffer's platform port follow it) and T20 in the bench (PLAY, then a
  4-block CD READ(10) on a 150,000-cycle device). **T20 fails**: block 3 of
  the read comes back stale (byte 1024 got 03, want 46) and the completion
  interrupt never comes, with "collision cycles seen: 0" -- i.e. the grant
  between two nexus blocks, not a same-cycle collision, breaks the next
  block (suspects in the resume file). Everything before T20 passes. The
  box: MENU core, RAM 32 MB, images clean, remote mouse motion dead (mrext
  restart at the menu core is the lever), Main relaunched with logging.
- 2026-09-16 07:40: core phase 1 committed (`3d5e32d`): tb_ncr53c96
  476,837 / 0. Analysis & Synthesis (`--check`): `cd_audio` 1,535 ALUTs /
  707 regs (was ~2,566 / 852), `ncr53c96` own 2,571 ALUTs. Full build
  launched 07:38 (`scratch/build_phase1.log`, sgiindy fitting alongside);
  full-machine sim rebuilt after a WSL restart, CD boot run pending.
- 2026-09-16 19:40, **T20 rewritten, the real hardware bug found and
  fixed (`3ec22e4`)**. The WIP T20 was chasing a phantom: (1) a CD data
  READ raises `read_stb`, which idles the engine (ast 5, both halves
  dropped), so no frame fetch could collide with the read -- "collision
  cycles seen: 0" was the truth; (2) its "stale" byte 1024 was HPS block
  10, which T14's WRITE(6) at LBA 10 had overwritten earlier in the same
  run; the read path was fine.  The rewritten T20 forces the same-cycle
  collision on purpose: the engine's status poke in flight on a
  300,000-cycle platform, the cadence frees a half meanwhile so the frame
  fetch waits in F_REQ, a nexus request waits on io_busy (part c: a disk
  WRITE(6) flush pushed as one TC=512 TI -- the chunk's bus service waits
  on nexus_io too; part d: a guest $CC window read); both fire the cycle
  the poke's ack falls, and the test asserts each precondition (hk_act,
  fst == F_REQ, sbuf_pos == 512 / blocks_left == 1 with no request up)
  so a cadence drift fails loudly.  The bench's platform model is now
  faithful to scsi_cache + hps_io: the lowest slot holding a request is
  served with the address and block count on the bus in that cycle, the
  ack goes to that slot only, and a disk-slot request carrying a window
  address or a block count is counted as astray.  Against the pre-owner
  RTL (`450445b`, `scratch/t20/prewip.log`) the new T20 fails the way the
  hardware did: the flush went out at the frame window's address with
  the engine's block count (`bad_disk_req` 1), its ack stayed masked and
  it was served again for ever -- 527 failures.  With the owner register,
  part c passed and part d still failed: the guest's six $CC bytes came
  back $FF (the chip's idle-PDMA answer) and the DATA IN ended empty when
  the engine's fetch behind it finished -- because **`abort_nexus` arms
  `io_discard` on io_busy, which includes the engine's transfer
  (`ca_io_active`), so a selection that lands while a frame fetch or the
  poke is out throws away the NEW nexus's first read** (`26b5e67`,
  2026-09-02; every release since carries it, the phase-2 fetches every
  13 ms made it bite at once).  On hardware that is every AppleCD status
  poll that selects during a fetch: the poll's DATA IN ends with no
  bytes, and a disk READ selected the same way comes back one block off
  (the Quad Squad image with error 41 has a candidate cause).  The same-
  cycle collision, by contrast, needs two requesters waking on the same
  transfer end, which the PLAY-then-poll sequence on hardware does not
  produce (only one poke, before frames flow) -- the owner register stays
  (correct by construction, T20 proves it), the discard fix is the one
  that matters for the player.  Fix: only the old nexus's own read in
  flight (`io_rd_i || io_ack_i`) arms the discard.  Bench 477,415 / 0.
  Full fit at seed 22 launched 19:38 (`scratch/build_phase2b.log`).
  Box facts (read-only look 19:20): MENU core, Main `898854ef` started by
  hand at 18:04 with stdout to `nohup.out` (holds event8..18 but NOT
  event15, created 18:04 -- the remote mouse's uinput node, hence "motion
  dead": relaunching Main at the menu core, not the remote service, is the
  cure; inittab starts Main once at sysinit, no respawn), `.s0` Quad
  Squad, `.s1` FreshTest, `.s4` retail ISO, cfg byte 0 = 0 (32 MB), the
  damaged copy is the pristine size (no file extension by the lost write).
- 2026-09-16 19:58, phase 2b fit: seed 22 (the qsf default since the
  13:50 phase-2 fit) FAILED in routing on the 3ec22e4 netlist
  (congestion, placement fine, 18 min; Analysis and Synthesis: ncr53c96
  self 2,317 ALUTs, with the engine 2,689, cd_audio 372 / 320 regs, DSP
  43, i.e. the fix costs nothing). Seed 23 launched 19:58
  (scratch/build_phase2b_s23.log), one flow at a time; if it fails too,
  the next lever is FITTER_AGGRESSIVE_ROUTABILITY_OPTIMIZATION ALWAYS
  rather than a fourth seed.
- 2026-09-16 20:30, phase 2b fit, seed 23: fits (36,932 ALMs = 88 %,
  25,223 regs, 43 DSP, 25 min) but the 33 MHz CPU clock MISSES by 0.752
  ns with TNS -37 ns (HDMI +0.254, clk_ram +0.555); rbf 0d374d4a kept as
  scratch/MacQuadra800_phase2b_s23_0d374d4a.rbf. Seed 24 launched 20:25
  (scratch/build_phase2b_s24.log). Under the try-marginal-builds policy
  the seed-23 rbf is staged on .143 as
  _Unstable/MacQuadra800_phase2b_s23.rbf (md5 verified) and an Opus
  operator runs scratch/p2b/BRIEF.md on it as a FIX PROBE: steps 0
  (relaunch Main at the menu core for the remote mouse), 1 (8.1 + retail
  ISO), 3 (the AppleCD Audio Player on AudioTest.cue) and 4; A/UX skipped
  on the marginal build; a clean seed gets the full gate and the release.
- 2026-09-16 20:45, **phase 2b fits at seed 24 with timing met**: worst
  +0.244 ns (HDMI +0.255, clk_sys +0.762, clk_ram +0.605), 37,056 ALMs
  (88 %; -1,072 against the morning's phase-1 release, -99 against the
  13:50 phase-2 fit of the unfixed head), 25,269 registers, 490 RAM
  blocks, 43 DSP; 18 min (synthesis reused). rbf `4bf9629c` kept as
  `scratch/MacQuadra800_phase2b_s24_4bf9629c.rbf` and staged on .143 as
  `_Unstable/MacQuadra800_phase2b_s24.rbf` (md5 verified; a file copy,
  the probe operator's guest untouched). The release gate brief is
  `scratch/p2c/BRIEF.md` (= p2b without the probe caveat, A/UX included);
  it runs once the seed-23 probe operator has returned the box to a halt
  screen. Seed 24 recorded as the qsf default (`319b72c`).
