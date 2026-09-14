# Write path: posted stores acknowledged on admission (candidate, 2026-09-14)

Follows the accepted line-return checkpoint (`CPU_LINE_RETURN_20260914.md`).
The Speedometer-interval profile puts memory writes at 11.4 % of all
cycles, 4.2 clocks per write against a 3-clock best case, and `wombat_cpu`
already posts qualifying RAM writes below the cache (the two-entry store
queue acknowledges them on capture and drains later). The cache, however,
still waited for that queue's acknowledge before releasing the core.

## Change

`ap040_cache.v` gains `c_post_ok`: the platform's own qualifier for a
write it will accept into the store queue and never fault (in
`wombat_cpu.sv`: `store_buffer_ok && addr[31:30] == 0`, the same predicate
as `wombat_store_buffer`'s `buffer_req`; the AP bench wrapper ties it
low because it has no queue). On admission of a store with `c_post_ok`
the cache registers the acknowledge at once, captures address, data,
size and FC, and drains from those copies in `C_PASS` while the core
moves on (`post_active`); `c_ack` is suppressed for the drain, a bus
error on a posted drain holds nothing (the store was promised not to
fault), and the aligned-store hit-update and row invalidates are
unchanged because they were already driven from values captured on
admission. The data RAM is not read during a posted drain: the
hit-update merge needs the admission-edge read.

Cost: 69 flops and the master-side muxes. A store now costs the core two
clocks (issue, acknowledge) instead of three; the next request waits in
`C_IDLE` for the drain to complete if it arrives immediately.

## Results (tree in `/tmp/wr-cand.path`)

| gate | result |
|---|---|
| AP suite | 11 of 11 (posting disabled in that wrapper) |
| cache bench with the port tied low | passes |
| corpus | 33,932,693 cycles, 0 REAL diffs (unchanged, no queue there) |
| latency fixture | 1,789 -> 1,782 clocks; RAM writes 3 -> 2 |
| Sieve sweep | 10,069,395 -> 9,636,048 (-4.3 %), every offset faster; byte store 9 -> 8 clocks |

Pending: the memory-attributed Speedometer profile (store-buffer-full
stalls and reads waiting behind queued stores decide whether the queue
gets deeper and whether read misses may bypass it), boot A/B, simulated
Speedometer, fit, hardware.

## Two bugs the early acknowledges exposed (2026-09-14, before any commit)

1. **Tag row follows the live address.** Once the requester is released
   early (posted store, or the requested-word-first fill below), the
   core's address pins move on to its next request or hint. The cache's
   tag row read followed `a_row` from those pins, so the tag write at the
   end of a fill composed the new row from whatever row the core was
   pointing at, and a posted store's merge lookup compared against the
   wrong row and silently skipped the merge, leaving stale data in a valid
   line. The FPU suite caught the fill case (an all-zero opcode dispatched
   after an RTE); the posted-store case reached the board first: the
   write-path bitstream (`241f137d...`) did not boot (four black frames,
   guard restore clean, `scratch/perf_wr_seed24_20260914/`). Fix: while a
   fill, its tag write or a posted drain is active, `tag_ridx` is the
   transaction's own `r_row`. A read-after-posted-store check is now in
   the latency fixture program (`scripts/fixtures/cache_early_handoff`),
   and the rule from here on is that nothing goes to the board without
   the full-machine boot simulation.
2. **Fill beats carried the live function code and space.** After the
   early acknowledge, the remaining beats presented `c_fc`/`c_instr` of
   the core's next request (the AP exception test saw a handler fetch
   with the vector read's FC). Fix: `r_fc` captured on admission,
   `m_fc`/`m_instr` use it while filling.

Also: the walker is held off while the cache still owns the master side
after a release (`c_busy`, gated in both wrappers), keeping the platform's
"walker never overlaps a CPU bus transaction" rule.

## Requested-word-first fills with early acknowledge

`C_FILL` now starts at the requested longword and wraps; the requester is
acknowledged as soon as its word (or spanning pair) is in, and `C_TAGW`
validates the line for everyone else. A completed instruction fill seeds
the line buffer from the freshly written line. Latency fixture: a data
miss drops from 20 to 7 clocks. The cache bench's T10/T12/T14 waited for
the old whole-line acknowledge and are updated to the new contract (the
retained line stays valid until the fill completes).

Candidate tree `/tmp/fill-cand.path` (posted stores + spanning reads +
invalid-way-first + requested-word-first fills + the fixes): AP suite 11
of 11, corpus 33,932,693 (0 REAL diffs), Sieve 9,610,802 total (every
offset passes), fixture passes with the new check. Boot simulation and fit
pending; hardware only after both.

## Bypass causes measured, and the two-word store merge

The bypass-cause profile of the committed RTL over the Speedometer bracket
(`/tmp/simspeedo-mem3/profile.tsv`, 1,135,513,767 clocks):

| bypassed access | entries | cycles | clocks each |
|---|---:|---:|---:|
| read, misaligned within a line | 11,759,107 | 120,177,397 (**10.6 %**) | 10.2 |
| read, cache-inhibited | 466,507 | 9,982,327 | 21.4 |
| write, misaligned | 6,198,378 | 15,549,809 | 2.5 |
| write, aligned (write-through) | 23,891,680 | 47,897,088 | 2.0 |
| write, cache-inhibited | 759,299 | 6,214,915 | 8.2 |

