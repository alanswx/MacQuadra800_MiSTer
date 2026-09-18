# RESUME PROMPT — Quadra 800 built-in Ethernet, hand-over (2026-09-18, late)

Written for someone picking this up cold, possibly without the previous
sessions' private notes. It supersedes `RESUME-ethernet-20260918b.md` (kept for
history) and is self-contained; the section "Operating knowledge" at the end
carries what used to live only in the assistant's memory files for this repo
and for `../Main_MiSTer`.

Working directory `C:\Temp\mistercore\MacQuadra800_MiSTer`, branch
`add-ethernet`. Read in this order: `CLAUDE.md` (binding hardware rules),
this file, `docs/ethernet.md` (design + instruments), then the day log
`RESUME-ethernet-20260918.md` (what each of builds 1-8 did). The planning
analysis `docs/sonic-ethernet-plan.md` is **untracked on purpose** (user: never
commit the plan; it is in `.git/info/exclude`).

## 1. Where things stand

**The Ethernet works on hardware, with two of the machine's CPU memory fast
paths switched off.** DHCP in 6 ms, gratuitous ARP, ARP replies, **1000/1000
pings of 1400 bytes, 0 lost, 3-10 ms** (`scratch/eth/hw9/A2_soak_1..4.txt`),
live desktop, clean shutdown. The user has since **transferred files over FTP**
(server `192.168.99.5`) — it works but is slow, **about 44 KB/s** (section 4).
Guest MAC `08:00:07:2d:d0:a3` (Apple OUI + the MiSTer's last three octets),
guest IP `192.168.99.109` from the LAN's DHCP server.

**The open bug is in the CPU memory path, not in the Ethernet.** With the fast
paths on, Open Transport's atomic list code goes wrong seconds after receive
traffic starts: OTLIFOEnqueue (`cas.l d0,d1,(a0)`) and OTLIFODequeue
(`cas2.l d0:d1,d1:d1,(a0):(a1)`, encoding `0EFC 8040 9041`) at guest
`$158188` / `$15819E`; the deferred-work list becomes circular (a pop hands out
one element twice), then the Finder livelocks, or the guest bombs, or it runs
away into an exception-frame storm (PC parked at `$517CAC`, the exception
dispatcher).

Proven NOT to be the cause:

- the frames — QEMU survives the identical capture replayed against a copy of
  the same disk image (`~/qemu-work/qemu_replay.py`);
- the DMA data — every frame and descriptor in guest RAM is byte-exact against
  the pcap (guest RAM dumped through the DMA engine on the hung guest);
- the interrupt path, transmit, the mailbox, the CR overlay;
- the D-cache snoop being on or off (both fail with the fast paths on; with the
  snoop OFF the guest dies even sooner, within ten frames, so the snoop is
  needed and is on by default).

### The bring-up switches (build 8, commit `5a271f0`)

OSD status bits, latched under reset (`MacQuadra800.sv:100-102, 508-511`),
passed to `quadra800` as `dbg_sw[2:0]`. Set them by patching
`/media/fat/config/MacQuadra800.CFG` **before** a `load_core` (check with
`xxd -l 8`; Main may rewrite the CFG when a core unloads, so patch with the
core halted and re-check after launch):

| CFG byte | bit | status | effect in RTL |
|---|---|---|---|
| 0 | `0x40` | — | Ethernet On |
| 1 | `0x02` | `[9]` = `dbg_sw[0]` | **store buffer + the cache's posted stores OFF** (`quadra800.sv:266` `.store_buffer_ok(!overlay && !dbg_sw[0])`, which also gates `c_post_ok*` in `wombat_cpu.sv:365-368`) |
| 1 | `0x04` | `[10]` = `dbg_sw[1]` | **retained-SDRAM-line fast paths OFF** (`quadra800.sv:147-148`: `mem_line_valid/pending` forced 0, so `line_cpu_match`, `bus_line_match` and the cache's `m_line_*` fill shortcut never fire) |
| 1 | `0x08` | `[11]` = `dbg_sw[2]` | DMA D-cache snoop OFF (`quadra800.sv:737`) |

| experiment | CFG bytes 0,1 | result |
|---|---|---|
| all fast paths on (builds 2-7) | `40 00` | hang/bomb within seconds of RX |
| A: store buffer off + line off | `40 06` | **works**: 108/108, then 1000/1000 1400-byte pings, clean shutdown, FTP works |
| B: store buffer off only | `40 02` | DHCP/ARP/6 pings fine, then **crashed** ~31 pings into a 1400-byte soak (PC wedged at `$517CAC`); run once |
| C: line off only | `40 04` | **NOT RUN** — it was queued at the end of this session and cancelled for lack of budget |

Reading of the table: B fails later than all-on, so the two paths contribute
separately — either two bugs, or one multi-master race whose odds both change.
The D-cache itself (still on in A, with the snoop) is sound.

### How the pieces fit (for whoever reads the RTL next)

- The SONIC's DMA engine (`rtl/sonic_mbx.sv`) is a third master in
  `quadra800.sv`'s service FSM (`svc_dma`; the others are the CPU bus and the
  MMU table walker). Its beats are ordinary longword RAM accesses through
  `sdram_beat32`, serialized with CPU beats by the FSM, one beat per `S_MEM`
  visit. On the `mem_ack` of a DMA **write** the FSM pulses `snoop_stb` for one
  clock with `{svc_addr,2'b00}` (`quadra800.sv:730-739`).
- `wombat_cpu.sv:300-327` merges that with the table walker's own
  write-snoop (`wsnp_pend`, held while `snoop_stb` is high) into the cache's
  `s_stb/s_addr` port (`rtl/ap68040/rtl/ap040_cache.v:108-114`). The cache
  handles snoop-vs-fill and snoop-vs-lookup collisions explicitly
  (`fill_snooped`, `look_snooped`, `xsnooped`, lines 433-458): a fill whose row
  is snooped still completes but is not validated.
- Fast path 1, the **store buffer** (`rtl/wombat_store_buffer.sv`, two ordered
  entries) plus the cache's one-clock **posted store**: the CPU is acked before
  the store reaches SDRAM. `pass_ok` lets a read overtake one queued store only
  if it is to another line.
- Fast path 2, the **retained line**: `sdram_beat32` keeps the last 16-byte
  SDRAM burst; `quadra800.sv` serves CPU reads that match it without a trip
  through the FSM (`line_cpu_match`, `bus_line_match`), and the cache's fill
  takes whole beats from it (`ap040_cache.v:515-523` `fill_line_match`).
  `sdram_beat32` drops the line on every accepted write, DMA writes included.
- The AP68040 header says "TAS/CAS/CAS2 are not bus-locked (single-master
  fabric here)". A real 68040 locks the read-modify-write; here a DMA beat, a
  queued store drain or a walker access can land between the CAS read and its
  write. OT's list heads are written only by the CPU, so an interleaved DMA
  write cannot by itself break CAS semantics — the failure has to be the CPU
  **reading a stale copy** (a read served from the retained line or overtaking
  a queued store while the newer value is still in flight), with DMA traffic
  only shifting the timing so that it happens.

