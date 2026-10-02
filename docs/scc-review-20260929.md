# Quadra 800 Core — SCC (Z8530) Review

A read-only review of the serial chip in `MacQuadra800_MiSTer` (build host copy at
commit `c5a157b`), made while debugging StyleWriter printing, with a comparison
to the Apple IIgs core's SCC. **No files in the Quadra tree were changed.**

Reviewed: `rtl/scc.v` (2,012 lines), the SCC instance and bus glue in
`rtl/iosb.sv`, and `rtl/uart/rxuart.v`.

## Summary

| # | Finding | Severity | Affects IIgs too? |
|---|---|---|---|
| 1 | 33 MHz is hard-coded in `iosb.sv` (SCC baud, VIA timers, ADB) | **High if the `iosb` clock changes** | n/a |
| 2 | About 15 register blocks use a combinationally decoded asynchronous reset | Medium (glitch/timing risk) | yes |
| 3 | 1200 baud and 600 baud are broken by "self-test" special cases | Medium (real-world serial use) | yes |
| 4 | RTxC clocking isn't modeled (BRG off → fixed 9600) | Low (no current software needs it) | yes |
| 5 | Tx interrupt / Tx Empty assert at end of character, not buffer-empty | Low (throughput only) | yes |
| 6 | RR0 Zero Count bit is hard-wired to 0 | Low | no (IIgs implements it) |

