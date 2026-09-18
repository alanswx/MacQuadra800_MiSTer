# Built-in Ethernet (DP83932 SONIC)

The Quadra 800's onboard Ethernet. The guest sees the real chip at the real
addresses, so the ROM's and the systems' own drivers bind to it: nothing to
install in Mac OS beyond Apple's "Apple Built-In Ethernet" (already on the Quad
Squad disk), no declaration ROM, no NuBus card.

**Status 2026-09-18: implemented and bench-tested, not yet run on hardware.**
A/UX networking is a later milestone (see "Open").

## Using it

- Needs the Main fork (`../Main_MiSTer`, `support/mac/mac_eth*`, `mac_sonic*`)
  with the Quadra 800 personality. On a stock Main the option does nothing and
  the machine is the one without Ethernet.
- OSD: **Ethernet (on reset): Off / On**, default Off, and **Net interface**:
  `eth0`, `eth1`, `wlan0`, `tap0`. Both take effect at the next reset — the
  guest must never see the chip appear or vanish under it.
- The guest's MAC address is `08:00:07` (Apple) + the last three octets of the
  chosen interface's own address (`eth0`'s, then `wlan0`'s, for a tap). Every
  MiSTer therefore gets its own stable address with nothing to configure, and
  there is deliberately no override in the core or its config directory: to
  change it, change the MiSTer's address.
- `eth0`/`eth1` bridge raw frames in promiscuous mode. Most Wi-Fi access points
  drop frames with a foreign source address, so on a Wi-Fi-only box use `tap0`
  and bridge or route it on the Linux side.
- `/tmp/mac_eth_stats` on the MiSTer, rewritten every second, is the first
  place to look: frame counts each way, the register-write histogram, and the
  `q8` lines (DMA round trips and their latency, ISR posts, Main's pass rate).
- Build without it: `set_global_assignment -name VERILOG_MACRO "ETHERNET_OFF=1"`
  in the `.qsf` (no front-end, no bus master, no DDR3 port, no OSD lines).

## How it is split

The chip *model* — CAM filter, descriptor walks, CRC, the bridge to Linux —
runs on the ARM (`mac_sonic.cpp`, a port of MAME's `dp83932c`). The FPGA holds
only what has to be in the machine, `rtl/sonic_mbx.sv` (its header carries the
window layout, which `support/mac/mac_eth.h` mirrors):

| piece | where | why there |
|---|---|---|
| register writes | doorbell ring in a DDR3 window (ARM `0x1FF00000`) | the guest waits for DDR3, never for software |
| register reads | one on-demand DDR3 read of the ARM's shadow block | no 64-register shadow file in flip-flops; fresher than a polled copy |
| ISR, IMR | flip-flops in the FPGA | write-1-to-clear must take effect in its own bus cycle; `irq` is exact |
| CR command bits | overlay until the ARM's applied index passes the write | Apple's driver spin-polls `CR.TXP` |
| MAC PROM | on-demand DDR3 read | read once per driver open |
| guest RAM access | op-list DMA engine, a third master in `quadra800.sv`'s service FSM | the SONIC is a bus master; packets and descriptors live in main RAM |

ISR ownership: the ARM posts raises through a sequenced `ISR_SET` word, one
post in flight at a time; every doorbell entry carries the last seq the FPGA
had consumed, so the ARM clears its replica bit only if the guest could have
seen that bit's latest raise. A clear and a post in the same clock: the post
wins, and the entry names the older seq, so both sides keep the bit.

DMA: the ARM posts up to eight `{direction, byte address, byte count}` ops; the
engine executes them in order as longword beats, the first and last write beat
under byte enables. Main defers writes and sends them in front of the next
read, so a received frame is two round trips — `{frame bytes, descriptor body,
link read}`, then `{in_use, status}` — and the status word that publishes the
descriptor is always the last access (the MacLC card's ordering law). Beats go
through the ordinary RAM port: `sdram_beat32` drops its retained line as for
any write, and each write beat pulses `wombat_cpu`'s snoop port, the 68040's
bus-snoop invalidate. The engine carries `addr[26:2]`: RAM only, by
construction.

Presence: OSD On (latched under reset) AND the Main service's MAGIC seen since
reset. Until then, and always with the option Off, `$5000A000` / `$50008000`
are iosb's inert read-0 space, exactly as before this feature; with the option
Off the block is held in reset and issues no DDR3 or bus request at all.

Ground truth, MAME `macquadra800.cpp` and QEMU `q800.c` agree: registers
`$5000A000`, 4-byte stride, value in the low half of the longword; PROM
`$50008000` = six fully bit-reversed MAC bytes, 0, `~XOR`; INT on VIA2 port A
bit 0 (slot $9), IPL 2. A QEMU trace of this ROM (2026-09-18): the ROM probes
`CR` with word reads at +0, then quiesces the chip with longword writes
(`CR=$4`, read, `CR=$80`, `IMR=0`, `CE=0`), twice per boot; the front-end takes
word accesses on either half and longwords.

## Tests

- `make tb_sonic_mbx` (in `verilator/`): ring, shadows, PROM, ISR ownership,
  CR overlay, a three-op DMA list with byte enables and a 1514-byte frame,
  reset replay protection, the bus watchdog, Off-inertness. `make lint_sonic`
  elaborates the machine with the front-end in (`sim.v` builds `SONIC=0`).
- Main: `support/mac/test/mac_q8_test.cpp` runs the model and the DMA client
  against a C model of the engine (publish order, round-trip counts, ack
  causality).
- Not bench-covered: D-cache coherence under DMA. On hardware, an md5 of a
  file transferred each way is the check.

## Open

- First hardware run; FTP throughput each way; Speedometer with Ethernet On
  and idle against Off.
- A/UX: QEMU routes the SONIC to IPL 3 in A/UX mode; this core has only the
  classic 4/2/1 scheme. Trace QEMU's A/UX first.