Checked on paper and found sound (so look harder, or elsewhere): the store
buffer's `pass_ok`; `sdram_beat32` line invalidation on every accepted write;
the cache's per-word sideband tag check on `m_line_*`; the service FSM's DMA
arm; the snoop-vs-fill handling above. `rtl/ap68040/tb/asm/t_cas_lifo.s`
(commit `4055c23`) runs the exact OT enqueue/dequeue sequences with caches on
and **passes** — but that harness has no store buffer, no retained line and no
second bus master, which is exactly what is implicated.

## 2. Next steps, in order

1. **Run experiment C** (`40 04`), and B once more for statistics. ~15 min
   each, no build needed (recipe in section 3). If C fails too, the common
   factor is DMA beats interleaving with CPU traffic; if C survives, the bug is
   confined to the retained-line paths and B's crash is that alone.
2. **Reproduce in simulation** with the REAL wrapper: a directed bench of
   `wombat_cpu` + `wombat_store_buffer` + `sdram_beat32` + the service FSM
   (a cut-down `quadra800`, or `quadra800` itself with a stub I/O side) running
   `t_cas_lifo`-style code while a second master issues random read/write beats
   through the DMA arm, with a checker on list integrity. Nothing today
   instantiates `wombat_cpu` outside the full-machine sim (the
   `SingleStepTests/preboot` benches boot it through the ROM). The full-machine
   sim builds with `SONIC=0`; the user prefers hardware over that sim because
   it is slow — keep sim runs short and directed.
