# The pipelined AP68040 in the Quadra 800 core -- a comparison (2026-10-22)

Adam Polkosnik's pipelined 68040 (`AP68040` main, as vendored by
`NeXT_MiSTer` branch `pipelined_040`) against the sequential ap040 this
core ships (`rtl/ap68040`, behind `wombat_cpu`).  Branch `pipelined-040`:
the new core is vendored at `rtl/ap68040_faster/` and bridged to
`wombat_cpu`'s port list by `rtl/quadra_cpu040.sv`; `CPU_AP68040=1` in the
`.qsf` selects it (`files.qip` / the `.qsf` swap the CPU file lists, since
the two FPUs share module names).  The bridge runs the 68040 bus 1:1 on the
33 MHz machine clock (`bclk_en` high); a line transfer becomes the four
aligned beats quadra800's fast paths expect, TCI marks everything outside
RAM and ROM uncacheable, interrupt acknowledges are answered with AVEC.

## Size and timing

| | old ap040 (master, seed 40) | pipelined AP68040 (seed 38) |
|---|---|---|
| whole design | 38,899 ALMs (93 %), 468 M10K, 36 DSP | **33,333 ALMs (80 %)**, 487 M10K, 38 DSP |
| CPU entity | 25,773 ALMs, 13 DSP | **~20,090 ALMs**, 82 M10K, 15 DSP |
| worst slack, 33 MHz CPU clock | +0.198 ns (seed 38 failed to fit) | **+1.249 ns**; seeds 38/39/40 all clean |
| caches | 8+8 KB write-through, store buffer | 4+4 KB copyback |

Both built with the release recipe (Quartus 17.0, misterubuntu).  The new
core's extra 19 M10K are its register files, ATCs and caches as block RAM.

Not supported with the new CPU: the SONIC D-cache snoop (the core snoops
the 68040 way and quadra800 has no bus arbitration -- build with the
Ethernet off), the MMU walker port and the retained-line sideband into the
cache (the core walks and fills through its own bus).

## Standalone Dhrystone 2.1 and Whetstone (simulation)

