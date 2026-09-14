# Registered cache-hit admission: RTL review and gate plan (2026-09-13)

Review of the isolated `ap040_cache.v` candidate described in
`CPU_CACHE_EARLY_HANDOFF_20260913.md` (patch
`scripts/fixtures/cache_early_handoff/candidate/cache-early.patch`, candidate
cache SHA256 `77882b83...`, baseline `55b94aee...`, accepted core `0c3a81bd...`).
This is the step-1 design review the handoff asked for. Results of the gates
launched from it are appended below as they arrive; until the hardware
section is filled in, nothing here is an accepted speedup.

## What the patch does, in one paragraph

The MMU drives the cache's `c_addr[11:0]` straight from the logical address
(`ap040_mmu.v`, the `ttr_hit ? c_addr : atc_hit ? {h_pa, c_addr[11:0]} : c_addr`
mux), so the set/word index bits `[9:2]` are stable one cycle before `c_req`
rises on a translated access. The patch lets the data RAM read every idle
cycle at that index (`cd_rd_en` gains `cst == C_IDLE`), remembers which index
and validity the last read carried, and compares the free-running tag row
against the live physical tag `a_tag` while in `C_IDLE`. When `rd_accept`
arrives and the remembered read matches the request, it registers `ack_r`
and `rdata_r` at the accept edge instead of going through `C_LOOK`. Warm
translated hits go 4 -> 3 clocks; TC-off and TTR hits are already 3 and get
nothing (the request and address arrive together, so there is no early cycle).

## Invariants checked by reading the RTL

- **Tag freshness.** The tag RAM read is free-running at `a_row`, so `tag_q`
  always reflects the row read on the previous clock. `idle_tag_idx` tracks
  the address the RAM actually read (write index when `tag_we`), and
  `idle_tag_valid` drops for any port-A write or any port-B invalidate on
  that clock, which also covers the mixed-port read-during-write case that is
  undefined on M10K. `idle_hit` additionally refuses the current clock's
  `tag_we`, `inv_wren`, `look_snooped` and `snoop_look_row`.
- **Data freshness.** `idle_data_idx`/`idle_data_valid` update only on a real
  `ce && cd_rd_en` read. Any data write (`cd_we`, only in `C_FILL`/`C_PASS`)
  clears validity, and a lookahead read (`ipred_read`) records itself as
  invalid rather than as the request index. Because the four way RAMs are
  indexed by `{bank, set, word}` only, a read of index X made on behalf of
  any earlier request (including a bypassed one) is still the correct data
  for a later request at X provided nothing wrote in between, which the
  validity bit guarantees, and provided the tag identifies the way, which the
  fresh tag compare guarantees.
- **No new combinational ack.** `c_ack` is still `pass_active ? m_ack : ack_r`;
  the idle path writes `ack_r`. The 5.9 ns ATC -> `c_ack` -> core exception
  mux path that once blocked enabling the caches is not reintroduced. The new
  timing path is ATC output -> `compare_tag` mux -> four 22-bit compares ->
  `idle_hit` -> `ack_r`/`rdata_r` flops inside the cache. It needs STA, not
  argument.
- **Priority and exclusivity.** `ipred_hit` keeps priority (`idle_hit` has
  `!ipred_hit`, and the FSM tests `ipred_hit` first). `rd_accept` already
  excludes writes, bypasses, `ci_inv_pend`, `store_inv_lost`, `ack_r` and a
  pending CINV; `idle_hit` adds `!err_hold` and `!m_err`.
- **Lookahead seeding.** An idle instruction hit seeds the next-word
  lookahead exactly as a `C_LOOK` hit does (`ipred_idle_read`, `ipred_way <=
  hit_way`), and the seeding read marks the idle data record invalid for that
  edge.
- **Reset, sweep, CINV.** Reset clears the four metadata registers. During
  `C_SWEEP` `tag_we` holds `idle_tag_valid` low; after CINV the tags are zero
  so no idle hit is possible until a refill, which itself clears data
  validity.
- **Conservative cases that only cost a cycle.** A stale `look_snooped` from
  an earlier snooped lookup blocks the idle path once (it is cleared on the
  next `rd_accept`), and unrelated-row port-B writes block reuse for a clock.
  Neither affects correctness.

