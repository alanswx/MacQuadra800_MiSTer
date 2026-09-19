# RESUME PROMPT — Quadra 800 built-in Ethernet, end of 2026-09-18

> **Superseded by `RESUME-ethernet-20260918c.md`** (the hand-over version: the
> A2 soak result, the FTP observation, RTL pointers, operating knowledge).

Paste this file as the opening prompt of the next session (working directory
`C:\Temp\mistercore\MacQuadra800_MiSTer`). Read `CLAUDE.md` (binding hardware
rules), then `docs/ethernet.md` (design + instruments), then the day log in
`RESUME-ethernet-20260918.md`. The planning analysis is
`docs/sonic-ethernet-plan.md`, **untracked on purpose** (user: never commit the
plan; it is in `.git/info/exclude`).

## Where things stand

**The Ethernet works on hardware** — with two of the machine's CPU fast paths
switched off: DHCP in 6 ms, gratuitous ARP, ARP replies, 108/108 pings
(100 of them 1400-byte) at 2-4 ms, live desktop, clean shutdown. Guest MAC
`08:00:07:2d:d0:a3` (= Apple OUI + the MiSTer's last three octets), guest IP
`192.168.99.109` from the LAN's DHCP server.

**The open bug is in the CPU memory path, not in the Ethernet.** With the
fast paths on, Open Transport's atomic list code goes wrong seconds after
receive traffic starts: OTLIFOEnqueue (`cas.l d0,d1,(a0)`) and OTLIFODequeue
(`cas2.l d0:d1,d1:d1,(a0):(a1)`, encoding `0EFC 8040 9041`) at guest
`$158188`/`$15819E`; the deferred work list becomes circular (a pop handing
out one element twice), the Finder livelocks or the guest bombs / runs away
into an exception-frame storm. Proven NOT to be: the frames (QEMU survives the
same capture replayed against the same disk image), the DMA data (every frame
and descriptor in guest RAM is byte-exact against the capture), the interrupt
path, transmit, the mailbox, the D-cache snoop on/off.

Bring-up switches in build 8 (OSD status bits, latched under reset; set them by
patching `/media/fat/config/MacQuadra800.CFG` before a `load_core`):
byte 0 `0x40` = Ethernet On; byte 1 bit 1 (`0x02`, status[9]) = **store buffer
+ posted stores OFF**, bit 2 (`0x04`, status[10]) = **retained-SDRAM-line fast
paths OFF**, bit 3 (`0x08`, status[11]) = DMA snoop OFF.

| experiment | CFG bytes 0,1 | result |
|---|---|---|
| all fast paths on (builds 2-7) | `40 00` | hang/bomb within seconds of RX |
| A: store buffer off + line off | `40 06` | **works**: 108/108 pings, alive, clean shutdown; a 1000-ping soak (4 x 250 x 1400 B) was started at 19:20, results in `scratch/ethernet-handover/hw9/A2_soak_*.txt` |
| B: store buffer off only | `40 02` | DHCP/ARP/6 pings fine, then **crashed** ~31 pings into a 1400-byte soak (PC wedged at `$517CAC`, the exception dispatcher) |
| C: line off only | `40 04` | **not run yet** |

So both `rtl/wombat_store_buffer.sv`/the cache's one-clock posted store AND the
retained-line paths (`quadra800.sv` `line_cpu_match` / `bus_line_match` /
the cache's `m_line_*` sideband) are implicated, or the real fault is a
multi-master race whose odds both of them change. Things already checked and
found sound on paper: the store buffer's `pass_ok` (one queued store, other
line only), `sdram_beat32` line invalidation on every accepted write, the
cache's per-word sideband tag check, the service FSM's DMA arm. The CPU core's
own harness passes the exact OT routines with caches on
(`rtl/ap68040/tb/asm/t_cas_lifo.s`) — but that harness has no store buffer, no
retained line and no second bus master.

## Next steps, in order

1. Read the A2 soak result; run experiment C; re-run B once more for
   statistics. If A is solid and B and C both fail, the common factor is DMA
   beats interleaving with CPU traffic that those paths assume is
   single-master (the AP68040 header says so: "TAS/CAS/CAS2 are not bus-locked
   (single-master fabric here)").
2. Reproduce in simulation: a directed bench with the REAL wrapper
   (`wombat_cpu` + `wombat_store_buffer` + `sdram_beat32` + the service FSM,
   i.e. a cut-down `quadra800`) running `t_cas_lifo`-style code while a
   second master issues random read/write beats through the DMA arm. Nothing
   today instantiates `wombat_cpu` outside the full-machine sim
   (`SingleStepTests/preboot` benches boot it through the ROM).
3. A cheap hardware discriminator before that: make DMA beats take the bus
   only when the CPU side is completely idle for N clocks, or hold the CPU
   off for a whole op list, and see whether B/C stop failing.
4. When fixed: remove the `Dbg ...` OSD lines and `dbg_sw` (commit `5a271f0`),
   decide whether the SAMPLE/DEBUG words stay (they cost ~100 ALMs), set CFG
   back, run the full regression gate (8.1, A/UX at 32 MB, CD audio by ear)
   with Ethernet Off and On, Speedometer On-idle vs Off, FTP both ways with an
   md5 (the user logs in to `192.168.99.5` themselves — I do not type
   passwords), then the speed pass and A/UX networking.

## What is installed / where

- MiSTer `.143`: Main `b6b5cc17` (fork branch
  `mac-ethernet-pr-with-SCSI-Optimizations-with-q800-eth`, head `68637c9`),
  previous binaries `MiSTer.prev_e2255642`, `MiSTer.prev_bb1a08d3` (the
  pre-Ethernet one). Core on the box = **ethernet build 8** (`5a271f0`, rbf
  `edf32a3b`, meets timing, 36,635 ALMs) in `_Unstable/`. CFG currently
  `40 06`; the Ethernet-Off copy is `MacQuadra800.CFG.bak_ethoff`. The guest's
  TCP/IP is set to built-in Ethernet, DHCP, load at startup. **At the time of
  writing the guest is RUNNING (experiment A, soak in progress): look before
  touching the box, shut it down with `bash scripts/mac_shutdown.sh`.** The
  Quad Squad image was yanked several times today while hung; it boots and
  works, but restore `backup/QuadSquad8_20260918_clean_after_b9.hda` before
  any release gate (then redo the TCP/IP setting).
- Core branch `add-ethernet`, head = the commit that adds this file. Builds:
  `scratch/ethernet-handover/build1..8/` (rbf + summaries); hardware evidence
  `scratch/ethernet-handover/hw1..hw9/`. Second Quartus host `dani@192.168.99.153`
  (`~/MacQuadra800_eth`, recipe in `RESUME-ethernet-20260918.md`); this PC's
  Quartus is free again and builds in ~20 min.
- QEMU reference in WSL `~/qemu-work`: `qs8_eth.hda` (the box's image),
  `qemu_net.py` (scripted DHCP/ARP/ping LAN on the UDP socket NIC),
  `qemu_replay.py` (replays a hardware capture), traces `sonic_eth.log`.
  Copies of the scripts are in `scratch/ethernet-handover/`.
- Instruments (all in build 8 + Main `b6b5cc17`): `/tmp/mac_eth_stats`
  (`q8 fpga`, `q8 reads`, `q8 pc` histogram, `q8 regs`), `/tmp/mac_eth_regtrace`,
  `/tmp/mac_eth.pcap` (`python3 scratch/ethernet-handover/pcapsum.py`), `/tmp/mac_eth_dumpreq`
  -> `/tmp/mac_eth_dump.bin` (guest RAM through the DMA engine; works on a
  hung guest), `/tmp/mac_eth_dbg` (1 = drop DMA writes, 2 = refuse all RX),
  and on the MiSTer `devmem 0x1FF040D0 32` samples the CPU's PC.
- Nothing is pushed in either repo (the user pushes). `origin/CPU-pipeline`
  still carries the plan commit `45e81a3`; removing it is the user's
  `git push --force-with-lease origin CPU-pipeline`.

## Fixes that landed today (all committed)

Core: `1be2218` the front-end; `665a450` VIA2 any-slot flag as a level (build 1
froze on a lost slot interrupt) + DEBUG word; `c49fcf3` read counter; `b20e833`
PC sampler; `6341570` applied index inside the ISR post (CR overlay drops in
the clock TXDN rises); `54ae465` snoop on; `5a271f0` the bring-up switches;
`4055c23` `t_cas_lifo`. Main: `d277747` Q8 personality (NuBus/IIvi/LBMacTwo
removed), `3ad68f5` **32-bit mode keeps the receive buffer pointer
longword-aligned** (DHCP was failing without it), `b527eb9` instruments + the
applied index only after the apply, `3bd7510`, `68637c9` debug switches.
