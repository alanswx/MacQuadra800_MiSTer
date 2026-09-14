# Instruction line return to the prefetch queue (candidate, 2026-09-14)

Follows the accepted address-hint checkpoint (`CPU_ADDR_HINT_20260913.md`).

## Why: instruction supply is the limiter

Per-instruction cycle attribution in the exact Speedometer Sieve kernel
(fixture `scripts/fixtures/wombat_sieve`, offset 0, accepted RTL):

| instruction | clocks |
|---|---:|
| `move.b #1,(0,a2,d3.w)` / `clr.b (0,a2,d4.w)` | 12 |
| `tst.b (0,a2,d3.w)` | 10.8 |
| `addq.w #1,d3` after the store | 5 |
| `cmpi.w #$1ffe,dn` | 4 to 5 |
| `ble.s` taken | 2 to 3 |
| `move.w`/`add.w` register forms | 1 to 2 |

A register instruction costs 1 clock when its opcode is resident and 3 to
5 when it is not. The prefetch queue drains because the fill engine is
locked out during EA states and while the port carries data, and a
longword fetch supplies at most one word per clock, exactly the rate a run
of one-clock instructions consumes. Folding the post-write `S_NEXT` state
(saves 1 clock per store) only moved the stall onto the following
instructions and lost at two alignments, so it is not adopted.

## What the candidate does

1. `ap040_cache.v`: the four way arrays are word-interleaved (array k holds
   word w of way v where (v + w) mod 4 = k, at index {bank, set, v}). A
   word-wise read addresses array k at way (k - w); a line-wise read
   addresses every array at the hit way and returns the whole 16-byte line
   in one cycle. The one-longword lookahead becomes a 128-bit line buffer,
   valid for any word of the line; a normal or idle-admission instruction
   hit seeds it on its own edge, and the buffer is offered to the core as a
   sideband (`c_line_stb/tag/data`) one cycle after every instruction ack.
2. `ap040_mmu.v`: pass-through of the sideband.
3. `ap040_core.v`: on the strobe, append every word from the fill tail to
   the end of the offered line that fits in the 8-word ring (up to 8), and
   seed the branch-refill sector buffer from the line. Refused while a
   queue fetch is outstanding or issued in the same cycle (its return would
   append the same words again) or after a flush in the same cycle.
4. Wrappers (`wombat_cpu.sv`, `ap040_tg68k_compat.v`): wiring.

Tree: the directory named in `/tmp/line-cand.path`.

## Results so far

- AP suite 11 of 11 after each step; corpus gate 0 REAL diffs.
- Latency fixture: 1,921 -> 1,841 clocks (-4.2 %) with the line append
  (interleaving alone is cycle-neutral, as intended). The fixture's shadow
  probes needed the interleaved index rule (local copy fixed).
- Sieve sweep: mixed (-3 % to +4 % per offset). Per-PC attribution at
  offset 0 shows the register instructions after the store still waiting,
  so the append is being refused in the hot loop; tracing in progress.
