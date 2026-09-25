# P214: a store spanning two longwords is pushed as two FIFO entries

## How it was found: the platform fixture

The kernel fixtures run `wombat_cpu` against a fixed-latency RAM model.  At `+wlatency=1` they
predicted P193 -> P205 at 1.130x on Whetstone; hardware gave 1.078x (1387 -> 1495 KWhet/s).  At
wlatency 3 the prediction was 1.061x, at 5 1.040x: the model had the wrong shape, not just the wrong
number.

`scratch/platform_fixture/` (built 2026-09-23; `run_platform_whet.py`, `TREE=<dir with rtl/>`, about
2 minutes a run) runs the same Whetstone image on the machine's real memory path: `quadra800` itself
(unmodified, `CDROM=0, SONIC=0`), `sdram_beat32`, `sdram.sv` and `tb_sdram.sv`'s chip model, at
99 MHz / 33 MHz with aligned edges, refresh included, the RAM image backdoor-loaded through sdram.sv's
address decode.  It checks the globals, the CODE3 patch area and the stack byte for byte against the
latency fixture's captures, and counts SDRAM protocol errors (zero).  It predicts P193 -> P205 at
1.093x.  (With the stack moved by two bytes it predicts 1.066x; hardware's 1.078x lies between, so the
remaining difference is most likely the stack alignment Speedometer runs with.)

Its instrumentation (P205, one loop):

- 914,001 stores are `move.l` to an address 2 mod 4, all in the stack page -- SANE's 10-byte extended
  temporaries.  The direct-write push (P185, `bus_wr_direct`) took only stores inside one longword
  (`bus_wr_end <= 4`), so these went through wombat_bus32 as two S_MEM beats: **10 clk_sys each,
  9.14M bus-busy cycles**.  The 1.49M stores inside one longword took 2.
- The 4-entry store buffer was full, with a store waiting, for 3.14M cycles (14.6 % of the loop).
- The bridge's write FIFO never filled; SDRAM row misses, refresh and read latency were minor.

## The change (`rtl/quadra800.sv`)

A RAM store with `bus_wr_end > 4` (a long at offset 1..3, a word at offset 3), whose second longword
is RAM too, takes the direct arm: the first longword is pushed at once with the enables of its tail
bytes (`(4'b1111 << (4 - bytes)) >> offset`, as before), and `wr_split_pend` pushes the second
longword on the next clock with the head bytes (`4'b1111 << (8 - end)`, data shifted left by
`(4 - offset)` bytes) and acknowledges the store then (`bus_miss_ack`).  `mem_wq_room` already means
two free entries.  While the second half is pending, the held request is kept out of the direct arm
and the adapter (`!wr_split_pend`), and the second push runs ahead of the arbiter, so nothing else
reaches the FIFO between the halves; reads still wait in the bridge for the FIFO to drain.

## Evidence

- Platform fixture, Whetstone loop: P212 20,759,095 -> P214 18,109,054 (**-12.8 %**); store buffer
  full 3.14M -> 13k cycles; direct stores 2.38 clocks mean; MEMCHECK match, 0 protocol errors.  An
  8-deep store buffer on top changes nothing (18,102,591).
- `verilator/tb_line_dma.sv` (the service arm verbatim, with SONIC DMA interleaved): the sized stores now
  use every offset, so words at 3 and longs at 1..3 span into the next longword (1,434 spanning stores
  among 5,381); the shadow covers both longwords.  PASS, 0 errors; with the second push's enables
  zeroed it fails with 3,898 errors.
- Projected on hardware from P205's calibration (21.43M <-> 1495 KWhet/s): about 1770 KWhet/s.
