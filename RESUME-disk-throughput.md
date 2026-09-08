# Disk throughput: the HPS round trip is the bottleneck

Paste this file as the opening message of a new session. Repo on
`cpu-sdram-handoff-seed15` through `b3b8480`. This is an analysis + ranked
work queue, not a rescue — nothing is broken, the disk path is *correct*,
it is just paying a round trip per 512 bytes.

**Binding rule (unchanged):** never load a core while the guest is booting or
running. Shut the guest down first (`scripts/guest/shutdown.sh`).

**Scope note.** Sections 1–3 are read off the RTL, off Main_MiSTer's
`user_io.cpp`, and off our own Speedometer corpus. Section 3's *absolute*
timings are derived from access counts, **not measured on hardware** — see
§8 for what to measure before trusting them. The structural claims (one round
trip per sector, zero overlap) are read directly from the code and are solid.

## 1. The finding

Disk is the only subsystem that has not moved in the entire optimization
campaign. From `docs/PERFORMANCE_MEASUREMENTS.md`, first recorded round to
last:

| Speedometer PR test | first | last | change |
|---|---:|---:|---:|
| CPU | 2.661 | 5.195 | **+95%** |
| Math | 15.841 | 34.011 | **+115%** |
| Disk | 0.671 | 0.680 | **+1.3%** |

Across ~25 measurement rounds Disk never leaves the 0.676–0.698 band. It does
not respond to the related-clock handoff, the SDRAM fast path, the store
buffer, the instruction lookahead, or any of the decode work. Whatever gates
it is outside the CPU and outside the memory system.

It is the HPS block-device round trip.

## 2. How the path actually works

### FPGA side

`wombat33.sv:132` — the transport is already configured well:

```verilog
hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .VDNUM(1), .BLKSZ(2)) hps_io
```

`WIDE(1)` puts us on the 16-bit `sd_buff` path (one HPS register write per
byte instead of two). `BLKSZ(2)` = 512-byte blocks. Nothing to win here — this
is already the good configuration. (For contrast, cores that leave `WIDE` at
its default 0 are paying 2x on the wire for nothing.)

`wombat33.sv:164` — and here is the first problem:

```verilog
.sd_blk_cnt('{6'd0}),
```

Hardwired to zero, so every HPS transaction moves exactly one block. `hps_io`
supports up to 32 blocks per request at `BLKSZ=2` — the constraint from
`sys/hps_io.sv:134` is
`(sd_blk_cnt+1) * (1 << (BLKSZ+7)) <= 16384`.

`rtl/ncr53c96.sv:457-465` — and the second, which is the bigger one. The
comment says "block prefetch"; the code is a demand fetch:

```verilog
//---------------------------------------------------- block prefetch
// data-in: fetch the next sector whenever the current one is spent
if (phase == PH_DIN && data_dir_in && blocks_left != 0 &&
    !io_busy && (!buf_valid || sbuf_pos >= sbuf_len)) begin
        buf_valid <= 0;
        io_lba <= lba;
        lba <= lba + 1'b1;
        blocks_left <= blocks_left - 1'b1;
        io_rd <= 1;
end
```

The next request only fires once the current sector is **fully drained**
(`sbuf_pos >= sbuf_len`). The sector buffer is one sector — `rtl/ncr53c96.sv:927`,
`numwords 256` x 16 bits = 512 bytes — so there is nowhere to prefetch *to*
even if we wanted to.

Net effect, strictly alternating dead time with zero overlap:

```
core asserts io_rd ──▶ [HPS idles until its next poll pass] ──▶ 512B transfer
                                                                     │
       ◀── [HPS idles waiting for the guest] ◀── ROM drains 32x TC=16 bursts
```

Neither side ever does work while the other is doing work.

### HPS side (Main_MiSTer, `~/Documents/development/Main_MiSTer`)

`user_io.cpp:3193` — `user_io_poll()` runs a 4-iteration loop issuing
`UIO_GET_SDSTAT` (0x16). `hps_io.sv:329` answers with
`{1'b1, sd_blk_cnt[sdn], BLKSZ[2:0], sdn, sd_wr[sdn], sd_rd[sdn]}`, and Main
decodes at `user_io.cpp:3206-3218`. Two more words carry the 32-bit LBA.

The payload then goes out via `spi_block_write(...)` → `fpga_spi_fast_block_write`
(`fpga_io.cpp:732`). Despite the name there is no SPI peripheral: it bit-bangs
the Cyclone V FPGA Manager's `gpo`/`gpi` registers
(`fpga_io.cpp:517-519`), two uncached register writes per 16-bit word, with
**no ACK handshake at all** in the fast path — it relies on the HPS register
write being inherently slower than `clk_sys` sampling.