3. **A cheap hardware discriminator before that** (one ~20 min build): let DMA
   beats take the bus only when the CPU side has been completely idle for N
   clocks and the store buffer is empty, or hold the CPU off for a whole op
   list. If `40 00` then survives, it is an interleaving race, and the list of
   suspects shrinks to the hand-over points between masters.
4. Another cheap one: split `dbg_sw[0]` into "store buffer off" and "posted
   store off", and `dbg_sw[1]` into `line_cpu_match` / `bus_line_match` / the
   cache's `fill_line_match`, to find which single shortcut is enough to break
   it. Spare status bits exist above `[11]`.
5. When fixed: remove the `Dbg ...` OSD lines and `dbg_sw` (commit `5a271f0`),
   decide whether the SAMPLE/DEBUG words stay (~100 ALMs), set the CFG back to
   `40 00`, restore the clean disk image (section 3), run the full regression
   gate from `CLAUDE.md` (8.1, A/UX at 32 MB, CD audio by ear) with Ethernet
   Off and On, Speedometer On-idle vs Off, FTP both ways with an md5, then the
   speed pass (section 4) and A/UX networking (QEMU routes the SONIC to IPL 3
   in A/UX mode; this core has only the classic 4/2/1 scheme — trace QEMU
   first). Then fix the stale parts of `docs/ethernet.md` ("Open").

## 3. Recipe: one hardware experiment

All from Git bash in the repo, `export MSYS_NO_PATHCONV=1; . scripts/local.env`
first; ssh is `ssh -n -i "$MISTER_SSH_KEY" root@$MISTER_HOST '...'`.

1. `bash scripts/grab.sh scratch/eth/hwNN/00.png` and **read the picture**. A
   live desktop: `bash scripts/mac_shutdown.sh` (exit 0 = "safe to switch off"
   seen; give the tool call 5 minutes, never let it be killed with the button
   down; `--release` frees a held button). A provably hung guest (bomb, frozen
   clock over two grabs 70 s apart, no ping) may be loaded over.
2. Patch the CFG, e.g. C: `printf '\x04' | dd of=/media/fat/config/MacQuadra800.CFG bs=1 seek=1 conv=notrunc; sync; xxd -l 8 ...`.
3. `echo "load_core /media/fat/_Unstable/MacQuadra800.rbf" > /dev/MiSTer_cmd`
   (the rbf there must be md5 `edf32a3bd2ce6c71b39270d5c3f72f46` = build 8 =
   `output_files/MacQuadra800.rbf` = `scratch/eth/build8/`). Re-check the CFG.
4. The guest answers ping 60-100 s later. Soak from Windows:
   `ping -n 250 -l 1400 192.168.99.109 > scratch/eth/hwNN/C_soak_1.txt`, four
   rounds. B died ~31 pings in; all-on dies within seconds.
