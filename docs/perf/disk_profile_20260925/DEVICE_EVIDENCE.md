# Device and build evidence

Captured during the 2026-09-25 disk profile.

## Guest storage descriptor

MiSTer Main PID `31518` had descriptor 5 open to the disposable image:

```text
/proc/31518/fd/5 -> /media/fat/games/MacQuadra800/QuadSquad8-pipeline-test-20260919.hda
pos:    489633280
flags:  06410002
mnt_id: 16
ino:    14594
```

The Linux flag word includes `O_RDWR` and `O_SYNC` (`O_DSYNC` is the subset
bit included in `O_SYNC`). This verifies the live descriptor's mode without
reading or hashing the mounted image.

## Main binary and local source

The running `/media/fat/MiSTer` SHA-256 was
`6db4851b939dbef32297c3fcce47d37531daddf5214e9a28a54412afd6586fd0`.
The local source checkout used for path inspection was at
`0cb45beefebfc57da45eb4c77cd37770cb24fe28`; its working tree had an unrelated
CRLF-only change in `lib/miniz/ChangeLog.md`. No local Main executable was
available for a binary/source hash match, so the source inspection is not
claimed to prove the running binary's exact source revision.

The installed FPGA RBF, as supplied in the handoff, was SHA-256
`4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`.

## Available instrumentation

`strace` was not installed on the MiSTer; `iotop` was present. No tracing tool
was attached to Main, and Main was not restarted or replaced. The SCSI cache's
`stat_hits` / `stat_misses` are internal RTL outputs and were not exposed to
the currently loaded bitstream's host/debug interface. `SCSI_TRACE` is
commented out in the QSF, so this run could not count cache hits, cache misses,
or individual FPGA/HPS transactions.
