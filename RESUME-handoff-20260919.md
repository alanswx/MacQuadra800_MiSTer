# HAND-OFF — Quadra 800: Ethernet speed, CPU bugs, CPU performance (2026-09-19)

Read this first. It is the index for three lines of work and says, for each,
what is known, what is only suspected, and the next experiment. Details live
in the files it points at:

| topic | file |
|---|---|
| the two Ethernet bugs, every hardware number, this Linux box | `RESUME-ethernet-20260919.md` |
| Ethernet design, instruments | `docs/ethernet.md` |
| Dani's Ethernet bring-up day, the experiment recipe, operating knowledge | `RESUME-ethernet-20260918c.md` |
| the CPU pipeline work this branch carries (increments 1-15, builds 6-13) | `RESUME-cpu-pipeline-20260919.md`, `docs/cpu-pipeline-increments-20260917.md`, `docs/PERFORMANCE_MEASUREMENTS.md` |
| binding hardware rules | `CLAUDE.md` (written for Dani's Windows PC: section 3 of the Ethernet resume says what differs here) |

## 0. State

- Branch `add-ethernet`, pushed to `alanswx/MacQuadra800_MiSTer`. Two pull
  requests are open to Dani: **core**
  `danifunker/MacQuadra800_MiSTer#3` (the two RTL fixes, the bench, docs,
  `vmouse.py`) and **Main** `danifunker/Main_MiSTer#1` (the DMA client's
  guard; the branch is `alanswx/Main_MiSTer:mac-q800-eth-dma-guard`, local
  clone `../Mac_Main_MiSTer`). If Dani pushes to his branch first, rebase ours;
  do not merge his into ours.
- **Ethernet works with every fast path on** (CFG `40 00`): DHCP, 1000/1000
  large pings, FTP 10 MB both ways with matching md5s, clean shutdowns, no
  DMA timeout in 35,920 round trips, Speedometer unchanged (On-idle
  0.923-0.926, Off 0.922-0.925).
- On the MiSTer (`10.3.89.233`, shared with other cores' sessions — look at
  `ps w | grep MiSTer` first): core = build 10 (`cedd0221...`,
  `_Unstable/MacQuadra800.rbf`), Main = `1d512b7a` (fallbacks
  `MiSTer.prev_b6b5cc17`, `MiSTer.prev_dfb5937b`), slot 0 =
  `QuadSquad8.hda` with TCP/IP on built-in Ethernet, DHCP, load at startup.
  Parked 2026-09-19 13:35 at the **menu core** after a clean guest shutdown,
  CFG `40 00` (Ethernet on, every fast path on).
  Tools that survive a reboot: `/media/fat/Scripts/q800tools/` (`vmouse.py`,
  `mac_hfs.py`, `aux_ufs.py`). **Read the CFG before assuming Ethernet is on**
  (`xxd -l 4 /media/fat/config/MacQuadra800.CFG`: byte 0 `40` = On, byte 1
  bits `02/04/08` = the bring-up switches; it is only read at core load).
- FTP peer for the guest: this box, `10.3.141.107` port **2121**, user unit
  `ftp-pub`, `guest`/`guest`, read-only except `dropbox/`; payloads and
  `MD5SUMS` in `/home/alans/ftp_pub`. In Fetch: host `10.3.141.107 2121`
  (a space), **Binary**, Put format **Raw Data**. The MiSTer cannot be the
  guest's peer (Main injects the guest's frames on `eth0`; the box's own
  stack never sees them). `ftp.funet.fi` `/pub/mac/` is a live public site.
- Still in the tree on purpose: the `Dbg ...` OSD lines and `dbg_sw`
  (`5a271f0`) and the SAMPLE/DEBUG words. They earned their keep twice; take
  them out only when sections 1 and 2 are closed, in one commit, followed by
  the release regression gate (8.1 and A/UX, Ethernet Off and On).

## 1. Ethernet speed

### What was measured (build 10, `hw12/`, `hw13/`)

