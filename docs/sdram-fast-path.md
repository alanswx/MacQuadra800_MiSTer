# SDRAM fast path — posting, burst capture and related-clock handoff

**Status:** posted writes and burst capture landed; the related-clock handoff
is hardware-validated in the current worktree. `rtl/sdram_beat32.sv`,
`rtl/sdram.sv`, `wombat33.sv`, `verilator/tb_sdram.sv`. Stages 1a–1c of the
CPU-speed plan; the cycle analysis behind them is
`docs/sdram-vram-sharing.md` §2 and §6.

The emulated machine runs the authentic 33 MHz bus clock, but its memory
delivered 16.5 MB/s where a real Quadra 800 does 50–65 MB/s. Under a
write-through cache with no write buffer that gap is paid on *every store* and
*every miss*. Three changes, all entirely on the platform side of the beat port
— nothing in `rtl/ap68040`, nothing in the cache — take the first bite.

---

## 1. What changed

**Posted RAM writes.** The bridge captures a write, acks the beat immediately,
and drains to the controller behind the machine's back. Nothing downstream had
to change: the whole stall chain — bridge, `wombat_bus32`, the cache's
write-through `C_PASS`, the core — is ack-based, so releasing the ack releases
all of it. Ordering is free, because the next beat (read or write) still waits
on `busy`; a read that follows a posted write cannot start until the write has
been issued to the chip. This hides write *latency*; it does not add
bandwidth, so a sustained store stream still drains at the controller's rate.

**One row cycle per read, not two.** The controller's mode register already
programs `BURST_LENGTH=4`, so every READ returns four words — the old bridge
discarded all four but the first and then paid a second full
ACT → RD → auto-precharge cycle for a word the chip had already handed it. A
32-bit beat's two halves are a 4-byte-aligned pair, so they are always words 0
and 1 of one burst: issue once, latch both. No command timing changes at all,
which is what makes this safe. Writes still take two accesses —
`NO_WRITE_BURST=1` in the mode register.

One wrinkle worth knowing: the read must drop `rd` a cycle early (`rd2`). The
controller is back in `STATE_IDLE` the cycle after burst word 1 lands, and a
still-asserted `rd` there reads as a fresh request for the same address.

**Timed half-cycle handoff.** `clk_sys` and `clk_ram` are not asynchronous:
they are phase-aligned 33/99 MHz outputs of the same PLL. The original bridge
still paid for a two-flop toggle synchroniser in each direction. The revised
bridge samples requests and completions on the falling edge of `clk_ram`,
halfway between its controller edges; the payload stays registered with the
toggle. TimeQuest therefore checks the crossings as ordinary half-cycle paths
instead of relying on an asynchronous exception.

Two supporting changes, neither of them behavioural:

- `sdram.sv` drives DQ from a registered value behind an explicit output
  enable instead of assigning `'Z` inside the state machine. Same one-cycle
  drive window, same inferred bidir buffer — but a continuous assignment is a
  tristate form Verilator can elaborate, which is what lets the testbench run
  the real controller.
- `sdram.sv`'s block-local statics (`state`, `data_ready_delay`, `cas_addr`, …)
  moved to module scope. As block-locals **with initialisers** they were both
  blocking- and non-blocking-assigned, which Verilator calls unsupported — and
  waiving the warning does not make it work, it silently stops executing the
  whole always block the moment startup finishes. (Cost an hour to find; it
  looks exactly like a hung handshake.) Identical for synthesis, and it makes
  the state machine visible to a waveform viewer.

## 2. Measured

`verilator/tb_sdram.sv` drives the beat port against a behavioural SDR SDRAM
model — bank/row state, CAS latency, sequential bursts, auto-precharge, write
byte masking, refresh. Same testbench both times; the "before" column is the
old bridge behaviour restored in a scratch copy.

