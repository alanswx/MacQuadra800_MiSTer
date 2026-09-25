# Disk profile — 2026-09-25

## Result

Two repetitions of the Speedometer 4.02 Disk test produced ratings of **0.589** and **0.585**. The chooser selected the **Quad Squad** volume; the live file descriptor identified the disposable `QuadSquad8-pipeline-test-20260919.hda`. The dialog required 1 MB free for its temporary file. CPU and Graphics were unchecked, while Disk and Math were checked (Math was left enabled because the final toggle did not take). Math scored 20.873 and 20.961. Thus these are repeatable **Disk+Math suite ratings**, not Disk-only timings or MB/s. Each suite used one iteration. The score screenshots and setup/chooser screenshots are in [`docs/perf/disk_profile_20260925/`](perf/disk_profile_20260925/).

The available live evidence confirms that Main had the disposable HDA open with `O_RDWR|O_SYNC`. During the second run's 89.283-second sampled interval, a roughly 22-second Main write-activity interval coincided with 3,682 device writes and 8,978 sectors written on the MiSTer SD device. Device write and busy-time counters advanced, but they are device-wide aggregates and do not measure time spent blocked in Main. They identify a synchronous-write path worth measuring further; they do not establish that it limits the benchmark score.

## Run and instrumentation

The running core was the supplied full-feature RBF SHA-256 `4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`. Both tests ran in the same guest session without restarting Main or replacing the core. The first run's sampler began after the chooser/test activity and therefore is not an in-run measurement. An approximately 89.4-second post-run idle/control sample showed no change to Main `wchar`, `write_bytes`, or the SD device counters; Main CPU ticks and read/poll counters continued to rise. This is only an endpoint control summary; the first-run raw series was not preserved.

For run 2, a detached 1 Hz sampler was armed and its first sample verified before confirming the selected volume. The full raw series is [`run2_counters_with_header.txt`](perf/disk_profile_20260925/run2_counters_with_header.txt), produced by [`disk_profile_sampler.py`](perf/disk_profile_20260925/disk_profile_sampler.py). It samples `/proc/31518/io`, `/proc/31518/stat`, and `/proc/diskstats` for `mmcblk0`. The window was 2026-09-25 10:39:40.495–10:41:09.778 UTC (89.283 seconds). Main's first changing row was 10:39:50.528 UTC; the last row with changed Main fields was 10:40:12.600 UTC, an observed activity span of 22.072 seconds. The device counters last changed at 10:40:15.609 UTC, 25.081 seconds after the first observed device change. They then remained flat for the rest of the sample. This write-activity span is not the whole Disk benchmark duration; the suite continued with Math and no benchmark end timestamp was sampled.

## Counter deltas

| Counter | Main process delta | `mmcblk0` device delta |
| --- | ---: | ---: |
| `rchar` / completed reads | +17,286,292 bytes | reads completed +0 |
| `wchar` / completed writes | +4,590,080 bytes | writes completed +3,682 |
| `syscr` / `syscw` | +863,899 / +3,675 calls | read merges +0 / write merges +5,294 |
| `read_bytes` / `write_bytes` | +0 / +16,228,352 bytes | sectors read +0 / sectors written +8,978 |
| CPU `utime` / `stime` | +1,819 / +5,695 ticks | — |
| — | — | read time +0 ms / write time +14,019 ms |
| — | — | in-flight at endpoints 0 / I/O time +15,728 ms |

The device counters follow the standard Linux `/proc/diskstats` ordering; the exact sampler header is included with the raw evidence. `/proc/PID/io` counters are Main-process totals, not HDA-specific. Device counters cover all I/O on the SD device, not just this HDA. `rchar` includes reads through cached data and unrelated Main activity. Flat `read_bytes` and disk read counters therefore do not prove the benchmark issued no reads; Linux page cache can satisfy them. The difference among `wchar`, `write_bytes`, and sector-derived device bytes is unresolved and should not be labeled write amplification from these observations.

The sampler's 1 Hz reads add small measurement activity, and one-second sampling bounds the timing of transitions. The separate idle-control sample also showed that Main's large system-read-call count rises while otherwise idle, so `syscr` is not a disk-command count. CPU ticks and aggregate disk time are not attributable solely to the selected benchmark phase. No per-file byte counters, syscall durations, SCSI command trace, or cache hit/miss counts were available.

