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

The fifth completion screenshot shows the guest in Speedometer with its done dialog. This task did not test Ethernet traffic, CD audio/data, OSD usability, normal shutdown, or a physical disk-cache threshold. Those remain separate checks. Do not hash or back up either HDA until a clean guest shutdown and confirmation that Main released the file.

Raw command logs, per-run setup captures, completion captures, and boot evidence are in `scratch/interim_mac_wqmlab_hw_20260924/`. The screenshots show the completion dialogs and result rows; see the linked full-size images above.

The five pre-run setup captures are also preserved in [the tracked evidence directory](perf/interim_wqmlab_20260925/), alongside the completion images.
