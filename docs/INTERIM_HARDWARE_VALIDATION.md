# Interim full-feature hardware validation checklist

Preparation only. Do not run this while the user is using MiSTer. Hardware use
requires the user to say the box is free. Apply this checklist to the exact
candidate RBF and report its fit/timing status. An authorized exploratory
check may proceed with a timing exception when the concrete artifact is
identified; report the exception, and do not describe the full build as
timing-clean.

## Before touching hardware

- Identify the exact fresh RBF and its source/configuration hashes. Record fit
  resources, timing slack, and clock-crossing results; state any failure or
  exception. The full-build goal still requires a successful full Quartus run
  and explicit timing reports. See [INTERIM_BUILD_GOAL](../docs/INTERIM_BUILD_GOAL.md).
- Target the shared box by `mister.local` (older local notes also call it
  `MiSTer.local`). Do not use stale `.143` / `.92` addresses. Check with the
  user that it is free before any SSH, screenshot, remote-control, or deploy
  command.
- The known disposable slot-0 image is
  `/media/fat/games/MacQuadra800/QuadSquad8-pipeline-test-20260919.hda`,
  Historical backup SHA-256 `224c5be7d031c4c5448745d29ce9717c22bcc310361888bb0e20f2c521c83e2a`
  (2,146,461,696 bytes). Guest writes can change this disposable image; do not require its current hash to match the historical backup. Preserve
  `/media/fat/games/MacQuadra800/QuadSquad8.hda`; confirm `config/MacQuadra800.s0`
  selects the disposable image. Hash/backup only after a clean guest shutdown
  and file release. Candidate reloads/resets on this disposable image are already authorized; no repeated clean-shutdown permission is needed. Still perform and record the normal shutdown check. A guest shutdown does not necessarily close Main’s disk descriptor, so verify release/unmount before hashing or copying. Never substitute or modify the protected original. The prior verified manifest and UI run procedure are in
  [disk_manifest.txt](../scratch/hardware_pipeline_baseline_20260919/disk_manifest.txt)
  and [navigation.md](../scratch/hardware_pipeline_baseline_20260919/navigation.md).
- Use `tools/misterdeploy/launch_unstable_core.py` with explicit
  `--host mister.local --ssh-key "$MISTER_SSH_KEY" --push <fresh-rbf>
  --core MacQuadra800.rbf --folder _Unstable`; it verifies the copied RBF and
  launched core. Do not pass any `--seed-*` arguments or use
  `scripts/deploy_screenshot.sh` defaults: the wrapper's default slot-0 seed
  names the protected original HDA. Candidate reloads/resets on the authorized
  disposable disk are allowed without another clean-shutdown approval; use a
  clean halt for the normal shutdown check when practical. Keep slot 0 on the
  disposable disk; record and restore the CD slot selection after CD tests.

## Boot, disk, and shutdown

- With Ethernet enabled at reset (CFG byte 0 `40`; full fast-path CFG previously
  tested as `40 00`), boot Mac OS 8.1 from the disposable HDA. Confirm the
  Finder desktop is responsive to keyboard and mouse, and the menu-bar clock
  advances over several minutes. Check normal disk use during boot and
  Speedometer; this exercises the configured SCSI read-ahead/write-behind
  cache.
- A dedicated hardware cache counter/throughput acceptance test is not
  specified in the existing docs. `cache_hits`/`cache_misses` are exposed for
  tracing, but no normal-run collection procedure or pass threshold is
  documented. Do not claim cache validation from simulated cache benches;
  record this as functional-use coverage unless instrumentation is arranged.
- For normal shutdown, use the MiSTer-side mouse helper because this box's
  mrext lacks mouse input:

  ```sh
  ssh root@mister.local 'python3 /media/fat/Scripts/q800tools/vmouse.py home m:111,-10 0.5 down 0.8 m:13,66 6 up'
  bash scripts/grab_fresh.sh <evidence>/shutdown.png
  ```

  Pass only when the screen says “It is now safe to switch off your
  Macintosh”. This is a required normal-shutdown test; candidate reloads/resets on the expressly authorized disposable image remain allowed. Do not treat the screenshot alone as proof Main closed its HDA descriptor. The exact descriptor check is documented in
  `scratch/hardware_pipeline_baseline_20260919/navigation.md`.

## Ethernet and CD audio

- Ethernet needs the Quadra-enabled Main fork and OSD Ethernet-On-Reset set to
  On with the correct network interface, then a reset/core start so the guest
  never sees the device appear mid-session. Confirm DHCP and read the current
  guest address from `/tmp/mac_eth_stats`/DHCP rather than assuming an old
  address. Pass: 1,000 of 1,000 1,400-byte pings; FTP 10 MB download and upload
  each finish with byte-exact MD5; `/tmp/mac_eth_stats` shows no DMA timeout
  or RPC failure. The prior passing setup and data are in
  [RESUME-handoff-20260919.md](../RESUME-handoff-20260919.md) and
  [docs/ethernet.md](../docs/ethernet.md). FTP host credentials are local
  operator setup; retrieve them from the current trusted handoff rather than
  assuming network reachability or reusing a stale IP.
