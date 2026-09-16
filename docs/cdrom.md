# SCSI: two hard disks and an AppleCD-class CD-ROM on the 53C96

Status 2026-09-16: phase A (targets, CD data command layer) and phase B (the
TOC/audio engine) are in `rtl/ncr53c96.sv` + `rtl/cd_audio.sv`; since the
`optimize-SCSI` work the CD target's identity, mode pages and TOC responses
are built by Main and read through a response window (section "Responses
from Main" below), and since phase 2 the playhead runs there too (the
next-frame window and the status poke, same section). The BlueSCSI Toolbox and
CD-changer transports (hps_io slots 3 and 5) are not yet wired.

## Shape

The Quadra 800 core keeps its 53C96 register/FIFO/interrupt model exactly as
the ROM and A/UX's `c94` driver validated it, and hangs three targets behind
the one sector buffer, one nexus at a time (`cur_tgt`):

| SCSI ID | target | hps_io slot | OSD entry | answers selection |
|---|---|---|---|---|
| 0 | hard disk | 0 | `SC0` Mount SCSI disk 0 | when an image is mounted |
| 1 | hard disk | 1 | `SC1` Mount SCSI disk 1 | when an image is mounted |
| 3 | CD-ROM | 4 | `SC4` Mount CD-ROM (ISO/TOAST/CUE/BIN/CHD) | always (the AppleCD driver polls TEST UNIT READY for a disc) |
| — | Toolbox control | 3 | none (Main announces it) | — |
| — | CD changer control | 5 | none | — |

Slot numbers are the Main fork's Mac SCSI family contract
(`Main_MiSTer/support/mac/mac.cpp`), so its handlers apply unchanged once the
core name is in `is_mac_scsi_family()` (added 2026-09-02, commit `be433c6` in
`../Main_MiSTer`). Selecting any other ID times out with the FIFO intact,
which A/UX's bus probe relies on.

`MacQuadra800.sv` keeps one mount memory per target and replays the three
pulses one at a time after every machine reset (the ROM only sees a target
that was announced after reset).

## The CD-ROM target

Identity and responses are byte-exact to MacLC's `rtl/scsi.v`, whose oracle
is MAME's `nscsi_cdrom_apple_device`: the stock Apple CD-ROM extension binds
only to drives it knows, so the INQUIRY says `SONY CD-ROM CDU-8004 1.9a`.

- Logical blocks are 2048 bytes; READ(6/10/12) scale the LBA and count by
  four onto the 512-byte HPS blocks, so a flat ISO/TOAST works on a stock
  Main. CUE/BIN/CHD need the fork's `mac_cdrom.cpp`, which serves them as a
  flat 2048-byte disc plus a TOC blob (`MCDA`, HPS block `0x7FFF0000`) and
  raw 2352-byte audio frames (`0x40000000 + lba`, five-block bursts).
