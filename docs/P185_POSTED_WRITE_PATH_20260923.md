# P185/P186: the posted-write path -- a write FIFO in the SDRAM bridge, stores pushed straight into it, and a back-to-back store-buffer drain

## Why: on hardware, Whetstone is bound by store drain

P182 measured Mix 1.467 on the MiSTer: Dhrystone, Towers and Quick moved as the kernel fixtures
predicted, but Whetstone stayed flat (+0.2 %) where the fixture predicted -3.4 %.  The Whetstone
fixture with a separate write latency (`scratch/p184_merge/tb_cpu_whetstone_wl.sv`, `+wlatency=`):

| Whetstone loop (P184) | writes latency 3 | writes latency 8 |
|---|---:|---:|
| reads latency 3 | 23,830,068 | 33,067,316 |
| reads latency 8 | 23,934,415 | 33,171,649 |

Read latency is +0.4 %; write latency is +39 %.  With the data cache write-through (a real Quadra
800 runs its 68040 data cache copyback), every one of Whetstone's ~2.4M stores per loop -- the SANE
glue copying 10-byte operands to and from the stack -- drains to SDRAM, and the P174->P182 hardware
delta matches the fixture only at the higher write latency (-0.3 % at latency 8).

`verilator/tb_memory_path.sv` (bridge + controller + chip model, the machine's service FSM
modelled) put a store at **6 clk_sys**: sequential and row-scattered alike, so it was handshake, not
SDRAM row cycles.  A store went store buffer -> wombat_bus32 -> service FSM `S_IDLE` (registers
`mem_req`) -> `S_MEM` -> the bridge (captures, acknowledges) -> `S_MEM`'s registered `b_ack` ->
wombat_bus32 -> the store buffer, which then idled a clock before presenting the next.  Behind that,
the bridge held `busy` through its own drain: request toggle across, two 16-bit controller WRITEs,
completion toggle back (~18 clk_ram).

## P185: the write FIFO and the push port

- `rtl/sdram_beat32.sv`: posted writes enter a four-entry FIFO on clk_sys (acknowledged there);
  clk_ram drains it back to back and returns its read pointer through the falling-edge handoff the
  toggles already use.  A read starts only when the FIFO is empty (clk_sys), and clk_ram also drains
  queued writes before it takes a read.  `busy` keeps its contract (a read in flight or a write not
  yet in the chip).  A registered push port (`wp_valid/addr/be/data`, `wq_room` = two or more free
  slots) accepts a write per cycle with no handshake; a push drops the retained line, and a push
  during a line fill keeps that fill's line from becoming valid (`fill_poisoned`).
  tb_sdram: 64 sequential writes to drained 32.4 -> 53.8 MB/s, 45/45 checks, 0 chip protocol errors.
- `rtl/quadra800.sv` (`DIRECT_WRITES`, default 1): in `S_IDLE`, a store-buffer RAM write inside one
  longword (`bus_wr_direct`: the read first-miss eligibility with `bus_write`, the transfer's lanes
  from wombat_bus32's formula, `mem_wq_room`) is registered onto the push port and acknowledged next
  clock through `bus_miss_ack` -- no wombat_bus32 beat, no `S_MEM`.  `bus_req_adapter` excludes it,
  as it excludes the read first miss.  `MacQuadra800.sv` wires it to the bridge; `verilator/sim.v`
  writes pushes into its RAM array (always room).
- `verilator/tb_line_dma.sv` carries the new arm verbatim (`DW`), wires the push port, adds sized
  stores (bytes and words at every offset, three to a line, then the line read back at once) and
  counts pushes: 0 errors against SONIC DMA and parked I/O beats with 8,220 direct pushes.  Negative
  control: without the push's retained-line invalidation the sized read-backs fail immediately.
  4,096 back-to-back stores: **24,576 -> 9,720 clk_sys** (6.0 -> 2.4 a store).

## P186: the store buffer drains back to back

`rtl/wombat_store_buffer.sv`: on an acknowledge with another write queued behind it, `drain_active`
stays up and the next entry is presented in the next clock (the post-cache contract every consumer
already honours), unless exactly one write would remain and a read is waiting (the pass-one-store
rule keeps its turn).  (`verilator/tb_wombat_store_buffer.sv` is stale: it predates the four-entry
queue and fails the same nine checks on the unmodified RTL.)

Fixtures on P184 + P186 (latency 3): Whetstone 23,830,068 -> 22,784,496 (-4.4 %), Permutations
(lat 3) -4.2 %, Queens -3.0 %, Towers -2.7 %, Quick -1.8 %, Dhrystone -0.6 %; all oracles, controls
and the AP68040 self-tests pass.

## Projection

Hardware stores behaved like fixture write latency ~5 (6 clk_sys + the store buffer's gap); with
P185 + P186 they behave like ~1.  Whetstone at reads 5 / writes 5 with the old store buffer
27,042,107 -> reads 5 / writes 1 with P186 22,445,865: **-17 %**.
