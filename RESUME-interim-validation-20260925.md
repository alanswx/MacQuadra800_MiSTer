# Resume: full-feature interim hardware validation

Latest fresh CPU/disk results, PR context, and live guest state: [PR review handoff](RESUME-pr-review-20260925.md).

## Current result

The normal-feature source `15a14497817ad8479bad91bf47d97e2163124d63` fits,
boots, and scores **1.828 median** over five valid Speedometer Mix runs:
1.817, 1.828, 1.829, 1.829, 1.827. All ten tests were enabled at one iteration.
Ethernet, CD-ROM/CD audio, disk caching, OSD and normal video/audio features
are compiled in; neither development profile is active.

The working artifact is:
`scratch/interim_mac_wqmlab_fit_20260924/MacQuadra800_interim_mac_wqmlab_15a1449.rbf`

SHA-256: `4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`.
It is installed on **mister.local (10.3.89.233)** as
`/media/fat/_Unstable/MacQuadra800.rbf`. Only this MiSTer is authorized.

This is an interim artifact, **not timing-clean**. CPU/RAM/HDMI setup slacks
are **-2.406/-0.697/-0.426 ns**. Summary holds pass; required queue capture
and pointer setup/hold checks pass, but optional internal MLAB collections
were empty. Fitted resources: 40,651/41,910 ALMs estimated needed,
4,182/4,191 LABs, 28,588 registers, 509/553 RAM blocks.

## Source and experiment disposition

The SDRAM bank-age shift experiment passed functional checks but failed routing
at seeds 21 and 28. The final seed-28 attempt took 50m07s in fitting / 55m30s
for the wrapper; no fresh RBF or timing result. Earlier tool crash and execution
interruption are separately recorded, not counted as equivalent design failures.
No Quartus job or seed sweep remains active.

Commit `88a8a5d` restored the exact fitted RTL and QSF. Every hash in
`docs/perf/interim_wqmlab_20260925/build/tracked_build_inputs.sha256` was checked
again after restoration. Current build inputs match the tested artifact's source;
subsequent commits add evidence/documentation only. Do not restart a fit simply
because an old checkpoint says one is active.

## Verified hardware coverage and remaining gates

- Boot to responsive Finder, keyboard/mouse operation, advancing clock, and
  normal shutdown to the readable safe-to-switch-off screen passed.
- Ethernet: 1,000/1,000 1,400-byte pings, zero loss; 10 MiB FTP download/upload
  round trip with matching SHA-256 and MD5. Installed Main lacks the expected
  DMA/RPC counters, so zero internal errors is not established.
- CD-ROM: replacement HFS ISO mounted as Q800 Data Test; directory and known
  146-byte README opened in SimpleText and text matched the fixture source.
- CD audio transport: Audio CD 1 and four tracks mounted; Play advanced exactly
  36 seconds over one observed 36-second interval and 49 over 49; Pause held
  Track 2 at 00:30 across 105 seconds; Resume advanced, Stop returned to Track
  1 at 00:00. These are UI observations, not audio sample-clock measurements.
- **Audible output remains unverified.** A listening question was sent during
  playback, but no user response arrived. CLAUDE.md requires listening at the
  display; screenshots cannot substitute for it.
- **OSD usability remains unverified.** One controlled F12 probe could not be
  observed in native captures, which may omit the overlay. CD tests used
  startup selection, so live OSD mounting is not proven.
- Disk caching is enabled and exercised by normal guest I/O; no hardware
  cache-hit or disk-throughput acceptance measurement is claimed.
- A/UX is explicitly deferred to Dani because the image is unavailable.

## Hardware restoration checkpoint

The original slot-4 selection was a 1024-byte buffer with an empty C-string
path (first byte NUL, 32 nonzero trailing bytes). It has been restored exactly
from `/media/fat/config/MacQuadra800.s4.cdtest-backup-20260925`; both hashes:
`885049f1219036556d7a8455af614213db3b98d35f4b587ae1b4c7ce2e2ace3f`.
A same-core reload then opened only the disposable HDA, with no ToneTest files.
Main PID 23834 and CORENAME=MacQuadra800 were observed after that reload.
The restored configuration booted to Finder and then shut down normally. Root
independently viewed `final_safe_halt.png` at 05:03 UTC and independently checked
the current core identity, RBF hash, and empty-path buffer/hash. The safe screen
remains up; no hardware input or build is ongoing. Recheck on resume.

Slot 0 remains `games/MacQuadra800/QuadSquad8-pipeline-test-20260919.hda`.
Never touch the protected `QuadSquad8.hda`. No mounted HDA was hashed or copied.
A safe guest screen does not prove Main released its descriptor. User permits
same-core reloads on the disposable disk; no repeated permission is needed.
Websocket coreRunning may still say FM-7, and early captures sometimes showed
old/black images. Require current readable screenshots and independent core,
artifact, and descriptor evidence; reject misleading captures.

## Next steps

Obtain the user's physical CD-audio and OSD observations. Restoration and the
final normal shutdown are complete. For listening, remount the staged ToneTest CUE
using the existing recovery procedure; Track 1 is a 440 Hz tone in both channels
with a short 2 kHz click each second. Restore slot 4 afterward. Do not declare
the goal complete or publish a validated release while these checks are missing.

After the interim build is validated, assess BRAM/SDRAM/DDRAM placement tradeoffs
for VRAM, ROM, CPU caches and disk buffers; then profile disk performance and
write a measured improvement plan. Do not resume CPU/seed experiments merely to
fill waiting time. A future CPU timing option is documented in
`scratch/brf_ack_data_select_review_20260924.md`; it is unimplemented/unmeasured.

Commit and push meaningful results to `origin add-ethernet`, as authorized.
Use Luna for routine hardware/build work; coordinate one hardware operator.
No git worktrees. Preserve unrelated untracked disk-planning files,
`worst_detail.txt`, `worst_paths.txt`, and the archived crash JSON.

## Evidence

- [Completion audit](docs/INTERIM_COMPLETION_AUDIT_20260925.md)
- [Hardware results and screenshots](docs/INTERIM_WQMLAB_HARDWARE_20260925.md)
- [Build summaries and input manifest](docs/perf/interim_wqmlab_20260925/build/README.md)
- [Feature configuration](docs/full-feature-config-20260925.md)
- [Rejected age-shift experiment](docs/SDRAM_BANK_AGE_SHIFT_20260925.md)
- [Earlier chronological recovery notes](RESUME-fit-recovery-20260924.md)

Critical summaries/screenshots are tracked. The exact RBF is now preserved in
`test-builds/` for PR review; raw scratch logs remain local. See the newer handoff
for the fresh benchmark session and PR state.