- MODE SENSE(6) pages: default, `$30` Apple magic, `$0E` audio control (the
  player's volume slider, MODE SELECT-writable), `$2A` capabilities.
- No disc: media commands CHECK with NOT READY / ASC `$B0` (the AppleCD
  answer; `$3A` makes Mac OS nag to format). Eject is START/STOP LoEj or Apple
  `$C0`, honouring PREVENT. Writes CHECK DATA PROTECT / `$27`.
- READ TOC (`$43` formats 0/1/2) and Apple `$C1` come from Main through the
  response window (they were `cd_audio`'s pre-rendered tables until
  2026-09-16); `$42`/`$C2`/`$CC` from its live position registers;
  data READs on a disc with no data track CHECK with `$64`, which the Audio
  CD Access extension relies on.
- `$43`/`$42` serve **exactly the allocation length**, zero-filled past the
  payload (the Mac's blind transfer arms the whole allocation; MacLC's
  2026-07-19 boot wedge).

Responses stream from a one-byte-per-clock sequencer into the sector buffer
(`synth`), then leave through the normal DATA IN path. The engine's tables
are even/odd byte planes whose outputs hold bytes x and x+1 of the address
presented last cycle, muxed by the current address's low bit — for the
sequencer that is a zero-latency read of the byte being written, so it
presents the current index (`nxt_idx`), not the next.

`cd_audio` shares the CD target's hps_io channel, and the channel has one
owner at a time (`eng_owns` in `ncr53c96.sv`, 2026-09-16).  The nexus has
priority: the audio engine's request (the blob header, the status poke, a
frame) is shown to the platform only once granted -- the cycle after it
was raised with no nexus request up and nothing of the nexus's in flight
-- and `io_lba`, `io_blk_cnt`, the ack mask (`io_ack_i`), the engine's own
ack and data strobes and the sector buffer's platform port all follow the
owner.  Before that, a nexus request and an engine request raised in the
same cycle (both decide from the same registered state: the nexus on
`!io_busy`, the engine on `ch_grant`) reached the platform as one merged
request carrying the engine's address and block count -- for a disk
flush, a write into nowhere served again for ever because the disk's ack
stayed masked (`tb_ncr53c96` T20 forces the case on purpose).  Its
counterpart on the nexus side: a new selection while the engine's
transfer is in flight must not arm `io_discard` -- that flag drops the
OLD nexus's read in flight, and armed on the engine's transfer it ate the
NEW nexus's first block instead (the AppleCD player's status polls,
selected during frame fetches, read nothing: "drive not responding").
`ca_io_active` (the engine's transfer in flight) stays part of `io_busy`,
so a nexus request waits behind it, and of `nexus_io`, so a DATA IN phase
completes only once the channel is quiet.
Its PCM leaves as `cd_snd_l/r` up through `iosb` and `quadra800` and is
summed with the ASC output at the top (`audio_mix_*`, saturating).

## Block size: 2048, and only 2048

An AppleCD answers READ CAPACITY and MODE SENSE with 2048-byte blocks and
serves READ in those units (four HPS blocks each).  The Mac ROM's CD boot
and the Apple CD-ROM driver send a MODE SELECT(6) whose block descriptor
asks for 512-byte blocks; since 2026-09-08 the target refuses it with
ILLEGAL REQUEST / invalid field in parameter list (05/26/00), exactly as
QEMU's scsi-cd does, because honouring it made the ROM re-walk the retail
disc's dual partition map at 512-byte granularity and register the one HFS
volume twice.  A descriptor that does not fit the list is refused the same
way.  The MODE SELECT parser still takes the page $0E ports at either
offset (with or without the descriptor).  `tb_ncr53c96` T16h covers it.

## Responses from Main (2026-09-16, `optimize-SCSI`)

The design note is `docs/scsi-hps-offload-plan.md`; this is the contract as
built.  Everything below is served by the Main fork
(`support/mac/mac_cdrom.cpp`, `mac_cdrom_resp.cpp`, `mac_cdrom_play.cpp`)
only for cores that pass its `is_mac_scsi_optimized()`; the other Mac cores
and older MacQuadra800 bitstreams never address these LBAs and see the old
blob / raw-audio windows unchanged.

- **Response window, read, 1 block:** `$7E000000 + (op << 16) + (a << 8) + b`
  holds the DATA IN of CD command `op` for the two CDB bytes it depends on:
  `$12` INQUIRY; `$1A` MODE SENSE, a = cdb[2] (page); `$43` READ TOC,
  a = cdb[9], b = cdb[6]; `$C1` Apple READ TOC, a = cdb[9], b = cdb[5];
  `$42`, a = cdb[3], b = cdb[6]; `$C2`; `$CC`, a = cdb[3].  The target
  fetches it as a one-block READ (`fetch` in `ncr53c96.sv`) whose serve
  length is the CDB's clamped allocation, so the initiator sees the bytes,
  zero-filled past the payload, behind one Main poll -- the wait a READ's
  first sector already takes.  Since phase 2 the position forms ($42/$C2/
  $CC) come from here too: the playhead is Main's.
- **Command block, write, 1 block:** `$7D000000 + (op << 16)`: the DATA OUT
  list (MODE SELECT, AUDIO CONTROL) at bytes 0.. where the drain left it,
  the 12-byte CDB at bytes 496..507 (`SY_CDB` copies it there).  Forwarded:
  an accepted MODE SELECT (Main mirrors the page $0E output ports for its
  MODE SENSE and scales the frames it serves by them; the RTL no longer
  keeps them), an eject, the pseudo-ops `$FF` (machine reset) and `$FE`
  (SCSI bus reset), and since phase 2 every transport command ($C8-$CB/$CD,
  $45/$47/$48/$4B/$4E/$A5, $01/$0B/$2B), which Main's playhead executes.
  STATUS is held until the write is acked, through the same `iccs_pend`
  deferral a judged MODE SELECT used.  The request is not shown to the
  platform while the audio engine's own transaction is in flight (`io_lba`
  follows `ca_io_active`, and the cache samples the address the cycle it
  sees the request bit, one cycle before `ca_io_active` drops: a PAUSE
  forwarded during a frame fetch went out at the frame window's address,
  `tb_ncr53c96` T19).  Forwards serialize:
  a nexus forward raised while a reset notice is still being written queues
  behind it (`fwd_q`), STATUS waits for both, and only a forward the current
  nexus owns (`fwd_own`) holds its status -- a notice, or a forward whose
  nexus was abandoned, completes without holding the next command
  (`tb_ncr53c96` T18: bus reset, then the eject a shutdown sends).
