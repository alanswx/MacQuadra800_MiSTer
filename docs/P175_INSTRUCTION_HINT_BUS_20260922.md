# P175 — the instruction side's own hint bus

## Why

After P174 (the one-clock instruction hit) the fetch instrument on Permute(7) still showed 63k of 175k
fetches issued without their address on the hint bus in the clock before (a two-clock fetch each) and
80k clocks of a data request waiting behind a presented fetch. Both are the one hint bus: the cache's
idle read — the tag row and the data word the one-clock acknowledge needs — is indexed by a single
address per clock, and the data side's hints (`hint_data`, `hint_store`, `hint_pipe`, ...) and the
instruction side's (`epf_ftail`, the redirect targets) took turns on it.

## The change

- **Core**: `mem_ihint_addr`, a second hint output: the presented fetch while `ifr_req`, else the
  redirect targets (`hint_bcc`, `hint_redir`, `hint_ftb`, `hint_bd`), else the queue's next fetch
  `epf_ftail`. `mem_hint_addr` carries only the data request and the data hints (`mem_hint_instr` is 0).
- **MMU**: the instruction hint translated the same way as the data hint (instruction space, the
  per-space copy's instruction entry, the ITTs) and registered: `m_ihint_ptag`, `m_ihint_match`.
- **Cache**: a mirror of the tag RAM (`ctag_ram_i`, port A written in step, otherwise reading the
  instruction hint's row) and a mirror of the data banks (`idata0..3`, every clock at the instruction
  hint's row and word). `fast_ihit` is P174's hit on these mirrors (`ihint_tag_q`, `idata_q`, `hqi_lo`,
  `c_ihint_match`); the line for the offer is still read on the P170 pair banks in the acknowledge
  clock. While an instruction request is presented (`c_ihold`, the wrapper arbiter's registered choice)
  the architectural banks follow the instruction hint, so the registered instruction paths
  (`ipred_hit`, `idle_hit`, `C_LOOK`, the line read) index their own row; otherwise they follow the
  data hint.
- **Engine hold (P175b)**: a fill is not issued in the clock after an instruction acknowledge — that is
  the clock the cache offers the acknowledged line, and the core takes an offer only with no fetch
  outstanding. With one-clock fetches the engine won that race constantly (offers refused while a fetch
  was pending: 66k -> 107k clocks) and refetched the offered words a longword at a time. The hold alone,
  without the second hint bus, loses (P174 + hold: Permute +1.8 %); the pair wins.

RAM: +4 M10K for the data mirror and the tag mirror; the pair banks (P170) stay.

## Results (latency 0 / 3; vs P174)

| fixture | P174 | P175 (bus only) | P175b (bus + hold) | vs P174 |
|---|---:|---:|---:|---:|
| Permute(7) lat 0 | 1,132,146 | 1,128,181 | **1,114,950** | -1.5 % |
| Permute(7) lat 3 | 1,168,890 | 1,166,969 | 1,162,939 | -0.5 % |
| Whetstone | 24,886,003 | 24,986,611 | **24,690,824** | -0.8 % |

Fetch presentations on P175's Permute: 204,138, **143,486 fast (70 %)**; un-hinted 23,791 (18,740 of
them the JSR/RTS targets, known only at the pop or the acknowledge); data-behind-fetch 80k -> 20k clocks.
Fill policy under P175b: "wanted = outstanding request only" equals the base, "never wait" and a floor of
4 are worse; the base (floor 3, idle fill to 6 when no data request or hint) stays.

Gates: `run_tests.sh` 31/31 (the two direct cache benches now connect the new ports), the 22 pipeline
programs, the four IRQ replay programs; Dhrystone and Queens below.

| Dhrystone | 102,604,350 | | **100,754,349** | -1.8 % |
| Queens | 54,785 | | **54,151** | -1.2 % |

Cumulative against P170 (the last cache on hardware, Mix 1.364 as P165b): Permute -11.8 %, Whetstone
-3.8 %, Dhrystone -5.0 %, Queens -5.2 %.
