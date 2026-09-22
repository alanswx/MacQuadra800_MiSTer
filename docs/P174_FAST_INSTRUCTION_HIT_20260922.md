# P174 — the one-clock instruction hit

## What the profile showed

On P171b's Permute(7) (1,175,448 clocks) an instrument on the wrapper's arbiter counted every
instruction-fetch presentation and whether it acknowledged in its first clock: **136,237 presented,
0 fast**. The cache's one-clock path (`fast_hit`, the acknowledge in the request clock from the hinted
idle read and the hint's registered tag) was data-only (`fast_accept` has `!c_instr`); an instruction
fetch always took the registered path (`ipred_hit` from the buffered line, or `idle_hit`), two clocks on
the one port. That is what the data side waited behind after the channel split: 90k clocks of a data
request queued behind a presented fetch, and the 58k pipe-source reads that lost their own one-clock hit
in 97 % of cases.

## The change (`rtl/ap68040/rtl/ap040_cache.v`)

`fast_ihit`: `fast_hit`'s terms on the instruction bank — the idle read indexed by the hint at the I row
(`idle_data_idx == {1, hq_lo}`), the hint's registered tag row (`hint_tag_idx == {1, set}`,
`hint_look_hit`), the registered `c_hint_instr` (`hq_instr_c`), `ie`, and the MMU's `c_hint_match`.
`c_ack` and `c_rdata` take it like `fast_hit`; `ipred_hit` yields to it.

The line offer needs the way's whole line a clock after the acknowledge, and the architectural data banks
are needed in that clock for the *next* request's hinted idle read. So the line is read on P170's mirror
banks (`pairdata0..3`, every array at `{row, hint_way}`) in the acknowledge clock and captured into
`iline_data` from `pair_q` the clock after (`iline_pair_pending`). The pair hit's precondition
(`fast_pair_idle`) gains `pair_idle_valid` — the mirrors hold the idle next-word read, not a line.

## Results (P171b core, latency 0 / 3 where measured; vs P171b and vs P170)

| fixture | P170 | P171b | P174 | vs P171b | vs P170 |
|---|---:|---:|---:|---:|---:|
| Permute(7) lat 0 | 1,263,600 | 1,175,448 | **1,132,146** | -3.7 % | -10.4 % |
| Permute(7) lat 3 | 1,278,213 | 1,212,524 | 1,168,890 | -3.6 % | -8.6 % |
| Whetstone | 25,671,327 | 25,185,192 | **24,886,003** | -1.2 % | -3.1 % |
| Dhrystone | 106,054,267 | 103,654,322 | **102,604,350** | -1.0 % | -3.3 % |
| Queens | 57,136 | 56,261 | **54,785** | -2.7 % | -4.1 % |

Fetch presentations on P174's Permute: 175,144, **96,426 fast (55 %)**; 62,698 issued without their
address on the hint bus the clock before (18,740 of them redirect seeds — JSR/RTS targets, known only at
the pop or the acknowledge; the rest fills issued under a branch-target hint, `hint_bcc`/`hint_bd`/
`hint_redir`, which are not in `data_hint_any`) and 16,020 hinted but with the data banks busy.
Holding fills for a hinted slot (P173, a registered "epf_ftail was the hint" flag with an un-hinted
floor of 1/2/3 words) loses on both P171b and P174 (best 1,151k against 1,132k): the fetch stalls it
adds outweigh the collisions it removes.

Gates: `run_tests.sh` 31/31, the 22 pipeline programs, the four IRQ replay programs.

## What is left on this port

79,634 clocks of Permute still have a data request waiting behind a presented fetch and 63k fetches go
out un-hinted: both are the one hint bus. The instruction side could have its own hint (epf_ftail is the
hint whenever nothing else is; a second hint bus would carry it always), with the mirror banks and the
tag RAM's port B reading the I row — that costs the pair hit (P170, -3 %) unless the mirrors can serve
both, and is the next structural item on the fetch side.
