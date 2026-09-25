# 15a1449 write-queue candidate: initial hardware and Speedometer results

## Artifact and test configuration

The exploratory hardware run used source commit `15a14497817ad8479bad91bf47d97e2163124d63` and exact RBF `scratch/interim_mac_wqmlab_fit_20260924/MacQuadra800_interim_mac_wqmlab_15a1449.rbf`, SHA-256 `4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`. The RBF was copied to `/media/fat/_Unstable/MacQuadra800.rbf`; the remote SHA-256 matched. The full-feature fit succeeded through routing, but the timing gate failed: CPU setup −2.406 ns, SDRAM setup −0.697 ns, HDMI setup −0.426 ns. Minimum hold slack is +0.200 ns. This is a timing-marginal exploratory result, not a timing-clean release. Queue capture and pointer paths had positive setup/hold slack; the worst queue sys-to-ram capture setup was +3.606 ns and ram-to-ram was +0.970 ns. The failing SDRAM path is bank-age logic (`bank_age[0][1] -> chip`), not the write-queue capture path. See `scratch/interim_mac_wqmlab_fit_20260924/RESULTS.md` and `scratch/timequest_wq_interim_mac_wqmlab/` for the full fit and queue STA.

The normal QSF was used: CPU enhancement macros, `CACHE_SMALL=1`, `CACHE_CD_OFF=1`, Ethernet and CD-ROM/audio enabled, and the SCSI block cache enabled. No development-profile OSD, audio-output, composite, video-calculation, shadowmask, or 512-mode removals were active. See `docs/full-feature-config-20260925.md` for the configuration audit. MiSTer CFG was `40 00 00 00` (Ethernet on, 33 MHz, 32 MB); no CFG change was needed. Slot 0 remained the disposable `games/MacQuadra800/QuadSquad8-pipeline-test-20260919.hda`. The protected `QuadSquad8.hda` was not read or modified.

The loader sent `load_core` and verified the copied file, but its `coreRunning` check continued to say `FM-7` and returned failure. The screen changed from the FM-7 Space Warp game to a classic Mac desktop with the Quad Squad volume, and a later screen showed the menu-bar clock advance. MiSTer PID 18332 held the disposable HDA open. The stale `coreRunning:FM-7` report remains an unresolved identity-report discrepancy; it is not hidden by the visual boot evidence. Main's binary contained the documented Quadra/CD capability markers, but its exact source build identity was not established. Deployment and screenshots are documented in `scratch/interim_mac_wqmlab_hw_20260924/README.md` and `deploy.log`.

## Speedometer 4.02 Benchmark Mix

Five runs used the documented Finder type-select/Command-O and Command-B sequence. Before each run, the Benchmark Mix setup showed all ten tests checked with `Iter. 1`. Each completion screenshot visibly showed “The tests are done!”, all ten result rows with `Itr. 1`, and nonzero Int. Matrix and Sieve values. No timed benchmark run was invalid or excluded. An initial navigation attempt opened Folder Icon Maker before any benchmark started; it was closed, Finder was rechecked, and the documented sequence was repeated successfully. That setup attempt is retained in `run1.log` but is not a benchmark run.

KWhetstones/s and Dhrystones/s are rates; all other per-test measurements are elapsed seconds. Mix is Speedometer's aggregate score.

