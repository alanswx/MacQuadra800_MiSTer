# Immediate-to-register direct dispatch (2026-09-14, candidate)

Builds on the hint-bus candidate (`CPU_FAST_READ_20260914.md`, which
carries the extension-word candidate). Core change plus one cache line.

## Why

The Speedometer opcode histogram (level-offer build, 198 M dispatches):
`CMPI.W #imm,Dn` alone is 4.5 % of all instructions (0C43/0C44), and
`ADD/SUB/CMP/AND/OR #imm,Dn` and `MOVE #imm,Dn/An` add several more
percent. Each ran decode -> (immediate consumed at decode) ->
`S_PIPE_START` -> `S_PIPE_REGS`: the pipe-start cycle only copied the
immediate into `src_val` and pointed port B at the destination.

## What

`immf_reg(n, da)`: at decode, with the same guards as the decode-time
immediate inline, consume the immediate from the queue into `imm`,
`x_ext` and `src_val`, select the destination register on port B and go
straight to `S_PIPE_REGS`, where the ALU retires it. Otherwise (word not
in the queue, a fetch outstanding, an acknowledge this cycle) the
established `immf(n, S_PIPE_START)` path is taken. Converted sites: the
`ORI/ANDI/SUBI/ADDI/EORI/CMPI #imm,Dn` group, `MOVE/MOVEA #imm,Rn`, and
the word/long `<ea>,Dn` ALU group with an immediate source. A two-word
immediate needs both words resident (`epf_ready_pc2`).

Also folded in (cache): `m_posted = post_active && (!r_span2 ||
sline_ready)`, so a spanning posted store keeps the one-cycle-later
acknowledge its line merge needs (`CPU_LINE_OFFER_20260914.md`, profile
finding).

## Results so far

- AP suite 11/11; corpus 33,964,466 cycles (same as the extension-word
  candidate), 0 REAL diffs; latency fixture 1,905 -> **1,883** clocks.
- Sieve (hint-bus candidate in parentheses): offset 0 512,914 (545,343,
  -5.9 %), 6 521,391 (538,284, -3.1 %), 16 584,369 (600,552, -2.7 %), 30
  550,061 (568,348, -3.2 %); arrays and guards PASS.

Pending: boot A/B, simulated Speedometer, fit, hardware. Tree
`/tmp/im-cand.*`.

### Lean stack without the hint bus (`/tmp/ie-cand.*`)

The hint-bus tree cannot route at 93 % utilization
(`CPU_FAST_READ_20260914.md`), so the same core change and the cache's
spanning-store fix were also applied directly to the extension-word
candidate. Gates: AP suite 11/11, corpus identical, latency fixture 1,944
-> **1,922**, Sieve (extension-word candidate in parentheses): offset 0
520,590 (553,009, -5.9 %), 6 529,067 (545,972, -3.1 %), 16 592,038
(608,223, -2.7 %), 30 557,750 (576,031, -3.2 %). Fit, boot A/B and
simulated Speedometer running. Only the extension-word core, this core
change and one cache line differ from the accepted build.

**Boot A/B, hint-bus + immediate-direct tree (row bug fixed):** 77,043,098
dispatches (+9.5 % over the level-offer checkpoint's 70,341,042), 5.451
clocks per dispatch, same frame, no faults. Reference only: that tree
does not route. The lean stack's own boot A/B follows.

**Boot A/B, lean stack:** 74,480,527 dispatches (+5.9 % over the
level-offer checkpoint, +0.9 % over the extension-word candidate alone),
5.639 clocks per dispatch, same frame, no faults. The boot workload has
few `#imm,Dn` operations; the Sieve fixture (-5.9 %) and the simulated
Speedometer carry this candidate's case. The gap to the hint-bus tree
(77.0 M) is the one-clock read hit's share, about 3.4 % of boot dispatches.

### Fit (done, closes at seed 23)

Seed 22: HDMI -0.572 ns (clk_sys +0.187, clk_ram +0.523), 38,872 ALMs.
**Seed 23: closes**, tree `/tmp/MacQuadra800_ie_v512s23.*`: 38,764 ALMs
(92 %), all 39 TNS zero, worst setup +0.057 ns (clk_ram 99 MHz), HDMI
+0.231 ns, clk_sys +0.557 ns, worst hold +0.255 ns, no Critical Warnings.
RBF SHA256 `a33a57182194c437121509d9aae83b39bcee888b8b0993453d5aaf0b68708423`
(4,432,304 bytes); sources core `96178506...`, cache `8ea1c405...`, MMU
and `wombat_cpu.sv` unchanged from the accepted build. Seed 21 still
running as a spare. RTL identical to the boot-simulated tree. Hardware
run in progress.

**Simulated Speedometer runs, 15:07:** the drivers of all four unattended
runs (extension-word, hint-bus, hint-bus + immediate, lean stack) were
terminated at 15:07:27 by something outside these scripts (the same
happened at 13:27:43); none reached its results window. The extension-word
and hint-bus runs had reached the alert, so their profiles exist:
1,123,242,151 and 1,109,315,751 cycles (about -1.2 % for the one-clock
read hit, within the poll-granularity noise of these brackets, and not
worth its area at 93 %). The lean stack's score comes from hardware.

### Hardware (done, three valid runs) — accepted 2026-09-14

`/media/fat/_Unstable/MacQuadra800_ie_v512_seed23_20260914.rbf` through
the lifecycle guard (dry-run, deploy, restore all exit 0), every wait a
verified foreground interval, fresh alert each run, no anomaly:

| Test | run 1 | run 2 | run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 485.494 | 487.841 | 487.879 |
| Dhrystones/sec | 8294.149 | 8295.944 | 8296.964 |
| Towers (s) | 1.447 | 1.446 | 1.448 |
| Quick Sort (s) | 0.932 | 0.931 | 0.932 |
| Bubble Sort (s) | 1.048 | 1.048 | 1.048 |
| Queens (s) | 0.763 | 0.763 | 0.763 |
| Puzzle (s) | 2.075 | 2.074 | 2.093 |
| Permutations (s) | 2.129 | 2.128 | 2.128 |
| Integer Matrix (s) | 1.502 | 1.493 | 1.503 |
| Sieve (s) | 1.700 | 1.698 | 1.698 |
| **CPU Mix** | **0.684** | **0.685** | **0.684** |

Mean **0.684333**, **+3.89 %** over the level-offer checkpoint 0.6587 and
+47.6 % over the source-only 0.4635. Every test faster: Dhrystones +4.6 %,
Puzzle -7.3 %, Sieve -6.1 %, Integer Matrix -5.8 %. Evidence
`scratch/perf_ie_seed23_20260914/RESULTS.txt`. Board restored to MENU,
Main and disposable disk verified.

**Simulated Speedometer (rerun, results captured 16:38):** CPU Mix
**0.701** (KWhetstones 524.6, Dhrystones 8315.7, Towers 1.451, Quick Sort
0.941, Bubble Sort 1.069, Queens 0.772, Puzzle 1.941, Permutations 2.186,
Integer Matrix 1.387, Sieve 1.715); profile 1,107,333,287 cycles, 5.318
clocks per dispatch. Hardware measured 0.684: the simulator reads 2.5 %
high, as it did for the write-path build (2.2 %). Screenshot
`/tmp/simspeedo-ie/screenshot_f8724.png`.
