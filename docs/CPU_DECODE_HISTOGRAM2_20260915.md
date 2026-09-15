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
