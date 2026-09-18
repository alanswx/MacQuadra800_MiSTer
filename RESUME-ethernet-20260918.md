# RESUME — built-in Ethernet (2026-09-18)

Read `docs/ethernet.md` first (what it is, how it is split, the contracts).
The planning analysis is in `docs/sonic-ethernet-plan.md`, which is **untracked
on purpose** (user: never commit the plan; it is in `.git/info/exclude`).

## Branches (nothing pushed; the user pushes)

| repo | branch | head |
|---|---|---|
| core | `add-ethernet` (cut from main `87a6cc3`) | see `git log` — `1be2218` is the RTL, `69d9585` the design note |
| Main fork `../Main_MiSTer` | `mac-ethernet-pr-with-SCSI-Optimizations-with-q800-eth` | `d277747` |

`CPU-pipeline` was moved back locally to `8353cdd`: I had committed the plan
there as `45e81a3` and the user pushed it before ruling that the plan stays
out of the repo. `origin/CPU-pipeline` still has it; removing it is the user's
`git push --force-with-lease origin CPU-pipeline`.

## User rulings (2026-09-18)

- Slim design (ARM-side chip model, FPGA mailbox with local ISR/IMR, op-list DMA).
- MAC = `08:00:07` + the MiSTer's last three octets; **no override in the core
  or its config dir** — to change it, change the MiSTer's address.
- OSD default **Off**; an OSD choice of the interface to bridge.
- A/UX networking is a stretch goal for a later session.
- MacIIvi and LBMacTwo are no longer shipped: their NuBus Ethernet personality
  and family entries are gone from the Main fork.
- A second PC may run Quartus: `dani@192.168.99.153` (Ubuntu, Quartus 17.0.2
  Lite in `~/intelFPGA_lite/17.0`, key `~/.ssh/mister_only`). Recipe:
  `git archive HEAD | ssh ... 'tar -x -C ~/MacQuadra800_eth'`, write
  `scripts/local.env` with `QUARTUS_BIN=/home/dani/intelFPGA_lite/17.0/quartus/bin`,
  `nohup setsid bash scripts/build_only.sh --no-wait > build_remote.log`.
  Its disk is 96 % full (9 GB free): delete old build dirs there.

## State

- Main: unit test `support/mac/test/mac_q8_test.cpp` 49/49. Installed on the
  .143 box by rename + reboot: `088865ba` (= `a56296d`: the Q8 personality +
  the `q8 fpga` stats line + delivered/filtered counts). Older binaries kept
  as `/media/fat/MiSTer.prev_7207759c` and `MiSTer.prev_bb1a08d3` (the last
  one is the pre-Ethernet Main; rollback = rename back + reboot).
- Core: `make tb_sonic_mbx` 37/37, `make lint_sonic` clean.
- **Ethernet build 1** (`69d9585`, seed 21, built on `.153`): 36,560 ALMs,
  HDMI -0.306. On hardware: boots with Ethernet Off and On; the driver opens
  once TCP/IP points at Ethernet; 12 packets sent, DMA round trips 36 us
  average, 68 ISR posts all consumed — then **the whole guest froze**.
  Cause: `iosb.sv`'s VIA2 any-slot flag followed edges of the OR of VBL and
  SONIC; with two sources the flag is cleared while the other is asserted and
  no slot interrupt (VBL included) is ever delivered again. Fixed `665a450`
  (the flag is a level). Evidence in `scratch/eth/hw1/` (`hang_stats.txt`).
- **Ethernet build 2** (`665a450`, seed 21, `.153`): meets timing everywhere
  (36,502 ALMs, clk_sys +0.323, HDMI +0.314, clk_ram +0.716, hold +0.220);
  rbf `2ea4d529` in `scratch/eth/build2/`; hardware run in `scratch/eth/hw2/`.
- `sonic_mbx` by itself: 401.6 ALMs / 665 ALUTs / 0 RAM (build 1 fit report).
- The MiSTer's eth0 is `ba:02:54:2d:d0:a3`, so the guest is
  `08:00:07:2d:d0:a3` (confirmed: Main held unicast frames for that address,
  i.e. the DHCP server answered it, so the PROM path is right).
- `/media/fat/config/MacQuadra800.CFG`: Ethernet On = byte 0 bit 6 (`0x40`,
  currently set; the Off copy is `MacQuadra800.CFG.bak_ethoff`), interface =
  bits 8:7 (0 = eth0). Patch the file before `load_core` instead of driving
  the OSD blind.
- Reading `/tmp/mac_eth_stats`: `q8 fpga isr/imr/present/irq` is the FPGA's
  own state; `regwr 05=` counts the guest's ISR acknowledgements. A frozen
  guest with `irq=1` and a flat `05=` is an interrupt that is not delivered.

## The first hardware day, in order (2026-09-18)

