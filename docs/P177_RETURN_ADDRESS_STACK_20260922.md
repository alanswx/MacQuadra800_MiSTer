# P177 — a return-address stack for the RTS target hint

After P175b the fetch instrument on Permute(7) had 22,371 un-hinted fetches left, 18,739 of them issued
from S_MRD: the RTS target fetch, issued in the pop read's acknowledge clock from the popped data
(`go_pc(mem_rdata)` at the retire site). Nothing can hint that fetch from the data — but the address is
predictable: it is what the matching JSR/BSR pushed.

`ras[0:7]` / `ras_sp` in the core: pushed with the store data (`m_wdat`, the return address) at the
acknowledge of a push store whose continuation is `S_JSR2` or `S_BSR_PUSH`; popped at the RTS retire.
During the pop read (`S_MRD`, `r_m_ret == S_RET2`, `ret_kind == RK_RTS`) the instruction hint bus
carries `ras[ras_sp-1]`, so when the popped address agrees the target fetch issued at the acknowledge is
a one-clock hit. A wrong prediction (overflowed stack, RTD/RTR, a modified return address) costs nothing:
the fetch is un-hinted, as before. The redirect hints (this one and `hint_bcc`/`hint_redir`/
`hint_ftb`/`hint_bd`) now take the instruction hint bus over a fetch that is outstanding but not
presented, since such a fetch is replaced by the redirect in the next clock (`ifr_avail`); a presented
fetch keeps the bus.

| fixture | P175b | P177 | delta |
|---|---:|---:|---:|
| Permute(7) lat 0 | 1,114,950 | **1,081,092** | -3.0 % |
| Permute(7) lat 3 | 1,162,939 | 1,130,419 | -2.8 % |
| Whetstone | 24,690,824 | 24,661,704 | -0.1 % |
| Dhrystone | 100,754,349 | **99,604,352** | -1.1 % |
| Queens | 54,151 | 53,925 | -0.4 % |

Against P170 (the cache last on hardware, Mix 1.364): Permute -14.4 %, Whetstone -3.9 %, Dhrystone
-6.1 %, Queens -5.6 %. Gates: `run_tests.sh` 31/31, 22 pipeline programs, 4 IRQ replays.
