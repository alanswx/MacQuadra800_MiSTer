# Speedometer 4.02 CPU Mix interval, full-machine simulator profile

Captured 2026-09-14 on the registered-cache-admission checkpoint RTL (core
`0c3a81bd...`, cache `77882b83...`; the adopted RTL when the run started).
Fastboot ROM, fresh copy of the golden Speedometer disk, the hardware
navigation route reproduced key for key, profiler bracket from the Run Set
Return to the completion alert (run 2; run 1 carried a 4.8 s idle tail and
is kept only for comparison). Artifacts: `/tmp/simspeedo-run2.yjmI9x/`
(`profile.tsv`, screenshots `screenshot_f6130.png` setup, `f9367` alert,
`f9568` results).

## The simulator predicts the hardware score

| | simulator | hardware (same RTL) |
|---|---:|---:|
| CPU Mix | **0.493** | 0.485 / 0.486 / 0.485 |
| Sieve (s) | 2.988 | 3.029 / 3.026 / 3.026 |
| Dhrystones/s | 5474 | 5606 / 5608 / 5608 |
| KWhetstones/s | 392.5 | 369.3 / 370.6 / 370.4 |

Within 2 % overall (the simulator's RAM model is slightly faster on
integer memory tests and slower on Whetstone). A full simulated run costs
about 1.5 hours of wall time (26 min boot, navigation, 41 s of guest time
at about 41x real time), so candidates can be scored before hardware.

## Where the 1,352,073,216 clocks go (167,975,032 dispatches, 8.05 each)

| core state | cycles | share | entries | clocks/entry |
|---|---:|---:|---:|---:|
| `S_MRD` (9) memory read | 415.9 M | **30.8 %** | 54.5 M | 7.6 |
| `S_MWR` (10) memory write | 166.6 M | **12.3 %** | 30.3 M | 5.5 |
| `S_DECODE` (4) | 141.3 M | 10.5 % | 135.1 M | 1.05 |
| `S_FETCH` (3) opcode wait | 129.6 M | 9.6 % | 44.7 M | 2.9 |
| `S_PIPE_REGS` (190) | 68.2 M | 5.0 % | 49.0 M | 1.4 |
| `S_PIPE_START` (20) | 66.0 M | 4.9 % | 66.0 M | 1 |
| `S_IMMF` (8) extension wait | 63.5 M | 4.7 % | 53.6 M | 1.2 |
| `S_EXEC` (28) | 29.9 M | 2.2 % | | 1 |
| `S_PIPE_SRD` (22) | 29.1 M | 2.2 % | | 1 |
| EA states (11, 13, 15) | 68.2 M | 5.0 % | | 1 |
| `S_NEXT` (5) | 19.1 M | 1.4 % | 19.1 M | 1 |

Cache state occupancy: `C_IDLE` 79.4 %, `C_PASS` 14.4 % (writes and
uncached traffic), `C_FILL` 5.5 %, `C_LOOK` 0.3 %. `tc=C000`, both caches
on for the whole bracket.

Reading: memory accesses are 43 % of all cycles, and the average read
costs 7.6 clocks against a 3-clock (now 2-clock) hit, so a large share of
data reads miss the 4 KB data cache and pay the SDRAM fill (about 20
clocks in the fixture). Writes average 5.5 clocks against a 3-clock
best case, so the two-entry store buffer and the SDRAM write path stall
runs of stores. After the line-return candidate (which removes most of the
fetch and extension waits and the port contention), the data cache miss
rate and the store path are the next targets: a 16 KB data cache fits the
free M10K budget (94 blocks free; the 4 KB cache uses 8 for data).

Top opcodes: `204A`/`206E` (MOVEA.L), `5243` (ADDQ.W #1,D3), `D0C3`
(ADDA.W), `0C43` (CMPI.W), `4E75` (RTS), `4E56`/`4E5E` (LINK/UNLK),
`E588` (LSL.L #2), `2270` (MOVEA.L (d8,An,Xn)), `6FF0`/`66F4`/`6DCA`/`67EE`
(short loop branches). Compiled Pascal/C code: frame pointers, indexed
addressing, short loops.
