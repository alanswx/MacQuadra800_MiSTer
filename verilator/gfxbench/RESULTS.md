# Graphics microbench, dual core (quadra_cpu040), 2026-10-26

tb_gfx.sv + gfx.s on the archived RTL. 16384 ops/kernel, platform mode
(direct writes ack next clock), fixed read latency lat=1. Build+run ~5 s.
Cost/op includes the dbf/addq loop overhead, equal across kernels; read the
RELATIVE costs. Platform-side effects (quadra800 adapter fallback, vram_ddr3)
are NOT here -- this is the CPU-internal half only.

| kernel | operation | cyc/op |
|---|---|---|
| K1 | aligned VRAM long store (fill)        |  9.01 |
| K2 | unaligned spanning VRAM store         | 22.26 |
| K3 | uncached VRAM read-modify-write       | 24.01 |
| K4 | cached RAM store, 16KB fill (overflows 8KB D-cache) | 10.13 |
| K5 | cached RAM read-modify-write          | 13.48 |

Findings:
- Aligned VRAM stores (~9) are already competitive with cached RAM streaming
  fills (~10): a copyback store to a cache-overflowing window read-allocates
  then pushes, so it is not free either.
- Unaligned spanning store is 2.5x an aligned one. The core splits a long at
  byte offset 1 into byte+word+byte = 3 bus transactions (writes counter
  confirms 3.0 beats/store). Bottleneck B, core-internal, large per-op.
- Uncached VRAM RMW (~24) is ~1.8x cached RMW (~13.5): the uncached
  framebuffer READ is the tax (bottleneck C), unavoidable at the CPU; the
  lever is a VRAM read cache (vram_ddr3's 4x32B), measured in the full sim.

Rerun: gfxbench/build_gfx.sh  (edit RTL copy, rebuild, ~1 min + 5 s).

## Store-buffer and read-latency A/B (2026-10-26)

Write latency varied (+noplatform +lat=N) with the external wombat_store_buffer
on and off (+nosb).  Deltas are the clean signal (loop overhead is constant).
NB: run each config as separate argv words -- zsh does not split unquoted $cfg,
which silently drops +lat=N.

| config | K1 aligned fill cyc/store | K3 RMW cyc/op |
|---|---:|---:|
| platform (direct 1-clk writes) |  9.00 | 24.00 |
| write lat 3, store buffer ON   |  9.01 | 26.00 |
| write lat 3, store buffer OFF  | 13.01 | 30.00 |
| write lat 7, store buffer ON   | 10.01 | 33.00 |
| write lat 7, store buffer OFF  | 17.01 | 38.00 |

- The store buffer works: aligned stores stay ~9-10 cyc as write latency grows
  from 1 to 7, because it posts them.  Removing it costs +4 (lat3) to +7 (lat7)
  cyc/store.  The store path is already well hidden; it is not the lever.
- The uncached READ is the unhideable tax: K3 RMW rises 26->33 as read latency
  goes 3->7 (+7, the read), and the store buffer cannot help a read.  This is
  bottleneck C; the only lever is a VRAM read cache (vram_ddr3's 4x32B) or not
  reading the framebuffer.  The full sim measures that cache's hit rate.

## Full-sim profile, Speedometer run slice (a_ideal, 2026-10-26)

Triggered the Speedometer benchmark series (Cmd-A) and profiled a ~13 guest-sec
slice. The slice caught the CPU phase + heavy Speedometer UI/QuickDraw (window,
dialog, cursor drawing) + idle at the "choose drive" dialog, not the pure Color
blit loop (the drive dialog blocked it). Still decisive for the ROM question
because QuickDraw's code working set is the same code either way.

ROM-cache sweep (16-byte lines, from the real ROM fetch stream):
  distinct ROM lines touched = 3,128 = 48.9 KB   <-- QuickDraw+Toolbox working set
  64 KB  direct-mapped:  2.80% miss
  128 KB direct-mapped:  0.83% miss   (0.34 misses / 1000 retirements)
  256 KB direct-mapped:  0.16% miss   (0.07 / 1000)
  512 KB / 1 MB:         0.16% / 0.15% (no further gain past 256 KB)
  ROM instruction fetch is only 4.89% of bracket cycles.

=> The ROM working set is ~49 KB. A 128 KB cache already misses <1%, and ROM
   fetch is ~5% of cycles, so its misses are a tiny fraction of execution.
   Growing to 256 KB cuts an already-tiny miss count; the payoff is negligible.
   DON'T spend M10K on 256 KB. (Matches the handoff's +0.03 PR from 128 KB.)

VRAM mechanism mix (124,627 stores, 57,886 reads in the slice):
  stores: 90% aligned long, 2.5% byte, 0 word, 7% line; UNALIGNED-in-long 2.0%,
          SPANNING-two-longs 0.  -> bottleneck B (unaligned spanning store)
          essentially does not occur in real QuickDraw. Not a lever.
  reads:  4-way 32-byte read-cache model = 0 hits, BUT the model is conservative
          (any write invalidates the line, so RMW read-after-write never hits);
          the real vram_ddr3 cache may do better. Read gaps are 16-128 words
          (limited spatial locality). Read-cache value is uncertain, not zero.

Where the slice's time went (heuristic): CPU-internal pipeline (dmu_busy 21% +
internal 20% = 41%), RAM latency (ifetch 17% + dread 13% = 31%), fetch-queue
empty 10%. VRAM was <0.2% and ROM fetch ~5%. The dual core's own pipeline and
RAM latency dominate; VRAM/ROM are not the bottleneck in this workload.

