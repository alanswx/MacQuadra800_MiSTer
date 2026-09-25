# P195b-P197: byte-lane cache arrays, the read-after-store handoff, FPU and PEA dispatches

## P195b: the byte-enabled data arrays as byte lanes

P195's per-byte slice writes into `reg [31:0]` arrays synthesized into flip-flops: Quartus 17 did not
infer byte-enabled RAM from that form in this Verilog-2001 file (the stopped P195 fit had 514,863
registers).  Each of the twelve data arrays (`cdata0..3`, `pairdata0..3`, `idata0..3`) is now four
8-bit lane arrays (`cdata0_b3..b0` ...), each an ordinary RAM written when its lane's enable is set,
read as the concatenation.  Same bits, same behaviour (cycle-identical on every fixture).

## P196: the read-after-store handoff

Of Whetstone's 1.33M `S_PIPE_START` clocks for memory-source ops, 870k followed a store's retire
(`S_MWR`, `r_m_ret == S_NEXT`): the store held the request and the hint bus in its acknowledge clock, so
the next instruction's read could only issue a clock later from S_PIPE_START.

- **Regfile port F** (every configuration, not an EXTRA_READS port -- the self-test build has none, and
  a pipeline-only port read zero there): `raddr_f = {1, rd_ir[2:0]}`, the queue head's EA register.
- **The prediction** (`hint_rsr`, registered-derived): the first S_MWR clock of a store that retires
  its instruction, hinted when it issued (`st_hinted`), the cache ready (`mem_fast_ready`), no fetch
  presented, no pipeline write, no trace; the next instruction a record-dispatched op (`NX_PSTART`)
  with an (An) or d16(An) memory source (`rsr_head`).  The data hint then shows that source address
  (`rsr_addr`: port F, a write landing now forwarded, plus the resident displacement).
- **The handoff** (`retire_store_read = hint_rsr && d_ack`): `apply_record` issues the read in place on
  the store's acknowledge edge (the in-place whitelist admits it under the held store), pops a d16
  displacement, sets port B for a register destination and port A for a MOVE destination; refused when
  the retiring arm writes the base on that edge.
- **Cache**: a store accepted while the hint is away looks its tag up at its own row (`tag_ridx` takes
  `a_row` under `c_hint_away && c_write`) -- with P195 the tag is all a store still takes from its accept
  clock -- and a data read may hit (fast, pair, cross-line) during a posted store's C_PASS
  (`fast_accept_pp`) unless one of its words is one the store writes (`pp_clash`, word granular: the
  store changes only its own bytes), the store is line-crossing, or an invalidate is owed.  `c_rdata`
  forces memory data only in a non-posted C_PASS.

Prediction accuracy on Whetstone: 275,262 predicted, 275,258 acknowledged as predicted.  The first
version (row must differ, aligned hits only) gained 0.2 %; the word-overlap rule and the pair/cross-line
hits in C_PASS made it 1.1 % (Whetstone), Towers -1.0 %.

## P197: FPU general ops and PEA d16(An) from the retire

The top S_DECODE users left in Whetstone were the FPU's cpGEN ops (~490k clocks) and PEA d16(A6)
(159k).  cpGEN (`$F200-$F23F`, not an illegal EA, command word resident) now dispatches from the retire
straight into S_FPU_DEC (which does all of decode's work from `imm`); PEA d16(An) into S_EA_D16 with
`r_ea_ret = S_PEA1` (the P180 push), refused on a same-edge write to An or A7.  Whetstone -1.6 %.

## Results (writes latency 1 for Whetstone, else latency 3)

| | P193 (hardware 1.646) | P197 |
|---|---:|---:|
| Whetstone | 21,664,729 | 20,731,556 (-4.3 %) |
| Towers | 16,958,527 | 16,630,818 (-1.9 %) |
| Dhrystone | 93,104,302 | 91,554,306 (-1.7 %) |
| Permutations (lat 0) | 996,189 | 984,476 (-1.2 %) |
| Queens | 51,887 | 51,692 (-0.4 %) |

All fixture oracles and controls (latency 0 and 3; Quick, Puzzle, Matrix with the 8K MMU) and the
AP68040 self-tests pass.
