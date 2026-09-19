# Regression run, 2026-09-19 -- operator report

Candidate core `output_files/MacQuadra800.rbf`, md5 **933b421a0880177be1b5fb2861dcea15**
(verified locally before the push and on the box after it). Main
**fbb540c8a51134cfdc960a8b5115807b**, already installed by the main session.
Box: 192.168.99.143 only. All times are box time (EDT). Every claim below is
marked SEEN (read out of a screenshot or a command's output) or INFERRED.

Result: **every phase PASSED.** Nothing was left running; the box is back at
the MENU core with the user's slots byte-identical to how they were found.

---

## Phase 0 -- prepare

| item | value | source |
|---|---|---|
| `/tmp/CORENAME` at start | `MENU` | SEEN (ssh) |
| screen at start | `P0_menu.png` -- the menu core's noise field, OSD closed, no guest | SEEN |
| CFG bytes 0..3 at start | `40 04 00 00` (Ethernet on, bring-up switch `04` set) | SEEN |
| `md5sum /media/fat/MiSTer` | `fbb540c8a51134cfdc960a8b5115807b` | SEEN -- phase 0c verification only, nothing installed |
| `.s0` as found | `games/MacQuadra800/QuadSquad8.hda` (+ stale tail `-Installed.hda`), md5 `c7496f5fb868b11f22890e45e2184c87` | SEEN |
| `.s1` as found (user's) | `games/MacLC/MacLC_7-1-MiSTer.hda` (+ stale tail), md5 `f8ea7ed8bdb3a97451fe0c764bc038b4` | SEEN |
| `.s4` as found (user's) | `games/MacLC/CD3/TIM_3-mac.CUE`, md5 `b245602392ea422e5d3c3b53070a2891` | SEEN |

Parked (user-approved) as `MacQuadra800.s1.parked_user` /
`MacQuadra800.s4.parked_user`. `.s0` was also copied aside as
`.s0.orig_20260919` so it could be put back byte-for-byte.

The `_Unstable` copy already there (md5 `edf32a3bd2ce6c71b39270d5c3f72f46`,
build 8) was renamed `MacQuadra800.rbf.build8_edf32a3b` -- the extension is no
longer `.rbf`, so Main does not list it as a second core. The candidate was
`scp`ed to `/media/fat/_Unstable/MacQuadra800.rbf`; md5 on the box read back
`933b421a0880177be1b5fb2861dcea15`. No core was loaded at this point.

## Phase 1 -- Mac OS 8.1, Ethernet ON (`40 00`)

`.s0` = `.s0.quadsquad`, `.s1`/`.s4` absent, CFG patched to `40 00` and
re-read as `40 00` after the launch (Main did not rewrite it). Loaded 11:22:00.

**Boot -- PASS.** `P1_desktop.png` (11:23:41, ~100 s after the load): the Mac OS
8.1 Finder desktop, "Quad Squad" window open, menu-bar clock `Sat 11:23`. SEEN.

**Ethernet -- PASS, this is the headline result.** At `40 00` (all CPU fast
paths ON) the guest stayed up and answered every packet. Before the fix it died
within seconds at this setting.

| run | file | result |
|---|---|---|
| reachability, 6 x 32 B | `P1_ping.txt` | 6 sent / 6 received / 0 lost, avg 2 ms |
| soak 1, 250 x 1400 B (11:24:05-11:28:17) | `P1_soak_1.txt` | **250 / 250 / 0 % loss**, min 3 / max 8 / avg 3 ms |
| soak 2, 250 x 1400 B (11:28:17-11:32:32) | `P1_soak_2.txt` | **250 / 250 / 0 % loss**, min 3 / max 4 / avg 3 ms |

**Total at `40 00`: 506 sent, 506 received, 0 lost.** All SEEN in the ping
output.

`P1_stats.txt` (`/tmp/mac_eth_stats`, SEEN) after the soaks: `rx_frames 9670`,
`rx_bytes 4138363`, `tx_frames 531`, `tx_bytes 724034`, `txp_cmds 534`,
`sonic_tx chains=534 pkts=534 eol=534`, and **every error counter zero** --
`tx_fail 0`, `sock_drops 0`, `rpc_fail 0`, `q8 rpc ... fail 0`, `ring_ovf 0`
(`ring_max 9`), `drain_full 0`, `rx_held 0`, `bad_addr 0`, `redeliver rx 0 tx 0`.
No DMA-timeout indication anywhere.

**Desktop responsive -- PASS.** Pointer moved under command;
`P1_apple_open.png` (11:32) shows the Apple menu fully dropped with every item
enabled, then it was cancelled and the button released explicitly. SEEN.

**Clock at idle -- PASS.** `P1_clock_t0.png` 11:33:14 and `P1_clock_t1.png`
11:34:43 (89 s apart): the menu-bar clock advanced 11:33 -> 11:34; MiSTer
`write_bytes` 753,664 -> 851,968 over the same window. SEEN.

**Shutdown -- PASS.** `mac_shutdown.sh` walked Special -> Shut Down and reported
`HALTED` at 11:35:45, exit 0. `P1_halt.png` shows the framed
"...is now safe to switch off your Macintosh." alert. SEEN.

### Phase 1 step 4 -- CD audio (UI half), its own boot

`.s4` was set by copying the existing `MacQuadra800.s4.bak_audiotest`, which
names `games/MacQuadra800/AudioTest.cue` -- the plan's escape clause ("copy that
file instead if it already names a Tone/AudioTest cue"). Core reloaded at
`40 00`; desktop at 11:37:47.

| check | result | source |
|---|---|---|
| disc mounts on the desktop | a new volume appeared at the right edge with a label ending in `1` (`P1cd_iconzoom.png`); the Quad Squad window covers the rest of the label, so the full string "Audio CD 1" was **not** readable. The player's own source popup reads `Audio CD`. | SEEN / partly INFERRED |
| AppleCD Audio Player opens | `P1cd_player2.png` 11:43:16 -- TOC read: 4 tracks (01:30, 01:30, 02:00, 02:02), total `07:02`, Track `01`, Elapsed `00:00` | SEEN |
| Play -- counter runs with the clock | `00:05` at 11:44:57 -> `00:48` at 11:45:41: 43 s of counter against 44 s of wall; menu clock 11:44 -> 11:45 | SEEN |
| track transitions | Track 03 `00:43` at 11:48:40, Track 04 `00:49` at 11:50:48 -- matches the TOC lengths | SEEN |
| Pause freezes it | Track 04 `00:49` at 11:50:48 **and still** Track 04 `00:49` at 11:51:27, while the menu clock went 11:50 -> 11:51 | SEEN |
| Resume picks up from the frozen value | `00:54` at 11:51:54 (i.e. from `00:49`, not from zero) -> `01:30` at 11:52:30, 36 s / 36 s | SEEN |
| Stop returns to Track 01 00:00 | the first click at ~11:53:00 landed where track 4 would also have ended naturally, so it was ambiguous. **Clean retest:** Play at 11:53:34 -> Track `01` `00:16` at 11:53:50; Stop at ~11:54:00 -> Track `01` `00:00` at 11:54:06, nowhere near a track end. PASS. | SEEN |
| "Apple CD-ROM drive is not responding" | never appeared in any frame of this boot | SEEN (absence) |

Quit with cmd-Q; `mac_shutdown.sh` reported `HALTED` at 11:55:24, exit 0. `.s4`
was then removed so A/UX would see no disc.

**Whether the disc actually made a SOUND is not something an operator on the
network can judge -- that half of the gate belongs to the user, at the display.**

Operator note for the next run: `scripts/guest/click.sh` cannot converge while
the player's counter is animating -- its cursor probe is a frame diff and it
locks onto the changing digits (it reported "last at (167,92)", inside the
counter). The working method was a measured manual walk: pin to the top-left
corner, step with `mouse:+/-1,0` / `mouse:0,+/-1` at `--delay 0.05` (~1.5 px per
event here), confirm the arrow's position in a screenshot, then
`mousebtn:left_down mousebtn:left_up` without moving again. The Play/Pause
button is at (399,119) and Stop at (351,119) in that window's position.

## Phase 2 -- A/UX 3.1, Ethernet ON (`40 00`), slot 4 empty

Menu core loaded first, then `unzip -o backup/HD60_512-AUX3.1-Installed.zip`
restored the pristine image (2,147,484,160 bytes, 6 m 50 s). `.s0` = `.s0.aux`,
no `.s1`, no `.s4`, CFG `40 00`. Loaded 12:02:51.

**Boot -- PASS.** `P2_boot2.png` at 12:05:57 (<=186 s) already shows the A/UX
multiuser Finder desktop: menu bar `Apple File Edit View Label Special`, the
volumes `/` and `MacPartition`, Trash; unchanged in `P2_boot3/4`. SEEN.
**This is the first A/UX boot with the SONIC present -- no hang, no panic, no
console spew, no video streaks.**

**CommandShell -- PASS.** `P2_cmdshell.png` 12:11:07: window "CommandShell 1",
the WELCOME TO A/UX banner, guest stamp `Sat Sep 19 05:04:10 PDT 2026` (an
RTC/zone offset, not a finding), prompt `localhost.root #`. SEEN.

| command | result | source |
|---|---|---|
| `uname -a` | `A/UX localhos 3.1 SVR2 mc68040` | SEEN (`P2_uname.png`) |
| `ls -l /etc` piped to `head -20` | `total 6410` + 19 rows, columns aligned, no garbling | SEEN (`P2_ls.png`, `P2_df.png`) |
| `df` | `/dev/dsk/c0d0s0   3695476 blocks   961639 i-nodes` | SEEN (`P2_df.png`) |

Every command returned promptly to the prompt.

`P2_stats.txt` taken while A/UX was up: `q8 fpga isr=0000 imr=0000 present=1`,
`q8 rpc 0 ops 0`, 88.4 % of sampled PCs in one idle loop -- **A/UX never touches
the SONIC** (it has no driver for it), which is why the chip being present is
harmless to it. SEEN, interpretation INFERRED.

**Shutdown -- PASS.** `sync; sync`, then `shutdown -h now` at 12:12:25. The
framed "You may now switch off your Macintosh safely." alert was SEEN in
`P2_shut2.png` at 12:14:31 -- **<=126 s**, the same figure the shipped core
posts. No port-mapper wedge (the box is at 32 MB, CFG RAM bits 0).

## Phase 3 -- Ethernet OFF (`00 00`)

**3.1 Mac OS 8.1 -- PASS.** CFG `00 00` (re-read as `00 00` after the launch),
loaded 12:15:59. `P3_8.1_desktop.png` 12:17:40: the ordinary Finder desktop,
clock `Sat 12:17`, **no TCP/IP or networking error dialog** of any kind. SEEN.
`ping 192.168.99.109` (`P3_ping_off.txt`): 2 timeouts then 3 x
"Destination host unreachable" from 192.168.99.82 (the router) -- **the guest
does not answer**, which is the wanted result with the chip absent. SEEN.
Apple menu opened fully at 12:18 (`P3_apple_open.png`), cancelled, released.
Clock 12:18 -> 12:20 across 89 s idle (`P3_clock_t0/t1.png`). SEEN.
`mac_shutdown.sh` `HALTED` at 12:21:23, exit 0.

**3.2 A/UX 3.1 -- PASS.** Same image (phase 2 shut down cleanly, so no second
unzip), CFG `00 00`, loaded 12:21:33. Multiuser Finder desktop SEEN in
`P3_aux_boot3.png` at 12:26:13, first seen 12:24:39 (<=186 s). CommandShell
opened; `uname -a` -> `A/UX localhos 3.1 SVR2 mc68040` (`P3_aux_uname.png`).
`sync; sync` then `shutdown -h now` at 12:27:49; the halt alert SEEN in
`P3_aux_shut2.png` at 12:29:55 -- **<=126 s**.

## Phase 4 -- box restored

Menu core loaded from the halted guest, then:

| item | value | source |
|---|---|---|
| core on screen | `MENU` (`/tmp/CORENAME`), process `/media/fat/MiSTer /media/fat/menu.rbf`, `P4_final_menu.png` = the menu noise field, no OSD open | SEEN |
| `.s0` | `games/MacQuadra800/QuadSquad8.hda`, md5 `c7496f5fb868b11f22890e45e2184c87` -- **byte-identical to phase 0** | SEEN |
| `.s1` | `games/MacLC/MacLC_7-1-MiSTer.hda`, md5 `f8ea7ed8bdb3a97451fe0c764bc038b4` -- **byte-identical to phase 0** | SEEN |
| `.s4` | `games/MacLC/CD3/TIM_3-mac.CUE`, md5 `b245602392ea422e5d3c3b53070a2891` -- **byte-identical to phase 0** | SEEN |
| CFG bytes 0..3 | `40 00 00 00` | SEEN |
| `/media/fat/MiSTer` | `fbb540c8a51134cfdc960a8b5115807b`, untouched | SEEN |
| `_Unstable` | `MacQuadra800.rbf` = the candidate (`933b421a...`), `MacQuadra800.rbf.build8_edf32a3b` = the previous one, `MacQuadra800_20260918.rbf` unchanged | SEEN |

No `*.parked_user` and no `.s0.orig_20260919` left behind. The A/UX image on
the box is the freshly unzipped pristine copy, cleanly halted.

---

## Summary table

| phase | check | verdict | evidence |
|---|---|---|---|
| 0 | box at MENU, state recorded, slots parked | PASS | `P0_menu.png` |
| 0c | Main md5 = `fbb540c8...` | PASS | ssh output |
| 0d | candidate pushed, md5 `933b421a...` on the box | PASS | ssh output |
| 1.1 | 8.1 boots to the desktop at `40 00` | PASS | `P1_desktop.png` |
| 1.2 | guest answers ping, 2 x 250-packet soak | PASS | `P1_ping.txt`, `P1_soak_1.txt`, `P1_soak_2.txt` |
| 1.2 | Ethernet counters, no DMA timeout | PASS | `P1_stats.txt` |
| 1.3 | pointer + Apple menu, clock advances | PASS | `P1_apple_open.png`, `P1_clock_t0/t1.png` |
| 1.4 | disc mounts (label partly occluded) | PASS | `P1cd_iconzoom.png`, `P1cd_player2.png` |
| 1.4 | AppleCD Audio Player: TOC, Play, Pause, Resume, Stop | PASS | `P1cd_play_t0/t1`, `P1cd_paused_t0/t1`, `P1cd_resume_t0/t1`, `P1cd_play3`, `P1cd_stopped2` (+`_zoom`) |
| 1.4 | no "CD-ROM not responding" dialog | PASS | all phase-1 CD frames |
| 1.4 | **CD makes an audible sound** | **NOT REACHED -- user's ears only** | -- |
| 1.5 | 8.1 Special -> Shut Down, halt screen | PASS | `P1_halt.png`, exit 0 |
| 2.1 | pristine A/UX image restored | PASS | ssh output |
| 2.2 | A/UX boots to the multiuser desktop with the SONIC present | PASS | `P2_boot2/3/4.png` |
| 2.3 | CommandShell: `uname -a`, `ls -l /etc`, `df` sane | PASS | `P2_cmdshell/uname/ls/df.png` |
| 2.4 | `shutdown -h now` reaches the halt screen (<=126 s) | PASS | `P2_shut2.png` |
| 3.1 | 8.1 at `00 00`: desktop, menu, clock | PASS | `P3_8.1_desktop.png`, `P3_apple_open.png`, `P3_clock_t0/t1.png` |
| 3.1 | guest does NOT answer ping, no error dialog | PASS | `P3_ping_off.txt`, `P3_8.1_desktop.png` |
| 3.1 | 8.1 shutdown | PASS | exit 0 |
| 3.2 | A/UX at `00 00`: boot, `uname -a`, shutdown | PASS | `P3_aux_boot3.png`, `P3_aux_uname.png`, `P3_aux_shut2.png` |
| 4 | box restored to the user's state | PASS | `P4_final_menu.png`, ssh output |

**md5s actually used:** rbf `933b421a0880177be1b5fb2861dcea15`;
Main `fbb540c8a51134cfdc960a8b5115807b`.

**Ping totals:** at `40 00`, 506 sent / 506 received / **0 lost** (6 + 250 +
250). At `00 00`, 5 sent / 0 answered by the guest (3 host-unreachable from the
router) -- the wanted result.

## Deviations from the plan

1. **Slot 4 disc** was `games/MacQuadra800/AudioTest.cue`, installed by copying
   the existing `MacQuadra800.s4.bak_audiotest`, not `ToneTest.cue`. This is
   the plan's own escape clause (step 1.4), and it keeps the slot file's byte
   format intact. `ToneTest.cue` does exist on the box if the user prefers it.
2. **The CD volume's full label was never readable**: the Quad Squad Finder
   window covers it and I chose not to move or close the user's window. Only
   the trailing `1` of the label is visible. The disc demonstrably mounted --
   the player read its 4-track TOC and played it.
3. **The first Stop click was time-ambiguous** (track 4 was about to end on its
   own), so Stop was re-tested from a fresh Play. Only the retest is counted.
4. **`.s0` was restored from a byte copy of the user's own original file**
   (`.s0.orig_20260919`), not from `.s0.quadsquad`, so it is byte-identical to
   what was found rather than merely equivalent.
5. **CFG is left at `40 00`** as the plan directs. The user's value when the box
   was handed over (11:06) was `40 04` -- byte 1's bring-up switch `04` is now
   cleared, which is the point of this candidate.
6. At 12:31, after the restore was finished, a second read-only ssh command
   (not mine: it read `CORENAME`, the CFG, `.s0`, the slot listing and a 10 s
   `write_bytes` delta) was running on the box. Read-only, nothing was changed
   by it and nothing was changed by me after that point. Noted for the record.

## Left for the user

- **CD audio by ear.** Everything an operator on the network can check passed --
  TOC, transport, counter, no error dialog -- but whether the tone is actually
  heard at the display is the user's half of the gate, and it is not done.
- **The HDMI picture with the installed Main** (`fbb540c8...`): screenshots
  cannot see HDMI output. The user confirmed it at the display before this run
  and nothing about Main was touched here.
