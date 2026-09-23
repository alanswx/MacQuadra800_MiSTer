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

## P191-P193 (same day)

- **P191, the JSR target fetch from S_JSR1.**  147k of Towers' 196k JSR d16(PC) were dispatched from a
  store's acknowledge (`S_MWR`), where `bd_go` must not raise the early fetch, so the target fetch went
  out only from S_JSR2 after the push and S_FETCH waited 2.8 clocks.  S_JSR1 now raises `sgo` (a new
  `go_pc_t_early` arm, `ea_addr`) behind the push; `issue_ifetch` does nothing when the pop already armed
  the stream there.  Towers -0.6 %, Whetstone -0.5 %.
- **P192, P182's store hint needs the data channel presented.**  The P175 merge dropped P182's
  `!ifr_hint_now` term with the fetch's use of the data hint bus; it also meant "a fetch holds the port,
  so this read cannot be acknowledged now".  `hint_move_store` requires `!ifr_pres` again.
  Cycle-neutral on the fixtures (the fetch's registered path takes the data banks anyway).
- **P193, the FPU's alignment shift in one clock.**  `F_SHR` shifted 32/16/8/4/2/1 bits a clock (up to
  six clocks per add alignment; Whetstone's polynomial FADD.X averaged 8.3 FPU clocks).  It now shifts
  the 67-bit {int, G, R, S} vector in one clock, S collecting every bit shifted out -- proved equal to
  the staged loop on 300,000 random operand/count pairs (counts 0..127).  Whetstone -0.5 %; the FPU
  self-tests pass.

P190-P193 against P188 (latency 3, writes latency 1 for Whetstone): Towers 17,696,009 -> 16,958,527
(-4.2 %), Permutations (lat 0) 1,022,062 -> 996,189 (-2.5 %), Whetstone 22,051,732 -> 21,664,729
(-1.8 %), Dhrystone 93,854,297 -> 93,104,302 (-0.8 %).  All oracles and the AP68040 self-tests pass.
The P190 fit (seed 24) failed routing at 38,570 ALMs; P193 fits at seed 25.
