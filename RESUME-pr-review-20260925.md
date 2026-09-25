# Handoff: full-feature CPU interim PR and fresh disk baseline

## Read this first

The current source is the tested full-feature CPU/area work, with build inputs
identical to fitted source `15a14497817ad8479bad91bf47d97e2163124d63`.
The unsuccessful SDRAM age-shift experiment was restored in `88a8a5d`; do not
restart its fits. No Quartus, simulation, or hardware-control job remains active.

Dani's target repository is `danifunker/MacQuadra800_MiSTer`, base `main`.
The fetched upstream/main is already an ancestor of this work, so no rebase or
merge is needed. The review branch is `alanswx:cpu-full-feature-interim-20260925`.
**Draft PR: https://github.com/danifunker/MacQuadra800_MiSTer/pull/6**

This is an experimentally working interim build with timing
failures and explicitly deferred physical checks, not a validated release.

## Fresh benchmark results

- Speedometer 4.02 all-ten Benchmark Mix, one iteration: **1.816**.
- Previous five valid runs: **1.817, 1.828, 1.829, 1.829, 1.827**, median **1.828**.
- Real Quadra 800 photo: **1.897**. Fresh Mix is **95.7%** of that aggregate;
  previous median is 96.4%. Real photo has 120 MiB RAM, guest has 32 MiB.
- Performance Rating (top Tests menu item), all four categories, one iteration:
  **Disk 0.565**, CPU 0.894, Graphics 1.041, Math 20.970, overall PR 0.914.
  Scale is **Quadra 605 = 1.0**, not MB/s. It used the disposable Quad Squad volume; the chooser required
  **1 MB free for its temporary file**. No cold-cache control or absolute
  transfer throughput was measured. Performance Rating CPU is not Mix.
- New real reference `docs/perf/speedometerrealquadra.png`: Disk **3.443**,
  Math 20.011, CPU 1.186, Graphics 1.347, PR 1.605. MiSTer disk rating is
  **16.4%** of this reference; real disk/cache conditions are unknown.
  Separate FPU reference: 5456.609 KWhetstones/s, Matrix 0.713 s, FFT 0.288 s,
  average 1.011 (Quadra 650 = 1.0). Matching MiSTer FPU run: **3837.386**
  KWhetstones/s, **1.033 s** Matrix, **0.460 s** FFT, average **0.681**
  (**67.4%** of the real average). All three tests, one iteration.

The [comparison report](docs/perf/INTERIM_VS_REAL_QUADRA800_20260925.md) includes
all ten absolute CPU metrics and the original reference photo. Clean results:
[CPU Mix](docs/perf/interim_wqmlab_20260925/fresh_mix_clean.png) and
[Performance/Disk](docs/perf/interim_wqmlab_20260925/performance_rating_clean.png).
Setup and completed-alert screenshots are retained alongside them.

## Artifact, features, and timing

The exact experimental RBF is now included for review in
[test-builds](test-builds/README.md), separate from published releases:
`MacQuadra800_interim_20260925_15a1449.rbf`.
SHA-256: `4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`.

Normal QSF, seed 21, Quartus 17.0.2. Ethernet, CD-ROM/CD audio, hard-disk block
caching and normal MiSTer video/audio/OSD features are enabled. CPU caches are
8 KiB instruction plus 8 KiB data; hard-disk cache windows are 32 sectors.
Required setup/hold queue crossing checks pass, but optional internal MLAB
endpoint collections were empty. Fit: 40,651/41,910 estimated ALMs needed,
4,182/4,191 LABs, 28,588 registers, 509/553 RAM blocks.

**Setup failures remain: CPU -2.406 ns, RAM -0.697 ns, HDMI -0.426 ns.**
All summary hold slacks are positive. Hardware success does not establish
correct operation across timing corners; do not call this timing-clean.
[Compact build reports and input manifest](docs/perf/interim_wqmlab_20260925/build/README.md).

## Validation and hardware state

Boot, keyboard/mouse, clock progression, normal shutdown, 1,000 packet pings,
10 MiB FTP round-trip SHA/MD5 integrity, HFS CD directory/file reads, and CD
Play/Pause/Resume/Stop controls passed. Relevant CPU/pipeline, cache, FPU and
SDRAM regressions are documented; ordinary legacy CPU tests are not a substitute
for experimental pipeline coverage. The checks are not exhaustive correctness
proof. Main's internal Ethernet DMA/RPC counters were unavailable.

**Physical audible output and OSD usability are pending at the user's explicit
request.** A/UX is deferred to Dani because no local disk exists. Do not repeat
permission/listening questions until the user is available. The goal is not
marked complete; [audit](docs/INTERIM_COMPLETION_AUDIT_20260925.md) lists limits.

MiSTer target remains **mister.local (10.3.89.233)**, installed core hash above.
The current guest is **running Speedometer**, with the clean FPU Benchmarks
panel foremost (Performance Test behind it); it is NOT on the prior safe-shutdown screen. Last observed Main
PID was 31518. Slot 0 is only
`games/MacQuadra800/QuadSquad8-pipeline-test-20260919.hda`. Protect the original
`QuadSquad8.hda`; no mounted HDA hashing/copying. Slot 4 remains the exact
restored 1024-byte empty-path buffer (first byte NUL, trailing bytes preserved),
SHA `885049f1219036556d7a8455af614213db3b98d35f4b587ae1b4c7ce2e2ace3f`.

## Next steps

1. Review the draft PR and reproduce with the provided artifact/source manifest.
   Keep timing and deferred physical checks explicit before any release decision.
2. Complete the user's audio/OSD observations when they are at the display;
   A/UX remains Dani's check. Coordinate one hardware operator and use Luna for
   routine tests. Same-core reloads on the disposable disk are authorized.
3. Assess global BRAM/SDRAM/DDRAM placement tradeoffs for VRAM, ROM, caches,
   and disk buffers before choosing a redesign.
4. Profile disk operation beyond this initial rating: separate reads/writes,
   sizes and access patterns, cache warmth, guest/FPGA/Main overhead and storage
   latency. Make a measured improvement plan before implementing changes.

The new disk score alone does not identify a bottleneck or prove DDRAM is the
right fix. No extra CPU/seed sweep is planned. The reviewed CPU timing fallback
in `scratch/brf_ack_data_select_review_20260924.md` is still unimplemented.

Commit and push progress to `origin/add-ethernet` and update the PR branch when
intended. No git worktrees. Leave unrelated untracked disk planning documents,
`worst_detail.txt`, `worst_paths.txt`, and `cr_ie_info.json` alone. Earlier
chronology: [previous validation handoff](RESUME-interim-validation-20260925.md).
