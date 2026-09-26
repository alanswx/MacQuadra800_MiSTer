# Test builds

## Pipeline back, timing met (2026-09-26): `MacQuadra800_pipeline_timingclean_20260926_31b6e99.rbf`

- Source `31b6e99` (seed 24), refit in the checkout reproduces it bit for bit.  SHA-256
  `ade84dbc0649433dcf2e8e464784382188248b909feae3105b18c95be936beef`, md5 `8481fce4`.
- **Timing met on every clock**: CPU +1.141, HDMI +0.158, SDRAM +0.791 ns; worst slack of any
  kind +0.158; SDRAM crossings +1.120 / +1.202.  38,487 ALMs, 469 M10K.
- The second integer pipeline is back (P243/P244 in the core); `SCSI_CACHE_OFF`, and three
  release-lite trims (audio IIR filter bypassed, video timing measurement off, no 512x384 mode).
- **Mix median 1.778** (1.768-1.784), PR 1.152 (Disk 1.595), FPU 0.687, Color 8-bit 13.97 s.
- Boot, pings, the data CD, the CD audio transport and shutdown pass; the full-machine boot
  sim reaches the Finder.  **Needs the Main write buffer** (`mac-disk-writebuffer-min`).
  Audible CD output, the OSD and A/UX remain unchecked.

## Candidate: SCSI cache off, 16+16 KB CPU caches (2026-09-25): `MacQuadra800_cacheoff_c16_s23_20260925.rbf`

- `a0b3072` plus `SCSI_CACHE_OFF=1`, `SETW = 8`, seed 23 (`docs/perf/cacheoff_s23_20260925/build/recipe.diff`).
  SHA-256 `954d7f18773d938bb282042baba5ea2db3098cbbada431b9cae4dccf46f66dd1`, md5 `cdd92e98`.
- **Timing met with margin**: CPU +0.360, HDMI +0.290, SDRAM +0.583 ns; holds, recovery/removal
  and SDRAM crossings positive.  37,532 ALMs, 485 M10K.
- Mix median **1.684** (five runs), PR Disk **1.604**, with the write-buffer Main.
- **Use it only with the Main write buffer** (`alanswx/Main_MiSTer` `mac-disk-writebuffer-min`);
  with an older Main every disk write waits ~4 ms for the card and the SCSI cache is needed.
- Boot, the Finder, Speedometer and disk copies were checked; CD, Ethernet and the audio/OSD checks
  have not been rerun on this build.

## Full-feature, timing-clean (2026-09-25): `MacQuadra800_fullfeature_timingclean_20260925_a0b3072.rbf`

- Source `a0b3072`, seed 21, Quartus 17.0.2.  SHA-256
  `ce26df46c0c7d7db0ef2d1088809f20adb2be92a3e8ea8eef9cc991d474e238e`, md5 `46b85dccbacd8c432fcd372b9d20ecaf`.
- **Timing met on every clock**: CPU +0.007, SDRAM +0.082, HDMI +0.044 ns setup;
  holds, recovery/removal and the SDRAM crossings positive.
- Ethernet, CD-ROM/CD audio, SCSI block cache, OSDs, audio and Y/C in.  The second
  integer pipeline is out (the area and timing price); CPU caches 8+8 KB.
- Speedometer Mix, five runs: median **1.670** (1.661-1.676).
- Ethernet pings, CD data, CD audio transport and normal shutdown pass; audible CD
  output, the OSD menu, the FTP round trip and A/UX are not yet checked.
  Evidence: `docs/perf/fullfeature_clean_20260925/`.
- Needs a Main with the Quadra 800 support (`grep -a -c macquadra800 MiSTer` > 0);
  with a Main that lacks it the screen stays black.

## Earlier: experimental full-feature interim build (timing NOT met)

This is the exact FPGA artifact used for the September 25 hardware tests.
**It is not a timing-clean release.** CPU/RAM/HDMI setup slacks are
**-2.406/-0.697/-0.426 ns**. Physical audible output and OSD usability are
still unverified; A/UX is deferred. Use a disposable test disk.

Artifact: [MacQuadra800_interim_20260925_15a1449.rbf](MacQuadra800_interim_20260925_15a1449.rbf)

- Source: `15a14497817ad8479bad91bf47d97e2163124d63`, seed 21, Quartus 17.0.2.
- SHA-256: `4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`.
- Normal features enabled: Ethernet, CD-ROM/CD audio, disk block caching,
  OSD and the normal MiSTer video/audio feature set.
- Five valid Speedometer Mix runs: median 1.828; fresh follow-up: 1.816.
- Boot/shutdown, Ethernet packet and file integrity, CD data reads, and CD
  playback controls passed their documented checks. Hardware success does
  not eliminate the setup-timing failures.

The branch's build inputs were restored to this fitted source and verified
against the archived manifest. Later documentation does not imply a newer RBF.
See [build evidence](../docs/perf/interim_wqmlab_20260925/build/README.md),
[hardware report](../docs/INTERIM_WQMLAB_HARDWARE_20260925.md), and
[fresh comparison](../docs/perf/INTERIM_VS_REAL_QUADRA800_20260925.md).
