# Which instructions still pay the decode cycle (2026-09-14)

Measured on checkpoint 8's RTL with a probe simulator that counts, per
opcode, entries into `S_DECODE` during the Speedometer CPU Mix bracket
(`/tmp/simspeedo-probe2/profile.tsv`, `DECODE_OP` rows). 211,011,277
dispatches; **147,319,357** of them (70 %) enter `S_DECODE`. The rest
dispatch by lookahead from the fetch queue straight into `S_PIPE_REGS`.

| opcode | decode entries | share of its dispatches | instruction | remedy |
|---|---:|---:|---|---|
| 5243 | 5,943,676 | 88 % | ADDQ.W #1,D3 (after a store) | checkpoint 9: store producer |
| 206E | 5,252,256 | 77 % | MOVEA.L d16(A6),A0 | memory-source lookahead (`/tmp/rm-cand`) |
| 0C43, 0C44 | 8,196,680 | 85-100 % | CMPI.W #imm,Dn | checkpoint 9: immediate descriptor |
| 6xxx (Bcc) | about 17 M | 100 % | conditional branches | not covered: Bcc lookahead would resolve the condition at the producer's retire |
| 3005, 5241, D482 | 5.8 M | 94-100 % | register ops at taken-branch targets | branch-target predecode (apply the descriptor to the refill word) |
| E588 | 2,909,178 | 100 % | ASL.L #2,D0 | shifts run S_EXEC, S_SHIFT, S_SHIFT_WB: a barrel shift as an ALU op |
| 2270, 302E, 306E, 3A30 | 8.2 M | 94-100 % | MOVE <mem>,Rn | memory-source lookahead |
| B270, BE70, BA70, B66D | 5.3 M | 100 % | CMP <mem>,Dn | memory-source lookahead |
| 4E75, 4E56, 4E5E, 4EB9 | 8.9 M | 98-100 % | RTS, LINK, UNLK, JSR abs.l | control-flow trims |
| 4A71, 4A32 | 3.1 M | 95-100 % | TST <mem> | add TST to the memory-source class |
| 52AE, 12D0 | 3.1 M | 100 % | ADDQ d16(An), MOVE.B (An),(An)+ | memory-destination ops |
| 41ED, 48C0, 48E7 | 3.5 M | 87-100 % | LEA, EXT.L, MOVEM | not covered |

Boot bracket for comparison (same probe, `/tmp/simboot-probe2.*/run`):
58.9 M of 80.4 M dispatches decode; Bcc and DBcc loops dominate there.