No defect was found. The cost is 18 metadata flops, 22 two-input muxes in
front of the existing comparators, and the idle read enable; the data RAM now
toggles every idle cycle.

## Test-contract decision for `tb_ap040_cache_snoop.v` T12

The original T12 asserts that the predicted (lookahead) reads are strictly
faster than an "ordinary" repeat read of `F000`. With idle admission that
repeat read legitimately completes in two clocks as well, because the address
sat on the bus during the idle gap, so the strict comparison ties and the
unmodified bench reports two FAILs while every returned value is correct.

Decision: the assertion's intent, "the predictor is faster than a lookup that
must read the RAM", is still the right contract. The adjusted bench
(`candidate/tb_cache_early.v`) keeps the strict comparison and makes the
ordinary seed genuinely ordinary by presenting a different idle address for
two clocks before it, so the seed falls back to three clocks. It then adds T14,
which asserts the new behaviour directly: settled byte and word reads complete
in two clocks, a stale index falls back to three, a same-index different
physical tag refills, and a snoop during frozen `ce` invalidates the reuse.
If the cache is adopted, T12 plus T14 replace the original bench in the
AP68040 submodule (committed there first, per the submodule rule), with the
T12 comment explaining the forced fallback. The original bench is not
silently relaxed: the two-clock tie is asserted as intended behaviour in T14
rather than tolerated in T12.

## Gates launched from this review

All in isolated `/tmp` copies; the active tree is untouched.

1. AP68040 all-11 suite on baseline and candidate; adjusted bench on both;
   full suite with the adjusted bench substituted; immutable first-100
   corpus gate on both; handoff latency fixture reproduced on both.
2. SDRAM-integrated exact Sieve at all 16 even alignments, baseline versus
   candidate (TC off: a correctness and no-regression check, not a gain
   measurement), plus the `verilator/` memory-path benches with the candidate.
3. Full-machine Verilator boot of the Speedometer disk with the fastboot ROM,
   same 900,000,000 half-edge budget, baseline versus candidate, comparing
   opcode dispatches in the fixed budget and cache-state occupancy. Mac OS
   boots with translation enabled, so this is the first translated-workload
   measurement of the candidate.
4. Matched Quartus build: the preserved trimmed source-only seed-24 tree
   (`/tmp/MacQuadra800_features_seed24.UNORIQ/trim`, 36,538 ALMs, 4,061 LABs)
   copied and changed only in `ap040_cache.v`.

Hardware follows only if 1 to 4 hold, through `scripts/cpu_benchmark_core.sh`
with the completion-modal rule from `docs/AGENT_TESTING_WORKFLOW.md`.

## Results

(appended as the gates report)

### Gate 2: SDRAM-integrated exact Sieve, 16 alignments (done, no regression)

Trees `/tmp/sieve-base.68Q9uX` and `/tmp/sieve-cand.WRU5Bu` (only
`ap040_cache.v` differs; candidate binary confirmed to contain `idle_hit`).
Both sweeps exit 0 with 16 `INTEGRATION_COMPLETE` lines; `array/guards/drained
= PASS`, `D6=1`, `D7=1899`, `imiss=5`, `dmiss=512` at every offset in both.
Every printed counter and the cycle count are byte-identical between baseline
and candidate at all 16 offsets (total 13,596,008 cycles each; per-offset
814,729 to 891,041). The fixture runs with `tc=00000000`, so no translated
request exists and the idle path has no early cycle to use: this is the
expected zero, a correctness result only. The fixture prints no idle-hit
counter, so it cannot say whether the path fired without saving cycles or
never fired.

`verilator/` targets `tb_memory_path_registered_first_miss`, `tb_memory_path`,
`tb_wombat_bus32`, `tb_store_buffer`, `tb_sdram` all pass in the candidate
tree (tb_sdram: 45 checks, 0 chip protocol errors). None of them compiles
`ap040_cache.v`; they only show the tree is otherwise intact.

### Gate 1: AP suite, adjusted bench, corpus, latency fixture (done, as expected)

Trees `/tmp/cache-gate-base.nixQgF` and `/tmp/cache-gate-cand.Y9LfCi`.

