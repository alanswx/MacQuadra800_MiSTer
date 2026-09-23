# P189/P190: the MOVEM predecrement store hint, and LEA d16 / LINK / UNLK dispatched from the retire

Towers profile on P188 (latency 3, `scripts/cpu/profile_towers.py --profile` plus an (opcode, state)
table): S_DECODE 16 % of all clocks; per call MOVEM.L save ~17 clocks for four registers, JSR d16(PC)
5.6, LINK 4.8, UNLK/RTS 3, LEA d16(A5) 2 (S_DECODE + S_EA_D16).

## P189: MOVEM's predecrement stores hinted at their own address

`hint_st_movem` presented `mm_addr`, but the predecrement form (`MOVEM.L regs,-(A7)`, every register
save) stores at `mm_addr - size`, so its stores never matched their hint and took the registered
path.  Towers -0.6 %.  (The rest of MOVEM's store time is the cache still in C_PASS on the previous
store: Pascal's 2-mod-4 stack makes each longword a spanning store, which reads its line before it
posts.  Byte-enable writes to the data RAMs would remove that read; not done.)

## P190: three more retire dispatches

`dispatch_branch` and `dispatch_dbcc` already take a queued BRA/BSR/JSR/JMP or DBcc from the
previous instruction's retire straight into its state.  The same now for:

- **LEA d16(An),Am** (`ld_ok`, under `AP040_EXPERIMENTAL_LEA`): displacement popped with the opcode,
  An on port A, into S_EA_D16 with `r_ea_ret = S_LEA1` (S_EA_D16 retires a LEA itself from the
  forwarded base).
- **LINK.W An,#d** (`lk_ok`): into S_LINK2 with the displacement in `imm`.
- **UNLK An** (`ul_ok`): into S_UNLK1.

Each is refused when the retiring arm writes An (or, for LINK/UNLK, A7) on the same edge, since the
states read them unforwarded (checked inline on `rfw_now`, as DBcc's is: `rfw_now` is a blocking
variable of the clocked block, not a wire).  RTS is left in S_DECODE: its pop read issues from decode
in place and hinted, which a dispatch from an arbitrary retiring state would lose.

| fixture (lat 3) | P188 | P190 | |
|---|---:|---:|---:|
| Towers | 17,696,009 | 17,057,470 | -3.6 % |
| Permutations (lat 0) | 1,022,062 | 996,192 | -2.5 % |
| Whetstone (writes latency 1) | 22,051,732 | 21,887,117 | -0.7 % |
| Dhrystone | 93,854,297 | 93,354,300 | -0.5 % |

All six fixture oracles and the AP68040 self-tests (including `lea_d16`, `lea_fault`) pass.
