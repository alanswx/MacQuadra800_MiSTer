# RESUME — Quadra 800 Ethernet, the CAS bug found (2026-09-19)

Supersedes `RESUME-ethernet-20260918c.md` for state and next steps; that file
still holds the experiments, the instruments and the operating knowledge, and
is worth reading once. The work moved from Dani's Windows PC to Alan's Linux
box on 2026-09-18 — section 3 says what is different here.

## 1. The bug

**Not a CAS problem, not a stale read, not the cache: a phantom bus
transaction.** `rtl/quadra800.sv` serves an aligned RAM longword read that
matches `sdram_beat32`'s retained line through a registered pulse,
`bus_line_ack`, without going through the service FSM. In the clock that pulse
is high, `bus_req` still carries the request being acknowledged. Nothing told
`bus_req_adapter` so — it was held low only because `bus_line_match` was still
high, which needs `svc == S_IDLE`. With the CPU as the only master that was
always true. The SONIC's DMA arm can take the FSM to `S_MEM` in exactly that
clock (`dma_take` does not count a line match as the CPU wanting the bus), so:

1. `bus_ram_eligible` drops under the ack, `bus_req_adapter` rises;
2. `wombat_bus32` captures a read of the already-acknowledged address;
3. the requester moves on; the adapter is now busy with a read nobody wants;
4. its `t_ack` acknowledges **whatever is on the bus by then** — a cache fill
   beat takes its neighbour's word, or a store is acknowledged and never
   written.

A dropped store under Open Transport's `cas.l` / `cas2.l` is precisely a LIFO
going circular. It also explains every line of the 2026-09-18 experiment table:

| observation | why |
|---|---|
| only with the retained-line paths on (`dbg_sw[1]` off) | the switch forces `bus_line_match` to 0 |
| only under receive traffic | it needs a DMA beat to arrive in one particular clock |
| guest RAM byte-exact, QEMU fine with the same frames | the DMA data was never wrong; the CPU's transaction was |
| store buffer on = dies in seconds, off = ~31 pings | `buffered_store_pending` gates the cache's own `m_line` shortcut, which pushes reads onto `bus_line_match` instead |
| snoop off = dies sooner | independent: without it the D-cache really is stale |
| `t_cas_lifo` passes | that harness has no second master |

Fix, commit `0533256`: `!bus_line_ack` in both `bus_ram_eligible` and
`bus_req_adapter`. Cycle-identical with one master.

Reproduction: `make tb_line_dma` in `verilator/`. The bench holds the FSM's RAM
subset line for line around the real `wombat_bus32`, `sdram_beat32` and
`sdram`, with a bursty DMA writer. `-GFIX=0`: 401 wrong transfers in 16000
reads and 2029 stores, one per line ack that found the FSM busy. As shipped:
325 such acks, 0 errors. Dense DMA traffic hides the bug (the line is always
already dropped) — it needs pauses, which is what real op lists have.

## 2. State and next steps

- **Build 9** = `0533256`, seed 21, timing met (CPU clock +0.905 ns, HDMI
  +0.197 ns), 88 % ALMs, rbf md5 `74532e55...`, in
  `scratch/ethernet-handover/build9/` and on the MiSTer in `_Unstable/`.
- **On hardware, 2026-09-19, CFG `40 00` — every fast path ON, the
  configuration that died within seconds on builds 2-8:** DHCP completes in
  259 ms (lease 10.3.231.233, guest MAC `08:00:07:05:06:07`), clean guest
  restart with a DHCP RELEASE, then **1000/1000 pings of 1400 bytes, 0 lost,
  3.7-7.1 ms** at five a second (`scratch/ethernet-handover/hw11/soak_1..4.txt`),
  on a LAN that puts ~100 frames a second on the wire. The longer two-stream
  soak is `soak_long_a/b.txt` in the same folder.
- One thing seen and not chased: `q8 rpc ... us_max 250071 slept 1 fail 1` —
  a single DMA round trip hit Main's 250 ms timeout, almost certainly across
  the guest's restart (the engine is reset under a request). Check that Main
  recovers by design rather than by luck.

1. FTP both ways with an md5 (the user logs in themselves), and the
   throughput figure with the fast paths on (section 4 of the 09-18 resume
   measured 44 KB/s with one off).
2. Remove the `Dbg ...` OSD lines and `dbg_sw` (commit `5a271f0`), decide on
   the SAMPLE/DEBUG words (~100 ALMs), then the full regression gate from
   `CLAUDE.md` with Ethernet Off and On, and Speedometer On-idle vs Off.
3. A/UX networking, later.

Worth a look while in there: `walker_pend` rising in the line-ack clock would
have opened the same hole. It cannot today (`walker_req` is held off while the
cache is busy), and the new guard covers it regardless.

## 3. This machine (Alan's Linux box) versus the docs

`CLAUDE.md` and the 09-18 resume describe Dani's Windows PC. Here:

- Quartus is native (`scripts/local.env`), a full build is ~15 min. Launch it
  with `systemd-run --user --unit=... bash -lc 'bash scripts/build_only.sh > log 2>&1'`
  so a tool timeout cannot kill it. Verilator 5 is
  `/home/alans/verilator5/bin/verilator` (`make V=... <target>`).
- The Main fork is `../Mac_Main_MiSTer` (not `../Main_MiSTer`), branch
  `mac-ethernet-pr-with-SCSI-Optimizations-with-q800-eth`, head `68637c9`. The
  ARM toolchain is in `/opt/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf/bin`.
- The MiSTer is `MiSTer.local` (10.3.89.233 / eth0 10.3.164.251 on a 10.3/16
  LAN), key `~/.ssh/id_rsa`. **It is shared with other core sessions** — look
  at `ps w | grep MiSTer` before loading a core or rebooting. Dani's
  `192.168.99.x` boxes are not reachable from here.
- On the box: `games/MacQuadra800/QuadSquad8.hda` is Dani's image with TCP/IP
  set up (md5 `c86dc7ec...`, pristine copy in
  `~/mister/MacQuadra800_fixtures/`), slot 0 points at it, `_Unstable/` holds
  the core. There is no `config/MacQuadra800.CFG` until the core has run once,
  so the CFG byte patching of the experiment recipe needs one load first.
  There is no A/UX image and no `backup/` directory on this box.
- That image came with TCP/IP on "Alternate Ethernet" and "load only when
  needed", so the driver never opened. It is now set to **Ethernet built-in,
  DHCP, load at startup** (done in the guest on 2026-09-19; the pristine copy
  in the fixtures directory still has the old setting).
- **This box's mrext remote has no mouse** (`mouseMove` answers `invalid`), so
  `menu.sh`, `click.sh` and `mac_shutdown.sh` do not work here; the keyboard
  half of `mister_ws.py` does. `scripts/guest/vmouse.py` is a uinput mouse that
  runs on the MiSTer (`scp` it to `/tmp`, `python3 /tmp/vmouse.py home m:100,60 click`):
  about 1.4-1.6 px per count, so move, screenshot, correct. To hold a menu open
  for a screenshot, run it in the background with `down 9 up` and grab meanwhile.
- The guest's MAC follows the MiSTer's, so its address here is not the
  `08:00:07:2d:d0:a3` / `192.168.99.109` of the 09-18 notes; read it from
  `/tmp/mac_eth_stats` and the LAN's DHCP leases.
