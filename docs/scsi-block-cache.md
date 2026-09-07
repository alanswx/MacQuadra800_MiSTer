# SCSI block cache (`rtl/scsi_cache.sv`)

A per-target read-ahead / write-behind buffer between the 53C96 engine
(`rtl/ncr53c96.sv`, inside `iosb`) and the MiSTer HPS block channel
(`hps_io`). Inserted in `rtl/quadra800.sv` on 2026-09-07; branch `work/cache`.

## Why

The engine moves one 512-byte sector per HPS round trip and waits for the
platform on every one. Two costs followed from that:

- **Latency.** A read served from Main's own read-ahead is ~100 us; a write
  is whatever the SD card takes, and images are opened O_SYNC, so a
  housekeeping pause on the card (hundreds of ms) lands on every guest write.
  An install or a file copy is thousands of sequential sectors.
- **A deadlock class.** The engine reports a write's GOOD status when its last
  block *starts* flushing. If the ROM then selects another target, the flush
  is still outstanding on the old one. `f349e9e` routes that ack correctly
  (`io_ack_i` follows `flush_tgt`), but the shape -- a platform transfer
  outstanding across a target switch -- is what the cache removes entirely:
  the engine's write is acked from block RAM in ~25 us and the flush happens
  behind it, on the platform side, where target switches do not exist.

## Shape

One true-dual-port M10K array of `SECT0 + SECT1 + SECT2` sectors
(64 + 48 + 16 = 128 sectors = 64 KB as instantiated: 32 KB hard disk 0,
24 KB hard disk 1, 8 KB CD-ROM). Port A is the engine side, port B the HPS
side; word addressing, big-endian byte pairs exactly as `hps_io` delivers
them -- the cache never interprets the data, so the byte-order swap in
`ncr53c96.sv` is unchanged.

Each slot owns **one contiguous LBA window** with a base, a `valid` bitmap
and a `dirty` bitmap. A request outside the window flushes what is dirty
and re-bases the window on the new LBA. That is a buffer around the current
position rather than a general cache: sequential traffic runs from RAM,
random access degrades to today's behaviour (one round trip per sector).

Platform-side transactions are serialized, in this priority:

1. **demand** -- an engine miss, or an uncacheable request;
2. **dirty flushes** -- in LBA order within the slot, then the next slot;
3. **prefetch** -- up to `PF_DEPTH` (8) sectors beyond the last read, only
   while the channel is otherwise idle. Every read (hit or miss) re-arms it
   just behind itself; it skips over sectors already present and stops at
   the window edge, so a sequential stream stays 8 sectors ahead.

The CD-ROM's TOC blob and CD-DA frame windows (LBA >= 0x40000000, served
by the Main fork with its own block sizes and 13-bit buffer addresses)
**pass straight through**, buses and all (`r_pt`).

## Engine-side contract

Identical to what `hps_io` offers, so `ncr53c96.sv` did not change:
the strobe is a level held until `ack` rises; words stream while `ack` is
high (`e_buff_wr` for a read, a registered readback at `e_buff_addr` for a
write); `ack` falling means done. A write hit takes 3 cycles per word
(address, the engine's registered read, sample), a read hit the same
(address, the RAM's registered read, drive).

## Coherency rules

- A read of a dirty sector is a hit and returns the new data.
- A window re-base first stops the prefetcher (`pf_left <= 0`), then waits
  in `E_FLUSHALL` until the slot is clean **and** the channel is idle with
  nothing able to start (no prefetch, no dirt, no demand), and only then
  rewrites the tags. A fetch that completes for a window that is no longer
  current (`c_base != win_base`, or `win_ok` dropped by a mount) sets no
  valid bit.
- Same-sector hazards are decided from registered state on both sides so
  they can never disagree within a cycle: the engine will not write a
  sector the channel is fetching or flushing (`ch_busy_me`), and the channel
  will not start a flush or a prefetch of a sector the engine is writing
  (`e_writing`, true from `E_DECIDE` until the last word is stored).
- A mount pulse whose image size differs from the one the slot was mounted
  with invalidates the slot (dirty data belonged to the old image). A pulse
  with the same size is the top level's post-reset replay and keeps
  everything, so a guest restart cannot lose the last writes.
- `nreset` aborts only the engine-side transaction in progress; tags, dirty
  bits and the background flusher survive a machine reset, so a reset in the
  middle of a write burst still lands the data.

The random bench found the two races (2026-09-07): a prefetch issued in
the same cycle the engine decided to re-base completed after the window
moved and marked its sector valid in the new window (slot 2 returned
LBA 8's data for LBA 25); and an engine write could start in the same
cycle as a background flush of the same sector. Both closed in `9754dac`.

## Bench

`verilator/tb_scsi_cache.sv` (`make tb_scsi_cache` from `verilator/`):
an engine-like requester against a slow device model with random latency.
T1 prefetch turns sequential reads into hits; T2 write-behind lands in
full and in order; T3 read-after-write before and after the flush; T4
re-base with dirty data; T5 per-slot windows and CD passthrough; T6 mount
invalidation vs. same-size replay; T6b the CD's 16-sector window under
re-bases; T7 200 random reads/writes across all slots with random device
latency, checked against a mirror and then a full device sweep; T8 the
installer's own pattern -- a 100-sector sequential write burst on slot 1
that crosses the window, then CD reads issued while the burst is still
flushing, on a slow device. 237,583 checks, 0 failures.

The full-machine sim covers the wiring: `verilator/sim.v` instantiates
`quadra800`, so a `sim_wsl.sh run --cd cd.iso` boot exercises engine,
cache and block-device model together.

## Cost

64 M10K blocks for the store (the fit before the cache used 430 of 553),
plus the two small state machines. `hps_busy` (the CPU stall-watchdog
hold in `quadra800.sv`) now covers both sides of the cache.

## Statistics

`stat_hits` / `stat_misses` count engine read hits and demand fetches;
brought out of the module as `cache_hits` / `cache_misses` in
`quadra800.sv` for the tracer to pick up when wanted.
