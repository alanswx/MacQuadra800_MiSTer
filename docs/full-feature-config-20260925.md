# Full-feature configuration audit

The fitted source `15a1449` uses the normal QSF, with both
`source configs/cpu_development.tcl` and `source configs/cpu_release_lite.tcl`
commented out. The checked-in QSF hash in the fit source manifest identifies
that configuration; subsequent SDRAM bank-age work does not alter it.

The active feature macros are the ten AP040 CPU enhancement switches,
`CACHE_SMALL=1`, and `CACHE_CD_OFF=1`. Ethernet and CD-ROM/CD audio remain
compiled in. The disk block cache remains enabled, with 32-sector windows for
each hard disk; CD bypasses this cache. The CPU cache configuration remains
8 KiB instruction plus 8 KiB data. No development-profile OSD, audio-output,
composite Y/C, video-calculation, shadowmask, or 512-mode removal is enabled.
The QSF also leaves the ALSA, adaptive-scaler, and downscale-NN restriction
macros commented out, despite older recipe comments describing them as active.
The included sys/sys.tcl and sys/sys_analog.tcl contain no further macro
assignments or source directives in this audited checkout.

## Evidence limitation

`scratch/interim_mac_wqmlab_fit_20260924/FEATURES.txt` is not a list of
active macros alone. `scripts/cpu/fit_dev.sh` line 41 appends the full contents
of both optional configuration templates even when their QSF source lines
are commented out. Reading the appended `SCSI_CACHE_OFF` or audio/OSD removal
macros as active would be incorrect. Use the exact QSF and its active source
directives, tied to the successful source-before/source-after manifest checks.
The artifact remains SHA256
`4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`.

This is a configuration audit, not a peripheral pass. Hardware Ethernet,
CD data/audio, OSD operation and normal shutdown still require direct results.
A/UX remains deferred at the user's instruction because its image is absent.
