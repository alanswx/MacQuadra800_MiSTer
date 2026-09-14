# Posted-store acknowledge and level line offers (2026-09-14, candidate)

Builds on the write-path candidate (`CPU_WRITE_PATH_20260914.md`, simulated
CPU Mix 0.661). Two small changes, one of them found by the other.

## 1. The store queue acknowledges a posted write in its capture cycle

The cache already acknowledges a cacheable store to the core when it posts
it (`post_active`), then drains the captured copy to the store queue and
stays busy until the queue acknowledges. The queue answered a cycle after
capture (`accept_ack`, which doubles as the held-request guard), so every
posted store held the cache one cycle longer than necessary: `post_active`
blocks `tag_ridx`, `c_busy` and the walker, and back-to-back posted stores
were 43 M cycles of the Speedometer profile.

Change: the cache exports `m_posted` (= `post_active`); the queue takes it
as `s_posted` and acknowledges `push & s_posted` in the capture cycle. The
guard flop is then not set (`accept_ack <= !s_posted`): the requester has
moved on, and a set guard would have acknowledged the *next* write without
capturing it (caught in review, before the hardware saw it). Nothing
upstream waits on the combinational acknowledge: the core's acknowledge
was registered at posting time.

Results: AP suite 11/11, `tb_store_buffer` pass, corpus gate identical
cycles / 0 REAL diffs, latency fixture pass. Posted stores drain in 2
clocks instead of 3 where the queue has room (phase 9: 9 of 31 at 2).

The Sieve sweep, however, went **slower at offset 6** (581,419 -> 595,957,
+2.5 %), with 15 k more bus requests and the registered-admission fetch
hits (`ihit`) falling from 17,415 to 1,956. That led to the second change.

## 2. The whole-line instruction offer is a level, not a pulse

The cache offered its buffered instruction line to the core for exactly
one cycle (`iline_stb`, or `iline_stb_pend` after a buffer hit). The core
refuses an offer while a queue fetch is outstanding (`epf_pend`) or in any
cycle with `mem_ack` set. A refused pulse was gone: the core then fetched
the rest of that line, and the next one, with explicit requests (2 clocks
each, more when they had to run through `C_LOOK`).

The traced Sieve loop (offsets 0x2034..0x2042, crossing the line boundary
at 0x2040) showed it directly: the write-path build completes the loop's
instruction supply with one fetch request per iteration, the posted-ack
build needed three, because the store's earlier completion let the
following data read complete at admission (2 clocks) and its acknowledge
landed exactly on the offer cycle.

Change (`ap040_cache.v`): `c_line_stb = iline_valid && !iline_pending`.
The core's accept is idempotent (it appends only the words between the
queue tail and the end of the offered line, and re-seeding the branch
refill sector with the same data is harmless), so holding the offer costs
nothing and any cycle the core is free it takes the line. `iline_stb` /
`iline_stb_pend` are now unused.

Sieve sweep (cycles; requests in parentheses):

| offset | write-path | + posted ack | + level offer |
|---:|---:|---:|---:|
| 0  | 593,364 | 593,353 | **575,473** (83,249 req, -3.0 %) |
| 6  | 581,419 (101,110 req) | 595,957 (116,109 req) | **563,258** (81,052 req, -3.1 %) |
| 16 | 632,055 | 632,055 | **616,415** (-2.5 %) |
| 30 | 598,954 | 598,954 | **590,305** (-1.4 %) |

All four arrays and guards PASS. AP suite 11/11, corpus gate identical
cycles / 0 REAL diffs, latency fixture 1,983 clocks PASS. Pending: boot
A/B, simulated Speedometer, fit, hardware.

Candidate tree: `/tmp/sb2-cand.*` (files: `ap040_cache.v`,
`ap040_tg68k_compat.v`, `wombat_cpu.sv`, `wombat_store_buffer.sv`).

### Boot A/B (done, holds)

Same ROM, disk, control file and 420,000,002-clock bracket as the
write-path run (`/tmp/simboot-merge.cDPE1S/run` versus
`/tmp/simboot-sb2.*/run`): opcode dispatches 70,065,559 -> **70,341,042**
(+0.39 %), 5.994 -> 5.971 clocks per dispatch, same "Starting up" frame,
no faults. Posted-write drain cycles (`pass_cycles_write`) 18.60 M ->
14.00 M, store-queue-full stalls 4.73 M -> 3.48 M, `C_PASS` cycles -4.0 M;
`C_LOOK`/fill cycles +3.7 M as the freed time lands on the next miss.
Boot is a poor proxy for the benchmark (the Sieve fixture moved 1.4-3.1 %);
the simulated Speedometer decides.