Store-queue-full stalls are 7.0 M cycles and reads waiting behind queued
stores 9.9 M, so the queue depth and a read bypass are not worth their
complexity yet. The misaligned reads are the target the spanning-read
change (in the fill candidate) hits: 3 to 4 clock hits instead of 10.
One store in five is misaligned and each invalidated its whole four-way
set before refilling, which is where a good share of the 2.8 M data fills
came from.

**Merge candidate** (`/tmp/merge-cand.path`, on top of the fill candidate):
a store that straddles two longwords of one line and hits reads the whole
line of the hit way during its pass (`sline_read`), merges both words
(`span_merge`, with the word-size shift corrected after the fixture caught
it) and writes them to their two arrays together through per-array write
data; a word store at offset 1 merges in place. If the acknowledge
outruns the line read, the row is invalidated instead. The latency
fixture program now also checks spanning longword and word stores and the
untouched neighbouring bytes. Gates: AP suite 11 of 11, corpus 0 REAL
diffs, Sieve unchanged (no misaligned stores there), fixture passes. Boot
simulation, simulated Speedometer, fit and hardware pending.

## Simulated Speedometer, merge candidate (2026-09-14)

`/tmp/simspeedo-merge` (profile saved as
`scratch/profiles/simspeedo-merge_*`): the whole CPU Mix on the merge
candidate's simulator, same procedure as before.

| Test | committed RTL (sim) | merge candidate (sim) | hardware, committed |
|---|---:|---:|---:|
| KWhetstones/sec | 442.652 | 504.474 | 409 |
| Dhrystones/sec | 7114.237 | 7602.819 | 7125 |
| Towers (s) | 1.677 | 1.509 | 1.622 |
| Quick Sort (s) | 1.053 | 0.962 | 1.025 |
| Bubble Sort (s) | 1.151 | 1.121 | 1.128 |
| Queens (s) | 0.860 | 0.811 | 0.844 |
| Puzzle (s) | 2.457 | 2.210 | 2.546 |
| Permutations (s) | 2.552 | 2.293 | 2.449 |
| Integer Matrix (s) | 1.780 | 1.555 | 1.92 |
| Sieve (s) | 2.005 | 1.835 | 2.003 |
| **CPU Mix** | **0.600** | **0.661** | 0.590 |

+10 % in the simulator; expected about 0.65 on the board. The profile
(5.67 clocks per dispatch) still shows 3.2 M bypassed reads at 10 clocks:
the misaligned reads that cross a line boundary, which the spanning-read
change deliberately left on the bus. Data fills rose from 2.8 M to 3.6 M
because 8.5 M formerly bypassed reads now allocate lines; net effect is
the gain above.

Fit status: seed 25 failed to place ("can't fit design in device"); seed
24 and seed 24 with `VIDEO_512_OFF` are running.

### Fit (done) and hardware (done, three valid runs) — accepted 2026-09-14

Seed 24 on the trimmed profile failed the CPU clock by 1.859 ns (TNS
-46.2), and seed 24 plus `VIDEO_512_OFF` (-360 ALMs, drops the 512x384
monitor option) missed the 99 MHz RAM clock by 0.039 ns. Seeds 22 and 23
of the `VIDEO_512_OFF` recipe both close:

| | seed 22 (deployed) | seed 23 |
|---|---:|---:|
| ALMs needed | 38,525 (92 %) | — |
| worst setup, HDMI | +0.238 ns | +0.383 ns |
| clk_ram 99 MHz | +0.615 ns | met |
| clk_sys 33 MHz (CPU) | +0.741 ns | met |
| TNS | all 39 zero | all zero |

Seed 22 tree `/tmp/MacQuadra800_merge_v512s22.*`, RBF SHA256
`60cafca28fd71ee3e09afb85d0d549963bd19f3abae70b14e34c190031bb8b07`
(4,381,488 bytes), sources cache `545eb807...`, core `b2afc434...`, MMU
`29de0a98...`, `wombat_cpu.sv` `db63a4b2...`. `VIDEO_512_OFF` is now part of
`configs/cpu_development.tcl`.

Hardware, `/media/fat/_Unstable/MacQuadra800_merge_v512_seed22_20260914.rbf`
through the lifecycle guard (dry-run, deploy, restore all exit 0), boot to
idle MacAtrium in 153 s, fresh alert each run, no anomaly:

| Test | run 1 | run 2 | run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 469.356 | 471.174 | 471.319 |
| Dhrystones/sec | 7579.673 | 7580.368 | 7579.944 |
| Towers (s) | 1.500 | 1.501 | 1.500 |
| Quick Sort (s) | 0.956 | 0.955 | 0.956 |
| Bubble Sort (s) | 1.100 | 1.100 | 1.100 |
| Queens (s) | 0.801 | 0.801 | 0.801 |
| Puzzle (s) | 2.334 | 2.334 | 2.353 |
| Permutations (s) | 2.235 | 2.236 | 2.235 |
| Integer Matrix (s) | 1.667 | 1.657 | 1.668 |
| Sieve (s) | 1.841 | 1.838 | 1.839 |
| **CPU Mix** | **0.646** | **0.647** | **0.646** |

Mean **0.646333**, **+9.49 %** over the line-return checkpoint 0.5903 and
+39.4 % over the source-only 0.4635. The simulator predicted 0.661 (2.2 %
high; its committed-RTL run was 1.7 % high). Evidence
`scratch/perf_merge_seed22_20260914/RESULTS.txt`. Board restored to MENU,
Main and the disposable disk verified unchanged.
