# SCSI: two hard disks and an AppleCD-class CD-ROM on the 53C96

Status 2026-09-02: phase A (targets, CD data command layer) and phase B (the
TOC/audio engine) are in `rtl/ncr53c96.sv` + `rtl/cd_audio.sv`; the BlueSCSI
Toolbox and CD-changer transports (hps_io slots 3 and 5) are not yet wired.

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
- READ TOC (`$43` formats 0/1/2) and Apple `$C1` come from `cd_audio`'s
  pre-rendered tables; `$42`/`$C2`/`$CC` from its live position registers;
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

`cd_audio` shares the CD target's hps_io channel: it may fetch (TOC blob,
audio frames) whenever the engine has nothing in flight; `ca_io_active`
keeps its acks and sector-buffer writes out of the engine's accounting.
Its PCM leaves as `cd_snd_l/r` up through `iosb` and `quadra800` and is
summed with the ASC output at the top (`audio_mix_*`, saturating).

## Verification

- `verilator/tb_ncr53c96.sv` T16a–g (8654 checks): CD INQUIRY, no-disc sense,
  READ CAPACITY, READ TOC format 0 through the engine's synthesized TOC, a
  2048-byte READ mapped to HPS blocks 4..7, write rejection, the second disk.
  The bench's device serves zeros at the TOC-blob window, so the engine takes
  its single-track fallback.
- Hardware: Mac OS 8.1 with `games/MacQuadra800/Open Transport 1.3.1.iso`
  pre-mounted through `config/MacQuadra800.s4`; then `games/MacIIvi/TIM_3-mac.chd`
  (mixed mode, needs the Main fork) for CD audio.

## Area

Phase A alone fitted at 33,857 ALMs (81 %). `cd_audio`'s twelve 256×8 tables
are `ramstyle = "M10K"` here (they were MLAB in MacLC, ~1,200 ALMs).