**Main needs no changes for any of this work.** Its read-ahead cache is already
sized for exactly what we want: `UIO_BUFFER_SIZE 16384` (`user_io.h:167`),
`buf_n = 16384/512 = 32` (`user_io.cpp:3355`). A 32-block request maps onto one
cache fill, and `user_io.cpp:3462-3480` already background-prefetches the next
16 KB when a request consumes the current one. Our 512-byte requests are using
about 3% of a mechanism built for this.

## 3. Where the time goes

Per 512 bytes, three terms:

1. **HPS notice latency** — up to one full Main_MiSTer main-loop pass
   (`user_io_poll` → `frame_timer` → `input_poll` → `HandleUI` → `OsdUpdate`;
   `scheduler.cpp:26-53` alternates the poll coroutine with the UI coroutine).
   `SPIKE_SCOPE("co_poll", 1000)` says the expected budget is 1 ms.
   **This is the dominant term.**
2. **The transfer** — 256 words x 2 register writes. Tens of microseconds.
   The *small* term. Raw wire bandwidth is not the problem.
3. **Guest drain** — the ROM's non-blind read issues 32 separate `$90`
   commands with TC=16 (`docs/scsi/rom-driver-scsi-access-patterns.md:333`),
   each gated on STATUS bit 4 + DREQ + FIFO-flags bit 4.

Term 2 is why "make the SPI faster" is the wrong instinct. Terms 1 and 3 are
both round-trip costs, and term 1 is entirely ours to fix.

Multiplier available: `blocks_left <= {16'd0, cdb[7], cdb[8]}`
(`rtl/ncr53c96.sv:830`) — Apple_Driver43's READ(10)s ask for many blocks at a
time. Today every single one pays term 1 separately.

## 4. Fix 1 — multi-block requests

Biggest win, mostly mechanical, no Main_MiSTer changes.

| File | Line | Change |
|---|---|---|
| `wombat33.sv` | 164 | Drive `.sd_blk_cnt` from the core: `min(blocks_left, 32) - 1` |
| `wombat33.sv` | 377 | `.sd_buff_addr(sd_buff_addr[7:0])` → pass all 13 bits |
| `rtl/ncr53c96.sv` | 927-935 | altsyncram defparams: `numwords_a/b 256 → 8192`, `widthad_a/b 8 → 13` |
| `rtl/ncr53c96.sv` | 125-126 | `sbuf_len` / `sbuf_pos` `[9:0]` → `[13:0]` |
| `rtl/ncr53c96.sv` | 320, 372 | `addr_e` / `sbuf_rd_ok`: `sbuf_pos[8:1]` → `sbuf_pos[13:1]` |
| `rtl/ncr53c96.sv` | 450 | `sbuf_len <= 10'd512` → `blks << 9` |
| `rtl/ncr53c96.sv` | 265, 565, 580 | the `10'd512` literals in the flush path become the same length |

`sd_buff_addr` is already declared `[12:0]` at `wombat33.sv:123` and `hps_io`
already drives all of it (`localparam AW = (WIDE) ? 12 : 13`) — we are just
throwing away the top 5 bits today.

**Clamping matters.** Never request more blocks than `blocks_left`. On reads
over-requesting is merely wasteful; on writes it would push data past the CDB's
range and corrupt the image.

**Reads first.** The write path (`rtl/ncr53c96.sv:565-591`) needs its flush
logic reworked to accumulate N sectors and handle trailing partials, and writes
are not what the Speedometer Disk test or a boot is dominated by.

Expected: up to **32x fewer round trips** on term 1. If Apple_Driver43 asks for
8 blocks, we get 8x; if it asks for 32+, we get the full 32x.

RAM cost: 8192 x 16 = 131,072 bits ≈ 13 M10K. Block memory 55% → ~57%.

## 5. Fix 2 — ping-pong the sector buffer

Even at 16 KB we still stall at every buffer boundary. Issue the next request
when the current buffer is **published** rather than when it is spent, into an
alternate buffer.

`io_busy` (`rtl/ncr53c96.sv:144`) already serializes the requests correctly —
`hps_io` allows only one outstanding request per virtual drive and that does not
change. What we need is per-buffer valid flags and a buffer-select on
`sd_buff_addr`'s MSB, so request N+1's HPS round trip overlaps buffer N's drain.

This is what actually kills term 1: after Fix 1 the round trip is amortized over
16 KB, and after Fix 2 it is hidden behind the guest's drain of the previous
16 KB.

RAM cost: 2 x 16 KB = 256 Kbit ≈ 26 M10K. Block memory 55% → ~60%.

## 6. Fix 3 — DDR sector window (deferred; only if 1+2 fall short)

