# SDRAM posted-write queue in MLAB

The eight-entry SDRAM posted-write FIFO stores 25 address bits, 32 data bits
and four byte enables per entry. The register-array implementation required
488 payload registers and an asynchronous eight-way read mux. In three failed
full-feature fits, the SDRAM bridge dominated the top 100 hold-delay insertion
paths. This identifies a useful optimization target, not a proven sole cause
of routing failure.

The candidate replaces those arrays with one explicit 8x61-bit `altdpram`
MLAB. Write data, address and enable use INCLOCK on clk_sys; read address and
output are unregistered. The existing clk_ram payload capture registers remain.
Push priority, bus acknowledgement, pointer handoff, queue capacity, byte masks,
read-after-write ordering and drain completion are unchanged. No new state or
cycle is introduced. No feature macro or timing constraint changes.

The write pointer is published on falling clk_ram after enqueue. Consumption
occurs on the following rising edge, after the entry has been written. Empty
queue output is ignored. The same-PLL 33/99 MHz clocks remain related and timed;
this optimization does not justify any false path. Physical RAM setup/hold and
related-clock checks remain required after routing. The Verilator array model
checks functional ordering but cannot prove device timing or collision safety.

## Measured standalone synthesis

Quartus 17.0.2, Cyclone V 5CSEBA6U23I7, BALANCED mode/AREA technique, identical
project settings for both isolated bridge builds:

| Resource | Register arrays | MLAB | Change |
|---|---:|---:|---:|
| Estimated ALMs | 888 | 618 | -270 |
| Registers | 1,446 | 958 | -488 |
| MLAB bits | 0 | 488 | +488 |
| M10K bits | 0 | 0 | 0 |

The RAM Summary confirms Simple Dual Port, depth 8, width 61, MLAB; mapping
uses 61 MLAB cells. Full-device placement savings and routing are not yet known.

The full-project synthesis for `interim_mac_wqmlab` (source `15a1449`)
completed in 4m49s: 38,816 estimated ALMs versus 39,021 previously (-205),
28,651 registers versus 29,142 (-491), and 4,840 MLAB bits versus 4,352
(+488). Its RAM Summary confirms the intended 8x61 MLAB queue. These full-
project savings differ from the isolated bridge estimate; routing is pending.

## Validation

Frozen candidate SHA256:
`6b49355a45b6e3d81d603d0542139a45854223c71c295ac8515c26cf5f9937ba`.

- SDRAM bench: 174 checks, zero failures or chip protocol errors; queue
  occupancy reached seven. Covers repeated wrapping and all byte-enable masks.
- Registered-first-miss memory path: 2,048 mixed operations, zero failures or
  chip protocol errors.
- Line/DMA integration: 20,512 reads, 5,381 stores, 11,423 DMA beats,
  9,408 direct pushes and 1,434 spanning stores, zero errors.

The regression's scratch negative DUT drops one push byte-enable bit and
produces 129 data mismatches. The tracked bench now returns failure on scoreboard
or chip protocol errors. The actual Intel `altdpram` model passed 256 edge writes across 32 slot
wraps, with no writes before the edge and correct data after changing source
address/data. A wrong-write-address mutation fails explicitly (exit 1).

The scratch slot guard passed 373 pushes, consume starts and pops with no
pending entries left, including 46 writes at slot 7. It checks pending-slot
overwrite, exact 61-bit payload, and write-to-consume age. Minimum reported age
is 10,102 ps including its 2 ps observation delay: the consume edge is one
10,100 ps clk_ram period after the write edge. The guard observed occupancy
eight after acceptance; the testbench's earlier negedge observation reached
seven. Both are simulation measurements, not physical timing margins.

Evidence: `scratch/sdram_wq_memory_review_20260924/` (standalone projects,
source snapshots, primitive checks, integration logs and input hashes) and
`scratch/sdram_wq_stress_20260924/` (baseline and corrupted-DUT checks).
These raw files are gitignored; this note records results in version control.
The full-feature fit from `15a1449` succeeded and produced a fresh RBF
(SHA256 `4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`).
Fitted use is 40,651 ALMs needed / 41,910, 28,588 registers and 509 M10Ks.
Setup misses remain: CPU -2.406 ns, RAM -0.697 ns, HDMI -0.426 ns. All summary
hold checks pass. Queue-focused capture and pointer setup/hold reports pass;
optional internal RAM pin/register queries are empty and are not claimed as
validated. Hardware subsequently completed five valid Speedometer runs (median 1.828),
Ethernet integrity, normal shutdown, and CD-ROM data reads. See the
[hardware report](INTERIM_WQMLAB_HARDWARE_20260925.md) for current audio/OSD
coverage and remaining limits. This is not a timing-clean release.
