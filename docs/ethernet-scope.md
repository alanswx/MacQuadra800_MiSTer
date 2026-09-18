# Built-in Ethernet (SONIC) — what it would take

**Status: survey only, 2026-09-18. Nothing built, nothing decided.** Written
from MAME (`~/mame/src/mame/apple/macquadra800.cpp`,
`src/devices/machine/dp83932c.cpp`), our own ROM image, the Main fork
(`../Mac_Main_MiSTer`, branch `mac-ethernet-pr-with-SCSI-Optimizations`) and
the MacLC core (`../MacLC_MiSTer`), which has the whole thing working as a PDS
card. This replaces open item 10 of `RESUME-open-items.md` with a costed plan.

The headline: **most of this already exists.** The SONIC chip model, the
mailbox protocol, the network bridge and one full set of hardware bring-up
scars are done and shipped on two other Mac cores. What this core has to add is
a front-end module, an I/O decode, and a DMA engine into SDRAM — plus about a
thousand ALMs it does not currently have.

---

## 1. How the real Quadra 800 did it

Built in on the motherboard, not a card. MAME's `quadra800_map()` and machine
config (`macquadra800.cpp:161-162`, `240-242`) are the ground truth:

| piece | guest address | shape |
|---|---|---|
| DP83932C SONIC (C20M, 40 MHz/2) | `$5000A000-$5000B0FF`, `.mirror(0x00fc0000)` — i.e. the `$50F0A000` the drivers use | 64 x 16-bit registers, `umask32 0x0000ffff`: register index = `A[7:2]`, the 16-bit value in the **low** half of the longword (`A+2`); the `$100` bank mirrors through the window |
| MAC address PROM | `$50008000-$50008007`, same mirror (`$50F08000`) | byte reads. Bytes 0-5 = MAC, bit-swizzled `bitswap<8>(b,0,1,2,3,7,6,5,4)`; byte 6 = `$00`; byte 7 = XOR of bytes 0-5, complemented |
| interrupt | SONIC INT -> `iosb_device::via2_irq_w<0x01>` | bit 0 of the pseudo-VIA slot register (active low), so IPL 2 |

Two facts shape everything downstream:

* **The chip bus-masters main memory.** `m_sonic->set_bus(m_maincpu, 0)`: the
  CAM load descriptors, the receive resource area, the RX/TX descriptor rings
  and every packet buffer live at guest *physical* addresses and the chip
  fetches and stores them itself. There is no on-card RAM to hide in.
* **A Quadra runs it in 32-bit (dword) mode** — `DCR.DW`, descriptor stride 4 —
  where the LC-class machines run 16-bit mode with stride 2. Worth confirming
  from a MAME register trace before building anything, because it decides the
  address width the DMA path has to carry.

### No declaration ROM is needed

Unlike the LC PDS and NuBus cards, there is nothing to serve. Parsing
`releases/quadra800.rom`: the format block at `0xFFFEC` (byteLanes `$0F`, test
pattern `5A932BC7`) points at a directory at `0xF2CA4` holding exactly one
sResource — `catBoard`, named "Unknown Macintosh". There is no Network
sResource anywhere in the image. The ROM does carry the SONIC POST (the string
"SONIC Ethernet controller CTE Test" at `0x460A2`), and discovery on the guest
side is the ROM plus the **Apple Built-In Ethernet** extension — already
installed on `QuadSquad8.hda` — poking the fixed addresses above.

That deletes the single largest piece of the LC card's front-end: no 64 KB
declROM window, no DDR3 ROM staging, no Slot Manager enumeration, no
`pds_claim` aliasing guard, no `$0028` word-read presence magic.

### What the core does today

`rtl/iosb.sv` decodes neither window. Its header calls SONIC
"present-but-inert" (`rtl/iosb.sv:9`) but there is no select for it: unmapped
`$50xxxxxx` accesses fall through to the catch-all that returns 0 and acks
(`rtl/iosb.sv:1113`). So the PROM checksum fails, the driver decides there is no
hardware, and the machine boots clean. That is why Ethernet's absence has never
cost us a boot.