Caveat: this slice is UI+setup+CPU, not the pure Color blit loop. The clean
Color-benchmark profile (to firm up the read-cache value and the blit mix) needs
clicking through the drive dialog and bracketing the Graphics phase.

## DMU engine-state histogram (tb_gfx [EST], 2026-10-26 evening)

Per posted VRAM store in K1 (16384 stores, 147,559 cycles = 9.0/store):
  E_IDLE 3.0 | E_BUS 1.0 | E_BUS_W 4.0 | E_VRAM_DONE 1.0  (engine busy 6.0)
  a store waits in WB with the engine busy: 2.5 cycles/store.
The platform acks a direct write the NEXT clock, so the 4 cycles of E_BUS_W
are the TS/TA handshake through quadra_cpu040 + wombat_store_buffer + the
BIU's registered pins, not memory latency.  Step 2 = release the engine for a
posted VRAM store once the BIU has the transaction (skip E_BUS_W/E_VRAM_DONE),
letting the BIU serialize the bus; expected ~9 -> 4-5 cycles/store.
K3 (RMW): E_BUS_W 10/op = store 4 + uncached read ~6, plus the read's E_S_*
states ~5 -> an uncached read costs ~11 engine cycles (Step 3 territory).

## Step 2 in the microbench (engine released at grant for posted VRAM stores)

ap68040_dmu.sv: in E_BUS_W a posted VRAM store (e_ret == E_VRAM_DONE) leaves
for E_IDLE at the BIU grant instead of after TA; its done/err is attributed via
post_pend while nothing is granted; the done/err handling is gated on bo_ingnt.
ap68040_biu.sv: a single transfer's write data is latched at grant (cur_wd_l),
so the client may release it (lines keep the hold-until-done contract).

| kernel | before | after |
|---|---:|---:|
| K1 aligned VRAM fill, cyc/store | 9.00 | 6.00 |
| K1 engine: E_IDLE / E_BUS / E_BUS_W / E_VRAM_DONE | 3 / 1 / 4 / 1 | 3 / 1 / 2 / 0 |
| K1 WB store waiting on a busy engine, cyc/store | 2.5 | 1.0 |
| K3 VRAM RMW, cyc/op | 24.0 | 21.0 |
| K2 unaligned (not posted), K4/K5 cached RAM | unchanged | unchanged |

tb_quadra_cpu040 (device ordering under posted stores, locked RMW, interrupt
storm): PASS normal / fast / platform.  The remaining 2 cycles of E_BUS_W are
the wait for the BIU to finish the previous transfer (TS, TA, idle); the 3 idle
cycles are the loop's own cadence.  A request queue in front of the BIU would
be the next step (~4 cyc/store).

## Step 3 trial (VRAM reads wait only for older stores): NO effect, reverted

Changed the cache-inhibited-read gate in ap68040_dmu.sv from dm_older to
st_older for the VRAM window. K3 RMW 21.01 -> 21.01; a new K6 (VRAM read,
mulu.l, add, dbf: ~10 clocks of non-store work between reads) 20.01 -> 20.01;
tb_quadra_cpu040 cycle counts identical. The serialization behind older uops
is not what an uncached VRAM read pays for; its ~12 clocks are the engine's
load sequence (E_S_START/ACT/BUSD/NEXT/DONE = 5) + E_BUS (1) + the read's bus
handshake (E_BUS_W ~6).  A real cut needs a short engine path for single
cache-inhibited reads (skip the allocation states) and/or a faster TS->TA path
for reads through quadra_cpu040 -> quadra800 -> vram_ddr3.  Not pursued now.
Tree reverted to Step 1+2 (dmu md5 05dc575127a7 = built candidate).