| check | baseline | candidate |
|---|---|---|
| unmodified all-11 suite | exit 0, all pass | exit 1; only `cache_snoop` fails, only the two T12 ties (`normal=2 fast=2 chained=2`) |
| adjusted bench `tb_cache_early.v` | T14 fails as predicted (settled byte/word = 3 clocks) | exit 0, `ALL TESTS PASSED` + `EARLY_ADMISSION_TESTS_COMPLETE`, 0 FAIL |
| suite with adjusted bench substituted | n/a | exit 0, 11/11 pass |
| immutable first-100 corpus gate | 34,740,491 cycles, 1,900 groups, 0 REAL diffs | 34,740,491 cycles, 1,900 groups, 0 REAL diffs (results.bin byte-identical) |
| handoff latency fixture | 2,188 clocks, 0 idle completions | 2,127 clocks, 61 idle completions; only phase 2 (ATC-hit) changes, 4 -> 3 and 20 -> 19 |

The corpus payload, like the Sieve, exercises no eligible translated hit, so
equal cycles is the expected result there too. The patched cache was
confirmed present in both candidate simulators. `rg` is missing from a
non-interactive PATH; the corpus script was run unmodified with the system
`rg` on PATH.

### Gate 4: matched trimmed seed-24 build (done, fits, timing met)

Tree `/tmp/MacQuadra800_cache_early_seed24.Wqzs1u`, only `ap040_cache.v`
differs from the trimmed source-only base; QSF byte-identical (SHA256
`f8b1b0c9...`, seed 24, `configs/cpu_development.tcl`). Quartus exit 0,
13m05s, log `output_files/build_20260913_205633.log`.

| metric | trim/source-only | trim/cache-early | delta |
|---|---:|---:|---:|
| ALMs needed | 36,538 | 36,684 | +146 |
| LABs occupied / free | 4,061 / 130 | 4,078 / 113 | +17 / -17 |
| registers | 23,046 | 23,032 | -14 |
| M10K / memory bits / DSP | 459 / 3,435,654 / 31 | same | 0 |
| setup slack, clk_sys 33 MHz (CPU) | +0.996 ns | +0.656 ns | -0.340 |
| setup slack, clk_ram 99 MHz | +0.542 ns | +0.770 ns | +0.228 |
| setup slack, HDMI 148.5 MHz | +0.615 ns | +0.322 ns | -0.293 |
| worst hold anywhere | +0.213 ns (HDMI) | +0.247 ns (HDMI) | |

All TNS zero in every domain and analysis type; no new Critical Warnings
(the one pre-existing map warning is unchanged). `ap040_cache` still infers
13 M10K (4 x 2 data ways, 5 tag), nothing fell to registers. The 0.34 ns
loss on the CPU clock is the expected comparator-mux path. RBF SHA256
`fb6682047db2b95f2178b736934f8cbce353eff008d0b37c605d2192a514e6e3`,
4,377,060 bytes.

### Gate 3: full-machine Verilator boot A/B (done, first translated-workload gain)

Trees `/tmp/simboot-base.l3sBmS` / `/tmp/simboot-cand.j4kbjx` (only
`ap040_cache.v` differs), run dirs `/tmp/simboot-run-base.uytuxt` /
`/tmp/simboot-run-cand.Vygd5j`. Fastboot ROM (SHA256 `045c0274...`, memory
test skipped, deliberately the same for both), fresh copies of the golden
Speedometer disk (MD5 `16790b05...`), `--max-cycles 900000000`, identical
control file (`profile start`, `wait 420000000`, `profile stop`, `shot`).
Both exit 0 at the full budget; both profiles bracket the same 420,000,002
clocks starting at simulator cycle 49. Both end on the Mac OS "Starting up..."
progress screen (frame 1001, byte-identical PNGs), with `tc=0000C000` and
`cacr=80008000` at the end of the bracket: translation and both caches on.