---

## 2. What already exists elsewhere

### Main fork — the whole host half

`../Mac_Main_MiSTer` commit `dfb1f94` ("Mac: Ethernet card support"), by Dani
Sarfati, already in the Main we ship:

| file | what |
|---|---|
| `support/mac/mac_sonic.cpp` (562 lines) | the DP83932/DP83934 model, a flow-for-flow port of the same MAME `dp83932c.cpp`. Guest memory is reached through injected host ops, so it has no target dependencies. Already supports stride 4 (dword mode) and `sonic_set_addr_bits(32)` |
| `support/mac/mac_eth.cpp` (839 lines) | the DDR3 mailbox client: doorbell drain, register shadow publish, MAC PROM cooking, RX pump, and the DMA-RPC that backs guest memory |
| `support/mac/mac_eth_iface.cpp` | AF_PACKET raw socket, or TUN/TAP for `tapN` |
| `support/mac/mac_eth.h` | the window layout — **the contract**, mirrored by the cores' RTL |

`mac.cpp:25` already lists `macquadra800` in the Mac family (for the SCSI/CD
layer), and `mac_eth_poll()` hangs off the same `mac_poll()` hook we already
use.

The PROM cooking is the *same* formula the Quadra wants: swizzled bytes 0-5,
zero, complemented XOR. Nothing to port there.

### MacLC core — the FPGA half, as a worked example

`../MacLC_MiSTer/rtl/pds/pds_enet.sv` (843 lines) is the Apple Ethernet LC
Twisted Pair front-end, with `verilator/tb_pds_enet.v` (488 lines) as its
bench, the SDRAM side-port pattern in its `rtl/sdram.v` (`eth_req`/`eth_ack`,
lowest priority, idle edges only), and a genuinely excellent design document at
`docs/pds_ethernet_scope.md`.

The architecture, which we would keep verbatim: **dumb, fast FPGA front-end;
chip model on the ARM; the guest never waits on host software.** Register
writes become entries in a doorbell ring in DDR3 (DTACK is held only until the
entry lands, never until the ARM runs); register reads are answered from an
ARM-maintained 64-entry shadow block; the interrupt line comes from a control
word. A dead Main cannot wedge the guest.

Read that document before writing any RTL. Three of its lessons are paid for in
other people's sessions and apply to us unchanged:

* **The odd-address class of bug.** The DMA engine moves even-addressed words;
  the SONIC legitimately uses odd addresses (an EOL link has the LSB set as a
  flag). Rejecting odd wedged the guest three different ways. The word
  alignment and read-modify-write belong in the host backend, and are already
  there (`mac_eth.cpp` `rpc_read`/`rpc_write`).
* **The ordering law.** Model-to-driver RAM sequences are the dangerous
  direction: the publish word must be the **last** access of a sequence, and
  nothing may touch the structure afterwards. The Apple driver consumes and
  recycles a descriptor the instant its status word goes nonzero.
* **The ISR-clear overlay.** The guest's view of the interrupt line lags its own
  ISR write by ~1.6 ms, which measured ~120 re-entries per real interrupt.
  The fix is local in RTL: serve ISR reads and drive IRQ as
  `shadow & ~pending_clear`, reconciled against each fresh shadow.

---

## 3. What is different here

The Quadra is a third personality: LC-like in that the chip masters guest RAM,
NuBus-like in that addresses are 32-bit, and simpler than both in its front-end.

**Simpler:** no declROM, no slot decode, no address translation. The SONIC's
addresses are plain physical RAM addresses — the LC needed a local copy of the
V8 RAM map; we need none.

