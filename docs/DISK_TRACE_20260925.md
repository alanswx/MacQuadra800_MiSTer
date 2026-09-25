# Disk channel trace, 2026-09-25: where the Quadra 800's disk time goes

Core: the timing-clean full-feature build (`a0b3072`, RBF md5 46b85dcc).
Main: `../Mac_Main_MiSTer` branch `mac-disk-trace` (`7f158ba`, on the
Quadra fork `0cb45be`), which adds an opt-in per-request log of the sector
channel to `user_io.cpp` (`touch /tmp/mac_disk_trace` turns it on; records go
to `/tmp/mac_disk_trace.csv`).  For each request it logs the slot, the
operation, the LBA and block count, the SPI transfer time, and the file I/O
time before and after the acknowledge.  Raw traces and the summarizer are in
`docs/perf/disk_trace_20260925/`.

(Kernel uprobes on libc were tried first and abandoned: the MiSTer's glibc is
Thumb code, which ARM uprobes cannot single-step.  The `lseek64` probe broke
`lseek` system-wide.  All probes were removed before any guest disk I/O.)

## Results

| workload | requests | data | Main time in the service | notes |
|---|---|---|---|---|
| cold boot to Finder (56 s) | 10,942 reads (all 8 x 512 B), 78 writes | 44.8 MB read, 40 KB written | 12.2 s | reads: SPI 837 us per 4 KB (**~4.9 MB/s**), file read 61 us median (page cache), 26 % Main-buffer misses |
| Finder duplicate of SimCity2000 (2.8 MB) | 910 reads, **1,894 writes (1,386 single-sector, 508 x 8)** | 3.7 MB read, 2.8 MB written | 11.2 s of a 12 s write phase | **writes: 3.8 ms median each, p95 9.3 ms**; 91 % continue the previous write's LBA; **~250 KB/s** |

- **Writes are the bottleneck.** `/media/fat` is mounted `sync,dirsync`
  (and images are opened `O_SYNC`), so every `write()` completes on the SD
  card.  That costs ~4 ms per call almost regardless of size.  The earlier
  host test measured 3.97 ms for 512 B, 3.77 ms for 4 KB and 4.45 ms for
  16 KB.  A sequential copy therefore runs at (call size) / 4 ms: 130 KB/s
  in single sectors, 1 MB/s in 4 KB, 3.6 MB/s in 16 KB.
- **The core flushes in small pieces.** `scsi_cache.sv` writes a wholly
  dirty aligned 8-sector group as one request.  A partly dirty group goes out
  one sector at a time once the engine has been quiet for 4,096 clocks
  (~120 us).  Mac OS's File Manager writes in short bursts separated by
  more than that, so 73 % of the copy's write requests were single sectors,
  although 91 % of them extended the previous write.
- **Reads are near the channel limit.** SPI moves 4 KB in ~837 us, about
  4.9 MB/s, which is already in the range of a real Quadra 800's internal
  SCSI disk.  Main's 16 KB read-ahead buffer serves three of every four
  8-block reads, and file reads are fast (page cache).

## What would help, in order

1. **Fewer, larger write calls.**  Two places can coalesce:
   - **In Main:** accept a write into a RAM buffer, extend it while the
     following writes are contiguous, and issue one `write()` of up to
     16-64 KB when the run breaks, the buffer fills, or the channel has
     been idle for a few ms.  Reads of a buffered range must be served from
     the buffer.  This needs no FPGA change, so it leaves the timing-clean
     bitstream alone.  Durability is the same kind of trade the core's
     write-behind cache already makes (the guest's write is acknowledged
     before it reaches the card).  Every buffered write must be flushed
     before shutdown or unmount.
   - **In the core:** flush contiguous dirty runs (not only whole aligned
     groups) as one multi-block request, and wait longer before flushing a
     partial run.  This is simpler, but it changes the fitted design, whose
     CPU clock margin is 7 ps.
2. **The mount option.**  A `sync` mount is a MiSTer-wide choice meant to
   protect the card on power loss.  Changing it is not this core's call.

Expected gain for writes: from ~250 KB/s towards 2-3 MB/s on sequential
copies, i.e. about 10x.  The Speedometer Disk rating (0.59 against the real
machine's 3.44) should move with it; that is the before/after benchmark to
run.