Evidence for each step is under `scratch/eth/hw1` .. `hw7` (stats, register
traces, captures, guest RAM dumps, screenshots) and `scratch/eth/build1` ..

1. **Build 1** froze the guest: `iosb.sv`'s VIA2 any-slot flag was an edge
   latch on the OR of VBL and SONIC. Fixed `665a450` (a level). Not seen since.
2. **Build 2**: DHCP DISCOVER answered by an OFFER the guest ignored. Capture +
   QEMU source: in 32-bit mode the chip keeps the receive buffer pointer
   longword-aligned; the MAME-derived model packed frames at odd addresses.
   Fixed in Main `3ad68f5`; DHCP then completes in 6 ms.
3. Still hangs/crashes seconds after receive traffic starts, in three shapes:
   a Finder livelock in shared-library code, a runaway exception stack (first
   frame: format-$7 access error, PC $01D2207E, fault address $517CE208), a
   plain bomb "Finder error type 10".
4. Instruments built for this (all still in): the FPGA's DEBUG word (ISR, IMR,
   irq, guest read count + last register read) and SAMPLE word (CPU PC + SR);
   Main's register-write trace, packet capture, guest-RAM dump through the DMA
   engine, PC histogram, and `/tmp/mac_eth_dbg` switches (1 = drop guest-RAM
   writes, 2 = refuse every received frame). See `docs/ethernet.md`.
5. **QEMU reference** (WSL `~/qemu-work`: `qs8_eth.hda` = the box's image of
   17:16, `qemu_net.py` = a scripted DHCP/ARP/ping LAN on QEMU's UDP socket
   NIC, `qemu_replay.py` = replays a hardware capture): the same image does
   DHCP, gratuitous ARP, answers ARP and ping, reloads the CAM with a multicast
   address right after the REQUEST, and survives eleven replays of the very
   frames that kill the FPGA guest. The register WRITE sequences match ours
   one for one up to the point of death.
6. Narrowing on hardware with the switches: with receive refused the guest is
   perfectly healthy (desktop, clock, DHCP retransmits with back-off); turned
   on at the live desktop it bombs within ten delivered frames -- while a
   guest RAM dump shows every descriptor and every frame byte-exact against
   the capture, pointers aligned, the ring recycled by the driver.
7. So RAM is right and what the CPU sees is not: builds 5 and 6 had the D-cache
   snoop OFF (an experiment, `ede6d62`). Apple's driver marks a recycled
   receive descriptor with $FF in the top byte of its length longword, so a
   stale cached copy is a 4 GB length. The earlier snoop-ON builds (2-4) each
   still had another bug (alignment, the TXP overlay race `6341570`, the early
   applied index). **Build 7 = snoop on + every fix** is the test that has not
   been run yet (`54ae465`).

If build 7 still dies: the snoop port of the vendored `ap040_cache` under
hundreds of snoops per frame concurrent with CPU stores is the next suspect
(`store_inv_lost`, the hint path); a directed bench there, or a coarser
scheme (hold the CPU off the bus for the length of a DMA list and invalidate
once), are the two ways forward.

## QEMU ground truth gathered (WSL `~/qemu-work/sonic8.log`, `sonic8_mr.log`)

This ROM + a copy of the Quad Squad disk, 5.5 minutes: the ROM reads `CR` as a
WORD at `$5000A000` (+0) 22 times, then quiesces with LONGWORD writes `CR=$4`,
read `CR` (=$14), `CR=$80`, `IMR=0`, `CE=0`; the whole thing happens twice per
boot. Mac OS never opens the driver on its own: TCP/IP (or AppleTalk) must be
pointed at Ethernet in the guest. QEMU here has no slirp (`-nic user` fails);
`-nic socket,udp=...,localaddr=...` gives the NIC a backend.

## Next

1. Fit result: ALMs vs 36,089, slack per clock, RAM Summary unchanged; record
   the seed in the `.qsf` comment block; cross-domain STA script.
2. Hardware, Mac OS 8.1 (operator subagent; binding rules in CLAUDE.md):
   boot with Ethernet **Off** first (must be the 20260918 machine), then On;
   TCP/IP -> Ethernet/DHCP; `/tmp/mac_eth_stats` (`q8` lines: rpc us_avg,
   isr posts, acks_kept, passes); ping the guest from the LAN; then a file
   each way with an md5 (the D-cache/DMA coherence check no bench covers);
   Speedometer On-idle vs Off.
3. NetBSD 11 mac68k ISO is on the box (`games/MacQuadra800/`): its `sn` driver
   is an independent second opinion on the register and DMA behaviour.
4. Then the speed pass and A/UX (QEMU routes SONIC to IPL 3 in A/UX mode; this
   core has no A/UX interrupt mode — trace QEMU's A/UX first).