**Harder:** the DMA engine must reach all of SDRAM, up to 128 MB. The mailbox's
`DMA_CMD` word packs the guest address into bits `[39:16]` — 24 bits
(`mac_eth.h:36`) — and `mac_eth.cpp` explicitly fails an RPC when
`addr_bits > 24` and the address exceeds the field. So the window layout needs
a **v4 revision with a wider address field and its own MAGIC** (say
`"McQDETH4"`), which is small on both sides but touches a header the LC and
IIvi cores share. Coordinate it with Dani rather than forking the contract.

---

## 4. Work in this core

1. **New `rtl/quadra_enet.sv`** — the front-end. 64x16 shadow register file,
   doorbell ring writer into DDR3, MAC PROM bytes from the control block, the
   ISR-clear overlay, presence latched from MAGIC at guest reset (no MAGIC =
   the decode stays off and the machine is exactly as it is today). Everything
   runs in `clk_sys`, and the top already drives `DDRAM_CLK = clk_sys`
   (`MacQuadra800.sv:877`), so there is no clock crossing — same as the LC.
2. **I/O decode** in the existing `in_low` block (`rtl/iosb.sv:491-508`):
   `sel_prom = addr[17:13] == 5'b00100` and `sel_sonic = addr[17:13] == 5'b00101`.
   Decoding on `[17:13]` rather than `[19:13]` makes the `$50F0xxxx` mirror the
   drivers use fall out for free — the same reasoning already written down for
   `sel_scsi` and `sel_scc`.