- **Next frame, read, 5 blocks:** `$7C000000`: one volume-scaled 2352-byte
  frame at Main's playhead (which advances per read, so fetched == played),
  the audio status at byte 2352 (0 play, 1 paused, 3 end, 5 idle), a
  frame-present flag at 2353 and a flush generation at 2354..2357 (bumped
  when a command moved the position).  `cd_audio`'s fetch loop reads it into
  the free half of its two-frame ping-pong while the ARM says "playing",
  as one transaction of 5 blocks: the engine asks for the block count
  (`ca_io_blk_cnt` -> `io_blk_cnt` -> `scsi_cache`'s `e_blk_cnt`, honoured
  for pass-through reads), and the pad is read on the fly as the words
  stream past.  A generation change drops the other half and restarts the
  cadence on the new frame; a frame with the flag clear holds the loop off
  for one frame time.  After the ARM reports the end the cadence still
  plays the buffered frames out.
- **The status poke:** after every forwarded transport command has been
  acked, the engine reads the `$CC` type-0 response once and takes byte 0
  as its state.  Anything but "playing" drops the buffered frames (the
  ARM's playhead is where the command left it: a PAUSE/RESUME pair costs
  the two buffered frames, 26 ms, and a SEARCH-then-PLAY starts clean).  A
  data READ, an eject, a bus reset or an unmount stop the engine at once
  (the ARM sees the same events forwarded).
- **Capability probe:** after every machine reset and CD mount pulse, once
  the bus is free, the target reads the INQUIRY window and latches its
  first two words straight off the platform stream (nothing lands in the
  sector buffer).  `05 80 02 02` arms `cd_hps_ok`; without it the CD target
  does not answer selection, so an older Main or the generic path gives no
  drive rather than a garbage identity.
- **The MCDA blob** is version 2: byte 12 bit 0 says the disc has a data
  track (`cd_audio` derives `disc_audio` from it instead of scanning the
  tracks); Main writes version 1 with the flag clear for the other cores.
- **Flat 2048-byte images** are `HANDLED` (served through `mac_cdrom_fill`)
  for optimized cores, so the blob and the windows are live for every disc;
  a flat file's data window is read in one run per request.

Stays in RTL: TEST UNIT READY, REQUEST SENSE, READ CAPACITY, READ HEADER,
the no-disc and audio-only CHECKs, eject / PREVENT state, the READ data
path, the MODE SELECT parse (the refusal rules above), and of the audio
engine only the blob-header parse (magic, version, has-data), the status
poke, the frame fetch loop and the 44.1 kHz sample engine with its
interpolation.  The command decode, the playhead, the M:S:F dividers, the
track table and its RAM, and the volume law with its two multipliers left
with phase 2 (`rtl/cd_vol_lut.vh` is history; the golden test extracts it
next to the reference `cd_audio.sv`).

Sims: `verilator/sim/cd_window.cpp` serves the windows for both
`tb_ncr53c96` (through the DPI-C shim `cd_win_dpi.cpp`) and the
full-machine block-device model, over the very Main files mirrored into
`verilator/sim/mac/` by `scripts/sync_main_mac.sh`.  The builders are
proven against the old RTL tables by `scripts/cd_resp_golden.sh`.

## What only hardware showed (2026-09-03)

The first hardware run hung grey at boot with a disc in slot 4 and wedged
the Finder on an in-OS mount, while the full-machine sim booted through the
same scan.  The Main's file positions (`/proc/<pid>/fdinfo`) showed it never
read a byte of either image: `MacQuadra800.sv` had the CD's `sd_rd` at bit
5 of the hps_io vector (the CD-changer control slot) while the image, lba,
data and ack were on slot 4, so every CD read -- the TOC fetch on mount
first -- was acked on the wrong slot and `io_busy` never dropped.  The sim
instantiates `quadra800`, not `emu`, and never crosses that wiring.

## Verification

- `verilator/tb_ncr53c96.sv` T16a–g: CD INQUIRY, no-disc sense, READ
  CAPACITY, READ TOC format 0, a 2048-byte READ mapped to HPS blocks 4..7,
  write rejection, the second disk; T16h-p the MODE SELECT refusal, the
  installer patterns, the eject, the slow-platform and stress cases; T17
  the Apple TOC and AUDIO STATUS from the window; T18 the serialized
  forwards; T19 (phase 2) PLAY AUDIO MSF forwarded, one status poke, two
  5-block frame fetches, $CC/$C2/$42 from the window, a refill after a
  consumed frame, PAUSE / RESUME / STOP.  The windows are served by the Main
  fork's own builders and playhead (`sim/cd_window.cpp`); 476,872 checks.
- Hardware: Mac OS 8.1 with `games/MacQuadra800/Open Transport 1.3.1.iso`
  pre-mounted through `config/MacQuadra800.s4`; then `games/MacIIvi/TIM_3-mac.chd`
  (mixed mode, needs the Main fork) for CD audio.

## Area

Phase A alone fitted at 33,857 ALMs (81 %). `cd_audio`'s twelve 256×8 tables
are `ramstyle = "M10K"` here (they were MLAB in MacLC, ~1,200 ALMs).