| metric (same 420,000,002 clocks) | baseline | candidate | delta |
|---|---:|---:|---|
| opcode dispatches | 50,276,290 | 53,312,328 | **+6.04 %** |
| clocks per dispatch | 8.354 | 7.878 | -5.70 % |
| `rd_accept` | 37,424,777 | 40,544,389 | +8.34 % |
| `ipred_hit` cycles | 13,162,247 | 13,767,420 | +4.60 % |
| cycles with MMU / D-cache / I-cache enabled | 362.4 M / 362.3 M / 408.1 M | identical | 0 |
| cache `C_IDLE` cycles | 284,478,516 (67.7 %) | 304,287,321 (72.4 %) | +4.7 pp |
| cache `C_LOOK` cycles | 24,262,530 (5.8 %) | 2,815,857 (0.7 %) | **-5.1 pp** |
| cache `C_FILL` cycles | 35,331,061 | 35,311,350 | -0.06 % |
| cache `C_PASS` cycles | 70,607,933 | 72,266,318 | +2.3 % |

Reading: with translation on, almost every cache hit that used to spend a
clock in `C_LOOK` now completes at admission (the 21.4 M `C_LOOK` clocks
saved are 5.1 % of the bracket, and dispatches rose 6.0 %). Fill and pass
occupancy are unchanged, so the miss and I/O behaviour is the same and the
extra dispatches are the same boot code executed further (the candidate's
sector reads run ahead of the baseline's at the same cycle: LBA 32,428
versus 26,676 at the bracket end). This is a boot workload, not CPU Mix, and
boot includes disk waits; the hardware runs are the acceptance measurement.

### Hardware: Speedometer 4.02 CPU Mix, three valid runs (done, accepted)

Deployed through `scripts/cpu_benchmark_core.sh` (dry-run, deploy and restore
all exit 0) as `/media/fat/_Unstable/MacQuadra800_cache_early_trim_seed24_20260913.rbf`,
RBF SHA256 `fb668204...`. Boot verified visually before input; setup script
exit 0 with `setup_ready.png` showing all ten tests at one iteration; each
run started with its own Return after the previous alert was dismissed and
the setup re-verified (completion-modal rule); quiet intervals 144 / 148 /
144 s. Parent (Astra) viewed all three completion screenshots: fresh "The
tests are done!" alert on each, guest clock 1:19, 1:23, 1:26 AM.

| Test | Run 1 | Run 2 | Run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 369.334 | 370.623 | 370.447 |
| Dhrystones/sec | 5606.060 | 5607.888 | 5607.536 |
| Towers (sec) | 1.867 | 1.867 | 1.868 |
| Quick Sort (sec) | 1.270 | 1.268 | 1.269 |
| Bubble Sort (sec) | 1.546 | 1.546 | 1.545 |
| Queens (sec) | 1.042 | 1.042 | 1.042 |
| Puzzle (sec) | 2.909 | 2.909 | 2.912 |
| Permutations (sec) | 2.959 | 2.958 | 2.959 |
| Integer Matrix (sec) | 2.104 | 2.080 | 2.102 |
| Sieve (sec) | 3.029 | 3.026 | 3.026 |
| CPU Mix | 0.485 | 0.486 | 0.485 |

Mean **0.485333**: +4.71 % over the matched trimmed source-only pair
(0.463 / 0.464, mean 0.4635) and +5.81 % over the accepted untrimmed CD-off
source-only mean 0.458667. No invalid or impossible time in any run. Every
test improved, Dhrystones most (+7.8 %), Sieve least (-1.7 % time).

Screenshot SHA256: run 1 `8136295e...`, run 2 `5769828d...`, run 3
`1b175501...`; evidence in `scratch/perf_cache_early_seed24_20260913/`
(`RESULTS.txt` has timestamps). Final state: core MENU, Main MD5
`dfb5937b...` unchanged, disposable restored to `16790b05...`.

## Decision

Accepted 2026-09-13. The gain is larger than the handoff's cautious
"one clock per translated hit" framing suggested because Mac OS runs with
translation on and nearly every cache hit was paying the `C_LOOK` clock
(simulator: `C_LOOK` occupancy 5.8 % -> 0.7 %). The candidate cache and the
adjusted bench (T12 forced-fallback seed plus T14) are committed in the
AP68040 submodule; the parent pointer, this note and the task list follow.
The trimmed feature profile used for the fit is still opt-in and uncommitted;
the full-feature QSF has not been re-fitted with this CPU/cache pair.
