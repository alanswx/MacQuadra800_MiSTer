# Resume here: disk speed, the SCSI cache and room for the pipeline (2026-09-25 night)

Supersedes the top of `RESUME-timing-closure-20260925.md` for everything after
PR #7.  Branch `add-ethernet`.

## Where things stand

| thing | state |
|---|---|
| **Timing-clean full-feature core** | `a0b3072`: pipeline out, SCSI cache on, 8+8 KB CPU caches.  CPU +0.007 / SDRAM +0.082 / HDMI +0.044 ns.  Mix median 1.670.  **PR #7** to danifunker/MacQuadra800_MiSTer (open).  RBF `test-builds/MacQuadra800_fullfeature_timingclean_20260925_a0b3072.rbf` |
| **Better candidate (not yet in the qsf)** | the same plus `SCSI_CACHE_OFF=1`, CPU caches 16+16 KB (`SETW = 8`), seed 23 (recipe: `docs/perf/cacheoff_s23_20260925/build/recipe.diff`).  37,532 ALMs, 485 M10K, **CPU +0.360 / HDMI +0.290 / SDRAM +0.583 ns**, every hold/recovery/crossing met.  **Mix median 1.684, Disk 1.604.**  RBF `test-builds/MacQuadra800_cacheoff_c16_s23_20260925.rbf` (md5 cdd92e98).  **Needs the write-buffer Main**; with an old Main the cache must stay on |
| **Main write buffer** | `alanswx/Main_MiSTer` branch **`mac-disk-writebuffer-min`**: one commit (`b0248f8`) on MiSTer-devel `master` (`aa271e4`, which already has the Mac Ethernet/SCSI/Quadra work, #1321).  3 files, +160 lines.  Branch `mac-disk-writebuffer` = the same on `alan/master` plus printer support and the opt-in disk trace |
| **Disk measurements** | `docs/DISK_TRACE_20260925.md` (everything: the trace method, the bottleneck, the buffer, the A/B, integrity, cache-off) |

Disk results on the same core (`a0b3072`), only Main changed: Speedometer
PR Disk **0.568 -> 1.758**; a 2.8 MB Finder copy's write phase 11 s -> 3.3 s.
Copies were verified byte-identical offline (machfs; `hfs_compare.py`).

## The MiSTer (10.3.89.233)

- Main: **write-buffer build `3dd49cd2`** (Quadra + printer + opt-in trace).
  Also on the box: `MiSTer.bak_pre_fujinet` (d5b50fc4, Quadra + printer, the
  previous one), `MiSTer.fujinet-20260925` (FujiNet, **no Quadra support**:
  every Quadra core stays black with it), `MiSTer.disktrace`,
  `MiSTer.writebuffer`.
- Core loaded: `_Unstable/MacQuadra800_cacheoff_s23.rbf`, guest in
  Speedometer at the Performance Rating result.  Shut it down (Speedometer:
  Cmd-Q, click No at about (263,215) with vmouse `home m:162,129`, then the
  Finder Special -> Shut Down vmouse recipe) before loading anything.
- `_Unstable/MacQuadra800.rbf` is the `a0b3072` timing-clean build.
- Disk trace: `touch /tmp/mac_disk_trace` on the MiSTer, run the workload,
  `rm` it, and read `/tmp/mac_disk_trace.csv`.  Summarize it with
  `docs/perf/disk_trace_20260925/analyze.py`.
- Driving the guest: keys with `scripts/mister_ws.py`; the mouse only with
  `ssh ... python3 /media/fat/Scripts/q800tools/vmouse.py` (about 1.6 px per
  unit; `home` pins the top-left corner).  Speedometer: Cmd-B = Benchmark
  Mix, Cmd-R = Performance Rating (then Return, and Return at the drive
  chooser).
- Do not use kernel uprobes on libc here: glibc is Thumb code and a probe
  on `lseek64` broke `lseek` system-wide (see the trace doc).

## Room for the pipeline (1.67 -> ~1.83)

The pipeline costs about 1,700 ALMs (CPU-only synthesis).  Fits so far:

| fit | recipe | ALMs | result |
|---|---|---|---|
| A (morning) | pipeline + SCSI cache | 39,626 (95 %) | routed after 2 h, CPU −2.76 ns |
| P1 | pipeline + cache off, 8 KB | 39,323 (94 %) | **router fails** |
| P2 s21 / s23, P3 s21 | P1 + the three release-lite framework trims (`MISTER_BYPASS_AUDIO_FILTER`, `MISTER_DISABLE_VIDEO_CALC`, `VIDEO_512_OFF`, ~1,065 ALMs); P3 also without PIPELINE_LOADS/STORES | | running (scratch/fitP2_*, fitP3_s21) |

If those still do not route, the next room would come from moving the
disk-target commands (INQUIRY, MODE SENSE, READ CAPACITY, sense) to Main,
as the CD-ROM target already is (it saved 510 ALMs).  After that, the CPU
itself.
