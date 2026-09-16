# Moving the CD-ROM target's brains to the ARM (branch `optimize-SCSI`)

Plan written 2026-09-16, before any code. The Main side lives on
`../Main_MiSTer` branch `mac-ethernet-pr-with-SCSI-Optimizations`; the core
side on this branch. Nothing here is implemented yet.

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
READ CAPACITY, READ HEADER `$44` (needs the 32-bit LBA; uses the disc-info
flag), the no-disc / audio-only CHECKs, eject/prevent state, the
`cd_blk512` MODE SELECT bit (READ address scaling must be in RTL; the ARM
mirrors it from the forwarded list for the mode page).

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
      the Apple CD-ROM extension's mount
- [ ] C5 `build_only.sh --check` logic-cell delta recorded here; full fit;
      hardware gate on .143 (both OSes, OT ISO, retail ISO CD boot, CHD audio)
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
- 2026-09-16 07:40: core phase 1 committed (`3d5e32d`): tb_ncr53c96
  476,837 / 0. Analysis & Synthesis (`--check`): `cd_audio` 1,535 ALUTs /
  707 regs (was ~2,566 / 852), `ncr53c96` own 2,571 ALUTs. Full build
  launched 07:38 (`scratch/build_phase1.log`, sgiindy fitting alongside);
  full-machine sim rebuilt after a WSL restart, CD boot run pending.