5. On a death: grab; `for i in 1 2 3 4 5; do devmem 0x1FF040D0 32; sleep 0.2; done`
   (the CPU's PC); `cat /tmp/mac_eth_stats`; optionally dump guest RAM
   (`echo "hexaddr hexlen" > /tmp/mac_eth_dumpreq` -> `/tmp/mac_eth_dump.bin`,
   works on a hung guest).
6. Leave the box safe: CFG back to `40 06`, guest shut down or menu core
   loaded.

Instruments (all in build 8 + Main `b6b5cc17`): `/tmp/mac_eth_stats`
(`q8 fpga` live ISR/IMR/irq, `q8 reads`, `q8 pc` PC histogram, `q8 regs`),
`/tmp/mac_eth_regtrace` (last 512 register writes), `/tmp/mac_eth.pcap`
(`python3 scratch/eth/pcapsum.py`), the dump request above, and
`/tmp/mac_eth_dbg` (1 = drop DMA writes, 2 = refuse all RX; re-read every
second). Note `scratch/` is gitignored: builds `scratch/eth/build1..8/`,
hardware evidence `scratch/eth/hw1..hw9/`, and copies of the QEMU scripts live
only on this PC.

## 4. The 44 KB/s FTP observation (user, 2026-09-18 late; not investigated)

Direction and CFG at the time were not recorded; the box had been left at
`40 06`, i.e. with both fast paths off, which makes every store and many reads
slow — but the number itself is suspicious: 44 KB/s is ~30 full-size segments
per second, **one per ~33 ms, while a ping round trip is 3-4 ms**. That smells
of a once-per-tick pacing rather than raw CPU speed. Places to look: how often
`mac_eth_poll()` (`../Main_MiSTer/support/mac/mac.cpp:111`) actually runs when
the core is busy with disk I/O for the same transfer; the DMA round trip
(`mac_eth_q8.cpp`, `SPIN_US 1500` then `usleep(50)`); one ISR post in flight at
a time; the driver's single receive buffer and 8 RDAs; delayed ACKs with a
small OT window. `/tmp/mac_eth_stats` (`q8` lines: DMA round trips and their
latency, ISR posts, Main's pass rate) during a transfer, plus the pcap's
inter-frame gaps, will tell which. Get direction (get/put) and both numbers.
This belongs to the speed pass, after the CAS bug — unless it turns out to be
the same stall.

## 5. What is installed / where

- MiSTer `192.168.99.143` (the ONLY box to touch; `.92` is off limits): Main
  `b6b5cc17`, built from the fork branch
  `mac-ethernet-pr-with-SCSI-Optimizations-with-q800-eth`, head `68637c9`
  (`../Main_MiSTer`, clean tree). Previous binaries on the box:
  `MiSTer.prev_e2255642`, `MiSTer.prev_bb1a08d3` (the pre-Ethernet one). Core =
  Ethernet build 8 in `_Unstable/`. CFG `40 06` when last touched by me; the
  Ethernet-Off copy is `MacQuadra800.CFG.bak_ethoff`. Guest TCP/IP: built-in
  Ethernet, DHCP, load at startup. **The user has been using the guest since
  (FTP): its state is unknown — look before touching.**
- The Quad Squad image was yanked several times on 2026-09-18 while hung; it
  boots and works, but restore
  `games/MacQuadra800/backup/QuadSquad8_20260918_clean_after_b9.hda` before any
  release gate (then redo the TCP/IP setting).
- Second Quartus host `dani@192.168.99.153` (key `~/.ssh/mister_only`, Ubuntu,
  Quartus 17.0.2 Lite in `~/intelFPGA_lite/17.0`, tree `~/MacQuadra800_eth`,
  recipe in `RESUME-ethernet-20260918.md`). This PC's Quartus builds in
  ~20 min when free.
- QEMU reference in WSL `~/qemu-work`: `qs8_eth.hda` (the box's image),
  `qemu_net.py` (scripted DHCP/ARP/ping LAN on the UDP-socket NIC),
  `qemu_replay.py` (replays a hardware capture), trace `sonic_eth.log`.
- **Nothing is pushed in either repo; the user pushes** (their ssh key is not
  in the tool shells). `origin/CPU-pipeline` still carries the plan commit
  `45e81a3`; removing it is the user's
  `git push --force-with-lease origin CPU-pipeline`.

## 6. Fixes that landed on 2026-09-18 (all committed)

Core: `1be2218` the front-end; `665a450` VIA2 any-slot flag as a level (build 1
froze on a lost slot interrupt) + DEBUG word; `c49fcf3` read counter; `b20e833`
PC sampler; `6341570` applied index inside the ISR post (the CR overlay drops
in the clock TXDN rises); `54ae465` snoop on; `5a271f0` the bring-up switches;
`4055c23` `t_cas_lifo`. Main: `d277747` Q8 personality (NuBus/IIvi/LBMacTwo
removed), `3ad68f5` **32-bit mode keeps the receive buffer pointer
longword-aligned** (DHCP failed without it), `b527eb9` instruments + the
applied index only after the apply, `3bd7510`, `68637c9` debug switches.

## 7. Operating knowledge (from the assistant's memory files, both repos)

User rulings for this feature: slim design; MAC = `08:00:07` + the MiSTer's
last three octets, no override anywhere; OSD default Off + interface choice;
A/UX networking is a later stretch goal; the plan doc is never committed; the
user logs in to the FTP server themselves — **never type passwords**.

How the user wants the work done:
- Commit after each landed step, linear history, plain-prose messages
  (`area: what and why`); do not push. No git worktrees. No feature-branch
  juggling beyond the branch in use.
- One Quartus flow at a time on this PC, ever (other sessions build other
  cores here: check `Get-CimInstance Win32_Process` for `quartus*` and match
  the command line before killing anything). Never edit the `.qsf`/RTL during a
  flow. Launch detached from PowerShell with `Start-Process`, wrapping the
  whole `bash -lc "..."` command in its own double quotes, and confirm a
  `quartus_*` process 45 s later. To stop a wait-gated build, kill every
  `scripts/build_only.sh` bash, not just the outer wrapper.
- Try marginal builds on hardware rather than walking seeds
  (`ALLOW_TIMING_VIOLATION=1`); a miss on the 33 MHz CPU clock is the dangerous
  kind, an HDMI-domain miss is video only.
- Go fast, do not stop to ask between build/run iterations; prefer the hardware
  to the slow full-machine sim; restore a damaged image from `backup/` instead
  of repairing it in the guest. Analyse one build fully before the next.
- Hardware driving was delegated to a cheaper-model operator agent with a tight
  script; design work stayed with the main model.
- Build instruments early (FPGA DEBUG/SAMPLE words, Main's regtrace / pcap /
  RAM dump, runtime OSD switches instead of a build per hypothesis): they found
  in hours what theory did not. Reproduce with the user's actual disk image in
  QEMU before blaming the core; check MAME before blaming a Main-side hack.

Hardware rules that have cost data (full text in `CLAUDE.md`): look at a
screenshot and read it before any deploy, in a separate command; never
`load_core` over a running guest; judge liveness by `/proc/$(pidof MiSTer)/io`
`write_bytes` and the menu-bar clock, never the `.hda` mtime; always send a
button-up after a guest-menu operation; never restart the mrext remote service
under a running core (remote input dies until the next `load_core`).

Main (`../Main_MiSTer`) specifics:
- Build in WSL Ubuntu-24.04 with the arm toolchain
  (`/opt/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf/bin`), via
  `scripts/build_main_wsl.sh` from this repo. **After a rebase or any header
  change, clean-build** (`rm -rf ~/Main_MiSTer/bin`): stale objects once linked
  a binary with a shifted `struct cfg` and the menu went black. Verify with
  `find ~/Main_MiSTer -name '*.o' ! -newermt "$(date +%F) 00:00"`; record the
  binary's md5.
- **Swap the binary by rename + reboot**: `mv MiSTer MiSTer.prev_<md5>; mv <new> MiSTer; sync; reboot`
  (`cp` over the running binary fails "Text file busy"). A hand relaunch over
  ssh (`killall MiSTer; nohup ... MiSTer menu.rbf`) has left the user's HDMI
  black with a perfectly good binary, and screenshots cannot see HDMI — only
  the user can judge the display; warn them first and reboot afterwards. On
  core load Main restarts into `/media/fat/MiSTer`, so an A/B candidate must
  live at that path.
- Main sends `stdout` to `/dev/null` unless `MiSTer.ini` has `debug=1` (it has,
  since 2026-07-30); stderr is always visible; `/tmp` is wiped on reboot. For a
  log, start it with `stdbuf -oL` and a file redirect.
- Code style there aims at upstream review: comments of at most two terse
  lines, only for the genuinely non-obvious, no history or dates; delete
  commented-out code. Mac-only behaviour is gated (`is_mac_scsi_optimized()`,
  core name `macquadra800`). The tree is shared with other sessions (MacLC
  work): re-read before editing, check `git log` for surprise commits.
- Shell traps: `pkill -f pattern` inside `wsl.exe -e bash -lc` or over ssh
  kills its own shell (use `pkill -x` or a pid); Bash-tool heredocs eat
  backslashes (use `chr(92)` in Python, or line edits); Git bash mangles
  `/media/fat/...` arguments without `MSYS_NO_PATHCONV=1`; `ssh` without `-n`
  eats a piped script; strip CRs after an rsync from the Windows tree.
