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

- Main: unit test `support/mac/test/mac_q8_test.cpp` 49/49; cross-build
  `scratch/MiSTer_7207759c`, **installed on the .143 box 2026-09-18 13:57 by
  rename + reboot** (previous binary kept as `/media/fat/MiSTer.prev_bb1a08d3`;
  rollback = rename back + reboot). It is `bb1a08d3`'s source plus `d277747`.
- Core: `make tb_sonic_mbx` 37/37, `make lint_sonic` clean. First Quartus
  compile (seed 21) running on `.153` from `69d9585`.
- The MiSTer's eth0 is `ba:02:54:2d:d0:a3`, so the guest will be
  `08:00:07:2d:d0:a3`.
- `/media/fat/config/MacQuadra800.CFG` is 16 zero bytes; Ethernet On = byte 0
  bit 6 (`0x40`), interface = bits 8:7 (0 = eth0). Patch the file before
  `load_core` instead of driving the OSD blind.

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
