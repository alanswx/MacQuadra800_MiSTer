# Experimental full-feature test build

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
