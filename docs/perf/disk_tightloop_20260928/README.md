# Tight-loop Main experiment, 2026-09-28 evening: variant (a) only, and a hang

Release core `b7e88b81`, disposable QuadSquad8 copy, 32 MB, Ethernet OSD option On.
Main variants built in `scratch/mac_main_sdprof_20260928/` (see
`docs/disk-main-path-20260928.md`): (a) `MiSTer_sdprof` (counters only, md5
`1603be2f`), (b)-(e) the tight-loop build at several spin/budget settings. Only
(a) ran; the tight-loop variants are still unmeasured.

## Install mechanism (reusable)

busybox init starts Main from `/etc/inittab` line 21 (`::sysinit:/media/fat/MiSTer &`),
before rcS. `/` is read-only by default. `/media/fat/linux/tl_install_main.sh <binary> "<vars>"`
remounts `/` rw, rewrites the line to
`::sysinit:/usr/bin/env $(cat /media/fat/linux/main_env.txt 2>/dev/null) /media/fat/MiSTer &`,
writes the variables to `main_env.txt`, installs the binary and remounts ro. Main
execs `/proc/self/exe` on a core load, so the environment reaches the core.
Backups on the box: `/media/fat/MiSTer.ff404af9`, `/etc/inittab.orig-20260928`.
Local scripts: `scratch/disk_tightloop_20260928/{reboot_verify.sh,tl_pr.sh,tl_dup.sh,analyze.py}`.

## Boots

Attempt 1: "bus error" over Welcome to Mac OS on the first core boot after the
Main install (the first-boot flake `RESUME-20260927.md:1622` records). A clean
MiSTer reboot and a second boot reached the Finder.

## Variant (a) results, before the hang

| measure | result |
|---|---|
| PR (CPU / Graphics / Disk / Math / PR), 3 runs | 0.896 / 1.118 / 1.526 / 21.432 / 1.176; 0.895 / 1.166 / 1.474 / 21.407 / 1.184; 0.895 / 1.155 / 1.527 / 21.473 / 1.187 |
| Photoshop duplicate 1, 2 | 7.62 s (519 kB/s), 7.38 s (536 kB/s) |
| read / write phase | 1.83-1.89 / 0.96 MiB/s |

PR Disk about 6 % under the `ff404af9` baseline (1.623): the counters cost about
ten `clock_gettime` calls per request. PR CPU 0.895 again, so the baseline
session's 0.796 was a one-boot effect.

sdprof over duplicate 2 (40 s): 9,979 reads, 7,747 writes; 192 us of Main service
per request; SPI 109 us per read sector, 154 per write; pass 110 us average, 46 ms
max; **`mac_poll` 19.06 s of 40 s (48 % of Main's time, about 53 us per pass with
the Ethernet option on)**; 78 write-buffer flushes, 835 ms, max 45 ms; ack-to-next-
request gaps: 0 under 50 us, 5,077 under 100, 6,918 under 200, 5,617 under 500,
113 above.

## The hang (duplicate 3, 01:14 UTC)

Source read completely (3,958,784 B); writes stopped at 2,442,240 B (62 %); the
copy dialog froze at about 85 %; the menu-bar clock stopped; the pointer still
followed vmouse (interrupt level alive), the Finder was stuck; Main kept polling
(pass 99 us) and **never saw another request: the 53C96 engine stopped asking**;
every written byte had been flushed to the card. Screens `dup3_after.png`, log
`sdprof_full_at_hang.log`. The baseline session on `ff404af9` had run five PRs
and five duplicates cleanly, so this is a core-side stall in the write path that a
slightly slower Main service exposed, or an intermittent one. To be reproduced in
the full-machine sim with randomised sector-service latency before the tight-loop
variants are measured further. The original Main and inittab were restored.