3. **Interrupt** — one line. `nubus_irqs` bit 0 becomes `~sonic_irq` instead of
   constant 1 (`rtl/iosb.sv:442`); `slot_any`'s `8'h79` mask already covers
   bit 0, and the VIA2 path from there is the one VBL already uses.
4. **DDR3 mailbox master.** The ROM-fetch state machine
   (`MacQuadra800.sv:900-970`) is the only DDR3 user today and is idle almost
   always; the ethernet window at ARM-physical `0x1FF00000` does not collide
   with our `0x30000000` RAM / `0x38000000` ROM regions. It needs a second
   requester arbitrated into that block.
5. **Guest-RAM DMA engine** — the real new engineering. The LC steals idle slots
   inside its own SDRAM controller; the clean insertion point here is the beat
   port of `sdram_beat32` (`MacQuadra800.sv:745-777`), muxing a DMA requester
   behind the machine's `mem_req`. Three coherency notes:
   - The retained 16-byte line self-invalidates on *any* write through that
     port (`rtl/sdram_beat32.sv:204-208`), so DMA writes are safe there for
     free.
   - **The 68040 data cache is not.** `rtl/wombat_cpu.sv:69` already carries the
     `snoop_stb`/`snoop_addr` port, tied off with the comment "SONIC later",
     and the CPU implements it (`rtl/ap68040/rtl/ap040_tg68k_compat.v:326`,
     `rtl/ap68040/README.md:74`). The instruction cache is not snooped, which is
     fine for packet and descriptor data.
   - `wombat_store_buffer` is the piece to think hardest about: a DMA read must
     not pass a posted CPU write to the same line.
6. **OSD.** An Ethernet on/off option, plus the interface and MAC-suffix bits
   Main reads. Careful: `mac_eth.cpp:69-70` hardcodes status bits `[37:36]` and
   `[35:32]`, which **collide with our MT32-pi options** (`P1O[35]`, `P1O[36]`,
   `P1O[38:37]` in `MacQuadra800.sv`'s CONF_STR). Either Main learns per-core
   bit strings, or this core drives it entirely from `<HomeDir>/eth.cfg` and
   skips the OSD bits.

### Work in the Main fork

Bounded, and mostly parameterisation of what is there:

* a `CARD_QD` personality with layout v4 (XFER bounce window + control block,
  no declROM window) and its own MAGIC;
* the wider DMA address field, and `addr_bits = 32` with the DMA-RPC backend
  (not the NuBus card-RAM backend);
* arming gated on the core name: `card_start()` currently refuses any non-MacLC
  core that has no `ethernet.rom` (`mac_eth.cpp:407`, and the `load_declrom()`
  failure path), which a Quadra will never have;
* its own MAC byte (the family byte is `'M'`; LC is `'L'`, IIvi is `'V'`) so two
  Mac cores on one LAN cannot collide.

### Verification

* `tb_pds_enet.v` ports over as the front-end bench (register windows, ring,
  shadows, ISR overlay, presence).
* A new bench for the DMA engine against the real `sdram.sv` — the LC did
  exactly this as its Phase 3, and `tb_sdram` must stay at zero protocol
  errors.
* MAME `macqd800` as the register/DMA oracle: trace what Apple's driver
  actually does — the DCR mode, whether it ever touches the `+0` half of a
  register longword, and the reset sequence.
* Remember the coverage gap: the full-machine Verilator sim instantiates
  `quadra800`, not `emu`, so the DDR3 mailbox wiring is hardware-only. That is
  the same class of gap that hid the CD-strobe-on-the-wrong-slot bug.

---

## 5. The blocker to weigh first: area

The LC's v1 front-end measured **441 ALMs / 732 registers / 0 M10K / 0 DSP**;
v2 added the DMA engine and wider shadows. Call it **700-1,000 ALMs** here,
with the DMA engine and a 32-bit address path and no declROM logic.

The shipped release sits at **98 % of the 5CSEBA6's 41,910 ALMs** — about
**840 free**. On the release recipe this does not fit. Options, in order of
preference:

* **Put the 64x16 shadow block in M10K** instead of registers. The LC chose
  registers deliberately, but our pressure is LUT logic, not memory (477/553
  RAM blocks, 76 free). Re-read the RAM Summary in the `.map.rpt` afterwards,
  and re-run the `clk_ram` / `clk_sys`-to-`clk_ram` path reports
  (`docs/sdram-open-row-crossing.md`) before trusting the build.
* **Build it behind a switch**, the way `CDROM_OFF` works, so an experiment
  build and a release build can differ while it is being brought up.
* **Trade a lever:** `MISTER_DISABLE_YC` (458 cells) plus `VIDEO_512_OFF` (300)
  gets most of the way, at the cost of composite output the user actually uses.
  The 3,000-ALM CD-ROM lever is not available to a release — users install from
  CD.
* **Land it after the CPU area work.** The `profile-speedometer402` branch's
  local build fits in 95 % (39,984 / 41,910), which is roughly what a build
  with Ethernet would look like if that work holds.

Every netlist change here is a seed walk, and the release gate is both guests
booting to a responsive desktop and shutting down cleanly.

---

## 6. Suggested order

| phase | work | gate |
|---|---|---|
| 1 | This doc hardened into a contract: the v4 window layout, mirrored into `mac_eth.h`; MAME register trace of the real driver | agreement with the LC/IIvi maintainer on the shared header |
| 2 | RTL front-end + `iosb` decode + IRQ + bench | `build_only.sh --check` for the real area number, before anything else is built on it |
| 3 | SDRAM DMA engine + CPU snoop + its own bench | `tb_sdram` at zero errors; Speedometer unchanged with Ethernet off (the engine must be provably inert, netlist-level) |
| 4 | Main: `CARD_QD`, v4 mailbox, 32-bit DMA, config | host-side unit test off-box, as `mac_sonic` already supports |
| 5 | Hardware bring-up | driver opens, AppleTalk zones in the Chooser, MacTCP ping, FTP soak; then A/UX; then the full release regression gate |

Phases 1-4 are mostly porting, not invention. The genuinely new engineering is
the SDRAM DMA port with its coherency, and the area.

Two things to decide before starting: whether Ethernet may displace a release
feature for area, and whether the v4 layout goes upstream into the shared
`mac_eth.h` or forks.