| Run | Start UTC | Completion UTC | KWhetstones/s | Dhrystones/s | Towers | Quick Sort | Bubble Sort | Queens | Puzzle | Permutations | Int. Matrix | Sieve | Mix | Evidence |
|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 02:47:05 | 02:48:02 | 1778.305 | 20049.120 | 0.474 | 0.502 | 0.574 | 0.339 | 0.719 | 0.703 | 0.481 | 1.031 | 1.817 | [`run1_complete.png`](perf/interim_wqmlab_20260925/run1_complete.png) |
| 2 | 02:49:11 | 02:50:08 | 1803.377 | 20047.480 | 0.476 | 0.502 | 0.573 | 0.338 | 0.715 | 0.705 | 0.477 | 1.025 | 1.828 | [`run2_complete.png`](perf/interim_wqmlab_20260925/run2_complete.png) |
| 3 | 02:51:23 | 02:52:20 | 1801.013 | 20060.848 | 0.475 | 0.504 | 0.574 | 0.339 | 0.717 | 0.704 | 0.473 | 1.021 | 1.829 | [`run3_complete.png`](perf/interim_wqmlab_20260925/run3_complete.png) |
| 4 | 02:53:43 | 02:54:39 | 1800.066 | 20046.652 | 0.475 | 0.502 | 0.573 | 0.338 | 0.716 | 0.704 | 0.472 | 1.022 | 1.829 | [`run4_complete.png`](perf/interim_wqmlab_20260925/run4_complete.png) |
| 5 | 02:55:30 | 02:56:26 | 1796.228 | 20019.779 | 0.474 | 0.504 | 0.574 | 0.339 | 0.714 | 0.704 | 0.474 | 1.020 | 1.827 | [`run5_complete.png`](perf/interim_wqmlab_20260925/run5_complete.png) |
| **Median** |  |  | **1800.066** | **20047.480** | **0.475** | **0.502** | **0.574** | **0.339** | **0.716** | **0.704** | **0.474** | **1.022** | **1.828** |  |

Mix median is 1.828 (range 1.817–1.829). Native screenshots were visually checked; OCR incorrectly transcribed several Mix values and was not used for the aggregate. Individual rows are stable across the five completed runs.

## Comparison and limits

The five-run P212 full-cache development-profile median was 1.725. This result is 6.0% higher by Mix, but the profiles differ: P212 omitted OSD menu and sound, whereas this candidate used the normal full-feature QSF. P232's five-run median was 1.778, but it was also a development profile and explicitly used `SCSI_CACHE_OFF`; it is diagnostic rather than a like-for-like baseline. These aggregate differences do not isolate a cause.

The real Quadra 800 reference screenshot reports Mix 1.897, so this candidate's median is 96.4% of that score. Its visible RAM was 122,880 KB versus this MiSTer's 32,768 KB; the reference comparison therefore also has a memory-configuration difference. Candidate median per-test values versus real Q800 are: KWhetstones 1800.066 vs 1978.474/s, Dhrystones 20047.480 vs 24999.350/s, Towers 0.475 vs 0.469 s, Quick Sort 0.502 vs 0.532 s, Bubble Sort 0.574 vs 0.566 s, Queens 0.339 vs 0.307 s, Puzzle 0.716 vs 0.799 s, Permutations 0.704 vs 0.619 s, Int. Matrix 0.474 vs 0.599 s, and Sieve 1.022 vs 0.974 s. Lower elapsed seconds are faster. These are observed score comparisons, not controlled attribution.

The fifth completion screenshot shows the guest in Speedometer with its done dialog. At the benchmark checkpoint, Ethernet traffic, CD audio/data, OSD usability, normal shutdown, and a physical disk-cache threshold had not been tested. Subsequent peripheral results are recorded below. Do not hash or back up either HDA until a clean guest shutdown and confirmation that Main released the file.

Raw command logs, per-run setup captures, completion captures, and boot evidence are in `scratch/interim_mac_wqmlab_hw_20260924/`. The screenshots show the completion dialogs and result rows; see the linked full-size images above.

The five pre-run setup captures are also preserved in [the tracked evidence directory](perf/interim_wqmlab_20260925/), alongside the completion images.

## Ethernet checkpoint (03:04 UTC)

The live guest address 10.3.231.233 replied to all 1,000 ICMP requests with
1,400-byte payloads, at five requests per second: 0% loss, mean round-trip
3.456 ms, minimum 3.172 ms, maximum 5.978 ms. This verifies the tested packet
traffic, not yet the planned 10 MB file integrity in both directions.
[Raw ping output](perf/interim_wqmlab_20260925/ethernet_ping1000.log).

MiSTer's `/tmp/CORENAME` reads `MacQuadra800`, independently confirming the
loaded core name while the websocket still reports its stale FM-7 label.
The installed Main does not contain the `/tmp/mac_eth_stats` path string;
that file is absent and stdout/stderr point to `/dev/console`. No alternate
Ethernet statistics files were found in `/tmp`. Thus DMA/RPC error-counter
coverage is unavailable; packet delivery does not establish zero internal
errors. Main was not restarted or replaced to obtain diagnostics.
[Instrumentation observations](perf/interim_wqmlab_20260925/ethernet_instrumentation.txt).