## Storage-path observations

Live `/proc/31518/fdinfo/5` identified descriptor 5 as the disposable HDA and showed flags `06410002`; the Linux flag word includes `O_RDWR` and `O_SYNC` (with `O_DSYNC` as the subset bit). The descriptor position at inspection was 489,633,280. This observation read metadata only; the mounted HDA was neither hashed nor copied. More details, including running Main SHA and source-revision caveat, are in [`DEVICE_EVIDENCE.md`](perf/disk_profile_20260925/DEVICE_EVIDENCE.md).

The local Main source checkout was inspected at `0cb45beefebfc57da45eb4c77cd37770cb24fe28`; it is not proven to match the running Main binary. Its generic user-I/O path batches requested block transfers through a 16 KiB buffer and the mounted-disk open path requests `O_SYNC`, consistent with the live descriptor. Local RTL source has the small SCSI cache enabled in the inspected build configuration, with aligned eight-sector groups; cache hit/miss counters are internal and unavailable from the loaded core. The FPGA build configuration is tied to the installed artifact by the [archived input manifest](perf/interim_wqmlab_20260925/build/README.md). The source observations identify instrumentation points but do not establish the runtime transaction mix; the installed Main binary’s exact source revision remains unverified. The old note that the installed build had its disk cache off does not match this installed configuration.

`strace` was not installed on MiSTer, so no syscall timing trace was collected. No tracing tool was installed or attached, and Main and the core were not replaced. The run also did not isolate small/random/sequential reads and writes, cold-vs-warm cache behavior, or backend service time. The legacy Speedometer score is the only guest-visible performance rating captured here.

## Host-only synchronous-write sweep

After the guest suite finished, a separate host-side sweep measured write syscall cost on a new exclusive 4 MiB test file under a newly created directory on `/media/fat`. It used the same preallocated file extent for three full overwrites with `O_SYNC` `pwrite`: 512-byte, 4 KiB, and 16 KiB writes. The script and machine-readable output are [`host_backend_test.py`](perf/disk_profile_20260925/host_backend_test.py) and [`host_backend_results.json`](perf/disk_profile_20260925/host_backend_results.json). The file was removed after recording results (`cleanup: true`); the host test script did not open any HDA or mounted guest image.

| Write size | Calls per 4 MiB | Elapsed time | Per-call median | Per-call p95* |
| ---: | ---: | ---: | ---: | ---: |
| 512 B | 8,192 | 31,326.9 ms | 3.970 ms | 7.975 ms |
| 4 KiB | 1,024 | 3,636.2 ms | 3.766 ms | 4.908 ms |
| 16 KiB | 256 | 1,425.9 ms | 4.451 ms | 11.449 ms |

The timed interval brackets only each sequence of write syscalls. Device-wide `mmcblk0` counters over the three sweeps advanced by 9,482 writes, 24,586 sectors (12,588,032 bytes), 34,709 ms write time, and 36,357 ms I/O time. Those are aggregate device counters; they do not map directly to this file or to time blocked in an individual syscall. `/media/fat` was `/dev/root` on exFAT with mount options `rw,sync,dirsync,noatime,nodiratime,...`; the full line is preserved in the JSON. Both the descriptor and mount requested synchronous behavior, so these results do not estimate ordinary asynchronous buffered writes. In particular, dropping `O_SYNC` by itself would not remove the mount's `sync` semantics.

This is a host backend microbenchmark, not a guest throughput result and not a model of SCSI request pacing. It shows a strong batch-size effect for this host/filesystem configuration, with substantial per-call tails, but does not prove the guest Disk rating is backend-bound. The device counters may include other activity, and a single sweep per size gives no run-to-run variance. The reported p95 is the floor-index empirical order statistic from the captured syscall timings.

## Follow-up measurement

The strongest next measurement is a controlled workload with known read/write sizes and access patterns on the same disposable HDA, paired with per-syscall timing for Main's `pread`/`pwrite`/`fsync` path or equivalent low-overhead tracing. Record guest workload boundaries separately from the test-suite score and sample Main plus device counters at those boundaries. If exact SCSI/cache decomposition is required, expose or trace cache hit/miss and request-completion events in a later instrumented build; the current loaded core does not export them. These measurements should first quantify whether synchronous backend service or request pacing materially contributes before selecting a redesign.
