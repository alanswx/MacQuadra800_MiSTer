# Interim build completion audit

This audit is incomplete: physical audio and OSD verification are still missing.
It does not declare the goal achieved or approve a timing-clean release.

| Requirement | Evidence and present result |
|---|---|
| Fitted full-feature artifact | Source `15a1449`, normal QSF, fresh archived RBF SHA-256 `4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`; placement/routing/assembly succeeded. The wrapper exited 1 for timing failures. |
| Reproducible source/configuration | `88a8a5d` restored the two rejected experimental inputs. Every entry in the successful fit's `tracked_before.sha256` passed a fresh hash check. No subsequent HDL/configuration change. |
| Normal MiSTer, Ethernet, CD-ROM/audio, disk caching enabled | [Configuration audit](full-feature-config-20260925.md). No development profile or feature-removal macros active; disk cache enabled with 32-sector hard-disk windows. This proves configuration, not every peripheral behavior. |
| Resources | 40,651/41,910 ALMs estimated needed; 4,182/4,191 LABs; 28,588 registers; 509/553 RAM blocks. |
| Timing and crossings | CPU/RAM/HDMI setup misses -2.406/-0.697/-0.426 ns; all summary holds positive. Required queue capture/pointer setup and hold reports pass. Optional internal MLAB collections were empty and are not covered. |
| Correctness regressions | Retained CPU directed/pipeline evidence is linked from the recovery notes; [MLAB queue validation](sdram-write-queue-mlab.md) records SDRAM, registered-first-miss, DMA, actual primitive, and negative-test coverage. These checks are relevant coverage, not exhaustive CPU correctness proof. |
| Boot and guest input | Mac Finder booted with the disposable HDA; keyboard/mouse used throughout tests, clock advanced. Subsequent same-core boots with data and audio discs succeeded. |
| Normal shutdown | [Verified safe-halt image](perf/interim_wqmlab_20260925/mac_shutdown_verified.png). Host HDA descriptor remained open; guest halt does not establish host file release. |
| Ethernet operation | 1,000/1,000 1,400-byte pings, zero loss; 10 MiB FTP round trip with matching SHA-256 and MD5. Internal DMA/RPC counters unavailable in installed Main; not claimed zero. |
| Disk cache operation | Enabled in fitted configuration; exercised by guest boot, applications, and FTP writes/reads. No dedicated hardware hit-rate or throughput threshold is established. |
| CD-ROM data | Known HFS volume mounted, directory opened, expected README read and compared visually with fixture source. Startup mounting tested; OSD hot-mount not proved. |
| CD audio | Disc and track list mounted; Play/Pause/Resume/Stop screenshot evidence reviewed. Physical audible output is still pending the user. Final transport evidence archival is in progress. |
| OSD usability | Inconclusive F12 probe; screenshot path may omit overlay. Requires observable hardware confirmation. |
| Five valid Speedometer runs | 1.817, 1.828, 1.829, 1.829, 1.827; median 1.828. All ten tests enabled, one iteration, completed alerts, nonzero Matrix/Sieve. [Detailed metrics and screenshots](INTERIM_WQMLAB_HARDWARE_20260925.md). |
| A/UX | Explicitly deferred to Dani by the user; disk image unavailable. |
| Commit/push and recovery | Source restoration, benchmark/Ethernet/shutdown/CD-data evidence pushed to `origin/add-ethernet`. Final audio evidence, restored slot-4 state, and final handoff remain to be committed when ready. |

The age-shift timing experiment did not fit and was not installed. No further
seed sweep is underway. The usable interim artifact remains the original fitted
source with its timing exceptions. Remaining physical checks must not be silently
redefined as passed. After the interim build is validated, proceed to memory
placement tradeoffs, then disk profiling and a measured disk-improvement plan.