Speedometer subsequently quit to Finder without saving its Machine Record.
Ethernet FTP integrity is now complete; CD data/audio, OSD and normal shutdown
remain pending.


## Ethernet FTP integrity (2026-09-25)

Fetch 3.0.3 connected to the local FTP server at `10.3.141.107:2121` from the
guest at `10.3.231.233`. Both transfers used Binary/Raw Data mode. The 10 MB
`test_10m.bin` download completed at exactly 10,485,760 bytes; the server
logged RETR completion in 121.242 s, while Fetch displayed 85,948 bytes/s at
completion. The downloaded file was saved on the disposable Quad Squad disk,
then duplicated and the copy renamed in Finder to `q800-wqmlab-20260925.bin`
for a unique upload name.

Fetch uploaded that guest file to `dropbox/q800-wqmlab-20260925.bin` as Raw
Data. The server logged 10,485,760 bytes received in 41.007 s. The original
`dropbox/test_10m.bin` was not overwritten. Source, original dropbox copy, and
new upload each remain 10,485,760 bytes and share SHA-256
`39a3a96f5ed02b53f771b255f51a4006cdddeeabefcecd01eb7846f82de9dc81`; the
uploaded file's MD5 is `183580bf321c5b5d128a535cdc1e89f2`, matching the source.
The upload was the downloaded guest file, so this round trip verifies both
guest read and write paths without hashing the mounted HDA. Rates are recorded
as observations, not compared against a pass threshold.

The [FTP transfer log](perf/interim_wqmlab_20260925/ethernet_ftp.log) records
the server RETR/STOR evidence and hashes. Screenshots preserve the connected
dropbox listing, download progress/completion, unique guest filename, upload
confirmation, and upload completion in
[tracked FTP screenshots](perf/interim_wqmlab_20260925/).


## Normal shutdown (2026-09-25 04:19 UTC)

After quitting Fetch and returning to Finder, the normal Special → Shut Down
sequence reached “It is now safe to switch off your Macintosh”. Root independently
reviewed the [fresh shutdown capture](perf/interim_wqmlab_20260925/mac_shutdown_verified.png).
An earlier capture was black and was rejected as insufficient evidence; the later
capture establishes the pass without relying on descriptor position or a filename.
Main still held the disposable HDA descriptor open, so no mounted-disk hash or
backup was attempted. This validates guest shutdown, not release of the host file.

A controlled virtual-keyboard F12 probe did not expose the OSD in the native
capture, which may exclude the overlay. OSD usability and hot-mount remain
unverified. CD tests are proceeding through the authorized same-core startup
mount fallback, preserving the original slot-4 configuration.


## CD-ROM data (2026-09-25 04:22–04:25 UTC)

After the verified shutdown, slot 4 was set to the staged
`interim-validation-20260924/HFS-Data-Test.iso` and the same candidate core
was reloaded. The original 1024-byte empty-path `.s4` was preserved exactly
for restoration. Main opened the ISO, and Finder displayed the mounted
[Q800 Data Test volume](perf/interim_wqmlab_20260925/cd_data_mounted.png).
Its [directory](perf/interim_wqmlab_20260925/cd_data_directory.png) contained
the expected `MacQuadra800-CD-README.txt`. SimpleText opened and displayed
[the README contents](perf/interim_wqmlab_20260925/cd_data_readme.png), which
root compared with the known 146-byte fixture text. The Unix newlines rendered
as box glyphs, but the expected text was present. No additional copy or binary
hash check was performed in the guest; this is a functional mount, directory,
and file-read pass. It does not establish OSD hot-mount operation.

For the subsequent audio test, the same core was reloaded with `ToneTest.cue`.
Live checks confirmed `/tmp/CORENAME=MacQuadra800`, installed RBF SHA-256
unchanged, and Main PID 21961 holding the disposable HDA and ToneTest CUE/BIN
files. A fresh desktop capture showed Audio CD 1. An earlier FM-7 image was
rejected as invalid boot evidence. Audio controls and audible output remain
pending at this checkpoint.