The new core's own benches (`rtl/ap68040_faster/tb/run_bench.sh`, vbcc
`-O=1023 -cpu=68040 -fpu=68040`, user mode, copyback data) on both cores
with the same images; the old core through `wombat_cpu`'s transaction port
in a scratch bench with a one-ack-per-transaction memory (latency 0 = the
68040's C1/C2).  Cycles per iteration from the difference of a 2000- and a
4000-run image, so start-up and cold caches cancel.

| core / configuration | Dhrystone cycles/iter | Dhrystones/s at 33 MHz | Whetstone cycles/loop |
|---|---|---|---|
| new, Quadra parameters (`FPU_PIPE=0 LOOP_PRED=0 EARLY_RES=0`) | **1009** | 32,706 | 518,038 |
| new, the tb's defaults (`FPU_PIPE=1 LOOP_PRED=1 EARLY_RES=1`) | 957 | 34,483 | 461,890 |
| old ap040, release macros | 1608 | 20,522 | **446,509** |

Per clock the pipelined core is 1.59x faster on Dhrystone and 14 % slower
on Whetstone (FPU-bound: the old core's FPU is at least as fast).  In
copyback mode the new core's figures are insensitive to the memory model
(random wait states change the totals by < 0.1 %); in write-through mode it
is 2.6x slower.  The old core only has a write-through cache and its store
buffer hides most of the bus cost (latency 0 to 2: +17 cycles/iteration).

## Mac OS 8.1 on hardware (Speedometer 4.02, mister192, 32 MB)

| | old ap040 | pipelined AP68040 |
|---|---|---|
| Dhrystones/s | 18,009.9 | **28,390.7** |
| KWhetstones/s | 1,754.7 | 1,157.8 |
| Benchmark Mix average | 1.790 | 1.612 (Towers 0.361 s, Quick Sort 0.474, Bubble 0.550, Queens 0.346, Puzzle 0.838, Permutations 0.601, Int. Matrix 0.596, Sieve 1.932) |
| Performance Rating | 1.195 (CPU 0.798, Graphics 1.176, Disk 2.660, Math 20.910) | **1.473** (CPU 1.717, Graphics 0.846, Disk 2.385, Math 13.223) |

For scale, Low End Mac's Speedometer 4 figures for a real 25 MHz full 68040
(Quadra 660av) are CPU 0.89, Graphics ~1.02, Disk 1.46, Math 15; a 33 MHz
Quadra 800 scales to about CPU 1.2 and Math 20.  Both cores are far ahead
of the real machine on CPU; the old core's Math is at real-040 speed.

Shut Down from the Finder hangs on the new core (the Finder spins with
the Special title inverted, interrupts alive) -- under investigation.

## Where the new core's cycles go (measured)

Micro-benchmarks with the same programs and the same memory model on both
cores (vbcc/vasm images on the new core's testbench and on a scratch bench
around `wombat_cpu`), a per-instruction comparison of the boot traces, and
the `+fillprobe` bus probe in the full-machine sim:

| structure | old ap040 | pipelined (Quadra configuration) |
|---|---:|---:|
| store that cannot complete in the cache (write-through, uncached, VRAM) | 3.0 clk (posted) | 11.2 clk (a DMU engine job each, DC1 held) |
| uncached / device read (the core treats CM 10 like CM 11) | 5.2 | 14.1 (waits for every older instruction) |
| copyback store miss | n/a | 15-clk line fill now, 7-clk push later |
| Sieve, 8190 / 32768 bytes | 504 K / 1.40 M clk | 637 K / 2.81 M (the hardware's 2.3x, once the array is past 4 KB) |
| memcpy `move.l (a0)+,(a1)+` / MOVE16 | 1.66 / 2.40 clk per byte | 4.4 / 2.7 |
| FADD/FMUL independent | 4.3 | 6.05 (3.3 with `FPU_PIPE=1`) |
| FDIV / FSQRT | 27 / 17.6 (our old FPU retires 3 quotient bits a clock) | 39 / 24.4 (upstream 1-bit stepper) |
| FP store to memory | 7.4 | 11.2 copyback, 31 write-through |
| taken FBcc | 3.7 | 10.7 (always mispredicted) |
| A-line trap + RTE / JSR+RTS | 64 / 14 | 83 / 25-30 |
| cached loads, EAs, LEA, MULS.L | -- | 1.5-3x faster |
| RAM line fill / ROM line fill (quadra800, both CPUs) | 15 / 9 clk | 15 / 9 clk |
| branches and calls over the boot stretch | 5.1 clk | 15.4 (4 KB I-cache, 4 fetch bubbles per taken prediction) |

Mac OS 8.1 maps RAM copyback (every RAM write on the bus during the
System's start-up is a 4-beat line push), so the engine-bound store only
hits VRAM and device space.  The options off in the Quadra configuration
(`FPU_PIPE`, `LOOP_PRED`, `EARLY_RES`: +714, +427, +519 ALMs by the
author's estimates) cost 5 % on Dhrystone and Sieve, 18 % on a 20x20
matmul and 15-40 % per FP arithmetic op.  Int. Matrix's hardware loss is
not reproduced in simulation (the new core wins every variant); the
remaining suspects are the 4 KB cache and blocking for the full fill on
every miss where the old core's retained line answered a second miss in
the same line at once.

### The write buffer (commit `d811095`)

A store to a noncachable, nonserialized page (CM 10, the 68040's
imprecise mode) now enters a four-entry write buffer in its WB cycle and
the buffer drains in order through a third BIU client; the engine takes no
job while the buffer holds anything, so nothing of the processor's reaches
the bus ahead of a posted write.  `PA_P_MASK`/`PA_P_MATCH` name a window
that is always CM 10: the DAFB frame buffer, which the earlier
`PA_IO_SERIAL` rule had forced serialized with the rest of the non-RAM
space.  Bench test 17 (`tb_quadra_cpu040`): a 32-store loop 547 -> 280
clocks with 1-4 clock acks; every posted write is in memory before a
serialized write that follows.  On hardware (seed 40, 33,470 ALMs, all
clocks positive) Speedometer's Graphics went 0.846 -> 0.924 (Color
Benchmarks 0.89-0.92 at every depth), PR 1.473 -> 1.530, Int. Matrix
0.596 -> 0.488 s; Sieve unchanged.  The bus probe shows why the rest of
the Graphics gap is not the writes: quadra800 acks a VRAM write in 1 clock
and a VRAM read in 3, and the Finder phase does 2,581 VRAM writes to 1,461
VRAM reads -- each read still costs the serialized 14 clocks, and
QuickDraw's A-line entry and JSR/RTS the rest.

## The bug the port found

Unfixed, the new core gets to the flashing "?" disk on hardware and in the
full-machine sim: it mounts the HFS volume, reads the first catalog node
with the right data, declares it bad and unmounts.  A retired-instruction
and register-write trace of both cores (`+rtrace` in each, diffed by
`scratch/rtdiff.py`) found the instruction: in the ROM's node check,

    suba.l  a0,a0
    movea.w $2a(a4),a0      ; node size, a D-cache hit
    adda.l  a1,a0           ; got a0 = a1

the `adda.l` used the `suba.l`'s result instead of the load's.  AG holds
a uop whose base register has older writers in flight; the cycle the older
writer leaves EX and the younger plain load hands its data over from DC2,
the hold path set `stale_b` ("reload from EX's value next cycle") and the
reload undid the capture.  The entering-AG path already guarded this.
Fixed in `ap68040_backend.sv` (commit `6e1b795`); the core's own regression
suite still passes, and `verilator/tb_cpu040/prog.s` tests 10-16 cover the
sequence (test 11 fails without the fix).  Also fixed on the way:
`PA_IO_SERIAL` (commit `073684e`) stops the core reading a Quadra device
speculatively -- the Mac ROM never sets MMU cache modes, so with
translation off everything was cacheable to it, FIFOs included.

### The configuration switches (`FPU_PIPE`, `LOOP_PRED`, `EARLY_RES` on)

Built on top of the write buffer at seed 40: 35,648 ALMs (85 %), all
clocks positive (+0.289 / +0.420 / +1.133 ns).  Speedometer: PR 1.543
(CPU 1.715, Graphics 0.927, Disk 2.376, Math 13.508); Mix average 1.727
(KWhetstones 1,219, Dhrystones 24,896, Towers 0.349 s, Quick Sort 0.442,
Bubble 0.472, Queens 0.320, Puzzle 0.779, Permutations 0.570, Int. Matrix
0.455, Sieve 1.803); Color Benchmarks 0.89-0.94; FPU Benchmarks 0.728
(Quadra 650 = 1.0).  The integer tests gain 5-15 % each; Whetstone/Math
barely move, as the microbenchmarks predicted (Speedometer keeps its
doubles in memory: FP stores, FDIV and FSQRT are untouched by the FPU
pipeline).  Speedometer's Dhrystone and Int. Matrix vary run to run on this core
far more than on the old one: two Mix runs four minutes apart on the same
boot of this build gave Dhrystones 24,896 then 30,221 and Int. Matrix
0.455 then 0.572 s (Towers, the sorts, Queens and Sieve within 1 %).  The
4 KB caches make those two tests sensitive to what else is resident and
where the 60 Hz interrupt lands; rank the builds on the stable tests, or
on the median of several Mix runs.

| build | PR | CPU | Graphics | Mix avg |
|---|---:|---:|---:|---:|
| old ap040 | 1.195 | 0.798 | 1.176 | 1.790 |
| pipelined, fixed (seed 38) | 1.473 | 1.717 | 0.846 | 1.612 |
| + write buffer (seed 40) | 1.530 | 1.700 | 0.924 | 1.647 |
| + FPU_PIPE/LOOP_PRED/EARLY_RES (seed 40) | 1.543 | 1.715 | 0.927 | 1.727 |

## Tools

    make -C verilator tb_quadra_cpu040      # the bridge + core against quadra800-shaped acks
    make -C verilator vemu040               # full-machine sim with the new CPU (obj_dir040/Vemu)
    Vemu ... +rtrace +rtrace_after=<clk>    # [RT]/[RW] trace from either core's sim
    python3 scratch/rtdiff.py <new_dir> <old_dir> <align_pc>