### Fit (done, closes at seed 22)

Trimmed profile with `VIDEO_512_OFF`, seed 22, tree
`/tmp/MacQuadra800_sb2_v512s22.*`: 38,459 ALMs (92 %), all 39 TNS zero,
worst setup +0.039 ns (HDMI), clk_ram +0.178 ns, clk_sys +0.814 ns, worst
hold +0.250 ns, no Critical Warnings. RBF SHA256
`89c27536a3335e96b5a446eac50ea99387886de296751d6ca4c959eb335d0cf8`
(4,427,380 bytes); sources cache `4d707652...`, `wombat_cpu.sv`
`e48cef29...`, `wombat_store_buffer.sv` `1e971856...`, core unchanged
`b2afc434...`. The HDMI margin is the thinnest of any build this week; a
seed walk is the remedy if a later candidate needs it.

### Hardware (done, three valid runs) — accepted 2026-09-14

`/media/fat/_Unstable/MacQuadra800_sb2_v512_seed22_20260914.rbf` through
the lifecycle guard (dry-run, deploy, restore all exit 0), fresh alert each
run, no negative or impossible time:

| Test | run 1 | run 2 | run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 472.955 | 474.634 | 474.481 |
| Dhrystones/sec | 7930.051 | 7929.597 | 7929.200 |
| Towers (s) | 1.483 | 1.484 | 1.483 |
| Quick Sort (s) | 0.962 | 0.961 | 0.962 |
| Bubble Sort (s) | 1.072 | 1.072 | 1.072 |
| Queens (s) | 0.782 | 0.782 | 0.782 |
| Puzzle (s) | 2.239 | 2.238 | 2.257 |
| Permutations (s) | 2.190 | 2.191 | 2.190 |
| Integer Matrix (s) | 1.592 | 1.582 | 1.593 |
| Sieve (s) | 1.810 | 1.808 | 1.807 |
| **CPU Mix** | **0.658** | **0.659** | **0.659** |

Mean **0.658667**, **+1.91 %** over the write-path checkpoint 0.6463 and
+42.1 % over the source-only 0.4635. Every test but Quick Sort (+0.006 s)
is faster; Dhrystones +4.6 %, Bubble Sort -2.5 %, Integer Matrix -4.5 %.
Evidence `scratch/perf_sb2_seed22_20260914/RESULTS.txt`. The agent's own
timing script captured runs 1 and 2 about 59 s after Run Set instead of
after the 140 s wait; the alerts were fresh (values differ run to run on a
freshly restored disk) and run 3, captured after a verified 140 s wait,
agrees. Board restored to MENU, Main and disposable disk verified.
The simulated Speedometer for this candidate was still running at
acceptance; its score is recorded below when it lands.

### Simulated Speedometer (profile only)

The unattended run reached the completion alert (screenshot_f8534, guest
time 13:26) but its driver was terminated before the results window was
captured, so only the profile survives: **1,097,765,031 cycles** for the
CPU Mix bracket against 1,123,045,543 for the write-path build (-2.25 %),
5.545 clocks per dispatch. Scaling the write-path build's simulated 0.661
by the cycle ratio gives about 0.676; hardware measured +1.9 %. Profile:
`/tmp/simspeedo-sb2/profile.tsv`.

**Profile finding (2026-09-14, for the next candidate):** data fills rose
3,648,901 -> 4,128,451 (+13 %) and `S_MRD` fill cycles +7.3 M. The
capture-cycle acknowledge reaches the cache in the first `C_PASS` cycle,
before a spanning store's line read (`sline_read`, one cycle) is ready, so
every spanning posted store now takes the invalidate fallback instead of
merging both words. Fix: `m_posted = post_active && (!r_span2 ||
sline_ready)`, which lets spanning stores keep the one-cycle-later
acknowledge they need. Worth about 0.5 % (480 k refills); folded into the
next cache candidate rather than refitting this one.