| | original bridge | posted + burst | + related-clock handoff |
|---|---|---|---|
| isolated read beat | 9 clk_sys, 272 ns | 7 clk_sys, 212 ns | **5 clk_sys, 151 ns** |
| isolated write beat | 8 clk_sys, 242 ns | **1 clk_sys, 30 ns** | **1 clk_sys, 30 ns** |
| 64 sequential reads | 13.1 MB/s | 16.4 MB/s | **22.0 MB/s** |
| 64 sequential writes, to drained | 14.6 MB/s | 16.4 MB/s | **21.7 MB/s** |

The isolated store is the number that matters most for felt speed:
write-through means the CPU pays it on every single store, and it drops by 8×.
The handoff then removes two more bus clocks from every read and raises the
drained streaming rate by another 34%.

The chip model also reports what the controller does to the part, and it is
unchanged by any of this: min ACT→ACT same bank 7 cycles (70.7 ns), tRCD 2,
PRE→ACT 4, refresh every ≤773 cycles.

## 3. What this says about the next stage

The related-clock handoff is now done: a read beat is 151 ns and the sequential
test delivers 22.0 MB/s. That is close to the real Quadra 800's single-access
latency, but still less than half its 50–65 MB/s sequential bandwidth. The
remaining platform bottleneck is the controller's mandatory
activate → access → auto-precharge row cycle on every beat. Page mode is now
the clear next stage.

Deliberately not done here:

- **Page-mode scheduler** (`sdram.sv`, plan §1d) — the structural prerequisite
  for real-Quadra bandwidth. `tb_sdram.sv` exists partly to make it tractable:
  the chip model already checks the timing parameters a row-open scheduler has
  to respect. Still the riskiest platform item.
- **Line-fill burst hint** (§1e) — needs `fill_active` out of `ap040_cache`,
  which is in the `rtl/ap68040` submodule.
- **Perf counters** (§4 stage 0) — the plan puts them in `debug_status`, which
  is the core's bus, and there is no readout path for platform counters today:
  `m_debug_status` in `wombat33.sv` goes nowhere, and the Verilator GUI sim
  builds `sim.v`, not `wombat33.sv`. Counters would be write-only. Giving them
  a home (an ioctl upload channel, or a debug window the guest can read) is the
  prerequisite, not the counters themselves.

The handoff was checked beyond simulation: seed 15 closes overall setup at
**+0.270 ns** and hold at **+0.241 ns**. Targeted TimeQuest reports put every
new crossing above +1.35 ns setup and +3.19 ns hold. On the same Speedometer
3.23 disk as the posted-write control, its PR CPU score rose from 2.661 to
**2.917** (+9.6%). Those PR scores are a different scale from the Speedometer
4.02 Benchmark Mix in `docs/PERFORMANCE_MEASUREMENTS.md` and must not be mixed.

### Page-mode prototype result

An isolated row-open controller prototype was run against this same chip model
after the handoff work. It passed the existing 33 functional checks and
reported **121 ns isolated reads, 26.1 MB/s sequential reads and 32.4 MB/s
drained writes**. Capturing burst words 2/3 as a one-beat read-ahead entry
raised sequential reads to **37.5 MB/s**.

That prototype is deliberately not in the worktree: its copy port still needs
directed coverage and its observed four-cycle ACT→PRE case needs resolving
against the module's tRAS grade before hardware. More importantly, it disproves
the old assumption that page mode by itself reaches 50–65 MB/s. Once rows stay
open, the bottleneck moves to the serialized one-request/one-ack beat contract.
Reaching real-Quadra bandwidth needs a complete 16-byte line path: expose the
cache's `fill_active` hint and pipeline four beats in the controller, or build a
coherent full-line read-ahead buffer. The one-beat BL=4 tail cache is useful but
cannot remove enough request/ack bubbles on its own.

## 4. Re-running the test

```
cd verilator && make tb_sdram
```

Seconds, no ROM and no disk needed. It checks the halfword order in the chip's
own array (a swap would still round-trip through the bridge, which writes in
the same order it reads), all sixteen byte-enable masks, read-after-posted-write
ordering, all four banks, survival across auto-refresh, and a 64-deep
sequential stream — then prints the latency and bandwidth table above.