| transfer | rate | notes |
|---|---|---|
| FTP download 1 MB, build 9 | 36 KB/s | six 250 ms DMA timeouts in it |
| FTP download 10 MB, build 10, under 5 pings/s of 1400 bytes | **62.6 KB/s** | 0 timeouts; ping RTT rose from 4 ms to **10.7 ms avg, 187 ms max** |
| FTP **upload** 10 MB, build 10 + Main `1d512b7a` | **227 KB/s** | 0 timeouts |
| DMA round trip | 62-81 us avg, 456 us max | 35,920 of them in the download = **2.7 s of 167 s** |

So the DMA engine is not the bottleneck: it accounts for under 2 % of the
download. 10 MB is ~7,200 full segments in 167 s = **one segment per 23 ms**,
against a 3.5 ms round trip. The guest sent ~4,100 ACKs for them (one per
1.75 segments), so the sender is ACK-clocked and something delays each
exchange by ~20 ms. Download and upload differ by 3.6x, and the difference
between them is which side of the guest's disk is busy: a download **writes**
the disk image through Main, an upload **reads** it.

### Hypotheses, most likely first

1. **Main is single-threaded and blocks in the SD write.** Every sector the
   guest writes is a synchronous `write()` to an exFAT file on the SD card
   from Main's one loop; while it blocks, `mac_eth_poll()` does not run, so
   received frames wait in the socket and the guest's ACKs wait in the
   doorbell ring. The ping RTT tripling during the download is this.
   (`../Mac_Main_MiSTer/support/mac/mac.cpp` `mac_poll` -> `mac_eth_poll`;
   the SCSI side is `user_io.cpp`'s sd handling plus `support/mac/`.)
2. One ISR post in flight at a time + the receive delivery being two DMA round
   trips per frame (`docs/ethernet.md`, "DMA"): each is cheap, but they are
   serialized with the guest's ISR acknowledging through the doorbell.
3. The driver's single 25 KB receive buffer and eight RDAs, and Open
   Transport's receive window / delayed ACK. Probably real but second-order:
   the upload runs through the same stack at 227 KB/s.

### Experiments, cheapest first (no FPGA build needed for 1-3)

1. **Separate disk from network.** In Fetch, download to a RAM disk (Memory
   control panel) or view a large text file instead of saving it. If the rate
   jumps to the upload's, hypothesis 1 is proven. Record `/tmp/mac_eth_stats`
   (`q8 passes` per second is Main's loop rate; watch it collapse) and the
   pcap's inter-frame gaps (`scratch/ethernet-handover/pcapsum.py`).
2. If it is the SD write: in Main, either service the Ethernet from its own
   thread (the mailbox is memory-mapped, the model is self-contained; the one
   shared thing is the DDR3 window, which the disk path does not touch), or
   make the disk write asynchronous / write-behind for the Mac cores. The
   a2065 code in `support/minimig/` is the precedent to read first. Keep the
   guard of `0cb45be`.
3. Measure with `ttcp`-style traffic that touches no disk (a discard/chargen
   pair, or Fetch "View File") both ways to get the stack's own ceiling (10BASE-T
   itself tops out near 1.1 MB/s).
4. FPGA side, only if the stack's ceiling is low: let the engine take
   back-to-back beats instead of one per FSM visit while the CPU is idle, and
   raise `SPIN_US`-style polling only after measuring.
5. Dani's 44 KB/s of 2026-09-18 and "direction not recorded" are superseded
   by the table above.

## 2. CPU bugs and oddities (none blocks Ethernet; all are in the shared CPU/memory path)

### 2a. Invalid Speedometer timings — open, now with a new data point

One of five Mix runs on build 10 (Ethernet On) reported **KWhetstones 0.232**
(rating 0.000) with every other line normal; four Off runs were clean
(`hw13/S07_mix_on2.png`). What is known:

- This CPU is the core of builds 12/13: increments 11 and 12 (the loop-top
  record cache, Dani's suspect (a)) are **already out** (`4abb118`), and that
  tree ran eight clean Mix runs on Dani's box. So the record cache is not
  required for an invalid timing.
- The earlier invalid values were impossibly **fast** (Bubble Sort 0.022 s);
  this one is impossibly **slow** (x2900) while the run took the usual wall
  time. A loop that "did not run" cannot produce that; a **bad elapsed-time
  reading** produces both signs.
- `docs/SPEEDOMETER_TIMING_DIAGNOSTIC.md` on branch
  `profile-speedometer402-20260909` (2026-09-12) already says invalid times
  "recur ... earlier releases also exhibited them", and that Speedometer
  times each test with the `Microseconds` trap (A193), falling back to
  InsTime/PrimeTime/RmvTime; it lists the code offsets for observation points.
- `Microseconds` is the Time Manager reading the VIA1 timer and combining it
  with a software count. So the suspects are, in order: (i) a **VIA timer
  read** that is not atomic across the counter's byte carry or lands on the
  reload (`rtl/via6522.sv`, the 783 kHz E clock derived as `E_HALF=21`
  clocks), (ii) the Time Manager's interrupt arriving between its two reads,
  i.e. an interrupt-timing issue in the CPU (RTE/IPL sampling), (iii) the
  33/99 MHz request handoff in `rtl/sdram_beat32.sv` (Dani's suspect (b), the
  2026-09-02 negative-time family).
- Next: a bare-metal or in-guest loop that calls `Microseconds` twice a few
  thousand times a second and logs any pair that goes backwards or jumps by
  more than a tick — it turns a once-in-five-runs event into one that shows in
  seconds, under QEMU (must never fire) and on hardware. Then the same loop
  reading the VIA T1/T2 counter bytes directly separates (i) from (ii). Do not
  average invalid runs into performance numbers.

### 2b. Finder hung inside Special > Shut Down, once

CFG `40 04` (retained line off), build 9, after a Fetch session that was
opened and quit without connecting: the menu title stayed lit, the clock
froze, the pointer still moved, the SONIC driver kept servicing receives
(`hw11/G05..G07`, `stats_shutdown_hang_4004.txt`). The same sequence at
`40 00` shut down cleanly three times, including after 10 MB transfers. Not
reproduced, not explained. It was on build 9, before the DMA fix, and during
a session that had just recovered from an improper shutdown; if it shows again
on build 10, dump low memory and the PC histogram (`q8 pc`) before loading
over it.

### 2c. Things noticed while reading the memory path (no failure observed)

- `TAS`/`CAS`/`CAS2` are not bus-locked (the AP68040 header says so). With a
  second master on the bus that is now a real, if narrow, exposure: a DMA
  write between a CAS's read and its write. OT's lists are CPU-only so it does
  not bite there; the driver's descriptor handshake is the place it could.
- `walker_pend` rising in a line-ack clock would have opened the same hole as
  bug 1; `walker_req` is held off while the cache is busy, and the new guard
  covers it, but it was luck rather than design before.
- The general rule the first bug teaches: **every shortcut that acknowledges
  outside the service FSM must itself hold off every other launch path in its
  ack clock.** `bus_miss_ack` had its term; `bus_line_ack` did not. Audit any
  new shortcut against a second master, with `tb_line_dma` as the harness
  (it has the DMA arm and the parked-device arm; add the shortcut to its FSM
  copy).
- Fetch 3.0.3 bombed with error 10 once, launched under ping load on build 9.
  Attributed to the DMA list being overwritten after a timeout (fixed twice
  over: build 10 removes the timeout, Main `0cb45be` guards the list); it did
  not recur on build 10 under the same load.

## 3. CPU performance

### Where the two CPU lines stand

- **This branch carries Dani's vendored CPU** (`rtl/ap68040/`, not a
  submodule since 2026-09-17; `rtl/ap68040/UPSTREAM.md`): Alan's checkpoint 15
  + the one-clock data hit (Alan's `6e65192`) + pipeline increments 1-10,
  13-15. **Speedometer Mix 0.925 here** (0.9285 on Dani's box for the same
  core), Dhrystones 11,870/s, against 0.855 for checkpoint 15. The scale's 1.0 is a
  real Quadra 605 (25 MHz); a real Quadra 800 rates well above it, so the
  machine is still slower than the one it models.
- **Alan's own line** is the submodule history in `alanswx/AP68040`
  (`cpu-fastread-20260915` = the "dovr" one-clock hit, never fitted there) and
  this repo's `profile-speedometer402-20260909`. Everything of value in it
  that was ready has been taken into the vendored tree; what has not is the
  Speedometer timing observer fixtures and the development build recipe
  (`configs/`, `scripts/fixtures/` on that branch, plus
  `~/mister/MacQuadra800_fixtures/`). New CPU work should go on the vendored
  tree; port to `alanswx/AP68040` only if that repo is to stay alive.
  Switching this checkout back to a submodule branch needs
  `git submodule update --init rtl/ap68040`.

### Levers, from the pipeline notes, in the order they were ranked there

1. 13 + 14 + 15 measured together against build 8 (stores are 12 % of the
   Speedometer bracket, reads behind stores 5 %) — done on Dani's box
   (0.9285); not yet written into `PERFORMANCE_MEASUREMENTS.md` from here.
2. A Bcc.W / JSR (An) target table (small).
3. Alan's two-sector refill buffer (+2,300 ALMs).
4. A one-clock instruction fetch (the fetch queue's ring write missed by 7 ns
   once).
5. The six-stage engine (months).

Area is the constraint on all of them: build 10 is 36,818 ALMs (88 %) with the
Ethernet in (`ETHERNET_OFF=1` in the `.qsf` builds without it, for a CPU
experiment that needs the room).

### Rules for CPU work that cost a build or a run each

- One Quartus flow at a time on this box; launch with
  `systemd-run --user --unit=<name> bash -lc 'bash scripts/build_only.sh > log 2>&1'`
  and watch the unit, not the terminal. ~15 min a build, seed 21 has met
  timing for builds 9 and 10.
- CPU gates before any build: `sh rtl/ap68040/tb/run_tests.sh` and the corpus
  (`scripts/cpu_gates_wsl.sh` is WSL-shaped; here run its steps natively with
  `/home/alans/verilator5/bin/verilator` and vasm from
  `~/mister/MacQuadra800_fixtures/wombat-vasm/`).
- The CPU-only bench cannot see store-path or memory-path gains; hardware
  decides, with **at least five Mix runs**, invalid ones reported and replaced,
  same boot disk, 32 MB, Ethernet **Off** (or note it: On costs 0.5 % of
  Dhrystones on a busy LAN).
- Run the cross-domain STA on every fitted tree before its db is overwritten
  (`scripts/cpu/timequest_cross_domain.tcl`); the `sdram_beat32`
  `req_tgl -> req_handoff` margin is the number to record — doubly so while
  2a is open.
- With Ethernet in the machine there is a second bus master: a memory-path
  change is not verified until `make tb_line_dma` passes and a ping soak plus
  an FTP transfer with an md5 has run on hardware at CFG `40 00`.

## 4. Driving the guest on this box

The MiSTer's mrext remote has no mouse commands, so `menu.sh`, `click.sh` and
`mac_shutdown.sh` do not work here. What does:

- keys: `python scripts/mister_ws.py --host $MISTER_HOST ...`
  (`down:56 raw:24 up:56` = cmd-O, `raw:48` = B, `raw:17` = W, `raw:16` = Q,
  `down:56 down:125 raw:17 ...` = cmd-opt-W closes every Finder window) and
  `bash scripts/guest/type.sh 'text'` for type-select and dialogs;
- mouse: `ssh root@$MISTER_HOST 'python3 /media/fat/Scripts/q800tools/vmouse.py home m:DX,DY click'`
  — 1.45 to 1.65 px per count, so move, `grab.sh`, correct, then click. From
  `home`: Special > Shut Down is `home m:111,-10 0.5 down 0.8 m:13,66 6 up`
  (Restart is `m:13,55`); hold a menu for a screenshot by running that in the
  background and grabbing 9-12 s later. The script always releases the button
  before its device goes away.
- If keys stop working, a modifier is held (a `mister_ws.py` call killed
  between `down:56` and `up:56` — keep every tool call under its time limit):
  send `up:56 up:125 up:42` first.
- A Fetch/Speedometer session end to end is in the `hw11`-`hw13` screenshots,
  in order. Updating mrext on the box would make Dani's scripts work again and
  is worth doing before any long operator session.
- To read a file out of the guest: shut it down to the halt screen, load
  `menu.rbf`, then on the MiSTer
  `python3 /media/fat/Scripts/q800tools/mac_hfs.py <image> cat ':path:to:file' out`.
