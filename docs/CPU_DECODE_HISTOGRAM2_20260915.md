# Which instructions still pay the decode cycle, checkpoint 14 (2026-09-15)

Harness counters on the checkpoint 14 RTL (`stack4`), Speedometer CPU
Mix bracket of 968.6 M cycles and 196.4 M dispatches: entries into
`S_DECODE` per opcode, against dispatches and lookahead dispatches
(`scratch/profiles_20260915/speedo_probe4_decode.tsv`).  123.96 M
dispatches (63 %) still decode; `S_DECODE` is 129.7 M cycles, 13.4 % of
the bracket.  The two-clock-hit question was answered by the read-path
probe the same night (`CPU_XLINE_20260915.md`): three quarters of data
reads already take it.

By family (decode entries, share of all decode entries):

| family | entries | share | what would remove them |
|---|---:|---:|---|
| MOVE/MOVEA memory to register | 22.9 M | 19.3 % | memory-source lookahead (`CPU_BRANCH_LOOKAHEAD_20260914.md`: -0.6 % on hardware at checkpoint 9, when the decode cycle was the fetch engine's slot on a 4 KB I-cache; retest on the 16 KB caches) |
| Bcc | 18.8 M | 15.8 % | the lookahead resolves only branches behind an ALU/store producer with a buffered target; forward taken branches need the go_pc from the lookahead site (+700 ALMs, rejected for area) |
| MOVE to memory | 14.7 M | 12.3 % | memory-destination dispatch by lookahead (the destination EA starts at the pipe start already; the decode itself stays) |
| other | 13.0 M | 10.9 % | |
| RTS, LINK, UNLK, JSR | 8.8 M | 7.4 % | inherent (they redirect or push) |
| CMP memory | 7.7 M | 6.5 % | memory-source lookahead |
| ADDQ/SUBQ register | 7.5 M | 6.3 % | descriptor-covered; these follow non-producers (branch targets, LEA, EXT) |
| TST memory | 7.2 M | 6.1 % | memory-source lookahead (TST class) |
| MOVE register to register | 6.6 M | 5.5 % | as ADDQ register |
| CLR memory | 4.2 M | 3.5 % | memory-destination |
| LEA, MOVEM, ADDQ memory, EXT | 7.3 M | 6.1 % | |

Top single opcodes: `206E` MOVEA.L d16(A6),A0 6.71 M; `4232` CLR.B
(d8,An,Xn) 3.0 M; `2270` MOVEA.L (d8,A0,Xn),A1 2.86 M; `204A` MOVEA.L
A2,A0 2.69 M of 6.15 M dispatches (0.65 M by lookahead); `4E75` RTS
2.69 M; `5243` ADDQ.W #1,D3 2.57 M of 6.76 M (3.16 M by lookahead);
`4E56`/`4E5E` LINK/UNLK 2.27 M / 2.21 M; `302E`, `306E`, `3A30` MOVE.W
d16(A6)/(d8,A0,Xn) 5.3 M; the seven busiest Bcc 9.1 M.

## Where the bracket stands

| bucket | cycles | share |
|---|---:|---:|
| `S_MRD` (62.4 M reads; 45 M two-clock hits, 16.5 M three-clock, 3.1 M fills, 0.4 M bypasses) | 275 M | 28.4 % |
| `S_DECODE` | 130 M | 13.4 % |
| `S_MWR` (34.0 M stores) | 109 M | 11.2 % |
| `S_PIPE_REGS` | 91 M | 9.4 % |
| `S_PIPE_START` | 69 M | 7.1 % |
| `S_FETCH` (22.8 M demand fetches) | 63 M | 6.5 % |
| `S_EXEC` | 32 M | 3.3 % |

Hardware CPU Mix is 0.830; the target of 1.0 needs 17 % fewer cycles
than this profile.  The levers still identified sum to less than that
at their optimistic values: the one-clock data hit (about 45 M cycles,
parked for area), the memory-source lookahead (up to 38 M), forward
taken branches (up to 19 M, area), the remaining three-clock reads
(16 M), the store path's ordered waits (13 M, the queue experiment
showed the naive fixes lose), a second refill sector (demand fetches,
area).  Beyond them the cost is structural: every instruction still
serialises fetch queue, decode, pipe start, register capture and
retire, and the device is at 94 % with the fitter failing most seeds.

## Memory-source lookahead, retested on checkpoint 14 (`/tmp/rm2-cand.*`)

The checkpoint 9 patch (`CPU_BRANCH_LOOKAHEAD_20260914.md`) reapplied:
AP 11/11, corpus 33,790,558 (+52 K over 33,738,108), Sieve identical,
latency fixture **2,061 against 2,037**.  The loss is structural, not
the fetch slot: an operand dispatched by lookahead reaches
`S_PIPE_START` in the cycle the producer's register write lands, and
both the direct-read paths (`ext_inline`, the (An)/(An)+/-(An) inline)
and the address hint (`hint_ext_ok`) are gated on no write landing, so
the read issues a cycle later without a preceding hint and takes the
three-clock lookup instead of the two-clock idle hit.  The decode cycle
it removes is the cycle in which the hint precedes the read.  Forwarding
the base register into the hint (`rf_capture_a`) would add a mux to the
hint-to-acknowledge path, the design's worst; hinting from the producer's
retire cycle needs the base before its port is selected.  Fits stopped;
boot A/B and simulated Speedometer left running for the record.

### rm3: the same lookahead with a base-only landing guard

`hint_ext_ok` and `ea_start`'s inline paths were gated on any register
write landing (`!rf_we`); rm3 gates them on a write landing *to the base
register* (`base_landing = rf_we && rf_waddr == rr_a`, a 4-bit compare
into the qualifier, no data mux), since a write to another register
leaves port A correct.  AP 11/11, corpus 33,788,472, Sieve identical,
latency fixture **2,013** (checkpoint 14: 2,037; rm2: 2,061): the
lookahead-dispatched operand keeps its two-clock hit.  Boot A/B,
simulated Speedometer and fits running.

Boot A/B of rm3: 75,833,599 dispatches (checkpoint 14: 75,840,887),
1.04 M fewer decode entries but +0.64 M cycles of demand fetches and
+0.42 M of store waits in that ROM-heavy bracket.  Fits at seeds 22 and
20 failed routing (39,596 / 39,503 ALMs, +183 over checkpoint 14), and a
seed 22 fit with `PLACEMENT_EFFORT_MULTIPLIER 2.0`,
`ROUTER_EFFORT_MULTIPLIER 2.0` and `ROUTER_TIMING_OPTIMIZATION_LEVEL
MAXIMUM` (an experiment in the build tree, not in the profile) failed the
same way in 17 minutes: fitter effort does not rescue routing at this
utilisation; only the seed does (checkpoint 14 routed at 1 of 2 seeds,
the cache build at 1 of 3, the fold-only stack at 0 of 4).  Any accepted
candidate from here needs a walk of about six seeds in parallel.