We already have a DDRAM master. `wombat33.sv:685-700` drives it for ROM at
`DDR_ROM_BASE = 29'h0700_0000` (byte `0x38000000`), and
`DDR_RAM_BASE = 29'h0600_0000` (byte `0x30000000`) is declared at
`wombat33.sv:687` but **never referenced** — RAM lives in SDRAM now. That
window is free, and DDR traffic in this core is ROM-only.

The model is Saturn CDD, not C64. In `Main_MiSTer/support/saturn/saturncdd.cpp:1271-1313`
the HPS writes CD sectors into four 4 KB DDR buffers and only a **2-byte**
mode/index word crosses the SPI link. That is the shape to copy: keep `hps_io`
for control (mount, LBA request, completion) and move the payload to DDR.

The C64 trick — whole image resident in DDR, core fetches tracks directly
(`Main_MiSTer/support/c64/c64.cpp:421-439`, worth reading for the rationale
comment) — does **not** transfer here. G64 images are a few hundred KB; Quadra
disk images are hundreds of MB against a 512 MB FPGA-visible window shared with
the scaler.

Cost: a custom `support/` module in Main_MiSTer plus a real DDR arbiter in the
core (today's `always @(posedge clk_sys)` block at `wombat33.sv:708` assumes a
single requester). Do not start here.

## 7. Not the place to start — blind mode

The ROM's blind path (`$408D228E` read / `$408D216C` write) would cut term 3
substantially: one `$90` with TC=512 and no polling, instead of 32 polled TC=16
bursts (`docs/scsi/rom-driver-scsi-access-patterns.md:197`, `:333`).

But `docs/scsi/rtl-gap-analysis.md:105-113` is explicit that the blind path does
raw unrolled `move.l` with no polling and *relies* on a bus error plus the ROM's
handler at `$408D2606`, which reads the IOSB `$50F18300` fault-status /
`$50F18400` data-latch pair. **That pair is not implemented.** Exercising blind
mode without it is a hang.

It also addresses term 3, which is orthogonal to the HPS stall. Fixes 1 and 2
are strictly better value per unit of risk.

## 8. What to measure first

Everything in §3's absolute timings is derived from access counts, not measured.
Before committing to the work, get two numbers:

1. **Main-loop period on hardware while the guest is doing sustained disk I/O.**
   `PROFILING` / `SPIKE_SCOPE` is already wired into `user_io_poll` and
   `scheduler_co_poll`. This tells us how big term 1 actually is.
2. **Round trips per second**, from a JTAG counter on `io_rd` rising edges
   during a Speedometer Disk run. Multiply by 512 to get today's effective
   throughput, and compare against what Fix 1's block count would predict.

If term 1 turns out to be far smaller than the 1 ms budget suggests, term 3
(the guest drain) is the real gate and §7 moves up the queue despite its risk.
Measure before building.

## 9. Area budget — the real constraint

`output_files/wombat33.fit.summary`:

```
Logic utilization (in ALMs)  : 36,525 / 41,910 ( 87 % )
Total block memory bits      : 3,135,384 / 5,662,720 ( 55 % )
```

Block memory is plentiful; **ALMs at 87% are the concern**, and
`CPU_AREA_HANDOFF.md` is already tracking that pressure.

Both fixes are M10K-heavy and ALM-light — wider counters and an address bus,
call it 50-150 ALMs — so they should fit. But run a fit check after Fix 1 before
committing to Fix 2's ping-pong, and note that the 5-bit widening of `sbuf_pos`
touches comparison chains (`byte_avail`, `sbuf_rd_ok`, the flush predicates)
that sit on the FIFO engine's critical path.

## 10. Queue

1. **Fix 1, read path only.** Verify in the Verilator full-machine bench
   first (`verilator/sim_main.cpp` + `verilator/sim/sim_blkdevice.cpp`; the
   disk-boot gate from `RESUME-disk-gate.md` is the regression that matters
   here). Then a fit check, then hardware, then a Speedometer Disk run.
2. **Measure** (§8) — ideally before step 1, definitely before step 3.
3. **Fix 1, write path.** Flush logic rework, trailing partials.
4. **Fix 2, ping-pong.** Only with ALM headroom confirmed.
5. **Fix 3 / blind mode.** Only if 1-4 leave Disk short and the measurements
   in §8 say which of the two terms is left.

One caution specific to this area: `rtl/ncr53c96.sv:339-359` documents the
16-bit `sd_buff` byte-packing difference between real hardware
(little-endian, disk byte 0 in `sd_buff_dout[7:0]`) and
`verilator/sim/sim_blkdevice.cpp` (big-endian). Getting it wrong swaps every byte
pair, is **invisible in sim**, and is fatal on hardware. Any change to the
buffer's width, addressing, or length handling must be re-checked against that
comment before it goes to the FPGA.