- CD audio uses `games/MacQuadra800/ToneTest.cue` in slot 4 via
  `config/MacQuadra800.s4`, and requires the shipped Quadra-aware Main fork
  (`releases/MiSTer_20260916` or later). In Mac OS, confirm “Audio CD 1” mounts;
  Play advances with the menu-bar clock, Pause freezes, Resume continues, Stop
  returns to Track 01 00:00, and no “drive is not responding” dialog occurs.
  Separately test CD-ROM data: mount the known flat HFS data image
  `/media/fat/games/MacQuadra800/Open Transport 1.3.1.iso` in slot 4, then
  confirm its volume appears in Finder, open it, inspect a directory, and open
  or copy a file from the disc to the disposable HDA. Record the image path and
  successful file read; audio controls alone do not validate data reads. The
  image is identified in `RESUME-cdrom-and-video.md`. If Main's `Mac CD: cmd`
  log is not already available, do not relaunch Main
  under the running core; arrange logging before the session. The final audible
  output check must be judged by the operator at the display.

## Five Speedometer Mix runs

Use the complete, already exercised UI sequence in
[navigation.md](../scratch/hardware_pipeline_baseline_20260919/navigation.md), targeting
`mister.local` after sourcing `scripts/local.env`. Do not capture during a
timed run. For every run, capture a fresh completion screenshot and record all
ten scores, Mix, start/end time, and evidence path. A run counts only if the
completion alert says “The tests are done!”, all ten tests show Iter. 1, and
Matrix/Sieve are nonzero and plausible. Replace invalid runs; retain their
evidence and identify them as invalid. Complete five valid runs and compare
the individual values and median with the prior working build and real Q800
reference. Latest completed full-cache comparison: P212, five valid values
1.716/1.725/1.725/1.725/1.726 (median 1.725), but it was a development
profile without OSD menu or sound, and its CPU timing missed by 1.446 ns. The
newer P232 result is 1.778 over five valid runs, but used `SCSI_CACHE_OFF`
and is diagnostic, not a full-feature/cache-on baseline. Compare the new
candidate against P212 and the real Q800 reference (1.897), while explicitly
noting these profile differences; look up any newer accepted full-feature
five-run baseline before reporting. The exact run criteria are in the
navigation guide.

## Evidence and limits

Record RBF SHA-256, source commit, build seed/config, fit/timing/crossing
reports, Main version, CFG, slot-0 image hash, Ethernet outcomes, CD control
and audible outcome, shutdown screenshot, and all five valid Speedometer
screenshots/metrics. Keep A/UX explicitly deferred (image unavailable per the
build goal). A desktop screenshot cannot verify audible CD output, and current
docs define no independent physical disk-cache threshold; mark those operator
checks/limits plainly in the handoff.

## September 24 preflight and replacement fixtures

The user has released the FPGA and authorized replacing the running core.
Read-only preflight confirmed mister.local resolves to 10.3.89.233, SSH and
remote input work, and slot 0 points to the disposable test HDA. The original
HDA is present and protected. The running core was FM-7; no core was changed.
Main's Quadra-specific version remains unverified.

ToneTest and the old Open Transport data fixture were missing. Replacement
fixtures are ready in `scratch/interim_hardware_preflight_20260924/fixtures/`:

- ToneTest.cue/bin, generated by `scripts/make_tonedisc.py`; BIN SHA-256
  `d7b79ff2ea7455c431bed459c50a6333ce1c8213c5244150ca511da57e95d06c`.
- HFS-Data-Test.iso, a 16 MiB flat HFS volume labelled `Q800 Data Test`.
  Its known 146-byte text file has Finder type/creator TEXT/ttxt. hfsutils
  listed and extracted it, and byte comparison passed. Image SHA-256
  `3aff251d770216fd5eabe1ae9ef4a2db7abe9d473f8aa688cba635bd9c3ab68b`.

The fixture directory contains `build_hfs_fixture.sh`; generation and checks
are recorded in `scratch/interim_hardware_preflight_20260924/asset_discovery.md`.
HFS volume timestamps mean a rebuild may have a different whole-image hash.
The three fixtures have been transferred to
`/media/fat/games/MacQuadra800/interim-validation-20260924/` on verified
mister.local (10.3.89.233); all destination SHA-256 values match the local
files. That directory was absent before creation. No slots, core, Main, or
HDAs were changed. Transfer evidence is in
`scratch/interim_hardware_preflight_20260924/fixture_transfer.md`.
Local validation does not prove the guest CD path; mount/open/copy and audio
tests remain required.

The installed Main binary SHA-256 is
`6db4851b939dbef32297c3fcce47d37531daddf5214e9a28a54412afd6586fd0`.
It does not match local named Main binaries, but contains the distinctive
`macquadra800`, `Mac CD: cmd`, and `Quadra 800 SONIC` markers. This supports
the required capabilities without establishing exact source provenance or
functional success. See `scratch/interim_hardware_preflight_20260924/main_identity.md`.