Things the Quadra SCC already gets right are listed in the
[section at the end](#what-the-quadra-scc-already-does-well). Several are worth
backporting to the IIgs.

---

## 1. Hard-coded 33 MHz in `iosb.sv`

`iosb.sv` assumes its `clk` is exactly 33 MHz in several places:

| Where | Constant | What depends on it |
|---|---|---|
| `iosb.sv:1034` | `scc #(.SYS_CLK_HZ(33_000_000))` | every SCC baud rate (BRG ratio, 9600 fallback, virtual TRxC) |
| `iosb.sv:18` | `E_HALF = 21` ("33 MHz/21 ≈ 783.4 kHz") | VIA 6522 E clock, so all VIA timers (tick, sound, ADB timing) |
| `iosb.sv:286` | `SHIFT_DELAY = 22'd100000` ("~3 ms at 33 MHz") | ADB transceiver timing |
| `iosb.sv:625` | `DBG_BAUD_DIV = 33_000_000 / 115200` | debug UART |

**Why it matters for the speed-up:** if the speed-up raises the clock that
feeds `iosb` (instead of only the CPU or its clock enable), all of these drift
by the same factor. The result would be wrong serial baud rates (framing
errors), fast VIA timers (wrong ticks and sound pitch, timeouts) and broken ADB
timing.

**Recommendation:** keep `iosb` on a fixed 33 MHz domain, or derive these
constants from one shared `IOSB_CLK_HZ` parameter.

The SCC's register interface enables (`scc_cep`/`scc_cen`, `iosb.sv:1020–1030`)
are `clk/4` gated by `ce`, so they scale with `ce`. The bus access state machine
(`A_SCC_ACC` → `A_SCC_REL`, both waiting on `scc_cen`) always releases
chip-select between accesses. That's required, because the SCC processes only
one access per chip-select assertion (`cs_access_done`), so a faster CPU is fine
there.

## 2. Combinationally decoded asynchronous reset

`scc.v:589–593`:

```verilog
assign reset   = ((wreg_a | wreg_b) & (rindex_latch == 9) & (wdata[7:6] == 2'b11)) | reset_hw;
assign reset_a = ((wreg_a | wreg_b) & (rindex_latch == 9) & ((wdata[7:6] == 2'b10) | ...)) | reset;
assign reset_b = ...;
```

These nets are decoded straight from bus signals (`cs`, `we`, `rs`, `wdata`,
the register pointer), and they drive **asynchronous** resets:

```
scc.v:741, 751, 861, 976, 1001, 1357, 1367, 1379, 1389,
      1401 (reset | reset_a), 1415 (reset | reset_b), 1433, 1455, 1478, 1511
    always @(posedge clk or posedge reset) ...
```

(WR10 A/B, the ext/status latches, the zero-count logic, the latch-open
control, the DCD/CTS latches, EOM, and the TX-empty latches.)

**Risk:** a glitch on any of those bus signals during an SCC write can
asynchronously reset part of the chip. Async reset paths are also awkward for
timing closure (recovery/removal), and that gets worse as timing tightens with
a speed-up. Most register blocks were already moved to the clean `reset_hw`
(lines 609–818).

**Recommendation:** convert the remaining blocks to use `reset_hw` as the async
reset, and apply the WR9 software resets (`reset`/`reset_a`/`reset_b`)
**synchronously**, qualified by `cen`, like the WR registers already do.

## 3. 1200 and 600 baud are broken by self-test special cases

`scc.v:1649–1667` (channel A) and `1837–1846` (channel B):

```verilog
if (wr13_a == 8'h00 && wr12_a == 8'h5E && (wr4_a == 8'h44 || wr4_a == 8'h4C))
    baud_divid_speed_a <= 24'd4;      // "ROM selftest": ~4 clocks per bit
else if (wr13_a == 8'h00 && wr12_a == 8'hBE && wr4_a == 8'h4C)
    baud_divid_speed_a <= 24'd100;    // "diagnostic disk loopback"
```

Those register values are ordinary baud settings. The time constant is
`TC = RTxC / (2 × 16 × baud) − 2`:

| Baud | TC @ 3.6864 MHz | TC @ 3.672 MHz |
|---|---|---|
| 1200 | **94 = `$5E`** | 93.6 → `$5E` |
| 600 | **190 = `$BE`** | 189.2 → `$BE` |

`WR4 = $44` is x16, 1 stop bit, no parity (8N1); `$4C` is x16, 2 stop bits. So
**any software using 1200 baud 8N1/8N2 or 600 baud 8N2** (modems, terminal
programs, some printers and plotters) gets a line running at about 4 clocks per
bit, which is pure garbage on the wire.

**Recommendation:** remove the special cases, or gate them behind a simulation
define or a "self-test mode" signal. If the ROM self-test really needs fast
serial, the loopback test can be satisfied without changing the real baud rate.
For example, when WR14 local loopback is on, deliver loopback bytes instantly.

The IIgs core (`rtl/scc8530.v:1452–1460`, `1623–1627`) has the same code and
the same bug.

## 4. RTxC clocking isn't modeled

`scc.v:1620–1690`: with the BRG disabled (`WR14[0] = 0`) the channel falls back
to a fixed 9600-baud divider (`CPB_9600`), whatever WR11 selects. A real SCC
would clock from the RTxC pin (3.6864 MHz ÷ the WR4 clock mode: x16 = 230,400,
x32 = 115,200, x64 = 57,600).

**Impact today:** none found. The 68k Color StyleWriter driver runs at 57,600 via
the BRG (TC = 0, x16), which the core computes correctly. Mac OS 8.1's private
Serial Driver fast mode (`'JF'`: WR11 = `$00`, WR14 = `$00`, 230.4 kbaud) is
only reached from PowerPC code (see
[stylewriter_driver_map.md](stylewriter_driver_map.md)). The unused
`rtxc_en` input and `SCC_USE_RTXC` define are already there for this.

## 5. Tx interrupt and Tx Empty assert at end of character

`scc.v:1198–1240` (and the TX-empty latch at ~1480): `tx_int_latch` and
`tx_empty_latch` set when the transmit shifter goes idle (`tx_busy` 1 → 0). On
a real Z8530, **Tx Buffer Empty** (RR0 bit 2, and the TxIP interrupt) asserts
as soon as the byte moves from the transmit buffer into the shift register. The
CPU can then load the next byte while the current one is still shifting, and
characters go out back to back.

**Impact:** it's functionally correct, but interrupt-driven and polled transmit
leave an idle gap after every character, so throughput is below the line rate.
The IIgs has the same behavior.

## 6. RR0 Zero Count is always 0

`scc.v:1048`: RR0 bit 1 (Zero Count) is hard-wired to 0, and the zero-count
ext/status interrupt isn't generated from the BRG. The IIgs core implements a
BRG down-counter for this, because its ROM diagnostics wait for zero-count
interrupts. No Mac OS dependency is known, but Mac diagnostics could care.

---

## What the Quadra SCC already does well

- **Register-pointer protocol:** a WR0 write that selects register 0 stays in
  READY state (`scc.v:457–466`). The IIgs core just received the same fix; its
  absence hung GS/OS printing there.
- **One access per chip-select** (`cs_access_done`), so a long chip-select
  window can't be processed twice.
- **Deferred pointer reset and FIFO pop:** the register pointer and the RX FIFO
  are only updated after chip-select drops (`pending_cleanup_*`,
  `pending_dequeue_*`), following MAME. The CPU therefore always samples the
  register it addressed, and FIFO reads aren't off by one.
- **Live CTS/DCD** in RR0, with latches, plus sync/hunt status in synchronous
  mode. The IIgs hard-codes CTS = 1.
- **`SYS_CLK_HZ`-derived baud constants** instead of magic numbers.
- **Receive input synchronized** through three flip-flops (`rxuart.v:159–168`).

**Worth backporting to the IIgs core** (only if it shows FIFO or read-timing
problems): the one-access-per-chip-select gating and the deferred FIFO
pop and pointer reset.
